# cli-workflow-template

Reusable GitHub Actions workflows for Go CLI projects.

## Workflows

### `go-ci.yml`

CI workflow with test, lint, and snapshot build.

```yaml
jobs:
  ci:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-ci.yml@main
```

**Defaults:**
- OS matrix: ubuntu, macos, windows
- golangci-lint v9
- gofmt check
- Race detector
- GoReleaser snapshot build (depends on test + lint)

### `go-release.yml`

Release workflow with GoReleaser, cosign signing, and SBOM generation.

```yaml
jobs:
  release:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-release.yml@main
    secrets: inherit
```

**Defaults:**
- Cosign keyless signing
- Syft SBOM generation
- Homebrew tap token verification
- Pre-release test run

### `go-codeql.yml`

CodeQL security scanning for Go projects.

```yaml
jobs:
  analyze:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-codeql.yml@main
```

**Defaults:**
- Language: Go
- Queries: security-extended
- Schedule: weekly (Monday)

## Usage

See the workflow files for available inputs. All inputs have sensible defaults — most projects can call the workflows with no parameters.

## Projects Using This

- [canvas-cli](https://github.com/thedavidweng/canvas-cli)
- [zenodo-cli](https://github.com/thedavidweng/zenodo-cli)
- [monarchmoney-cli](https://github.com/thedavidweng/monarchmoney-cli)
- [flickr-cli](https://github.com/thedavidweng/flickr-cli)
- [money](https://github.com/thedavidweng/money)

## License

BSD 2-Clause
