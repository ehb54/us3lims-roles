#!/usr/bin/env python3
"""Read and edit slurm.conf and cgroup.conf for the upgrade-lims-slurm role.

  slurm_conf_tool.py facts CONF MAY_DIFFER_REGEX
      Print facts about the slurm.conf CONF as JSON.  "digest" is the SHA-1 of
      its lines without those matching MAY_DIFFER_REGEX, to compare the files
      of a cluster's nodes.

  slurm_conf_tool.py edit IN OUT EDITS_JSON_FILE
      Write IN, with the edits in EDITS_JSON_FILE, to OUT (which may be IN),
      and print a unified diff.  The edits (all optional):
        "comment":  ["Key", ...]      comment out every active Key= line
        "set":      {"Key": value}    replace the first active Key= line (and
                                      comment out later ones), else the first
                                      "#Key=" line, else insert the line after
                                      the active line named in "after"[Key],
                                      else append it
        "after":    {"Key": "OtherKey"}
        "node_realmemory": {"node": MB}   set RealMemory= on the node's line

Keys are matched without regard to case, as Slurm does.  Runs on Python 3.6.
"""
import difflib
import hashlib
import json
import re
import sys


def read_lines(path):
    with open(path) as fh:
        text = fh.read()
    return text.splitlines(), text.endswith("\n") or text == ""


def write_lines(path, lines, final_newline):
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + ("\n" if final_newline and lines else ""))


def key_pattern(key, active=True):
    prefix = r"^\s*" if active else r"^\s*#\s*"
    return re.compile(prefix + re.escape(key) + r"\s*=\s*(.*?)\s*$", re.I)


def active(lines, key):
    pat = key_pattern(key)
    return [(i, pat.match(l).group(1)) for i, l in enumerate(lines) if pat.match(l)]


def facts(path, may_differ):
    lines, _ = read_lines(path)
    nodes = {}
    for line in lines:
        m = re.match(r"^\s*NodeName\s*=\s*(\S+)", line, re.I)
        if m and m.group(1).upper() != "DEFAULT":
            rm = re.search(r"\bRealMemory\s*=\s*(\d+)", line, re.I)
            nodes[m.group(1)] = {"realmemory": int(rm.group(1)) if rm else 0, "line": line}

    def first(key, default=""):
        found = active(lines, key)
        return found[0][1] if found else default

    differ = re.compile(may_differ)
    kept = [l for l in lines if not differ.search(l)]
    out = {
        "nodes": nodes,
        "node_ranges": [n for n in nodes if "[" in n or "," in n],
        "taskplugin": first("TaskPlugin"),
        "proctracktype": first("ProctrackType"),
        "selecttypeparameters": first("SelectTypeParameters"),
        "defmempercpu": first("DefMemPerCPU"),
        "accountingstoragetype": first("AccountingStorageType"),
        "statesavelocation": first("StateSaveLocation", "/var/spool/slurmctld"),
        "slurmdspooldir": first("SlurmdSpoolDir", "/var/spool/slurmd"),
        "firstjobid": first("FirstJobId"),
        "digest": hashlib.sha1("\n".join(kept).encode()).hexdigest(),
    }
    print(json.dumps(out, sort_keys=True))


def edit(src, dst, edits_path):
    with open(edits_path) as fh:
        edits = json.load(fh)
    lines, final_newline = read_lines(src)
    before = list(lines)

    for key in edits.get("comment", []):
        pat = key_pattern(key)
        lines = ["#" + l + "  # not used by this Slurm release" if pat.match(l) else l for l in lines]

    after = edits.get("after", {})
    for key, value in edits.get("set", {}).items():
        new = "%s=%s" % (key, value)
        found = active(lines, key)
        if found:
            lines[found[0][0]] = new
            for i, _ in found[1:]:
                lines[i] = "#" + lines[i] + "  # set above"
            continue
        inactive = key_pattern(key, active=False)
        idx = next((i for i, l in enumerate(lines) if inactive.match(l)), None)
        if idx is not None:
            lines[idx] = new
            continue
        anchor = active(lines, after[key]) if key in after else []
        if anchor:
            lines.insert(anchor[-1][0] + 1, new)
        else:
            lines.append(new)

    for node, mb in edits.get("node_realmemory", {}).items():
        pat = re.compile(r"^(\s*NodeName\s*=\s*" + re.escape(node) + r")(\s.*)?$", re.I)
        for i, line in enumerate(lines):
            m = pat.match(line)
            if not m:
                continue
            rest = m.group(2) or ""
            if re.search(r"\bRealMemory\s*=", rest, re.I):
                rest = re.sub(r"\bRealMemory\s*=\s*\d+", "RealMemory=%d" % int(mb), rest, flags=re.I)
            else:
                rest = " RealMemory=%d" % int(mb) + rest
            lines[i] = m.group(1) + rest

    write_lines(dst, lines, final_newline)
    for d in difflib.unified_diff(before, lines, src, dst, lineterm=""):
        print(d)


def main(argv):
    if len(argv) == 4 and argv[1] == "facts":
        facts(argv[2], argv[3])
    elif len(argv) == 5 and argv[1] == "edit":
        edit(argv[2], argv[3], argv[4])
    else:
        sys.stderr.write(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
