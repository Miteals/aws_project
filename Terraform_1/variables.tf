variable "common_tags" {
  default = {
    Project     = "img-gallery"
    Environment = "Dev"
  }
}

variable "project_name" {
  type    = string
  default = "img-gallery"
}

variable "account_number" {
  type    = string
  default = "049718899517"
}

variable "region" {
  description = "The AWS region to deploy resources in"
  default     = "us-east-1"
}