locals {
  bucket_name = "${var.project_name}-${var.environment}-site-fd"
  logs_bucket = "${var.project_name}-${var.environment}-logs-fd"
}

# ---------------------------------------------------------------------------
# Logging bucket — receives CloudFront and S3 server-access logs
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront log delivery requires BucketOwnerPreferred ownership controls.
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ---------------------------------------------------------------------------
# Site bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  depends_on = [aws_s3_bucket_versioning.site]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_logging" "site" {
  bucket = aws_s3_bucket.site.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
}

# Fix M-2: explicit SSE for site bucket (AES256 is free; bucket_key_enabled reduces KMS call cost if migrated later)
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Fix M-2: explicit SSE for logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Fix M-3: versioning on logs bucket (enables noncurrent expiration below)
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Fix M-4: expire log objects after 90 days; prune noncurrent versions after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  depends_on = [aws_s3_bucket_versioning.logs]

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# S3 bucket policy — allow CloudFront OAC read access only
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "site_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

# ---------------------------------------------------------------------------
# CloudFront security response headers policy
# ---------------------------------------------------------------------------

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.project_name}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self' data:; style-src 'self'; font-src 'self'; frame-ancestors 'none';"
      override                = true
    }
  }
}

# ---------------------------------------------------------------------------
# CloudFront distribution
#
# TODO (WAF — 3.3): Attach an aws_wafv2_web_acl with managed rule groups
#   (AWSManagedRulesCommonRuleSet, AWSManagedRulesAmazonIpReputationList)
#   once WAF costs are approved. Add `web_acl_id` to this resource.
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  is_ipv6_enabled     = true

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized managed policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_regional_domain_name
    prefix          = "cf-access/"
    include_cookies = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Using the default CloudFront certificate because no custom domain is configured yet.
  # TLSv1.2_2021 with a custom domain requires an ACM certificate in us-east-1.
  # TODO: once a custom domain is set, replace viewer_certificate with:
  #   viewer_certificate {
  #     acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
  #     ssl_support_method       = "sni-only"
  #     minimum_protocol_version = "TLSv1.2_2021"
  #   }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}
