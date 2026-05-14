---
name: project-infra-overview
description: Infrastructure layout for the portfolio-site project — S3 + CloudFront + OAC, no OIDC/IAM role in current TF files (last verified 2026-05-13 audit #3)
metadata:
  type: project
---

Static portfolio site deployed to AWS via S3 + CloudFront, provisioned with Terraform.

**Resources in terraform/ (as of 2026-05-13 audit #3 — no change from audit #2):**
- `aws_s3_bucket.site` — private bucket, all public access blocked, versioning ENABLED, server-access logging to logs bucket, 30-day noncurrent version lifecycle expiration
- `aws_s3_bucket.logs` — receives CF and S3 access logs, all public access blocked, BucketOwnerPreferred ownership controls; NO explicit SSE, NO versioning
- `aws_s3_bucket_public_access_block.site` / `.logs` — all four flags true on both buckets
- `aws_s3_bucket_versioning.site` — Enabled
- `aws_s3_bucket_lifecycle_configuration.site` — expires noncurrent versions after 30 days
- `aws_s3_bucket_logging.site` — targets logs bucket, prefix s3-access/
- `aws_cloudfront_origin_access_control.site` — OAC with sigv4, correct
- `aws_cloudfront_response_headers_policy.security` — HSTS (1yr, includeSubdomains, preload), X-Content-Type-Options, X-Frame-Options DENY, Referrer-Policy strict-origin-when-cross-origin, XSS protection, CSP (uses unsafe-inline for style-src)
- `aws_cloudfront_distribution.site` — redirect-to-https, CachingOptimized managed policy, response-headers policy attached, compress=true, IPv6 enabled, logging_config to logs bucket prefix cf-access/, NO WAF, default CloudFront cert (TLSv1 minimum)
- `aws_s3_bucket_policy.site` — scoped to CloudFront service + specific distribution ARN via condition
- Backend in backend.tf is commented out (local state in terraform/terraform.tfstate, NOT committed to git as of this audit)

**Account ID in tfstate on disk:** 890381434210 — tfstate files present on disk but NOT committed to git (protected by terraform/.gitignore).

**What is NOT in TF files:** OIDC provider, GitHub Actions IAM role, WAF WebACL, explicit SSE on logs bucket, root-level .gitignore

**Why:** Needed to track baseline so future audits can detect drift.
**How to apply:** Use this as the baseline when comparing future runs; flag any new resources or missing resources against this list.
