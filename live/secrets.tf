resource "aws_secretsmanager_secret" "app" {
  name = "${var.project_name}-app-secret"

  tags = {
    Name = "${var.project_name}-app-secret"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id     = aws_secretsmanager_secret.app.id
  secret_string = var.app_secret_value
}

# A separate policy resource (rather than folding this into
# k3s_instance_ecr in k3s_instance.tf) so the grant lives next to the
# secret it grants access to, and the ECR pull policy stays untouched by
# anything secrets-related - same instance role, attached from two places.
resource "aws_iam_role_policy" "k3s_instance_secrets" {
  name = "${var.project_name}-k3s-secrets-read"
  role = aws_iam_role.k3s_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAppSecretOnly"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.app.arn
      }
    ]
  })
}
