# Create a new instance of the latest Ubuntu 18.04 on an instance,
# t2.micro node. If you are not sure of what you are trying to find,
# try this using the AWS command line:
#
# aws ec2 describe-images --owners 099720109477 \
#   --filters "Name=name,Values=*hvm-ssd*bionic*18.04-amd64*" \
#   --query 'sort_by(Images, &CreationDate)[].Name'

provider "aws" {
  region = "us-west-1"
}

variable "instance_names" {
  type    = list(string)
  default = ["vault"]
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu" {
  count                  = length(var.instance_names)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  subnet_id              = aws_subnet.interrupt_subnet.id
  vpc_security_group_ids = [aws_security_group.interrupt_nsg.id]

  tags = merge(map(
    "Name", var.instance_names[count.index]
  ), var.tags)
}

resource "aws_vpc" "interrupt_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = merge(map(
    "Name", "Interrupt VPC"
  ), var.tags)
}

resource "aws_subnet" "interrupt_subnet" {
  vpc_id                  = aws_vpc.interrupt_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(map(
    "Name", "Interrupt Subnet"
  ), var.tags)
}

resource "aws_security_group" "interrupt_nsg" {
  name        = "interrupt_nsg"
  description = "Interrupt inbound traffic"
  vpc_id      = aws_vpc.interrupt_vpc.id

  tags = merge(map(
    "Name", "Interrupt NSG"
  ), var.tags)
}

resource "aws_security_group_rule" "tls" {
  description       = "Sample TLS Connection"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interrupt_nsg.id
}

resource "aws_security_group_rule" "ssh" {
  description       = "SSH Access"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interrupt_nsg.id
}

resource "aws_security_group_rule" "Vault-API" {
  description       = "Vault API"
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interrupt_nsg.id
}

resource "aws_security_group_rule" "Allow-All" {
  description       = "Allow all outbound traffic."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interrupt_nsg.id
}

resource aws_internet_gateway "interrupt_gw" {
  vpc_id = aws_vpc.interrupt_vpc.id

  tags = merge(map(
    "Name", "Interrupt Gateway"
  ), var.tags)

}

resource aws_route_table "interrupt_rt" {
  vpc_id = aws_vpc.interrupt_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.interrupt_gw.id
  }

  tags = merge(map(
    "Name", "Interrupt Routing Table"
  ), var.tags)

}

resource aws_route_table_association "interrupt" {
  subnet_id      = aws_subnet.interrupt_subnet.id
  route_table_id = aws_route_table.interrupt_rt.id
}

resource "aws_key_pair" "ssh" {
  key_name   = var.key_name
  public_key = var.ssh_key
}

data "aws_instance" "awsvm" {
  instance_id = aws_instance.ubuntu[0].id
}

output "public_ip" {
  value       = data.aws_instance.awsvm.public_ip
  description = "The public IP of the web server"
}

# Create customized output for reference. In this case, a local variable and a data source.
output "ssh_command" {
  value = "ssh -i ~/.ssh/interrupt_rsa ubuntu@${data.aws_instance.awsvm.public_ip}"
}
