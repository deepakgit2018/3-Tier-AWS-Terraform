#!/bin/bash
echo ECS_CLUSTER=dk-ecs-cluster >> /etc/ecs/ecs.config
#yum update -y
#yum install -y docker
#service docker start
#usermod -a -G docker ec2-user
#chkconfig docker on