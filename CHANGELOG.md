# Changelog

[//]: # (## Upcoming)

[//]: # (### Added/Changed:)

[//]: # (### Fixes:)

[//]: # (### Deprecated/Removed:)

## [ 2024/10/26 - v0.1.0 ]

### Added/Changed:

* switch to grype and syft for sbom and scans

## [ 2024/08/30 - v0.0.4 ]

### Added/Changed:

* updated modules

## [ 2024/05/04 - v0.0.3 ]

### Added/Changed:

* updated modules

## [ 2024/01/27 - v0.0.2 ]

### Added/Changed:

* Changed aws- prefixed to s3-prefixed to remove any confusion around aws requirement
* Updated action versions
* Added step to determine the repo type based on the repo name. If there is no period, it's presumed a DockerHub registry

### Removed
* removed `use-dockerhub` as it's determined based on the repo-name.

## [ 2024/01/23 - v0.0.1 ]

### Added/Changed:

* Added Trivy for SBOM creation and scanning
* Added ability to provide a `.trivyignore` file to bypass particular CVE checks
* Only fixed vulns will cause a failure, unfixed will appear in a report
* Image signing done via cosign
* Added optional tlog uploads for cosign
