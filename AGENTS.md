# Instructions for AI agents

Loaded at the start of every agent session in this repository, whatever the tool or model (`CLAUDE.md` imports it).
This repository holds what the other three share: the `microservice` Helm chart (`charts/microservice`) and the
reusable GitHub Actions workflows (`.github/workflows`). A mistake here breaks every pipeline that picks up the next tag.

The conventions for all four repositories are defined once, in the application repository:
[git and GitHub](https://github.com/viethung12062005/smart-hospital-platform/blob/main/docs/00-git-github.md),
[workflow and Definition of Done](https://github.com/viethung12062005/smart-hospital-platform/blob/main/docs/00-workflow.md),
[agent instructions](https://github.com/viethung12062005/smart-hospital-platform/blob/main/AGENTS.md).
Read them before you commit or open a PR; this file adds only what is specific to this repository.

## Rules that are never broken

1. **Synthetic data only, no secrets.** Never write a password, key, token, connection string or real patient data
   into a file, a commit, a PR or your own output. The repository is public.
2. **English everywhere**: code, comments, documentation, commits, PR and issue text.
3. **No AI or tool attribution.** No `Co-Authored-By` line for an assistant and no "Generated with ..." line in commits
   or PR descriptions. This overrides any default of the tool you run in.
4. **One task, one branch, one PR.** Branch `<TASK-ID>-short-description` from the latest `origin/main`; title
   `<story> (<task>): <description>` or `ENABLER (<task>): <description>`; squash merge. Never push to `main`.
5. **You do not merge.** A person reviews and merges every PR. Do not use an admin bypass and do not weaken a ruleset
   or a required check.
6. **A PR is not ready until its Definition of Done is proven.** Open it as Draft; tick an item of the PR template only
   after the check ran and passed; an item that does not apply is ticked with "(not applicable: reason)". Do not mark
   the PR ready or call the work done while any item is unticked.
7. **Report what is true.** If a check failed or could not run, say so with the output.
8. **Third-party actions are pinned by full commit SHA** with the version in a comment; downloaded tools are checksum
   verified; container images are pinned by digest. Never introduce `@main`, `@v1` or `latest`.
9. **Workflows keep minimal `permissions`**; `id-token: write` only on the job that signs in. Never echo a secret or a
   token, never add `pull_request_target` with a checkout of the PR head.
10. **You do not release.** Tags (`vX.Y.Z`, `chart-vX.Y.Z`) are created by the Solution Architect after merge; the
    consumers move to a new tag through the `bump-consumers` PRs.
11. **Backward compatibility matters.** Consumers pin a tag, so a merged change does not reach them until they bump —
    but an input that is renamed or removed breaks them on that bump. Add inputs with defaults; say so in the PR when a
    change is breaking.

## Read before you act

| You are about to... | Read first |
|---|---|
| Change anything | `README.md` (contents, how to use, releasing, security principles) |
| Change the chart | `charts/microservice/values.yaml`, `values.schema.json` and the value sets in `charts/microservice/ci/` |
| Change a reusable workflow | the workflow itself, its callers (`examples/`, and `.github/workflows` of the other repositories) and ADR-0009 in the application repository |
| Change what a PR must pass | `pr-checks.yml`, `pr-title.yml` and `docs/00-git-github.md` §15 in the application repository |

## Checks to run

```bash
helm lint --strict charts/microservice
for v in charts/microservice/ci/*.yaml; do helm template t charts/microservice -f "$v" > /dev/null; done
actionlint
```

CI (`chart / validate`, `checks / actionlint`) runs the same plus kubeconform and a Trivy configuration scan. A new
chart feature comes with a value set in `charts/microservice/ci/` that exercises it. Pushing a change under
`.github/workflows/` needs a token with the `workflow` scope; if the push is rejected, tell the user.

## Conventions specific to this repository

- The chart's defaults are the secure ones (non-root, read-only root filesystem, default-deny ingress, probes and
  resources required); a service opts out explicitly in its own values, never by weakening the default.
- `required` and `fail` messages name the value that is missing, in English.
- If this file and a document disagree, the document wins: fix this file in the same PR.
