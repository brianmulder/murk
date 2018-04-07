variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.
Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "enable_ihaskell_host"     { default = 1 }
variable "enable_ihaskell_refresh"  { default = 0 }
variable "enable_docker_build_host" { default = 0 }

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "ap-southeast-2"
}

# CentOS Linux 7 https://wiki.centos.org/Cloud/AWS
# Requires subscription, do not be alarmed...
variable "centos_amis" {
  default = {
    ap-southeast-2 = "ami-b6bb47d4"
  }
}

variable "ubuntu_amis" {
  default = {
    ap-southeast-2 = "ami-79915c1b"
  }
}

variable "prepared_amis" {
  default = {
    ap-southeast-2 = "ami-3a5a9558"
  }
}

