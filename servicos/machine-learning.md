# Machine Learning na AWS — SAA-C03

> **Nota para a prova:** ML não é cobrado em profundidade na SAA-C03, mas você precisa saber **o que cada serviço faz** e **quando usá-lo**. Foque em associar cenários a serviços.

---

## 1. Tabela Geral — Serviços de ML da AWS

| Serviço | Descrição (1 linha) | Caso de Uso Típico |
|---------|--------------------|--------------------|
| Amazon Rekognition | Análise de imagens e vídeos com deep learning | Moderação de conteúdo, detecção facial, busca de celebridades |
| Amazon Transcribe | Conversão de fala em texto (speech-to-text) | Legendas automáticas, transcrição de call centers |
| Amazon Polly | Conversão de texto em fala (text-to-speech) | Leitura de artigos, assistentes de voz |
| Amazon Translate | Tradução de texto em tempo real | Localização de aplicações, tradução de chat |
| Amazon Lex | Criação de chatbots com voz e texto | Bots de atendimento, IVR inteligente |
| Amazon Connect | Contact center na nuvem | Central de atendimento telefônico escalável |
| Amazon Comprehend | Processamento de linguagem natural (NLP) | Análise de sentimento, extração de entidades |
| Amazon SageMaker | Plataforma completa de ML (build, train, deploy) | Modelos customizados de ML em produção |
| Amazon Kendra | Busca empresarial inteligente com NLP | Pesquisa interna em documentos corporativos |
| Amazon Personalize | Motor de recomendações personalizadas | Recomendações de produtos, conteúdo personalizado |
| Amazon Textract | OCR avançado com extração estruturada | Extração de dados de formulários e tabelas |
| Amazon Forecast | Previsão de séries temporais | Previsão de demanda, vendas, estoque |
| Amazon Fraud Detector | Detecção de fraudes com ML | Fraude em pagamentos, cadastros falsos |
| Amazon CodeGuru | Revisão automatizada de código | Identificar bugs e otimizações de performance |
| Amazon Augmented AI (A2I) | Revisão humana de previsões de ML | Validação de moderação de conteúdo |

---

## 2. Amazon Rekognition

### 2.1 O que é

Serviço de **visão computacional** totalmente gerenciado que permite analisar imagens e vídeos sem necessidade de conhecimento em ML.

### 2.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Detect Labels** | Identifica objetos, cenas, atividades (ex: carro, praia, corrida) |
| **Detect Faces** | Detecta rostos e atributos faciais (idade, emoção, óculos) |
| **Compare Faces** | Compara dois rostos e retorna similaridade |
| **Search Faces** | Busca faces em uma coleção indexada |
| **Recognize Celebrities** | Identifica celebridades em imagens |
| **Detect Text** | Extrai texto presente em imagens (placas, banners) |
| **Content Moderation** | Detecta conteúdo impróprio ou explícito |
| **Video Analysis** | Análise assíncrona de vídeos armazenados no S3 |
| **Custom Labels** | Treina modelo customizado para objetos específicos |

### 2.3 Arquitetura Típica

```
Imagem/Vídeo → S3 → Rekognition API → Resultados (JSON)
                                      → SNS (notificação)
                                      → Lambda (processamento)
```

### 2.4 Pontos Importantes para a Prova

- Integra nativamente com **S3** para processamento de imagens/vídeos
- Vídeos são processados de forma **assíncrona** (usa SNS para notificação)
- **Content Moderation** pode ser combinado com **Amazon A2I** para revisão humana
- Não requer conhecimento de ML — totalmente gerenciado
- Suporta streaming de vídeo via **Kinesis Video Streams**

---

## 3. Amazon Transcribe

### 3.1 O que é

Serviço de **speech-to-text** (reconhecimento automático de fala) que converte áudio em texto usando deep learning.

### 3.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Transcrição em lote** | Processa arquivos de áudio armazenados no S3 |
| **Transcrição em tempo real** | Streaming de áudio via WebSocket |
| **Automatic Language Identification** | Detecta automaticamente o idioma do áudio |
| **Multi-language** | Suporta 30+ idiomas |
| **Custom Vocabulary** | Adiciona termos específicos do domínio |
| **PII Redaction** | Remove/mascara informações pessoais (CPF, cartão) |
| **Vocabulary Filtering** | Remove palavras indesejadas da transcrição |
| **Speaker Identification** | Identifica diferentes speakers na conversa |

### 3.3 Casos de Uso

- Legendas automáticas para vídeos
- Transcrição de reuniões e call centers
- Análise de conformidade em ligações (compliance)
- Documentação médica (Transcribe Medical)

### 3.4 Pontos Importantes para a Prova

- **PII Redaction** é destaque — cenários de compliance e privacidade
- **Automatic Language Identification** — não precisa saber o idioma de antemão
- Integra com **S3** (entrada) e pode disparar **Lambda** para pós-processamento
- **Transcribe Medical** — variante especializada para terminologia médica

---

## 4. Amazon Polly

### 4.1 O que é

Serviço de **text-to-speech** (TTS) que converte texto em fala natural usando deep learning.

### 4.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Standard Voices** | Vozes concatenativas tradicionais |
| **Neural Voices** | Vozes mais naturais usando deep learning (NTTS) |
| **Multiple Languages** | 60+ vozes em 30+ idiomas |
| **Lexicons** | Personalização de pronúncia de palavras específicas |
| **SSML** | Speech Synthesis Markup Language — controle fino da fala |
| **Speech Marks** | Metadados de sincronização (lip sync) |

### 4.3 SSML — Controle Avançado

O SSML permite controlar:
- **Pausas** (`<break>`)
- **Ênfase** (`<emphasis>`)
- **Velocidade/Volume** (`<prosody>`)
- **Pronúncia fonética** (`<phoneme>`)
- **Sussurro** (`<amazon:effect name="whispered">`)

### 4.4 Pontos Importantes para a Prova

- Diferença entre **Standard** e **Neural** voices (Neural = mais natural, mais caro)
- **Lexicons** permitem customizar pronúncia (ex: siglas, nomes próprios)
- **SSML** oferece controle fino sobre a fala gerada
- Saída em formatos MP3, OGG, PCM
- Pode armazenar resultado no **S3**

---

## 5. Amazon Translate

### 5.1 O que é

Serviço de **tradução de texto** em tempo real usando neural machine translation (NMT).

### 5.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Real-time Translation** | Tradução síncrona via API |
| **Batch Translation** | Tradução de documentos em lote (S3) |
| **Custom Terminology** | Termos que não devem ser traduzidos (marcas, nomes) |
| **Auto Language Detection** | Detecta idioma de origem automaticamente |
| **Formality Setting** | Controle de formalidade (formal/informal) |

### 5.3 Pontos Importantes para a Prova

- **75+ idiomas** suportados
- Integra com outros serviços: Transcribe → Translate → Polly (pipeline multilíngue)
- **Custom Terminology** para manter termos específicos sem tradução
- Usado para localização de websites e aplicações
- Suporta tradução em **tempo real** e em **lote**

---


## 6. Amazon Lex

### 6.1 O que é

Serviço para construção de **chatbots conversacionais** com voz e texto. Utiliza a **mesma tecnologia da Alexa**.

### 6.2 Componentes Principais

| Componente | Descrição |
|-----------|-----------|
| **ASR (Automatic Speech Recognition)** | Converte fala em texto |
| **NLU (Natural Language Understanding)** | Entende a intenção do usuário |
| **Intents** | Ações que o bot pode executar |
| **Slots** | Parâmetros necessários para completar um intent |
| **Fulfillment** | Lógica de negócio (geralmente via Lambda) |
| **Utterances** | Frases de exemplo que disparam um intent |

### 6.3 Integrações

- **AWS Lambda** — lógica de fulfillment e validação
- **Amazon Connect** — IVR inteligente para call centers
- **Amazon CloudWatch** — monitoramento e logs
- **Amazon Kendra** — busca inteligente integrada ao bot
- **Messaging platforms** — Facebook, Slack, Twilio

### 6.4 Pontos Importantes para a Prova

- **Mesma tecnologia do Alexa** — palavra-chave frequente
- ASR + NLU integrados no mesmo serviço
- Integração nativa com **Lambda** para processamento
- Usado para criar **IVR inteligente** quando combinado com Amazon Connect
- Escala automaticamente — serverless

---

## 7. Amazon Connect

### 7.1 O que é

Serviço de **contact center na nuvem** — permite criar centrais de atendimento telefônico escaláveis, sem hardware.

### 7.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Contact Flows** | Fluxos visuais de atendimento (drag-and-drop) |
| **Phone Numbers** | Números de telefone provisionados pela AWS |
| **Queues** | Filas de atendimento com roteamento inteligente |
| **IVR com Lex** | Menu interativo usando chatbot do Lex |
| **Real-time Analytics** | Métricas em tempo real dos atendimentos |
| **Recording** | Gravação de chamadas armazenadas no S3 |
| **Contact Lens** | Análise de sentimento e transcrição de chamadas |

### 7.3 Arquitetura Típica com ML

```
Ligação → Amazon Connect → Lex (IVR inteligente)
                         → Transcribe (transcrição)
                         → Comprehend (sentimento)
                         → S3 (gravações)
                         → Lambda (lógica customizada)
```

### 7.4 Pontos Importantes para a Prova

- **Contact center cloud-based** — sem infraestrutura física
- Integra com **Lex** para IVR inteligente (reconhecimento de fala natural)
- **Pay-per-use** — cobra por minuto de uso
- Pode receber chamadas de qualquer telefone convencional
- **Contact Lens** usa ML para analisar sentimento das chamadas
- Cenários: "empresa quer migrar call center para a nuvem" → Amazon Connect

---

## 8. Amazon Comprehend

### 8.1 O que é

Serviço de **NLP (Natural Language Processing)** totalmente gerenciado que extrai insights de texto.

### 8.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Sentiment Analysis** | Positivo, negativo, neutro, misto |
| **Entity Recognition** | Identifica pessoas, lugares, datas, organizações |
| **Key Phrase Extraction** | Extrai frases-chave do texto |
| **Language Detection** | Identifica o idioma do texto (100+ idiomas) |
| **Topic Modeling** | Agrupa documentos por tópicos |
| **Syntax Analysis** | Análise sintática (substantivos, verbos, etc.) |
| **PII Detection** | Detecta informações pessoais no texto |
| **Custom Classification** | Classificação customizada de documentos |
| **Custom Entity Recognition** | Reconhecimento de entidades customizadas |

### 8.3 Amazon Comprehend Medical

Variante especializada para **dados de saúde**:
- Extrai condições médicas, medicamentos, dosagens
- Identifica relações entre entidades médicas
- Integra com sistemas de saúde (EHR/EMR)
- Detecta PHI (Protected Health Information) — compliance HIPAA

### 8.4 Pontos Importantes para a Prova

- **Análise de sentimento** — cenários de feedback de clientes, reviews
- **NLP serverless** — não precisa gerenciar infraestrutura
- **Comprehend Medical** — cenários de healthcare
- Pode processar em **lote** (S3) ou em **tempo real** (API)
- Integra com **S3**, **Lambda**, **Kinesis Data Firehose**
- Cenário: "analisar sentimento de reviews de produtos" → Comprehend

---

## 9. Amazon SageMaker

### 9.1 O que é

Plataforma **completa e gerenciada** para construir, treinar e implantar modelos de machine learning em produção.

### 9.2 Componentes Principais

| Componente | Descrição |
|-----------|-----------|
| **SageMaker Studio** | IDE web completa para ML |
| **Notebooks** | Jupyter notebooks gerenciados |
| **Training** | Infraestrutura gerenciada para treinamento |
| **Endpoints** | Deploy de modelos como APIs REST |
| **Ground Truth** | Serviço de labeling de dados |
| **Autopilot** | AutoML — cria modelos automaticamente |
| **Model Monitor** | Monitora drift e qualidade do modelo |
| **Feature Store** | Repositório centralizado de features |
| **Pipelines** | MLOps — CI/CD para ML |
| **Canvas** | Interface visual no-code para ML |

### 9.3 Fluxo de Trabalho

```
1. Preparar dados (S3)
2. Rotular dados (Ground Truth)
3. Desenvolver (Studio/Notebooks)
4. Treinar (Training Jobs)
5. Avaliar modelo
6. Deploy (Endpoints)
7. Monitorar (Model Monitor)
```

### 9.4 Pontos Importantes para a Prova

- **Plataforma completa** — end-to-end para ML
- Para a SAA-C03: saiba que é a opção para "ML customizado"
- Diferença dos outros serviços: SageMaker = **você constrói o modelo**
- Outros serviços (Rekognition, Comprehend) = **modelos pré-treinados**
- **Notebooks** para desenvolvimento e experimentação
- **Endpoints** para inferência em tempo real
- Cenário: "cientista de dados quer treinar modelo customizado" → SageMaker

---


## 10. Amazon Kendra

### 10.1 O que é

Serviço de **busca empresarial inteligente** que usa NLP para encontrar informações em documentos corporativos.

### 10.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Natural Language Queries** | Busca com perguntas em linguagem natural |
| **Document Indexing** | Indexa múltiplos formatos (PDF, Word, HTML, PPT) |
| **FAQ Extraction** | Extrai perguntas e respostas automaticamente |
| **Relevance Tuning** | Ajuste de relevância dos resultados |
| **Access Control** | Respeita permissões de acesso aos documentos |
| **Connectors** | Conecta com S3, RDS, SharePoint, Salesforce, etc. |
| **Custom Document Enrichment** | Enriquece documentos durante indexação |

### 10.3 Data Sources (Conectores)

- Amazon S3
- Amazon RDS
- Microsoft SharePoint
- Salesforce
- ServiceNow
- OneDrive
- Google Drive
- Confluence
- Bases de dados via JDBC

### 10.4 Pontos Importantes para a Prova

- **Enterprise search** — diferente do CloudSearch/Elasticsearch
- Entende **linguagem natural** (não apenas keywords)
- **FAQ extraction** — extrai pares pergunta/resposta de documentos
- Respeita **ACLs** dos documentos originais
- Cenário: "empresa quer busca inteligente em documentos internos" → Kendra
- Integra com **Lex** para adicionar busca a chatbots

---

## 11. Amazon Personalize

### 11.1 O que é

Serviço de **recomendações personalizadas** em tempo real — usa a **mesma tecnologia do Amazon.com**.

### 11.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **User Personalization** | Recomendações baseadas no histórico do usuário |
| **Similar Items** | Itens semelhantes ao que o usuário viu |
| **Personalized Ranking** | Reordena lista baseado em preferências |
| **Real-time Events** | Incorpora interações em tempo real |
| **Batch Recommendations** | Recomendações em lote (S3) |
| **Campaigns** | Endpoints de inferência gerenciados |

### 11.3 Dados de Entrada

| Tipo de Dataset | Descrição |
|----------------|-----------|
| **Users** | Metadados dos usuários (idade, localização) |
| **Items** | Metadados dos itens (categoria, preço) |
| **Interactions** | Histórico de interações (cliques, compras, views) |

### 11.4 Pontos Importantes para a Prova

- **Mesma tecnologia do Amazon.com** — palavra-chave frequente
- Não precisa de conhecimento de ML — apenas fornecer dados
- Recomendações em **tempo real** e em **lote**
- Cenários: "recomendação de produtos", "conteúdo personalizado", "ranking personalizado"
- Diferente do SageMaker: Personalize é **específico para recomendações**
- Dados enviados via **S3** (datasets) e **API/SDK** (eventos em tempo real)

---

## 12. Amazon Textract

### 12.1 O que é

Serviço de **OCR avançado** que extrai texto, tabelas e dados de formulários de documentos digitalizados.

### 12.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **Detect Document Text** | OCR básico — extrai todo o texto |
| **Analyze Document** | Extrai texto + estrutura (tabelas, formulários) |
| **Tables** | Identifica e extrai dados tabulares |
| **Forms** | Extrai pares chave-valor de formulários |
| **Queries** | Faz perguntas específicas sobre o documento |
| **Expense Analysis** | Extrai dados de notas fiscais e recibos |
| **Identity Document** | Extrai dados de documentos de identidade |
| **Lending** | Processa documentos de empréstimos |

### 12.3 Diferença de OCR Tradicional vs Textract

| Aspecto | OCR Tradicional | Amazon Textract |
|---------|----------------|-----------------|
| Texto simples | ✅ | ✅ |
| Tabelas | ❌ | ✅ |
| Formulários (key-value) | ❌ | ✅ |
| Layout/Estrutura | ❌ | ✅ |
| Queries em linguagem natural | ❌ | ✅ |

### 12.4 Pontos Importantes para a Prova

- **Mais que OCR** — extrai estrutura (tabelas + formulários)
- Processa documentos do **S3** ou via **API direta** (bytes)
- Cenários: "extrair dados de formulários", "processar notas fiscais", "digitalizar documentos"
- Diferente do **Rekognition Detect Text** — Textract entende a **estrutura** do documento
- Assíncrono para documentos multi-página (notifica via **SNS**)

---

## 13. Amazon Forecast

### 13.1 O que é

Serviço de **previsão de séries temporais** que usa ML para gerar previsões precisas sem conhecimento de ML.

### 13.2 Funcionalidades Principais

| Funcionalidade | Descrição |
|---------------|-----------|
| **AutoML** | Seleciona automaticamente o melhor algoritmo |
| **Multiple Algorithms** | DeepAR+, Prophet, ETS, ARIMA, NPTS |
| **Related Time Series** | Incorpora dados contextuais (promoções, clima) |
| **Item Metadata** | Metadados dos itens para melhorar previsões |
| **What-if Analysis** | Simula cenários hipotéticos |
| **Explainability** | Explica fatores que influenciam a previsão |

### 13.3 Casos de Uso

- Previsão de **demanda de produtos**
- Planejamento de **estoque**
- Previsão de **receita/vendas**
- Planejamento de **capacidade** (servidores, recursos)
- Previsão de **tráfego** web

### 13.4 Pontos Importantes para a Prova

- Cenários de **previsão de demanda/vendas** → Forecast
- Não precisa de expertise em ML — fornece dados históricos e o serviço faz o resto
- Dados de entrada via **S3** (CSV)
- Até **50% mais preciso** que métodos tradicionais (segundo a AWS)
- Diferente do SageMaker: Forecast é **específico para séries temporais**

---

## 14. Palavras-Chave da Prova SAA-C03

### Cenários e Respostas Rápidas

| # | Cenário na Prova | Resposta |
|---|-----------------|----------|
| 1 | "Detectar conteúdo impróprio em imagens enviadas por usuários" | **Amazon Rekognition** (Content Moderation) |
| 2 | "Transcrever chamadas de call center e remover dados pessoais" | **Amazon Transcribe** (com PII Redaction) |
| 3 | "Converter artigos em áudio para podcast automatizado" | **Amazon Polly** |
| 4 | "Traduzir conteúdo do site para múltiplos idiomas" | **Amazon Translate** |
| 5 | "Criar chatbot para atendimento ao cliente" | **Amazon Lex** |
| 6 | "Migrar call center para a nuvem com IVR inteligente" | **Amazon Connect** + **Lex** |
| 7 | "Analisar sentimento de reviews de clientes" | **Amazon Comprehend** |
| 8 | "Cientista de dados precisa treinar modelo customizado" | **Amazon SageMaker** |
| 9 | "Busca inteligente em documentos internos da empresa" | **Amazon Kendra** |
| 10 | "Recomendações personalizadas de produtos para e-commerce" | **Amazon Personalize** |
| 11 | "Extrair dados de formulários e notas fiscais digitalizadas" | **Amazon Textract** |
| 12 | "Prever demanda de produtos para planejamento de estoque" | **Amazon Forecast** |
| 13 | "Identificar celebridades em fotos de eventos" | **Amazon Rekognition** (Celebrity Recognition) |
| 14 | "Extrair informações médicas de prontuários de texto" | **Amazon Comprehend Medical** |
| 15 | "Adicionar legendas automáticas a vídeos" | **Amazon Transcribe** |
| 16 | "Detectar fraudes em transações de pagamento" | **Amazon Fraud Detector** |
| 17 | "Verificar identidade facial no login da aplicação" | **Amazon Rekognition** (Compare Faces) |
| 18 | "Classificar documentos automaticamente por categoria" | **Amazon Comprehend** (Custom Classification) |
| 19 | "Criar pipeline completo de ML com CI/CD" | **Amazon SageMaker Pipelines** |
| 20 | "Empresa quer usar mesma tecnologia de recomendação da Amazon" | **Amazon Personalize** |

### Dicas de Associação Rápida

| Palavra-chave no Enunciado | Serviço |
|---------------------------|---------|
| Imagem, vídeo, face, moderação | Rekognition |
| Fala → texto, transcrição, legendas | Transcribe |
| Texto → fala, áudio, voz | Polly |
| Tradução, idiomas, localização | Translate |
| Chatbot, Alexa, conversacional | Lex |
| Call center, telefone, IVR | Connect |
| Sentimento, NLP, entidades, tópicos | Comprehend |
| Treinar modelo, deploy, notebook | SageMaker |
| Busca inteligente, documentos, FAQ | Kendra |
| Recomendação, personalização | Personalize |
| OCR, formulário, tabela, documento | Textract |
| Previsão, demanda, série temporal | Forecast |
| Fraude, transação suspeita | Fraud Detector |

---

## 15. Resumo Comparativo Final

### Serviços Pré-treinados vs Customizáveis

| Categoria | Serviços Pré-treinados (sem ML skills) | Serviço Customizável (requer ML skills) |
|-----------|----------------------------------------|----------------------------------------|
| Visão | Rekognition, Textract | SageMaker |
| Linguagem | Comprehend, Translate, Lex | SageMaker |
| Fala | Transcribe, Polly | SageMaker |
| Recomendação | Personalize | SageMaker |
| Previsão | Forecast | SageMaker |
| Busca | Kendra | OpenSearch |

### Quando Usar SageMaker vs Serviços Gerenciados

| Use SageMaker quando... | Use serviços gerenciados quando... |
|------------------------|------------------------------------|
| Precisa de modelo customizado | O caso de uso se encaixa em um serviço existente |
| Tem cientistas de dados na equipe | Não tem expertise em ML |
| Requisitos muito específicos | Quer solução rápida e simples |
| Precisa de controle total do pipeline | Precisa de escalabilidade automática |

---

## 16. Integrações Comuns entre Serviços ML

### Pipeline de Processamento de Áudio/Vídeo

```
Upload → S3 → Lambda (trigger)
         ↓
    Transcribe (áudio → texto)
         ↓
    Comprehend (sentimento, entidades)
         ↓
    Translate (se necessário)
         ↓
    Polly (texto → áudio em outro idioma)
         ↓
    S3 (resultado final)
```

### Pipeline de Processamento de Documentos

```
Upload → S3 → Lambda (trigger)
         ↓
    Textract (extração de texto/tabelas)
         ↓
    Comprehend (classificação, entidades)
         ↓
    Kendra (indexação para busca)
         ↓
    DynamoDB/RDS (dados estruturados)
```

### Contact Center Inteligente

```
Chamada → Amazon Connect
           ↓
    Lex (IVR - entende intenção)
           ↓
    Lambda (lógica de negócio)
           ↓
    Transcribe (grava e transcreve)
           ↓
    Comprehend (analisa sentimento)
           ↓
    S3 + Athena (analytics)
```

---

> **Última dica:** Na SAA-C03, a maioria das perguntas de ML será sobre **escolher o serviço correto** para um cenário. Memorize a tabela de palavras-chave (seção 14) e você estará preparado!
