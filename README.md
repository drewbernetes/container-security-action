# Container Security Scan :lock:

<!-- action-docs-header source="action.yml" -->

<!-- action-docs-header source="action.yml" -->

<!-- action-docs-description source="action.yml" -->
## Description

Generally speaking when scanning a container you should generate an SBOM and then scan the resulting
image to ensure you know exactly what vulnerabilities exist within the image and any packages used within it.

This action enables that process. On top of that, it signs the image
with [Sigstore Cosign](https://github.com/sigstore/cosign) so that you can validate the image and be confident the one
you're using is the one you built, as you built it.

Whilst nothing can catch everything, this gives a decent view of what is going on within an image.

## Why?

Some container registries provide scanning and signing support as part and parcel of their service. However, some do
not. This action provides consistency and enables the scanning and signing of your containers during the build process,
not after the push.

## Scanning with Trivy

Trivy is used to scan the images and
a [trivyignore](https://aquasecurity.github.io/trivy/v0.22.0/vulnerability/examples/filter/#by-vulnerability-ids) file
can be supplied to ignore certain CVEs if desired.

If you wish to use a trivyignore file, then you can store it in the repo that calls this action.
Make sure you run `actions/checkout@v4` before calling this action and pass the `trivyignore-file` input parameter.
It will automatically be used if the S3 option isn't explicitly enabled.

For example:

  ```yaml
steps:
    - name: Checkout Repo
      uses: actions/checkout@v4
      - name: Build, Scan and Sign Image
        uses: drewbernetes/container-security-action@v0.0.4
        with:
          image-repo: "drewviles"
          repo-username: ${{ secrets.DOCKER_USER }}
          repo-password: ${{ secrets.DOCKER_PASSWORD }}
          image-name: "csa-demo"
          image-tag: "1.0"
          check-severity: "HIGH,CRITICAL"
          trivyignore-file: "trivyignore"
          add-latest-tag: "true"
          publish-image: "true"
          cosign-private-key: ${{secrets.COSIGN_KEY}}
          cosign-password: ${{secrets.COSIGN_PASSWORD}}
          cosign-tlog: false
          dockerfile-path: .
  ```

  If you wish to use the S3 approach, to prevent constantly pushing updated trivyignore files to the source repo, then you
can supply the following:

  ```yaml
steps:
    - name: Build, Scan and Sign Image
      uses: drewbernetes/container-security-action@v0.0.4
      with:
        image-repo: "your-registry.example.com/some-project"
        repo-username: ${{ secrets.REGISTRY_PUBLIC_USER }}
        repo-password: ${{ secrets.REGISTRY_PUBLIC_PASSWORD }}
        image-name: "csa-demo"
        image-tag: "1.0"
        check-severity: "MEDIUM,HIGH,CRITICAL"
        trivyignore-from-s3: true
        s3-endpoint: "https://s3.example.com"
        s3-access-key: ${{secrets.S3_ACCESS_KEY}}
        s3-secret-key: ${{secrets.S3_SECRET_KEY}}
        s3-bucket: "trivyignores"
        s3-path: "image-ignorefile"
        add-latest-tag: "false"
        publish-image: "true"
        cosign-private-key: ${{secrets.COSIGN_KEY}}
        cosign-password: ${{secrets.COSIGN_PASSWORD}}
        cosign-tlog: true
        dockerfile-path: .
  ```

  If you also supply the `trivyignore-file` input when using the above, then this will be used as the resulting filename
  when the trivyignore file is pulled from s3. It won't use any file in the source repo as S3 overrides local trivyignore
  files.

  ## Signing images with Cosign

  The Cosign image signing works by using the standard process used by Cosign.
  You will need to generate
  the [Cosign keys as described in their documentation](https://docs.sigstore.dev/key_management/overview/) and store
  these as a secret in GitHub.
  This can then be supplied via the `cosign-private-key` and `cosign-password` inputs.

  ## Publishing Results

  The resulst of the scan will be uploaded as artifacts within the repo however, if you have it enabled, you can have 
  this pushed to the GitHub Dependency graph instead by adding the following input parameters:
  
  ```
  enable-dependency-graph: true
  dependency-graph-token: ${{ secrets.GITHUB_TOKEN }}
  ```

  **Hardware token verification is currently not supported.**
  ## TODO (AKA nice to haves but may not come!):

  * Support dynamic key generation for Cosign.
  * Support OIDC cosign signing.
  * Support adding to Rekor (currently does not do this by default to prevent any private images being added when the user
  may not want this to happen)
<!-- action-docs-description source="action.yml" -->

<!-- action-docs-usage source="action.yml" project="<baski-action>" version="<v0.0.4>" -->
## Usage

```yaml
- uses: <baski-action>@<v0.0.4>
  with:
    image-repo:
    # The repo to push the image to. This should just be the base url, eg: my-repo or ghcr.io or, if using DockerHub, just the username you'd usually use for your repo.
    #
    # Required: true
    # Default: ""

    repo-username:
    # The username to log into the repo.
    #
    # Required: true
    # Default: ""

    repo-password:
    # The password to log into the repo.
    #
    # Required: true
    # Default: ""

    image-name:
    # The name of the image to build.
    #
    # Required: true
    # Default: ""

    image-tag:
    # The tag to build the image with - provide a matrix to build against multiple tags as each will need to be SBOM'd, scanned and signed independently.
    #
    # Required: true
    # Default: ""

    add-latest-tag:
    # Adds the latest tag to the build.
    #
    # Required: false
    # Default: false

    cosign-private-key:
    # A private key with which to sign the image using cosign.
    #
    # Required: true
    # Default: ""

    cosign-password:
    # The password to unlock the private key.
    #
    # Required: true
    # Default: ""

    cosign-tlog:
    # Set to true to upload to tlog for transparency.
    #
    # Required: false
    # Default: false

    publish-image:
    # If true the image will be published to the repo.
    #
    # Required: false
    # Default: false

    check-severity:
    # A comma deliminated (uppercase) list of severities to check for. If found the pipeline will fail. Support values: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
    #
    # Required: false
    # Default: high

    sbom-fail-on-detection:
    # Must be 0 to succeed or any other number to fail if a severity is discovered at the `check-severity` level. This will be used as the exit code for the Trivy SBOM scan and 1 is recommended to differentiate it from the scan exit code.
    #
    # Required: false
    # Default: 1

    scan-fail-on-detection:
    # Must be 0 to succeed or any other number to fail if a severity is discovered at the `check-severity` level. This will be used as the exit code for the Trivy scan and 2 is recommended to differentiate it from the SBOM exit code.
    #
    # Required: false
    # Default: 2

    trivyignore-file:
    # Supply a Trivy ignore file to ignore specific CVEs and prevent a pipeline failure.
    #
    # Required: false
    # Default: trivyignore

    trivyignore-from-s3:
    # If disabled, the trivyignore can be supplied via the repo itself but actions/checkout@v4 must be used before calling this action.
    #
    # Required: false
    # Default: false

    enable-dependency-graph:
    # Will upload the SBOM to GitHub Dependency Graph - you must enable this and enable write permissions on your workflow for this to work.
    #
    # Required: false
    # Default: false

    dependency-graph-token:
    # This can be a PAT or the GITHUB_TOKEN secret
    #
    # Required: false
    # Default: ""

    s3-endpoint:
    # If the endpoint isn't a standard AWS one, pass it in here.
    #
    # Required: false
    # Default: https://some-s3-endpoint.com

    s3-region:
    # The AWS Region.
    #
    # Required: false
    # Default: us-east-1

    s3-access-key:
    # The S3 access key.
    #
    # Required: false
    # Default: ""

    s3-secret-key:
    # The S3 secret key.
    #
    # Required: false
    # Default: ""

    s3-bucket:
    # The S3 bucket in which the trivyignore file is stored.
    #
    # Required: false
    # Default: trivy

    s3-path:
    # The path in the s3 bucket to the trivyignore file.
    #
    # Required: false
    # Default: trivyignore

    dockerfile-path:
    # Path to the Dockerfile (default {context}/Dockerfile).
    #
    # Required: false
    # Default: .
```
<!-- action-docs-usage source="action.yml" project="<baski-action>" version="<v0.0.4>" -->

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `image-repo` | <p>The repo to push the image to. This should just be the base url, eg: my-repo or ghcr.io or, if using DockerHub, just the username you'd usually use for your repo.</p> | `true` | `""` |
| `repo-username` | <p>The username to log into the repo.</p> | `true` | `""` |
| `repo-password` | <p>The password to log into the repo.</p> | `true` | `""` |
| `image-name` | <p>The name of the image to build.</p> | `true` | `""` |
| `image-tag` | <p>The tag to build the image with - provide a matrix to build against multiple tags as each will need to be SBOM'd, scanned and signed independently.</p> | `true` | `""` |
| `add-latest-tag` | <p>Adds the latest tag to the build.</p> | `false` | `false` |
| `cosign-private-key` | <p>A private key with which to sign the image using cosign.</p> | `true` | `""` |
| `cosign-password` | <p>The password to unlock the private key.</p> | `true` | `""` |
| `cosign-tlog` | <p>Set to true to upload to tlog for transparency.</p> | `false` | `false` |
| `publish-image` | <p>If true the image will be published to the repo.</p> | `false` | `false` |
| `check-severity` | <p>A comma deliminated (uppercase) list of severities to check for. If found the pipeline will fail. Support values: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL</p> | `false` | `high` |
| `sbom-fail-on-detection` | <p>Must be 0 to succeed or any other number to fail if a severity is discovered at the <code>check-severity</code> level. This will be used as the exit code for the Trivy SBOM scan and 1 is recommended to differentiate it from the scan exit code.</p> | `false` | `1` |
| `scan-fail-on-detection` | <p>Must be 0 to succeed or any other number to fail if a severity is discovered at the <code>check-severity</code> level. This will be used as the exit code for the Trivy scan and 2 is recommended to differentiate it from the SBOM exit code.</p> | `false` | `2` |
| `trivyignore-file` | <p>Supply a Trivy ignore file to ignore specific CVEs and prevent a pipeline failure.</p> | `false` | `trivyignore` |
| `trivyignore-from-s3` | <p>If disabled, the trivyignore can be supplied via the repo itself but actions/checkout@v4 must be used before calling this action.</p> | `false` | `false` |
| `enable-dependency-graph` | <p>Will upload the SBOM to GitHub Dependency Graph - you must enable this and enable write permissions on your workflow for this to work.</p> | `false` | `false` |
| `dependency-graph-token` | <p>This can be a PAT or the GITHUB_TOKEN secret</p> | `false` | `""` |
| `s3-endpoint` | <p>If the endpoint isn't a standard AWS one, pass it in here.</p> | `false` | `https://some-s3-endpoint.com` |
| `s3-region` | <p>The AWS Region.</p> | `false` | `us-east-1` |
| `s3-access-key` | <p>The S3 access key.</p> | `false` | `""` |
| `s3-secret-key` | <p>The S3 secret key.</p> | `false` | `""` |
| `s3-bucket` | <p>The S3 bucket in which the trivyignore file is stored.</p> | `false` | `trivy` |
| `s3-path` | <p>The path in the s3 bucket to the trivyignore file.</p> | `false` | `trivyignore` |
| `dockerfile-path` | <p>Path to the Dockerfile (default {context}/Dockerfile).</p> | `false` | `.` |
<!-- action-docs-inputs source="action.yml" -->
