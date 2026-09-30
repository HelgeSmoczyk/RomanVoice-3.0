#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# GitHub web uploads can leave asset-catalog metadata with case-only legacy
# names (for example contents.json). Canonicalize them before verification
# and before Xcode/actool sees the catalog. The two-step rename also works on
# the default case-insensitive macOS filesystem used by GitHub Actions.
python3 - <<'PY_ASSETS'
from pathlib import Path

assets = Path("RomanVoice/Assets.xcassets")
catalogs = [assets] + [
    path for path in assets.rglob("*")
    if path.is_dir() and path.suffix in {".imageset", ".appiconset"}
]
for catalog in catalogs:
    matches = [
        entry for entry in catalog.iterdir()
        if entry.is_file() and entry.name.casefold() == "contents.json"
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"Genau eine Contents.json-Metadatei erwartet in {catalog}, "
            f"gefunden: {[entry.name for entry in matches]}"
        )
    source = matches[0]
    canonical = catalog / "Contents.json"
    if source.name != canonical.name:
        temporary = catalog / ".romanvoice-contents-normalize.tmp"
        if temporary.exists():
            temporary.unlink()
        source.rename(temporary)
        temporary.rename(canonical)

    # GitHub's web uploader adds/replaces files but does not delete older files
    # that are absent from a new upload. Remove stale, unreferenced payload files
    # from imagesets/appiconsets before the verifier and actool see them.
    if catalog.suffix in {".imageset", ".appiconset"}:
        import json
        metadata = json.loads(canonical.read_text(encoding="utf-8"))
        referenced = {
            item.get("filename")
            for item in metadata.get("images", [])
            if item.get("filename")
        }
        for entry in catalog.iterdir():
            if not entry.is_file():
                continue
            if entry.name == "Contents.json" or entry.name.startswith("."):
                continue
            if entry.name not in referenced:
                print(f"Entferne veraltete Asset-Datei: {entry}")
                entry.unlink()
PY_ASSETS

mkdir -p Vendor
if [[ ! -d Vendor/llama.xcframework ]]; then
  curl --fail --location --retry 3 'https://github.com/ggml-org/llama.cpp/releases/download/b6500/llama-b6500-xcframework.zip' -o Vendor/llama.zip
  echo '00e8636fdb02a2cbfec5612d8835b1cc33a1a23242195db331933ce7d4514975  Vendor/llama.zip' | shasum -a 256 -c -
  unzip -q Vendor/llama.zip -d Vendor/unpacked
  mv Vendor/unpacked/build-apple/llama.xcframework Vendor/llama.xcframework
fi
