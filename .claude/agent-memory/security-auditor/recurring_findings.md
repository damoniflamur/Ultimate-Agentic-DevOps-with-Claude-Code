---
name: recurring-findings
description: Security patterns found repeatedly in this project's Terraform — use to quickly flag regressions in future audits
metadata:
  type: feedback
---

Patterns from audit #1 (2026-05-13) and their current status as of audit #3 (2026-05-13):

1. **tfstate on disk with account ID exposed** — `terraform/terraform.tfstate` and `.backup` exist on disk and contain AWS account ID 890381434210, CloudFront distribution ID, bucket ARNs, and domain names. Backend block in backend.tf is commented out so state is local-only.
   - Audit #1 status: tfstate files were committed to git (CRITICAL).
   - Audit #2 status: `terraform/.gitignore` now correctly lists both files; git status shows `?? terraform/` (entire dir untracked). Files are NOT committed. Risk downgraded to HIGH (local plaintext, no remote backend, no encryption at rest for state).
   **Why:** Bootstrap chicken-and-egg; S3 backend not yet provisioned.

2. **CloudFront: no response-headers policy** — FIXED in audit #2. `response_headers_policy_id` is now set to `aws_cloudfront_response_headers_policy.security.id`. Full security headers (HSTS, CSP, X-Frame-Options, X-Content-Type, Referrer-Policy, XSS) are present.

3. **CloudFront: default certificate forces TLSv1** — STILL PRESENT. `cloudfront_default_certificate = true` with no `minimum_protocol_version` override means AWS enforces TLSv1 minimum. The fix (ACM cert + TLSv1.2_2021) is present in a commented-out TODO block at main.tf:222-227.
   **Why:** No custom domain configured yet.

4. **CloudFront: no access logging** — FIXED in audit #2. `logging_config` block now present, targeting the logs bucket with prefix `cf-access/`.

5. **CloudFront: no WAF WebACL** — STILL PRESENT. Commented TODO at main.tf:174-177 documents intent. No `web_acl_id` set.

6. **CloudFront: IPv6 disabled** — FIXED in audit #2. `is_ipv6_enabled = true`.

7. **S3: versioning disabled** — FIXED in audit #2. `aws_s3_bucket_versioning.site` with `status = "Enabled"` and a 30-day noncurrent version expiration lifecycle rule.

8. **S3: no access logging** — FIXED in audit #2. `aws_s3_bucket_logging.site` targets logs bucket with prefix `s3-access/`.

9. **S3: SSE uses AWS-managed AES256, not CMK** — STILL PRESENT (implicit, no `aws_s3_bucket_server_side_encryption_configuration` resource). AWS default encryption applies. Acceptable for public static assets.

10. **Compression disabled** — FIXED in audit #2. `compress = true` in default_cache_behavior.

11. **Logs bucket: no encryption resource** — NEW. `aws_s3_bucket.logs` has no `aws_s3_bucket_server_side_encryption_configuration`. AWS default encryption applies silently, but explicit SSE configuration is best practice.

12. **Logs bucket: no versioning** — NEW. Only the site bucket has versioning; the logs bucket does not.

13. **No root-level .gitignore** — NEW. The repo has no root `.gitignore`. Only `terraform/.gitignore` protects tfstate. If someone accidentally runs `git add .` from root, tfstate files might be staged if the scoped .gitignore is bypassed by certain git configurations.

14. **CSP uses `unsafe-inline` for style-src** — NEW. main.tf:165 sets `style-src 'self' 'unsafe-inline'`. This weakens XSS protection for style injection attacks. Acceptable if inline styles are required by the site; worth tracking.

15. **custom_error_response returns HTTP 200 for 404** — main.tf:202-206 maps error_code 404 to response_code 200. This masks real 404 errors from monitoring and log analysis tools. Should return response_code 404 (or a dedicated 404 HTML page with the correct status code).
    - Audit #3 status: STILL PRESENT.

16. **No lifecycle rule on logs bucket** — `aws_s3_bucket.logs` has no lifecycle configuration. Access logs will accumulate indefinitely, increasing storage cost and exposing long-term access patterns.
    - Audit #3 status: STILL PRESENT.

**How to apply:** On every future audit, scan for these patterns first before looking for new issues. Items marked FIXED should be checked for regression.
