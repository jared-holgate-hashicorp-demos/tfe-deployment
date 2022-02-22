variable "friendly_name_prefix" {
  type        = string
  description = "(Optional) Friendly name prefix used for tagging and naming AWS resources."
  default     = "jfh-tfe-poc"
}

variable "root_domain" {
  type        = string
  description = "(Optional) Domain name."
  default     = "hashicorpdemo.net"
}

variable "tfe_sub_domain" {
  type        = string
  description = "(Optional) Domain name."
  default     = "tfe"
}

variable "replicated_sub_domain" {
  type        = string
  description = "The sub-domain for replicated."
  default     = "replicated"
}

variable "network_cidr" {
  type        = string
  description = "(Optional) CIDR block for VPC."
  default     = "10.0.0.0/16"
}

variable "network_public_subnet_cidrs" {
  type        = list(string)
  description = "(Optional) List of public subnet CIDR ranges to create in VPC."
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "network_private_subnet_cidrs" {
  type        = list(string)
  description = "(Optional) List of private subnet CIDR ranges to create in VPC."
  default     = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
}

variable "bastion_ip_restrictions" {
  type        = list(string)
  description = "The IP restrictions for the bastion server."
  default     = []
}

variable "tfe_ip_restrictions" {
  type        = list(string)
  description = "The IP restrictions for tfe."
  default     = []
}

variable "replicated_ip_restrictions" {
  type        = list(string)
  description = "The IP restrictions for replicated."
  default     = ["217.155.46.217/32"]
}

variable "install_type" {
  type        = string
  description = "(Optional) Create a Hello World application."
  default     = "tfe_automated_mounted_disk"
  validation {
    condition     = contains(["apache_hello_world", "tfe_manual", "tfe_automated_mounted_disk", "tfe_automated_external_services", "tfe_automated_active_active"], var.install_type)
    error_message = "Valid values for install_type: test_variable are apache_hello_world, tfe_manual, tfe_automated_mounted_disk, tfe_automated_external_services and tfe_automated_active_active."
  }
}

variable "tfe_license" {
  type        = string
  description = "(Optional) The license for the TFE application."
  default     = ""
}