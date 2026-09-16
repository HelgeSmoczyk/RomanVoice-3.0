#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Vendor
if [[ ! -d Vendor/llama.xcframework ]]; then
  curl --fail --location --retry 3 'https://github.com/ggml-org/llama.cpp/releases/download/b6500/llama-b6500-xcframework.zip' -o Vendor/llama.zip
  echo '00e8636fdb02a2cbfec5612d8835b1cc33a1a23242195db331933ce7d4514975  Vendor/llama.zip' | shasum -a 256 -c -
  unzip -q Vendor/llama.zip -d Vendor/unpacked
  mv Vendor/unpacked/build-apple/llama.xcframework Vendor/llama.xcframework
fi
