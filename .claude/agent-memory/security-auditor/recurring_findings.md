---
name: recurring-findings
description: Security patterns found repeatedly in this project's Terraform — use to quickly flag regressions in future audits
metadata:
  type: feedback
---

Patterns confirmed in the first full audit (2026-05-13):

1. **tfstate committed to repo** — `terraform/terraform.tfstate` and `.backup` are tracked in git, exposing AWS account ID 890381434210 and resource ARNs. Backend block in backend.tf is commented out.
   **Why:** No .gitignore for *.tfstate exists; bootstrap chicken-and-egg left state local.

2. **CloudFront: no response-headers policy** — `response_headers_policy_id` is empty. Security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) are absent entirely.
   **Why:** Never configured; the managed cache policy was added but the response-headers policy was overlooked.

3. **CloudFront: default certificate uses TLSv1** — `cloudfront_default_certificate = true` forces `minimum_protocol_version = "TLSv1"`. Upgrading to ACM cert allows setting TLSv1.2_2021.
   **Why:** No custom domain configured; `domain_name` variable exists but is empty.

4. **CloudFront: no access logging** — `logging_config` is empty. No record of viewer requests.

5. **CloudFront: no WAF WebACL** — `web_acl_id` is empty. No rate limiting or managed rule protection.

6. **CloudFront: IPv6 disabled** — `is_ipv6_enabled = false`. Minor posture gap but worth enabling.

7. **S3: versioning disabled** — `versioning.enabled = false`. Site content can be silently overwritten.

8. **S3: no access logging** — `logging` block empty. No record of GetObject calls.

9. **S3: SSE uses AES256 (AWS-managed), not CMK** — Acceptable for public static assets but worth noting; bucket_key_enabled = false wastes cost if CMK ever added.

10. **Compression disabled** — `compress = false` in default_cache_behavior. Performance issue, not security.

**How to apply:** On every future audit, scan for these patterns first before looking for new issues.
