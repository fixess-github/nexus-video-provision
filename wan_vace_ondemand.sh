#!/usr/bin/env bash
# Bootstrap Wan 2.2 Fun-VACE weights on stock vastai/comfy (ondemand) via
# PROVISIONING_SCRIPT. The VACE graph uses only native ComfyUI nodes
# (LoadVideo / GetVideoComponents / WanVaceToVideo), so no custom nodes are
# installed here — only the model weights are fetched.
#
# IMPORTANT: at runtime ComfyUI reads models from ${WORKSPACE}/ComfyUI/models
# (vast's convention; matches its own provisioning scripts). Writing to
# /opt/workspace-internal would NOT be picked up, since the boot-time sync from
# the image has already run.
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
MODELS="${WORKSPACE}/ComfyUI/models"
MARKER="${MODELS}/diffusion_models/.wan_vace_provisioned"
REPACK="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files"

if [[ -f "${MARKER}" ]]; then
  echo "wan vace: already provisioned"
  exit 0
fi

mkdir -p "${MODELS}/diffusion_models" "${MODELS}/text_encoders" "${MODELS}/vae"

_fetch() {
  local dest="$1" url="$2"
  if [[ -f "${dest}" ]]; then
    echo "wan vace: have $(basename "${dest}")"
    return 0
  fi
  echo "wan vace: downloading $(basename "${dest}") ..."
  wget -c --tries=5 --timeout=120 -O "${dest}" "${url}"
}

_fetch "${MODELS}/diffusion_models/wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors" \
  "${REPACK}/diffusion_models/wan2.2_fun_vace_high_noise_14B_fp8_scaled.safetensors"
_fetch "${MODELS}/diffusion_models/wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors" \
  "${REPACK}/diffusion_models/wan2.2_fun_vace_low_noise_14B_fp8_scaled.safetensors"
_fetch "${MODELS}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "${REPACK}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
_fetch "${MODELS}/vae/wan_2.1_vae.safetensors" \
  "${REPACK}/vae/wan_2.1_vae.safetensors"

touch "${MARKER}"
echo "wan vace: provisioning complete"
