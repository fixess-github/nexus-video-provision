#!/usr/bin/env bash
# Provision the from-scratch pose-keyframe stack on the baked ltx-comfy image:
# a photoreal SDXL checkpoint + the xinsir OpenPose SDXL ControlNet. Runs as
# PROVISIONING_SCRIPT at boot; ComfyUI reads models from ${WORKSPACE}/ComfyUI/models
# (the image's /opt/workspace-internal tree was already synced by then, so
# writing there would be missed — same rule as wan_vace_ondemand.sh).
#
# Consumed by server/video/pose_keyframe_workflow.py: filenames here must match
# PHOTOREAL_CKPT / OPENPOSE_CONTROLNET in that module.
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
MODELS="${WORKSPACE}/ComfyUI/models"
MARKER="${MODELS}/controlnet/.sdxl_pose_keyframe_provisioned"

if [[ -f "${MARKER}" ]]; then
  echo "sdxl pose keyframe: already provisioned"
  exit 0
fi

mkdir -p "${MODELS}/checkpoints" "${MODELS}/controlnet" \
  "${MODELS}/ipadapter" "${MODELS}/clip_vision"

_fetch() {
  local dest="$1" url="$2"
  if [[ -f "${dest}" ]]; then
    echo "sdxl pose keyframe: have $(basename "${dest}")"
    return 0
  fi
  echo "sdxl pose keyframe: downloading $(basename "${dest}") ..."
  wget -c --tries=5 --timeout=120 -q -O "${dest}" "${url}"
}

# Photoreal SDXL (RealVisXL 4.0) — the 1970s-film look wants photoreal, not the
# baked Animagine anime checkpoint.
_fetch "${MODELS}/checkpoints/RealVisXL_V4.0.safetensors" \
  "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors"

# xinsir OpenPose SDXL ControlNet — keypoint-specialized pose control (the
# missing piece Replicate could not provide; design doc §14).
_fetch "${MODELS}/controlnet/xinsir_openpose_sdxl.safetensors" \
  "https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"

# IP-Adapter Plus SDXL + its ViT-H CLIP vision encoder — masked per-character
# identity conditioning (IPAdapterAdvanced in pose_keyframe_workflow.py).
_fetch "${MODELS}/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors" \
  "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
_fetch "${MODELS}/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" \
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"

touch "${MARKER}"
echo "sdxl pose keyframe: provisioning complete"
