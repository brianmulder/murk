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

resource "aws_security_group" "sandbox" {
  name        = "sandbox"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.dark.id}"

  # SSH access from the perimeter
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.dark.id}"]
  }

  # HTTP access from certain security groups
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    self            = "true"
    security_groups = ["${aws_security_group.dark.id}"]
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
  tags {
    Name = "dark"
  }
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
    source = "ignition.playbook.yml"
    destination = "~/ignition.playbook.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install epel-release",
      "sudo yum -y install ansible",
      "echo localhost ansible_connection=local | sudo tee --append /etc/ansible/hosts",
      "ansible-playbook ~/ignition.playbook.yml"
    ]
  }
}

resource "aws_instance" "shine" {
  tags {
    Name = "shine"
  }
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.sandbox.id}"]
  subnet_id = "${aws_subnet.dark.id}"
  instance_type = "t2.large"
  ami = "${lookup(var.prepared_amis, var.aws_region)}"
}

# ... instead burn an image from scratch
#   instance_type = "t2.xlarge"
#   ami = "${lookup(var.ubuntu_amis, var.aws_region)}"
#   connection {
#     type = "ssh"
#     user = "ubuntu"
#     host = "${self.private_ip}"
#     bastion_host = "${aws_instance.dark.public_ip}"
#     bastion_user = "centos"
#   }
#   provisioner "file" {
#     source = "ihaskell.playbook.yml"
#     destination = "~/ihaskell.playbook.yml"
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt update",
#       "sudo apt upgrade -y",
#       "sudo apt install -y software-properties-common",
#       "sudo apt-add-repository -y ppa:ansible/ansible",
#       "sudo apt update",
#       "sudo apt install -y ansible",
#       "echo localhost ansible_connection=local | sudo tee --append /etc/ansible/hosts",
#       "ansible-playbook ~/ihaskell.playbook.yml"
#     ]
#   }
# }
