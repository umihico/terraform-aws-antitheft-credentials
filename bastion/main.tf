terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_iam_group" "default" {
  name = "bastion-users-group"
}

resource "aws_iam_user" "users" {
  for_each = toset(var.user_names)
  name     = each.key
}

resource "aws_iam_group_membership" "default" {
  name  = "bastion-users-group-membership"
  users = [for u in aws_iam_user.users : u.name]
  group = aws_iam_group.default.name
}

resource "aws_iam_group_policy" "default" {
  name  = "bastion-users-group-policy"
  group = aws_iam_group.default.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = var.role_arns
      },
    ]
  })
}
