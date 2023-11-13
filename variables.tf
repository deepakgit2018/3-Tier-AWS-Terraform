variable "instance_size" {
  type    = string
  default = "t2.micro"
}

variable "db_password" {
    default = "admin123"
    sensitive = true
}