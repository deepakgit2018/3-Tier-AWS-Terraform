variable "instance_size" {
  type    = string
  default = "t2.micro"
}

variable "ami_id" {
  type    = string
  default = "ami-0695f2f761eeb04e6"
}

variable "db_password" {
  default   = "admin123"
  sensitive = true
}

variable "cloudwatch_group" {
  description = "CloudWatch group name."
  type        = string
  default     = "supreme-task-group"
}