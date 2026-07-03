# =============================================================================
# OUTPUTS — Lab 05 RDS Multi-AZ
# =============================================================================

output "primary_endpoint" {
  description = "Endpoint da instância primária — use para leitura e escrita"
  value       = aws_db_instance.primary.endpoint
}

output "primary_address" {
  description = "Hostname da instância primária"
  value       = aws_db_instance.primary.address
}

output "replica_endpoint" {
  description = "Endpoint da Read Replica — use apenas para leitura"
  value       = aws_db_instance.replica.endpoint
}

output "db_name" {
  description = "Nome do banco de dados criado"
  value       = aws_db_instance.primary.db_name
}

output "db_port" {
  description = "Porta do MySQL"
  value       = aws_db_instance.primary.port
}

output "multi_az_enabled" {
  description = "Indica se Multi-AZ está habilitado na instância primária"
  value       = aws_db_instance.primary.multi_az
}

output "primary_availability_zone" {
  description = "AZ atual da instância primária — muda após failover"
  value       = aws_db_instance.primary.availability_zone
}

output "connection_string" {
  description = "String de conexão MySQL CLI para testar"
  value       = "mysql -h ${aws_db_instance.primary.address} -P ${aws_db_instance.primary.port} -u ${aws_db_instance.primary.username} -p ${aws_db_instance.primary.db_name}"
  sensitive   = false
}
