terraform {
  backend "s3" {
    bucket         = "kodekloud-lab-state-1763599383"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kodekloud-lab-locks-1763599383"
    encrypt        = true
  }
}
