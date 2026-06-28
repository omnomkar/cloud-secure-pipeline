data "aws_ami" "amazon_linux" {
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
  name        = "${var.project_name}-nat-sg"
  description = "Allow the private subnet to route through the NAT instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic from the private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  egress {
    description = "All outbound traffic to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nat-sg"
  }
}

resource "aws_iam_role" "nat_instance" {
  name = "${var.project_name}-nat-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM access only - no SSH key is ever created or attached to this instance.
resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  name = "${var.project_name}-nat-instance-profile"
  role = aws_iam_role.nat_instance.name
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  iam_instance_profile        = aws_iam_instance_profile.nat_instance.name
  associate_public_ip_address = true

  # Required for a NAT instance: it must be able to forward traffic that
  # isn't addressed to itself.
  source_dest_check = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # enforce IMDSv2
  }

  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/templates/nat-user-data.sh.tpl", {
    private_subnet_cidr = var.private_subnet_cidr
  })

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}
