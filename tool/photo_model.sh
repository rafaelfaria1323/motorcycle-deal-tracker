#!/usr/bin/env bash
# Downloads the image model of tool/photo_examine.py (P.2) into $1 unless
# it is already there: OpenAI's CLIP ViT-B/32 (MIT licence) as exported to
# ONNX for transformers.js (Hugging Face, Xenova/clip-vit-base-patch32).
# collect.yml caches the folder, so this downloads once, not every run.
set -euo pipefail

dir=${1:?usage: tool/photo_model.sh <model_dir>}
base=https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main
mkdir -p "$dir"

fetch() {
  local from=$1 to=$2
  if [ -s "$dir/$to" ]; then return; fi
  curl --fail --silent --show-error --location --retry 3 \
    --output "$dir/$to.part" "$base/$from"
  mv "$dir/$to.part" "$dir/$to"
}

fetch onnx/vision_model.onnx vision_model.onnx
fetch onnx/text_model.onnx text_model.onnx
fetch tokenizer.json tokenizer.json
(cd "$dir" && sha256sum vision_model.onnx text_model.onnx tokenizer.json)
