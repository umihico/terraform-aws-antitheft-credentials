output "aws_iam_role_default" {
  value = aws_iam_role.default
}

output "aws_iam_role_policy_default" {
  value = aws_iam_role_policy.default
}

output "aws_iam_role_condition_changer" {
  value = aws_iam_role.condition_changer
}

output "aws_iam_role_policy_condition_changer" {
  value = aws_iam_role_policy.condition_changer
}

output "bastion" {
  value = module.bastion
}

output "ip_address_table" {
  value = aws_dynamodb_table.ip_address_table
}
