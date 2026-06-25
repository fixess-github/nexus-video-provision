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
# Flat cel-shaded Ghibli style LoRA (Wan 2.1 T2V 14B, applies to the 2.2 MoE
# experts). Public HF mirror, no auth. Override with WAN_GHIBLI_LORA_URL.
GHIBLI_LORA_URL="${WAN_GHIBLI_LORA_URL:-https://huggingface.co/Muapi/studio-ghibli-wan2.1-t2v-14b/resolve/main/studio-ghibli-wan2.1-t2v-14b.safetensors}"
GHIBLI_LORA_NAME="studio-ghibli-wan2.1-t2v-14b.safetensors"

if [[ -f "${MARKER}" ]]; then
  echo "wan vace: already provisioned"
  exit 0
fi

mkdir -p "${MODELS}/diffusion_models" "${MODELS}/text_encoders" "${MODELS}/vae" \
  "${MODELS}/loras"

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
_fetch "${MODELS}/loras/${GHIBLI_LORA_NAME}" "${GHIBLI_LORA_URL}"

# Higher-fidelity bf16 experts (unquantized) — only when requested, since each is
# ~28GB. Lets a quality sweep A/B fp8 vs bf16 on the same warm boot.
if [[ "${WAN_VACE_FETCH_BF16:-}" =~ ^(1|true|yes)$ ]]; then
  echo "wan vace: WAN_VACE_FETCH_BF16 set — also fetching bf16 experts"
  _fetch "${MODELS}/diffusion_models/wan2.2_fun_vace_high_noise_14B_bf16.safetensors" \
    "${REPACK}/diffusion_models/wan2.2_fun_vace_high_noise_14B_bf16.safetensors"
  _fetch "${MODELS}/diffusion_models/wan2.2_fun_vace_low_noise_14B_bf16.safetensors" \
    "${REPACK}/diffusion_models/wan2.2_fun_vace_low_noise_14B_bf16.safetensors"
fi

touch "${MARKER}"
echo "wan vace: provisioning complete"
