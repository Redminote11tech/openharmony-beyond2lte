#!/usr/bin/env python3
"""Host tests with temp files/API stubs; never access or alter a real gadget."""
from pathlib import Path
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parents[1] / "beyond2lte_usb.c"
with tempfile.TemporaryDirectory(prefix="beyond2lte-usb-test-") as temporary:
    root = Path(temporary)
    (root / "udc").mkdir()
    (root / "gadget").mkdir()
    (root / "parameter.h").write_text(
        "int SetParameter(const char *, const char *);\n"
        "int GetParameter(const char *, const char *, char *, unsigned int);\n"
    )
    (root / "stub.c").write_text(
        "int SetParameter(const char *k,const char *v){(void)k;(void)v;return 0;}\n"
        "int GetParameter(const char *k,const char *d,char *v,unsigned int n)"
        "{(void)k;(void)d;(void)v;(void)n;return 0;}\n"
    )
    harness = r'''
#define main helper_main
#include "SOURCE_PATH"
#undef main
#include <assert.h>
#include <sys/stat.h>

static void Fixture(const char *value)
{
    FILE *f = fopen(GADGET "/UDC", "w");
    assert(f != NULL);
    assert(fputs(value, f) >= 0);
    assert(fclose(f) == 0);
}

int main(void)
{
    char actual[256];
    const char *expected = "10c00000.dwc3";
    int bound = -1;
    assert(FindController(actual, sizeof(actual)) == 0);
    assert(mkdir(BEYOND2LTE_UDC_DIR "/10c00000.dwc3", 0700) == 0);
    assert(FindController(actual, sizeof(actual)) == 1);
    assert(strcmp(actual, expected) == 0);
    assert(mkdir(BEYOND2LTE_UDC_DIR "/second", 0700) == 0);
    assert(FindController(actual, sizeof(actual)) == -1);

    // First endpoint-ready bind.
    Fixture("\n");
    assert(ReconcileController(expected, 1, &bound) == 0 && bound == 1);
    assert(ReadController(actual, sizeof(actual)) == 0 && strcmp(actual, expected) == 0);
    // Helper restart adopts the actual expected binding, without rewriting it.
    assert(ReconcileController(expected, 1, &bound) == 0 && bound == 1);
    // ffs_closed cleared UDC while ready=0->1 was missed between polls.
    Fixture("\n");
    assert(ReconcileController(expected, 1, &bound) == 0 && bound == 1);
    // Disabled/not-ready unbind, then endpoint-ready rebind.
    assert(ReconcileController(expected, 0, &bound) == 0 && bound == 0);
    assert(ReadController(actual, sizeof(actual)) == 0 && actual[0] == '\0');
    assert(ReconcileController(expected, 1, &bound) == 0 && bound == 1);
    // Unknown binding is never unbound or overwritten.
    Fixture("other-controller\n");
    assert(ReconcileController(expected, 1, &bound) == -2);
    assert(ReconcileController(expected, 0, &bound) == -2);
    assert(ReadController(actual, sizeof(actual)) == 0 && strcmp(actual, "other-controller") == 0);
    assert(unlink(GADGET "/UDC") == 0);
    assert(ReconcileController(expected, 1, &bound) == -1 && errno == ENOENT);
    puts("USB discovery/restart/reconnect/unbind/foreign-owner/error tests passed.");
    return 0;
}
'''.replace("SOURCE_PATH", str(SOURCE))
    (root / "harness.c").write_text(harness)
    subprocess.run([
        "cc", "-std=c11", "-D_GNU_SOURCE", "-Wall", "-Wextra", "-Werror",
        f'-DBEYOND2LTE_UDC_DIR="{root / "udc"}"',
        f'-DGADGET="{root / "gadget"}"', f"-I{root}",
        str(root / "harness.c"), str(root / "stub.c"), "-o", str(root / "test"),
    ], check=True)
    subprocess.run([str(root / "test")], check=True)
