# Create 3 subnets in web layer across each AZ

# Subnets for Web layer
resource "aws_subnet" "web" {
  count                   = 3
  vpc_id                  = aws_vpc.dkvpc.id
  cidr_block              = "10.0.1.${count.index * 32}/27"
  availability_zone       = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "web-${count.index}"
  }
}


# Create route table for web layer

resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.dkvpc.id
  tags = {
    Name = "web-rt"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dkigw.id
  }
}

# Create route table association for web layer
resource "aws_route_table_association" "web" {
  count          = 3
  subnet_id      = element(aws_subnet.web[*].id, count.index)
  route_table_id = element(aws_route_table.web-rt[*].id, count.index)
}

# Create one Security group for web layer (Load balancer)
resource "aws_security_group" "alb-sg" {
  name   = "web security group"
  vpc_id = aws_vpc.dkvpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create Public ALB for accessing the website hosted in backend EC2 instances
resource "aws_lb" "dkalb" {
  name               = "dk-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.web[*].id
  security_groups    = [aws_security_group.alb-sg.id]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
   Name = "ecs-alb"
 }
}

# Create Target Group
resource "aws_lb_target_group" "alb-tg" {
  name        = "alb-ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.dkvpc.id
  #target_type = "instance"
  
  health_check {
   path = "/"
   interval            = 30
   timeout             = 10
   healthy_threshold   = 2
   unhealthy_threshold = 2
 }
 depends_on = [aws_lb.dkalb]
}


# Register instances with target group
resource "aws_lb_target_group_attachment" "ecs_tg_attachment" {
  #count            = aws_ecs_service.ecs_service.desired_count
  target_group_arn = aws_lb_target_group.alb-tg.arn
  #target_id        = aws_ecs_service.ecs_service.id
  target_id        = aws_ecs_task_definition.ecs_task.arn
  port             = 80
}

# Create alb lisener for routing the traffic
resource "aws_lb_listener" "front-end" {
  load_balancer_arn = aws_lb.dkalb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:152729937704:certificate/ff3d3264-01f3-492b-9568-70841853e20c"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}