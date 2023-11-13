/*
# Create 3 subnets in db layer across each AZ

# Subnets for DB layer
resource "aws_subnet" "db" {
  count             = 3
  vpc_id            = aws_vpc.dkvpc.id
  cidr_block        = "10.0.3.${count.index * 32}/27"
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1c"], count.index)
  tags = {
    Name = "db-${count.index}"
  }
}

# Create route table for DB layer

resource "aws_route_table" "db-rt" {
  vpc_id = aws_vpc.dkvpc.id
  count  = 3
  tags = {
    Name = "three-tier-db-rt"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.dknat[*].id, count.index)
  }
}

#Create Security group for db layer
resource "aws_security_group" "db-sg" {
  name   = "db security group"
  vpc_id = aws_vpc.dkvpc.id
  ingress {
    description     = "Allow request from only app layer Security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.app-sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a DB subnet group for the RDS instances
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "private-db-subnet-group"
  subnet_ids  = aws_subnet.db.*.id
  description = "Subnets available for the RDS DB Instance"
}


# Create the primary RDS instances in private subnet (active-passive)
resource "aws_db_instance" "rds_mysql_instances" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "admin"
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  backup_retention_period = 7
  multi_az             = true
  vpc_security_group_ids = aws_security_group.db-sg.*.id
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  }
  */