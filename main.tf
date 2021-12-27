
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
        region = "eu-north-1"
        shared_credentials_file = "~/.aws/credentials"

}

#############
# vpc aws
#############

resource "aws_vpc" "main" {
  cidr_block = "10.8.0.0/16"
  tags = {
    Name = "main"
  }
}


###################
# two public subnet 
###################


resource "aws_subnet" "new-public-01" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.8.128.0/18"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "new-public-01"
  }
}


resource "aws_subnet" "new-public-02" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.8.192.0/18"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "new-public-02"
  }
}




resource "aws_lb" "mylb" {
  name               = "testnginxlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.new-public-01.id, aws_subnet.new-public-02.id]

  enable_deletion_protection = false
}



resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myec2.arn
  }
}


resource "aws_lb_target_group" "myec2" {
  name        = "testnginx"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
}



resource "aws_lb_target_group_attachment" "testnginx" {
  target_group_arn = aws_lb_target_group.myec2.arn
  target_id        = aws_instance.test_instance.id
  port             = 80
}




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



resource "aws_security_group" "allow_elb" {
  name        = "allow_elb"
  description = "Allow ELB inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = [
    {
      description      = "From ELB to EC2"
      from_port        = 80
      to_port          = 80
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



resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}
 




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






resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.default_rt.id
}






resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress =  [
    {
      description      = "SSH from World"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self = false
  }
]

  egress = [
      {
        description    = "for All outgoing traffics"
        from_port      = 0
        to_port        = 0
        protocol       = "-1"
        cidr_blocks    = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
        prefix_list_ids = []
        security_groups = []
        self = false
  }
 ]


  tags = {
    Name = "allow_ssh"
  }
}





#resource "aws_key_pair" "ec2" {
#  key_name   = "ec2"
#  public_key = file("~/.ssh/ec2.pub")
# }



resource "aws_instance" "test_instance" {
  ami           = "ami-092cce4a19b438926"
  instance_type = "t3.micro"
  key_name      = "ubuntu"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id     = aws_subnet.new-public-01.id
  user_data     = "${file("install_nginx.sh")}"


  tags = {
    Name = "nginx"
 }
}






output "instance_ip" {
  value = aws_instance.test_instance.*.public_ip

}
