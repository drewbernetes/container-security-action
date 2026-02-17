#!/usr/bin/env bash
set -euo pipefail

# build-image.sh - Builds Docker images with multi-platform and GHA cache support.
#
# Required env vars:
#   IMAGE_REF            - Full image reference without tag (e.g. ghcr.io/user/image)
#   TAGS                 - Space-separated list of tags
#   INPUT_DOCKERFILE_PATH - Path to directory containing Dockerfile
#   INPUT_BUILD_ARGS     - Comma-separated build args (optional)
#   INPUT_PLATFORMS      - Comma-separated platform list (optional, triggers multi-platform build)

DOCKERFILE="${INPUT_DOCKERFILE_PATH:-.}/Dockerfile"

# --- Parse build args ---
BUILD_ARGS=""
if [[ -n "${INPUT_BUILD_ARGS:-}" ]]; then
  IFS=',' read -ra ARG_ARRAY <<< "${INPUT_BUILD_ARGS}"
  for arg in "${ARG_ARRAY[@]}"; do
    trimmed=$(echo "$arg" | xargs)
    BUILD_ARGS="${BUILD_ARGS} --build-arg ${trimmed}"
  done
fi

# --- Build tag flags ---
TAG_FLAGS=""
for tag in ${TAGS}; do
  TAG_FLAGS="${TAG_FLAGS} -t ${IMAGE_REF}:${tag}"
done

MULTIPLATFORM_BUILD="false"
IMAGE_DIGEST=""

if [[ -n "${INPUT_PLATFORMS:-}" ]]; then
  # --- Multi-platform build ---
  MULTIPLATFORM_BUILD="true"
  echo "Building multi-platform image for: ${INPUT_PLATFORMS}"

  # Create a dedicated builder if one doesn't exist
  BUILDER_NAME="csa-multiplatform"
  if ! docker buildx inspect "${BUILDER_NAME}" &>/dev/null; then
    docker buildx create --name "${BUILDER_NAME}" --driver docker-container --use
  else
    docker buildx use "${BUILDER_NAME}"
  fi

  # Multi-platform builds must push directly (cannot --load multiple platforms)
  # shellcheck disable=SC2086
  docker buildx build \
    ${BUILD_ARGS} \
    ${TAG_FLAGS} \
    --platform="${INPUT_PLATFORMS}" \
    --push \
    --cache-from type=gha \
    --cache-to type=gha,mode=max \
    -f "${DOCKERFILE}" \
    .

  # Extract digest from the first tag
  FIRST_TAG=$(echo "${TAGS}" | awk '{print $1}')
  IMAGE_DIGEST=$(docker buildx imagetools inspect "${IMAGE_REF}:${FIRST_TAG}" --format '{{.Digest}}')

  echo "Multi-platform build complete. Digest: ${IMAGE_DIGEST}"
else
  # --- Single-platform build ---
  echo "Building single-platform image"

  # shellcheck disable=SC2086
  docker buildx build \
    ${BUILD_ARGS} \
    ${TAG_FLAGS} \
    --load \
    --cache-from type=gha \
    --cache-to type=gha,mode=max \
    -f "${DOCKERFILE}" \
    .

  echo "Single-platform build complete."
fi

# Export to GITHUB_ENV
{
  echo "MULTIPLATFORM_BUILD=${MULTIPLATFORM_BUILD}"
  echo "IMAGE_DIGEST=${IMAGE_DIGEST}"
} >> "${GITHUB_ENV}"
