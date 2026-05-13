---
name: project-infra-overview
description: Infrastructure layout for the portfolio-site project — S3 + CloudFront + OAC, no OIDC/IAM role in current TF files
metadata:
  type: project
---

Static portfolio site deployed to AWS via S3 + CloudFront, provisioned with Terraform.

**Resources in terraform/ (as of 2026-05-13):**
- `aws_s3_bucket.site` — private bucket, all public access blocked, AES256 SSE (auto-applied by AWS default), versioning disabled
- `aws_s3_bucket_public_access_block.site` — all four flags true
- `aws_cloudfront_origin_access_control.site` — OAC with sigv4, correct
- `aws_cloudfront_distribution.site` — redirect-to-https, CachingOptimized policy, default CloudFront cert (TLSv1), no response-headers policy, no WAF, no logging, IPv6 disabled
- `aws_s3_bucket_policy.site` — scoped to CloudFront service + specific distribution ARN via condition
- Backend in backend.tf is commented out (local state in terraform.tfstate)

**Account ID exposed in tfstate:** 890381434210 — tfstate committed to repo (CRITICAL finding)

**What is NOT in TF files:** OIDC provider, GitHub Actions IAM role (referenced in CLAUDE.md but absent from code — likely manual or in a separate repo)

**Why:** Needed to track baseline so future audits can detect drift.
**How to apply:** Use this as the baseline when comparing future runs; flag any new resources or missing resources against this list.
