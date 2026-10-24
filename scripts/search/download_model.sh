#!/usr/bin/env bash
# Downloads the embedding model used by dish search (BAAI/bge-small-en-v1.5, MIT license, ~133 MB ONNX).
# Files go to backend/models/bge-small-en-v1.5 (git-ignored). Without them search still works, keyword + tags only.
set -euo pipefail
DEST="${1:-$(dirname "$0")/../../backend/models/bge-small-en-v1.5}"
BASE="https://huggingface.co/BAAI/bge-small-en-v1.5/resolve/main"
mkdir -p "$DEST"
for f in onnx/model.onnx vocab.txt tokenizer_config.json config.json; do
  out="$DEST/$(basename "$f")"
  if [ -s "$out" ]; then echo "have $(basename "$f")"; continue; fi
  echo "fetching $f"
  curl -fL --retry 3 -o "$out.part" "$BASE/$f"
  mv "$out.part" "$out"
done
ls -la "$DEST"
