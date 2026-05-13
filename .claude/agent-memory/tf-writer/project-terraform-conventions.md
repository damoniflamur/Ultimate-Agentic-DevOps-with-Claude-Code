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

**Why:** Security audit identified state exposure, missing security headers, no logging, and uncompressed responses as the primary risks.

**How to apply:** Any future changes to the CloudFront distribution or S3 buckets must preserve these settings. Do not remove `response_headers_policy_id`, logging config, or public access blocks.
