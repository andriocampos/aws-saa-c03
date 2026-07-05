# Revisão de Erros

> Registre aqui as questões que errou com a explicação correta.
> Este arquivo é sua principal ferramenta de melhoria contínua.

---

## Como usar

1. Após cada simulado, revise cada questão errada
2. Registre o resumo da questão, sua resposta e a resposta correta
3. Escreva com suas palavras por que a resposta correta está certa
4. Categorize o erro (conceito errado, confusão entre serviços, distrator)

---

## Erros — Quiz IAM (04/07/2026) — Score: 23/30 (76%)

### Erro 01
- **Serviço:** STS / Cognito
- **Questão:** App mobile com Google Sign-In precisa acesso temporário AWS
- **Minha resposta:** B (AssumeRoleWithSAML)
- **Resposta correta:** C (AssumeRoleWithWebIdentity via Cognito)
- **Por que está correta:** SAML = corporativo (AD). Web Identity = social (Google, Facebook). Cognito é o recomendado para apps mobile.
- **Tipo de erro:** [x] Confusão entre serviços

### Erro 02
- **Serviço:** IAM Identity Center
- **Questão:** AD on-premises + SSO Console AWS
- **Minha resposta:** D (Simple AD)
- **Resposta correta:** B (IAM Identity Center integrado ao AD)
- **Por que está correta:** Directory Service gerencia o AD. Identity Center FAZ o SSO. Para login no Console = Identity Center.
- **Tipo de erro:** [x] Confusão entre serviços

### Erro 03
- **Serviço:** STS
- **Questão:** Duração padrão de credenciais sts:AssumeRole
- **Minha resposta:** A (15 minutos)
- **Resposta correta:** B (1 hora)
- **Por que está correta:** 15 min é o MÍNIMO. Padrão = 1h. Máximo = 12h. GetSessionToken padrão = 12h.
- **Tipo de erro:** [x] Não sabia

### Erro 04
- **Serviço:** IAM Access Analyzer
- **Questão:** O que significa findings no Access Analyzer para um bucket S3
- **Minha resposta:** D (bucket policy com erros de sintaxe)
- **Resposta correta:** B (bucket acessível por entidades externas à zona de confiança)
- **Por que está correta:** Access Analyzer = detecta recursos EXPOSTOS externamente. Não analisa sintaxe.
- **Tipo de erro:** [x] Conceito errado

### Erro 05
- **Serviço:** IAM Credentials Report
- **Questão:** O que o Credentials Report gera
- **Minha resposta:** C (recursos acessados por user nos últimos 90 dias)
- **Resposta correta:** B (CSV com status de senhas, keys e MFA de todos Users)
- **Por que está correta:** Report = status de credenciais. Access Advisor = último acesso por serviço. Confundi os dois.
- **Tipo de erro:** [x] Confusão entre serviços

### Erro 06
- **Serviço:** IAM Conditions
- **Questão:** Dar acesso S3 a toda Organization sem listar cada conta
- **Minha resposta:** A (Principal: '*' sem Condition)
- **Resposta correta:** B (Condition aws:PrincipalOrgID)
- **Por que está correta:** Principal:* sem condition = público (PERIGO). PrincipalOrgID filtra para apenas a Organization.
- **Tipo de erro:** [x] Não sabia

### Erro 07
- **Serviço:** IAM Identity Center
- **Questão:** O que Permission Set cria ao ser atribuído a uma conta
- **Minha resposta:** D (policy inline na Management Account)
- **Resposta correta:** B (IAM Role na conta destino)
- **Por que está correta:** Permission Set = cria Role automaticamente na conta destino. User assume essa Role temporariamente.
- **Tipo de erro:** [x] Conceito errado

---

## Erros — Simulado 2

### Erro 01
- **Serviço:** 
- **Questão:** 
- **Minha resposta:** 
- **Resposta correta:** 
- **Por que está correta:** 
- **Tipo de erro:** [ ] Conceito errado [ ] Confusão entre serviços [ ] Distrator [ ] Não sabia

---

## Erros — Simulado 3

### Erro 01
- **Serviço:** 
- **Questão:** 
- **Minha resposta:** 
- **Resposta correta:** 
- **Por que está correta:** 
- **Tipo de erro:** [ ] Conceito errado [ ] Confusão entre serviços [ ] Distrator [ ] Não sabia

---

## Padrões de Erro Recorrentes

| Tema | Frequência de erro | Ação corretiva |
|------|-------------------|----------------|
| Federação / Identity Center | 3 erros | Reler simulados/reforco-iam-erros.md seção 1 |
| Ferramentas de auditoria IAM | 2 erros | Decorar: Report=status, Advisor=uso, Analyzer=exposição |
| Detalhes STS / Conditions | 2 erros | Memorizar tabela de durações + PrincipalOrgID |

---

## Diferenças Críticas que Me Confundem

| Par | Diferença Principal |
|-----|---------------------|
| Directory Service vs Identity Center | Directory = gerencia AD. Identity Center = faz SSO no Console |
| Access Analyzer vs Access Advisor | Analyzer = recursos expostos. Advisor = permissões não usadas |
| Credentials Report vs Access Advisor | Report = CSV de status (MFA, keys). Advisor = último acesso por serviço |
| AssumeRoleWithSAML vs WebIdentity | SAML = corporativo (AD). WebIdentity = social (Google, Facebook) |
| Identity Center vs Cognito | Identity Center = funcionários + Console. Cognito = clientes de apps |
| Multi-AZ vs Read Replica | |
| Security Group vs NACL | |
| CloudFront vs Global Accelerator | |
| Secrets Manager vs SSM Parameter Store | |
| SNS vs SQS vs EventBridge | |
