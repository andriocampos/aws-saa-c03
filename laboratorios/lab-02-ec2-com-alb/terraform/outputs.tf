# =============================================================================
# OUTPUTS — Lab 02 EC2 com ALB e ASG
# =============================================================================

output "alb_dns_name" {
  description = "DNS do ALB — acesse este endereço no browser para ver o lab funcionando"
  value       = "http://${aws_lb.web.dns_name}"
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.web.arn
}

output "target_group_arn" {
  description = "ARN do Target Group"
  value       = aws_lb_target_group.web.arn
}

output "asg_name" {
  description = "Nome do Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID do Launch Template"
  value       = aws_launch_template.web.id
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas (uma por AZ)"
  value       = [for s in aws_subnet.public : s.id]
}
