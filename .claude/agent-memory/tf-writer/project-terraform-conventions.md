---
name: project-terraform-conventions
description: Terraform patterns, resource decisions, and security posture established for the portfolio-site project
metadata:
  type: project
---

Key decisions locked in during the security hardening sprint (2026-05-13):

- CloudFront uses OAC (not OAI) — `aws_cloudfront_origin_access_control` wired via `origin_access_control_id`
- Managed cache policy ID `658327ea-f89d-4fab-a63d-7e88639e58f6` (CachingOptimized) is used in `default_cache_behavior`
- Security response headers policy (`aws_cloudfront_response_headers_policy.security`) is attached via `response_headers_policy_id` on `default_cache_behavior`
- Logging bucket (`aws_s3_bucket.logs`) requires `aws_s3_bucket_ownership_controls` with `BucketOwnerPreferred` — CF log delivery will silently fail without it
- Site bucket has versioning enabled and a 30-day noncurrent-version expiration lifecycle rule
- `cloudfront_default_certificate = true` is intentional — custom TLS requires ACM cert in us-east-1; a TODO comment with the exact swap-in HCL is left in main.tf
- WAF (3.3) is deliberately skipped — TODO comment on CloudFront resource flags it for a future pass
- `sensitive = true` is set on `cloudfront_distribution_id` and `s3_bucket_arn` outputs
- Provider pinned to `~> 5.100`
- S3 backend in backend.tf is commented out — migration to S3 state is required before team use; tfstate is git-ignored via terraform/.gitignore
- `is_ipv6_enabled = true` and `compress = true` are set on the CloudFront distribution

Security fixes applied in second hardening pass (2026-05-13):

- M-1: CloudFront `custom_error_response` for 404 now returns `response_code = 404` (was 200) and sets `error_caching_min_ttl = 10` — returning 200 for 404s was masking errors for crawlers and analytics
- M-2: Explicit `aws_s3_bucket_server_side_encryption_configuration` added for both site and logs buckets (AES256, `bucket_key_enabled = true`) — makes SSE declarative and audit-visible rather than relying on S3 default
- M-3: Versioning enabled on logs bucket (`aws_s3_bucket_versioning.logs`) — prerequisite for noncurrent-version lifecycle expiration
- M-4: Lifecycle rule on logs bucket — expires current objects after 90 days, noncurrent versions after 30 days; `depends_on = [aws_s3_bucket_versioning.logs]` required to avoid race condition
- M-5: Removed `'unsafe-inline'` from `style-src` in CSP header — tightens XSS posture; inline styles in HTML must now be moved to the stylesheet if this causes visual regressions
- L-1: `lifecycle { prevent_destroy = true }` added to `aws_s3_bucket.site` and `aws_s3_bucket.logs`
- L-2: `lifecycle { prevent_destroy = true }` added to `aws_cloudfront_distribution.site`
- L-3: `default_tags` block added to `provider "aws"` with `Project`, `Environment`, `ManagedBy = "terraform"` — provider-level tags propagate to all resources automatically; explicit per-resource `tags` blocks are intentionally kept as well (they merge/override provider defaults)

Skipped (require prerequisites):
- H-1 (remote backend): needs a real state bucket name first
- H-2 (TLS 1.2 minimum): needs a custom domain + ACM cert in us-east-1
- H-3 (WAF): requires cost approval

**Why:** Security audit round 2 targeted: incorrect HTTP semantics on 404s, missing explicit SSE, no log retention policy, CSP weakness, and absence of accidental-destroy protection.

**How to apply:** Any future changes to the CloudFront distribution or S3 buckets must preserve these settings. Do not remove `response_headers_policy_id`, logging config, public access blocks, lifecycle prevent_destroy, or the SSE configurations. If a custom domain is added, swap in the ACM cert viewer_certificate block and set minimum_protocol_version = "TLSv1.2_2021".
