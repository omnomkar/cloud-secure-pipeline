output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "nat_instance_id" {
  description = "ID of the NAT instance"
  value       = aws_instance.nat.id
}

output "nat_instance_private_ip" {
  description = "Private IP address of the NAT instance"
  value       = aws_instance.nat.private_ip
}

output "k3s_instance_id" {
  description = "ID of the k3s node instance"
  value       = aws_instance.k3s.id
}

output "k3s_instance_private_ip" {
  description = "Private IP address of the k3s node instance"
  value       = aws_instance.k3s.private_ip
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the app image"
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC - paste this into the repo's AWS_ROLE_ARN Actions variable"
  value       = aws_iam_role.github_actions_deploy.arn
}
