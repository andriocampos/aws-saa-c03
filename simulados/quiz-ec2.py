#!/usr/bin/env python3
"""Quiz EC2 - 30 questões estilo SAA-C03 (interativo no terminal)"""

QUESTIONS = [
    {
        "q": "Uma empresa executa workloads de Machine Learning que exigem GPUs de alta performance. Qual família de instância EC2 é mais adequada?",
        "opts": {
            "A": "C (Compute Optimized)",
            "B": "R (Memory Optimized)",
            "C": "P (Accelerated Computing — GPU)",
            "D": "M (General Purpose)"
        },
        "ans": "C",
        "exp": "Família P (P4d, P5) e G (G5) são para GPU — ML training, rendering, HPC. Família C é CPU-intensive sem GPU."
    },
    {
        "q": "Uma aplicação web tem tráfego previsível e constante 24/7 por 3 anos. Qual opção de compra oferece o MAIOR desconto?",
        "opts": {
            "A": "On-Demand",
            "B": "Reserved Instance Standard 3 anos All Upfront",
            "C": "Spot Instances",
            "D": "Savings Plans Compute 1 ano No Upfront"
        },
        "ans": "B",
        "exp": "Reserved Standard 3 anos All Upfront = até 72% de desconto (máximo possível para uso contínuo). Spot é mais barato mas pode ser interrompido — inaceitável para app 24/7."
    },
    {
        "q": "Uma instância Spot está rodando batch processing. A AWS precisa recuperar a capacidade. O que acontece?",
        "opts": {
            "A": "A instância é terminada imediatamente sem aviso",
            "B": "A instância recebe notificação 2 minutos antes e pode ser terminada, parada ou hibernada",
            "C": "A instância é migrada automaticamente para On-Demand",
            "D": "A AWS espera o job terminar antes de reclamar"
        },
        "ans": "B",
        "exp": "Spot recebe aviso de 2 minutos via instance metadata (169.254.169.254/latest/meta-data/spot/termination-time). Ação depende do Spot Interruption Behavior configurado (terminate/stop/hibernate)."
    },
    {
        "q": "Um volume EBS gp2 de 100GB está atingindo o limite de IOPS. Qual ação resolve SEM mudar o tipo de volume?",
        "opts": {
            "A": "Aumentar o tamanho do volume para 200GB",
            "B": "Habilitar Multi-Attach",
            "C": "Migrar para Instance Store",
            "D": "Ativar EBS Encryption"
        },
        "ans": "A",
        "exp": "gp2 tem 3 IOPS/GB (baseline). 100GB = 300 IOPS. 200GB = 600 IOPS. Aumentar o volume aumenta IOPS proporcionalmente (até 16.000 IOPS no máximo = 5.334GB+). Multi-Attach é só io1/io2."
    },
    {
        "q": "Qual tipo de volume EBS suporta Multi-Attach (múltiplas instâncias na mesma AZ)?",
        "opts": {
            "A": "gp3",
            "B": "io1 e io2",
            "C": "st1",
            "D": "Todos os tipos de EBS"
        },
        "ans": "B",
        "exp": "Multi-Attach é exclusivo de io1/io2 (Provisioned IOPS). Permite até 16 instâncias lerem/escreverem no mesmo volume na mesma AZ. Requer filesystem cluster-aware."
    },
    {
        "q": "Uma aplicação requer latência de storage ultrabaixa (centenas de milhares de IOPS) e pode tolerar perda de dados ao parar a instância. Qual opção?",
        "opts": {
            "A": "EBS io2 Block Express",
            "B": "Instance Store",
            "C": "EBS gp3 com throughput máximo",
            "D": "EFS com performance mode Max I/O"
        },
        "ans": "B",
        "exp": "Instance Store oferece milhões de IOPS com latência mínima (discos fisicamente no host). Dados são EFÊMEROS — perdidos ao stop/terminate. Ideal para cache, buffers temporários, scratch data."
    },
    {
        "q": "Qual é a diferença entre Dedicated Host e Dedicated Instance?",
        "opts": {
            "A": "Dedicated Host dá visibilidade de sockets/cores (licenciamento); Dedicated Instance apenas garante isolamento físico",
            "B": "São a mesma coisa com nomes diferentes",
            "C": "Dedicated Instance é mais caro que Dedicated Host",
            "D": "Dedicated Host é compartilhado entre contas da mesma Organization"
        },
        "ans": "A",
        "exp": "Dedicated Host = você controla o servidor físico (vê sockets, cores, host ID) — necessário para licenças per-socket/per-core (Oracle, Windows Server). Dedicated Instance = isolamento físico mas sem visibilidade do hardware."
    },
    {
        "q": "Uma empresa quer garantir que instâncias EC2 em um cluster HPC tenham a menor latência de rede possível entre si. Qual Placement Group usar?",
        "opts": {
            "A": "Spread",
            "B": "Partition",
            "C": "Cluster",
            "D": "Default (sem placement group)"
        },
        "ans": "C",
        "exp": "Cluster = todas as instâncias na MESMA AZ, mesma rack, menor latência possível (10 Gbps entre instâncias). Ideal para HPC e aplicações tightly-coupled. Trade-off: se a rack falhar, tudo cai junto."
    },
    {
        "q": "Uma aplicação crítica precisa de alta disponibilidade com instâncias distribuídas em hardware distinto. Máximo de 7 instâncias por AZ é aceitável. Qual Placement Group?",
        "opts": {
            "A": "Cluster",
            "B": "Spread",
            "C": "Partition",
            "D": "Nenhum — usar Multi-AZ com ASG"
        },
        "ans": "B",
        "exp": "Spread = cada instância em hardware distinto (racks diferentes). Limite: 7 instâncias por AZ. Se uma rack falha, apenas 1 instância é afetada. Ideal para apps críticas com poucas instâncias."
    },
    {
        "q": "Qual a diferença PRINCIPAL entre gp2 e gp3?",
        "opts": {
            "A": "gp3 suporta Multi-Attach, gp2 não",
            "B": "gp3 permite configurar IOPS e throughput INDEPENDENTEMENTE do tamanho do volume",
            "C": "gp2 é mais barato que gp3",
            "D": "gp3 é apenas para instâncias Nitro"
        },
        "ans": "B",
        "exp": "gp3: baseline 3.000 IOPS + 125 MB/s incluídos, e você pode aumentar IOPS (até 16.000) e throughput (até 1.000 MB/s) independente do tamanho. gp2: IOPS escala com tamanho (3 IOPS/GB). gp3 é mais barato que gp2."
    },
    {
        "q": "Uma instância EC2 precisa ser parada e reiniciada rapidamente sem perder o estado da RAM (memória). Qual feature usar?",
        "opts": {
            "A": "EC2 Instance Store backup",
            "B": "EC2 Hibernate",
            "C": "EC2 Stop + EBS snapshot",
            "D": "EC2 AMI creation"
        },
        "ans": "B",
        "exp": "Hibernate salva a RAM no volume EBS root (que DEVE ser criptografado). Ao reiniciar, o estado da memória é restaurado — boot muito mais rápido. Limitações: max 150GB RAM, root deve ser EBS encrypted, não pode hibernar mais que 60 dias."
    },
    {
        "q": "Security Groups são stateful. O que isso significa na prática?",
        "opts": {
            "A": "Regras são avaliadas em ordem numérica",
            "B": "Se o tráfego de entrada é permitido, a resposta de saída é automaticamente permitida (e vice-versa)",
            "C": "As regras persistem mesmo após reboot",
            "D": "Pode ter regras Allow e Deny"
        },
        "ans": "B",
        "exp": "Stateful = se ENTRADA é permitida, a SAÍDA da resposta é automática (não precisa de regra de saída). NACLs são stateless — precisam de regras em AMBAS as direções. SGs só têm Allow (sem Deny)."
    },
    {
        "q": "Uma instância EC2 precisa de um IP público fixo que não mude mesmo após stop/start. Qual recurso usar?",
        "opts": {
            "A": "Public IP auto-assigned",
            "B": "Elastic IP",
            "C": "Private IP",
            "D": "ENI secundária"
        },
        "ans": "B",
        "exp": "Elastic IP = IP público estático que permanece fixo. Public IP auto-assigned muda após stop/start. Limite: 5 EIPs por região (soft limit). Best practice: usar DNS/Load Balancer ao invés de EIP."
    },
    {
        "q": "Qual é o comando correto para buscar credenciais da IAM Role via Instance Metadata usando IMDSv2?",
        "opts": {
            "A": "curl http://169.254.169.254/latest/meta-data/iam/security-credentials/MyRole",
            "B": "Primeiro PUT para obter token, depois GET com o token no header",
            "C": "curl https://iam.amazonaws.com/metadata/credentials",
            "D": "aws sts get-instance-credentials"
        },
        "ans": "B",
        "exp": "IMDSv2 requer: 1) PUT para obter token (X-aws-ec2-metadata-token-ttl-seconds), 2) GET com header X-aws-ec2-metadata-token. Isso protege contra SSRF — atacantes não conseguem fazer PUT facilmente."
    },
    {
        "q": "Uma empresa quer executar workloads tolerantes a interrupção ao menor custo possível, usando múltiplos tipos de instância. Qual estratégia?",
        "opts": {
            "A": "Reserved Instances Convertible",
            "B": "Spot Fleet com diversificação de instâncias e AZs",
            "C": "On-Demand com T3 burstable",
            "D": "Savings Plans Compute"
        },
        "ans": "B",
        "exp": "Spot Fleet = coleção de Spot (e opcionalmente On-Demand) com múltiplos tipos/AZs. Diversificar reduz chance de interrupção total. Até 90% de desconto. Ideal para batch, CI/CD, big data."
    },
]

QUESTIONS += [
    {
        "q": "Um snapshot de EBS é armazenado em qual serviço?",
        "opts": {
            "A": "EBS (no mesmo volume)",
            "B": "S3 (gerenciado pela AWS, não visível no seu console S3)",
            "C": "Glacier automaticamente",
            "D": "Instance Store como backup"
        },
        "ans": "B",
        "exp": "Snapshots são armazenados incrementalmente no S3 (gerenciado pela AWS — você não vê no seu bucket). Primeiro snapshot = full copy. Subsequentes = apenas blocos alterados (incremental)."
    },
    {
        "q": "Qual tipo de volume EBS é indicado para data warehousing com acesso sequencial e alto throughput?",
        "opts": {
            "A": "gp3",
            "B": "io2",
            "C": "st1 (Throughput Optimized HDD)",
            "D": "sc1 (Cold HDD)"
        },
        "ans": "C",
        "exp": "st1 = HDD otimizado para throughput (até 500 MB/s). Ideal para big data, data warehousing, log processing — acesso sequencial. NÃO pode ser boot volume. sc1 é para dados frios/infrequentes."
    },
    {
        "q": "Uma empresa quer criar uma AMI padronizada com todas as dependências pré-instaladas para acelerar deploys. Como se chama esse pattern?",
        "opts": {
            "A": "Immutable Infrastructure",
            "B": "Golden AMI",
            "C": "Blue-Green Deployment",
            "D": "Canary Release"
        },
        "ans": "B",
        "exp": "Golden AMI = AMI padrão com OS, patches, software e configurações pré-instalados. Reduz tempo de boot e garante consistência. Combina com User Data para config dinâmica restante."
    },
    {
        "q": "Qual é o limite de Elastic IPs por região por padrão?",
        "opts": {
            "A": "1",
            "B": "5",
            "C": "10",
            "D": "Ilimitado"
        },
        "ans": "B",
        "exp": "Limite padrão: 5 EIPs por região (soft limit — pode pedir aumento). EIP NÃO associado a instância running = COBRA. AWS incentiva uso de DNS/ALB ao invés de EIPs."
    },
    {
        "q": "Uma instância EC2 está em estado 'stopped'. O que é cobrado?",
        "opts": {
            "A": "Nada — instância parada não cobra",
            "B": "Apenas o volume EBS anexado + Elastic IPs não associados",
            "C": "Cobrança integral (mesma de running)",
            "D": "50% da cobrança de running"
        },
        "ans": "B",
        "exp": "Instância stopped: NÃO cobra compute. COBRA: volumes EBS (por GB/mês), Elastic IPs não associados a instância running, e snapshots. É por isso que EBS persiste após stop."
    },
    {
        "q": "Qual a diferença entre ENI, ENA e EFA?",
        "opts": {
            "A": "São três gerações do mesmo componente de rede",
            "B": "ENI = interface de rede virtual; ENA = networking até 100Gbps; EFA = HPC com bypass do kernel (OS-bypass)",
            "C": "ENI é para VPC, ENA para Direct Connect, EFA para VPN",
            "D": "Todos são tipos de Elastic IP"
        },
        "ans": "B",
        "exp": "ENI = placa de rede virtual (toda instância tem). ENA = Enhanced Networking até 100Gbps (SR-IOV). EFA = Elastic Fabric Adapter para HPC com OS-bypass (MPI, NCCL) — menor latência entre instâncias."
    },
    {
        "q": "Savings Plans Compute vs EC2 Instance Savings Plans. Qual é mais FLEXÍVEL?",
        "opts": {
            "A": "EC2 Instance SP — pode trocar de família",
            "B": "Compute SP — pode trocar família, região, OS, e até usar em Fargate/Lambda",
            "C": "Ambos são idênticos em flexibilidade",
            "D": "Compute SP — mas só se aplica a EC2"
        },
        "ans": "B",
        "exp": "Compute SP = mais flexível (qualquer família, região, OS, tenancy + Fargate + Lambda) mas desconto menor (~66%). EC2 Instance SP = locked na família + região mas desconto maior (~72%). Trade-off: flexibilidade vs desconto."
    },
    {
        "q": "Uma instância T3 está com CPU em 100% constantemente. O que acontece quando os burst credits acabam?",
        "opts": {
            "A": "A instância é terminada",
            "B": "Performance de CPU é limitada ao baseline (ex: 20% para t3.medium) ou cobra extra se unlimited mode",
            "C": "A instância é migrada automaticamente para família C",
            "D": "AWS adiciona vCPUs automaticamente"
        },
        "ans": "B",
        "exp": "T3 (burstable): acumula credits quando idle, gasta quando precisa de CPU acima do baseline. Credits = 0 → throttled ao baseline. Com 'unlimited mode' (padrão T3): pode estourar mas COBRA pelo uso extra."
    },
    {
        "q": "Qual é o tamanho MÁXIMO de um volume EBS?",
        "opts": {
            "A": "1 TB",
            "B": "16 TB",
            "C": "64 TB",
            "D": "128 TB"
        },
        "ans": "B",
        "exp": "EBS máximo = 16 TB (16.384 GB). Para mais, usar RAID 0 (striping de múltiplos volumes) ou EFS/FSx. io2 Block Express suporta até 64 TB, mas é caso especial."
    },
    {
        "q": "User Data de EC2 é executado com qual privilégio e em qual momento?",
        "opts": {
            "A": "Como usuário ec2-user, a cada boot",
            "B": "Como root, apenas no PRIMEIRO boot (por padrão)",
            "C": "Como root, a cada boot",
            "D": "Como usuário IAM associado à instância"
        },
        "ans": "B",
        "exp": "User Data roda como ROOT e apenas no PRIMEIRO boot (launch). Para rodar em todo boot, usar mime multi-part ou cloud-init config com 'always'. Scripts devem ser idempotentes se executados repetidamente."
    },
    {
        "q": "Uma AMI criada na região us-east-1 precisa ser usada em eu-west-1. O que é necessário?",
        "opts": {
            "A": "Nada — AMIs são globais",
            "B": "Copiar a AMI para eu-west-1 (Copy AMI cross-region)",
            "C": "Exportar a AMI para S3 e importar na outra região",
            "D": "Recriar a AMI na outra região do zero"
        },
        "ans": "B",
        "exp": "AMIs são REGIONAIS. Para usar em outra região, fazer Copy AMI. A cópia inclui os snapshots EBS. Útil para DR e deploy multi-region. Pode copiar AMIs cross-account também."
    },
    {
        "q": "Qual recurso permite mover uma ENI de uma instância para outra na mesma AZ, mantendo o IP privado, Elastic IP e Security Groups?",
        "opts": {
            "A": "Elastic IP reassociation",
            "B": "ENI (Elastic Network Interface) — detach e attach em outra instância",
            "C": "VPC Peering",
            "D": "IP address swap via Route 53"
        },
        "ans": "B",
        "exp": "ENI pode ser detached de uma instância e attached a outra (mesma AZ). Mantém: private IP, Elastic IP, MAC address, Security Groups. Útil para failover: mover interface de rede para instância backup."
    },
    {
        "q": "Reserved Instance Standard vs Convertible. Qual permite trocar família de instância, OS e tenancy?",
        "opts": {
            "A": "Standard — por isso é 'standard'",
            "B": "Convertible — mais flexível porém com menor desconto",
            "C": "Ambos permitem troca",
            "D": "Nenhum permite troca — precisa comprar nova"
        },
        "ans": "B",
        "exp": "Standard RI: desconto até 72% mas NÃO pode trocar família/OS/tenancy (pode trocar AZ e scope). Convertible RI: desconto até 66% mas PODE trocar família, OS, tenancy (para valor igual ou maior)."
    },
    {
        "q": "Uma empresa precisa de 256.000 IOPS em um único volume EBS. Qual tipo usar?",
        "opts": {
            "A": "io2 Block Express",
            "B": "io2 standard",
            "C": "gp3 com IOPS provisionados",
            "D": "Instance Store"
        },
        "ans": "A",
        "exp": "io2 Block Express: até 256.000 IOPS e 4.000 MB/s, volumes até 64TB. io2 standard: até 64.000 IOPS. gp3: até 16.000 IOPS. Para mais de 64.000 IOPS em um volume = io2 Block Express (requer instância Nitro)."
    },
    {
        "q": "Uma empresa quer garantir capacidade EC2 numa AZ específica sem compromisso de 1-3 anos e sem desconto. Qual opção?",
        "opts": {
            "A": "Reserved Instance com No Upfront",
            "B": "On-Demand Capacity Reservation",
            "C": "Spot Fleet com target capacity",
            "D": "Dedicated Host"
        },
        "ans": "B",
        "exp": "On-Demand Capacity Reservation: garante capacidade numa AZ específica sem compromisso de tempo e sem desconto. Paga o preço On-Demand esteja usando ou não. Combina com Savings Plans para ter desconto + capacidade garantida."
    },
]


def run_quiz():
    print("\n" + "=" * 65)
    print("   SIMULADO EC2 — 30 QUESTÕES (Estilo AWS SAA-C03)")
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
        print("\n   🏆 EXCELENTE! Você domina EC2. Pronto para a prova nesse tópico!")
    elif pct >= 65:
        print("\n   👍 BOM! Está no caminho certo, revise os erros abaixo.")
    elif pct >= 50:
        print("\n   ⚠️  ATENÇÃO! Precisa reforçar. Releia o material e tente de novo.")
    else:
        print("\n   📚 PRECISA ESTUDAR! Releia servicos/ec2.md antes de refazer.")

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
