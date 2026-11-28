"""Offline check of the throwaway probe addon (tools/probe/AzPr_Probe), run by tools/check_docs.py and in CI.

  1. The TOC declares exactly "## Interface: 16001" and the SavedVariable AzPr_ProbeDB.
  2. Every file the TOC lists exists (exact case: CI runs on Linux), none twice, and every .lua file of the folder is
     listed.
  3. The check registry (Checks.lua) has each of V1-V21 and L exactly once.
  4. The load order: AzPr_Probe.lua first, Checks.lua second, then the Checks_<area>.lua files (they call
     Probe:Implement on registered checks); each of those files starts from the probe table (_G.AzPr_Probe).
  5. The checks of the steps done so far (IMPLEMENTED: M0.3, M0.4 and M0.5) have their code: Probe:Implement("<id>",
     ...) exactly once each, and no other check has any (the others stay stubs until their step).
  6. Addon messages use only the test prefix (from M0.5): in every Lua file of the probe, each call of
     SendAddonMessage, SendAddonMessageLogged or RegisterAddonMessagePrefix (direct, or as the function passed to
     Probe.Call / pcall) takes Probe.TEST_PREFIX, or a local PREFIX bound to it, as its prefix; and no file contains the
     real prefix of the addon.
  7. The rules above behave as documented (a few fixed cases).

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
# The checks that have their code, step by step (M0.3: V1, V19, V20, V21; M0.4: V2, V3, V12, V13; M0.5: V4, V5,
# V14). A step that implements a check adds it here.
IMPLEMENTED = ["V1", "V2", "V3", "V4", "V5", "V12", "V13", "V14", "V19", "V20", "V21"]
IMPLEMENT = re.compile(r'Implement\(\s*(?:"(\w+)"|(\w+))\s*,')
CONSTANT = re.compile(r'^local\s+(\w+)\s*=\s*"(V\d+|L)"\s*$', re.M)
GUARD = "_G.AzPr_Probe"
# The prefix argument of the addon-message calls: the first token after "SendAddonMessage(" or "SendAddonMessage,"
PREFIX_CALL = re.compile(r'\b(?:SendAddonMessage(?:Logged)?|RegisterAddonMessagePrefix)\s*[(,]\s*([^,\s)]+)')
PREFIX_LOCAL = re.compile(r'^local\s+PREFIX\s*=\s*Probe\.TEST_PREFIX\b', re.M)
REAL_PREFIX = "AZPRES"  # SPEC-06 section 12.1: the probe never sends or registers it


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


def order_problems(toc):
    """The core file first, the registry second, then only Checks_<area>.lua files."""
    listed = [line.strip().replace("\\", "/") for line in toc.splitlines()
              if line.strip() and not line.lstrip().startswith("#")]
    problems = []
    if listed[:2] != [NAME + ".lua", "Checks.lua"]:
        problems.append(f"the TOC must load {NAME}.lua first and Checks.lua second, found {listed[:2]}")
    problems += [f"the TOC lists {p} after the registry: only Checks_<area>.lua files may follow it"
                 for p in listed[2:] if not re.fullmatch(r"Checks_\w+\.lua", p)]
    return problems


def implemented_ids(lua):
    """The ids given to Probe:Implement in one file, literal ("V1") or through a local constant (local V19 = "V19")."""
    constants = dict(CONSTANT.findall(lua))
    ids = []
    for literal, name in IMPLEMENT.findall(lua):
        ids.append(literal or constants.get(name, f"<unknown constant {name}>"))
    return ids


def implement_problems(sources, implemented=None):
    """sources: {file name: text} of the Checks_<area>.lua files; implemented: the ids that must have code (by default
    IMPLEMENTED)."""
    implemented = IMPLEMENTED if implemented is None else implemented
    problems = [f"{name} does not start from the probe table ({GUARD})" for name, text in sorted(sources.items())
                if GUARD not in text]
    ids = [i for text in sources.values() for i in implemented_ids(text)]
    problems += [f"check {i} has Probe:Implement {ids.count(i)} times, expected once" for i in implemented
                 if ids.count(i) != 1]
    problems += [f"check {i} has code but is not in IMPLEMENTED" for i in sorted(set(ids) - set(implemented))]
    return problems


def prefix_problems(sources):
    """sources: {file name: text} of every Lua file of the probe."""
    problems = []
    for name, text in sorted(sources.items()):
        code = re.sub(r"--[^\n]*", "", text)  # comments may name the calls freely
        for arg in PREFIX_CALL.findall(code):
            if arg == "Probe.TEST_PREFIX" or (arg == "PREFIX" and PREFIX_LOCAL.search(code)):
                continue
            problems.append(f"{name} sends or registers an addon prefix other than the test prefix ({arg})")
        if REAL_PREFIX in text:
            problems.append(f"{name} contains the real prefix of the addon ({REAL_PREFIX})")
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
        ("good order", order_problems(f"## X: y\n{NAME}.lua\nChecks.lua\nChecks_A.lua\n"), 0),
        ("registry first", order_problems(f"Checks.lua\n{NAME}.lua\n"), 1),
        ("other file after the registry", order_problems(f"{NAME}.lua\nChecks.lua\nHelpers.lua\n"), 1),
    ]
    guard = f"local Probe = {GUARD}\n"
    impl = guard + 'Probe:Implement("V1", f)\nlocal V19 = "V19"\nProbe:Implement(V19, f)\nProbe:Implement("V20", f)\n'
    done = ["V1", "V19", "V20", "V21"]  # a fixed list, so that the cases do not change with IMPLEMENTED
    cases += [
        ("good implementations", implement_problems({"A": impl, "B": guard + 'Probe:Implement("V21", f)'}, done), 0),
        # V21 missing, V2 not in the list, V20 twice, B without the guard
        ("missing, extra, twice, no guard", implement_problems({"A": impl + 'Probe:Implement("V2", f)\n',
                                                               "B": 'Probe:Implement("V20", f)'}, done), 4),
    ]
    bound = "local PREFIX = Probe.TEST_PREFIX\n"
    good_calls = (bound + "call(C_ChatInfo.SendAddonMessage, PREFIX, t, d)\n"
                  "C_ChatInfo.RegisterAddonMessagePrefix(Probe.TEST_PREFIX)\n"
                  '-- SendAddonMessage("x") in a comment\nlocal r = Enum.SendAddonMessageResult\n')
    cases += [
        ("test prefix", prefix_problems({"A": good_calls}), 0),
        # a literal prefix; PREFIX not bound to the test prefix; the real prefix in a string
        ("other prefixes", prefix_problems({"A": 'C_ChatInfo.SendAddonMessage("Other", t)\n',
                                            "B": 'local PREFIX = "AZPRES"\n'
                                                 "pcall(C_ChatInfo.SendAddonMessageLogged, PREFIX)\n"}), 3),
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
    if NAME + ".toc" in files:
        found.extend(f"tools/probe/{NAME}/{NAME}.toc: {p}" for p in order_problems(read(NAME + ".toc")))
    sources = {name: read(name) for name in sorted(files) if re.fullmatch(r"Checks_\w+\.lua", name)}
    found.extend(f"tools/probe/{NAME}: {p}" for p in implement_problems(sources))
    lua = {name: read(name) for name in sorted(files) if name.endswith(".lua")}
    found.extend(f"tools/probe/{NAME}: {p}" for p in prefix_problems(lua))
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
