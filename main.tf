# Networking
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "yk-VPC"
  }
}

resource "aws_internet_gateway" "igwigw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwigw.id
  }
}

resource "aws_route_table_association" "public_rt" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "ec2-subnet"
  }
}

resource "aws_security_group" "ec2-sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Compute
resource "aws_instance" "yk-ec2" {
  ami = "ami-0c614dee691cbbf37"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2-sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "yk-ec2"
  }

  user_data = <<-EOF
              #!/bin/bash
              sleep 30
              mkfs -t ext4 /dev/xvdb
              mkdir -p /mnt/data
              mount /dev/xvdb /mnt/data

              UUID=$(sudo blkid -o value -s UUID /dev/xvdb)
              echo "$UUID /mnt/data ext4 defaults 0 0" >> /etc/fstab
  EOF
  
}

# Storage
resource "aws_ebs_volume" "ebs-ec2" {
  availability_zone = aws_subnet.public.availability_zone
  size = 1
  type = "gp3"

  tags = {
    Name = "ebs-ec2"
  }
}

# Associations
resource "aws_volume_attachment" "ebs_to_ec2" {
  device_name = "/dev/sdb"
  volume_id = aws_ebs_volume.ebs-ec2.id
  instance_id = aws_instance.yk-ec2.id
}