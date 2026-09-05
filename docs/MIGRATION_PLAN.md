# WAF Terraform Migration Plan

## Ownership Model

All WAF resources — Web ACLs, IP sets, and regex pattern sets — are **exclusively managed by Terraform**.  
Direct AWS Console changes are not permitted. Console changes will be overwritten on the next `terraform apply`.

## Phase Sequence

| Phase | Action | Risk |
|-------|--------|------|
| 1 | Run `discover_waf.sh` per environment | Read-only, zero risk |
| 2 | Review backup JSON and fill `main.tf` to match exactly | Local files only, zero risk |
| 3 | Fill import blocks in `imports.tf` with UUIDs from backups | Local files only, zero risk |
| 4 | `terraform init && terraform validate` | Read-only, zero risk |
| 5 | `terraform plan` — must show only imports, 0 changes | Read-only, zero risk |
| 6 | `terraform apply` — imports resources into state only | State write only, no infra changes |
| 7 | `terraform plan` again — must show 0 changes | Read-only, zero risk |
| 8 | Repeat for each environment: dev → stage → us1-prod → us2-prod → eu-prod | |

## Apply Order

```
dev → stage → us1-prod → us2-prod → eu-prod
```

Never apply to production without first validating in dev and stage.

## Module Rule Types

| Variable | Use Case |
|----------|----------|
| `regex_pattern_sets` + `regex_pattern_set_rules` | Rules matching regex patterns (XSS, SQLi, etc.) |
| `ip_sets` + `ip_set_rules` | Rules based on source IP address |
| `rules` | Managed rule groups, rate-based rules, geo-match, and any other rule type |

## Pre-Apply Checklist

- [ ] `discover_waf.sh` run and backup saved for this environment
- [ ] `terraform validate` passes with 0 errors
- [ ] `terraform plan` reviewed by at least two engineers
- [ ] Plan shows **0 resources to add, change, or destroy** (only imports on first run)
- [ ] No rule action changes (allow ↔ block ↔ count)
- [ ] No rule priority changes
- [ ] No Web ACL recreation (`-/+`)
- [ ] No regex pattern set recreation (`-/+`)
- [ ] No IP set recreation (`-/+`)
- [ ] No association or logging changes
- [ ] Plan output attached to the PR or change ticket
- [ ] Change approved by manager/tech lead
- [ ] dev + stage applied and validated before any production apply
- [ ] AWS Console open to monitor WAF metrics during apply

## Environment → Region Mapping

| Environment | AWS Region | State Key |
|-------------|-----------|-----------|
| dev | us-east-1 | `waf/dev/terraform.tfstate` |
| stage | us-east-1 | `waf/stage/terraform.tfstate` |
| us1-prod | us-east-1 | `waf/us1-prod/terraform.tfstate` |
| us2-prod | us-west-2 | `waf/us2-prod/terraform.tfstate` |
| eu-prod | eu-west-1 | `waf/eu-prod/terraform.tfstate` |

## Rollback

If `terraform plan` shows unexpected changes — **stop, do not apply**.

1. Read the plan carefully.
2. Fix `main.tf` to match the live configuration.
3. Re-run `terraform plan` until it is clean.
4. Only then proceed.

If an apply already ran and caused an unintended change:
1. Open the backup JSON in `terraform/backups/<env>/` as the source of truth.
2. Fix `main.tf` to restore the intended state.
3. Run `terraform plan` to verify the fix, then apply.
