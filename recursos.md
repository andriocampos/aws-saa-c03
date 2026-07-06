# Recursos de Estudo — SAA-C03

---

## Curso Principal

### Stephane Maarek — Ultimate AWS Certified Solutions Architect Associate
- **Plataforma:** Udemy
- **Link:** https://www.udemy.com/course/aws-certified-solutions-architect-associate-saa-c03/
- **Por que usar:** O mais completo e atualizado para SAA-C03. Cobre todos os domínios com profundidade.
- **Duração:** ~27 horas de vídeo
- **Dica:** Comprar na promoção do Udemy (normalmente R$27-R$34). Nunca pagar preço cheio.

---

## Simulados

### Tabela Comparativa

| Plataforma | Preço | Qualidade | Observação |
|------------|:-----:|:---------:|------------|
| Tutorials Dojo | ~$15 | ⭐⭐⭐⭐⭐ | Mais próximo da prova real, melhor custo-benefício |
| Whizlabs | ~$20 | ⭐⭐⭐⭐ | Bom volume (600+ questões), explicações detalhadas |
| Neal Davis (Digital Cloud Training) | ~$20 | ⭐⭐⭐⭐ | Questões bem escritas, cheat sheets inclusos |
| Stephane Maarek (Udemy) | ~$15 | ⭐⭐⭐⭐ | Complementa o curso dele, 300+ questões |
| AWS Skill Builder | Gratuito | ⭐⭐⭐ | Simulado oficial da AWS (20 questões grátis) |
| ExamTopics | Gratuito | ⭐⭐ | Banco da comunidade — cuidado com respostas erradas |

### Links

- **Tutorials Dojo (Udemy):** https://www.udemy.com/course/aws-certified-solutions-architect-associate-amazon-practice-exams-saa-c03/
- **Tutorials Dojo (Portal):** https://portal.tutorialsdojo.com/courses/aws-certified-solutions-architect-associate-practice-exams/
- **Whizlabs:** https://www.whizlabs.com/aws-solutions-architect-associate/
- **Neal Davis (Udemy):** https://www.udemy.com/course/aws-certified-solutions-architect-associate-practice-tests-k/
- **Stephane Maarek (Udemy):** https://www.udemy.com/course/practice-exams-aws-certified-solutions-architect-associate/
- **AWS Skill Builder (oficial gratuito):** https://explore.skillbuilder.aws/learn/course/external/view/elearning/13266/aws-certified-solutions-architect-associate-official-practice-question-set
- **ExamTopics:** https://www.examtopics.com/exams/amazon/aws-certified-solutions-architect-associate-saa-c03/

### Recomendação por Fase

```
AGORA (aprendendo — semanas 1-8):
  → Nossos quizzes por tópico (simulados/quiz-*.py)
  → AWS Skill Builder (grátis, oficial — como termômetro)

SEMANA 9-10 (simulados full — 65 questões cronometradas):
  → Tutorials Dojo (6 exams x 65 questões = 390 questões) — OBRIGATÓRIO
  → Stephane Maarek Practice Exams (se já faz o curso dele)

SE QUISER MAIS:
  → Whizlabs ou Neal Davis como terceira fonte
```

### O que Evitar

- **ExamTopics** — muitas respostas erradas nos comentários, confunde mais do que ajuda
- **Brain dumps** — questões vazadas são antiéticas e frequentemente desatualizadas
- **Simulados genéricos** — se não menciona "SAA-C03" especificamente, pode ser da versão antiga (C02)

### Meta nos Simulados

| Fase | Meta | Ação |
|------|:----:|------|
| Primeiros simulados | 65-70% | Normal — identificar gaps |
| Após reforço | 75-80% | Revisar erros e refazer |
| Pré-prova | 80%+ consistente | Pode agendar a prova |

---

## Documentação AWS

### Whitepapers Essenciais
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
  - Os 6 pilares: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, Sustainability
- [AWS Overview: The Simplest Guide](https://d1.awsstatic.com/whitepapers/aws-overview.pdf)
- [Architecting for the Cloud: Best Practices](https://d1.awsstatic.com/whitepapers/AWS_Cloud_Best_Practices.pdf)
- [Disaster Recovery on AWS](https://d1.awsstatic.com/whitepapers/aws-disaster-recovery.pdf)

### FAQs dos Serviços (leitura obrigatória)
- [EC2 FAQ](https://aws.amazon.com/ec2/faqs/)
- [S3 FAQ](https://aws.amazon.com/s3/faqs/)
- [VPC FAQ](https://aws.amazon.com/vpc/faqs/)
- [RDS FAQ](https://aws.amazon.com/rds/faqs/)
- [Lambda FAQ](https://aws.amazon.com/lambda/faqs/)
- [IAM FAQ](https://aws.amazon.com/iam/faqs/)

---

## Recursos Gratuitos

### AWS Free Tier
- **Link:** https://aws.amazon.com/free/
- **Usar para:** EC2 (t2.micro/t3.micro), S3 (5GB), RDS (t2.micro/t3.micro), Lambda (1M requests/mês)
- **Atenção:** Monitorar o billing para não ter surpresas. Configurar alertas no CloudWatch Billing.

### AWS Skill Builder (gratuito)
- **Link:** https://skillbuilder.aws/
- Cursos gratuitos oficiais da AWS por serviço
- Laboratórios guiados (alguns pagos, outros gratuitos)

### AWS Documentation
- **Link:** https://docs.aws.amazon.com/
- Consultar quando tiver dúvidas específicas durante o estudo

### YouTube
- **Canal AWS:** https://www.youtube.com/@amazonwebservices
- **Ótimos vídeos de re:Invent** explicando arquiteturas e serviços em profundidade

---

## Cheat Sheets

### Tutorials Dojo Cheat Sheets
- **Link:** https://tutorialsdojo.com/aws-cheat-sheets/
- Resumos concisos de cada serviço. Excelente para revisão rápida.
- Serviços disponíveis: EC2, S3, VPC, RDS, Lambda, IAM, e muitos outros

---

## Flashcards

### Anki
- **Link:** https://apps.ankiweb.net/
- Criar flashcards das diferenças críticas entre serviços
- Revisar diariamente (15-20 min)

### Exemplos de flashcards a criar
- "Qual a diferença entre Security Group e NACL?"
- "Quando usar CloudFront vs Global Accelerator?"
- "RDS Multi-AZ vs Read Replicas — qual a função de cada?"
- "Qual o limite de timeout do Lambda?"

---

## Comunidade

### Reddit
- **r/AWSCertifications:** https://www.reddit.com/r/AWSCertifications/
- Dicas de quem passou recentemente, recursos recomendados, experiências de prova

### Discord
- Buscar servidores de AWS Certifications no Discord para tirar dúvidas

---

## Ambiente de Prova

### Informações da Prova SAA-C03
- **Questões:** 65 (50 pontuadas + 15 não pontuadas/experimentais)
- **Duração:** 130 minutos
- **Formato:** Múltipla escolha e múltipla resposta
- **Nota mínima:** 720/1000
- **Idioma:** Disponível em Português (BR)
- **Modalidade:** Presencial (centro de testes) ou online proctored

### Dicas para o dia da prova
- Ler a pergunta com atenção — a AWS gosta de palavras-chave: "mais econômico", "mais disponível", "menor latência", "sem gerenciar servidores"
- Eliminar as alternativas claramente erradas primeiro
- Nas questões de múltipla resposta, o número de respostas corretas é sempre indicado
- Não mudar respostas sem certeza — confiar no primeiro instinto
- Gerenciar o tempo: ~2 min por questão

---

## Cronograma de Investimento

| Item | Custo Estimado |
|------|---------------|
| Curso Stephane Maarek (Udemy) | R$ 27-34 (promoção) |
| Simulados Tutorials Dojo | ~USD 14-20 |
| AWS Free Tier | Gratuito (com limites) |
| Voucher SAA-C03 | Já possui ✅ |
| **Total estimado** | **~R$ 100-150** |
