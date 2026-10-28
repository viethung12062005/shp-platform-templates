# shp-platform-templates

Template dùng chung cho Smart Hospital Platform: **chart Helm `microservice`** và **reusable workflow** của GitHub Actions. Mỗi service có pipeline riêng
nhưng gọi các template này để đồng nhất kiểm tra. Quyết định: ADR-0009, ADR-0010, ADR-0011 trong repo ứng dụng.

## Nội dung
| Đường dẫn | Mục đích |
|---|---|
| `charts/microservice/` | Chart cho mọi service: Deployment hoặc Argo Rollout (canary), HPA/KEDA, PDB, NetworkPolicy, HTTPRoute, Workload Identity, Key Vault CSI. Bảo mật mặc định mức *restricted* |
| `.github/workflows/java-ci.yml` | Maven `-pl <modules> -am verify`: Spotless check, build `-Werror`, test (Testcontainers), JaCoCo ≥ ngưỡng |
| `.github/workflows/python-ci.yml` | (service ai, ml) ruff, mypy, pytest + coverage, pip-audit |
| `.github/workflows/container.yml` | hadolint → build → Trivy (chặn HIGH/CRITICAL) → SBOM → push ACR (OIDC) → ký cosign |
| `.github/workflows/helm-validate.yml` | `helm lint --strict`, render, kubeconform (kể cả CRD), Trivy config |
| `.github/workflows/terraform-checks.yml` | `fmt`, `validate`, tflint, Trivy config (không `apply`) |
| `.github/workflows/pr-checks.yml` | gitleaks, actionlint, dependency review |
| `.github/workflows/gitops-promote.yml` | Cập nhật digest image trong repo GitOps (commit cho UAT, PR cho prod). Deploy thật do Argo CD |
| `.github/workflows/release-chart.yml` | Tag `chart-vX.Y.Z` → đẩy chart lên ACR (OCI) |
| `examples/svc-scheduling.yml` | Mẫu workflow riêng của một service |

## Cách dùng
Service gọi bằng `uses: viethung12062005/shp-platform-templates/.github/workflows/<file>@<tag>` (xem `examples/`). **Luôn ghim theo tag/SHA**, không dùng `@main`, để thay đổi template không làm vỡ mọi service cùng lúc.
Bật *Settings → Actions → Access → Accessible from repositories owned by the user* nếu repo này private.

## Nguyên tắc bảo mật
- Mọi action bên thứ ba được **ghim theo commit SHA** (ghi chú phiên bản bên cạnh); Dependabot đề xuất nâng cấp. Công cụ tải về (kubeconform, actionlint) kiểm **checksum**; Trivy chạy bằng image **ghim theo digest**.
- Không có secret trong repo. Đăng nhập Azure bằng **OIDC federated credential**; GitHub App bot chỉ có quyền ghi vào repo GitOps.
- Workflow khai báo `permissions` tối thiểu; `id-token: write` chỉ ở job cần.
- Chữ ký cosign dùng chế độ *keyless* (Sigstore công khai): metadata chữ ký, gồm tên repo, được ghi vào nhật ký minh bạch công khai kể cả khi repo private. Cluster xác minh chữ ký bằng Kyverno (GOP-07).

## Kiểm thử chart
Các bộ giá trị trong `charts/microservice/ci/` được thử ở CI (`helm-validate`). Thêm tính năng cho chart thì thêm một bộ giá trị tương ứng.

## Trạng thái
Đã kiểm bằng `helm lint --strict`, `kubeconform --strict` (kèm CRD Argo Rollouts, KEDA, Gateway API, Secrets Store) và `actionlint` + `shellcheck`.
**Chưa chạy trên GitHub Actions thật** (cần repo, OIDC, ACR): kiểm ở task ENV-05.
