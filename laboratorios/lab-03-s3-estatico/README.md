# Lab 03 — Hospedagem de Site Estático no S3

**Semana:** 02 | **Duração estimada:** 30 min | **Custo:** Free Tier (praticamente gratuito)

## Objetivo

Hospedar um site estático no S3, configurar versioning, lifecycle policy e experimentar pre-signed URLs.

## Passo a Passo

### 1. Criar Bucket S3
- [ ] S3 → Create Bucket
- Name: `lab-static-site-SEUNOME` (deve ser único globalmente)
- Region: us-east-1
- Desmarcar "Block all public access"
- Confirmar o aviso

### 2. Habilitar Static Website Hosting
- [ ] Properties → Static website hosting → Enable
- Index document: `index.html`
- Error document: `error.html`
- Anotar o endpoint do site

### 3. Configurar Bucket Policy (acesso público)
- [ ] Permissions → Bucket Policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::SEU-BUCKET-NAME/*"
    }
  ]
}
```

### 4. Fazer Upload dos Arquivos
- [ ] Criar `index.html` localmente:
```html
<!DOCTYPE html>
<html>
<head><title>Meu Site AWS</title></head>
<body>
  <h1>Estou estudando SAA-C03!</h1>
  <p>Hospedado no Amazon S3</p>
</body>
</html>
```
- [ ] Criar `error.html` com mensagem de erro
- [ ] Upload de ambos os arquivos para o bucket

### 5. Habilitar Versioning
- [ ] Properties → Bucket Versioning → Enable
- [ ] Editar `index.html` e fazer novo upload
- [ ] Verificar versões anteriores em Objects → Show versions

### 6. Configurar Lifecycle Policy
- [ ] Management → Lifecycle rules → Create
- Rule: mover versões antigas para Standard-IA após 30 dias
- Expirar versões antigas após 90 dias

### 7. Testar Pre-signed URL
- [ ] Via AWS CLI:
```bash
aws s3 presign s3://SEU-BUCKET/index.html --expires-in 300
```
- [ ] Acessar a URL gerada no browser (válida por 5 min)
- [ ] Remover acesso público e testar novamente com pre-signed URL

### 8. Testar o Site
- [ ] Acessar o endpoint do site no browser
- [ ] Acessar uma URL que não existe para ver o error.html

## Limpeza
- [ ] Deletar todos os objetos (incluindo versões)
- [ ] Deletar o bucket

## Anotações do Lab

### O que funcionou como esperado


### Surpresas ou dificuldades


### Conceitos reforçados

