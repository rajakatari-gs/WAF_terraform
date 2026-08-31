# WAF Terraform Migration Plan

## Ownership Split

| Resource | Managed by |
|----------|-----------|
| Web ACL | Terraform |
| Web ACL Associations | Terraform |
| Web ACL Logging Configuration | Terraform |
| IP Sets | AWS Console only |
| Regex Pattern Sets | AWS Console only |

IP sets and regex pattern sets are **never** created, modified, imported, or destroyed by Terraform. Terraform reads their ARNs at plan time using `data` source lookups and passes them into rule statements.

## Phase Sequence

```
Discovery → Backup → TF Config + Data Sources → Import Web ACL → Plan Verify → Production Management
```

| Phase | Action | Safe? |
|-------|--------|-------|
| 1 | Run discover_waf.sh per environment | Read-only, 100% safe |
| 2 | Review backup JSON files | Read-only, 100% safe |
| 3 | Populate main.tf rules and imports.tf (Web ACL only) | Local files only, 100% safe |
| 3a | Add `data` source blocks for each console-managed regex pattern set / IP set used by rules; fill `id` from AWS Console | Local files only, 100% safe |
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
- [ ] No Web ACL recreation
- [ ] No association changes
- [ ] All `data` source `id` fields contain real UUIDs (no `REPLACE_WITH_...` placeholders)
- [ ] Data source lookups resolve without error during `terraform plan`
- [ ] Change reviewed and approved by manager/tech lead
- [ ] Rollback plan documented and ready

## Environment → Region Mapping

| Environment | AWS Region   | State Key               |
|-------------|-------------|-------------------------|
| stage       | us-east-1   | waf/stage/terraform.tfstate    |
| us1-prod    | us-east-1   | waf/us1-prod/terraform.tfstate |
| us2-prod    | us-west-2   | waf/us2-prod/terraform.tfstate |
| eu-prod     | eu-west-1   | waf/eu-prod/terraform.tfstate  |

## Data Source Pattern (for console-managed resources)

When a WAF rule references a regex pattern set or IP set, add a `data` source block to the environment's `main.tf`:

```hcl
data "aws_wafv2_regex_pattern_set" "xss_custom_latest" {
  name  = "XSS_CUSTOM_LATEST"
  id    = "<UUID from AWS Console>"  # Console → WAF → Regex pattern sets → click set → ID
  scope = "REGIONAL"
}
```

Reference the ARN in the rule:
```hcl
arn = data.aws_wafv2_regex_pattern_set.xss_custom_latest.arn
```

No import block is needed — the resource is not in Terraform state.

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
