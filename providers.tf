provider "aws" {
  region = "eu-west-2"
  default_tags {
   tags = {
     Environment = var.friendly_name_prefix
     Owner       = "Jared Holgate"
     Description     = "Test Environment for TFE"
   }
 }
}

provider "cloudflare" {

}