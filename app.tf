# Create 3 subnets in app layer across each AZ

# Subnets for App layer
resource "aws_subnet" "app" {
  count             = 3
  vpc_id            = aws_vpc.dkvpc.id
  cidr_block        = "10.0.2.${count.index * 32}/27"
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)
  tags = {
    Name = "app-${count.index}"
  }
}

# Create route table for app layer

resource "aws_route_table" "app-rt" {
  vpc_id = aws_vpc.dkvpc.id
  count  = 3
  tags = {
    Name = "three-tier-app-rt"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.dknat[*].id, count.index)
  }
}

# Create route table association for app layer

resource "aws_route_table_association" "app" {
  count          = 3
  subnet_id      = element(aws_subnet.app[*].id, count.index)
  route_table_id = element(aws_route_table.app-rt[*].id, count.index)
}

#Create Security group for app layer
resource "aws_security_group" "app-sg" {
  name   = "app security group"
  vpc_id = aws_vpc.dkvpc.id
  ingress {
    description     = "Allow http request from Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb-sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create keypair for EC2 instances
resource "aws_key_pair" "ec2-key-pair" {
  key_name   = "app-tier-key"
  public_key = file("./ec2-key.pub")
}

/*
#Create EC2 instance for App layer  (We are using EC2 here to host the website)

resource "aws_instance" "app" {
  count                       = 3
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = var.instance_size
  subnet_id                   = element(aws_subnet.app[*].id, count.index)
  vpc_security_group_ids      = [aws_security_group.app-sg.id]
  key_name                    = aws_key_pair.ec2-key-pair.key_name
  associate_public_ip_address = false
  user_data                   = file("./user-data.sh")
  tags = {
    name = "app-${count.index}"
  }
}
*/

#Create an ECS cluster

resource "aws_ecs_cluster" "dk_cluster" {
  name = "dk-ecs-cluster"
}

#Create an Capacity provider for hosting ECS cluster
resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "capacityprpvider"

  auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.dk_asg.arn

  managed_scaling {
     maximum_scaling_step_size = 1000
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 3
   }
 }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
 cluster_name = aws_ecs_cluster.dk_cluster.name

 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

 default_capacity_provider_strategy {
   base              = 1
   weight            = 100
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
 }
}

#Create an Autosclaing group for ECS EC2 instances

resource "aws_launch_template" "dk_launch_template" {
  name_prefix     = "dk-launch-template"
  image_id        = data.aws_ami.amazon-linux-2.id
  instance_type   = var.instance_size
  vpc_security_group_ids = [aws_security_group.app-sg.id]
  key_name        = aws_key_pair.ec2-key-pair.key_name
  iam_instance_profile  {
    name = aws_iam_instance_profile.ecs_profile.name
  }

  block_device_mappings {
   device_name = "/dev/xvda"
   ebs {
     volume_size = 30
     volume_type = "gp2"
   }
 }
  
  tag_specifications {
   resource_type = "instance"
   tags = {
     Name = "ecs-instance"
   }
 }
  user_data = filebase64("./ecs.sh")
}

#Create an Autosclaing group for ECS EC2 instances

resource "aws_autoscaling_group" "dk_asg" {
  name             = "dk-asg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 3
  vpc_zone_identifier = aws_subnet.app[*].id
   launch_template {
   id      = aws_launch_template.dk_launch_template.id
   version = "$Latest"
 }

tag {
   key                 = "AmazonECSManaged"
   value               = true
   propagate_at_launch = true
 }
}

# Create EC2 instance profile for ECS Service

resource "aws_iam_role" "ecs_service_role" {
  name = "dk_ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create EC2 Instance profile for ECS Service actions
resource "aws_iam_instance_profile" "ecs_profile" {
  name = "ecs_service_profile"
  role = aws_iam_role.ecs_service_role.name
}

# Attach iam_role policy for ECS service
resource "aws_iam_role_policy_attachment" "ecs-service-role-policy-attachment" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create ECS task role

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"
  
   assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

# Attach iam_role policy for ecs task
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#Create ECS task and Service

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "dk-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  cpu                = 256
  memory             = 512
  runtime_platform {
  operating_system_family = "LINUX"
  cpu_architecture        = "X86_64"
 }
  container_definitions = jsonencode([
    {
    name  = "dk-container"
    image = "hub.docker.com/_/hello-world:linux"
    cpu   = 256
    memory = 512
    essential =  true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "dk-service"
  cluster         = aws_ecs_cluster.dk_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  scheduling_strategy   = "REPLICA"
  launch_type     = "EC2"
  desired_count   = 3

network_configuration {
  subnets         = aws_subnet.app[*].id
  security_groups  = [aws_security_group.app-sg.id]
}
/*
capacity_provider_strategy {
  capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  weight            = 100
  }
  */
  load_balancer {
    target_group_arn = aws_lb_target_group.alb-tg.arn
    container_name   = "dk-container"
    container_port   = 80
  }

    depends_on = [aws_lb_listener.front-end]
}