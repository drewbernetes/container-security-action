# Container Security Scan :lock:

Generally speaking when scanning a container you should generate an SBOM, scan the SBOM and then scan the resulting
image to ensure you know exactly what vulnerabilities exist within the image and any packages used in it.

This action enables that process. On top of that, it signs the image
with [Sigstore Cosign](https://github.com/sigstore/cosign) so that you can validate the image and be confident the one
you're using is the one you built, as you built it.

Whilst nothing can catch everything, this gives a wide view of what is going on within an image.

## Scanning with Trivy

Trivy is used to scan the images and a trivyignore file can be supplied to ignore certain CVEs if desired.

If you wish to use a trivyignore file, then you can store it in the repo that calls this action.
Make sure you run `actions/checkout@v4` before calling this action and pass the `trivyignore-file` input parameter.
It will automatically be used if the S3 option isn't explicitly enabled.

For example:

```yaml
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v4
      - name: Build, Scan and Sign Image
        uses: drewbernetes/container-security-action@v0.0.1
        with:
          image-repo: ghcr.io
          repo-username: ${{ github.repository_owner }}
          repo-password: ${{ secrets.GITHUB_TOKEN }}
          image-name: csa-demo
          image-tag: "1.0"
          check-severity: CRITICAL
          trivyignore-file: "trivyignore"
          publish-image: true
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
      uses: drewbernetes/container-security-action@v0.0.1
      with:
        image-repo: ghcr.io
        repo-username: ${{ github.repository_owner }}
        repo-password: ${{ secrets.GITHUB_TOKEN }}
        image-name: csa-demo
        image-tag: "1.0"
        check-severity: CRITICAL
        trivyignore-from-s3: true
        aws-endpoint: "https://some-s3-endpoint.com"
        aws-region: "eu-west-1"
        aws-access-key: ${{secrets.AWS_ACCESS_KEY}}
        aws-secret-key: ${{secrets.AWS_SECRET_KEY}}
        s3-bucket: "BUCKET_NAME"
        s3-path: "path/to/some_trivyignore_file"
        publish-image: true
        cosign-private-key: ${{secrets.COSIGN_KEY}}
        cosign-password: ${{secrets.COSIGN_PASSWORD}}
        cosign-tlog: false
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

**Hardware token verification is currently not supported.**

## Inputs

| Name                   | Description                                                                                                                                                                                              | Required | Default                        |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|--------------------------------|
| image-repo             | The repo to push the image to. This should just be the base url, eg: my-repo or ghcr.io or, if using DockerHub, just the username you'd usually use for your repo (you must also specify use-dockerhub). | true     | -                              |
| repo-username          | The username to log into the repo.                                                                                                                                                                       | true     | -                              |
| repo-password          | The password to log into the repo.                                                                                                                                                                       | true     | -                              |
| image-name             | The name of the image to build.                                                                                                                                                                          | true     | -                              |
| image-tag              | The tag to build the image with.                                                                                                                                                                         | true     | -                              |
| add-latest-tag         | Adds a latest tag to the image                                                                                                                                                                           | true     | false                          |
| cosign-private-key     | A private key to sign the image using Cosign.                                                                                                                                                            | true     | -                              |
| cosign-password        | The password to unlock the private key.                                                                                                                                                                  | true     | -                              |
| cosign-tlog            | Set to true to upload to tlog for transparency.                                                                                                                                                          | false    | 'false'                        |
| publish-image          | If true, the image will be published to the repo.                                                                                                                                                        | false    | 'false'                        |
| check-severity         | Comma-delimited list of severities to check for.                                                                                                                                                         | false    | high                           |
| sbom-fail-on-detection | Exit code for Trivy SBOM scan.                                                                                                                                                                           | false    | "1"                            |
| scan-fail-on-detection | Exit code for Trivy scan.                                                                                                                                                                                | false    | "2"                            |
| trivyignore-file       | Trivy ignore file to prevent pipeline failure.                                                                                                                                                           | false    | "trivyignore"                  |
| trivyignore-from-s3    | Supply trivyignore via S3.                                                                                                                                                                               | false    | false                          |
| s3-endpoint            | Custom AWS S3 endpoint if not standard.                                                                                                                                                                  | false    | "https://some-s3-endpoint.com" |
| s3-region              | The AWS Region.                                                                                                                                                                                          | false    | "us-east-1"                    |
| s3-access-key          | The S3 access key.                                                                                                                                                                                       | false    | ""                             |
| s3-secret-key          | The S3 secret key.                                                                                                                                                                                       | false    | ""                             |
| s3-bucket              | The S3 bucket for trivyignore file.                                                                                                                                                                      | false    | "trivy"                        |
| s3-path                | The path in the S3 bucket to the trivyignore file.                                                                                                                                                       | false    | "trivyignore"                  |
| dockerfile-path        | Path to the Dockerfile.                                                                                                                                                                                  | false    | "."                            |

## TODO (AKA nice to haves but may not come!):

* Generate easy to read report for the scans to allow easy browsing of the scan results.
* Support dynamic key generation for Cosign.
* Support OIDC cosign signing.
* Support adding to Rekor (currently does not do this by default to prevent any private images being added when the user
  may not want this to happen)
