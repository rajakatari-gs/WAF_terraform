#!/usr/bin/env bash
# =============================================================
# discover_waf.sh
# Discovers all WAF resources in the given environment/region
# and writes a JSON backup to terraform/backups/<env>/
#
# Usage:
#   ./scripts/discover_waf.sh <env> <region> [aws-profile]
#
# Example:
#   ./scripts/discover_waf.sh stage us-east-1 stage-profile
#   ./scripts/discover_waf.sh us1-prod us-east-1 prod-profile
#   ./scripts/discover_waf.sh us2-prod us-west-2 prod-profile
#   ./scripts/discover_waf.sh eu-prod eu-west-1 prod-profile
# =============================================================
set -euo pipefail

ENV="${1:-}"
REGION="${2:-}"
PROFILE="${3:-default}"

if [[ -z "$ENV" || -z "$REGION" ]]; then
  echo "Usage: $0 <env> <region> [aws-profile]"
  exit 1
fi

BACKUP_DIR="../backups/${ENV}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="${BACKUP_DIR}/${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

AWS="aws --profile $PROFILE --region $REGION"

echo "=== Discovering WAF resources for env=$ENV region=$REGION ==="

# ── Web ACLs ─────────────────────────────────────────────────
echo "[1/6] Listing Web ACLs..."
$AWS wafv2 list-web-acls --scope REGIONAL \
  --output json > "$OUTPUT_DIR/web_acls.json"
echo "      Saved: $OUTPUT_DIR/web_acls.json"

# Fetch full detail for each Web ACL
jq -r '.WebACLs[] | "\(.Name) \(.Id)"' "$OUTPUT_DIR/web_acls.json" | \
while read -r NAME ID; do
  echo "      → Getting detail for Web ACL: $NAME ($ID)"
  $AWS wafv2 get-web-acl --name "$NAME" --id "$ID" --scope REGIONAL \
    --output json > "$OUTPUT_DIR/web_acl_${NAME}.json"
done

# ── IP Sets ──────────────────────────────────────────────────
echo "[2/6] Listing IP Sets..."
$AWS wafv2 list-ip-sets --scope REGIONAL \
  --output json > "$OUTPUT_DIR/ip_sets.json"
echo "      Saved: $OUTPUT_DIR/ip_sets.json"

jq -r '.IPSets[] | "\(.Name) \(.Id)"' "$OUTPUT_DIR/ip_sets.json" | \
while read -r NAME ID; do
  echo "      → Getting detail for IP Set: $NAME ($ID)"
  $AWS wafv2 get-ip-set --name "$NAME" --id "$ID" --scope REGIONAL \
    --output json > "$OUTPUT_DIR/ip_set_${NAME}.json"
done

# ── Regex Pattern Sets ────────────────────────────────────────
echo "[3/6] Listing Regex Pattern Sets..."
$AWS wafv2 list-regex-pattern-sets --scope REGIONAL \
  --output json > "$OUTPUT_DIR/regex_pattern_sets.json"
echo "      Saved: $OUTPUT_DIR/regex_pattern_sets.json"

jq -r '.RegexPatternSets[] | "\(.Name) \(.Id)"' "$OUTPUT_DIR/regex_pattern_sets.json" | \
while read -r NAME ID; do
  echo "      → Getting detail for Regex Pattern Set: $NAME ($ID)"
  $AWS wafv2 get-regex-pattern-set --name "$NAME" --id "$ID" --scope REGIONAL \
    --output json > "$OUTPUT_DIR/regex_pattern_set_${NAME}.json"
done

# ── Rule Groups ───────────────────────────────────────────────
echo "[4/6] Listing Rule Groups..."
$AWS wafv2 list-rule-groups --scope REGIONAL \
  --output json > "$OUTPUT_DIR/rule_groups.json"
echo "      Saved: $OUTPUT_DIR/rule_groups.json"

# ── Logging Configurations ────────────────────────────────────
echo "[5/6] Listing Logging Configurations..."
$AWS wafv2 list-logging-configurations --scope REGIONAL \
  --output json > "$OUTPUT_DIR/logging_configurations.json"
echo "      Saved: $OUTPUT_DIR/logging_configurations.json"

# ── Resource Associations (per Web ACL) ──────────────────────
echo "[6/6] Listing Web ACL Associations..."
jq -r '.WebACLs[].ARN' "$OUTPUT_DIR/web_acls.json" | \
while read -r ACL_ARN; do
  SAFE_NAME=$(echo "$ACL_ARN" | tr '/:' '__')
  $AWS wafv2 list-resources-for-web-acl --web-acl-arn "$ACL_ARN" \
    --output json > "$OUTPUT_DIR/associations_${SAFE_NAME}.json" || true
done

echo ""
echo "=== Discovery complete. Backup saved to: $OUTPUT_DIR ==="
echo ""
echo "Next step: Review the backup, then populate the Terraform"
echo "configuration in environments/$ENV/main.tf and imports.tf"
