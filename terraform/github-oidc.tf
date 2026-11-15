
# GitHub Actions OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "github-actions-oidc"
    Project = var.project_name
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:tahsinulhoque/cloud-native-service:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-github-actions"
    Project = var.project_name
  }
}

# SSM Deployment Permissions
resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "${var.project_name}-github-actions-ssm"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowRunCommandOnTargetInstance"
        Effect = "Allow"

        Action = [
          "ssm:SendCommand"
        ]

        Resource = aws_instance.app.arn
      },
      {
        Sid    = "AllowAWSRunShellScript"
        Effect = "Allow"

        Action = [
          "ssm:SendCommand"
        ]

        Resource = "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
      },
      {
        Sid    = "DescribeSSMInstances"
        Effect = "Allow"

        Action = [
          "ssm:DescribeInstanceInformation"
        ]

        Resource = "*"
      },
      {
        Sid    = "ReadCommandExecutionStatus"
        Effect = "Allow"

        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]

        Resource = "*"
      }
    ]
  })
}
