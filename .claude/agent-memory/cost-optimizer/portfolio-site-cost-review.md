---
name: portfolio-site-cost-review
description: Cost optimization findings for static portfolio site (S3 + CloudFront) deployed in ap-south-1
metadata:
  type: project
---

## Project Context

Static HTML/CSS portfolio site hosted on S3 + CloudFront in ap-south-1. No compute, no databases. Versioning and logging both enabled.

**Deployment pattern**: Push to main → GitHub Actions syncs to S3 → CloudFront cache invalidation

## Findings

### HIGH SAVINGS POTENTIAL

1. **Logging Bucket Missing Storage Class & Lifecycle** (main.tf:10-17, 82-87)
   - **Current**: Standard storage class, no expiration policy, no transition rules
   - **Issue**: CloudFront + S3 server-access logs accumulate indefinitely at $0.023/GB/month in ap-south-1
   - **Recommendation**: Add S3 Intelligent-Tiering or Glacier transition with 90-day expiration
   - **Estimated Impact**: $5-15/month savings (depending on traffic) if old logs auto-deleted; higher if Intelligent-Tiering used

2. **Logs Bucket Versioning Not Explicitly Disabled** (main.tf:10-17)
   - **Current**: Versioning status not explicitly set (defaults to disabled, but implicit)
   - **Issue**: If versioning is ever accidentally enabled, noncurrent log versions won't be cleaned up automatically
   - **Recommendation**: Add explicit `aws_s3_bucket_versioning` with `status = "Disabled"` for logs bucket
   - **Estimated Impact**: Low ($1-2/month max), but prevents future cost surprise if misconfigured

### MEDIUM SAVINGS POTENTIAL

3. **CloudFront PriceClass_200 — Consider PriceClass_100** (main.tf:182)
   - **Current**: PriceClass_200 (covers most edge locations except a few premium regions)
   - **Consideration**: For a portfolio site with low traffic, PriceClass_100 (North America, Europe, Asia) may be sufficient
   - **Recommendation**: Verify traffic distribution. If most users are in covered regions, PriceClass_100 saves ~25% on data transfer costs
   - **Estimated Impact**: $2-5/month savings if traffic is primarily in standard regions (depends on origin requests + data transfer)

4. **CloudFront Logging Enabled Without Retention Policy** (main.tf:208-212)
   - **Current**: Logging enabled, logs written to `cf-access/` prefix, no expiration defined in lifecycle
   - **Issue**: CloudFront logs accumulate at ~1KB per request; a moderate site could generate 1-5GB/month
   - **Recommendation**: Add lifecycle rule to logs bucket: transition to Glacier after 30 days, delete after 90 days
   - **Estimated Impact**: $1-3/month savings (logs moved to Glacier at $0.004/GB/month after 30 days)

### LOW SAVINGS POTENTIAL

5. **Site Bucket Versioning with 30-Day Noncurrent Expiration** (main.tf:59-80)
   - **Current**: Versioning enabled, noncurrent versions expire after 30 days (well-configured)
   - **Recommendation**: This is already optimized. No change needed.
   - **Note**: The 30-day retention is reasonable for a static site with infrequent deployments

6. **No S3 Intelligent-Tiering on Site Bucket** (main.tf:41-48)
   - **Current**: Standard storage class only
   - **Consideration**: For a site bucket, objects are accessed regularly via CloudFront (not infrequent access)
   - **Recommendation**: Keep Standard. Intelligent-Tiering adds $0.0125/1000 object overhead — not worth it for regularly-accessed static content
   - **Estimated Impact**: Negligible (avoid unnecessary cost)

## Total Estimated Savings

- **High impact**: $5-15/month (logging lifecycle + transitions)
- **Medium impact**: $2-5/month (price class review)
- **Low impact**: $1-3/month (logging expiration)
- **Total potential**: $8-23/month ($96-276/year)

## Next Steps (Prioritized)

1. **Immediate**: Add lifecycle rule to logs bucket (expire after 90 days) → Save $5-15/month
2. **Review**: Analyze CloudFront access logs to understand traffic distribution, then decide on PriceClass_100 vs. 200
3. **Optional**: Add explicit versioning=disabled to logs bucket (risk mitigation, minimal cost impact)

## Related Memories

None yet — this is the initial cost audit.
