# Changelog

[//]: # (## Upcoming)

[//]: # (### Added/Changed:)

[//]: # (### Fixes:)

[//]: # (### Deprecated/Removed:)

## [ 2024/01/23 - v0.0.2 ]

### Added/Changed:

* Changed aws- prefixed to s3-prefixed to remove any confusion around aws requirement
* Updated action versions

## [ 2024/01/23 - v0.0.1 ]

### Added/Changed:

* Added Trivy for SBOM creation and scanning
* Added ability to provide a `.trivyignore` file to bypass particular CVE checks
* Only fixed vulns will cause a failure, unfixed will appear in a report
* Image signing done via cosign
* Added optional tlog uploads for cosign
