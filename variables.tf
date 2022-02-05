variable "account_id" {
  description = "Existing account as a bastion account"
  type        = string
}

variable "user_names" {
  description = "Iam user names to create in bastion account"
  type        = list(string)
}
