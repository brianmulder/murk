# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "dark" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "dark" {
  vpc_id = "${aws_vpc.dark.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.dark.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.dark.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "dark" {
  vpc_id                  = "${aws_vpc.dark.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Our security group to access the instances over SSH
resource "aws_security_group" "dark" {
  name        = "dark"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.dark.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "dark" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    user = "centos"
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.dark.id}"]

  subnet_id = "${aws_subnet.dark.id}"

  provisioner "file" {
    source = "lettherebelight.yml"
    destination = "~/lettherebelight.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install epel-release",
      "sudo yum -y install ansible",
      "echo localhost ansible_connection=local | sudo tee --append /etc/ansible/hosts",
      "ansible-playbook ~/lettherebelight.yml"
    ]
  }
}
