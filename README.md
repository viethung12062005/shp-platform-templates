# shp-platform-templates

Shared templates for the Smart Hospital Platform: the **`microservice` Helm chart** and the **reusable GitHub Actions workflows**. Each service keeps its own
pipeline but calls these templates so the checks are the same everywhere. Decisions: ADR-0009, ADR-0010, ADR-0011 in the application repo.

## Contents
| Path | Purpose |
|---|---|
| `charts/microservice/` | Chart for every service: Deployment or Argo Rollout (canary), HPA/KEDA, PDB, NetworkPolicy, HTTPRoute, Workload Identity, Key Vault CSI. Security defaults at *restricted* |
| `.github/workflows/java-ci.yml` | Maven `-pl <modules> -am verify`: Spotless check, build with `-Werror`, tests (Testcontainers), JaCoCo >= threshold |
| `.github/workflows/python-ci.yml` | (ai, ml services) ruff, mypy, pytest + coverage, pip-audit |
| `.github/workflows/dependency-check-db.yml` | Builds/refreshes the OWASP Dependency-Check vulnerability database (NVD, CISA KEV, RetireJS) and saves it to the Actions cache; triggered on a schedule from the default branch. `pr-checks` uses the prebuilt copy with `--noupdate` |
| `.github/workflows/node-ci.yml` | (web app) prettier, eslint `--max-warnings=0`, tsc, vitest + coverage (thresholds in `vite.config.ts`), build, `npm audit` (production dependencies) |
| `.github/workflows/container.yml` | hadolint -> build -> Trivy (blocks HIGH/CRITICAL) -> SBOM -> push to ACR (OIDC) -> cosign sign |
| `.github/workflows/helm-validate.yml` | `helm lint --strict`, render, kubeconform (CRDs included), Trivy config |
| `.github/workflows/terraform-checks.yml` | `fmt`, `validate`, tflint, Trivy config (never `apply`) |
| `.github/workflows/pr-checks.yml` | gitleaks, actionlint, dependency review, OWASP Dependency-Check (see [Dependency-Check suppressions](#dependency-check-suppressions)) |
| `.github/workflows/pr-title.yml` | The PR title must follow `<story> (<task>): <description>` or `ENABLER (<task>): <description>` (docs/00-git-github.md §2.1 of the application repo); PRs opened by a bot are exempt. The caller runs on `pull_request` with `types: [opened, edited, synchronize, reopened]` |
| `.github/workflows/gitops-promote.yml` | Updates the image digest in the GitOps repo (commit for UAT, PR for prod). The actual deploy is done by Argo CD |
| `.github/workflows/release-chart.yml` | Tag `chart-vX.Y.Z` -> push the chart to ACR (OCI) |
| `examples/svc-scheduling.yml` | Example of a service's own workflow |

## How to use
A service calls a template with `uses: viethung12062005/shp-platform-templates/.github/workflows/<file>@<tag>` (see `examples/`). **Always pin by tag or SHA**, never `@main`, so a template change does not break every service at once.

### Releasing and upgrading
1. Change the template through a PR into `main` as usual. Repos that use the template are not affected yet.
2. Create the release tag: `git checkout main && git pull && git tag vX.Y.Z && git push origin vX.Y.Z`.
3. The `bump-consumers.yml` workflow opens the "Bump platform templates pin to vX.Y.Z" PR in `smart-hospital-platform`, `shp-gitops` and `shp-infra`. The CI of that PR is the trial run for the new version; the reviewer decides when to merge. Re-run it for an existing tag with `workflow_dispatch`.

This workflow only runs when a GitHub App is configured: the `TEMPLATE_BUMP_APP_ID` variable and the `TEMPLATE_BUMP_APP_PRIVATE_KEY` secret live in this repo. The App needs write access to `Contents`, `Pull requests` and `Workflows` on the three repos above (the `Workflows` permission is required because the PR changes files under `.github/workflows`). While the variable is missing, the workflow is skipped.
Turn on *Settings → Actions → Access → Accessible from repositories owned by the user* if this repo is private.

## Dependency-Check suppressions
The `dependency-check` job of `pr-checks.yml` fails the PR on any finding with CVSS >= 7 (`--failOnCVSS 7`). A repository can add a reviewed exception for a finding that is a false positive or cannot be fixed yet: put a
[`dependency-check-suppressions.xml`](https://jeremylong.github.io/DependencyCheck/general/suppression.html) at the **root of the calling repository**. When the file exists the job passes `--suppression /src/dependency-check-suppressions.xml`; when it does not, the command is unchanged. The threshold is not lowered.

Rules for each `<suppress>`: match one package (`<packageUrl>`) or one vulnerability name, never a blanket suppression; give the reason in `<notes>` (why it does not apply, the review date, the condition to remove it); set the `until` attribute so the exception lapses by itself and the finding fails the gate again. The file is reviewed like code (CODEOWNERS). Changing the job is a template change: release a new tag and bump the callers' pin.

## Security principles
- Every third-party action is **pinned by commit SHA** (with the version noted next to it); Dependabot proposes upgrades. Downloaded tools (kubeconform, actionlint) are **checksum**-verified; Trivy runs from an image **pinned by digest**.
- No secrets in the repo. Azure sign-in uses an **OIDC federated credential**; the GitHub App bot can only write to the GitOps repo.
- Workflows declare minimal `permissions`; `id-token: write` only on the job that needs it.
- cosign signatures are *keyless* (public Sigstore): the signature metadata, including the repo name, is written to a public transparency log even when the repo is private. The cluster verifies signatures with Kyverno (GOP-07).

## Testing the chart
The value sets under `charts/microservice/ci/` are exercised in CI (`helm-validate`). When you add a chart feature, add a matching value set.
The unit tests under `charts/microservice/tests/` run with [`helm-unittest`](https://github.com/helm-unittest/helm-unittest); run them with `helm unittest charts/microservice --strict`.

## Status
Checked with `helm lint --strict`, `kubeconform --strict` (with the Argo Rollouts, KEDA, Gateway API and Secrets Store CRDs) and `actionlint` + `shellcheck`.
**Not yet run on real GitHub Actions** (needs the repo, OIDC and ACR): that check is ENV-05.

## `microservice` chart: options for the web app

- `httpRoute.pathPrefixes`: several prefixes on one HTTPRoute (overrides `pathPrefix`). The Gateway API uses `[/fhir, /api]`, the web app keeps `/`.
- `configFiles`: mount a read-only file from a ConfigMap, for example the web app's runtime `config.json` (`ci/web-values.yaml`).
