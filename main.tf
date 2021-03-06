data "aws_caller_identity" "bastion" {
  provider = aws.bastion
}

locals {
  assume_role_policy_user_arns = [for u in var.user_names : "arn:aws:iam::${data.aws_caller_identity.bastion.account_id}:user/${u}"]
}

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.bastion]
    }
  }
}

resource "aws_dynamodb_table" "ip_address_table" {
  name           = "bastion-ip-address-table-${var.suffix}"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "IpAddress"
  range_key      = "ExpireAt"

  attribute {
    name = "IpAddress"
    type = "S"
  }

  attribute {
    name = "ExpireAt"
    type = "N"
  }

  ttl {
    attribute_name = "ExpireAt"
    enabled        = true
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }
}

resource "aws_iam_role" "default" {
  name                 = "BastionUserRole_${var.suffix}"
  permissions_boundary = aws_iam_policy.boundary_policy.arn
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : "sts:AssumeRole"
        "Effect" : "Allow"
        "Principal" : { "AWS" : local.assume_role_policy_user_arns }
        "Condition" : {
          "Bool" : {
            "aws:MultiFactorAuthPresent" : true
          }
        }
      },
    ]
  })
  max_session_duration = 43200 # maxiumum session duration is 12 hours (43200 seconds)
}

resource "aws_iam_role_policy_attachment" "default" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.default.name
  policy_arn = each.key
}

resource "aws_iam_policy" "boundary_policy" {
  name        = "BastionUserRole_permissions_boundary_policy_${var.suffix}"
  description = "IP Address Based Boundary Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    "Statement" : [{
      "Effect" : "Deny",
      "Action" : "*",
      "Resource" : "*",
      "Condition" : {
        "NotIpAddress" : {
          "aws:SourceIp" : []
        },
        "Bool" : { "aws:ViaAWSService" : false }
      }
    }]
  })
  lifecycle {
    ignore_changes = [
      policy,
    ]
  }
}

resource "aws_iam_role" "condition_changer" {
  name = "BastionUpdatePolicyRole_${var.suffix}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : {
      "Action" : "sts:AssumeRole"
      "Effect" : "Allow"
      "Principal" : { "AWS" : local.assume_role_policy_user_arns }
      "Condition" : {
        "NumericLessThan" : { "aws:MultiFactorAuthAge" : 10 }
        "Bool" : {
          "aws:MultiFactorAuthPresent" : true
        }
      }
    }
  })
  max_session_duration = 3600 # minimum session duration is 1 hour (3600 seconds)
}

resource "aws_iam_role_policy" "condition_changer" {
  name = "BastionUpdatePolicyRole_policy_${var.suffix}"
  role = aws_iam_role.condition_changer.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:CreatePolicyVersion",
        ]
        Effect   = "Allow"
        Resource = aws_iam_policy.boundary_policy.arn
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan",
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.ip_address_table.arn
      },
    ]
  })
}

module "bastion" {
  source     = "./bastion"
  providers  = { aws = aws.bastion }
  user_names = var.user_names
  role_arns = [
    aws_iam_role.default.arn,
    aws_iam_role.condition_changer.arn,
  ]
}
