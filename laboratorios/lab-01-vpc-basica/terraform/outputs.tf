# =============================================================================
# OUTPUTS — Lab 01 VPC Básica
# =============================================================================
# Outputs expõem valores dos recursos criados após o apply.
# Úteis para: consultar IDs, usar em outros módulos, verificar o que foi criado.
# =============================================================================

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID da subnet pública"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID da subnet privada"
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID do NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "IP público do NAT Gateway (Elastic IP) — saída das instâncias privadas"
  value       = aws_eip.nat.public_ip
}

output "sg_public_ec2_id" {
  description = "ID do Security Group para instâncias públicas"
  value       = aws_security_group.public_ec2.id
}

output "sg_private_ec2_id" {
  description = "ID do Security Group para instâncias privadas"
  value       = aws_security_group.private_ec2.id
}
