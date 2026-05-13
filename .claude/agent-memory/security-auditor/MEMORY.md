# Security Auditor Memory Index

- [Project Infra Overview](project_infra_overview.md) — S3+CloudFront+OAC baseline, account ID in tfstate, no OIDC/IAM in TF files (last verified 2026-05-13)
- [Recurring Findings](recurring_findings.md) — 10 confirmed patterns to check on every audit: tfstate in git, no response-headers policy, TLSv1, no CF logging, no WAF, IPv6 off, no S3 versioning/logging
