
provider "aws" {
  region = var.region
}

// Chart Data S3 Bucket
resource "aws_s3_bucket" "chart_data_bucket" {
  bucket = var.chart_data_bucket_name
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.chart_data_bucket.id

  block_public_acls = true
  ignore_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
}



// Chart Data API Lambda
resource "aws_iam_role" "lambda" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": "arn:aws:s3:::*"
    }
  ]
}
EOF
}

data "archive_file" "chart_data_api_function" {
  type = "zip"

  source_dir  = "${path.module}/lambda/chart-data-api/build"
  output_path = "${path.module}/lambda/chart-data-api.zip"
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "notion-charts-lambda-bucket"

  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket_object" "chart_data_api_function" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "chart-data-api.zip"
  source = data.archive_file.chart_data_api_function.output_path

  etag = filemd5(data.archive_file.chart_data_api_function.output_path)
}

resource "aws_lambda_function" "chart_data_api" {
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.chart_data_api_function.key
  function_name    = "chart-data-api"
  role             = aws_iam_role.lambda.arn
  handler          = "chart-data-api.handler"
  source_code_hash = data.archive_file.chart_data_api_function.output_base64sha256
  runtime          = "nodejs12.x"
  description      = "Notions Charts data JSON api with OKTA Authentication"
  publish          = true
}

resource "aws_cloudwatch_log_group" "chart_data_api" {
  name = "/aws/lambda/${aws_lambda_function.chart_data_api.function_name}"

  retention_in_days = 30
}



// Chart Data Lambda API Gateway
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = true
    allow_methods = ["GET"]
    allow_origins = var.allowed_origins 
    allow_headers = ["Authorization"]
  }
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "api"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "chart_data_api" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.chart_data_api.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "chart_data_api" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.chart_data_api.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chart_data_api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}



// React Site S3 and Cloudfront
resource "aws_s3_bucket" "site_bucket" {
  bucket = var.chart_site_bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_cloudfront_distribution" "website_cdn" {
  enabled = true

  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.site_bucket.id}"
    domain_name = aws_s3_bucket.site_bucket.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_root_object = "index.html"

  custom_error_response {
    error_caching_min_ttl = 0
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = "0"
    default_ttl            = "300"
    max_ttl                = "1200"
    target_origin_id       = "origin-bucket-${aws_s3_bucket.site_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "website_cdn_id" {
  value = aws_cloudfront_distribution.website_cdn.id
}

output "website_endpoint" {
  value = aws_cloudfront_distribution.website_cdn.domain_name
}



// Domain name mapping
// Have to wait for domain cert to be issued before mapping to domain
// Might should just create cert before and use ARN
# resource "aws_acm_certificate" "dayneio" {
#   domain_name       = "chart-api.dayne.io"
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_zone" "chart_api" {
#   name = "chart-api.dayne.io"

#   tags = {
#     Environment = "dev"
#   }
# }

# resource "aws_apigatewayv2_domain_name" "lambda" {
#   domain_name = "chart-api.dayne.io"

#   domain_name_configuration {
#     certificate_arn = aws_acm_certificate.dayneio.arn
#     endpoint_type   = "REGIONAL"
#     security_policy = "TLS_1_2"
#   }
# }

# resource "aws_route53_record" "lambda" {
#   name    = aws_apigatewayv2_domain_name.lambda.domain_name
#   type    = "A"
#   zone_id = aws_route53_zone.chart_api.zone_id

#   alias {
#     name                   = aws_apigatewayv2_domain_name.lambda.domain_name_configuration[0].target_domain_name
#     zone_id                = aws_apigatewayv2_domain_name.lambda.domain_name_configuration[0].hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# resource "aws_apigatewayv2_api_mapping" "lambda" {
#   api_id      = aws_apigatewayv2_api.lambda.id
#   domain_name = aws_apigatewayv2_domain_name.lambda.id
#   stage       = aws_apigatewayv2_stage.lambda.id
# }
