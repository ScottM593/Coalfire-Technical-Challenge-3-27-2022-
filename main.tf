# Configure the AWS Provider
provider "aws" {
  region = "us-west-1"
  access_key = "" #Removed by the user for security purposes
  secret_key = "" #Removed by the user for security purposes
}

# Creating the VPC
resource "aws_vpc" "scenario" {
  cidr_block = "10.1.0.0/16"
}

#Creating the gateway the traffic travels through
resource "aws_internet_gateway" "scenario-gateway" {
  vpc_id = aws_vpc.scenario.id
}

#Creating the routing table
resource "aws_route_table" "scen-routing" {
  vpc_id = aws_vpc.scenario.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.scenario-gateway.id
  }
}

#Creating the subnets
resource "aws_subnet" "Sub1" {
  vpc_id     = aws_vpc.scenario.id
  cidr_block = "10.1.0.0/24"
  availability_zone = "us-west-1a"
}

resource "aws_subnet" "Sub2" {
  vpc_id     = aws_vpc.scenario.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "us-west-1a"
}

resource "aws_subnet" "Sub3" {
  vpc_id     = aws_vpc.scenario.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "us-west-1c"
}

resource "aws_subnet" "Sub4" {
  vpc_id     = aws_vpc.scenario.id
  cidr_block = "10.1.3.0/24"
  availability_zone = "us-west-1c"
}

#Creating the associations that allow subnets 1 and 2 to access the internet
resource "aws_route_table_association" "one" {
  subnet_id      = aws_subnet.Sub1.id
  route_table_id = aws_route_table.scen-routing.id
}

resource "aws_route_table_association" "two" {
  subnet_id      = aws_subnet.Sub2.id
  route_table_id = aws_route_table.scen-routing.id
}
#Subnets 3 and 4 are not included so that they are not accessible from the internet

#Creating a security group for traffic
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound internet connections"
  vpc_id      = aws_vpc.scenario.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
#Creating a NIC for compute instances to use
resource "aws_network_interface" "redhat-nic" {
  subnet_id       = aws_subnet.Sub2.id
  private_ips     = ["10.1.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}

#This allows for the NIC to be associated with a specific IP
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.redhat-nic.id
  associate_with_private_ip = "10.1.1.50"
  depends_on = [aws_internet_gateway.scenario-gateway]
}

#Creating the computing instance
resource "aws_instance" "client-RedHat" {
  ami           = "ami-054965c6cd7c6e462" # us-east-1
  instance_type = "t2.micro"
  availability_zone = "us-west-1a"
  key_name = "test"


  root_block_device {
    volume_size = 20
  }
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.redhat-nic.id
  }
}

#Creating S3 buckets
resource "aws_s3_bucket" "lifecycle" {
  bucket = "lifecycle-test5930"
}

#Creating the folders
resource "aws_s3_bucket_object" "lifecycle-Images" {
  bucket = aws_s3_bucket.lifecycle.id
  key = "Images/"
}

#Defining the lifecycle rules for the folders
resource "aws_s3_bucket_object" "lifecycle-Logs" {
  bucket = aws_s3_bucket.lifecycle.id
  key = "Logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "transition" {
  bucket = aws_s3_bucket.lifecycle.id

  rule {
    id = "glacier"

    transition {
      days = 90
      storage_class = "GLACIER"
    }
    
    filter {
      prefix = "Images/"
    }
    status = "Enabled"
  }

  rule {
    id = "clear"
    
    expiration {
      days = 90
    }

    filter {
      prefix = "Logs/"
    }
    status = "Enabled"
  }
}
