#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'template validation failed: %s\n' "$1" >&2
  exit 1
}

grep -q 'uses: sigstore/cosign-installer@v4\.[0-9]\+\.[0-9]\+' .github/workflows/go-release.yml \
  || fail 'go-release.yml must pin sigstore/cosign-installer to an existing patch tag'

grep -q 'MIT License' LICENSE \
  || fail 'LICENSE must contain the MIT license text'

grep -q '^MIT$' README.md \
  || fail 'README license section must say MIT'

grep -q 'contents: write' README.md \
  || fail 'README release caller example must request contents: write'

grep -q 'id-token: write' README.md \
  || fail 'README release caller example must request id-token: write'

grep -q 'security-events: write' README.md \
  || fail 'README CodeQL caller example must request security-events: write'

grep -q 'Release policy lives here' README.md \
  || fail 'README must document the release policy boundary'

test -f .github/workflows/tauri-ci.yml \
  || fail 'tauri-ci.yml reusable workflow is required'

test -f .github/workflows/tauri-codeql.yml \
  || fail 'tauri-codeql.yml reusable workflow is required'

grep -q 'Reusable GitHub Actions workflows for app and CLI projects' README.md \
  || fail 'README must describe this repo as a general workflow template'

grep -q 'tauri-ci.yml' README.md \
  || fail 'README must document the Tauri CI workflow'

grep -q 'Tauri contract boundary' README.md \
  || fail 'README must document the Tauri contract boundary'

grep -q 'security-events: write' README.md \
  || fail 'README Tauri caller example must request security-events: write when workflow lint is enabled'

grep -q '^  validate:' .github/workflows/tauri-ci.yml \
  || fail 'tauri-ci.yml must expose a final validate job'
