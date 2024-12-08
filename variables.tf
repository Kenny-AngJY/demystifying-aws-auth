variable "region" {
  type        = string
  default     = "ap-southeast-1"
}

variable "create_vpc" {
  description = "Choose whether to create a new VPC."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "If create_vpc is false, define your own vpc_id."
  type        = string
  default     = ""
}

variable "list_of_subnet_ids" {
  description = "If create_vpc is false, define your own subnet_ids."
  type        = list(string)
  default     = []
}

variable "create_node_group" {
  type    = bool
  default = false
}

variable "kms_key_arn" {
  description = "Encrypt Kubernetes secrets using an existing KMS key."
  type        = string
  default     = ""
}