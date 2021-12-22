
#################
# aws providers
#################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
 }

##################
# aws region name
##################

provider "aws" {
        region = "region_name"
        shared_credentials_file = "~/.aws/credentials"
}

#############
# vpc aws
#############

resource "aws_vpc" "main" {
  cidr_block = "10.8.0.0/16"
}

###################
# two public subnet 
###################


resource "aws_subnet" "public-01" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.11.128.0/18"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-01"
  }
}

resource "aws_subnet" "public-02" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.11.256.0/18"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-02"
  }
}

######################
# instance web-server
######################

resource "aws_instance" "my-instance" {
        ami = "ami-092cce4a19b438926"
        instance_type = "t3.micro"
        key_name  = aws_key_pair.ec2.key_name
        vpc_security_group_ids = [aws_security_group.allow_ssh.id, aws_security_group.allow_elb.id]
        subnet_id = aws_subnet.public-01.id
        user_data = << EOF
                #! /bin/bash
                sudo apt-get update
                sudo apt-get install -y nginx
                sudo systemctl start nginx
                sudo systemctl enable nginx
                echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
        EOF >>

         tags = {
    Name = var.instance_name
  }
}

#####################
# default route table
#####################

resource "aws_route_table" "default_rt" {
  vpc_id = aws_vpc.main.id

  route = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      nat_gateway_id             = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    }
  ]

  tags = {
    Name = "myroutetable"
  }
}

##################
# internet gateway
##################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

#################
# nginx lb
#################

resource "aws_lb" "mylb" {
  name               = "nginxlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.public-01.id, aws_subnet.public-02.id]

  enable_deletion_protection = false
}

###############
# lb listener
###############

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myec2.arn
  }
}

########################
# aws_security_group web
########################

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow WEB inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = [
    {
      description      = "WEB from World"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]
egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]


  tags = {
    Name = "allow_web"
  }
}

###################
#security_group elb
###################

resource "aws_security_group" "allow_elb" {
  name        = "allow_elb"
  description = "Allow ELB inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = [
    {
      description      = "From ELB to EC2"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = [aws_security_group.allow_web.id]
      self = false
    }
  ]
egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]


  tags = {
    Name = "allow_elb"
  }
}

###################################
#  aws_main_route_table_association
###################################

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.default_rt.id
}

#######################
#  output "instance_ip"
#######################

output "instance_ip" {
  value = aws_instance.test_instance.*.public_ip

}
