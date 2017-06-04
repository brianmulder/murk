provider "aws" {
  region  = "ap-southeast-2"
}

resource "aws_instance" "example" {
  ami            = "ami-881317eb"
  instance_type  = "t2.micro"

  tags {
    Name  = "terraform-example"
  }
}
