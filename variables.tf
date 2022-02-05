variable "account_id" {
  description = "Existing account as a bastion account"
  type        = string
}

variable "user_names" {
  description = "Iam user names to create in bastion account"
  type        = list(string)
}

variable "policy_arns" {
  description = "Policy ARN attaching to the role users assume"
  type        = list(string)
}
