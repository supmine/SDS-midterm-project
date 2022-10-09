variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zone" {
  description = "value of the availability zone"
  type        = string
  default     = "ap-southeast-1a"
}

variable "ami" {
  description = "value of the ami"
  type        = string
}

variable "database_name" {
  description = "database name"
  type        = string
  default     = "wordpress"
}

variable "database_pass" {
  description = "database password"
  type        = string
  default     = "password"
}

variable "database_user" {
  description = "database user"
  type        = string
  default     = "username"
}

variable "bucket_name" {
  description = "bucket name"
  type        = string
  default     = "bucket01"
}

variable "admin_user" {
  description = "admin user"
  type        = string
  default     = "admin"
}

variable "admin_pass" {
  description = "admin password"
  type        = string
  default     = "admin"
}

variable "admin_email" {
  description = "admin email"
  type        = string
  default     = "exmaple@example.com"
}

variable "title" {
  description = "wordpress title"
  type        = string
  default     = "supmine"
}

variable "instance_type" {
  description = "instance type"
  type        = string
  default     = "t2.micro"
}
