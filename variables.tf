variable "friendly_name_prefix" {
  type        = string
  description = "(Optional) Friendly name prefix used for tagging and naming AWS resources."
  default     = "jfh-tfe-poc"
}

variable "create_hello_world" {
  type        = bool
  description = "(Optional) Create a Hello World application."
  default     = true
}