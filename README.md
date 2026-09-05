# Gainsight WAF — Terraform Management

End-to-end Infrastructure as Code management of AWS WAF across all Gainsight environments.  
**All changes to WAF rules, IP sets, and regex pattern sets must go through this repository. Direct AWS Console changes are not allowed.**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Environment Map](#environment-map)
4. [Prerequisites](#prerequisites)
5. [Rule Types Reference](#rule-types-reference)
6. [Initial Import Workflow (First-Time Setup)](#initial-import-workflow-first-time-setup)
   - [Step 1 — Configure AWS Credentials](#step-1--configure-aws-credentials)
   - [Step 2 — Configure S3 Backend](#step-2--configure-s3-backend)
   - [Step 3 — Discover Existing WAF Resources](#step-3--discover-existing-waf-resources)
   - [Step 4 — Fill Import Blocks](#step-4--fill-import-blocks)
   - [Step 5 — Initialize and Validate](#step-5--initialize-and-validate)
   - [Step 6 — Plan (Dry Run)](#step-6--plan-dry-run)
   - [Step 7 — Import (Apply)](#step-7--import-apply)
   - [Step 8 — Verify Zero-Change Plan](#step-8--verify-zero-change-plan)
   - [Step 9 — Repeat per Environment](#step-9--repeat-per-environment)
7. [Day-2 Operations — Making Changes](#day-2-operations--making-changes)
   - [Adding a Regex Pattern Set and Rule](#adding-a-regex-pattern-set-and-rule)
   - [Adding an IP Set and Rule](#adding-an-ip-set-and-rule)
   - [Adding a Managed Rule Group](#adding-a-managed-rule-group)
   - [Modifying an Existing Rule](#modifying-an-existing-rule)
   - [Removing a Rule](#removing-a-rule)
8. [PR and Deployment Workflow](#pr-and-deployment-workflow)
9. [Troubleshooting](#troubleshooting)
10. [Pre-Apply Production Checklist](#pre-apply-production-checklist)
11. [Rollback Plan](#rollback-plan)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    This Repository                          │
│                                                             │
│  environments/<env>/                                        │
│    ├── regex_rules.auto.tfvars  ← regex pattern sets+rules  │
│    ├── ip_rules.auto.tfvars     ← IP sets + IP rules        │
│    ├── managed_rules.auto.tfvars← managed groups, rate, geo │
│    └── main.tf                  ← module wiring only        │
│              │                                              │
│              └──► modules/waf/main.tf                       │
│                        │  creates & manages:                │
│                        ├── aws_wafv2_ip_set                 │
│                        ├── aws_wafv2_regex_pattern_set      │
│                        ├── aws_wafv2_web_acl                │
│                        ├── aws_wafv2_web_acl_association    │
│                        └── aws_wafv2_web_acl_logging_config │
└─────────────────────────────────────────────────────────────┘
                         │
                         │  terraform apply
                         ▼
              AWS WAF (live traffic)
```

### Key design decisions

| Decision | Reason |
|----------|--------|
| All resources owned by Terraform | Single source of truth; console changes cause drift detected at next plan |
| IP set and regex rule ARNs resolved inside the module | Avoids Terraform dependency cycles; no placeholder strings needed |
| One state file per environment | A mistake in one environment cannot affect any other |
| `type = any` for freeform rules | Supports all AWS WAF statement types without requiring module changes |

---

## Repository Structure

```
WAF_terraform/
├── README.md
├── docs/
│   └── MIGRATION_PLAN.md
└── terraform/
    ├── modules/
    │   └── waf/
    │       ├── main.tf        ← All resource logic + internal ARN resolution
    │       ├── variables.tf   ← All input variables with types and descriptions
    │       ├── outputs.tf     ← Web ACL ARN/ID, IP set ARNs, regex set ARNs
    │       └── imports.tf     ← Import ID format reference (no active blocks)
    ├── environments/
    │   ├── dev/               ← us-east-1, dev profile
    │   │   ├── provider.tf
    │   │   ├── main.tf                      ← module wiring, references var.*
    │   │   ├── variables.tf                 ← variable declarations for all rule types
    │   │   ├── regex_rules.auto.tfvars      ← regex pattern sets + rules
    │   │   ├── ip_rules.auto.tfvars         ← IP sets + IP rules
    │   │   ├── managed_rules.auto.tfvars    ← managed groups, rate-based, geo-match
    │   │   ├── outputs.tf
    │   │   └── imports.tf
    │   ├── stage/             ← us-east-1, stage profile  (same file layout as dev)
    │   ├── us1-prod/          ← us-east-1, prod profile   (same file layout as dev)
    │   ├── us2-prod/          ← us-west-2, prod profile   (same file layout as dev)
    │   └── eu-prod/           ← eu-west-1, prod profile   (same file layout as dev)
    ├── scripts/
    │   ├── discover_waf.sh    ← Read-only AWS CLI discovery + JSON backup
    │   └── validate_waf.sh    ← Post-import verification
    └── backups/
        ├── dev/
        ├── stage/
        ├── us1-prod/
        ├── us2-prod/
        └── eu-prod/
```

### Rule file responsibilities

| File | What goes here |
|------|---------------|
| `regex_rules.auto.tfvars` | XSS, SQLi, and any regex pattern-based rules |
| `ip_rules.auto.tfvars` | IP blocklists and IP-based allow/block rules |
| `managed_rules.auto.tfvars` | AWS managed rule groups, rate-based rules, geo-match |
| `main.tf` | Module config only — never edited for rule changes |
| `variables.tf` | Variable type declarations — never edited for rule changes |

---

## Environment Map

| Environment | AWS Region | AWS Profile | State Key |
|-------------|-----------|-------------|-----------|
| dev | us-east-1 | dev-profile | `waf/dev/terraform.tfstate` |
| stage | us-east-1 | stage-profile | `waf/stage/terraform.tfstate` |
| us1-prod | us-east-1 | prod-profile | `waf/us1-prod/terraform.tfstate` |
| us2-prod | us-west-2 | prod-profile | `waf/us2-prod/terraform.tfstate` |
| eu-prod | eu-west-1 | prod-profile | `waf/eu-prod/terraform.tfstate` |

Each environment has its own isolated S3 state file. An error in one environment cannot affect any other.

Apply order: **dev → stage → us1-prod → us2-prod → eu-prod**

---

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Terraform | >= 1.6 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | >= 2.x | `brew install awscli` |
| jq | any | `brew install jq` |

### AWS Permissions Required

**Discovery (read-only):**
- `wafv2:ListWebACLs`, `wafv2:GetWebACL`
- `wafv2:ListIPSets`, `wafv2:GetIPSet`
- `wafv2:ListRegexPatternSets`, `wafv2:GetRegexPatternSet`
- `wafv2:ListLoggingConfigurations`
- `wafv2:ListResourcesForWebACL`

**Apply (read + write):**
- All of the above plus:
- `wafv2:CreateWebACL`, `wafv2:UpdateWebACL`, `wafv2:DeleteWebACL`
- `wafv2:CreateIPSet`, `wafv2:UpdateIPSet`, `wafv2:DeleteIPSet`
- `wafv2:CreateRegexPatternSet`, `wafv2:UpdateRegexPatternSet`, `wafv2:DeleteRegexPatternSet`
- `wafv2:AssociateWebACL`, `wafv2:DisassociateWebACL`
- `wafv2:PutLoggingConfiguration`, `wafv2:DeleteLoggingConfiguration`
- `wafv2:TagResource`, `wafv2:ListTagsForResource`

---

## Rule Types Reference

The module supports three categories of rules. Choose the right one based on what you need.

### 1. `regex_pattern_set_rules` — regex pattern set references

Use when a rule checks request fields against a regex pattern set defined in `regex_pattern_sets`.

```hcl
regex_pattern_sets = {
  "MY_PATTERN_SET" = {
    description = "Describe what these patterns detect"
    patterns    = ["(?i)pattern1", "(?i)pattern2"]
  }
}

regex_pattern_set_rules = [
  {
    name                        = "MY_PATTERN_SET_RULE"
    priority                    = 10
    action                      = "count"   # allow | block | count | captcha | challenge
    regex_pattern_set_key       = "MY_PATTERN_SET"
    fields_to_match             = ["ALL_QUERY_ARGUMENTS", "JSON_BODY", "URI_PATH"]
    # Multiple fields → automatic or_statement. Single field → direct statement.
    json_body_match_scope       = "ALL"      # ALL | KEY | VALUE
    json_body_oversize_handling = "CONTINUE" # CONTINUE | MATCH | NO_MATCH
    text_transformations = [
      { priority = 0, type = "URL_DECODE_UNI" }
    ]
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "MY_PATTERN_SET_RULE"
      sampled_requests_enabled   = true
    }
  }
]
```

**Supported `fields_to_match` values:** `ALL_QUERY_ARGUMENTS`, `URI_PATH`, `QUERY_STRING`, `METHOD`, `JSON_BODY`

### 2. `ip_set_rules` — IP set references

Use when a rule allows or blocks requests based on source IP.

```hcl
ip_sets = {
  "BlocklistedIPs" = {
    description        = "IPs to block at the edge"
    ip_address_version = "IPV4"   # IPV4 or IPV6
    addresses          = ["1.2.3.4/32", "10.0.0.0/8"]
  }
}

ip_set_rules = [
  {
    name       = "BlocklistedIPs"
    priority   = 1
    action     = "block"
    ip_set_key = "BlocklistedIPs"
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlocklistedIPs"
      sampled_requests_enabled   = true
    }
  }
]
```

### 3. `rules` — freeform rules

Use for AWS managed rule groups, rate-based rules, geo-match rules, or any statement type not covered above.

```hcl
rules = [
  {
    name            = "AWSManagedRulesCommonRuleSet"
    priority        = 20
    override_action = { none = {} }   # none = use rule group's own actions
    statement = {
      managed_rule_group_statement = {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
]
```

---

## Initial Import Workflow (First-Time Setup)

Follow these steps the **first time** you bring an environment under Terraform control. The goal is to import existing AWS resources into Terraform state without modifying them.

> **Safety guarantee:** Steps 1–6 are read-only and cannot affect live traffic.  
> Step 7 writes to Terraform state only — it does **not** modify AWS infrastructure.

### Step 1 — Configure AWS Credentials

```bash
# Check your named profiles are configured
aws configure list-profiles

# Verify access for the target environment
aws sts get-caller-identity --profile stage-profile
```

### Step 2 — Configure S3 Backend

Open `terraform/environments/<env>/provider.tf` and replace the placeholder values:

```hcl
backend "s3" {
  bucket         = "your-actual-bucket-name"      # ← replace
  key            = "waf/stage/terraform.tfstate"  # ← keep as-is, unique per env
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "your-actual-lock-table"       # ← replace
}
```

### Step 3 — Discover Existing WAF Resources

Run the discovery script to read all existing WAF resources and save JSON backups.

```bash
cd terraform/scripts

# Usage: ./discover_waf.sh <env> <region> <aws-profile>
./discover_waf.sh stage    us-east-1 stage-profile
./discover_waf.sh dev      us-east-1 dev-profile
./discover_waf.sh us1-prod us-east-1 prod-profile
./discover_waf.sh us2-prod us-west-2 prod-profile
./discover_waf.sh eu-prod  eu-west-1 prod-profile
```

This writes read-only JSON snapshots to `terraform/backups/<env>/<timestamp>/`:

```
web_acls.json                     ← Lists all Web ACLs with Name, Id, ARN
web_acl_gainsight-waf-<env>.json  ← Full rule configuration for each ACL
ip_sets.json                      ← Lists all IP sets with Name, Id
ip_set_<name>.json                ← Addresses for each IP set
regex_pattern_sets.json           ← Lists all regex sets with Name, Id
regex_pattern_set_<name>.json     ← Patterns for each regex set
logging_configurations.json
associations_<arn>.json
```

**Important fields to copy from the JSON:**
- Web ACL: `WebACLs[].Id` → use in import block
- IP set: `IPSets[].Id` → use in import block
- Regex set: `RegexPatternSets[].Id` → use in import block

### Step 4 — Fill Import Blocks

Open `terraform/environments/<env>/imports.tf` and uncomment/fill the blocks for resources that already exist in AWS. Use the UUIDs from the backup JSON:

```hcl
import {
  to = module.waf.aws_wafv2_web_acl.this
  id = "gainsight-waf-stage/abc12345-1234-1234-1234-abcdef123456/REGIONAL"
}

import {
  to = module.waf.aws_wafv2_regex_pattern_set.this["XSS_CUSTOM_LATEST"]
  id = "XSS_CUSTOM_LATEST/bf22b1f5-5880-4b18-b0e5-c4838acfe4bf/REGIONAL"
}
```

**Import ID format:** `<resource-name>/<uuid>/REGIONAL`

Also fill in the `.auto.tfvars` files to match the backup JSON exactly:
- `regex_rules.auto.tfvars` — pattern strings and rule definitions (HCL requires `\\b` where the pattern uses `\b`)
- `ip_rules.auto.tfvars` — IP addresses must match exactly
- Rule names, priorities, and actions must all match what's live

### Step 5 — Initialize and Validate

```bash
cd terraform/environments/stage

terraform init
terraform validate
```

`validate` checks HCL syntax only. Fix any errors before proceeding.

### Step 6 — Plan (Dry Run)

```bash
terraform plan
```

`plan` is always read-only — it never modifies AWS. With import blocks active, the output will show resources being imported:

```
Plan: 2 to import, 0 to add, 0 to change, 0 to destroy.
```

If the plan shows **any** `to add`, `to change`, or `to destroy` in addition to the imports — **stop**. This means the HCL in `main.tf` does not match the live AWS configuration. Fix the mismatch before continuing.

### Step 7 — Import (Apply)

```bash
terraform apply
```

With import blocks in place, this reads the existing AWS resources and writes them into Terraform state. It does **not** create, modify, or delete anything in AWS.

### Step 8 — Verify Zero-Change Plan

Immediately after apply, run plan again:

```bash
terraform plan
```

Required result:

```
No changes. Your infrastructure matches the configuration.
```

If you see any changes — stop. Fix the HCL in `main.tf` and re-run plan until it is clean.

### Step 9 — Repeat per Environment

Repeat Steps 3–8 in this order:

```
dev → stage → us1-prod → us2-prod → eu-prod
```

Always fully validate dev and stage before touching any production environment.

---

## Day-2 Operations — Making Changes

Once all environments are imported and showing clean plans, all changes go through this repository.

> **The golden rule:** If you can make a change in the AWS Console, you can make it in this repo instead — and it will be tracked, reviewed, and reversible.

### Adding a Regex Pattern Set and Rule

Edit `environments/<env>/regex_rules.auto.tfvars`.

**1. Add the pattern set:**

```hcl
regex_pattern_sets = {
  "XSS_CUSTOM_LATEST" = { ... },   # existing

  "SQLI_CUSTOM" = {
    description = "Custom SQL injection detection"
    patterns = [
      "(?i)(union\\s+select|insert\\s+into|drop\\s+table)",
      "(?i)(exec\\s*\\(|execute\\s*\\(|sp_executesql)",
    ]
  }
}
```

**2. Add a rule referencing it:**

```hcl
regex_pattern_set_rules = [
  { ... },   # existing rules

  {
    name                        = "SQLI_CUSTOM"
    priority                    = 25
    action                      = "count"   # start with count, switch to block after monitoring
    regex_pattern_set_key       = "SQLI_CUSTOM"
    fields_to_match             = ["ALL_QUERY_ARGUMENTS", "URI_PATH"]
    text_transformations = [
      { priority = 0, type = "URL_DECODE_UNI" }
    ]
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "CUSTOM_SQLI"
      sampled_requests_enabled   = true
    }
  }
]
```

**3. Open a PR and run plan:** The plan will show exactly 2 new resources (the pattern set + the web ACL rule update).

**4. Apply dev → stage → prod** after plan review.

---

### Adding an IP Set and Rule

Edit `environments/<env>/ip_rules.auto.tfvars`.

```hcl
ip_sets = {
  "BLOCKED_IPS" = {
    description        = "Known malicious IPs"
    ip_address_version = "IPV4"
    addresses = [
      "1.2.3.4/32",
      "5.6.7.8/32",
    ]
  }
}

ip_set_rules = [
  {
    name       = "BLOCK_BAD_IPS"
    priority   = 1
    action     = "block"
    ip_set_key = "BLOCKED_IPS"
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "BLOCKED_IPS"
      sampled_requests_enabled   = true
    }
  }
]
```

To add an IP to an existing set, just add it to the `addresses` list and open a PR.

---

### Adding a Managed Rule Group

Edit `environments/<env>/managed_rules.auto.tfvars`.

```hcl
rules = [
  {
    name            = "AWSManagedRulesCommonRuleSet"
    priority        = 20
    override_action = { none = {} }
    statement = {
      managed_rule_group_statement = {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
]
```

Other common managed rule groups: `AWSManagedRulesBotControlRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, `AWSManagedRulesSQLiRuleSet`.

---

### Modifying an Existing Rule

To change a rule (e.g., change action from `count` to `block`):

1. Edit the relevant field in the appropriate `.auto.tfvars` file for that environment
2. Run `terraform plan` — verify the plan shows only that specific change
3. Open a PR with the plan output attached
4. Get approval, then apply dev → stage → prod

---

### Removing a Rule

Remove the rule from the appropriate `.auto.tfvars` file (`ip_rules`, `regex_rules`, or `managed_rules`). If removing a regex pattern set rule, also remove its entry from `regex_pattern_sets` in the same file and same PR.

`terraform plan` will show the deletion. Verify no other rules are affected before applying.

---

## PR and Deployment Workflow

```
Engineer edits the relevant *.auto.tfvars file for the target environment
  (regex_rules.auto.tfvars / ip_rules.auto.tfvars / managed_rules.auto.tfvars)
         │
         ▼
git commit + Pull Request
         │
         ▼
terraform plan run in CI (or manually), output added to PR description
         │
         ▼
Tech Lead / Manager reviews the plan line by line
         │
         ▼
PR approved and merged to main
         │
         ▼
terraform apply to dev
         │
         ▼
terraform apply to stage
         │
         ▼
Monitor CloudWatch WAF metrics for 10–15 minutes
         │
         ▼
terraform apply to us1-prod → us2-prod → eu-prod  (one at a time)
         │
         ▼
Monitor CloudWatch metrics after each production apply
```

**Rules:**
- Never apply to production without first applying and validating in dev and stage
- The PR plan output must show only the intended changes — no unrelated diffs
- One engineer applies; another monitors the CloudWatch WAF dashboard

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `plan` shows rule action change (e.g., COUNT → BLOCK) | HCL action doesn't match the live config | Fix `main.tf` to match the existing live value; change the action in a separate PR |
| `plan` shows rule priority change | Priority number doesn't match | Fix priority in `main.tf` to match the live value exactly |
| `plan` wants to recreate the Web ACL (`-/+`) | Import ID is wrong or pattern doesn't match | Check `imports.tf` UUID against backup JSON |
| `plan` wants to recreate a regex pattern set | Pattern string differs (often a backslash escaping issue) | HCL requires `\\b` for `\b`, `\\s` for `\s`. Compare with `regex_pattern_set_<name>.json` |
| `plan` wants to recreate an IP set | Address list or import ID differs | Compare `addresses` list with `ip_set_<name>.json` |
| `terraform apply` fails during import | Wrong UUID in import block | Re-run `discover_waf.sh` and compare UUIDs |
| `terraform validate` fails | HCL syntax error | Read the error message line number and fix in `main.tf` |
| `terraform init` fails (backend error) | S3 bucket or DynamoDB table name is wrong | Update `provider.tf` backend config |
| `No declaration found for var.X` | Module variables.tf not updated | Ensure `modules/waf/variables.tf` declares the variable |
| AWS Console shows configuration not matching Terraform | Someone made a console change | Run `terraform plan` to see the drift, then decide: revert console change or update Terraform |

---

## Pre-Apply Production Checklist

Complete every item before running `terraform apply` against **any** production environment.

**Discovery & config:**
- [ ] `discover_waf.sh` run and backup saved for this environment
- [ ] Backup JSON reviewed and compared with `main.tf` values
- [ ] `terraform validate` passes with 0 errors
- [ ] `terraform init` completed successfully

**Plan review:**
- [ ] `terraform plan` output reviewed line by line by at least two engineers
- [ ] Plan shows **0 resources to add, 0 to change, 0 to destroy** (only imports on first run)
- [ ] No unintended rule action changes (allow ↔ block ↔ count)
- [ ] No rule priority changes
- [ ] No Web ACL recreation (`-/+` replace)
- [ ] No regex pattern set recreation (`-/+` replace)
- [ ] No IP set recreation (`-/+` replace)
- [ ] No association changes
- [ ] No logging configuration changes

**Process:**
- [ ] PR has been approved by manager or tech lead
- [ ] Plan output is attached to the PR or change ticket
- [ ] dev environment has been successfully applied and validated
- [ ] stage environment has been successfully applied and validated
- [ ] AWS Console open in a second window to monitor WAF metrics during apply
- [ ] Rollback procedure understood and ready

---

## Rollback Plan

### If `terraform plan` shows unexpected changes

1. **Do not run `terraform apply`.**
2. Read the plan output carefully to identify what would change.
3. Fix `main.tf` so the values match the live configuration.
4. Re-run `terraform plan` until it shows 0 changes.

### If `terraform apply` was run and caused an unintended change

1. Check the AWS Console immediately to assess what changed.
2. Open the backup JSON in `terraform/backups/<env>/` — this is the ground truth for the pre-change state.
3. Fix `main.tf` to restore the intended configuration.
4. Run `terraform plan` to confirm the fix, then apply.
5. If the change affected live traffic, escalate to the on-call engineer.

### Specific scenarios

| Scenario | Action |
|----------|--------|
| Terraform wants to delete a Web ACL | Stop immediately — import ID is wrong. Fix `imports.tf`. |
| Terraform wants to delete a regex pattern set | Stop — check `regex_pattern_sets` in `main.tf` for typos |
| Rules are missing from Terraform state | Add missing import blocks, re-apply, verify zero-change plan |
| Rule action changed unintentionally | Revert `main.tf` and apply immediately to restore |
| IP address removed accidentally | Add it back to `addresses` in `main.tf` and apply |
| Console change detected in plan | Decide: override with Terraform (apply) or preserve (update `main.tf` to match) |

> **Never** run `terraform destroy` or `terraform state rm` without explicit approval from a senior engineer and a written rollback plan.

---

*Maintained by the Platform Team — rkatari@gainsight.com*  
*All WAF changes must go through this repository. Console changes will be overwritten on the next `terraform apply`.*
