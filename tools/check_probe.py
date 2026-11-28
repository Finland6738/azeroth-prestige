"""Offline check of the throwaway probe addon (tools/probe/AzPr_Probe), run by tools/check_docs.py and in CI.

  1. The TOC declares exactly "## Interface: 16001" and the SavedVariable AzPr_ProbeDB.
  2. Every file the TOC lists exists (exact case: CI runs on Linux), none twice, and every .lua file of the folder is
     listed.
  3. The check registry (Checks.lua) has each of V1-V21 and L exactly once.
  4. The rules above behave as documented (a few fixed cases).

Usage: python -I -X utf8 tools/check_probe.py      (exit code 0 = all good, 1 = problems, listed one per line)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAME = "AzPr_Probe"
FOLDER = os.path.join(ROOT, "tools", "probe", NAME)
INTERFACE = "16001"
SAVED = "AzPr_ProbeDB"
IDS = [f"V{n}" for n in range(1, 22)] + ["L"]
ENTRY = re.compile(r'^\s*\{\s*"(V\d+|L)"\s*,', re.M)


def toc_problems(toc, files):
    """toc: the text of the TOC; files: the paths that exist in the probe folder, with forward slashes."""
    problems = []
    fields = re.findall(r"^##\s*([\w-]+)\s*:\s*(.*?)\s*$", toc, re.M)
    interface = [v for k, v in fields if k == "Interface"]
    if interface != [INTERFACE]:
        problems.append(f"the TOC must declare Interface {INTERFACE} once, found {interface}")
    if [v for k, v in fields if k == "SavedVariables"] != [SAVED]:
        problems.append(f"the TOC must declare SavedVariables: {SAVED}")
    listed = [line.strip().replace("\\", "/") for line in toc.splitlines()
              if line.strip() and not line.lstrip().startswith("#")]
    if not listed:
        problems.append("the TOC lists no file")
    for path in sorted(set(listed)):
        if path not in files:
            problems.append(f"the TOC lists a missing file: {path}")
        if listed.count(path) > 1:
            problems.append(f"the TOC lists a file twice: {path}")
    for path in sorted(files):
        if path.endswith(".lua") and path not in listed:
            problems.append(f"the TOC does not list {path}")
    return problems


def registry_problems(lua):
    ids = ENTRY.findall(lua)
    problems = [f"the check registry has {i} {ids.count(i)} times, expected once" for i in IDS if ids.count(i) != 1]
    problems += [f"the check registry has an unknown id: {i}" for i in sorted(set(ids) - set(IDS))]
    return problems


def self_cases():
    good = f"## Interface: {INTERFACE}\n## SavedVariables: {SAVED}\n\n# comment\nA.lua\n"
    registry = "\n".join(f'    {{ "{i}", "x" }},' for i in IDS)
    cases = [
        ("good TOC", toc_problems(good, {"A.lua", "x.toc"}), 0),
        ("wrong interface", toc_problems(good.replace(INTERFACE, "11507"), {"A.lua"}), 1),
        ("no saved variable", toc_problems(good.replace(SAVED, "Other"), {"A.lua"}), 1),
        ("wrong case", toc_problems(good, {"a.lua"}), 2),
        ("listed twice", toc_problems(good + "A.lua\n", {"A.lua"}), 1),
        ("not listed", toc_problems(good, {"A.lua", "B.lua"}), 1),
        ("good registry", registry_problems(registry), 0),
        ("missing and unknown id", registry_problems(registry.replace('"L"', '"V22"')), 2),
    ]
    return [f"self case '{label}' gave {len(got)} problem(s), expected {n}" for label, got, n in cases
            if len(got) != n]


def read(name):
    with open(os.path.join(FOLDER, name), encoding="utf-8") as f:
        return f.read()


def check(problems):
    found = [f"tools/check_probe.py: {p}" for p in self_cases()]
    files = set()
    for base, _, names in os.walk(FOLDER):
        files.update(os.path.relpath(os.path.join(base, n), FOLDER).replace(os.sep, "/") for n in names)
    for name, rule in ((NAME + ".toc", lambda text: toc_problems(text, files)), ("Checks.lua", registry_problems)):
        if name not in files:
            found.append(f"tools/probe/{NAME}/{name} is missing")
            continue
        found.extend(f"tools/probe/{NAME}/{name}: {p}" for p in rule(read(name)))
    problems.extend(found)


def main():
    problems = []
    check(problems)
    for p in problems:
        print(p)
    print(f"Probe check: {len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
