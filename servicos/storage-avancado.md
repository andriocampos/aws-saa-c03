# Storage Avançado — EFS, FSx, Storage Gateway, Snow Family, Backup & Mais

> Guia aprofundado para a certificação AWS SAA-C03.
> Cobre: EFS, FSx (todos), Storage Gateway, Snow Family, DataSync, Transfer Family, AWS Backup.

---

## 1. Tabela Geral — Comparação de Serviços de Storage

| Critério | EBS | EFS | S3 | Instance Store | FSx |
|----------|-----|-----|----|----------------|-----|
| **Tipo** | Block storage | File storage (NFS) | Object storage | Block storage | File storage (vários) |
| **Protocolo** | Block device | NFS v4.1 | REST API (HTTP) | Block device | SMB / Lustre / NFS / iSCSI |
| **Acesso** | 1 instância por vez* | Múltiplas instâncias, multi-AZ | Qualquer lugar (via API) | Apenas instância host | Múltiplas instâncias |
| **Persistência** | ✅ (sobrevive stop/reboot) | ✅ | ✅ | ❌ (perde ao stop/terminate) | ✅ |
| **Multi-AZ** | ❌ (preso a 1 AZ) | ✅ Regional (Standard) | ✅ (11 noves durabilidade) | ❌ | Depende do tipo |
| **Escalabilidade** | Manual (resize) | Automática (elastic) | Ilimitada | Fixo (hardware) | Definida na criação |
| **Custo relativo** | Médio | Alto | Baixo | Incluído na EC2 | Médio-Alto |
| **Throughput máx** | 16.000 IOPS (gp3) / 256.000 (io2 Block Express) | Até 10+ GB/s (elastic) | Alta (multi-part upload) | Muito alta (NVMe local) | Varia por tipo |
| **Criptografia** | ✅ (KMS) | ✅ (KMS) | ✅ (SSE-S3/KMS/C) | Depende do tipo | ✅ (KMS) |
| **Backup** | Snapshots → S3 | AWS Backup | Versionamento + Replicação | ❌ | AWS Backup |
| **Caso de uso** | Boot volume, BD, apps single-instance | CMS compartilhado, web farms, containers | Data lake, backups, static hosting | Cache, scratch, buffer I/O | Windows shares, HPC, enterprise NAS |

> *EBS Multi-Attach disponível apenas para io1/io2 na mesma AZ (até 16 instâncias).

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VISÃO GERAL — STORAGE AWS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────┐   │
│   │   EBS    │   │   EFS    │   │    S3    │   │ Instance Store│   │
│   │ (Block)  │   │  (File)  │   │ (Object) │   │   (Block)    │   │
│   └────┬─────┘   └────┬─────┘   └────┬─────┘   └──────┬───────┘   │
│        │               │              │                 │           │
│   1 instância     Multi-AZ       API HTTP         Local à EC2      │
│   por AZ         Multi-instância  Ilimitado        Efêmero         │
│                                                                     │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │                    FSx (File Systems)                     │      │
│   │  Windows │ Lustre │ NetApp ONTAP │ OpenZFS               │      │
│   └──────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. EFS — Elastic File System: Conceitos Fundamentais

### 2.1 O que é o EFS

- **Sistema de arquivos NFS v4.1 totalmente gerenciado** pela AWS
- **Elastic**: cresce e encolhe automaticamente conforme arquivos são adicionados/removidos
- **Não é necessário provisionar capacidade** — pague apenas pelo que usa
- **Multi-AZ**: dados replicados automaticamente em múltiplas AZs (classe Standard)
- **Compatível apenas com Linux** (AMI baseada em Linux) — NÃO funciona com Windows
- **POSIX compliant**: suporta permissões de arquivo Unix padrão (user, group, other)
- **Suporta milhares de conexões simultâneas** de clientes NFS
- **Criptografia**: at-rest (KMS) e in-transit (TLS)
- **Compatível com**: EC2, ECS, EKS, Fargate, Lambda

### 2.2 Arquitetura EFS

```
                    ┌─────────────────────────────────┐
                    │         Amazon EFS               │
                    │   (Regional File System)         │
                    └──────────┬──────────────────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
     ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐
     │  Mount     │      │  Mount     │      │  Mount     │
     │  Target    │      │  Target    │      │  Target    │
     │  (AZ-a)   │      │  (AZ-b)   │      │  (AZ-c)   │
     └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
           │                   │                   │
     ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼─────┐
     │  EC2 / ECS │      │  EC2 / ECS │      │  Lambda    │
     │  Fargate   │      │  Fargate   │      │  Function  │
     └───────────┘      └───────────┘      └───────────┘
```

- Cada **Mount Target** tem um IP e security group próprio
- Security Groups controlam acesso de rede ao EFS
- Use **amazon-efs-utils** para montar com TLS e IAM

---

## 3. EFS — Performance Modes

| Modo | Latência | IOPS | Paralelismo | Quando usar |
|------|----------|------|-------------|-------------|
| **General Purpose** (padrão) | Baixa (sub-ms) | Até 35.000 read / 7.000 write | Moderado | Web servers, CMS, WordPress, home directories, dev environments |
| **Max I/O** | Maior | Sem limite prático | Muito alto (milhares de clientes) | Big data, media processing, genomics, workloads massivamente paralelos |
| **Elastic** (recomendado) | Baixa | Auto-scales | Alto | **Recomendado para novos file systems** — combina baixa latência com alta paralelização |

### 3.1 Detalhes Importantes

- **General Purpose**: monitore `PercentIOLimit` no CloudWatch — se atingir 100%, considere mudar
- **Max I/O**: tradeoff = maior latência para operações de metadata
- **Elastic** (lançado recentemente): 
  - Escala automaticamente a performance
  - Substitui a necessidade de escolher entre GP e Max I/O
  - **AWS recomenda Elastic para novos file systems**
  - Suporta até 500.000+ IOPS de leitura

> ⚠️ **Na prova**: se pedirem "file system compartilhado com melhor performance sem trade-offs", a resposta é **Elastic mode**.

---

## 4. EFS — Throughput Modes

| Modo | Como funciona | Throughput | Quando usar |
|------|--------------|-----------|-------------|
| **Bursting** | Escala com tamanho do FS (50 MiB/s por TB armazenado) | Burst até 100 MiB/s (com créditos) | File systems pequenos-médios com padrão de acesso variável |
| **Provisioned** | Você define o throughput desejado (independente do tamanho) | Até 3-10+ GiB/s | Throughput alto necessário com pouco dado armazenado |
| **Elastic** | Auto-scales conforme demanda | Até 10+ GiB/s read / 3+ GiB/s write | **Recomendado** — workloads imprevisíveis, sem necessidade de planejar |

### 4.1 Bursting — Detalhes

- Baseline: 50 KiB/s por GiB armazenado
- Pode burst até 100 MiB/s (para FS < 1TB)
- File systems > 1TB: baseline já é > 50 MiB/s (sem necessidade de burst)
- Usa sistema de **burst credits** (similar ao gp2 do EBS)

### 4.2 Provisioned — Detalhes

- Você paga pelo throughput provisionado separadamente do storage
- Útil quando: muito throughput necessário, mas pouco dado armazenado
- Exemplo: 256 MiB/s de throughput com apenas 20 GiB armazenados

### 4.3 Elastic — Detalhes

- **Escala automaticamente** — sem necessidade de provisionar
- Paga por uso real de throughput (leitura: $0.03/GiB, escrita: $0.06/GiB)
- Ideal para workloads com spikes imprevisíveis
- **Não tem burst credits** — sempre disponível

> ⚠️ **Na prova**: "workload com throughput imprevisível em EFS" → **Elastic throughput mode**


---

## 5. EFS — Storage Classes e Lifecycle Management

### 5.1 Classes de Armazenamento

| Classe | Disponibilidade | Redundância | Custo Storage | Custo Acesso | Caso de uso |
|--------|----------------|-------------|---------------|--------------|-------------|
| **Standard** | 99.99% | Multi-AZ (3+ AZs) | Maior | Nenhum adicional | Dados acessados frequentemente |
| **Standard-IA** | 99.99% | Multi-AZ (3+ AZs) | ~47% menor | Cobra por acesso | Dados acessados raramente (backup, auditoria) |
| **One Zone** | 99.9% | Single-AZ | ~47% menor que Standard | Nenhum adicional | Dev/test, dados recriáveis |
| **One Zone-IA** | 99.9% | Single-AZ | ~72% menor que Standard | Cobra por acesso | Logs antigos, dados recriáveis e raramente acessados |

### 5.2 Lifecycle Management (Lifecycle Policies)

- Move arquivos automaticamente entre classes baseado no **último acesso**
- Políticas configuráveis: 7, 14, 30, 60 ou 90 dias sem acesso → move para IA
- **Transition to IA**: Standard → Standard-IA (ou One Zone → One Zone-IA)
- **Transition out of IA**: pode mover de volta quando acessado (opcional)
- Economia de até **92%** combinando One Zone-IA com lifecycle policies

```
┌─────────────────────────────────────────────────────────────┐
│              EFS Lifecycle Management                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────┐   após N dias    ┌──────────────┐           │
│   │ Standard │ ──────────────── │ Standard-IA  │           │
│   └──────────┘   sem acesso     └──────────────┘           │
│        ▲                               │                    │
│        │         ao acessar            │                    │
│        └───────────────────────────────┘                    │
│              (se habilitado)                                 │
│                                                             │
│   ┌──────────┐   após N dias    ┌──────────────┐           │
│   │ One Zone │ ──────────────── │ One Zone-IA  │           │
│   └──────────┘   sem acesso     └──────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "reduzir custos de EFS mantendo disponibilidade" → lifecycle policy + IA classes.

---

## 6. EFS + Lambda

### 6.1 Conceito

- Lambda pode **montar um EFS file system** como storage persistente
- Útil para: modelos de ML grandes, bibliotecas compartilhadas, dados de referência
- Lambda precisa estar em uma **VPC** para acessar EFS (via mount target)
- Conexão via **EFS Access Points** (obrigatório para Lambda)

### 6.2 Casos de Uso

| Cenário | Por que EFS + Lambda |
|---------|---------------------|
| ML inference com modelo grande (>250MB) | Lambda tem limite de 250MB deploy; EFS não tem limite |
| Compartilhar dados entre invocações | /tmp é efêmero (512MB-10GB); EFS é persistente |
| Múltiplas funções acessando mesmos dados | EFS é compartilhado; /tmp é isolado por invocação |
| Processamento de vídeo/imagem | Arquivos intermediários persistentes entre steps |

### 6.3 Limitações

- Lambda deve estar na **mesma VPC** do EFS
- **Cold start** pode ser maior por causa da conexão VPC + NFS mount
- Throughput limitado pelo modo do EFS e burst credits
- Conexões NFS contam contra o limite de concurrent executions

> ⚠️ **Na prova**: "Lambda precisa de storage persistente compartilhado > 512MB" → **EFS mount**

---

## 7. EFS Access Points

### 7.1 O que são

- **Endpoints de acesso personalizados** para o file system EFS
- Permitem **enforcement de identidade POSIX** (UID/GID) para cada aplicação
- Definem **root directory** específico para cada aplicação
- Simplificam gerenciamento de permissões em ambientes multi-tenant

### 7.2 Funcionalidades

| Feature | Descrição |
|---------|-----------|
| **POSIX User Identity** | Força UID/GID específico independente do cliente NFS |
| **Root Directory** | Cada Access Point pode ter seu próprio "/" (chroot) |
| **Criação automática de diretório** | Cria root dir com permissões definidas se não existir |
| **IAM Integration** | Policies IAM podem restringir acesso por Access Point |

### 7.3 Exemplo de Arquitetura Multi-App

```
┌─────────────────────────────────────────────────────────────────┐
│                      Amazon EFS                                   │
│                                                                   │
│   /data/app1/     /data/app2/     /data/shared/                  │
│       │               │               │                          │
└───────┼───────────────┼───────────────┼──────────────────────────┘
        │               │               │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │  Access  │     │  Access  │     │  Access  │
   │  Point 1 │     │  Point 2 │     │  Point 3 │
   │ UID:1001 │     │ UID:1002 │     │ UID:1003 │
   │ root:/   │     │ root:/   │     │ root:/   │
   │ data/app1│     │ data/app2│     │data/shared│
   └────┬────┘     └────┬────┘     └────┬────┘
        │               │               │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │ Lambda   │     │  ECS     │     │  EC2     │
   │ App 1    │     │  App 2   │     │  Shared  │
   └─────────┘     └─────────┘     └─────────┘
```

> ⚠️ **Na prova**: "isolar acesso de diferentes aplicações no mesmo EFS" → **Access Points**

---

## 8. EFS vs EBS — Tabela Comparativa Detalhada

| Critério | EBS | EFS |
|----------|-----|-----|
| **Tipo** | Block storage | File storage (NFS) |
| **Protocolo** | Attached block device | NFS v4.1 |
| **Acesso simultâneo** | 1 instância (io1/io2: Multi-Attach até 16, mesma AZ) | Milhares de instâncias, multi-AZ |
| **Disponibilidade** | Single-AZ (snapshot para mover) | Multi-AZ (Standard) ou Single-AZ (One Zone) |
| **Escalabilidade** | Manual — precisa resize (operação online) | Automática — elastic |
| **Tamanho máximo** | 64 TiB por volume | Petabytes (sem limite prático) |
| **Performance** | Até 256.000 IOPS (io2 Block Express) | Até 500.000+ IOPS read (elastic) |
| **Latência** | Sub-ms (io2 Block Express) | Sub-ms (General Purpose) |
| **SO compatível** | Linux + Windows | Linux only |
| **Custo** | Paga por capacidade provisionada | Paga por uso (Standard) ou provisionado |
| **Backup** | Snapshots (manuais ou automáticos) | AWS Backup + lifecycle policies |
| **Boot volume** | ✅ Sim | ❌ Não |
| **Compartilhamento** | Limitado (Multi-Attach mesma AZ) | Total (multi-AZ, multi-instância) |
| **Encryption** | KMS (at-rest + in-transit entre EC2-EBS) | KMS (at-rest) + TLS (in-transit) |
| **Caso de uso principal** | BD (MySQL, PostgreSQL), boot, app single-instance | Web farms, CMS, containers, CI/CD shared storage |

### Quando usar EBS vs EFS (decisão rápida)

```
Precisa de boot volume?                    → EBS
Precisa de IOPS extremo (>100K)?          → EBS io2 Block Express
Precisa compartilhar entre instâncias?     → EFS
Precisa de acesso multi-AZ?               → EFS
Precisa de Windows?                        → Nenhum dos dois → FSx for Windows
Workload Linux + shared storage?           → EFS
Database (MySQL, PostgreSQL)?              → EBS (gp3 ou io2)
```


---

## 9. FSx for Windows File Server

### 9.1 Conceitos

- **File system SMB totalmente gerenciado** pela AWS
- Protocolo: **SMB (Server Message Block)** — nativo do Windows
- Integração completa com **Active Directory** (AWS Managed AD ou Self-managed AD)
- Suporta: Windows ACLs, DFS namespaces, shadow copies, user quotas
- Acessível de: Windows, Linux (via SMB client), macOS
- **Data deduplication**: reduz custos eliminando dados duplicados (até 50-60% economia)

### 9.2 Deployment Options

| Opção | Disponibilidade | Caso de uso |
|-------|----------------|-------------|
| **Single-AZ** | 99.5-99.9% | Dev/test, workloads não-críticos |
| **Multi-AZ** | 99.99% | Produção, aplicações críticas |

### 9.3 Storage Types

| Tipo | Performance | Custo | Caso de uso |
|------|-------------|-------|-------------|
| **SSD** | Baixa latência, alto IOPS | Maior | Databases, home directories, CRM |
| **HDD** | Alto throughput, latência maior | Menor | Home dirs com acesso moderado, file shares grandes |

### 9.4 Features Importantes

- **DFS (Distributed File System) Namespaces**: agrupa múltiplos file systems sob namespace único
- **Shadow Copies**: versões anteriores de arquivos acessíveis pelo usuário final
- **Data Deduplication**: ativada no file system, reduz storage real necessário
- **Backup automático**: diário para S3 (retenção configurável)
- **Criptografia**: at-rest (KMS) e in-transit (SMB encryption)
- **Throughput**: até 2 GB/s, milhões de IOPS, latência sub-ms

### 9.5 Diagrama

```
┌──────────────────────────────────────────────────────────┐
│                 FSx for Windows File Server                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌───────────┐     SMB 3.0      ┌───────────────────┐   │
│  │  Windows  │ ───────────────► │  FSx for Windows  │   │
│  │  Clients  │                  │  (Multi-AZ)       │   │
│  └───────────┘                  │                   │   │
│                                 │  ┌─────────────┐  │   │
│  ┌───────────┐     SMB         │  │ Active Dir  │  │   │
│  │  Linux    │ ───────────────► │  │ Integration │  │   │
│  │  Clients  │                  │  └─────────────┘  │   │
│  └───────────┘                  │                   │   │
│                                 │  ┌─────────────┐  │   │
│  ┌───────────┐                  │  │ DFS         │  │   │
│  │  Active   │ ◄──── Auth ────► │  │ Namespaces  │  │   │
│  │ Directory │                  │  └─────────────┘  │   │
│  └───────────┘                  └───────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "shared Windows file system com AD" → **FSx for Windows File Server**

---

## 10. FSx for Lustre

### 10.1 Conceitos

- **File system Lustre de alta performance** gerenciado pela AWS
- Projetado para: **HPC (High Performance Computing)**, Machine Learning, Financial Modeling
- **Sub-millisecond latency**, centenas de GB/s de throughput, milhões de IOPS
- **POSIX compliant** — compatível com qualquer aplicação Linux
- **Integração nativa com S3**: objetos S3 aparecem como arquivos no Lustre

### 10.2 Integração com S3

| Feature | Descrição |
|---------|-----------|
| **Lazy Loading** | Dados são carregados do S3 para Lustre apenas quando acessados pela primeira vez |
| **Auto-export** (Persistent) | Mudanças no Lustre são automaticamente exportadas de volta ao S3 |
| **Data Repository Association** | Link entre file system e bucket S3 |
| **hsm_archive** | Comando para forçar export de arquivos para S3 |

```
┌──────────────────────────────────────────────────────────┐
│            FSx for Lustre + S3 Integration                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────┐                      ┌─────────────┐       │
│  │   S3    │ ─── lazy loading ──► │  FSx Lustre │       │
│  │ Bucket  │ ◄── auto-export ──── │  File System│       │
│  └─────────┘                      └──────┬──────┘       │
│                                          │              │
│                              ┌───────────┼───────────┐  │
│                              │           │           │  │
│                         ┌────▼───┐  ┌────▼───┐  ┌───▼──┐
│                         │ EC2    │  │ EC2    │  │ EC2  │  
│                         │ HPC    │  │ ML     │  │ Data │  
│                         └────────┘  └────────┘  └──────┘  
└──────────────────────────────────────────────────────────┘
```

### 10.3 Deployment Types

| Tipo | Replicação | Durabilidade | Custo | Caso de uso |
|------|-----------|--------------|-------|-------------|
| **Scratch** | ❌ Nenhuma | Não durável (dados perdidos se server falhar) | Menor | Jobs temporários, processamento de curto prazo, dados recriáveis |
| **Persistent** | ✅ Dentro da mesma AZ | Alta (replicação automática) | Maior | Armazenamento de longo prazo, dados sensíveis, workloads de produção |

### 10.4 Performance

- **Scratch**: 200 MB/s por TiB de storage provisionado
- **Persistent**: 50, 100 ou 200 MB/s por TiB (escolha na criação)
- Burst: pode exceder baseline temporariamente
- Milhões de IOPS
- Latência < 1 ms

> ⚠️ **Na prova**: "HPC workload precisa acessar dados do S3 com alta performance" → **FSx for Lustre**
> ⚠️ **Na prova**: "processamento temporário de dados" → **FSx Lustre Scratch**
> ⚠️ **Na prova**: "workload de longo prazo com alta I/O" → **FSx Lustre Persistent**

---

## 11. FSx for NetApp ONTAP

### 11.1 Conceitos

- File system **NetApp ONTAP** gerenciado pela AWS
- **Multi-protocol**: NFS, SMB e iSCSI simultaneamente
- Compatível com: Linux, Windows e macOS ao mesmo tempo
- Ideal para **migração de workloads on-premises** que já usam NetApp

### 11.2 Features Principais

| Feature | Descrição |
|---------|-----------|
| **Multi-protocol** | NFS + SMB + iSCSI no mesmo file system |
| **SnapMirror** | Replicação entre file systems (on-prem ↔ AWS ou AWS ↔ AWS) |
| **FlexClone** | Clones instantâneos de volumes (sem copiar dados) — ideal para dev/test |
| **Data Tiering** | Move dados frios automaticamente para capacity pool (S3-like, mais barato) |
| **Compression + Dedup** | Reduz storage utilizado automaticamente |
| **Snapshots** | Point-in-time recovery, sem custo de performance |
| **FlexGroup** | Volumes distribuídos para escalar capacidade e throughput |

### 11.3 Arquitetura de Tiering

```
┌───────────────────────────────────────────────────┐
│         FSx for NetApp ONTAP                       │
├───────────────────────────────────────────────────┤
│                                                   │
│   ┌─────────────────────────────────┐             │
│   │   SSD Performance Tier          │ ← Hot data  │
│   │   (dados acessados ativamente)  │             │
│   └──────────────┬──────────────────┘             │
│                  │ auto-tiering                    │
│                  ▼                                 │
│   ┌─────────────────────────────────┐             │
│   │   Capacity Pool Tier            │ ← Cold data │
│   │   (custo ~80% menor)            │             │
│   └─────────────────────────────────┘             │
└───────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "migrar NetApp on-prem para AWS" → **FSx for NetApp ONTAP**
> ⚠️ **Na prova**: "precisa NFS + SMB + iSCSI ao mesmo tempo" → **FSx for NetApp ONTAP**

---

## 12. FSx for OpenZFS

### 12.1 Conceitos

- File system **OpenZFS** gerenciado pela AWS
- Ideal para **migração de workloads ZFS on-premises** para a nuvem
- Protocolo: **NFS** (v3 e v4)
- Compatível com: Linux, Windows (via NFS client), macOS
- Até **1 milhão de IOPS** com latência < 0.5ms

### 12.2 Features Principais

| Feature | Descrição |
|---------|-----------|
| **Snapshots** | Point-in-time, eficientes (copy-on-write) |
| **Clones** | Instantâneos a partir de snapshots |
| **Compression** | LZ4 ou ZSTD (reduz storage) |
| **Data integrity** | Checksums automáticos (detecta corrupção) |
| **NFS export** | Acessível via NFS padrão |
| **Quotas** | User e group quotas |
| **Point-in-time recovery** | Via snapshots programados |

### 12.3 Quando usar

- Migração de ZFS on-premises para AWS sem refatorar aplicações
- Workloads que dependem de features ZFS (snapshots, clones, compression)
- Databases que se beneficiam de baixa latência e alto IOPS

> ⚠️ **Na prova**: "migrar ZFS workload para AWS" → **FSx for OpenZFS**

---

## 13. Tabela Comparativa — Todos os FSx

| Critério | FSx for Windows | FSx for Lustre | FSx for NetApp ONTAP | FSx for OpenZFS |
|----------|-----------------|----------------|---------------------|-----------------|
| **Protocolo** | SMB | Lustre (POSIX) | NFS, SMB, iSCSI | NFS |
| **SO compatível** | Windows + Linux | Linux | Linux, Windows, macOS | Linux, Windows, macOS |
| **Integração principal** | Active Directory | Amazon S3 | NetApp ecosystem | ZFS ecosystem |
| **Multi-AZ** | ✅ (opcional) | ❌ (single-AZ) | ✅ | ❌ (single-AZ) |
| **Performance** | Até 2 GB/s | Centenas de GB/s | Alta | Até 12.5 GB/s |
| **IOPS** | Milhões | Milhões | Centenas de milhares | 1 milhão |
| **Latência** | Sub-ms | Sub-ms | Sub-ms | < 0.5 ms |
| **Data tiering** | ❌ | ❌ (usa S3 link) | ✅ (automático) | ❌ |
| **Snapshots** | Shadow copies | ❌ | ✅ (NetApp snapshots) | ✅ (ZFS snapshots) |
| **Deduplication** | ✅ | ❌ | ✅ | ❌ |
| **Clone instantâneo** | ❌ | ❌ | ✅ (FlexClone) | ✅ |
| **Replicação** | DFS | ❌ | SnapMirror | ❌ |
| **Caso de uso** | Windows shares, SharePoint, SQL Server | HPC, ML, Big Data | Enterprise NAS, multi-protocol | ZFS migration, databases |
| **Custo relativo** | Médio | Variável (Scratch barato) | Alto | Médio |


---

## 14. AWS Storage Gateway — Conceitos

### 14.1 O que é

- **Bridge (ponte) entre infraestrutura on-premises e armazenamento AWS**
- Roda como **VM on-premises** (VMware, Hyper-V, KVM) ou **hardware appliance** (comprado da AWS)
- Expõe protocolos familiares (NFS, SMB, iSCSI) localmente → armazena dados na AWS
- Mantém **cache local** para acesso de baixa latência aos dados mais usados

### 14.2 Tipos de Gateway

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Storage Gateway                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │
│  │ S3 File GW    │  │ FSx File GW   │  │ Volume GW     │           │
│  │ NFS/SMB → S3  │  │ SMB → FSx Win │  │ iSCSI → S3   │           │
│  └───────────────┘  └───────────────┘  │ + EBS Snaps   │           │
│                                        └───────────────┘           │
│  ┌───────────────┐                                                  │
│  │ Tape GW       │                                                  │
│  │ iSCSI → S3    │                                                  │
│  │ Glacier       │                                                  │
│  └───────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 14.3 Hardware Appliance

- Para clientes que **não têm infraestrutura de virtualização** on-prem
- Mini server físico comprado da AWS
- Suporta todos os tipos de gateway
- Ideal para escritórios remotos, filiais, ambientes edge

---

## 15. S3 File Gateway

### 15.1 Funcionamento

- Expõe **NFS ou SMB** localmente para aplicações on-premises
- Por trás, armazena arquivos como **objetos no Amazon S3**
- Cada arquivo → 1 objeto S3 (com metadata preservada)
- **Cache local**: mantém dados recentemente acessados no appliance on-prem
- Suporta: S3 Standard, S3 Standard-IA, S3 One Zone-IA, S3 Intelligent-Tiering

### 15.2 Features

| Feature | Descrição |
|---------|-----------|
| **Protocolos** | NFS v3/v4.1, SMB 2/3 |
| **Destino** | S3 (múltiplas classes) |
| **Cache local** | Sim — dados hot ficam acessíveis com baixa latência |
| **AD Integration** | Sim (para SMB) — autenticação via Active Directory |
| **Lifecycle policies** | Aplicar no bucket S3 para mover para Glacier |
| **Notificações** | S3 Events (Lambda, SNS, SQS) |
| **Acesso via S3 API** | Sim — objetos acessíveis diretamente via S3 API |

### 15.3 Diagrama

```
┌──────────────────┐         ┌───────────────┐         ┌──────────┐
│  Aplicação       │  NFS/   │  S3 File      │ HTTPS   │  Amazon  │
│  On-Premises     │──SMB───►│  Gateway      │────────►│    S3    │
│  (Linux/Windows) │         │  (VM + cache) │         │          │
└──────────────────┘         └───────────────┘         └────┬─────┘
                                                            │
                                                     Lifecycle Policy
                                                            │
                                                     ┌──────▼──────┐
                                                     │  S3 Glacier  │
                                                     └─────────────┘
```

> ⚠️ **Na prova**: "on-prem NFS/SMB access to S3" → **S3 File Gateway**
> ⚠️ **Na prova**: "extend on-prem storage to cloud" → **S3 File Gateway**

---

## 16. FSx File Gateway

### 16.1 Funcionamento

- Expõe **SMB** localmente → armazena dados no **FSx for Windows File Server**
- **Cache local**: frequentemente acessados ficam no appliance on-prem
- Útil quando já usa FSx for Windows mas precisa de acesso low-latency on-prem
- Mantém compatibilidade total com **Windows features** (ACLs, shadow copies)

### 16.2 Quando usar

| Cenário | Solução |
|---------|---------|
| On-prem precisa acessar S3 via NFS/SMB | S3 File Gateway |
| On-prem precisa acessar FSx for Windows com cache local | **FSx File Gateway** |
| Escritórios remotos acessando FSx centralizado | **FSx File Gateway** |

### 16.3 Diferença vs S3 File Gateway

- **S3 File GW**: dados ficam em S3 (object storage)
- **FSx File GW**: dados ficam em FSx for Windows (file system gerenciado)
- FSx File GW mantém **group policies, DFS, shadow copies** intactos

> ⚠️ **Na prova**: "on-prem Windows users acessando FSx com baixa latência" → **FSx File Gateway**

---

## 17. Volume Gateway

### 17.1 Conceitos

- Expõe **volumes iSCSI** para servidores on-premises
- Dados armazenados no **S3** com backup como **EBS Snapshots**
- Dois modos: **Stored Volumes** e **Cached Volumes**

### 17.2 Stored Volumes

- **Dados completos ficam on-premises** (low-latency total)
- Backup **assíncrono** e incremental para S3 (como EBS snapshots)
- Tamanho: 1 GiB a 16 TiB por volume
- Cenário: DR — dados locais com backup na nuvem

```
┌──────────────────┐         ┌───────────────────────────┐
│  Aplicação       │  iSCSI  │  Volume Gateway            │
│  On-Premises     │────────►│  (Stored Mode)             │
└──────────────────┘         │                           │
                             │  ┌─────────────────────┐  │
                             │  │ DADOS COMPLETOS     │  │
                             │  │ (storage local)     │  │
                             │  └──────────┬──────────┘  │
                             └─────────────┼─────────────┘
                                           │ async backup
                                           ▼
                             ┌─────────────────────────┐
                             │  S3 (EBS Snapshots)      │
                             └─────────────────────────┘
```

### 17.3 Cached Volumes

- **Dados completos ficam no S3** (nuvem)
- **Cache local** apenas dos dados mais frequentemente acessados
- Tamanho: 1 GiB a 32 TiB por volume
- Cenário: expandir storage sem comprar hardware — dados na nuvem com acesso local

```
┌──────────────────┐         ┌───────────────────────────┐
│  Aplicação       │  iSCSI  │  Volume Gateway            │
│  On-Premises     │────────►│  (Cached Mode)             │
└──────────────────┘         │                           │
                             │  ┌─────────────────────┐  │
                             │  │ CACHE (hot data)    │  │
                             │  └──────────┬──────────┘  │
                             └─────────────┼─────────────┘
                                           │ full data
                                           ▼
                             ┌─────────────────────────┐
                             │  Amazon S3               │
                             │  (dados completos)       │
                             └─────────────────────────┘
```

### 17.4 Stored vs Cached — Comparação

| Critério | Stored Volumes | Cached Volumes |
|----------|---------------|----------------|
| **Dados primários** | On-premises | S3 (nuvem) |
| **Latência** | Muito baixa (tudo local) | Baixa para cache, maior para cold data |
| **Capacidade máx** | 16 TiB | 32 TiB |
| **Storage local necessário** | Todo o dataset | Apenas cache |
| **Caso de uso** | DR com dados locais | Expandir storage sem hardware |
| **Backup** | Assíncrono → S3 snapshots | Dados já estão no S3 |

> ⚠️ **Na prova**: "block storage on-prem com backup para AWS" → **Volume Gateway (Stored)**
> ⚠️ **Na prova**: "expandir storage on-prem sem comprar hardware" → **Volume Gateway (Cached)**

---

## 18. Tape Gateway

### 18.1 Conceitos

- Emula uma **Virtual Tape Library (VTL)** para aplicações de backup
- Interface: **iSCSI** — compatível com software de backup existente (Veeam, NetBackup, Backup Exec)
- Substitui **fitas físicas** por virtual tapes armazenadas na AWS
- Tapes armazenadas: S3 (para tapes ativas) → Glacier/Deep Archive (para tapes arquivadas)

### 18.2 Fluxo de dados

```
┌──────────────────┐         ┌───────────────┐         ┌──────────────┐
│  Software de     │  iSCSI  │  Tape Gateway │  HTTPS  │  S3          │
│  Backup          │────────►│  (VTL)        │────────►│  (Virtual    │
│  (Veeam, etc.)   │         │               │         │   Tapes)     │
└──────────────────┘         └───────────────┘         └──────┬───────┘
                                                              │
                                                       Archive (eject)
                                                              │
                                                       ┌──────▼───────┐
                                                       │  S3 Glacier  │
                                                       │  ou Deep     │
                                                       │  Archive     │
                                                       └──────────────┘
```

### 18.3 Custos

| Tier | Quando | Latência de recuperação |
|------|--------|------------------------|
| S3 (VTL) | Tapes ativas | Imediato |
| S3 Glacier | Tapes arquivadas | Minutos a horas |
| S3 Glacier Deep Archive | Tapes raramente necessárias | 12-48 horas |

> ⚠️ **Na prova**: "substituir fitas físicas de backup" → **Tape Gateway**
> ⚠️ **Na prova**: "backup com S3 Glacier usando software existente" → **Tape Gateway**

---

## 19. Tabela Comparativa — Todos os Storage Gateways

| Critério | S3 File Gateway | FSx File Gateway | Volume Gateway (Stored) | Volume Gateway (Cached) | Tape Gateway |
|----------|----------------|-----------------|------------------------|------------------------|--------------|
| **Protocolo** | NFS / SMB | SMB | iSCSI | iSCSI | iSCSI |
| **Destino AWS** | S3 | FSx for Windows | S3 + EBS Snapshots | S3 + EBS Snapshots | S3 → Glacier |
| **Cache local** | ✅ | ✅ | N/A (dados locais) | ✅ (hot data) | ✅ |
| **Dados primários** | S3 | FSx | On-premises | S3 | S3/Glacier |
| **AD Integration** | ✅ (SMB) | ✅ | ❌ | ❌ | ❌ |
| **Caso de uso** | File shares → S3 | File shares → FSx | DR com dados locais | Storage expansion | Backup tapes |
| **Tipo de acesso** | File | File | Block | Block | Tape (block) |


---

## 20. Snow Family — Snowcone

### 20.1 Especificações

| Critério | Snowcone (HDD) | Snowcone SSD |
|----------|----------------|--------------|
| **Capacidade utilizável** | 8 TB HDD | 14 TB SSD |
| **Peso** | 2.1 kg (4.5 lbs) | 2.1 kg |
| **vCPUs** | 2 | 2 |
| **RAM** | 4 GB | 4 GB |
| **Edge compute** | ✅ (EC2 + IoT Greengrass) | ✅ |
| **DataSync agent** | ✅ pré-instalado | ✅ pré-instalado |
| **Alimentação** | USB-C ou bateria opcional | USB-C ou bateria |
| **Conectividade** | Wi-Fi, Ethernet | Wi-Fi, Ethernet |
| **Criptografia** | 256-bit (automática) | 256-bit |

### 20.2 Casos de uso

- **Edge computing** em locais remotos (campo, embarcações, veículos)
- Coleta de dados IoT onde não há internet confiável
- Migração de pequenos volumes (< 24 TB)
- Pode enviar dados via **AWS DataSync** (online) ou enviar fisicamente o dispositivo

### 20.3 Transferência

- Pode transferir dados **online** via DataSync agent integrado (quando há rede)
- Ou pode **enviar fisicamente** para AWS (como Snowball)
- Mais portátil e leve da família Snow

> ⚠️ **Na prova**: "edge computing em local remoto e portátil" → **Snowcone**

---

## 21. Snow Family — Snowball Edge

### 21.1 Variantes

| Critério | Storage Optimized | Compute Optimized |
|----------|-------------------|-------------------|
| **Storage utilizável** | 80 TB | 42 TB |
| **vCPUs** | 40 | 104 |
| **RAM** | 80 GB | 416 GB |
| **GPU** | ❌ | Opcional (p/ ML inference) |
| **EC2 instances** | ✅ | ✅ |
| **Lambda** | ✅ (via IoT Greengrass) | ✅ |
| **Caso de uso** | Migração de dados em larga escala | Edge computing intensivo, ML, análise de vídeo |
| **Cluster** | Até 15 dispositivos | Até 15 dispositivos |

### 21.2 Features

- **Clustering**: agrupar múltiplos Snowball Edge para aumentar capacidade e redundância
- **EC2 compatible**: rodar instâncias EC2 localmente (sbe1, sbe-c, sbe-g)
- **Lambda@Edge**: rodar funções Lambda localmente via IoT Greengrass
- **S3 compatible**: endpoint S3 local no dispositivo
- **Criptografia**: 256-bit automática, KMS managed
- **Tamper-resistant**: TPM (Trusted Platform Module), caso de violação o dispositivo é apagado

### 21.3 Diagrama de uso

```
┌────────────────────────────────────────────────────────────────┐
│                    Snowball Edge — Workflow                      │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  1. ORDER        2. LOAD           3. SHIP        4. IMPORT    │
│  ┌─────────┐    ┌─────────┐      ┌─────────┐    ┌─────────┐  │
│  │ Console │    │ Conectar │      │ Enviar  │    │ AWS     │  │
│  │ Pedir   │───►│ + Copiar │─────►│ p/ AWS  │───►│ importa │  │
│  │ device  │    │ dados    │      │ (courier)│    │ p/ S3   │  │
│  └─────────┘    └─────────┘      └─────────┘    └─────────┘  │
│                                                                │
│  ◄─── On-premises ────────────────────── AWS ──────────────►   │
└────────────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "migração offline de 10-80 TB" → **Snowball Edge Storage Optimized**
> ⚠️ **Na prova**: "edge computing com alta capacidade de processamento" → **Snowball Edge Compute Optimized**

---

## 22. Snow Family — Snowmobile

### 22.1 Especificações

| Critério | Snowmobile |
|----------|-----------|
| **Capacidade** | 100 PB (100.000 TB) |
| **Forma** | Caminhão container (45 pés) |
| **Segurança** | Escolta armada, GPS tracking, vigilância 24/7, criptografia 256-bit |
| **Conectividade** | Fibra de alta velocidade para data center |
| **Transferência** | ~1 exabyte com 10 Snowmobiles em paralelo |
| **Tempo estimado** | ~6 meses para 100PB (transferência + trânsito) |

### 22.2 Quando usar

- Migração de **mais de 10 PB** de dados
- Cenários onde Snowball Edge levaria muitos dispositivos/ciclos
- Data center decommissioning (encerramento completo)
- Cada Snowmobile = ~1.000 Snowball Edge devices

### 22.3 Processo

1. AWS envia equipe de avaliação ao data center
2. Caminhão estaciona no data center com conexão de fibra dedicada
3. Dados transferidos em alta velocidade (até 1 Tbps)
4. Caminhão retorna ao data center AWS
5. Dados importados para S3

> ⚠️ **Na prova**: "migrar >10PB de dados" → **Snowmobile**
> ⚠️ Se < 10PB → use múltiplos **Snowball Edge**

---

## 23. Snow Family → S3: Processo de Transferência

### 23.1 Workflow Completo

```
┌─────────────────────────────────────────────────────────────────┐
│            Snow Family — Processo de Transferência                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌───────────┐   │
│  │  ORDER  │    │  RECEIVE │    │  LOAD   │    │   SHIP    │   │
│  │         │    │          │    │         │    │           │   │
│  │ Console │───►│ Receber  │───►│ Instalar│───►│ Devolver  │   │
│  │ ou CLI  │    │ device   │    │ client  │    │ p/ AWS    │   │
│  │         │    │          │    │ + copiar│    │ (prepaid) │   │
│  └─────────┘    └──────────┘    └─────────┘    └─────┬─────┘   │
│                                                      │         │
│  ┌───────────────────────────────────────────────────▼──────┐  │
│  │  IMPORT                                                   │  │
│  │  • Device chega ao data center AWS                        │  │
│  │  • Dados importados para S3 bucket especificado           │  │
│  │  • Device é sanitizado (NIST 800-88)                      │  │
│  │  • Notificação SNS quando completo                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 23.2 Detalhes Importantes

- **Snowball Client** ou **OpsHub** (GUI) para transferir dados ao device
- Dados criptografados com **KMS** antes de sair do on-premises
- Após importação para S3, o device é **wiped** (limpeza segura NIST 800-88)
- Dados vão para **S3 Standard** → depois use lifecycle policies para mover para Glacier
- **Não é possível importar diretamente para Glacier** — sempre passa pelo S3 primeiro

### 23.3 Export (S3 → Snow)

- Também possível exportar dados **de S3 para Snow device**
- Cenário: precisa de dados do S3 em local sem internet
- Processo inverso: order → AWS carrega → ship → recebe on-prem

---

## 24. Regra de Ouro — Snow vs Transferência Online

### 24.1 Tabela de Decisão por Tamanho e Bandwidth

| Volume de dados | 100 Mbps | 1 Gbps | 10 Gbps | Recomendação |
|-----------------|----------|--------|---------|--------------|
| 10 GB | 14 min | 1.4 min | 8 seg | ✅ Online |
| 100 GB | 2.3 horas | 14 min | 1.4 min | ✅ Online |
| 1 TB | 1 dia | 2.3 horas | 14 min | ✅ Online |
| 10 TB | 12 dias | 1.2 dias | 2.3 horas | ⚠️ Depende (Snow ou online) |
| 100 TB | 120 dias | 12 dias | 1.2 dias | ❄️ Snow |
| 1 PB | 3.4 anos | 124 dias | 12 dias | ❄️ Snow |
| 10+ PB | 34 anos | 3.4 anos | 124 dias | ❄️ Snowmobile |

### 24.2 Regra Simplificada

```
┌─────────────────────────────────────────────────────────────┐
│         QUANDO USAR SNOW FAMILY?                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Transferência online levaria > 1 SEMANA?                   │
│                                                             │
│       SIM ──────► Use Snow Family                           │
│       NÃO ──────► Use transferência online                  │
│                   (DataSync, S3 Transfer Acceleration,       │
│                    Direct Connect + VPN)                     │
│                                                             │
│  Volume > 10 PB?                                            │
│       SIM ──────► Snowmobile                                │
│       NÃO ──────► Snowball Edge                             │
│                                                             │
│  Precisa de edge computing?                                 │
│       SIM + portátil ──────► Snowcone                       │
│       SIM + poder ──────► Snowball Edge Compute Optimized   │
└─────────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "migração levaria semanas pela internet" → **Snow Family**
> ⚠️ **Na prova**: "dados importados para S3 Standard primeiro, depois mover para Glacier" → Snow import + lifecycle


---

## 25. AWS DataSync

### 25.1 Conceitos

- Serviço de **transferência de dados online** — mover dados de/para AWS de forma automatizada
- Suporta fontes: **NFS, SMB, HDFS, S3 API** (on-premises ou outras nuvens)
- Suporta destinos: **S3, EFS, FSx** (todos os tipos)
- **Agent on-premises**: VM que conecta ao storage de origem (NFS/SMB server)
- Transferência **criptografada** (TLS) e com validação de integridade
- **Bandwidth throttling**: limitar banda utilizada para não impactar produção
- **Scheduled transfers**: agendar transferências incrementais (cron-like)
- Até **10 Gbps** de throughput por task

### 25.2 Arquitetura

```
┌──────────────────────────────────────────────────────────────────┐
│                     AWS DataSync                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ON-PREMISES                         AWS                         │
│  ┌───────────┐    ┌──────────┐      ┌─────────────────────────┐ │
│  │ NFS/SMB   │    │ DataSync │      │  Destinos:              │ │
│  │ Server    │───►│ Agent    │─────►│  • Amazon S3            │ │
│  │           │    │ (VM)     │  TLS │  • Amazon EFS           │ │
│  └───────────┘    └──────────┘      │  • FSx (todos os tipos) │ │
│                                     └─────────────────────────┘ │
│                                                                  │
│  AWS → AWS (sem agent necessário)                                │
│  ┌───────────┐              ┌───────────────────────────┐       │
│  │ EFS       │─── DataSync ──►│  S3 / EFS / FSx          │       │
│  │ (região A)│              │  (região B)               │       │
│  └───────────┘              └───────────────────────────┘       │
└──────────────────────────────────────────────────────────────────┘
```

### 25.3 Funcionalidades

| Feature | Descrição |
|---------|-----------|
| **Incremental** | Apenas dados alterados são transferidos após a primeira cópia |
| **Scheduling** | Agendar transfers (hora/diário/semanal) |
| **Filtering** | Incluir/excluir arquivos por padrão |
| **Bandwidth limit** | Throttle para não saturar link de rede |
| **Verification** | Checksums para garantir integridade |
| **Preservação** | Mantém permissões, timestamps, metadata |
| **Cross-Region** | Mover dados entre regiões AWS |
| **Cross-Account** | Mover dados entre contas AWS |

### 25.4 DataSync vs Snow Family vs Storage Gateway

| Critério | DataSync | Snow Family | Storage Gateway |
|----------|----------|-------------|-----------------|
| **Tipo** | Online, scheduled | Offline, físico | Online, contínuo |
| **Uso** | Migração e sincronização | Migração massiva | Acesso híbrido contínuo |
| **Quando** | Rede disponível, < 10PB | Rede insuficiente, > 10TB | Operação diária on-prem→cloud |
| **Direção** | On-prem → AWS ou AWS → AWS | On-prem → AWS | Bidirecional (cache) |
| **Persistência** | Task executa e termina | Device enviado e devolvido | Gateway permanece ativo |

> ⚠️ **Na prova**: "migrar NFS on-prem para EFS automaticamente" → **DataSync**
> ⚠️ **Na prova**: "sincronizar dados entre regiões" → **DataSync** (ou S3 Replication para S3)

---

## 26. AWS Transfer Family

### 26.1 Conceitos

- Serviço **managed** para transferência de arquivos via protocolos legados
- Protocolos suportados: **SFTP, FTPS, FTP, AS2**
- Destinos: **Amazon S3** ou **Amazon EFS**
- Endpoints: **público** (internet), **VPC** (privado), ou **VPC_ENDPOINT**
- Autenticação: **Service-managed** (SSH keys), **AD**, **Custom Identity Provider** (Lambda/API Gateway)

### 26.2 Quando usar

| Cenário | Por que Transfer Family |
|---------|------------------------|
| Parceiros enviam arquivos via SFTP | Não precisa gerenciar servidor SFTP |
| Compliance exige SFTP/FTPS | Protocolo managed com auditoria |
| Migrar servidor FTP on-prem para AWS | Drop-in replacement |
| Workflow de EDI (AS2) | Protocolo B2B managed |

### 26.3 Diagrama

```
┌──────────────────────────────────────────────────────────┐
│               AWS Transfer Family                         │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐   SFTP/FTPS   ┌────────────────┐          │
│  │ Parceiro │ ─────────────► │ Transfer Family │          │
│  │ Externo  │                │ (Managed Server)│          │
│  └──────────┘                └───────┬────────┘          │
│                                      │                   │
│                              ┌───────┼───────┐           │
│                              │       │       │           │
│                         ┌────▼──┐  ┌─▼────┐             │
│                         │  S3   │  │ EFS  │             │
│                         └───────┘  └──────┘             │
└──────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "managed SFTP/FTP server" → **AWS Transfer Family**
> ⚠️ **Na prova**: "parceiros precisam enviar arquivos via SFTP para S3" → **Transfer Family**

---

## 27. AWS Backup

### 27.1 Conceitos

- Serviço **centralizado** para gerenciar e automatizar backups de múltiplos serviços AWS
- **Não é um storage** — é um **orquestrador de backups**
- Define policies uma vez, aplica a múltiplos recursos

### 27.2 Componentes

| Componente | Descrição |
|-----------|-----------|
| **Backup Plan** | Define frequência (cron), retenção, transição para cold storage |
| **Backup Vault** | Container lógico para armazenar backups (criptografado KMS) |
| **Recovery Point** | Um backup individual (snapshot, AMI, etc.) |
| **Backup Selection** | Quais recursos incluir (tags, resource ARNs) |

### 27.3 Serviços Suportados

- EC2 (AMIs + EBS Snapshots)
- EBS (Snapshots)
- RDS (DB Snapshots)
- Aurora (Cluster Snapshots)
- DynamoDB (Table Backups)
- EFS (File System Backups)
- FSx (todos os tipos)
- Storage Gateway (Volume Backups)
- S3 (Backup de objetos)
- DocumentDB
- Neptune
- Redshift
- SAP HANA on EC2
- VMware (via Backup Gateway)

### 27.4 Features Avançadas

| Feature | Descrição |
|---------|-----------|
| **Cross-Region Backup** | Copia backups automaticamente para outra região (DR) |
| **Cross-Account Backup** | Copia backups para outra conta AWS (isolamento de segurança) |
| **Vault Lock (WORM)** | Write-Once-Read-Many — impede deleção de backups (compliance) |
| **Backup Audit Manager** | Verifica compliance de backup policies |
| **Legal Hold** | Impede deleção de recovery points específicos (auditoria/legal) |
| **Lifecycle to Cold Storage** | Move backups antigos para cold tier (menor custo) |

### 27.5 Vault Lock (WORM) — Detalhes

```
┌──────────────────────────────────────────────────────────────┐
│                 AWS Backup Vault Lock                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │  Backup Vault (com Vault Lock ativado)                │   │
│  │                                                       │   │
│  │  • Ninguém pode deletar backups (nem root user!)      │   │
│  │  • Backups retidos pelo período definido              │   │
│  │  • Compliance: SEC, FINRA, HIPAA                      │   │
│  │  • Cool-off period: 72h para cancelar (depois, final) │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova**: "backup centralizado de múltiplos serviços" → **AWS Backup**
> ⚠️ **Na prova**: "backups que nem root pode deletar" → **Vault Lock (WORM)**
> ⚠️ **Na prova**: "DR com cópia automática para outra região" → **Cross-Region Backup**
> ⚠️ **Na prova**: "isolamento de backups contra account compromise" → **Cross-Account Backup**

---

## 28. AWS CloudFormation (Breve)

### 28.1 Conceitos

- **Infrastructure as Code (IaC)** — define toda infraestrutura em templates declarativos
- Formato: **JSON** ou **YAML**
- Cada deploy cria uma **Stack** (conjunto de recursos)
- Recursos são provisionados na **ordem correta** (dependências resolvidas automaticamente)

### 28.2 Componentes Principais

| Componente | Descrição |
|-----------|-----------|
| **Template** | Arquivo JSON/YAML que descreve recursos |
| **Stack** | Instância de um template (conjunto de recursos provisionados) |
| **StackSet** | Deploy de stacks em múltiplas contas/regiões |
| **Change Set** | Preview de mudanças antes de aplicar |
| **Drift Detection** | Detecta se recursos foram modificados fora do CloudFormation |

### 28.3 Seções de um Template

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Exemplo"
Parameters:       # Inputs do usuário
Mappings:         # Constantes por região/condição
Conditions:       # Lógica condicional
Resources:        # OBRIGATÓRIO — recursos a criar
Outputs:          # Valores exportados (cross-stack reference)
```

### 28.4 Drift Detection

- Detecta quando recursos da stack foram **modificados manualmente** (console/CLI)
- Status: **IN_SYNC**, **DRIFTED**, **NOT_CHECKED**
- Não corrige automaticamente — apenas detecta e reporta

> ⚠️ **Na prova**: "IaC na AWS, managed" → **CloudFormation**
> ⚠️ **Na prova**: "detectar mudanças manuais na infraestrutura" → **Drift Detection**

---

## 29. Palavras-Chave da Prova SAA-C03 — Storage Avançado

### Cenários e Respostas Rápidas

| # | Cenário / Palavra-chave na prova | Resposta |
|---|----------------------------------|----------|
| 1 | "Shared file storage para Linux, multi-AZ" | **EFS** |
| 2 | "Windows file share com Active Directory" | **FSx for Windows File Server** |
| 3 | "HPC, Machine Learning, alta performance com S3" | **FSx for Lustre** |
| 4 | "Migrar NetApp on-prem para AWS" | **FSx for NetApp ONTAP** |
| 5 | "Migrar ZFS on-prem para AWS" | **FSx for OpenZFS** |
| 6 | "NFS + SMB + iSCSI ao mesmo tempo" | **FSx for NetApp ONTAP** |
| 7 | "On-prem NFS/SMB acesso a S3" | **S3 File Gateway** |
| 8 | "On-prem Windows acesso a FSx com cache" | **FSx File Gateway** |
| 9 | "Block storage on-prem com backup na cloud" | **Volume Gateway (Stored)** |
| 10 | "Expandir storage on-prem sem hardware" | **Volume Gateway (Cached)** |
| 11 | "Substituir tape backup físico" | **Tape Gateway** |
| 12 | "Migração offline > 10TB, rede lenta" | **Snowball Edge** |
| 13 | "Migração > 10PB" | **Snowmobile** |
| 14 | "Edge computing portátil, IoT remoto" | **Snowcone** |
| 15 | "Transferência online agendada NFS → EFS/S3" | **DataSync** |
| 16 | "SFTP/FTP managed para S3" | **AWS Transfer Family** |
| 17 | "Backup centralizado multi-serviço" | **AWS Backup** |
| 18 | "Backups imutáveis (WORM)" | **AWS Backup Vault Lock** |
| 19 | "Lambda precisa storage >512MB persistente" | **EFS mount (Access Point)** |
| 20 | "Isolar aplicações no mesmo file system" | **EFS Access Points** |
| 21 | "EFS com throughput imprevisível" | **Elastic throughput mode** |
| 22 | "EFS reduzir custos de dados raramente acessados" | **Lifecycle policy → IA classes** |
| 23 | "Dados temporários para HPC, sem replicação" | **FSx Lustre Scratch** |
| 24 | "Snow data imported → vai para Glacier" | **Snow → S3 Standard → Lifecycle → Glacier** |
| 25 | "Cross-region DR de backups" | **AWS Backup Cross-Region** |
| 26 | "Proteger backups contra conta comprometida" | **AWS Backup Cross-Account** |
| 27 | "Detectar mudanças manuais na infra" | **CloudFormation Drift Detection** |
| 28 | "File system com data deduplication" | **FSx for Windows File Server** |
| 29 | "Clone instantâneo de volumes sem copiar dados" | **FSx for NetApp ONTAP (FlexClone)** |
| 30 | "On-prem → AWS, sem infra de virtualização" | **Storage Gateway Hardware Appliance** |

---

## Resumo Visual — Árvore de Decisão de Storage

```
                         Preciso de storage?
                               │
                 ┌─────────────┼─────────────────┐
                 │             │                 │
              Block         File             Object
                 │             │                 │
           ┌────┴────┐    ┌───┴────┐           │
           │         │    │        │         Amazon S3
          EBS   Instance  EFS     FSx
                 Store    │        │
                          │    ┌───┴───┬──────┬────────┐
                       Linux   │       │      │        │
                       only  Windows  Lustre  ONTAP  OpenZFS
                                │       │      │        │
                              AD+SMB   HPC  Multi-    ZFS
                                      +S3   protocol  migration

                    Preciso mover dados?
                               │
              ┌────────────────┼────────────────┐
              │                │                │
          Online           Offline          Híbrido
              │                │             (contínuo)
         ┌────┴────┐     ┌────┴────┐           │
         │         │     │         │      Storage Gateway
      DataSync  Transfer  Snow    Snowmobile
               Family    (Cone/Ball)
```

---

## Dicas Finais para a Prova

1. **EFS = Linux only**. Se a questão menciona Windows → NÃO é EFS.
2. **FSx for Windows = SMB + AD**. Se menciona Active Directory → FSx Windows.
3. **FSx for Lustre = HPC + S3**. Se menciona HPC ou integração com S3 para compute → Lustre.
4. **Storage Gateway = on-premises**. Se não há componente on-prem → não é Storage Gateway.
5. **Snow Family = offline**. Se menciona transferência sem internet → Snow.
6. **DataSync = online + agendável**. Se menciona sincronização periódica → DataSync.
7. **Transfer Family = protocolos legados (SFTP/FTP)**. Se menciona parceiros enviando via SFTP → Transfer Family.
8. **AWS Backup Vault Lock = WORM = imutável**. Se menciona compliance ou proteção contra deleção → Vault Lock.
9. **Snowball importa SEMPRE para S3 Standard primeiro** → depois lifecycle move para Glacier.
10. **Volume Gateway Cached vs Stored**: "dados primários na nuvem" = Cached; "dados primários local" = Stored.

