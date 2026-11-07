#!/usr/bin/env python3
"""Validate a root module folder and zip it for flashing.

Usage: python tools/package.py <module-dir> --out /mnt/user-data/outputs [--keep-old]
Checks: module.prop keys, id/versionCode format, shebangs, CRLF line endings, `sh -n` syntax on every .sh,
leftover template placeholders, forbidden files, size. Removes older <id>-*.zip from --out unless --keep-old.
The zip has module.prop at its root, which is what KernelSU/SukiSU/Magisk require.
"""
import argparse, glob, os, re, subprocess, sys, zipfile

def fail(msgs):
    for m in msgs:
        print("ERROR:", m)
    sys.exit(1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("module_dir")
    ap.add_argument("--out", required=True)
    ap.add_argument("--keep-old", action="store_true")
    a = ap.parse_args()
    d = os.path.abspath(a.module_dir)
    errs, warns = [], []

    prop_path = os.path.join(d, "module.prop")
    if not os.path.isfile(prop_path):
        fail(["module.prop missing at module root"])
    prop = {}
    for line in open(prop_path, encoding="utf-8"):
        if "=" in line and not line.startswith("#"):
            k, v = line.rstrip("\n").split("=", 1)
            prop[k.strip()] = v.strip()
    for k in ("id", "name", "version", "versionCode", "author", "description"):
        if not prop.get(k):
            errs.append(f"module.prop: '{k}' missing or empty")
    if prop.get("id") and not re.fullmatch(r"[a-zA-Z][a-zA-Z0-9._-]+", prop["id"]):
        errs.append("module.prop: id has invalid characters")
    if prop.get("versionCode") and not prop["versionCode"].isdigit():
        errs.append("module.prop: versionCode must be an integer")
    if prop.get("banner") and not os.path.isfile(os.path.join(d, prop["banner"])):
        errs.append(f"module.prop: banner file '{prop['banner']}' not found")

    files = []
    for root, dirs, fs in os.walk(d):
        dirs[:] = [x for x in dirs if x not in (".git", "__pycache__", "node_modules")]
        for f in fs:
            p = os.path.join(root, f)
            files.append(p)
            rel = os.path.relpath(p, d)
            if f.endswith((".zip", ".pyc")) or f == ".DS_Store":
                warns.append(f"unexpected file skipped: {rel}")
                continue
            if f.endswith(".sh") or rel == "system/bin/" + prop.get("id", ""):
                data = open(p, "rb").read()
                if b"\r\n" in data:
                    errs.append(f"{rel}: Windows (CRLF) line endings break shell scripts")
                if not data.startswith(b"#!/system/bin/sh"):
                    errs.append(f"{rel}: first line must be #!/system/bin/sh")
                r = subprocess.run(["sh", "-n", p], capture_output=True, text=True)
                if r.returncode != 0:
                    errs.append(f"{rel}: syntax error: {r.stderr.strip()}")
            if f.endswith((".sh", ".html", ".prop", ".txt", ".awk")):
                if "__" in open(p, encoding="utf-8", errors="ignore").read() and re.search(r"__(ID|NAME|AUTHOR|DESC|VERSION|VCODE)__", open(p, encoding="utf-8", errors="ignore").read()):
                    errs.append(f"{rel}: unreplaced template placeholder")
    if not os.path.isfile(os.path.join(d, "customize.sh")) and not os.path.isfile(os.path.join(d, "service.sh")):
        warns.append("no customize.sh or service.sh: module will do nothing at install or boot")
    if errs:
        fail(errs)

    os.makedirs(a.out, exist_ok=True)
    if not a.keep_old:
        for old in glob.glob(os.path.join(a.out, prop["id"] + "-*.zip")):
            os.remove(old)
    ver = prop["version"] if prop["version"].startswith("v") else "v" + prop["version"]
    zpath = os.path.join(a.out, f"{prop['name'].replace(' ', '')}-{ver}.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(files):
            rel = os.path.relpath(p, d)
            if p.endswith((".zip", ".pyc")) or os.path.basename(p) == ".DS_Store":
                continue
            info = zipfile.ZipInfo.from_file(p, rel)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(p, "rb").read())
    size = os.path.getsize(zpath)
    for w in warns:
        print("warning:", w)
    print(f"OK {zpath} ({size/1024:.0f} KB)")
    if size > 5 * 1024 * 1024:
        print("warning: zip is over 5 MB; shrink images")

if __name__ == "__main__":
    main()
