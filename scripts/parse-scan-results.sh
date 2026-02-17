#!/usr/bin/env bash
set -euo pipefail

# parse-scan-results.sh - Extracts CVE data from Grype JSON scan results.
#
# Required env vars:
#   INPUT_CHECK_SEVERITY  - Comma-separated severity threshold (e.g. "HIGH,CRITICAL")
#   SBOM_SCAN_RESULTS     - Path to SBOM scan JSON file (may be empty)
#   IMAGE_SCAN_RESULTS    - Path to image scan JSON file (may be empty)
#
# Outputs (via GITHUB_OUTPUT):
#   cve-list    - JSON array of CVE objects
#   cve-count   - Integer count of matching CVEs
#   cve-summary - Human-readable summary

# --- Build severity filter ---
# Map severity names to numeric levels for >= comparison
severity_level() {
  case "$1" in
    UNKNOWN)    echo 0 ;;
    NEGLIGIBLE) echo 1 ;;
    LOW)        echo 2 ;;
    MEDIUM)     echo 3 ;;
    HIGH)       echo 4 ;;
    CRITICAL)   echo 5 ;;
    *)          echo -1 ;;
  esac
}

# Find the minimum severity level from the threshold list
MIN_LEVEL=5
IFS=',' read -ra SEVS <<< "${INPUT_CHECK_SEVERITY:-HIGH}"
for sev in "${SEVS[@]}"; do
  sev_trimmed=$(echo "$sev" | xargs | tr '[:lower:]' '[:upper:]')
  level=$(severity_level "${sev_trimmed}")
  if [[ ${level} -lt ${MIN_LEVEL} && ${level} -ge 0 ]]; then
    MIN_LEVEL=${level}
  fi
done

echo "Filtering CVEs at severity level >= ${MIN_LEVEL}"

# --- Collect scan result files ---
SCAN_FILES=()
if [[ -n "${SBOM_SCAN_RESULTS:-}" && -f "${SBOM_SCAN_RESULTS}" ]]; then
  SCAN_FILES+=("${SBOM_SCAN_RESULTS}")
  echo "Including SBOM scan results: ${SBOM_SCAN_RESULTS}"
fi
if [[ -n "${IMAGE_SCAN_RESULTS:-}" && -f "${IMAGE_SCAN_RESULTS}" ]]; then
  SCAN_FILES+=("${IMAGE_SCAN_RESULTS}")
  echo "Including image scan results: ${IMAGE_SCAN_RESULTS}"
fi

if [[ ${#SCAN_FILES[@]} -eq 0 ]]; then
  echo "No scan result files found. Setting empty outputs."
  {
    echo "cve-list=[]"
    echo "cve-count=0"
    echo "cve-summary=No scan results available"
  } >> "${GITHUB_OUTPUT}"
  exit 0
fi

# --- Extract and deduplicate CVEs across all scan files ---
# Build a jq filter that maps severity to level and filters >= MIN_LEVEL
CVE_JSON=$(jq -n \
  --argjson min_level "${MIN_LEVEL}" \
  --slurpfile files <(cat "${SCAN_FILES[@]}") \
  '
  def sev_level:
    if . == "Critical" then 5
    elif . == "High" then 4
    elif . == "Medium" then 3
    elif . == "Low" then 2
    elif . == "Negligible" then 1
    else 0
    end;

  [ $files[] | .matches[]? |
    select(.vulnerability.severity | sev_level >= $min_level) |
    {
      id: .vulnerability.id,
      severity: .vulnerability.severity,
      package: .artifact.name,
      version: .artifact.version,
      fixed_version: (.vulnerability.fix.versions // [] | join(", ")),
      link: (.vulnerability.dataSource // "")
    }
  ] | unique_by(.id + .package + .version)
  | sort_by(
      (if .severity == "Critical" then 0
       elif .severity == "High" then 1
       elif .severity == "Medium" then 2
       elif .severity == "Low" then 3
       elif .severity == "Negligible" then 4
       else 5 end),
      .id
    )
  '
)

CVE_COUNT=$(echo "${CVE_JSON}" | jq 'length')

# --- Build summary ---
CRITICAL_COUNT=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity == "Critical")] | length')
HIGH_COUNT=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity == "High")] | length')
MEDIUM_COUNT=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity == "Medium")] | length')
LOW_COUNT=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity == "Low")] | length')
UNKNOWN_COUNT=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity != "Critical" and .severity != "High" and .severity != "Medium" and .severity != "Low")] | length')

SUMMARY_PARTS=()
if [[ ${CRITICAL_COUNT} -gt 0 ]]; then SUMMARY_PARTS+=("${CRITICAL_COUNT} Critical"); fi
if [[ ${HIGH_COUNT} -gt 0 ]]; then SUMMARY_PARTS+=("${HIGH_COUNT} High"); fi
if [[ ${MEDIUM_COUNT} -gt 0 ]]; then SUMMARY_PARTS+=("${MEDIUM_COUNT} Medium"); fi
if [[ ${LOW_COUNT} -gt 0 ]]; then SUMMARY_PARTS+=("${LOW_COUNT} Low"); fi
if [[ ${UNKNOWN_COUNT} -gt 0 ]]; then SUMMARY_PARTS+=("${UNKNOWN_COUNT} Unknown/Negligible"); fi

if [[ ${CVE_COUNT} -eq 0 ]]; then
  SUMMARY="No CVEs found at or above the configured severity threshold"
else
  DETAIL=$(IFS=', '; echo "${SUMMARY_PARTS[*]}")
  SUMMARY="Found ${CVE_COUNT} CVE(s): ${DETAIL}"
fi

echo "${SUMMARY}"

# --- Write outputs ---
# GitHub Actions has a 1MB limit on output values. Truncate if needed.
CVE_JSON_SIZE=${#CVE_JSON}
MAX_OUTPUT_SIZE=1000000

if [[ ${CVE_JSON_SIZE} -gt ${MAX_OUTPUT_SIZE} ]]; then
  echo "::warning::CVE list exceeds 1MB output limit (${CVE_JSON_SIZE} bytes). Truncating to Critical and High only."
  CVE_JSON=$(echo "${CVE_JSON}" | jq '[.[] | select(.severity == "Critical" or .severity == "High")]')
  TRUNCATED_COUNT=$(echo "${CVE_JSON}" | jq 'length')
  SUMMARY="${SUMMARY} (output truncated to ${TRUNCATED_COUNT} Critical/High CVEs due to size limits)"
fi

# Use delimiter syntax for multi-line output
{
  DELIM="EOF_$(date +%s%N)"
  echo "cve-list<<${DELIM}"
  echo "${CVE_JSON}"
  echo "${DELIM}"
  echo "cve-count=${CVE_COUNT}"
  echo "cve-summary=${SUMMARY}"
} >> "${GITHUB_OUTPUT}"

# --- Write step summary ---
{
  echo "## Container Security Scan Results"
  echo ""
  echo "${SUMMARY}"
  echo ""
  if [[ ${CVE_COUNT} -gt 0 ]]; then
    echo "| Severity | CVE ID | Package | Version | Fixed Version |"
    echo "|----------|--------|---------|---------|---------------|"
    # Limit table to first 100 rows for readability
    echo "${CVE_JSON}" | jq -r '
      .[:100][] |
      "| \(.severity) | [\(.id)](\(.link)) | \(.package) | \(.version) | \(.fixed_version // "N/A") |"
    '
    if [[ ${CVE_COUNT} -gt 100 ]]; then
      echo ""
      echo "*Showing first 100 of ${CVE_COUNT} CVEs. See the cve-list output for the full list.*"
    fi
  fi
} >> "${GITHUB_STEP_SUMMARY}"
