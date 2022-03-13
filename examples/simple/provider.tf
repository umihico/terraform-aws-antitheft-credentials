provider "aws" {
  profile = "default"
  region  = "ap-northeast-1"
}

provider "aws" {
  alias   = "bastion"
  profile = "default"
  region  = "ap-northeast-1"
  assume_role {
    role_arn = "arn:aws:iam::222244446666:role/OrganizationAccountAccessRole"
  }
}
