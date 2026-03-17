terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# provider "aws" {
#   region = "us-east-1"
#   access_key = ACCESS_KEY
#   secret_key = SECRET_KEY
# }
