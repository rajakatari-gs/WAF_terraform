#!/usr/bin/env bash
# =============================================================
# validate_waf.sh
# Post-import validation: compares live AWS WAF config against
# Terraform state and confirms zero-change plan.
#
# Usage:
#   ./scripts/validate_waf.sh <env> <region> [aws-profile]
#
# Example:
#   ./scripts/validate_waf.sh stage us-east-1 stage-profile
# =============================================================
set -euo pipefail

ENV="${1:-}"
REGION="${2:-}"
PROFILE="${3:-default}"

if [[ -z "$ENV" || -z "$REGION" ]]; then
  echo "Usage: $0 <env> <region> [aws-profile]"
  exit 1
fi

ENV_DIR="../environments/${ENV}"
AWS="aws --profile $PROFILE --region $REGION"

echo "=== Validating Terraform state vs live AWS WAF for env=$ENV ==="
echo ""

# ── Step 1: Terraform validate ─────────────────────────────────
echo "[1/5] Running terraform validate..."
(cd "$ENV_DIR" && terraform init -backend=false -input=false > /dev/null)
(cd "$ENV_DIR" && terraform validate)

# ── Step 2: terraform state list ─────────────────────────────
echo ""
echo "[2/5] Resources tracked in Terraform state:"
(cd "$ENV_DIR" && terraform state list) || echo "      (No state yet — run import first)"

# ── Step 3: terraform plan ────────────────────────────────────
echo ""
echo "[3/5] Running terraform plan (read-only verification)..."
echo "      EXPECTED RESULT: No changes."
(cd "$ENV_DIR" && terraform plan -detailed-exitcode -out=tfplan_validate.tfplan) && \
  echo "      PASS: Plan shows 0 changes." || \
  echo "      WARNING: Plan shows changes — review before proceeding!"

# ── Step 4: Live vs State Web ACL count ──────────────────────
echo ""
echo "[4/5] Comparing Web ACL count (live vs state)..."

LIVE_COUNT=$($AWS wafv2 list-web-acls --scope REGIONAL \
  --query 'length(WebACLs)' --output text)
STATE_COUNT=$(cd "$ENV_DIR" && terraform state list 2>/dev/null | \
  grep -c 'aws_wafv2_web_acl' || echo "0")

echo "      Live Web ACLs : $LIVE_COUNT"
echo "      State Web ACLs: $STATE_COUNT"
if [[ "$LIVE_COUNT" == "$STATE_COUNT" ]]; then
  echo "      PASS: Counts match."
else
  echo "      WARNING: Count mismatch — possible missing imports."
fi

# ── Step 5: IP Set count check ───────────────────────────────
echo ""
echo "[5/5] Comparing IP Set count (live vs state)..."

LIVE_IP_COUNT=$($AWS wafv2 list-ip-sets --scope REGIONAL \
  --query 'length(IPSets)' --output text)
STATE_IP_COUNT=$(cd "$ENV_DIR" && terraform state list 2>/dev/null | \
  grep -c 'aws_wafv2_ip_set' || echo "0")

echo "      Live IP Sets : $LIVE_IP_COUNT"
echo "      State IP Sets: $STATE_IP_COUNT"
if [[ "$LIVE_IP_COUNT" == "$STATE_IP_COUNT" ]]; then
  echo "      PASS: Counts match."
else
  echo "      WARNING: Count mismatch — check imports.tf."
fi

echo ""
echo "=== Validation complete for env=$ENV ==="
