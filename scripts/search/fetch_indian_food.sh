#!/usr/bin/env bash
# Fetches the Indian Food 101 CSV (255 dishes with a flavor_profile label) for the auto-tagger agreement test.
# It is NOT committed: the Kaggle license was not confirmed. Original: kaggle.com/datasets/nehaprabhavalkar/indian-food-101
set -euo pipefail
DEST="${1:-$(dirname "$0")/../../data/indian_food.csv}"
mkdir -p "$(dirname "$DEST")"
curl -fL --retry 3 -o "$DEST" "https://huggingface.co/spaces/tushar310/alphaGPT-Generic/resolve/main/indian_food.csv"
wc -l "$DEST"; head -3 "$DEST"
