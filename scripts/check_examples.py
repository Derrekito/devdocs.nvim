#!/usr/bin/env python
"""Check every fenced code example in the notes tree — the repo's unit tests
for documentation.

Each fence must at least compile (or parse, for interpreted languages):

  cpp/c   full programs (contain `int main`) compile standalone with
          -std=c++17 -Wall -Wextra; fragments are wrapped in a main() that
          carries the *cumulative context* of earlier fences in the same file
          (their top-level declarations and main bodies), so a fragment can
          use a `v` or `people` introduced by an earlier example. A fence
          tagged with a standard (```cpp c++20) compiles with that -std,
          so version-specific examples state their requirement and get
          checked against it.
  lua     loadfile() syntax check (luac/luajit/lua, whichever exists)
  python  compile() syntax check
  bash    bash -n
  text    ignored (expected-output fences)
  <lang> skip   an explicit opt-out, e.g. ```cpp skip

With --run, full cpp/c programs are also executed (5s timeout); when the next
fence in the file is a ```text fence within a few lines, stdout must match it.

Exit code 1 if anything fails.

Usage: check_examples.py [--notes DIR] [--docset NAME] [--run] [file.md ...]
"""

import argparse
import concurrent.futures
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

CPP_PRELUDE = [
    "algorithm", "array", "bitset", "cctype", "chrono", "cmath", "cstdint",
    "cstdio", "cstdlib", "cstring", "deque", "filesystem", "fstream",
    "functional", "iomanip", "iostream", "iterator", "limits", "list", "map",
    "memory", "numeric", "optional", "queue", "random", "set", "sstream",
    "stack", "stdexcept", "string", "string_view", "tuple", "type_traits",
    "unordered_map", "unordered_set", "utility", "variant", "vector",
]
C_PRELUDE = [
    "assert.h", "ctype.h", "errno.h", "limits.h", "math.h", "stdbool.h",
    "stddef.h", "stdint.h", "stdio.h", "stdlib.h", "string.h", "time.h",
]

FENCE_RE = re.compile(r"^```(\w*)\s*([\w+]*)\s*$")


class Fence:
    def __init__(self, lang, tag, lineno):
        self.lang, self.tag, self.lineno = lang or "text", tag, lineno
        self.lines = []

    @property
    def code(self):
        return "\n".join(self.lines) + "\n"


def parse_fences(path):
    fences, cur = [], None
    for i, line in enumerate(path.read_text().splitlines(), 1):
        if cur is not None:
            if line.startswith("```"):
                cur.end = i
                fences.append(cur)
                cur = None
            else:
                cur.lines.append(line)
        else:
            m = FENCE_RE.match(line)
            if m:
                cur = Fence(m.group(1), m.group(2), i)
    return fences


def hoist(code):
    """Split code into (includes/usings, rest) so fragment includes reach the
    top of the synthetic program."""
    top, rest = [], []
    for line in code.splitlines():
        if line.startswith("#include") or re.match(r"\s*using\s", line):
            top.append(line)
        else:
            rest.append(line)
    return top, rest


def split_program(code):
    """Split a full program into (pre-main top level, main body) by naive
    brace counting — good enough for reference snippets."""
    m = re.search(r"\bint\s+main\s*\([^)]*\)", code)
    if not m:
        return code, ""
    open_brace = code.find("{", m.end())
    if open_brace < 0:
        return code, ""
    depth, i = 0, open_brace
    while i < len(code):
        if code[i] == "{":
            depth += 1
        elif code[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return code[: m.start()], code[open_brace + 1 : i]


class Failure:
    def __init__(self, path, fence, message):
        self.path, self.fence, self.message = path, fence, message

    def __str__(self):
        msg = "\n".join("    " + l for l in self.message.strip().splitlines()[:12])
        return f"FAIL {self.path}:{self.fence.lineno} (```{self.fence.lang})\n{msg}"


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60, **kw)


def check_cpp_like(path, fences, lang, run_programs, expected_for):
    """Cumulative-context checking for one file's cpp or c fences."""
    if lang == "cpp":
        base, default_std = ["g++"], "c++17"
        prelude = [f"#include <{h}>" for h in CPP_PRELUDE]
        suffix = ".cpp"
    else:
        base, default_std = ["gcc"], "c11"
        prelude = [f"#include <{h}>" for h in C_PRELUDE]
        suffix = ".c"
    if shutil.which(base[0]) is None:
        return [], len([f for f in fences if f.lang == lang])

    failures = []
    ctx_top, ctx_body = [], []
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        for n, fence in enumerate(f for f in fences if f.lang == lang):
            # ```cpp c++20 pins the fence to that standard
            std = fence.tag if re.fullmatch(r"c\+\+\d+|c\d+", fence.tag or "") \
                else default_std
            compiler = base + [f"-std={std}", "-Wall", "-Wextra"]
            src = tmp / f"ex{n}{suffix}"
            full = re.search(r"\bint\s+main\s*\(", fence.code)
            if full:
                src.write_text(fence.code)
                r = run(compiler + ["-fsyntax-only", str(src)])
                if r.returncode != 0:
                    failures.append(Failure(path, fence, r.stderr))
                else:
                    if std == default_std:  # pinned fences don't feed context
                        pre, body = split_program(fence.code)
                        top, rest = hoist(pre)
                        ctx_top += top + rest
                        ctx_body += body.splitlines()
                    if run_programs:
                        exe = tmp / f"ex{n}.out"
                        r = run(compiler + [str(src), "-o", str(exe)])
                        if r.returncode != 0:
                            failures.append(Failure(path, fence, r.stderr))
                            continue
                        try:
                            r = subprocess.run([str(exe)], capture_output=True,
                                               text=True, timeout=5)
                        except subprocess.TimeoutExpired:
                            failures.append(Failure(path, fence, "timed out after 5s"))
                            continue
                        if r.returncode != 0:
                            failures.append(Failure(
                                path, fence, f"exit {r.returncode}\n{r.stderr}"))
                            continue
                        want = expected_for.get(id(fence))
                        if want is not None and r.stdout.rstrip() != want.rstrip():
                            failures.append(Failure(
                                path, fence,
                                f"output mismatch\n--- expected\n{want.rstrip()}"
                                f"\n--- got\n{r.stdout.rstrip()}"))
            else:
                top, rest = hoist(fence.code)
                # a fragment may (a) build on earlier examples' variables,
                # (b) redeclare them — prose "replaces" context — or (c) be
                # top-level code like a function definition; try each shape
                attempts = [
                    ("cumulative", prelude + ctx_top + top
                     + ["int main() {"] + ctx_body + rest + ["return 0; }"]),
                    ("standalone", prelude + ctx_top + top
                     + ["int main() {"] + rest + ["return 0; }"]),
                    ("toplevel", prelude + ctx_top + top + rest
                     + ["int main() { return 0; }"]),
                ]
                first_err = None
                for kind, lines in attempts:
                    src.write_text("\n".join(lines) + "\n")
                    r = run(compiler + ["-fsyntax-only", str(src)])
                    if r.returncode == 0:
                        # a fence pinned to a non-default standard must not
                        # feed the shared context — later default-std
                        # fragments would inherit code they can't compile
                        if std == default_std:
                            ctx_top += top
                            if kind == "cumulative":
                                ctx_body += rest
                            elif kind == "standalone":
                                ctx_body = list(rest)  # restarted context
                            else:
                                ctx_top += rest
                        break
                    first_err = first_err or r.stderr
                else:
                    failures.append(Failure(path, fence, first_err))
    return failures, 0


def syntax_cmd(lang, src):
    """Interpreter syntax-check command for one source file, or None if no
    suitable tool is installed."""
    if lang == "lua":
        if shutil.which("luac"):
            return ["luac", "-p", str(src)]
        for lua in ("luajit", "lua"):
            if shutil.which(lua):
                return [lua, "-e",
                        f'local f,e=loadfile("{src}") '
                        f"if not f then io.stderr:write(e) os.exit(1) end"]
        return None
    if lang == "python":
        if shutil.which("python"):
            return ["python", "-c",
                    f"compile(open('{src}').read(), '{src}', 'exec')"]
        return None
    if lang == "bash":
        if shutil.which("bash"):
            return ["bash", "-n", str(src)]
        return None
    return None


def check_file(path, run_programs):
    fences = parse_fences(path)
    # expected output: the next fence is ```text and starts within 6 lines
    expected_for = {}
    for a, b in zip(fences, fences[1:]):
        if a.lang not in ("text",) and b.lang == "text" and b.lineno - a.end <= 6:
            expected_for[id(a)] = b.code

    failures, checked, skipped = [], 0, 0
    runnable = [f for f in fences if f.lang != "text"]
    for fence in runnable:
        if fence.tag == "skip":
            skipped += 1
    runnable = [f for f in runnable if f.tag != "skip"]

    for lang in ("cpp", "c"):
        group = [f for f in runnable if f.lang == lang]
        if group:
            fails, skip = check_cpp_like(path, group, lang, run_programs, expected_for)
            failures += fails
            skipped += skip
            checked += len(group) - skip

    with tempfile.TemporaryDirectory() as tmp:
        for n, fence in enumerate(f for f in runnable if f.lang not in ("cpp", "c")):
            src = pathlib.Path(tmp) / f"ex{n}.{fence.lang}"
            src.write_text(fence.code)
            cmd = syntax_cmd(fence.lang, src)
            if cmd is None:
                skipped += 1  # cmake and friends: no cheap check
                continue
            checked += 1
            r = run(cmd)
            if r.returncode != 0:
                failures.append(Failure(path, fence, r.stderr or r.stdout))
    return failures, checked, skipped


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", type=pathlib.Path,
                    help="specific notes files (default: whole notes tree)")
    ap.add_argument("--notes", type=pathlib.Path,
                    default=pathlib.Path(__file__).resolve().parent.parent / "notes")
    ap.add_argument("--docset", help="only this docset subdirectory")
    ap.add_argument("--run", action="store_true",
                    help="also execute full programs and diff ```text output")
    args = ap.parse_args()

    files = args.files
    if not files:
        root = args.notes / args.docset if args.docset else args.notes
        files = sorted(p for p in root.rglob("*.md") if p.name != "README.md")
    if not files:
        print("no notes files found", file=sys.stderr)
        return 1

    failures, checked, skipped = [], 0, 0
    with concurrent.futures.ThreadPoolExecutor() as pool:
        for fails, c, s in pool.map(lambda p: check_file(p, args.run), files):
            failures += fails
            checked += c
            skipped += s

    for f in failures:
        print(f, file=sys.stderr)
    print(f"{checked} examples checked in {len(files)} files: "
          f"{len(failures)} failed, {skipped} skipped")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
