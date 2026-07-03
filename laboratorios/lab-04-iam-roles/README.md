# Lab 04 — IAM Roles e Políticas

**Semana:** 01 | **Duração estimada:** 45 min | **Custo:** Gratuito

## Objetivo

Entender na prática como usuários, grupos, roles e políticas funcionam, e como uma instância EC2 usa uma IAM Role para acessar recursos AWS sem credenciais hardcoded.

## Passo a Passo

### 1. Criar Grupo e Usuário IAM
- [ ] IAM → User Groups → Create Group
  - Name: `developers`
  - Permissões: `AmazonS3ReadOnlyAccess`
- [ ] IAM → Users → Create User
  - Name: `dev-user-01`
  - Adicionar ao grupo `developers`
  - Habilitar Console access
- [ ] Testar login com `dev-user-01`
  - Verificar que consegue listar buckets S3
  - Verificar que NÃO consegue criar buckets (ReadOnly)

### 2. Criar Política Customizada
- [ ] IAM → Policies → Create Policy
  - Usar JSON Editor:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::lab-static-site-*/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::lab-static-site-*"
    }
  ]
}
```
  - Name: `lab-s3-readwrite-policy`
- [ ] Anexar a política ao usuário `dev-user-01`
- [ ] Testar que agora consegue fazer upload em buckets com prefixo correto

### 3. Criar IAM Role para EC2
- [ ] IAM → Roles → Create Role
  - Trusted entity: AWS Service → EC2
  - Permissão: `AmazonS3ReadOnlyAccess`
  - Name: `lab-ec2-s3-role`
- [ ] Lançar instância EC2 t2.micro com a role `lab-ec2-s3-role`
- [ ] Conectar via EC2 Instance Connect
- [ ] Executar sem credenciais:
```bash
aws s3 ls
aws sts get-caller-identity
```
- [ ] Verificar que retorna informações da role, não de usuário

### 4. Testar MFA (opcional)
- [ ] Habilitar MFA virtual para `dev-user-01` via Google Authenticator
- [ ] Criar política que exige MFA para ações sensíveis:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

## Limpeza
- [ ] Terminar instância EC2
- [ ] Deletar usuário `dev-user-01`
- [ ] Deletar grupo `developers`
- [ ] Deletar role `lab-ec2-s3-role`
- [ ] Deletar política customizada

## Anotações do Lab

### O que funcionou como esperado


### Surpresas ou dificuldades


### Conceitos reforçados

