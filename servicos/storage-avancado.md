# Storage Avançado — EFS, FSx, Storage Gateway, Snow, Backup

## EBS vs EFS vs S3 vs Instance Store — Tabela Geral

| | EBS | EFS | S3 | Instance Store |
|-|-----|-----|----|----------------|
| Tipo | Block storage | File storage (NFS) | Object storage | Block storage |
| Acesso | 1 instância (Multi-Attach: io1/io2 + mesma AZ) | Múltiplas instâncias, múltiplas AZs | Via HTTP (API/Console/CLI) | Apenas a instância host |
| Protocolo | Block device | NFS v4 | REST API | Block device |
| Persistência | ✅ (sobrevive stop) | ✅ | ✅ | ❌ (perde ao stop/terminate) |
| Multi-AZ | ❌ (por AZ) | ✅ Regional | ✅ (Standard/IA) | ❌ |
| Escalabilidade | Manual (aumentar volume) | Automática | Ilimitada | Fixo (ligado ao hardware) |
| Custo | Médio | Alto | Baixo | Incluído na instância |
| Casos de uso | Boot volume, banco de dados | Compartilhado entre servidores, CMS | Objetos, backups, data lake | Cache temporário, buffer de alta I/O |

---

## EFS — Elastic File System

- Sistema de arquivos NFS gerenciado, elástico e serverless
- Cresce e encolhe automaticamente — sem provisionar capacidade
- **Multi-AZ:** montado em múltiplas instâncias em diferentes AZs

### Performance Modes
| Modo | Quando usar |
|------|------------|
| General Purpose (padrão) | Latência sensível: web servers, CMS, home directories |
| Max I/O | Alta paralelização: big data, media processing (maior latência) |

### Throughput Modes
| Modo | Descrição |
|------|-----------|
| Bursting | Throughput escala com tamanho do filesystem |
| Provisioned | Define throughput independente do tamanho |
| Elastic | Auto-scaling de throughput (recomendado para workloads imprevisíveis) |

### Storage Classes
| Classe | Acesso | Custo |
|--------|--------|-------|
| EFS Standard | Frequente | Maior |
| EFS Standard-IA | Infrequente | Menor |
| EFS One Zone | Frequente (1 AZ) | Menor que Standard |
| EFS One Zone-IA | Infrequente (1 AZ) | Mais barato |

---

## FSx — Managed File Systems

| | FSx for Windows | FSx for Lustre | FSx for NetApp ONTAP | FSx for OpenZFS |
|-|----------------|---------------|---------------------|----------------|
| Protocolo | SMB | Lustre (POSIX) | NFS, SMB, iSCSI | NFS, SMB |
| Integração | Active Directory | S3 | — | — |
| Casos de uso | Windows workloads, SharePoint, SQL Server | HPC, ML, financial modeling | Enterprise storage migration | ZFS workloads |
| Performance | Alta | Muito alta (sub-milissegundo) | Alta | Alta |

### FSx for Lustre — Detalhes
- Integra com S3: pode ler/gravar objetos S3 como arquivos
- Deployment options: Scratch (sem replicação, mais barato) vs Persistent (replicado, HA)

---

## Storage Gateway

Conecta ambientes on-premises à AWS via interface familiar (NFS, SMB, iSCSI).

| Tipo | Interface | Dados em | Casos de uso |
|------|-----------|----------|-------------|
| **File Gateway** | NFS/SMB | S3 (por trás) | Backup de arquivos, extensão de storage on-prem para S3 |
| **Volume Gateway** | iSCSI (block) | S3 + EBS Snapshots | DR, backup de volumes, cloud migration |
| **Tape Gateway** | iSCSI (virtual tape) | S3 Glacier | Substituir fitas físicas de backup |

---

## Snow Family — Migração Física de Dados

| | Snowcone | Snowball Edge | Snowmobile |
|-|----------|--------------|------------|
| Capacidade | 8TB HDD / 14TB SSD | 80TB / 210TB | 100 PB |
| Compute | Limitado | ✅ EC2 + Lambda | ❌ |
| Portátil | ✅ (2kg) | ✅ | ❌ (caminhão) |
| Quando usar | Edge computing pequeno, < 24TB | 10TB-10PB, edge computing | > 10 PB, migração massiva |
| Transferência | Via AWS DataSync também | — | — |

> **Regra:** Migração de dados via Snow Family quando a janela de transferência pela internet seria > 1 semana.

---

## AWS Backup

- Serviço centralizado para gerenciar backups de múltiplos serviços AWS
- Suporte: EC2 (EBS), RDS, DynamoDB, EFS, FSx, Storage Gateway, S3
- **Backup Plan:** define frequência, retenção e destino
- **Cross-Region Backup:** copia backups para outra região (DR)
- **Cross-Account Backup:** copia backups para outra conta (isolamento)
- **Vault Lock (WORM):** protege backups de deleção acidental ou maliciosa

---

## Diferenças Críticas

- **EFS vs EBS:** EFS é compartilhado entre múltiplas instâncias/AZs; EBS é dedicado a uma instância por AZ
- **FSx for Windows vs EFS:** FSx for Windows usa SMB e integra com AD; EFS usa NFS e é para Linux
- **Storage Gateway File vs Volume:** File GW expõe S3 como NFS/SMB; Volume GW expõe como bloco iSCSI
- **Snowball vs DataSync:** Snowball é migração física offline; DataSync é migração online via rede
