resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = length(var.public_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-private-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public_to_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-private-route-table"
  }
}

resource "aws_route_table_association" "private_association" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "nat" {
  name   = "${var.name}-nat-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Allow all inbound traffic private suvbnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.private_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-nat-sg"
  }
}

resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat.id]
  source_dest_check      = false

  root_block_device {
    encrypted = true
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Install iptables for NAT
    sudo yum install iptables-services -y
    sudo systemctl enable iptables
    sudo systemctl start iptables

    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/custom-ip-forwarding.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

    # Get the primary network interface
    iface=$(netstat -i | awk 'NR>2 {print $1}' | grep -E '^(eth|en)' | head -n 1)

    # Configure NAT masquerading
    sudo /sbin/iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
    sudo /sbin/iptables -F FORWARD
    sudo service iptables save

    # Enable SSH for Bastion functionality
    sudo yum update -y
    sudo yum install -y openssh-server
    sudo systemctl enable sshd
    sudo systemctl start sshd
  EOF

  tags = {
    Name = "${var.name}-nat-instance"
  }
}

resource "aws_route" "private_to_nat_instance" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.ec2_instance.primary_network_interface_id
}
