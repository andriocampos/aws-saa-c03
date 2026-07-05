#!/usr/bin/env python3
"""Quiz IAM - 30 questões estilo SAA-C03 (interativo no terminal)"""

import random

QUESTIONS = [
    {
        "q": "Uma aplicação em EC2 precisa acessar S3. O time de segurança proíbe access keys em código. Qual a abordagem correta?",
        "opts": {
            "A": "Criar IAM User, gerar access keys e guardar no Secrets Manager",
            "B": "Criar IAM Role com policy de S3 e associar via Instance Profile",
            "C": "Criar bucket policy permitindo o IP da instância EC2",
            "D": "Usar pre-signed URLs com credenciais do root account"
        },
        "ans": "B",
        "exp": "Instance Profile + IAM Role é o padrão para dar permissões a EC2. Credenciais temporárias são rotacionadas automaticamente. Access keys são anti-pattern."
    },
    {
        "q": "Um User tem policy 'Allow s3:*' e a conta tem SCP com 'Deny s3:DeleteBucket'. O User tenta deletar um bucket. Resultado?",
        "opts": {
            "A": "Permitido — identity-based Allow s3:* vence",
            "B": "Negado — Deny explícito SEMPRE vence, independente de qualquer Allow",
            "C": "Permitido — SCPs não afetam Users, apenas contas",
            "D": "Negado — mas apenas se for Management Account"
        },
        "ans": "B",
        "exp": "Deny explícito SEMPRE vence. SCP com Deny sobrepõe qualquer Allow em identity-based policies. SCPs afetam todos os principals da conta-membro (inclusive root)."
    },
    {
        "q": "Qual afirmação sobre IAM Groups é VERDADEIRA?",
        "opts": {
            "A": "Um Group pode conter outros Groups (nesting)",
            "B": "Um Group pode ser usado como Principal em Trust Policies",
            "C": "Um User pode pertencer a no máximo 10 Groups",
            "D": "Groups podem ter credenciais próprias para acesso programático"
        },
        "ans": "C",
        "exp": "Limite de 10 groups por user. Groups NÃO podem conter outros groups, NÃO podem ser Principal em policies, e NÃO possuem credenciais."
    },
    {
        "q": "Lambda na Conta A precisa enviar mensagens para SQS na Conta B, mantendo acesso a recursos na Conta A. Melhor abordagem?",
        "opts": {
            "A": "AssumeRole para uma Role na Conta B",
            "B": "Resource-based policy na SQS permitindo a execution role da Lambda",
            "C": "Access keys da Conta B como variáveis de ambiente na Lambda",
            "D": "VPC Peering entre as contas"
        },
        "ans": "B",
        "exp": "Resource-based policy permite cross-account SEM perder permissões da conta de origem. AssumeRole faria a Lambda PERDER acesso à Conta A durante a sessão."
    },
    {
        "q": "Qual campo é OBRIGATÓRIO em resource-based policy mas NÃO existe em identity-based policy?",
        "opts": {
            "A": "Effect",
            "B": "Action",
            "C": "Principal",
            "D": "Resource"
        },
        "ans": "C",
        "exp": "Principal define QUEM recebe a permissão. Em identity-based, o principal é implícito (a entidade onde a policy está anexada). Em resource-based, deve ser explícito."
    },
    {
        "q": "DevOps precisa criar IAM Users que nunca tenham mais que S3 e CloudWatch. Qual mecanismo usar?",
        "opts": {
            "A": "SCP na OU do DevOps",
            "B": "Inline policy restritiva em cada User criado",
            "C": "Permission Boundary obrigatória via Condition na policy do DevOps",
            "D": "Negar iam:CreateUser e criar Users apenas via ticket"
        },
        "ans": "C",
        "exp": "Permission Boundary define o MÁXIMO de permissões. A Condition iam:PermissionsBoundary garante que o DevOps DEVE anexar o boundary ao criar Users."
    },
    {
        "q": "App mobile autentica com Google Sign-In e precisa de acesso temporário à AWS. Qual API STS?",
        "opts": {
            "A": "AssumeRole",
            "B": "AssumeRoleWithSAML",
            "C": "AssumeRoleWithWebIdentity (preferencialmente via Cognito)",
            "D": "GetSessionToken"
        },
        "ans": "C",
        "exp": "Web identity federation (Google, Facebook) usa AssumeRoleWithWebIdentity. Na prática, AWS recomenda usar Cognito Identity Pools que chama essa API internamente."
    },
    {
        "q": "Empresa usa AD on-premises e quer SSO no Console AWS para funcionários. Melhor solução?",
        "opts": {
            "A": "Criar IAM Users para cada funcionário sincronizando senhas",
            "B": "IAM Identity Center integrado ao Active Directory",
            "C": "AssumeRoleWithWebIdentity com AD como provedor",
            "D": "Cognito User Pools com federação SAML"
        },
        "ans": "B",
        "exp": "IAM Identity Center (ex-AWS SSO) é a solução padrão para SSO corporativo com AD. Gerencia acesso centralizado a múltiplas contas."
    },
    {
        "q": "User tem identity policy 'Allow ec2:*' e Permission Boundary com 'Allow ec2:Describe*, s3:GetObject'. O que pode fazer?",
        "opts": {
            "A": "Todas ações EC2 + s3:GetObject",
            "B": "Apenas ec2:Describe* (interseção entre identity e boundary)",
            "C": "Todas ações EC2 — boundary expande com s3:GetObject",
            "D": "ec2:Describe* + s3:GetObject"
        },
        "ans": "B",
        "exp": "Acesso efetivo = Identity Policy ∩ Permission Boundary. A interseção de 'ec2:*' com 'ec2:Describe* + s3:GetObject' resulta apenas em ec2:Describe*. s3:GetObject não está na identity policy."
    },
    {
        "q": "Conta-membro tem SCP 'Allow *'. User nessa conta NÃO tem policies. Pode acessar S3?",
        "opts": {
            "A": "Sim — SCP permite tudo",
            "B": "Não — SCP permite a possibilidade, mas User precisa de identity policy com Allow",
            "C": "Sim — sem Deny explícito, tudo é permitido",
            "D": "Depende da região"
        },
        "ans": "B",
        "exp": "SCP NÃO concede permissão — apenas define o MÁXIMO permitido. O User ainda precisa de um Allow explícito via identity-based policy. Sem policy = deny implícito."
    },
    {
        "q": "Qual a diferença de segurança entre IMDSv1 e IMDSv2 em EC2?",
        "opts": {
            "A": "IMDSv2 usa HTTPS, IMDSv1 usa HTTP",
            "B": "IMDSv2 requer token via PUT request antes de acessar metadata",
            "C": "IMDSv2 criptografa credenciais com KMS",
            "D": "IMDSv1 não fornece credenciais, apenas IMDSv2"
        },
        "ans": "B",
        "exp": "IMDSv2 exige PUT para obter token e depois GET com esse token. Protege contra SSRF (Server-Side Request Forgery) porque atacantes não conseguem fazer PUT facilmente."
    },
    {
        "q": "Garantir que NINGUÉM em nenhuma conta da Org possa desabilitar CloudTrail (incluindo root de contas-membro). Qual mecanismo?",
        "opts": {
            "A": "Permission Boundary em todos Users",
            "B": "SCP com Deny em cloudtrail:StopLogging e cloudtrail:DeleteTrail",
            "C": "Inline policy com Deny em todos Users e Roles",
            "D": "Config Rule que reverte a mudança"
        },
        "ans": "B",
        "exp": "SCP afeta TODOS os principals da conta-membro, incluindo root. É a única forma de impedir até o root de fazer algo. Permission Boundary não afeta root."
    },
    {
        "q": "Exigir MFA para deletar tabela DynamoDB de produção. Qual Condition Key usar?",
        "opts": {
            "A": "aws:SecureTransport",
            "B": "aws:MultiFactorAuthPresent",
            "C": "aws:TokenIssueTime",
            "D": "aws:PrincipalOrgID"
        },
        "ans": "B",
        "exp": "aws:MultiFactorAuthPresent verifica se MFA foi usado na sessão. Usado com Deny + BoolIfExists: false para bloquear ações sem MFA."
    },
    {
        "q": "Trust Policy com Principal: {'Service': 'lambda.amazonaws.com'}. Quem pode assumir essa Role?",
        "opts": {
            "A": "Qualquer User com permissão sts:AssumeRole",
            "B": "Apenas o serviço Lambda (funções Lambda usam como execution role)",
            "C": "Qualquer serviço AWS",
            "D": "Apenas Lambdas na mesma região"
        },
        "ans": "B",
        "exp": "Trust Policy define QUEM pode assumir. Service: lambda.amazonaws.com significa que apenas o serviço Lambda pode usar essa Role como execution role."
    },
    {
        "q": "50 contas AWS. Funcionários precisam SSO com login único para múltiplas contas. Qual serviço?",
        "opts": {
            "A": "IAM Groups com cross-account roles",
            "B": "IAM Identity Center (antigo AWS SSO)",
            "C": "Cognito User Pools",
            "D": "AWS Directory Service Simple AD"
        },
        "ans": "B",
        "exp": "IAM Identity Center é o serviço centralizado de SSO para múltiplas contas AWS em Organizations. Usa Permission Sets para definir acesso por conta."
    },
    {
        "q": "Qual é o MÁXIMO de usuários IAM por conta AWS?",
        "opts": {
            "A": "1.000",
            "B": "5.000",
            "C": "10.000",
            "D": "Ilimitado"
        },
        "ans": "B",
        "exp": "Limite hard de 5.000 users por conta. Para mais identidades, usar federação (Identity Center, Cognito) que não cria IAM Users."
    },
    {
        "q": "Uma policy tem Condition com múltiplos valores na mesma chave:\n'aws:RequestedRegion': ['us-east-1', 'eu-west-1']\nComo é avaliado?",
        "opts": {
            "A": "AND — deve ser us-east-1 E eu-west-1 simultaneamente",
            "B": "OR — vale se for us-east-1 OU eu-west-1",
            "C": "Apenas o primeiro valor é considerado",
            "D": "Gera erro de validação"
        },
        "ans": "B",
        "exp": "Múltiplos valores na MESMA chave = OR. Múltiplas chaves DIFERENTES no mesmo bloco = AND. Essa é uma pegadinha comum na prova."
    },
    {
        "q": "EC2 está rodando com uma Role via Instance Profile. De onde o SDK busca as credenciais?",
        "opts": {
            "A": "Do arquivo ~/.aws/credentials dentro da instância",
            "B": "Do Instance Metadata Service (169.254.169.254)",
            "C": "Do AWS Secrets Manager automaticamente",
            "D": "Do IAM diretamente via API pública"
        },
        "ans": "B",
        "exp": "O SDK busca credenciais temporárias do Instance Metadata Service em 169.254.169.254. As credenciais são rotacionadas automaticamente pelo EC2."
    },
    {
        "q": "Qual é a duração PADRÃO de credenciais retornadas por sts:AssumeRole?",
        "opts": {
            "A": "15 minutos",
            "B": "1 hora",
            "C": "6 horas",
            "D": "12 horas"
        },
        "ans": "B",
        "exp": "Padrão: 1 hora. Configurável de 15 minutos até 12 horas (dependendo do MaxSessionDuration da Role)."
    },
    {
        "q": "Um User na Conta A assume Role na Conta B via AssumeRole. Quais permissões tem durante a sessão?",
        "opts": {
            "A": "Soma das permissões da Conta A + permissões da Role na Conta B",
            "B": "Apenas as permissões da Role na Conta B (perde acesso à Conta A)",
            "C": "As permissões originais da Conta A com acesso adicional à Conta B",
            "D": "Nenhuma — precisa de resource-based policy no destino"
        },
        "ans": "B",
        "exp": "Ao AssumeRole, você 'veste' a Role e PERDE suas permissões originais. Ganha APENAS as permissões da Role assumida. Para manter ambas, use resource-based policy."
    },
    {
        "q": "Qual ferramenta IAM mostra o ÚLTIMO acesso de cada serviço por uma entidade (para aplicar least privilege)?",
        "opts": {
            "A": "IAM Credentials Report",
            "B": "IAM Access Advisor",
            "C": "IAM Access Analyzer",
            "D": "CloudTrail Insights"
        },
        "ans": "B",
        "exp": "Access Advisor mostra quando cada serviço foi acessado pela última vez. Permite identificar permissões não usadas para removê-las (least privilege)."
    },
    {
        "q": "IAM Access Analyzer encontrou findings para um bucket S3. O que isso significa?",
        "opts": {
            "A": "O bucket tem objetos corrompidos",
            "B": "O bucket está acessível por entidades FORA da zona de confiança (conta/org)",
            "C": "O bucket excedeu o limite de storage",
            "D": "A bucket policy tem erros de sintaxe"
        },
        "ans": "B",
        "exp": "Access Analyzer identifica recursos compartilhados com entidades EXTERNAS à sua zona de confiança (conta ou Organization). Finding = recurso exposto externamente."
    },
    {
        "q": "IAM Credentials Report gera informação sobre:",
        "opts": {
            "A": "Permissões efetivas de cada User",
            "B": "Status de senhas, access keys, MFA de TODOS os Users (CSV)",
            "C": "Recursos acessados por cada User nos últimos 90 dias",
            "D": "Policies anexadas a cada Group"
        },
        "ans": "B",
        "exp": "Credentials Report é um CSV com: user, password_enabled, password_last_used, access_key_active, access_key_last_rotated, mfa_active. Útil para auditoria de compliance."
    },
    {
        "q": "SCP pode afetar a Management Account da Organization?",
        "opts": {
            "A": "Sim — SCPs afetam todas as contas",
            "B": "Não — Management Account NUNCA é afetada por SCPs",
            "C": "Sim — mas apenas SCPs do tipo Deny",
            "D": "Depende de como o SCP foi configurado"
        },
        "ans": "B",
        "exp": "Management Account NUNCA é afetada por SCPs. Essa é uma regra absoluta. SCPs afetam apenas contas-membro e OUs."
    },
    {
        "q": "Qual a diferença PRINCIPAL entre Permission Boundary e SCP?",
        "opts": {
            "A": "Boundary aplica a Users/Roles; SCP aplica a contas inteiras/OUs",
            "B": "Boundary concede permissões; SCP apenas restringe",
            "C": "SCP é mais granular que Boundary",
            "D": "Boundary funciona cross-account; SCP apenas na mesma conta"
        },
        "ans": "A",
        "exp": "Permission Boundary: limita Users/Roles individuais (dentro de 1 conta). SCP: limita contas inteiras ou OUs (Organization-wide). Ambos apenas restringem, não concedem."
    },
    {
        "q": "Para restringir que recursos AWS só possam ser criados em us-east-1 e eu-west-1 em toda a Organization, qual Condition usar num SCP?",
        "opts": {
            "A": "aws:SourceIp com IPs das regiões",
            "B": "aws:RequestedRegion com StringNotEquals e NotAction para excluir serviços globais",
            "C": "aws:PrincipalOrgID com o ID da org",
            "D": "aws:SourceVpc com VPCs das regiões permitidas"
        },
        "ans": "B",
        "exp": "RequestedRegion + NotAction é o padrão. NotAction exclui serviços globais (IAM, STS, Organizations, Support) que precisam funcionar independente da região."
    },
    {
        "q": "Qual é o recurso que permite uma bucket policy no S3 dar acesso a QUALQUER conta da sua Organization sem listar cada Account ID?",
        "opts": {
            "A": "Principal: '*' sem Condition",
            "B": "Condition com aws:PrincipalOrgID",
            "C": "Principal com ARN da Organization",
            "D": "Condition com aws:SourceAccount"
        },
        "ans": "B",
        "exp": "aws:PrincipalOrgID permite que qualquer principal da Organization acesse o recurso. Evita manter lista manual de Account IDs. Muito útil em resource-based policies."
    },
    {
        "q": "O que é ABAC no contexto do IAM?",
        "opts": {
            "A": "Controle de acesso baseado em endereço IP",
            "B": "Controle de acesso baseado em tags/atributos (PrincipalTag, ResourceTag)",
            "C": "Controle de acesso baseado em horário",
            "D": "Controle de acesso baseado em MFA"
        },
        "ans": "B",
        "exp": "ABAC = Attribute-Based Access Control. Usa tags no principal e no recurso para controlar acesso. Vantagem: não precisa atualizar policies quando novos recursos são criados."
    },
    {
        "q": "Uma empresa quer usar IAM Identity Center com Permission Sets. Quando um Permission Set é atribuído a um usuário para uma conta específica, o que é criado automaticamente?",
        "opts": {
            "A": "Um IAM User na conta destino",
            "B": "Uma IAM Role na conta destino",
            "C": "Um IAM Group na conta destino",
            "D": "Uma policy inline na Management Account"
        },
        "ans": "B",
        "exp": "Permission Sets criam IAM Roles automaticamente nas contas destino. O usuário do Identity Center assume essas Roles temporariamente ao acessar cada conta."
    },
    {
        "q": "GetCallerIdentity do STS retorna informações sobre a identidade que fez a chamada. Em qual cenário é mais útil?",
        "opts": {
            "A": "Quando precisa rotacionar credenciais",
            "B": "Quando precisa verificar QUAL identidade/role está sendo usada (debugging)",
            "C": "Quando precisa gerar novas access keys",
            "D": "Quando precisa invalidar uma sessão"
        },
        "ans": "B",
        "exp": "GetCallerIdentity é a API de debugging — retorna Account, ARN e UserId da identidade chamadora. Útil para confirmar se você está usando a Role/User correto."
    },
]

def run_quiz():
    print("\n" + "=" * 65)
    print("   SIMULADO IAM — 30 QUESTÕES (Estilo AWS SAA-C03)")
    print("=" * 65)
    print("\nDigite a letra da alternativa (A, B, C ou D).")
    print("Digite 'q' para sair a qualquer momento.\n")
    print("-" * 65)

    score = 0
    total = len(QUESTIONS)
    errors = []

    for i, q in enumerate(QUESTIONS, 1):
        print(f"\n📋 Questão {i}/{total}")
        print(f"\n{q['q']}\n")
        for letter, text in q["opts"].items():
            print(f"   {letter}) {text}")

        while True:
            answer = input(f"\n   Sua resposta: ").strip().upper()
            if answer == 'Q':
                print(f"\n{'=' * 65}")
                print(f"   Quiz interrompido. Acertou {score}/{i-1} respondidas.")
                print(f"{'=' * 65}")
                return
            if answer in q["opts"]:
                break
            print("   ⚠️  Digite A, B, C ou D (ou 'q' para sair)")

        if answer == q["ans"]:
            score += 1
            print(f"\n   ✅ CORRETO!")
        else:
            print(f"\n   ❌ ERRADO! Resposta certa: {q['ans']}")
            errors.append({"num": i, "q": q["q"], "your": answer, "correct": q["ans"], "exp": q["exp"]})

        print(f"   💡 {q['exp']}")
        print(f"\n   Placar: {score}/{i} ({int(score/i*100)}%)")
        print("-" * 65)

    # Resultado final
    pct = int(score / total * 100)
    print(f"\n{'=' * 65}")
    print(f"   RESULTADO FINAL: {score}/{total} ({pct}%)")
    print(f"{'=' * 65}")

    if pct >= 80:
        print("\n   🏆 EXCELENTE! Você domina IAM. Pronto para a prova nesse tópico!")
    elif pct >= 65:
        print("\n   👍 BOM! Está no caminho certo, revise os erros abaixo.")
    elif pct >= 50:
        print("\n   ⚠️  ATENÇÃO! Precisa reforçar. Releia o material e tente de novo.")
    else:
        print("\n   📚 PRECISA ESTUDAR! Releia iam-guia-didatico.md e iam.md antes de refazer.")

    if errors:
        print(f"\n{'=' * 65}")
        print(f"   REVISÃO DOS ERROS ({len(errors)} questões)")
        print(f"{'=' * 65}")
        for e in errors:
            print(f"\n   ❌ Questão {e['num']}: {e['q'][:80]}...")
            print(f"      Você: {e['your']} | Correta: {e['correct']}")
            print(f"      → {e['exp']}")

    print(f"\n{'=' * 65}")
    print("   Dica: revise os erros em simulados/revisao-erros.md")
    print(f"{'=' * 65}\n")

if __name__ == "__main__":
    run_quiz()
