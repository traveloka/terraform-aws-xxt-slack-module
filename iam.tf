data "aws_iam_policy_document" "sns-topic-policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::630072297223:role/SuperAdmin",
        "arn:aws:iam::124129351750:role/SuperAdmin",
        "arn:aws:iam::124129351750:role/PowerUser",
        "arn:aws:iam::630072297223:role/PowerUser",
        "arn:aws:iam::124129351750:role/Deployer_001",
        "arn:aws:iam::124129351750:role/Deployer_002",
        "arn:aws:iam::124129351750:role/Deployer_003"
      ]
    }
    resources = [
      "${local.sns_topic_arn}"
    ]
    sid = "readWriteSNS"
    actions = [
      "SNS:Publish",
    ]
  }
}

resource "aws_sns_topic_policy" "default" {
  arn = "${local.sns_topic_arn}"

  policy = "${data.aws_iam_policy_document.sns-topic-policy.json}"
}

data "aws_iam_policy_document" "assume_role" {
  count = "${var.create}"

  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_basic" {
  count = "${var.create}"

  statement {
    sid = "AllowWriteToCloudwatchLogs"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:/aws/lambda/${var.lambda_function_name}",
      "arn:aws:logs:*:*:/aws/lambda/${var.lambda_function_name}:*",
    ]
  }
}

data "aws_iam_policy_document" "lambda" {
  count = "${(var.create_with_kms_key == 1 ? 1 : 0) * var.create}"

  source_json = "${data.aws_iam_policy_document.lambda_basic.0.json}"

  statement {
    sid = "AllowKMSDecrypt"

    effect = "Allow"

    actions = ["kms:Decrypt"]

    resources = ["${var.kms_key_arn == "" ? "" : var.kms_key_arn}"]
  }
}

resource "aws_iam_role" "lambda" {
  count = "${var.create}"

  name_prefix        = "lambda"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.0.json}"
}

resource "aws_iam_role_policy" "lambda" {
  count = "${var.create}"

  name_prefix = "lambda-policy-"
  role        = "${aws_iam_role.lambda.0.id}"

  policy = "${element(compact(concat(data.aws_iam_policy_document.lambda.*.json, data.aws_iam_policy_document.lambda_basic.*.json)), 0)}"
}
