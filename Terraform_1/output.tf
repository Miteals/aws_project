output "cf_url" {
  value = aws_cloudfront_distribution.cf.domain_name
}