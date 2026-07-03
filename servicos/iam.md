# IAM — Identity and Access Management

## Conceitos Fundamentais

- **Usuários:** identidade permanente para uma pessoa ou serviço
- **Grupos:** coleção de usuários, não podem conter outros grupos
- **Roles:** identidade temporária assumida por usuários, serviços ou contas
- **Policies:** documentos JSON que definem permissões

## Tipos de Policy

| Tipo | Descrição |
|------|-----------|
| AWS Managed | Criadas e gerenciadas pela AWS |
| Customer Managed | Criadas por você, reutilizáveis |
| Inline | Anexadas diretamente a um usuário/grupo/role, não reutilizáveis |
| Resource-based | Anexadas a recursos (ex: S3 bucket policy) |

## Lógica de Avaliação

1. Deny explícito → sempre nega
2. Allow explícito → permite
3. Deny implícito (default) → nega tudo que não foi explicitamente permitido

## Boas Práticas

- Usar MFA para root e usuários privilegiados
- Nunca usar root para tarefas do dia a dia
- Princípio do menor privilégio
- Usar roles para serviços AWS (não access keys)
- Rotacionar access keys regularmente
- Usar grupos para atribuir permissões

## STS — Security Token Service

- Emite credenciais temporárias
- `AssumeRole`: trocar de role
- `AssumeRoleWithWebIdentity`: federação com IdP web (Cognito)
- `AssumeRoleWithSAML`: federação com SAML 2.0
- `GetSessionToken`: MFA para operações sensíveis

## Diferenças Críticas

- **Role vs User:** Role não tem credenciais permanentes; credenciais são temporárias via STS
- **Identity-based vs Resource-based:** Identity-based está na entidade; Resource-based está no recurso e permite cross-account sem AssumeRole
