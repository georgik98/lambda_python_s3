# Initialize provider (region)
provider "aws" {
  region = "eu-central-1"
}

# Create SNS service
resource "aws_sns_topic" "my_topic" {
  name = "my-notification-topic"
}

# Send SNS email
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "email"
  endpoint  = "georgipetrovkolev1998@gmail.com"
}

# Create S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-s3-bucket-georgik16-123123-1231"
}


data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py" #${path.module} -> current working dir
  output_path = "${path.module}/lambda.zip"
}

# Provide S3 object resourse
resource "aws_s3_bucket_object" "lambda_code" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "lambda_function.zip"
  source = data.archive_file.lambda.output_path
  etag   = filemd5(data.archive_file.lambda.output_path)
}

# Provide lambda function resourse
resource "aws_lambda_function" "s3_notification_lambda" {
  function_name = "S3NotificationLambda"
  s3_bucket     = aws_s3_bucket.my_bucket.bucket
  s3_key        = "lambda_function.zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec_role.arn

  source_code_hash = data.archive_file.lambda.output_base64sha256
  depends_on       = [aws_s3_bucket_object.lambda_code]
}

# Lambda permissions to invoke s3
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_notification_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_bucket.arn
}


# Give iam role for lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
      },
    ]
  })
}

# Iam policy
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "IAM policy for Lambda to access S3 and SNS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "sns:Publish",
          "s3:GetObject"
        ],
        Resource = "*",
        Effect   = "Allow",
      }
    ]
  })
}

# Attach lambda policy
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_permission" "allow_S3_invoke" {
  statement_id  = "AllowExecutionFromS3BucketUnique"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_notification_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.my_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notification_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
