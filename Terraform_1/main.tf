terraform {
  backend "s3" {
    bucket = "787339431038-terraform"
    key    = "img_gallery"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.55.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # Configuration options
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${data.aws_caller_identity.current.account_id}-${var.project_name}"
}

resource "aws_s3_bucket" "images" {
  bucket = "${local.name_prefix}-images"

  tags = var.common_tags
}

resource "aws_s3_bucket" "images-resized" {
  bucket = "${local.name_prefix}-images-resized"

  tags = var.common_tags
}

resource "aws_s3_bucket" "code" {
  bucket = "${local.name_prefix}-code"

  tags = var.common_tags
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = var.project_name
  description                       = ""
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cf" {
  origin {
    domain_name              = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "images"
  }
  origin {
    domain_name              = aws_s3_bucket.images-resized.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "images-resized"
  }
  origin {
    domain_name              = aws_s3_bucket.code.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "code"
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = ""
  default_root_object = "index.html"

  #logging_config {
  #include_cookies = false
  #bucket          = "mylogs.s3.amazonaws.com"
  #prefix          = "myprefix"
  #}

  #aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "images"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/256x256/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "images-resized"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "index.html"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "code"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "PL"]
    }
  }

  tags = var.common_tags

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_object" "lambda_code" {
  bucket = aws_s3_bucket.code.id
  key    = "lambda_code.zip"
  source = "code/Lambda_code.zip"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("code/Lambda_code.zip")
}

resource "aws_dynamodb_table" "images" {
  name         = "images"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"
  attribute {
    name = "name"
    type = "S"
  }
}

resource "aws_lambda_function" "image-resizer" {
  function_name = "image-resizer"
  role         = aws_iam_role.image-resizer.arn
  handler      = "CreateThumbnail.handler"
  runtime      = "python3.7"
  timeout      = 10
  memory_size  = 128

  
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = "images"
    }
  }

  #source_code_hash = "${filebase64sha256("code/lambda_code.zip")}"
  #filename         = "code/lambda_code.zip"

  s3_bucket = aws_s3_bucket.code.bucket
  s3_key    = "lambda_code.zip"
}

resource "aws_cloudwatch_log_group" "image-resizer" {
  name              = "/aws/lambda/image-resizer"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image-resizer.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image-resizer.arn
    events              = ["s3:ObjectCreated:*"]
    #filter_prefix       = "AWSLogs/"
    #filter_suffix       = ".log"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}


resource "aws_lambda_function" "image-list" {
  function_name = "image-list"
  role         = aws_iam_role.image-list.arn
  handler      = "CreateThumbnail.list_handler"
  runtime      = "python3.7"
  timeout      = 10
  memory_size  = 128

  
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = "images"
    }
  }

  #source_code_hash = "${filebase64sha256("code/lambda_code.zip")}"
  #filename         = "code/lambda_code.zip"

  s3_bucket = aws_s3_bucket.code.bucket
  s3_key    = "lambda_code.zip"
}

resource "aws_cloudwatch_log_group" "image-list" {
  name              = "/aws/lambda/image-list"
  retention_in_days = 14
}

resource "aws_lambda_function_url" "image-list" {
  function_name      = aws_lambda_function.image-list.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

data "template_file" "index-html" {
  template = "${file("${path.module}/templates/index.html")}"
  vars = {
    LAMBDA_URL = aws_lambda_function_url.image-list.function_url
    CF_URL = aws_cloudfront_distribution.cf.domain_name
  }
}

resource "local_file" "index-html" {
  content  = data.template_file.index-html.rendered
  filename = "${path.module}/code/index.html"
}

resource "aws_s3_bucket_object" "index-html" {
  bucket = aws_s3_bucket.code.id
  key    = "index.html"
  source = "code/index.html"

  #etag = filemd5("code/index.html")
  depends_on = [
    local_file.index-html
  ]
}
