resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}

resource "aws_route_table_association" "rt1a" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rt1b" {
   subnet_id = aws_subnet.sub2.id
   route_table_id = aws_route_table.rt.id
  
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "webapp-sg"
  }


# Ingress rules (inbound)
ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Egress rules (outbound)
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"  # -1 means all protocols
    cidr_blocks      = ["0.0.0.0/0"]
  }

}

resource "aws_s3_bucket" "s3_bux" {
  bucket = "my-tf-demo-bucket19"

  tags = {
    Name        = "My bucket"
    Environment = "Test"
  }
}

# resource "aws_s3_bucket_public_access_block" "access" {
#   bucket = aws_s3_bucket.s3_bux.id

#   block_public_acls = false
#   block_public_policy = false
#   ignore_public_acls = false
#   restrict_public_buckets = false

# }

# resource "aws_s3_bucket_acl" "acl" {
  # depends_on = [ 
  #   aws_s3_bucket_ownership_control.s3_bux,
  #   aws_s3_bucket_public_access_block.access
  #  ]
#   bucket = aws_s3_bucket.s3_bux.id
#   acl = "public_read"
# }

resource "aws_instance" "webvm1" {
  ami           = "ami-02521d90e7410d9f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.app_sg.id ]
  subnet_id = aws_subnet.sub1.id
  user_data = (file("userdata.sh"))
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_instance" "webvm2" {
  ami           = "ami-02521d90e7410d9f0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.app_sg.id ]
  subnet_id = aws_subnet.sub2.id
  user_data = (file("userdata1.sh"))
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_lb" "mylb" {
  name = "myalb"
  internal = false
  load_balancer_type = "application"

  security_groups = [ aws_security_group.app_sg.id ]
  subnets = [ aws_subnet.sub1.id, aws_subnet.sub2.id ]
  tags = {
    Name = "Webapp"
  }  
}

resource "aws_lb_target_group" "tg" {
  name     = "alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

}

resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webvm1.id
    port = 80
  }

  resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webvm2.id
    port = 80
  }

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "lbdns" {
  value = aws_lb.mylb.dns_name
  
}