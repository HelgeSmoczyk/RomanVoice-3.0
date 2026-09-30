#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p Vendor
if [[ ! -d Vendor/llama.xcframework ]]; then
  curl --fail --location --retry 3 'https://github.com/ggml-org/llama.cpp/releases/download/b6500/llama-b6500-xcframework.zip' -o Vendor/llama.zip
  echo '00e8636fdb02a2cbfec5612d8835b1cc33a1a23242195db331933ce7d4514975  Vendor/llama.zip' | shasum -a 256 -c -
  rm -rf Vendor/unpacked
  unzip -q Vendor/llama.zip -d Vendor/unpacked
  mv Vendor/unpacked/build-apple/llama.xcframework Vendor/llama.xcframework
fi

# GitHub "Add files via upload" overwrites files, but does not remove old files.
# On macOS, paths that differ only by case can also collapse onto one filesystem entry.
# Normalize every asset set BEFORE verify_project.py runs.
python3 - <<'PY'
from pathlib import Path
import json
import os
import subprocess

root = Path.cwd()
assets = root / 'RomanVoice' / 'Assets.xcassets'


def git_blob(rel: Path):
    """Read the exact canonical path from Git's index/HEAD when available."""
    try:
        return subprocess.check_output(
            ['git', 'show', f'HEAD:{rel.as_posix()}'],
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return None


def referenced_filenames(metadata):
    names = set()
    def walk(value):
        if isinstance(value, dict):
            filename = value.get('filename')
            if isinstance(filename, str) and filename:
                names.add(filename)
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(metadata)
    return names

for folder in sorted(list(assets.glob('*.imageset')) + list(assets.glob('*.appiconset'))):
    canonical_rel = folder.relative_to(root) / 'Contents.json'
    blob = git_blob(canonical_rel)

    entries = [p for p in folder.iterdir() if p.is_file()]
    variants = [p for p in entries if p.name.casefold() == 'contents.json']

    if blob is None:
        exact = next((p for p in variants if p.name == 'Contents.json'), None)
        chosen = exact or (variants[0] if variants else None)
        if chosen is None:
            raise SystemExit(f'{folder}: Contents.json fehlt')
        blob = chosen.read_bytes()

    # Remove all case variants first, then recreate exactly one canonical Contents.json.
    for p in list(folder.iterdir()):
        if p.is_file() and p.name.casefold() == 'contents.json':
            p.unlink()
    canonical = folder / 'Contents.json'
    canonical.write_bytes(blob)

    try:
        metadata = json.loads(blob.decode('utf-8'))
    except Exception as exc:
        raise SystemExit(f'{canonical}: ungültiges JSON: {exc}')

    keep = referenced_filenames(metadata)
    for p in list(folder.iterdir()):
        if not p.is_file() or p.name == 'Contents.json':
            continue
        if p.name not in keep:
            print(f'Entferne veraltete Asset-Datei: {p.relative_to(root)}')
            p.unlink()
PY
