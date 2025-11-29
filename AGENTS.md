# Repository Guidelines

## Project Structure & Module Organization
- Root Terraform module in `*.tf` files: `main.tf`, `variable.tf`, `locals.tf`, `providers.tf`, `versions.tf`, `data.tf`, `outputs.tf`.
- Templates and tooling:
  - `policies/` — IAM policy template(s) used by the module (`*.tftpl`).
  - `user-data/` — manager instance user‑data template(s) (`*.tftpl`).
  - `packer-image-builder/` — Packer AMI definition (`docker-ami.pkr.hcl`).
- This repo is a reusable module; no state files are committed. Consume from a root stack.

## Build, Test, and Development Commands
- Terraform formatting: `terraform fmt -recursive` (use `-check` in CI).
- Initialize providers: `terraform init` (in your root stack using this module). Provider constraint is **aws >= 5.72** because `aws_iam_role_policy_attachments_exclusive` is used; older providers will fail.
- Validate configuration: `terraform validate`.
- Plan changes: `terraform plan -var-file=env/dev.tfvars`.
- Apply changes: `terraform apply -var-file=env/dev.tfvars`.
- Packer image build: `cd packer-image-builder && packer init . && packer validate . && packer build docker-ami.pkr.hcl`.

## Coding Style & Naming Conventions
- Terraform HCL2, 2‑space indentation, 120‑char soft line limit.
- Use `snake_case` for variables, outputs, and locals. Prefer descriptive names: `asg_max_size`, `manager_ec2_type`.
- Group related inputs in `variable.tf` with `description` and sensible `default`s; document units.
- Derive values in `locals.tf`; avoid inline magic numbers. Reuse `name_prefix` for namespacing.
- Use `default_tags` (passed to the provider) for consistent tagging; avoid per-resource drift.
- Prefer `templatefile()` for rendered JSON/Shell in `policies/` and `user-data/`.
- Run `terraform fmt` before pushing.

## Testing Guidelines
- Required: `terraform validate` must pass; include `terraform plan` output in PR description.
- Optional static analysis: run `tflint` and/or `checkov` if available.
- For AMI changes, attach `packer validate` output and (optionally) a successful `packer build` log.

## Commit & Pull Request Guidelines
- Commits: imperative, concise subject lines (e.g., "Add S3 cache lifecycle").
- PRs must include: purpose/summary, linked issue, `plan` output (redacted), affected variables/outputs, and any AWS region/account context.
- For behavior changes, add before/after notes or screenshots/logs (e.g., ASG creation, manager instance user‑data).

## Security & Configuration Tips
- Never commit secrets or GitLab runner tokens; pass via `-var-file` or a secure secrets manager (e.g., SSM Parameter Store).
- Scope IAM minimally; review `policies/` changes carefully. Keep `default_tags` consistent across resources.
- If using S3 cache, set `s3_cache_expiration_days` per retention policy; verify bucket encryption and access policies in your root stack.
- IAM managed policy attachments are enforced exclusively via `aws_iam_role_policy_attachments_exclusive`; ensure any additional managed policies are included in `policy_arns` to avoid drift.
