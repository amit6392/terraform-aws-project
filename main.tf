resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

# create the first subnet 
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true #to create a public subnet 
}

#create the second subnet
resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

#creating the internet gateway this is helpful for accessing the internet and with this we need to create route table as well 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

#creation of the route table 
resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Now need to attach this route table to the public subnets 

resource "aws_route_table_association" "subnet-1-associate" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.my-route-table.id
}

resource "aws_route_table_association" "subnet-2-associate" {
  subnet_id = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.my-route-table.id
}

# Now we need to define the security groups 

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "web-sg"
  }
}

# create S3 bucket 
resource "aws_s3_bucket" "my-bucket" {
  bucket = "amit-das-first-project-terraform"
}

#create ec2 instance

resource "aws_instance" "webserver1" {
  ami = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id = aws_subnet.subnet-1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id = aws_subnet.subnet-2.id
  user_data = base64encode(file("userdata1.sh"))
}

#create alb

resource "aws_lb" "myalb" {
  name = "test-alb"
  internal = false #this is internet-facing and having public ip 
  load_balancer_type = "application"
  security_groups = [aws_security_group.webSg.id]
  subnets = [aws_subnet.subnet-1.id , aws_subnet.subnet-2.id]
}

resource "aws_lb_target_group" "tg" {
  name = "my-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "taget-group-attach1" {
  target_group_arn = aws_lb.myalb.arn
  target_id = aws_instance.webserver1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "taget-group-attach2" {
  target_group_arn = aws_lb.myalb.arn
  target_id = aws_instance.webserver2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "load-balancer-dns" {
  value = aws_lb.myalb.dns_name
}