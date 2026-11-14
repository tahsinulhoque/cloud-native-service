
terraform {
  backend "s3" {
    bucket               = "cloud-native-service-tfstate"
    key                  = "terraform.tfstate"
    region               = "us-west-2"
    encrypt              = true
    use_lockfile         = true
    workspace_key_prefix = "cloud-native-service"
  }
}
