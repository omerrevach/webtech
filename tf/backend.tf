terraform {
  backend "s3" {
    bucket = "nginx-test-env-tf-state-omer-1234"
    key    = "tf/terraform.tfstate"
    region = "eu-north-1"

    encrypt = true
  }
}
