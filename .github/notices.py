"""THIRD-PARTY-NOTICES.txt for a pcbkit release archive: every open-source crate built into the
binary for one target, with its licence and the licence and notice files it ships.

    python3 notices.py SOURCE_DIR TARGET OUT
"""
import json, os, subprocess, sys

src, target, out = sys.argv[1:4]
meta = json.loads(subprocess.check_output(
    ["cargo", "metadata", "--format-version", "1", "--locked", "--filter-platform", target], cwd=src))
packages = {p["id"]: p for p in meta["packages"]}
nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
root = next(i for i, p in packages.items() if p["name"] == "pcbkit" and p["source"] is None)

# What the binary links: normal and build dependencies, from the pcbkit package down.
seen, stack = set(), [root]
while stack:
    i = stack.pop()
    if i in seen:
        continue
    seen.add(i)
    for d in nodes[i]["deps"]:
        if any(k["kind"] in (None, "build") for k in d["dep_kinds"]):
            stack.append(d["pkg"])

names = ("LICENSE", "LICENCE", "COPYING", "NOTICE", "COPYRIGHT", "AUTHORS")
parts = ["Open-source components of pcbkit (" + target + "), each under its own licence.\n"]
for p in sorted((packages[i] for i in seen if packages[i]["source"] is not None), key=lambda p: (p["name"], p["version"])):
    licence = p.get("license") or "see the files below"
    if any(w in licence.upper() for w in ("GPL", "AGPL", "SSPL")):
        sys.exit(f"notices: {p['name']} {p['version']} is {licence}: copyleft code must not ship")
    head = f"{p['name']} {p['version']} — {licence}" + (f" — {p['repository']}" if p.get("repository") else "")
    parts.append("=" * 78 + "\n" + head + "\n")
    folder = os.path.dirname(p["manifest_path"])
    files = sorted(f for f in os.listdir(folder) if f.upper().startswith(names) and os.path.isfile(os.path.join(folder, f)))
    if p.get("license_file"):
        files = sorted(set(files) | {p["license_file"]})
    for f in files:
        with open(os.path.join(folder, f), encoding="utf-8", errors="replace") as fh:
            parts.append(f"--- {f}\n" + fh.read().strip() + "\n")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(parts))
print(f"notices: {len(seen) - 1} crates", file=sys.stderr)
