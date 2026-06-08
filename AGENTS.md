# OpenShift Builds Release Tooling

Konflux release infrastructure — kustomize templates, Tekton pipelines, and scripts for managing OpenShift Builds release streams.

## Architecture

- `ReleaseLocal/` — kustomize overlays for Konflux resources (Application, Component, ImageRepository, ReleasePlanAdmission) per version
- `pipelines/` — Tekton pipeline definitions (build, E2E, release pipelines)
- `tasks/` — reusable Tekton task definitions
- `scripts/` — helper scripts (snapshot generation, task bundle updates)
- `docs/` — design specs

This is a pure infrastructure repo — no application code. It defines how Konflux builds, tests, and releases OpenShift Builds operator and catalog images.

## Build & Test Commands

- Install kustomize: `make kustomize`
- Update task bundles: `make update-pipelines`

No tests or lint — validation is done by Konflux when resources are applied to the cluster.

## Key Conventions

- **Kustomize overlays per version** — each release version has its own overlay in `ReleaseLocal/` with version-specific Application, Component, and RPA definitions.
- **Pipeline files are version-scoped** — pipeline YAML files reference specific applications and components by version (e.g., `openshift-builds-1-8`). Update labels and annotations when copying pipelines to a new version.
- **Release branches** follow `builds-X.Y` naming convention.
- **Never hand-edit generated kustomize output** — modify the overlays and re-run kustomize.

## PR Conventions

- **Commit flags:** always use `-s` (sign-off) and `-S` (GPG sign)
- **Commit format:** `[BUILD-XXXX] scope: description` — Jira key prefix in brackets, conventional commit style
- **PR title:** `[BUILD-XXXX] scope: description`
- **PR body:** `## Summary` header with bullet points, ends with `Co-Authored-By: Claude Code`
- **Fork-aware push:** detect fork vs upstream for `gh pr create --head` flag
- **One commit per PR:** amend and force push — no references to incremental changes
