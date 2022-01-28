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

variable "create_hello_world" {
  type        = bool
  description = "(Optional) Create a Hello World application."
  default     = false
}

variable "tfe_license" {
    type        = string
    description = "(Optional) The license for the TFE application."
    default     = ""
}