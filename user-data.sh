#!/bin/bash

yum update -y
yum install -y httpd.x86_64
systemctl restart httpd.service
systemctl enable httpd.service
echo "Hello World! from $(hostname -f)" > /var/www/html/index.html
sudo yum install -y firewalld
systemctl start firewalld
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload
systemctl enable firewalld