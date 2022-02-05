module "bastion" {
  source     = "../.."
  account_id = "123456789012"
  providers = {
    aws.bastion = aws.bastion,
  }
  user_names = [
    "umihico",
  ]
}
