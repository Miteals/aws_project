data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.images-oac.json
}

data "aws_iam_policy_document" "images-oac" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = ["arn:aws:s3:::${aws_s3_bucket.images.id}/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images-resized" {
  bucket = aws_s3_bucket.images-resized.id
  policy = data.aws_iam_policy_document.images-resized-oac.json
}

data "aws_iam_policy_document" "images-resized-oac" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = ["arn:aws:s3:::${aws_s3_bucket.images-resized.id}/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "code" {
  bucket = aws_s3_bucket.code.id
  policy = data.aws_iam_policy_document.code-oac.json
}

data "aws_iam_policy_document" "code-oac" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = ["arn:aws:s3:::${aws_s3_bucket.code.id}/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf.arn]
    }
  }
}


data "aws_iam_policy_document" "image-resizer" {
  statement {

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "logs:CreateLogStream",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/image-resizer:*",
      "arn:aws:s3:::${local.name_prefix}-images/*",
      "arn:aws:s3:::${local.name_prefix}-images-resized/*",
      "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/images",
      "arn:aws:s3:::${local.name_prefix}-code/*"
    ]

  }

}



data "aws_iam_policy_document" "image-list" {
  statement {

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {

    actions = [
      "s3:GetObject",
      "logs:CreateLogStream",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/image-list:*",
      "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/images",
    "arn:aws:s3:::${local.name_prefix}-code/*"]

  }

}

resource "aws_iam_policy" "image-resizer" {
  name        = "image-resizer"
  description = ""

  policy = data.aws_iam_policy_document.image-resizer.json
}

resource "aws_iam_role_policy_attachment" "image-resizer" {
  policy_arn = aws_iam_policy.image-resizer.arn
  role       = aws_iam_role.image-resizer.name
}

resource "aws_iam_role" "image-resizer" {
  name               = "${local.name_prefix}-image-resizer"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_policy" "image-list" {
  name        = "image-list"
  description = ""

  policy = data.aws_iam_policy_document.image-list.json
}

resource "aws_iam_role_policy_attachment" "image-list" {
  policy_arn = aws_iam_policy.image-list.arn
  role       = aws_iam_role.image-list.name
}


resource "aws_iam_role" "image-list" {
  name               = "${local.name_prefix}-image-list"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

