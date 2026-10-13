#!/usr/bin/env bash
set -euo pipefail
root="$(pwd)"
tmp="$(mktemp -d)"
mkdir -p vendors registries
: > "$tmp/sources.tsv"
sources=(
  "jev-ultrafast browser-use/jev-ultrafast"
  "laya NandhaKishorM/laya"
  "ax google/ax"
  "hindsight vectorize-io/hindsight"
  "paperclip paperclipai/paperclip"
)
for entry in "${sources[@]}"; do
  read -r name upstream <<< "$entry"
  if [[ -e "$root/vendors/$name" ]]; then
    echo "Refusing to overwrite existing vendors/$name" >&2
    exit 1
  fi
  git clone --depth 1 --single-branch "https://github.com/$upstream.git" "$tmp/$name"
  commit="$(git -C "$tmp/$name" rev-parse HEAD)"
  mkdir "$root/vendors/$name"
  git -C "$tmp/$name" ls-files -z > "$tmp/$name.files"
  (cd "$tmp/$name" && tar --null --verbatim-files-from -T "$tmp/$name.files" -cf -) |
    tar -xf - -C "$root/vendors/$name"
  printf '%s\t%s\t%s\n' "$name" "$upstream" "$commit" >> "$tmp/sources.tsv"
done
python3 - "$tmp/sources.tsv" <<'PY'
import json, pathlib, subprocess, sys
records=[]
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    name, upstream, commit=line.split("\t")
    records.append({"name":name,"upstream":"https://github.com/"+upstream,
                    "commit":commit,"path":"vendors/"+name,"status":"source-copied"})
pathlib.Path("registries/source-lock.json").write_text(json.dumps(
    {"schema_version":1,"copy_type":"tracked source snapshot, without upstream history",
     "tools":records},indent=2)+"\n")
PY
git add --force vendors registries/source-lock.json
python3 - "$tmp" <<'PY'
import json, pathlib, subprocess, sys
tmp=pathlib.Path(sys.argv[1])
def tree(path):
    raw=subprocess.check_output(["git","-C",str(path),"ls-tree","-r","-z","HEAD"])
    rows={}
    for item in raw.split(b"\0"):
        if not item: continue
        meta,name=item.split(b"\t",1)
        mode,kind,sha=meta.split()
        if kind!=b"blob": raise RuntimeError("Non-blob entry requires separate handling: "+name.decode())
        rows[name]=(mode,sha)
    return rows
raw=subprocess.check_output(["git","ls-files","--stage","-z","vendors"])
actual={}
for item in raw.split(b"\0"):
    if not item: continue
    meta,name=item.split(b"\t",1)
    mode,sha,stage=meta.split()
    actual[name]=(mode,sha)
for tool in json.loads(pathlib.Path("registries/source-lock.json").read_text())["tools"]:
    expected=tree(tmp/tool["name"])
    prefix=(tool["path"]+"/").encode()
    copied={name[len(prefix):]:val for name,val in actual.items() if name.startswith(prefix)}
    if copied!=expected: raise RuntimeError("Source content or modes differ: "+tool["name"])
    print(tool["name"]+": verified "+str(len(expected))+" exact Git blobs and file modes")
PY
if git diff --cached --quiet; then
  echo "No source changes"
  exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit -m "Vendor five upstream workflow tools with exact source verification"
git push origin HEAD:main
