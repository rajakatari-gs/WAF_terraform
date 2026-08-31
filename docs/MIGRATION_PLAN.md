# WAF Terraform Migration Plan

## Phase Sequence

```
Discovery → Backup → TF Config → Import → Plan Verify → Production Management
```

| Phase | Action | Safe? |
|-------|--------|-------|
| 1 | Run discover_waf.sh per environment | Read-only, 100% safe |
| 2 | Review backup JSON files | Read-only, 100% safe |
| 3 | Populate main.tf and imports.tf | Local files only, 100% safe |
| 4 | terraform init + terraform plan (no apply) | Read-only, 100% safe |
| 5 | terraform apply with import blocks | Writes state only, no infra changes |
| 6 | Verify zero-change plan | Read-only, 100% safe |
| 7 | Future changes via PR + plan review | Managed, auditable |

## Pre-Apply Checklist (run before any `terraform apply`)

- [ ] `discover_waf.sh` run and backup saved for this environment
- [ ] `terraform validate` passes with 0 errors
- [ ] `terraform plan` reviewed by at least one engineer
- [ ] Plan shows **0 resources to add, change, or destroy**
- [ ] No rule action changes (ALLOW → BLOCK, etc.)
- [ ] No rule priority changes
- [ ] No IP set recreation
- [ ] No Web ACL recreation
- [ ] No association changes
- [ ] Change reviewed and approved by manager/tech lead
- [ ] Rollback plan documented and ready

## Environment → Region Mapping

| Environment | AWS Region   | State Key               |
|-------------|-------------|-------------------------|
| stage       | us-east-1   | waf/stage/terraform.tfstate    |
| us1-prod    | us-east-1   | waf/us1-prod/terraform.tfstate |
| us2-prod    | us-west-2   | waf/us2-prod/terraform.tfstate |
| eu-prod     | eu-west-1   | waf/eu-prod/terraform.tfstate  |

## Rollback

If `terraform plan` shows unexpected changes **stop immediately** and do NOT apply.

Steps:
1. Do not run `terraform apply`.
2. Identify the diff between `terraform plan` output and the live AWS config.
3. Correct the Terraform HCL in `main.tf` to match the live config exactly.
4. Re-run `terraform plan` until it shows 0 changes.
5. Only then proceed.

If Terraform state was accidentally applied and resources changed:
1. Use AWS Console to restore the previous Web ACL configuration.
2. Use the backup JSON in `terraform/backups/<env>/` as the source of truth.
3. Re-import the corrected resources.
