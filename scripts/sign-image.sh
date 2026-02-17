#!/usr/bin/env bash
set -euo pipefail

# sign-image.sh - Signs container images using Cosign with private-key or OIDC mode.
#
# Required env vars:
#   IMAGE_REF              - Full image reference without tag (e.g. ghcr.io/user/image)
#   TAGS                   - Space-separated list of tags
#   INPUT_SIGNING_MODE     - "private-key" or "oidc"
#   INPUT_COSIGN_TLOG      - Whether to upload to transparency log ("true"/"false")
#   MULTIPLATFORM_BUILD    - "true" if multi-platform build was used
#
# Required for private-key mode:
#   COSIGN_PRIVATE_KEY     - The private key contents
#   COSIGN_PASSWORD        - The key password

FINAL_IMAGE_DIGEST=""

for tag in ${TAGS}; do
  FULL_REF="${IMAGE_REF}:${tag}"
  echo "Signing ${FULL_REF}..."

  # --- Extract digest ---
  DIGEST=""
  if [[ "${MULTIPLATFORM_BUILD}" == "true" ]]; then
    # Multi-platform: use buildx imagetools to get the manifest list digest
    DIGEST=$(docker buildx imagetools inspect "${FULL_REF}" --format '{{.Digest}}')
  else
    # Single-platform: after push, RepoDigests is populated
    DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${FULL_REF}" 2>/dev/null | sed 's/.*@//')
  fi

  if [[ -z "${DIGEST}" ]]; then
    echo "::error::Failed to extract digest for ${FULL_REF}"
    exit 1
  fi

  SIGN_REF="${IMAGE_REF}@${DIGEST}"
  echo "Resolved digest: ${DIGEST}"

  # --- Sign ---
  COSIGN_ARGS=(
    sign
    "--tlog-upload=${INPUT_COSIGN_TLOG}"
    --yes
  )

  if [[ "${INPUT_SIGNING_MODE}" == "private-key" ]]; then
    COSIGN_ARGS+=(--key env://COSIGN_PRIVATE_KEY)
  fi
  # OIDC mode: no --key flag, cosign uses ambient OIDC credentials

  cosign "${COSIGN_ARGS[@]}" "${SIGN_REF}"
  echo "Signed ${SIGN_REF}"

  # Keep the last digest for output
  FINAL_IMAGE_DIGEST="${DIGEST}"
done

# Export for outputs
echo "FINAL_IMAGE_DIGEST=${FINAL_IMAGE_DIGEST}" >> "${GITHUB_ENV}"
