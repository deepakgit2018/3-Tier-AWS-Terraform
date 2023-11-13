# Create VPC , us-east-1 has been taken for this excercise

resource "aws_vpc" "dkvpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "3-tier-vpc"
  }
}

# Create Internet gateway for the vpc

resource "aws_internet_gateway" "dkigw" {
  vpc_id = aws_vpc.dkvpc.id
  tags = {
    Name = "dk-igw"
  }
}

# Create EIP for NAT gateways

resource "aws_eip" "natgw-eip" {
  count      = 3
  domain     = "vpc"
  depends_on = [aws_internet_gateway.dkigw]
  tags = {
    Name = "EIP_for_NAT_${count.index}"
  }
}

# Create 1 NAT gateway for each of the public subnets across each AZ

resource "aws_nat_gateway" "dknat" {
  count         = 3
  allocation_id = aws_eip.natgw-eip[count.index].id
  subnet_id     = element(aws_subnet.web[*].id, count.index)
  tags = {
    Name = "dk-NAT"
  }
}

# Create S3 bucket (No use in this excercise but it is mentioned in diagram hence created)
resource "aws_s3_bucket" "dk_bucket" {
  bucket = "dkbucket15081988"

  tags = {
    Name        = "DK bucket"
    Environment = "Prod"
  }
}