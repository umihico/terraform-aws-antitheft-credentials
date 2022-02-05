terraform {
  backend "s3" {
    bucket         = "terraform-backend-123456789012-bastion-account"
    dynamodb_table = "terraform-backend-123456789012-bastion-account"
    encrypt        = true
    key            = "simple/terraform.tfstate"
    profile        = "default"
    region         = "ap-northeast-1"
  }
}
