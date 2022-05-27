provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      Environment = var.friendly_name_prefix
      Owner       = "Jared Holgate"
      Description = "Test Environment for TFE"
    }
  }
}

provider "cloudflare" {

}