output "web_acl_arn" {
  description = "US2-PROD WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}

output "web_acl_id" {
  description = "US2-PROD WAF Web ACL ID"
  value       = module.waf.web_acl_id
}
