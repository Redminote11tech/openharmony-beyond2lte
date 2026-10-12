// SPDX-License-Identifier: Apache-2.0
// Discover the actual registered UDC and bind only after HDC writes FFS descriptors.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/statfs.h>
#include <unistd.h>
#include "parameter.h"

#ifndef BEYOND2LTE_UDC_DIR
#define BEYOND2LTE_UDC_DIR "/sys/class/udc"
#endif
// Samsung 4.14 drivers/usb/gadget/function/f_fs.c (private kernel magic).
#define FUNCTIONFS_MAGIC 0x0a647361UL
#ifndef GADGET
#define GADGET "/config/usb_gadget/beyond2lte_hdc"
#endif

static int FindController(char *name, size_t size)
{
    DIR *dir = opendir(BEYOND2LTE_UDC_DIR);
    if (dir == NULL) {
        return 0;
    }
    int count = 0;
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') {
            continue;
        }
        if (strlen(entry->d_name) >= size) {
            closedir(dir);
            return -1;
        }
        ++count;
        if (count == 1) {
            strcpy(name, entry->d_name);
        }
    }
    closedir(dir);
    // Multiple controllers require an explicit board selection; never pick arbitrarily.
    return count == 1 ? 1 : (count == 0 ? 0 : -1);
}

static int WriteController(const char *name)
{
    int fd = open(GADGET "/UDC", O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    // A newline unbinds configfs UDC; empty write would do nothing.
    const char *value = name[0] ? name : "\n";
    size_t length = strlen(value);
    ssize_t written = write(fd, value, length);
    int savedError = written >= 0 && written != (ssize_t)length ? EIO : errno;
    close(fd);
    errno = savedError;
    return written == (ssize_t)length ? 0 : -1;
}

// Read authoritative kernel state every poll: ffs_closed can unregister the
// gadget during a daemon restart even if ready=0->1 occurs between polls.
static int ReadController(char *controller, size_t size)
{
    int fd = open(GADGET "/UDC", O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    ssize_t length = read(fd, controller, size - 1);
    int savedError = errno;
    close(fd);
    if (length < 0) {
        errno = savedError;
        return -1;
    }
    if ((size_t)length == size - 1) {
        errno = EOVERFLOW;
        return -1;
    }
    controller[length] = '\0';
    controller[strcspn(controller, "\r\n")] = '\0';
    return 0;
}

// Return -2 for an unexpected owner, -1 for retryable I/O, 0 for reconciled.
static int ReconcileController(const char *expected, int ready, int *bound)
{
    char actual[256];
    if (ReadController(actual, sizeof(actual)) != 0) {
        return -1;
    }
    if (actual[0] && strcmp(actual, expected) != 0) {
        fprintf(stderr, "beyond2lte USB: unexpected bound UDC %s; refusing change\n", actual);
        return -2;
    }
    *bound = actual[0] != '\0';
    if (ready == *bound) {
        return 0;
    }
    if (WriteController(ready ? expected : "") != 0) {
        return -1;
    }
    if (ReadController(actual, sizeof(actual)) != 0) {
        return -1;
    }
    if (actual[0] && strcmp(actual, expected) != 0) {
        fprintf(stderr, "beyond2lte USB: UDC changed owner during bind; refusing change\n");
        return -2;
    }
    *bound = actual[0] != '\0';
    if (*bound != ready) {
        errno = EAGAIN;
        return -1;
    }
    return 0;
}

static int ParameterEquals(const char *key, const char *expected)
{
    char value[128] = {0};
    return GetParameter(key, "", value, sizeof(value)) > 0 && strcmp(value, expected) == 0;
}

int main(int argc, char **argv)
{
    char controller[256] = {0};
    if (argc == 2 && strcmp(argv[1], "--detect-only") == 0) {
        int found = FindController(controller, sizeof(controller));
        if (found == 1) {
            puts(controller);
            return 0;
        }
        return found < 0 ? 2 : 1;
    }
    if (argc != 1) {
        return 2;
    }
    struct statfs fs;
    if (statfs("/dev/usb-ffs/hdc", &fs) != 0 || (unsigned long)fs.f_type != FUNCTIONFS_MAGIC ||
        access(GADGET "/UDC", W_OK) != 0 || access(GADGET "/configs/b.1/f1", F_OK) != 0) {
        fputs("beyond2lte USB: configfs/FunctionFS setup incomplete\n", stderr);
        return 1;
    }
    int found = 0;
    for (int attempt = 0; attempt < 30; ++attempt) {
        found = FindController(controller, sizeof(controller));
        if (found != 0) {
            break;
        }
        sleep(1);
    }
    if (found != 1) {
        fputs("beyond2lte USB: no unique registered UDC; refusing bind\n", stderr);
        return 1;
    }
    if (SetParameter("sys.beyond2lte.usb.controller", controller) != 0 ||
        SetParameter("sys.beyond2lte.usb.prepared", "1") != 0) {
        fputs("beyond2lte USB: failed to publish setup parameters\n", stderr);
        return 1;
    }
    int publishedBound = -1;
    int previousError = 0;
    for (;;) {
        int ready = ParameterEquals("persist.hdc.mode.usb", "enable") &&
                    ParameterEquals("sys.usb.ffs.ready.hdc", "1");
        int bound = 0;
        int result = ReconcileController(controller, ready, &bound);
        if (result == -2) {
            return 1;
        }
        if (result == -1) {
            int error = errno;
            if (error != previousError) {
                fprintf(stderr, "beyond2lte USB: UDC reconciliation failed: %s (errno=%d)\n",
                        strerror(error), error);
                previousError = error;
            }
        } else {
            previousError = 0;
            if (bound != publishedBound &&
                SetParameter("sys.beyond2lte.usb.bound", bound ? "1" : "0") == 0) {
                publishedBound = bound;
            }
        }
        sleep(1);
    }
}
