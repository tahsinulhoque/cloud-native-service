output "ec2_instance_id" {
  description = "ID of the application EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IP address of the application"
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the application"
  value       = aws_instance.app.public_dns
}

output "application_url" {
  description = "Application health endpoint"
  value       = "http://${aws_instance.app.public_ip}/health"
}

output "vpc_id" {
  description = "ID of the custom VPC"
  value       = aws_vpc.main.id
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}
