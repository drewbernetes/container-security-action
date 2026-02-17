#!/usr/bin/env bash
set -euo pipefail

# validate-inputs.sh - Validates all action inputs and fails fast with all errors reported.

ERRORS=()

# --- Helper ---
add_error() {
  ERRORS+=("$1")
}

# --- Validate check-severity (case-insensitive) ---
if [[ -n "${INPUT_CHECK_SEVERITY:-}" ]]; then
  IFS=',' read -ra SEVERITIES <<< "${INPUT_CHECK_SEVERITY}"
  ALLOWED="UNKNOWN LOW MEDIUM HIGH CRITICAL"
  for sev in "${SEVERITIES[@]}"; do
    sev_trimmed=$(echo "$sev" | xargs)
    sev_upper=$(echo "${sev_trimmed}" | tr '[:lower:]' '[:upper:]')
    if [[ ! " ${ALLOWED} " =~ " ${sev_upper} " ]]; then
      add_error "Invalid check-severity value '${sev_trimmed}'. Allowed: UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL"
    fi
  done
fi

# --- Validate signing-mode ---
if [[ -n "${INPUT_SIGNING_MODE:-}" ]]; then
  case "${INPUT_SIGNING_MODE}" in
    private-key|oidc) ;;
    *) add_error "Invalid signing-mode '${INPUT_SIGNING_MODE}'. Must be 'private-key' or 'oidc'" ;;
  esac
fi

# --- Signing mode requirements ---
if [[ "${INPUT_PUBLISH_IMAGE:-false}" == "true" ]]; then
  if [[ "${INPUT_SIGNING_MODE:-private-key}" == "private-key" ]]; then
    if [[ -z "${INPUT_COSIGN_PRIVATE_KEY:-}" ]]; then
      add_error "cosign-private-key is required when signing-mode is 'private-key' and publish-image is true"
    fi
    if [[ -z "${INPUT_COSIGN_PASSWORD:-}" ]]; then
      add_error "cosign-password is required when signing-mode is 'private-key' and publish-image is true"
    fi
  fi
fi

# --- Publish image requirements ---
if [[ "${INPUT_PUBLISH_IMAGE:-false}" == "true" ]]; then
  if [[ -z "${INPUT_REPO_USERNAME:-}" ]]; then
    add_error "repo-username is required when publish-image is true"
  fi
  if [[ -z "${INPUT_REPO_PASSWORD:-}" ]]; then
    add_error "repo-password is required when publish-image is true"
  fi
fi

# --- S3 requirements ---
if [[ "${INPUT_GRYPEIGNORE_FROM_S3:-false}" == "true" ]]; then
  if [[ -z "${INPUT_S3_ACCESS_KEY:-}" ]]; then
    add_error "s3-access-key is required when grypeignore-from-s3 is true"
  fi
  if [[ -z "${INPUT_S3_SECRET_KEY:-}" ]]; then
    add_error "s3-secret-key is required when grypeignore-from-s3 is true"
  fi
  if [[ -z "${INPUT_S3_BUCKET:-}" ]]; then
    add_error "s3-bucket is required when grypeignore-from-s3 is true"
  fi
fi

# --- Dependency graph requirements ---
if [[ "${INPUT_ENABLE_DEPENDENCY_GRAPH:-false}" == "true" ]]; then
  if [[ -z "${INPUT_GITHUB_TOKEN:-}" ]]; then
    add_error "github-token is required when enable-dependency-graph is true"
  fi
fi

# --- Multi-platform requires publish ---
if [[ -n "${INPUT_PLATFORMS:-}" ]]; then
  if [[ "${INPUT_PUBLISH_IMAGE:-false}" != "true" ]]; then
    add_error "publish-image must be true when platforms is set (multi-platform builds push during build)"
  fi
fi

# --- Dockerfile existence ---
DOCKERFILE_PATH="${INPUT_DOCKERFILE_PATH:-.}"
if [[ ! -f "${DOCKERFILE_PATH}/Dockerfile" ]]; then
  add_error "Dockerfile not found at '${DOCKERFILE_PATH}/Dockerfile'"
fi

# --- Docker availability ---
if ! command -v docker &>/dev/null; then
  add_error "docker is not available on this runner"
elif ! docker buildx version &>/dev/null; then
  add_error "docker buildx is not available on this runner"
fi

# --- jq availability (required for CVE parsing) ---
if ! command -v jq &>/dev/null; then
  add_error "jq is not available on this runner (required for scan result parsing)"
fi

# --- Report all errors ---
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "::error::Input validation failed with ${#ERRORS[@]} error(s):"
  for err in "${ERRORS[@]}"; do
    echo "::error::  - ${err}"
  done
  exit 1
fi

echo "All inputs validated successfully."
