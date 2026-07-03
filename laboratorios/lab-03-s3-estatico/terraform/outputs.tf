# =============================================================================
# OUTPUTS — Lab 03 S3 Site Estático
# =============================================================================

output "bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN do bucket"
  value       = aws_s3_bucket.website.arn
}

output "website_endpoint" {
  description = "URL do site estático — acesse no browser após o apply"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "bucket_regional_domain" {
  description = "Domínio regional do bucket (usado como origin no CloudFront)"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}
