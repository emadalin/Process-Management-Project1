#!/usr/bin/env python3
"""Keep the demo prep line references honest.

Each presenter page quotes code with its line numbers baked in, like:

    **[`VendingMachine.swift`](../../Sources/ThreadLab/VendingMachine.swift#L75-L82) · lines 75–82**

    ```swift
    /*  75 */     func buyOneUnsafe() -> Bool {
    ...

Editing the Swift files — even just adding a comment — shifts every one of
those numbers, and the links then scroll to the wrong place mid-demo.

    python3 "demo help/check-refs.py"          # check; exit 1 if anything is stale
    python3 "demo help/check-refs.py" --fix    # relocate the references, then check

--fix finds each quoted line by its CODE (ignoring trailing comments and
indentation), so it survives renumbering. It rewrites the line numbers, the
#L anchors, the "· lines N–M" text and the inline "line N" callouts in the
prose, and adds an elision note to any block that skips lines.

A quoted line whose text no longer exists in the source cannot be relocated
automatically — usually the line was reworded or split. Those are reported
by file and line for a human to fix.

Run it after touching anything in Sources/ThreadLab or Package.swift.
"""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "demo help")
NOTE = "*(Comments elided for space — the line numbers above are exact.)*"

# ](../../Sources/ThreadLab/Foo.swift#L12-L34)  or  ](../../Package.swift#L1-L13)
ANCHOR = re.compile(r'\((?:\.\./\.\./)?(?:Sources/ThreadLab/)?(\w+\.swift)#L(\d+)-L(\d+)\)')
QUOTED = re.compile(r'^/\*\s*(\d+)\s*\*/ ?(.*)$')

_cache = {}


def source(name):
    """Lines of a source file, by bare filename."""
    if name not in _cache:
        rel = name if name == "Package.swift" else os.path.join("Sources", "ThreadLab", name)
        with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
            _cache[name] = fh.read().split("\n")
    return _cache[name]


def key(text):
    """Comparable form of a line: no trailing comment, no indentation."""
    return re.sub(r'\s+', ' ', re.sub(r'\s+//.*$', '', text)).strip()


def pages():
    for path in sorted(glob.glob(os.path.join(DOCS, "*.md"))):
        if os.path.basename(path) not in ("README.md",):
            yield path


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().split("\n")


def write(path, lines):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def blocks(lines):
    """Yield (anchor_index, [indices of quoted lines]) for each code block."""
    anchor, quoted = None, []
    for i, line in enumerate(lines):
        if ANCHOR.search(line):
            if anchor is not None:
                yield anchor, quoted
            anchor, quoted = i, []
        elif QUOTED.match(line) and anchor is not None:
            quoted.append(i)
    if anchor is not None:
        yield anchor, quoted


def check(path):
    """Report stale references. Returns a list of problem strings."""
    problems = []
    lines = read(path)
    rel = os.path.relpath(path, ROOT)
    for ai, idxs in blocks(lines):
        m = ANCHOR.search(lines[ai])
        name, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
        text = re.search(r'·\s*lines\s*(\d+)[–-](\d+)', lines[ai])
        if text and (int(text.group(1)), int(text.group(2))) != (lo, hi):
            problems.append(f"{rel}:{ai+1}: anchor #L{lo}-L{hi} disagrees with its 'lines' text")
        src = source(name)
        for di in idxs:
            q = QUOTED.match(lines[di])
            n, code = int(q.group(1)), q.group(2)
            actual = src[n - 1] if 0 < n <= len(src) else "<past end of file>"
            if actual.rstrip() != code.rstrip():
                problems.append(f"{rel}:{di+1}: quotes {name}:{n}, which now reads:\n"
                                f"      want: {code.rstrip()}\n"
                                f"      got:  {actual.rstrip()}")
            elif not lo <= n <= hi:
                problems.append(f"{rel}:{di+1}: line {n} falls outside its anchor L{lo}-L{hi}")
    return problems


def fix(path):
    """Relocate references by content. Returns (moved, unmatched)."""
    lines = read(path)
    rel = os.path.relpath(path, ROOT)
    moved, unmatched, mapping = 0, [], {}

    for ai, idxs in blocks(lines):
        if not idxs:
            continue
        name = ANCHOR.search(lines[ai]).group(1)
        src = source(name)
        cursor, found = 0, []
        for di in idxs:
            q = QUOTED.match(lines[di])
            old, code = int(q.group(1)), q.group(2)
            want = key(code)
            # Search forward only: keeps repeated lines (like "}") in order.
            hit = next((n for n in range(cursor, len(src)) if key(src[n]) == want), None)
            if hit is None:
                unmatched.append(f"{rel}:{di+1}: no line in {name} matches {code.strip()!r}")
                continue
            cursor = hit + 1
            new = hit + 1
            mapping.setdefault(old, new)
            if lines[di] != "/* %3d */ %s" % (new, src[hit]):
                moved += 1
            lines[di] = "/* %3d */ %s" % (new, src[hit])
            found.append(new)
        if found:
            lo, hi = min(found), max(found)
            lines[ai] = ANCHOR.sub(
                lambda m: m.group(0).replace("#L%s-L%s)" % (m.group(2), m.group(3)),
                                             "#L%d-L%d)" % (lo, hi)), lines[ai])
            lines[ai] = re.sub(r'·\s*lines\s*\d+[–-]\d+', '· lines %d–%d' % (lo, hi), lines[ai])

    # Inline "line 83" / "lines 97 to 100" / "lines 178 and 172" in the prose.
    def renumber(m):
        head, first, joiner, second = m.groups()
        out = head + str(mapping.get(int(first), int(first)))
        if second:
            out += joiner + str(mapping.get(int(second), int(second)))
        return out

    for i, line in enumerate(lines):
        if QUOTED.match(line) or ".swift#L" in line:
            continue
        lines[i] = re.sub(r'\b([Ll]ines?\s+)(\d+)((?:\s+(?:to|and)\s+))?(\d+)?', renumber, line)

    lines = add_elision_notes(lines)
    write(path, lines)
    return moved, unmatched


def add_elision_notes(lines):
    """Mark blocks whose shown line numbers have gaps."""
    out, i = [], 0
    while i < len(lines):
        out.append(lines[i])
        if lines[i].strip() == "```swift":
            nums, j = [], i + 1
            while j < len(lines) and lines[j].strip() != "```":
                m = QUOTED.match(lines[j])
                if m:
                    nums.append(int(m.group(1)))
                out.append(lines[j])
                j += 1
            if j < len(lines):
                out.append(lines[j])
                gapped = nums and (max(nums) - min(nums) + 1) != len(nums)
                if gapped and NOTE not in "\n".join(lines[j + 1:j + 3]):
                    out += ["", NOTE]
            i = j + 1
            continue
        i += 1
    return out


def main():
    doing_fix = "--fix" in sys.argv[1:]
    stragglers = []

    if doing_fix:
        for path in pages():
            moved, unmatched = fix(path)
            stragglers += unmatched
            print(f"{os.path.relpath(path, ROOT)}: {moved} reference(s) relocated")
        print()

    problems = []
    for path in pages():
        problems += check(path)

    if stragglers:
        print("Could not relocate automatically — the source line was reworded or split:")
        for s in stragglers:
            print("  " + s)
        print()

    if problems:
        print("Stale references:")
        for p in problems:
            print("  " + p)
        if not doing_fix:
            print("\nRun with --fix to relocate them.")
        return 1

    total = sum(len(idxs) for path in pages() for _, idxs in blocks(read(path)))
    print(f"OK — all {total} quoted lines match their source.")
    return 0 if not stragglers else 1


if __name__ == "__main__":
    sys.exit(main())
