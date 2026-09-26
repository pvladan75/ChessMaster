"""Read a Windows minidump of the app and name the function it died in.

Phase 3 of docs/PLAN-FORENZIKA-PADA.md. Written from the two scripts that read
the crash of 26.9.2026 in the hour after it happened, so that the next crash
is read in minutes by anyone:

    python tools/crashdump/read_dump.py              # newest Mislisha.exe.*.dmp
    python tools/crashdump/read_dump.py some.dmp
    python tools/crashdump/read_dump.py --self-test  # the gate; exits 0

It prints the exception, the faulting module and offset, the registers, and
the faulting thread's stack as return-address candidates, each resolved to a
function name where the module is the Flutter engine.

Names come from the engine the Flutter SDK on PATH ships
(`bin/cache/artifacts/engine/windows-x64-release/flutter_windows.dll` and its
`.pdb`). **A name read from the wrong engine is a confident lie**, so the tool
compares the DLL's PE timestamp and image size with the module recorded in the
dump and refuses to name anything when they differ — the SDK is upgraded more
often than the installed app is rebuilt.

The names are the labels `dumpbin /disasm` prints with the PDB beside the DLL
(`dumpbin` from the newest Visual Studio Build Tools, found by `vswhere`). That
takes minutes and 200 MB of text, so it runs once per engine and keeps only
the labels, under %TEMP%, keyed by the timestamp and size. Mangled names are
made readable with `undname` from the same directory when it is there.

The stack is scanned, not unwound: every word on the faulting thread's stack
from Rsp upward that points into a module is printed. Most of them are real
return addresses; some are stale. Read it as evidence, not as a call chain.

Python 3.8+, no dependencies.
"""

from __future__ import annotations

import bisect
import glob
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ENGINE = "flutter_windows.dll"
IMAGE_BASE = 0x180000000  # the engine's preferred base; dumpbin prints VAs
# Past this far into a label, an address is in the data after the last
# function rather than in the function: the engine's largest function is well
# under it, and its data sections follow its code.
FAR = 0x20000

EXCEPTIONS = {
    0xC0000005: "ACCESS_VIOLATION",
    0xC0000409: "STACK_BUFFER_OVERRUN (fail-fast)",
    0xC00000FD: "STACK_OVERFLOW",
    0xC0000374: "HEAP_CORRUPTION",
    0x80000003: "BREAKPOINT",
    0xE06D7363: "C++ exception",
}

REGS = "Rax Rcx Rdx Rbx Rsp Rbp Rsi Rdi R8 R9 R10 R11 R12 R13 R14 R15".split()


# --------------------------------------------------------------------------
# The minidump
# --------------------------------------------------------------------------


class DumpError(Exception):
    pass


def parse_minidump(data: bytes) -> dict:
    """The parts of a minidump this tool reads, as plain values."""
    if len(data) < 32 or data[:4] != b"MDMP":
        raise DumpError("not a minidump (no MDMP signature)")
    _, _, nstreams, dir_rva, _, ts, flags = struct.unpack_from("<4sIIIIIQ", data, 0)
    streams: dict[int, tuple[int, int]] = {}
    for i in range(nstreams):
        stype, dsize, drva = struct.unpack_from("<III", data, dir_rva + 12 * i)
        streams.setdefault(stype, (drva, dsize))

    def md_string(rva: int) -> str:
        (n,) = struct.unpack_from("<I", data, rva)
        return data[rva + 4 : rva + 4 + n].decode("utf-16-le", "replace")

    modules = []
    if 4 in streams:
        mrva, _ = streams[4]
        (nmod,) = struct.unpack_from("<I", data, mrva)
        for i in range(nmod):
            base, size, _, tstamp, name_rva = struct.unpack_from(
                "<QIIII", data, mrva + 4 + 108 * i
            )
            modules.append(
                {"base": base, "size": size, "timestamp": tstamp, "path": md_string(name_rva)}
            )

    ranges = []
    if 5 in streams:
        rva, _ = streams[5]
        (n,) = struct.unpack_from("<I", data, rva)
        for i in range(n):
            start, dsize, drva = struct.unpack_from("<QII", data, rva + 4 + 16 * i)
            ranges.append((start, dsize, drva))
    if 9 in streams:
        rva, _ = streams[9]
        n, cur = struct.unpack_from("<QQ", data, rva)
        for i in range(n):
            start, dsize = struct.unpack_from("<QQ", data, rva + 16 + 16 * i)
            ranges.append((start, dsize, cur))
            cur += dsize

    if 6 not in streams:
        raise DumpError("the dump carries no exception stream")
    erva, _ = streams[6]
    tid, _, code, _, _, addr, nparams = struct.unpack_from("<IIIIQQI", data, erva)
    params = struct.unpack_from("<15Q", data, erva + 40)[: min(nparams, 15)]
    ctx_size, ctx_rva = struct.unpack_from("<II", data, erva + 8 + 152)
    regs = dict(zip(REGS, struct.unpack_from("<16Q", data, ctx_rva + 0x78)))
    (regs["Rip"],) = struct.unpack_from("<Q", data, ctx_rva + 0xF8)

    stack = None
    thread_count = 0
    if 3 in streams:
        trva, _ = streams[3]
        (thread_count,) = struct.unpack_from("<I", data, trva)
        for i in range(thread_count):
            t_id, _, _, _, _, s_start, s_size, s_rva = struct.unpack_from(
                "<IIIIQQII", data, trva + 4 + 48 * i
            )
            if t_id == tid:
                stack = (s_start, s_size, s_rva)
                break

    return {
        "timestamp": ts,
        "flags": flags,
        "modules": modules,
        "ranges": ranges,
        "exception": {"thread": tid, "code": code, "address": addr, "params": list(params)},
        "registers": regs,
        "stack": stack,
        "thread_count": thread_count,
        "data": data,
    }


def module_of(dump: dict, addr: int):
    for m in dump["modules"]:
        if m["base"] <= addr < m["base"] + m["size"]:
            return m, addr - m["base"]
    return None, None


def short(path: str) -> str:
    return re.split(r"[\\/]", path)[-1]


def stack_candidates(dump: dict, limit: int = 200):
    """(offset from Rsp, value, module, rva) for every word on the faulting
    thread's stack that points into a module."""
    if not dump["stack"]:
        return []
    s_start, s_size, s_rva = dump["stack"]
    rsp = dump["registers"]["Rsp"]
    lo = max(rsp, s_start)
    out = []
    for a in range(lo, s_start + s_size - 7, 8):
        (v,) = struct.unpack_from("<Q", dump["data"], s_rva + (a - s_start))
        m, rva = module_of(dump, v)
        if m:
            out.append((a - rsp, v, m, rva))
            if len(out) >= limit:
                break
    return out


# --------------------------------------------------------------------------
# The engine on PATH, and its names
# --------------------------------------------------------------------------


def pe_identity(path: str):
    """(TimeDateStamp, SizeOfImage) of a PE file — what a minidump's module
    list records, so the two can be compared."""
    with open(path, "rb") as f:
        head = f.read(4096)
    (lfanew,) = struct.unpack_from("<I", head, 0x3C)
    if head[lfanew : lfanew + 4] != b"PE\0\0":
        raise DumpError("%s is not a PE file" % path)
    (ts,) = struct.unpack_from("<I", head, lfanew + 8)
    (size_of_image,) = struct.unpack_from("<I", head, lfanew + 24 + 56)
    return ts, size_of_image


def sdk_engine() -> str | None:
    flutter = shutil.which("flutter")
    if not flutter:
        return None
    root = os.path.dirname(os.path.dirname(os.path.realpath(flutter)))
    dll = os.path.join(
        root, "bin", "cache", "artifacts", "engine", "windows-x64-release", ENGINE
    )
    return dll if os.path.exists(dll) else None


def find_msvc_tool(name: str) -> str | None:
    vswhere = os.path.join(
        os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
        "Microsoft Visual Studio", "Installer", "vswhere.exe",
    )
    if not os.path.exists(vswhere):
        return shutil.which(name)
    try:
        out = subprocess.run(
            [vswhere, "-latest", "-products", "*", "-find",
             "VC/Tools/MSVC/**/bin/Hostx64/x64/" + name],
            capture_output=True, text=True, timeout=60,
        ).stdout.splitlines()  # one path a line; the paths hold spaces
    except (OSError, subprocess.SubprocessError):
        out = []
    return out[-1] if out else shutil.which(name)


LABEL = re.compile(r"\s+([0-9A-Fa-f]{16}):")


def parse_labels(lines) -> list[tuple[int, str]]:
    """(rva, name) for every function label in `dumpbin /disasm` output: a
    line that starts in column 0 and ends in `:`, named at the address of the
    first instruction under it."""
    labels = []
    pending = None
    for line in lines:
        if line and line[0] not in " \t\r\n":
            pending = line.rstrip().rstrip(":") if line.rstrip().endswith(":") else None
        elif pending is not None:
            m = LABEL.match(line)
            if m:
                labels.append((int(m.group(1), 16) - IMAGE_BASE, pending))
                pending = None
    labels.sort()
    return labels


def label_cache_path(ts: int, size: int) -> str:
    return os.path.join(
        tempfile.gettempdir(), "crashdump-labels-%s-%08x-%08x.txt" % (ENGINE, ts, size)
    )


def load_labels(dll: str, ts: int, size: int, out=sys.stdout):
    cache = label_cache_path(ts, size)
    if os.path.exists(cache):
        labels = []
        with open(cache, encoding="utf-8") as f:
            for line in f:
                rva, name = line.rstrip("\n").split(" ", 1)
                labels.append((int(rva, 16), name))
        return labels
    dumpbin = find_msvc_tool("dumpbin.exe")
    if not dumpbin:
        print("  (no dumpbin: install Visual Studio Build Tools to name functions)", file=out)
        return None
    print("  disassembling %s once for its labels (a few minutes)..." % ENGINE, file=out)
    out.flush()
    try:
        proc = subprocess.Popen(
            [dumpbin, "/nologo", "/disasm", dll],
            stdout=subprocess.PIPE, text=True, errors="replace",
        )
    except OSError as e:
        print("  (dumpbin did not start: %s)" % e, file=out)
        return None
    labels = parse_labels(proc.stdout)
    proc.wait()
    if not labels:
        print("  (dumpbin printed no labels — is the .pdb beside the DLL?)", file=out)
        return None
    tmp = cache + ".part"
    with open(tmp, "w", encoding="utf-8") as f:
        for rva, name in labels:
            f.write("%x %s\n" % (rva, name))
    os.replace(tmp, cache)
    return labels


def resolve(labels, rva: int):
    """The label an rva falls under, and the offset into it."""
    i = bisect.bisect_right(labels, (rva, "\uffff")) - 1
    if i < 0:
        return None, None
    return labels[i][1], rva - labels[i][0]


def demangle(names, out=sys.stdout) -> dict[str, str]:
    undname = find_msvc_tool("undname.exe")
    result = {n: n for n in names}
    if not undname:
        return result
    for n in names:
        if not n.startswith("?"):
            continue
        try:
            text = subprocess.run(
                [undname, "0x1000", n], capture_output=True, text=True, timeout=30
            ).stdout
        except (OSError, subprocess.SubprocessError):
            continue
        m = re.search(r'is :- "(.*)"', text)
        if m:
            result[n] = m.group(1)
    return result


# --------------------------------------------------------------------------
# The report
# --------------------------------------------------------------------------


def report(path: str, out=sys.stdout, labels_for=None) -> dict:
    """Print what the dump says. `labels_for(module)` returns the engine's
    labels or None; the default reads the SDK on PATH."""
    with open(path, "rb") as f:
        dump = parse_minidump(f.read())
    exc = dump["exception"]
    regs = dump["registers"]
    print("dump      %s" % path, file=out)
    print("exception 0x%08x %s on thread %d" % (
        exc["code"], EXCEPTIONS.get(exc["code"], ""), exc["thread"]), file=out)
    if exc["code"] == 0xC0000005 and len(exc["params"]) >= 2:
        kind = {0: "read", 1: "write", 8: "execute"}.get(exc["params"][0], exc["params"][0])
        print("          %s of address 0x%x" % (kind, exc["params"][1]), file=out)
    m, rva = module_of(dump, exc["address"])
    print("at        %s+0x%x" % (short(m["path"]), rva) if m else
          "at        0x%x (no module)" % exc["address"], file=out)

    engine = next((mm for mm in dump["modules"] if short(mm["path"]).lower() == ENGINE), None)
    labels = None
    if engine is not None:
        labels = (labels_for or _sdk_labels)(engine, out)

    def name(addr: int) -> str:
        mm, r = module_of(dump, addr)
        if not mm:
            return ""
        s = "%s+0x%x" % (short(mm["path"]), r)
        if labels and mm is engine:
            fn, off = resolve(labels, r)
            if fn and off < FAR:
                s += "  %s+0x%x" % (fn, off)
            elif fn:
                s += "  (not code: data, or a stale word)"
        return s

    print("registers", file=out)
    for r in REGS + ["Rip"]:
        v = regs[r]
        print("  %-3s = 0x%016x  %s" % (r, v, name(v)), file=out)

    cands = stack_candidates(dump)
    print("stack of thread %d, return-address candidates from Rsp up (%d)" % (
        exc["thread"], len(cands)), file=out)
    fault = name(exc["address"])
    resolved = [fault] + [name(v) for _, v, _, _ in cands]
    named = re.compile(r"^(\S+)  (\S+)\+(0x[0-9a-f]+)$")
    if labels:
        mangled = sorted({m.group(2) for m in map(named.match, resolved) if m})
        pretty = demangle(mangled, out)
    else:
        pretty = {}

    def show(s: str) -> str:
        m = named.match(s)
        if not m:
            return s
        return "%s  %s+%s" % (m.group(1), pretty.get(m.group(2), m.group(2)), m.group(3))

    print("  [fault]      %s" % show(fault), file=out)
    for (off, _, _, _), s in zip(cands, resolved[1:]):
        print("  [rsp+0x%04x] %s" % (off, show(s)), file=out)
    return {"dump": dump, "fault": show(fault)}


def _sdk_labels(engine: dict, out):
    dll = sdk_engine()
    if not dll:
        print("names     none: no Flutter SDK on PATH", file=out)
        return None
    ts, size = pe_identity(dll)
    if (ts, size) != (engine["timestamp"], engine["size"]):
        print("names     REFUSED: the dump's engine is 0x%08x/0x%x, the SDK's is "
              "0x%08x/0x%x (%s). Names from another engine would be wrong; "
              "check out the Flutter version the app was built with." % (
                  engine["timestamp"], engine["size"], ts, size, dll), file=out)
        return None
    print("names     from %s (engine 0x%08x matches)" % (dll, ts), file=out)
    return load_labels(dll, ts, size, out)


def newest_dump() -> str | None:
    folder = os.path.join(os.environ.get("LOCALAPPDATA", ""), "CrashDumps")
    dumps = glob.glob(os.path.join(folder, "Mislisha.exe*.dmp"))
    return max(dumps, key=os.path.getmtime) if dumps else None


# --------------------------------------------------------------------------
# The gate
# --------------------------------------------------------------------------


def _synthetic_dump(engine_ts: int, engine_size: int) -> bytes:
    """A minidump with two modules, one thread whose stack holds a return
    address into the engine and one word pointing nowhere, and an access
    violation inside the engine."""
    exe_base, dll_base = 0x7FF700000000, 0x7FFA00000000
    fault = dll_base + 0x3CF3A
    ret = dll_base + 0x1234
    # The stack as captured starts one word below Rsp, and that word points
    # into the engine too: it is below the frame and must not be read.
    rsp = 0x10000
    stack = struct.pack(
        "<6Q", dll_base + 0x999, 0xDEAD, ret, 0, exe_base + 0x40, dll_base + 0x80000)
    names = ["C:\\app\\Mislisha.exe", "C:\\app\\" + ENGINE]

    out = bytearray(32 + 12 * 4)  # header, directory of four streams
    directory = []

    def put(b: bytes) -> int:
        rva = len(out)
        out.extend(b)
        return rva

    name_rvas = [put(struct.pack("<I", len(n) * 2) + n.encode("utf-16-le")) for n in names]
    mods = struct.pack("<I", 2)
    for base, size, ts, nrva in ((exe_base, 0x100000, 0x11111111, name_rvas[0]),
                                 (dll_base, engine_size, engine_ts, name_rvas[1])):
        mods += struct.pack("<QIIII", base, size, 0, ts, nrva) + bytes(108 - 24)
    directory.append((4, len(mods), put(mods)))

    stack_rva = put(stack)
    context = bytearray(0x4D0)
    struct.pack_into("<Q", context, 0x78 + 8 * REGS.index("Rsp"), rsp)
    struct.pack_into("<Q", context, 0x78 + 8 * REGS.index("Rcx"), dll_base + 0x10)
    struct.pack_into("<Q", context, 0xF8, fault)
    ctx_rva = put(bytes(context))
    threads = struct.pack("<I", 1) + struct.pack(
        "<IIIIQQIIII", 77, 0, 0, 0, 0, rsp - 8, len(stack), stack_rva, len(context), ctx_rva)
    directory.append((3, len(threads), put(threads)))

    memory = struct.pack("<I", 1) + struct.pack("<QII", rsp - 8, len(stack), stack_rva)
    directory.append((5, len(memory), put(memory)))

    exc = struct.pack("<IIIIQQII", 77, 0, 0xC0000005, 0, 0, fault, 2, 0)
    exc += struct.pack("<15Q", 0, 0x28, *([0] * 13))
    exc += struct.pack("<II", len(context), ctx_rva)
    directory.append((6, len(exc), put(exc)))

    struct.pack_into("<4sIIIIIQ", out, 0, b"MDMP", 0xA793, len(directory), 32, 0, 0x66F5A000, 0)
    for i, (t, size, rva) in enumerate(directory):
        struct.pack_into("<III", out, 32 + 12 * i, t, size, rva)
    return bytes(out)


def _synthetic_pe(ts: int, size: int) -> bytes:
    head = bytearray(1024)
    head[:2] = b"MZ"
    struct.pack_into("<I", head, 0x3C, 0x80)
    head[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<I", head, 0x80 + 8, ts)
    struct.pack_into("<I", head, 0x80 + 24 + 56, size)
    return bytes(head)


def self_test() -> int:
    import io

    failures = []

    def check(what, cond):
        if not cond:
            failures.append(what)

    ts, size = 0x6A0B1C2D, 0x1500000
    data = _synthetic_dump(ts, size)
    dump = parse_minidump(data)
    check("two modules", [short(m["path"]) for m in dump["modules"]] == ["Mislisha.exe", ENGINE])
    check("the engine's timestamp is read", dump["modules"][1]["timestamp"] == ts)
    check("access violation", dump["exception"]["code"] == 0xC0000005)
    check("read of 0x28", dump["exception"]["params"] == [0, 0x28])
    m, rva = module_of(dump, dump["exception"]["address"])
    check("fault at engine+0x3cf3a", m is dump["modules"][1] and rva == 0x3CF3A)
    check("Rip from the context", dump["registers"]["Rip"] == dump["exception"]["address"])
    cands = stack_candidates(dump)
    check("two words on the stack point into modules",
          [(off, short(mm["path"]), r) for off, _, mm, r in cands]
          == [(8, ENGINE, 0x1234), (24, "Mislisha.exe", 0x40), (32, ENGINE, 0x80000)])

    labels = parse_labels([
        "?Other@@YAXXZ:\n",
        "  0000000180001000: push        rsi\n",
        "  0000000180001001: ret\n",
        "?SetRoleFromFlutterUpdate@AccessibilityBridge@flutter@@AEAAXAEAUAXNodeData@ui@@AEBUSemanticsNode@12@@Z:\n",
        "  000000018003C000: push        rbx\n",
        "  000000018003CF3A: mov         eax,dword ptr [rcx+28h]\n",
        "Summary\n",
        "\n",
        "        1000 .data\n",
    ])
    check("labels read from dumpbin", [r for r, _ in labels] == [0x1000, 0x3C000])
    fn, off = resolve(labels, 0x3CF3A)
    check("the fault names its function",
          fn is not None and fn.startswith("?SetRoleFromFlutterUpdate") and off == 0xF3A)
    check("an address before every label names nothing", resolve(labels, 0x10) == (None, None))

    with tempfile.TemporaryDirectory() as d:
        pe = os.path.join(d, ENGINE)
        with open(pe, "wb") as f:
            f.write(_synthetic_pe(ts, size))
        check("PE identity read", pe_identity(pe) == (ts, size))
        dmp = os.path.join(d, "Mislisha.exe.1.dmp")
        with open(dmp, "wb") as f:
            f.write(data)

        buf = io.StringIO()
        report(dmp, buf, labels_for=lambda engine, out: labels)
        text = buf.getvalue()
        check("the report names the function at the fault",
              re.search(r"\[fault\].*SetRoleFromFlutterUpdate.*\+0xf3a", text) is not None)
        check("the report names the access", "read of address 0x28" in text)
        check("a word far past every function is not named as one",
              re.search(r"\[rsp\+0x0020\].*not code", text) is not None)

        # The refusal: an SDK whose engine is not the dump's names nothing.
        other = os.path.join(d, "other", ENGINE)
        os.makedirs(os.path.dirname(other))
        with open(other, "wb") as f:
            f.write(_synthetic_pe(ts + 1, size))
        # `load_labels` answers the test's labels, so a refusal that went
        # missing shows as a name rather than as a dumpbin run on a fake DLL.
        global sdk_engine, load_labels
        saved = sdk_engine, load_labels
        sdk_engine = lambda: other  # noqa: E731
        load_labels = lambda dll, ts, size, out: labels  # noqa: E731
        try:
            buf = io.StringIO()
            report(dmp, buf)
            text = buf.getvalue()
        finally:
            sdk_engine, load_labels = saved
        check("another engine is refused", "REFUSED" in text)
        check("and names nothing", "SetRoleFromFlutterUpdate" not in text)

    try:
        parse_minidump(b"not a dump" * 10)
        check("a file that is not a dump is refused", False)
    except DumpError:
        pass

    for f in failures:
        print("FAIL  " + f)
    print("self-test: %d failure(s)" % len(failures))
    return 1 if failures else 0


def main(argv) -> int:
    if argv[1:] == ["--self-test"]:
        return self_test()
    path = argv[1] if len(argv) > 1 else newest_dump()
    if not path:
        print("no dump given and none in %LOCALAPPDATA%\\CrashDumps")
        return 2
    try:
        report(path)
    except DumpError as e:
        print("error: %s" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
