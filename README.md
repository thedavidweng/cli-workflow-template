# cli-workflow-template

Reusable GitHub Actions workflows for app and CLI projects. One place to define common CI, release, and security scanning policy while each downstream project keeps its product-specific commands and metadata.

## Architecture

```
cli-workflow-template/              <- you are here
├── .github/workflows/
│   ├── go-ci.yml                   Go test + lint + snapshot
│   ├── go-release.yml              GoReleaser + cosign + SBOM
│   ├── go-codeql.yml               Go CodeQL security scanning
│   ├── tauri-ci.yml                Tauri frontend/Rust/build checks
│   ├── tauri-codeql.yml            Tauri Rust + JS/TS CodeQL scanning
│   └── template-check.yml          validates this template repo
│
canvas-cli/
├── .github/workflows/
│   ├── ci.yml                      uses: .../go-ci.yml@main
│   ├── release.yml                 uses: .../go-release.yml@main
│   └── codeql.yml                  uses: .../go-codeql.yml@main
│
OpenKara / OpenLoop/
├── .github/workflows/
│   ├── ci.yml                      uses: .../tauri-ci.yml@main
│   └── codeql.yml                  uses: .../tauri-codeql.yml@main
```

Downstream projects own triggers, release timing, secrets, and project metadata. This repo owns shared execution policy: consistent setup, security checks, lint/test/build ordering, and reusable release primitives where the project family is standardized enough.

## Workflows

### go-ci.yml

Test, lint, and build Go projects on every push and PR. Builds a GoReleaser snapshot on `main` after tests pass.

| Input | Default | Description |
|-------|---------|-------------|
| `os-matrix` | `["ubuntu-latest", "macos-latest", "windows-latest"]` | OS to test on |
| `enable-golangci-lint` | `true` | Run golangci-lint |
| `golangci-lint-version` | `latest` | golangci-lint version |
| `enable-gofmt` | `true` | Explicit gofmt check |
| `enable-race` | `true` | Race detector |
| `enable-snapshot` | `true` | GoReleaser snapshot build |

**Concurrency:** cancels in-progress runs on the same ref.

```yaml
jobs:
  ci:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-ci.yml@main
```

### go-release.yml

Release Go projects via GoReleaser on `v*` tag push. Includes cosign keyless signing, SBOM generation, pre-release tests, and Homebrew tap token verification.

| Input | Default | Description |
|-------|---------|-------------|
| `enable-syft` | `true` | Generate SBOM with syft |
| `enable-pre-release-test` | `true` | Run tests before GoReleaser |
| `enable-homebrew-verify` | `true` | Verify HOMEBREW_TAP_GITHUB_TOKEN |

**Permissions:** caller workflows must grant `contents: write` and `id-token: write`. GitHub does not let a called reusable workflow elevate the caller's token.

**Secrets:** `HOMEBREW_TAP_GITHUB_TOKEN`, `SCOOP_BUCKET_GITHUB_TOKEN` (both optional, inherited via `secrets: inherit`).

**Release policy lives here:** pre-release tests, cosign installation, syft installation, Homebrew token verification, and the GoReleaser invocation are centralized in this workflow. Downstream repos own when a release is triggered; this template owns how the release runs.

**GoReleaser config boundary:** downstream repos currently keep `.goreleaser.yaml` only for project metadata that has not been standardized yet, such as binary name, ldflags package, package names, and Homebrew formula or cask details. The intended end state is a template-owned GoReleaser config generated from a small metadata contract, so release behavior can change in one place.

```yaml
permissions:
  contents: write
  id-token: write

jobs:
  release:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-release.yml@main
    secrets: inherit
```

### go-codeql.yml

CodeQL security scanning for Go projects with `security-extended` queries.

| Input | Default | Description |
|-------|---------|-------------|
| `languages` | `go` | Language to scan |

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 0 * * 1"

permissions:
  security-events: write
  actions: read
  contents: read

jobs:
  analyze:
    uses: thedavidweng/cli-workflow-template/.github/workflows/go-codeql.yml@main
```

### tauri-ci.yml

Shared CI skeleton for Tauri 2 desktop apps. It centralizes the repeatable parts: workflow linting, pnpm/Node setup, Rust setup, dependency audit hooks, Cargo dependency policy, Linux Tauri packages, Rust cache wiring, and optional Tauri build validation.

| Input | Default | Description |
|-------|---------|-------------|
| `node-version` | `24` | Node.js version |
| `pnpm-version` | `10.33.2` | pnpm version |
| `rust-toolchain` | `stable` | Rust toolchain passed to `dtolnay/rust-toolchain` |
| `rust-os-matrix` | `["ubuntu-22.04", "macos-14"]` | OSes for Rust checks |
| `tauri-build-os-matrix` | `["ubuntu-22.04", "macos-14", "windows-latest"]` | OSes for optional Tauri build checks |
| `cargo-manifest-path` | `src-tauri/Cargo.toml` | Cargo manifest path |
| `cargo-workspace` | `./src-tauri -> target` | Rust cache workspace mapping |
| `linux-apt-packages` | Tauri WebKit/GTK build packages | Packages installed on Linux jobs |
| `project-prepare-command` | empty | Project-owned setup for models, sidecars, generated native assets, or runtime prep |
| `frontend-command` | `pnpm ci:frontend` | Project-owned frontend CI command |
| `rust-command` | `pnpm ci:rust` | Project-owned Rust CI command |
| `tauri-build-command` | `pnpm ci:tauri-build` | Project-owned Tauri build validation command |
| `enable-workflow-lint` | `true` | Run actionlint and zizmor |
| `enable-frontend` | `true` | Run the frontend job |
| `enable-cargo-deny` | `true` | Run cargo-deny |
| `enable-rust` | `true` | Run Rust checks |
| `enable-tauri-build` | `false` | Run cross-platform Tauri build validation |

**Tauri contract boundary:** this workflow owns the shared environment and check ordering. Each app owns its scripts. If a project needs ONNX Runtime, model downloads, sidecars, generated bindings, app-specific secrets, or platform-specific release packaging, put that logic behind the project commands rather than adding broad fallback behavior here.

**Permissions:** caller workflows must grant `contents: read`. If `enable-workflow-lint` stays enabled, also grant `security-events: write` so zizmor can upload SARIF results.

**Build dependency:** `enable-tauri-build: true` expects `enable-frontend`, `enable-cargo-deny`, and `enable-rust` to remain enabled. The final `validate` job fails when an enabled check is skipped or unsuccessful, so misconfigured callers fail visibly.

```yaml
jobs:
  ci:
    uses: thedavidweng/cli-workflow-template/.github/workflows/tauri-ci.yml@main
    with:
      project-prepare-command: pnpm prepare:sidecars
      frontend-command: pnpm ci:frontend
      rust-command: pnpm ci:rust
      tauri-build-command: pnpm ci:tauri-build
      enable-tauri-build: true
```

### tauri-codeql.yml

CodeQL security scanning for Tauri projects. The default matrix scans Rust with autobuild and JavaScript/TypeScript without autobuild.

| Input | Default | Description |
|-------|---------|-------------|
| `matrix` | Rust + JS/TS | JSON array of CodeQL `{ "language", "build-mode" }` objects |

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 0 * * 1"

permissions:
  security-events: write
  actions: read
  contents: read

jobs:
  analyze:
    uses: thedavidweng/cli-workflow-template/.github/workflows/tauri-codeql.yml@main
```

## Projects

| Project | Family | Shared workflows | Notes |
|---------|--------|------------------|-------|
| [canvas-cli](https://github.com/thedavidweng/canvas-cli) | Go CLI | `go-ci`, `go-release`, `go-codeql` | Binary: `canvas` |
| [zenodo-cli](https://github.com/thedavidweng/zenodo-cli) | Go CLI | `go-ci`, `go-release`, `go-codeql` | Binary: `zenodo` |
| [monarchmoney-cli](https://github.com/thedavidweng/monarchmoney-cli) | Go CLI | `go-ci`, `go-release`, `go-codeql` | Binary: `monarch` |
| [flickr-cli](https://github.com/thedavidweng/flickr-cli) | Go CLI | `go-ci`, `go-release`, `go-codeql` | Binary: `flickr` |
| [money](https://github.com/thedavidweng/money) | Go app | `go-codeql` | Website and app CI stay separate |
| [OpenKara](https://github.com/thedavidweng/OpenKara) | Tauri 2 app | planned: `tauri-ci`, `tauri-codeql` | Release, model/runtime, WinGet, and Flatpak stay project-owned |
| [OpenLoop](https://github.com/thedavidweng/OpenLoop) | Tauri 2 app | planned: `tauri-ci`, `tauri-codeql` | Release and sidecar packaging stay project-owned |

## Adding a Go Project

1. Add caller workflows for CI, release, and CodeQL.
2. Keep project metadata in the downstream repo until the GoReleaser metadata contract is standardized.
3. Add the project to the table above.

## Adding a Tauri Project

1. Add project scripts that match the Tauri contract:

```json
{
  "scripts": {
    "ci:frontend": "pnpm audit --audit-level=high && pnpm format:check && pnpm lint && pnpm test:coverage && pnpm build",
    "ci:rust": "cargo fmt --manifest-path src-tauri/Cargo.toml --check && cargo clippy --manifest-path src-tauri/Cargo.toml -- -D warnings && cargo test -q --manifest-path src-tauri/Cargo.toml",
    "ci:tauri-build": "pnpm tauri build --debug --no-bundle --ci"
  }
}
```

2. Add a caller workflow:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  security-events: write

jobs:
  ci:
    uses: thedavidweng/cli-workflow-template/.github/workflows/tauri-ci.yml@main
    with:
      enable-tauri-build: true
```

3. Add CodeQL:

```yaml
name: CodeQL
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 0 * * 1"

permissions:
  security-events: write
  actions: read
  contents: read

jobs:
  analyze:
    uses: thedavidweng/cli-workflow-template/.github/workflows/tauri-codeql.yml@main
```

4. Keep release workflows project-owned until a real shared Tauri release contract emerges.

## Shared Conventions

All projects using this template follow:

- **Caller ownership:** downstream repos own triggers, branch filters, secrets, and project metadata.
- **Template ownership:** this repo owns reusable setup, check ordering, security scanner choices, and standardized release primitives.
- **Go version:** from `go.mod` for Go workflows.
- **Tauri JavaScript runtime:** Node 24 and pnpm by default.
- **Tauri Rust manifest:** `src-tauri/Cargo.toml` by default.
- **Security scanning:** CodeQL uses `security-extended`; workflow linting uses actionlint and zizmor where enabled.
- **No hidden fallback behavior:** if a project needs generated assets, sidecars, runtimes, or release-specific secrets, expose that as a project command or caller workflow setting.

## Updating

To update shared CI behavior for all projects, edit the workflow file here. Changes take effect on the next push/PR in each consuming project.

```bash
# Example: upgrade pnpm across Tauri apps
# Change the default in tauri-ci.yml, then let callers pick it up on their next run.
```

## License

MIT
