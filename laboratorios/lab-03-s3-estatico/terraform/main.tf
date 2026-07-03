# =============================================================================
# LAB 03 — S3 SITE ESTÁTICO
# =============================================================================
# O que este lab cria:
#   - Bucket S3 configurado para hospedagem de site estático
#   - Versionamento habilitado
#   - Lifecycle policy (transição e expiração de versões antigas)
#   - Bucket policy para acesso público de leitura
#   - Objetos index.html e error.html
#
# Conceitos SAA-C03 praticados:
#   - Static website hosting no S3
#   - Bucket policies (resource-based policy)
#   - Block Public Access: deve ser desabilitado para site público
#   - Versioning: protege contra deleções e sobrescritas acidentais
#   - Lifecycle rules: otimização de custo com transição de storage class
#   - S3 Object Ownership: necessário para ACLs públicas
# =============================================================================

# -----------------------------------------------------------------------------
# BUCKET S3
# O nome do bucket deve ser único em toda a AWS (globalmente).
# force_destroy = true permite deletar o bucket mesmo com objetos dentro
# (útil para labs — não use em produção sem cuidado).
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = true  # permite terraform destroy mesmo com objetos no bucket

  tags = var.tags
}

# -----------------------------------------------------------------------------
# BLOCK PUBLIC ACCESS
# Por padrão, a AWS bloqueia todo acesso público ao bucket.
# Para um site público, precisamos desabilitar esse bloqueio.
# Em produção, mantenha habilitado a menos que seja necessário acesso público.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false  # permite ACLs públicas
  block_public_policy     = false  # permite bucket policies públicas
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# -----------------------------------------------------------------------------
# OBJECT OWNERSHIP
# Necessário para permitir bucket policies públicas no S3 moderno.
# BucketOwnerPreferred: o dono do bucket é dono de todos os objetos.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# -----------------------------------------------------------------------------
# STATIC WEBSITE HOSTING
# Habilita o bucket como servidor de site estático.
# Após apply, o endpoint gerado é: http://BUCKET.s3-website-REGION.amazonaws.com
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"  # página principal
  }

  error_document {
    key = "error.html"  # página exibida em erros 4xx
  }
}

# -----------------------------------------------------------------------------
# VERSIONAMENTO
# Quando habilitado, cada upload cria uma nova versão do objeto.
# Versões antigas podem ser recuperadas ou restauradas.
# Importante: não confundir com replicação — versioning é local ao bucket.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# LIFECYCLE POLICY
# Regras automáticas para gerenciar o ciclo de vida dos objetos.
# Objetivo aqui: controlar versões antigas para evitar acúmulo de custo.
#
# Transições de storage class (do mais caro ao mais barato):
#   Standard → Standard-IA → Glacier → Glacier Deep Archive
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  depends_on = [aws_s3_bucket_versioning.website]

  rule {
    id     = "manage-old-versions"
    status = "Enabled"

    # filter vazio = aplica a todos os objetos do bucket
    filter {}

    # Aplica apenas a versões não-correntes (antigas)
    noncurrent_version_transition {
      noncurrent_days = 30               # após 30 dias sem ser a versão atual
      storage_class   = "STANDARD_IA"   # move para Standard-IA (acesso infrequente)
    }

    noncurrent_version_expiration {
      noncurrent_days = 90  # deleta versões antigas após 90 dias
    }
  }
}

# -----------------------------------------------------------------------------
# BUCKET POLICY
# Permite leitura pública de todos os objetos do bucket.
# Principal: "*" significa qualquer pessoa/serviço (público).
# Action: s3:GetObject permite apenas leitura, não upload ou delete.
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  # Depende do Public Access Block estar desabilitado
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"                          # qualquer pessoa
        Action    = "s3:GetObject"               # apenas leitura
        Resource  = "${aws_s3_bucket.website.arn}/*"  # todos os objetos
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# OBJETOS DO SITE
# O Terraform pode fazer upload de arquivos para o S3.
# content_type é importante para que o browser interprete corretamente.
# -----------------------------------------------------------------------------
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <title>AWS SAA-C03 Study Lab</title>
      <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        h1   { color: #FF9900; }
        p    { color: #232F3E; }
      </style>
    </head>
    <body>
      <h1>Lab 03 — S3 Site Estático</h1>
      <p>Hospedado no Amazon S3</p>
      <p>Estudando para AWS SAA-C03 🚀</p>
    </body>
    </html>
  HTML

  tags = var.tags
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <title>Erro</title>
    </head>
    <body>
      <h1>Página não encontrada</h1>
      <p><a href="/">Voltar para o início</a></p>
    </body>
    </html>
  HTML

  tags = var.tags
}
