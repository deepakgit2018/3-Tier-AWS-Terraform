output "ami" {
  value = data.aws_ami.amazon-linux-2
}

output "website_url" {
  description = "This URL can be used to access the web page"
  value       = "https://${aws_lb.dkalb.dns_name}:443"
}