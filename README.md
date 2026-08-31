# AWS WAF Terraform Migration Guide

Production-safe migration and management of AWS WAF rules using Terraform IaC across four environments: **STAGE**, **US1-PROD**, **US2-PROD**, and **EU-PROD**.

---

## Table of Contents

1. [Overview](#overview)
2. [Repository Structure](#repository-structure)
3. [Environment Map](#environment-map)
4. [Prerequisites](#prerequisites)
5. [Workflow — Step by Step](#workflow--step-by-step)
   - [Step 1: Discovery](#step-1--discovery-read-only-zero-risk)
   - [Step 2: Read the Backup](#step-2--read-the-backup)
   - [Step 3: Write Terraform Configuration](#step-3--write-terraform-configuration)
   - [Step 4: Fill Import Blocks](#step-4--fill-import-blocks)
   - [Step 5: Initialize and Plan](#step-5--initialize-and-plan)
   - [Step 6: Apply the Import](#step-6--apply-the-import-state-only)
   - [Step 7: Validate](#step-7--validate)
   - [Step 8: Repeat per Environment](#step-8--repeat-per-environment)
   - [Step 9: Future Changes](#step-9--future-changes-day-2-operations)
6. [Module Architecture](#module-architecture)
7. [State Management](#state-management)
8. [Import ID Reference](#import-id-reference)
9. [Troubleshooting](#troubleshooting)
10. [Rollback Plan](#rollback-plan)
11. [Pre-Apply Production Checklist](#pre-apply-production-checklist)

---

## Overview

### Goal

Import all existing live AWS WAF configurations into Terraform state and manage them going forward as Infrastructure as Code — without interrupting production traffic or modifying any existing WAF behavior.

### Migration Flow

```
AWS (live WAF)
      │
      ▼
[1] DISCOVER          ← Read-only AWS CLI calls
      │
      ▼
[2] BACKUP            ← Save JSON snapshots locally
      │
      ▼
[3] WRITE TF CONFIG   ← Match live config exactly in HCL
      │
      ▼
[4] IMPORT            ← Pull AWS resources into Terraform state
      │
      ▼
[5] PLAN VERIFY       ← Must show 0 changes before proceeding
      │
      ▼
[6] MANAGE GOING FWD  ← All future changes via Terraform PRs
```

> **Production Safety Rule:** Nothing modifies AWS infrastructure until Step 6, and even then only after a verified zero-change plan.

---

## Repository Structure

```
terraform-nginx-frontend/
├── README.md                          ← This file
├── .gitignore
├── docs/
│   └── MIGRATION_PLAN.md              ← Phase sequence, checklist, rollback
└── terraform/
    ├── modules/
    │   └── waf/
    │       ├── main.tf                ← Manages all WAF resources
    │       ├── variables.tf           ← All input variables with validation
    │       ├── outputs.tf             ← Web ACL ARN/ID, IP Set ARNs
    │       └── imports.tf             ← Commented import block examples
    ├── environments/
    │   ├── stage/
    │   │   ├── provider.tf            ← S3 backend + AWS provider (us-east-1)
    │   │   ├── main.tf                ← Calls waf module with stage values
    │   │   ├── variables.tf
    │   │   ├── outputs.tf
    │   │   └── imports.tf             ← Uncomment and fill after discovery
    │   ├── us1-prod/                  ← Same structure (us-east-1)
    │   ├── us2-prod/                  ← Same structure (us-west-2)
    │   └── eu-prod/                   ← Same structure (eu-west-1)
    ├── scripts/
    │   ├── discover_waf.sh            ← AWS CLI discovery + JSON backup
    │   └── validate_waf.sh            ← Post-import state vs live verification
    └── backups/
        ├── stage/                     ← JSON backups written by discover_waf.sh
        ├── us1-prod/
        ├── us2-prod/
        └── eu-prod/
```

---

## Environment Map

| Environment | AWS Region  | Default AWS Profile | State File Path                    |
|-------------|-------------|---------------------|------------------------------------|
| stage       | us-east-1   | stage-profile       | `waf/stage/terraform.tfstate`      |
| us1-prod    | us-east-1   | prod-profile        | `waf/us1-prod/terraform.tfstate`   |
| us2-prod    | us-west-2   | prod-profile        | `waf/us2-prod/terraform.tfstate`   |
| eu-prod     | eu-west-1   | prod-profile        | `waf/eu-prod/terraform.tfstate`    |

> Each environment has its own isolated S3 state file. A mistake in one environment cannot affect another.

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Terraform   | >= 1.6  |
| AWS CLI     | >= 2.x  |
| jq          | any     |

**AWS permissions required (read-only for discovery):**
- `wafv2:ListWebACLs`
- `wafv2:GetWebACL`
- `wafv2:ListIPSets`
- `wafv2:GetIPSet`
- `wafv2:ListRegexPatternSets`
- `wafv2:GetRegexPatternSet`
- `wafv2:ListRuleGroups`
- `wafv2:ListLoggingConfigurations`
- `wafv2:ListResourcesForWebACL`

**Additional permissions required for import/apply:**
- `wafv2:GetWebACL`
- `wafv2:TagResource`
- `wafv2:ListTagsForResource`

---

## Workflow — Step by Step

### Step 1 — Discovery (Read-Only, Zero Risk)

Run the discovery script for the target environment. Start with **stage** before touching any production environment.

```bash
cd terraform/scripts

# Usage: ./discover_waf.sh <env> <region> <aws-profile>
./discover_waf.sh stage    us-east-1 stage-profile
./discover_waf.sh us1-prod us-east-1 prod-profile
./discover_waf.sh us2-prod us-west-2 prod-profile
./discover_waf.sh eu-prod  eu-west-1 prod-profile
```

**What the script does internally:**

```bash
# All of these are read-only calls — they never modify AWS
aws wafv2 list-web-acls --scope REGIONAL
aws wafv2 get-web-acl --name "..." --id "..." --scope REGIONAL
aws wafv2 list-ip-sets --scope REGIONAL
aws wafv2 get-ip-set --name "..." --id "..." --scope REGIONAL
aws wafv2 list-regex-pattern-sets --scope REGIONAL
aws wafv2 list-logging-configurations --scope REGIONAL
aws wafv2 list-resources-for-web-acl --web-acl-arn "..."
```

**Output — files written to `terraform/backups/<env>/<timestamp>/`:**

```
web_acls.json                          ← All Web ACLs with IDs and ARNs
web_acl_gainsight-waf-stage.json       ← Full rule detail per Web ACL
ip_sets.json                           ← All IP sets
ip_set_AllowlistedIPs.json             ← Addresses per IP set
regex_pattern_sets.json
logging_configurations.json
associations_arn__aws__...json         ← Which ALBs/API GWs are associated
```

---

### Step 2 — Read the Backup

Open the Web ACL JSON and understand every field. This is your source of truth.

```json
{
  "WebACL": {
    "Name": "gainsight-waf-stage",
    "Id": "abc12345-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "ARN": "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/gainsight-waf-stage/abc12345-...",
    "DefaultAction": { "Allow": {} },
    "Rules": [
      {
        "Name": "AWSManagedRulesCommonRuleSet",
        "Priority": 1,
        "OverrideAction": { "None": {} },
        "Statement": {
          "ManagedRuleGroupStatement": {
            "VendorName": "AWS",
            "Name": "AWSManagedRulesCommonRuleSet"
          }
        },
        "VisibilityConfig": {
          "CloudWatchMetricsEnabled": true,
          "MetricName": "AWSManagedRulesCommonRuleSet",
          "SampledRequestsEnabled": true
        }
      }
    ]
  }
}
```

> Every value in this JSON must be reproduced exactly in your Terraform HCL in the next step.

---

### Step 3 — Write Terraform Configuration

Open `terraform/environments/<env>/main.tf` and fill it in to match the backup exactly.

**Example — translating the JSON backup to HCL:**

```hcl
module "waf" {
  source = "../../modules/waf"

  name           = "gainsight-waf-stage"   # from web_acls.json → Name
  scope          = "REGIONAL"
  default_action = "allow"                 # from DefaultAction → Allow

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "gainsight-waf-stage"
    sampled_requests_enabled   = true
  }

  rules = [
    {
      name     = "AWSManagedRulesCommonRuleSet"   # exact name from JSON
      priority = 1                                # exact priority from JSON
      override_action = { none = {} }             # OverrideAction: None
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

  ip_sets = {
    "AllowlistedIPs" = {
      ip_address_version = "IPV4"
      addresses          = ["10.0.0.0/8", "192.168.1.0/24"]  # from ip_set_...json
    }
  }

  association_resource_arns = [
    "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/stage-alb/xxxx"
  ]

  tags = {
    Environment = "stage"
    ManagedBy   = "terraform"
    Team        = "platform"
    Project     = "gainsight-waf"
  }
}
```

> **Critical:** If any value differs from the backup, `terraform plan` will show a change. Fix the HCL, never the live AWS config.

---

### Step 4 — Fill Import Blocks

Open `terraform/environments/<env>/imports.tf` and fill in the IDs from the backup JSON.

```hcl
# Import ID format: <name>/<id>/<scope>
# The ID comes from web_acls.json → WebACLs[].Id

import {
  to = module.waf.aws_wafv2_web_acl.this
  id = "gainsight-waf-stage/abc12345-xxxx-xxxx-xxxx-xxxxxxxxxxxx/REGIONAL"
}

import {
  to = module.waf.aws_wafv2_ip_set.this["AllowlistedIPs"]
  id = "AllowlistedIPs/def67890-xxxx-xxxx-xxxx-xxxxxxxxxxxx/REGIONAL"
}

import {
  to = module.waf.aws_wafv2_web_acl_association.this["<ALB_ARN>"]
  id = "<ALB_ARN>/<WEB_ACL_ARN>"
}

import {
  to = module.waf.aws_wafv2_web_acl_logging_configuration.this[0]
  id = "<WEB_ACL_ARN>"
}
```

> The `id` values come directly from the backup JSON files — never guess them.

---

### Step 5 — Initialize and Plan

```bash
cd terraform/environments/stage

# Download the AWS provider
terraform init

# Check HCL syntax and module references
terraform validate

# Generate a plan — this runs the import blocks but does NOT apply anything
terraform plan
```

**Expected output during plan with import blocks:**

```
Terraform will perform the following actions:

  # module.waf.aws_wafv2_web_acl.this will be imported
  + resource "aws_wafv2_web_acl" "this" {
      + id   = "abc12345-..."
      + name = "gainsight-waf-stage"
      ...
    }

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

`terraform plan` is always read-only. It never changes AWS.

---

### Step 6 — Apply the Import (State Only)

```bash
terraform apply
```

This step is different from a normal apply. With import blocks, `terraform apply`:

- Reads the existing AWS WAF resource
- Writes it into the Terraform state file
- Does **not** create, modify, or delete any AWS infrastructure

Immediately after apply, run plan again:

```bash
terraform plan
```

**Required result:**

```
No changes. Your infrastructure matches the configuration.
```

If you see anything other than zero changes — **stop and do not proceed.** Fix the HCL mismatch and re-run until the plan is clean.

---

### Step 7 — Validate

Run the validation script to confirm everything is consistent:

```bash
cd terraform/scripts
./validate_waf.sh stage us-east-1 stage-profile
```

The script checks:

| Check | Expected Result |
|-------|----------------|
| `terraform validate` | 0 errors |
| `terraform state list` | All WAF resources listed |
| `terraform plan` | 0 changes |
| Live Web ACL count vs state count | Match |
| Live IP Set count vs state count | Match |

All five checks must pass before moving to the next environment.

---

### Step 8 — Repeat per Environment

Follow Steps 1–7 for each environment in this order:

```
stage → us1-prod → us2-prod → eu-prod
```

Always validate stage fully before touching any production environment.

```bash
# Each environment is fully isolated
cd terraform/environments/us1-prod
terraform init
terraform validate
terraform plan    # Must show 0 changes after import
terraform apply   # Import only
terraform plan    # Final confirmation — must be 0 changes
```

---

### Step 9 — Future Changes (Day 2 Operations)

Once all environments are imported and show clean plans, all WAF changes must go through Terraform:

```
Engineer edits main.tf
        │
        ▼
git commit + Pull Request
        │
        ▼
terraform plan output added to PR description
        │
        ▼
Manager / Tech Lead reviews the plan
        │
        ▼
PR approved and merged
        │
        ▼
terraform apply to stage first
        │
        ▼
Verify in AWS Console / CloudWatch metrics
        │
        ▼
Apply to us1-prod → us2-prod → eu-prod
```

**Example — adding a new blocked IP:**

```hcl
# In environments/us1-prod/main.tf
ip_sets = {
  "BlocklistedIPs" = {
    ip_address_version = "IPV4"
    addresses = [
      "1.2.3.4/32",
      "5.6.7.8/32",   # ← new IP added here
    ]
  }
}
```

`terraform plan` will show only that single IP being added. Nothing else changes.

---

## Module Architecture

```
environments/stage/main.tf
        │  calls with environment-specific values
        ▼
modules/waf/main.tf          ← shared logic, maintained in one place
        │  creates/manages
        ▼
aws_wafv2_web_acl
aws_wafv2_ip_set
aws_wafv2_regex_pattern_set
aws_wafv2_web_acl_association
aws_wafv2_web_acl_logging_configuration
```

The module code is shared across all four environments. Each environment only provides different input values. A bug fix or new feature in the module benefits all environments simultaneously.

---

## State Management

| Environment | State File | Region | Lock Table |
|-------------|-----------|--------|------------|
| stage | `s3://bucket/waf/stage/terraform.tfstate` | us-east-1 | DynamoDB |
| us1-prod | `s3://bucket/waf/us1-prod/terraform.tfstate` | us-east-1 | DynamoDB |
| us2-prod | `s3://bucket/waf/us2-prod/terraform.tfstate` | us-west-2 | DynamoDB |
| eu-prod | `s3://bucket/waf/eu-prod/terraform.tfstate` | eu-west-1 | DynamoDB |

- State files are encrypted at rest in S3
- DynamoDB lock table prevents two engineers from applying simultaneously
- Running `terraform apply` in one environment directory cannot affect another

---

## Import ID Reference

| Resource | Import ID Format | Example |
|----------|-----------------|---------|
| `aws_wafv2_web_acl` | `<name>/<id>/<scope>` | `my-waf/abc123/REGIONAL` |
| `aws_wafv2_ip_set` | `<name>/<id>/<scope>` | `AllowedIPs/def456/REGIONAL` |
| `aws_wafv2_regex_pattern_set` | `<name>/<id>/<scope>` | `BadPatterns/ghi789/REGIONAL` |
| `aws_wafv2_rule_group` | `<name>/<id>/<scope>` | `CustomRules/jkl012/REGIONAL` |
| `aws_wafv2_web_acl_association` | `<resource_arn>/<web_acl_arn>` | `arn:aws:elasticloadbalancing:.../arn:aws:wafv2:...` |
| `aws_wafv2_web_acl_logging_configuration` | `<web_acl_arn>` | `arn:aws:wafv2:us-east-1:123456789012:regional/webacl/...` |

Find all IDs in the backup JSON files under `terraform/backups/<env>/`.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Plan shows rule action change (ALLOW → BLOCK) | HCL action does not match backup | Fix `main.tf` — match the backup JSON exactly |
| Plan shows rule priority change | Priority number differs | Fix `main.tf` — use exact priority from backup JSON |
| Plan wants to recreate the Web ACL | Import ID is wrong | Check `imports.tf` — verify the ID from backup JSON |
| Plan wants to recreate an IP set | IP list or import ID differs | Compare `main.tf` addresses with `ip_set_*.json` |
| Resource count mismatch in validate script | A resource exists in AWS but not in `imports.tf` | Add missing import blocks and re-apply |
| `terraform apply` fails during import | Resource ID in `imports.tf` is wrong | Verify the ID directly from backup JSON |
| `terraform init` fails | S3 bucket or DynamoDB table not found | Update `provider.tf` with correct bucket/table names |

---

## Rollback Plan

### If `terraform plan` shows unexpected changes

1. **Do not run `terraform apply`.**
2. Identify what Terraform wants to change by reading the plan output carefully.
3. Fix the Terraform HCL in `main.tf` to match the live config.
4. Re-run `terraform plan` until it shows 0 changes.
5. Only then proceed.

### If `terraform apply` was run and changed something unintended

1. Immediately check AWS Console to assess what changed.
2. Open the backup JSON in `terraform/backups/<env>/` — this is your source of truth for what the config should be.
3. Restore the original AWS WAF configuration manually via AWS Console.
4. Fix the Terraform HCL to match the restored configuration.
5. Run `terraform plan` to confirm zero changes before re-importing.

### Specific scenarios

| Scenario | Action |
|----------|--------|
| Terraform wants to delete a Web ACL | Stop — import ID is wrong. Do not apply. Fix `imports.tf`. |
| Rules are missing from Terraform state | Add missing rules to `main.tf`, re-run plan |
| Rule priorities differ | Update priorities in `main.tf` to match AWS exactly |
| IP set shows replacement (`-/+`) | Address list or ID differs. Fix `main.tf` and `imports.tf`. |
| Logging config mismatch | Match `logging_configuration` block exactly to `logging_configurations.json` |

> Do not use destructive Terraform operations (`terraform destroy`, `terraform state rm`) without explicit approval from a senior engineer.

---

## Pre-Apply Production Checklist

Complete every item before running `terraform apply` against any production environment.

- [ ] `discover_waf.sh` run and backup saved for this environment
- [ ] Backup JSON reviewed and understood
- [ ] `terraform validate` passes with 0 errors
- [ ] `terraform plan` reviewed line by line by at least one engineer
- [ ] Plan shows **0 resources to add, 0 to change, 0 to destroy**
- [ ] No rule action changes (ALLOW, BLOCK, COUNT)
- [ ] No rule priority changes
- [ ] No Web ACL recreation (`-/+` replace)
- [ ] No IP set recreation (`-/+` replace)
- [ ] No association changes
- [ ] No logging configuration changes
- [ ] Plan output attached to the PR or change ticket
- [ ] Change approved by manager or tech lead
- [ ] Stage environment has already been successfully imported and validated
- [ ] Rollback procedure documented and understood by the team
- [ ] AWS Console open in a second window to monitor during apply

---

*Maintained by the Platform Team. For questions contact rkatari@gainsight.com.*
