terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "Production"
      Name        = "SDS Project"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# Subnet Private
resource "aws_subnet" "private_link" {
  //use for communicate between app and db
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "subnet-private-link"
  }

}

resource "aws_subnet" "private_2" {
  //use for associate to nat gateway
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone

  tags = {
    Name = "subnet-private-2"
  }
}

# Subnet Public
resource "aws_subnet" "public_1" {
  //use for app instance
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = "true" //it makes this a public subnet

  tags = {
    Name = "subnet-public-1"
  }
}

resource "aws_subnet" "public_2" {
  //use for nat gateway
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = "true" //it makes this a public subnet

  tags = {
    Name = "subnet-public-2"
  }

}

# Network Interface
//app instance 
//network interface for connect to database
resource "aws_network_interface" "app_private_link" {
  subnet_id       = aws_subnet.private_link.id
  description     = "interface for app to connect to database"
  security_groups = [aws_security_group.app.id]

  tags = {
    Name = "app-private-link"
  }
}

//network interface for connect to public internet
resource "aws_network_interface" "app_public_1" {
  subnet_id       = aws_subnet.public_1.id
  description     = "interface for app to connect to public internet"
  security_groups = [aws_security_group.app.id]

  tags = {
    "Name" = "app-public-1"
  }
}

//database instance
//network interface for connect to app instance
resource "aws_network_interface" "database_private_link" {
  subnet_id       = aws_subnet.private_link.id
  description     = "interface for database to connect to app"
  security_groups = [aws_security_group.database_1.id]

  tags = {
    Name = "database-private-link"
  }
}

//network interface for connect to internet
resource "aws_network_interface" "database_private_2" {
  subnet_id       = aws_subnet.private_2.id
  description     = "interface for database to connect to internet"
  security_groups = [aws_security_group.database_2.id]

  tags = {
    Name = "database-private-2"
  }
}

# Security Group
resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allows all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "database_1" {
  name        = "database-1-sg"
  description = "allow traffic from database to app instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow mariadb"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_link.cidr_block]
  }

  tags = {
    Name = "database-1-sg"
  }
}

resource "aws_security_group" "database_2" {
  name        = "database-2-sg"
  description = "allow traffic from database to internet"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "allows all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "database-2-sg"
  }
}

# AWS instance
resource "aws_instance" "database" {
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.availability_zone

  network_interface {
    network_interface_id = aws_network_interface.database_private_2.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.database_private_link.id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/database.tftpl", {
    database_name = var.database_name
    database_user = var.database_user
    database_pass = var.database_pass
  })
  user_data_replace_on_change = true

  tags = {
    "Name" = "database-instance"
  }
}

resource "aws_instance" "app" {
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.availability_zone

  network_interface {
    network_interface_id = aws_network_interface.app_public_1.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.app_private_link.id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/wordpress.tftpl", {
    database_name = var.database_name
    database_user = var.database_user
    database_pass = var.database_pass
    database_host = aws_network_interface.database_private_link.private_ip
    public_ip     = aws_eip.public.public_ip
    admin_user    = var.admin_user
    admin_pass    = var.admin_pass
    admin_email   = var.admin_email
    title         = var.title
    access_key    = aws_iam_access_key.s3_access_key.id
    secret_key    = aws_iam_access_key.s3_access_key.secret
    bucket_name   = var.bucket_name
    region        = var.region
  })
  user_data_replace_on_change = true

  depends_on = [
    aws_instance.database
  ]

  tags = {
    "Name" = "app-instance"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "main-igw"
  }
}

# Elastic IP
resource "aws_eip" "nat" {
  vpc = true

  tags = {
    "Name" = "nat-eip"
  }
}

resource "aws_eip" "public" {
  network_interface = aws_network_interface.app_public_1.id
  vpc               = true

  tags = {
    "Name" = "public-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_2.id

  tags = {
    "Name" = "private-nat-gateway"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    "Name" = "public-route-table"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private.id
  }

  tags = {
    "Name" = "private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# S3
resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = "${var.bucket_name}-bucket"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "public-read"
}

# IAM
resource "aws_iam_user" "s3_user" {
  name = "s3_user"

  tags = {
    "Name" = "s3-user"
  }
}

resource "aws_iam_access_key" "s3_access_key" {
  user = aws_iam_user.s3_user.name
}

data "aws_iam_policy_document" "s3_policy_doc" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_user_policy" "s3_policy" {
  name   = "s3_user_policy"
  user   = aws_iam_user.s3_user.name
  policy = data.aws_iam_policy_document.s3_policy_doc.json
}


