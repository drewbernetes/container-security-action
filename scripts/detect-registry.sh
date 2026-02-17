#!/usr/bin/env bash
set -euo pipefail

# detect-registry.sh - Detects registry type and constructs image references and tags.
#
# Required env vars:
#   INPUT_IMAGE_REPO     - The image repository (e.g. ghcr.io, my-dockerhub-user, myregistry.azurecr.io/project)
#   INPUT_IMAGE_NAME     - The image name
#   INPUT_IMAGE_TAG      - The image tag
#   INPUT_ADD_LATEST_TAG - Whether to add a latest tag ("true"/"false")
#   INPUT_REPO_USERNAME  - The registry username (used for ghcr.io path construction)

IS_DOCKERHUB="true"
REPO="${INPUT_IMAGE_REPO}"

# Detect registry type based on known patterns
if echo "${INPUT_IMAGE_REPO}" | grep -qE '\.azurecr\.io'; then
  IS_DOCKERHUB="false"
elif echo "${INPUT_IMAGE_REPO}" | grep -qE '\.gcr\.io'; then
  IS_DOCKERHUB="false"
elif echo "${INPUT_IMAGE_REPO}" | grep -qE '\.pkg\.dev'; then
  IS_DOCKERHUB="false"
elif echo "${INPUT_IMAGE_REPO}" | grep -qE '\.dkr\.ecr\..*\.amazonaws\.com'; then
  IS_DOCKERHUB="false"
elif echo "${INPUT_IMAGE_REPO}" | grep -qE '^ghcr\.io'; then
  IS_DOCKERHUB="false"
  # ghcr.io special case: append username to form the full path
  if [[ "${REPO}" == "ghcr.io" ]]; then
    REPO="ghcr.io/${INPUT_REPO_USERNAME}"
  fi
elif echo "${INPUT_IMAGE_REPO}" | grep -qE '(\.|/)'; then
  # Contains a dot or slash but didn't match known patterns - treat as non-DockerHub
  IS_DOCKERHUB="false"
fi

VERSION_TAG="${INPUT_IMAGE_TAG}"
IMAGE_REF="${REPO}/${INPUT_IMAGE_NAME}"

# Build space-separated tag list
TAGS="${VERSION_TAG}"
if [[ "${INPUT_ADD_LATEST_TAG}" == "true" ]]; then
  TAGS="${TAGS} latest"
fi

# Export to GITHUB_ENV
{
  echo "IS_DOCKERHUB=${IS_DOCKERHUB}"
  echo "REPO=${REPO}"
  echo "IMAGE_REF=${IMAGE_REF}"
  echo "VERSION_TAG=${VERSION_TAG}"
  echo "TAGS=${TAGS}"
} >> "${GITHUB_ENV}"

echo "Registry detection complete:"
echo "  IS_DOCKERHUB=${IS_DOCKERHUB}"
echo "  REPO=${REPO}"
echo "  IMAGE_REF=${IMAGE_REF}"
echo "  TAGS=${TAGS}"
