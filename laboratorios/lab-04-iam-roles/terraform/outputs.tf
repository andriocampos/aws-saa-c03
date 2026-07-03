# =============================================================================
# OUTPUTS — Lab 04 IAM Roles e Políticas
# =============================================================================

output "iam_group_name" {
  description = "Nome do grupo IAM criado"
  value       = aws_iam_group.developers.name
}

output "custom_policy_arn" {
  description = "ARN da política customizada de S3 read+write"
  value       = aws_iam_policy.s3_readwrite.arn
}

output "ec2_role_name" {
  description = "Nome da IAM Role para EC2"
  value       = aws_iam_role.ec2_s3_role.name
}

output "ec2_role_arn" {
  description = "ARN da IAM Role — use ao associar a outros serviços"
  value       = aws_iam_role.ec2_s3_role.arn
}

output "instance_profile_name" {
  description = "Nome do Instance Profile — use ao lançar instâncias EC2"
  value       = aws_iam_instance_profile.ec2_s3_profile.name
}

output "instance_profile_arn" {
  description = "ARN do Instance Profile"
  value       = aws_iam_instance_profile.ec2_s3_profile.arn
}
