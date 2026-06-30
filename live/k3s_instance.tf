resource "aws_iam_role" "k3s_instance" {
  name = "${var.project_name}-k3s-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Same as the NAT instance: this is the only way this box is ever reached.
resource "aws_iam_role_policy_attachment" "k3s_instance_ssm" {
  role       = aws_iam_role.k3s_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege ECR pull access - nothing else.
resource "aws_iam_role_policy" "k3s_instance_ecr" {
  name = "${var.project_name}-k3s-ecr-pull"
  role = aws_iam_role.k3s_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcrAuthToken"
        Effect = "Allow"
        # ecr:GetAuthorizationToken has no resource-level permissions in
        # IAM - AWS requires it be granted on "*". This is not an
        # oversight; there is no narrower scope available for this action.
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid      = "EcrPullThisRepoOnly"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_instance" {
  name = "${var.project_name}-k3s-instance-profile"
  role = aws_iam_role.k3s_instance.name
}

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "k3s node - no inbound access; reachable only via SSM Session Manager"
  vpc_id      = aws_vpc.main.id

  # Intentionally zero ingress rules. SSM Session Manager requires no
  # inbound ports at all - the SSM agent only makes outbound connections
  # to the SSM endpoints. There is nothing missing here.

  egress {
    description = "All outbound traffic (ECR, SSM endpoints, etc.) - routed via the NAT instance"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k3s-sg"
  }
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.k3s_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_instance.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # enforce IMDSv2

    # Default hop limit is 1, which only reaches IMDS requests made
    # directly from the host's network namespace. boto3 running inside a
    # pod is one extra network hop away (host -> pod), so a hop limit of 1
    # makes its IMDS calls silently time out - boto3 then reports "unable
    # to locate credentials" with nothing pointing at IMDS as the cause.
    # 2 hops covers host -> pod without raising the limit any further than
    # this instance's own workloads need.
    http_put_response_hop_limit = 2
  }

  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/templates/k3s-user-data.sh.tpl", {
    k3s_version = var.k3s_version
  })

  tags = {
    Name = "${var.project_name}-k3s-instance"
  }
}

# k3s v1.36+ (Kubernetes 1.36) fully removed cgroup v1 support, and
# Amazon Linux 2 defaults to cgroup v1. Amazon Linux 2023 defaults to
# cgroup v2, so the k3s node needs its own AMI lookup, separate from
# the NAT instance's Amazon Linux 2 AMI.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}