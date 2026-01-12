# 🏥 Informix HealthCheck v2.0

<div align="center">

**Comprehensive Informix Database Health Monitoring Tool**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Informix](https://img.shields.io/badge/Informix-11.50%2B-orange.svg)](https://www.ibm.com/products/informix)

</div>

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Novidades v2.0](#-novidades-v20)
- [Características](#-características)
- [Compatibilidade](#-compatibilidade)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Reports e Visualizações](#-reports-e-visualizações)
- [Checks Realizados](#-checks-realizados)
- [Notificações](#-notificações)
- [Troubleshooting](#-troubleshooting)
- [Contribuindo](#-contribuindo)
- [Licença](#-licença)

---

## 🎯 Visão Geral

O **Informix HealthCheck** é uma ferramenta completa e moderna para monitoramento da saúde de bancos de dados Informix. Projetada para DBAs, a ferramenta oferece análise detalhada, relatórios HTML5 interativos e notificações automáticas sobre o estado do seu ambiente Informix.

### Objetivo

Fornecer uma visão clara e abrangente da saúde do ambiente Informix, detectando proativamente problemas críticos e fornecendo insights acionáveis através de relatórios visuais modernos e intuitivos.

---

## 🆕 Novidades v2.0

Esta versão representa uma **modernização completa** da aplicação:

### 🎨 Interface & UX
- ✨ **Relatórios HTML5 modernos** com design responsivo
- 📊 **Gráficos interativos** usando Chart.js
- 🎯 **Dashboard com filtros** e busca em tempo real
- 📱 **Design responsivo** para visualização mobile
- 🌈 **Interface visual aprimorada** com melhor UX

### 🏗️ Arquitetura
- 🧩 **Arquitetura modular** com separação de responsabilidades
- 📦 **Código refatorado** seguindo melhores práticas
- 🔧 **Configuração JSON** flexível e estruturada
- 📝 **Sistema de logging** robusto e estruturado
- 🔍 **Tratamento de erros** aprimorado

### 🚀 Funcionalidades
- 🔄 **Suporte multi-versão** do Informix (11.50, 11.70, 12.10, 14.10)
- 🔍 **Detecção automática** de versão do Informix
- 📈 **Histórico de métricas** para análise de tendências
- 🔔 **Múltiplos canais** de notificação (Email, Slack, Teams)
- 🎛️ **Checks configuráveis** - habilite/desabilite conforme necessário
- 💾 **Exportação para PDF** dos relatórios
- ⚙️ **Thresholds personalizáveis** para alertas

### 📊 Novos Checks
- 👥 **Sessões ativas** e long-running queries
- 🔒 **Locks e deadlocks** do sistema
- ✅ **Checkpoints** e performance
- 📜 **Logical logs** e disponibilidade
- 📊 **Métricas de performance** detalhadas
- 💻 **Estatísticas do sistema** (I/O, memória, threads)

---

## ⭐ Características

### Core Features

| Característica | Descrição |
|---------------|-----------|
| 🔍 **Detecção Automática** | Detecta versão do Informix e adapta queries automaticamente |
| 📊 **Reports Interativos** | HTML5 moderno com gráficos, filtros e busca |
| 🎯 **Multi-instância** | Monitore múltiplos servidores Informix simultaneamente |
| 📧 **Notificações Inteligentes** | Email, Slack, Teams com alertas configuráveis |
| 🔄 **Histórico** | Rastreamento de métricas ao longo do tempo |
| ⚙️ **Configurável** | JSON configuration com todos os parâmetros ajustáveis |
| 🛡️ **Seguro** | Sem credenciais hardcoded, usa variáveis de ambiente |
| 📱 **Responsivo** | Visualize relatórios em desktop, tablet ou mobile |

### Benefícios

- ⏱️ **Economia de Tempo**: Coleta automática de métricas críticas
- 🎯 **Proatividade**: Identifique problemas antes que se tornem críticos
- 📈 **Insights**: Visualize tendências e padrões de uso
- 🔔 **Alertas**: Seja notificado imediatamente sobre problemas
- 📋 **Compliance**: Documentação automática do estado do sistema
- 🤝 **Colaboração**: Relatórios compartilháveis com a equipe

---

## 🔧 Compatibilidade

### Versões do Informix Suportadas

| Versão | Status | Notas |
|--------|--------|-------|
| **14.10** | ✅ Completo | Todas as features suportadas |
| **12.10** | ✅ Completo | Suporte completo incluindo JSON |
| **11.70** | ✅ Completo | Todas as features principais |
| **11.50** | ✅ Básico | Algumas features limitadas |
| **< 11.50** | ⚠️ Limitado | Funcionalidade reduzida |

### Sistemas Operacionais

- ✅ Linux (RHEL, CentOS, Ubuntu, Debian)
- ✅ Unix (AIX, Solaris, HP-UX)
- ⚠️ Windows (com WSL ou Cygwin)

### Dependências

#### Requeridas
- `bash` 4.0+
- `awk`
- `sed`
- `grep`
- `date`
- `bc`
- `dbaccess` (Informix Client/Server)

#### Opcionais (recomendadas)
- `jq` - Parsing JSON (melhora configuração)
- `mailx` - Envio de emails
- `curl` - Notificações Slack/Teams
- `wkhtmltopdf` - Exportação para PDF

---

## 🚀 Instalação

### Instalação Rápida

```bash
# Clone o repositório
git clone https://github.com/yourusername/HealthCheck_Informix.git
cd HealthCheck_Informix

# Execute o setup
./setup.sh

# Configure seus hosts
cp config/hosts.conf.example config/hosts.conf
nano config/hosts.conf

# Execute o primeiro health check
./healthcheck.sh --no-email
```

### Instalação Manual

```bash
# 1. Criar estrutura de diretórios
mkdir -p {config,lib,modules,templates,reports,logs,data/{collections,history}}

# 2. Verificar dependências
command -v dbaccess || echo "Instale Informix Client SDK"
command -v jq || sudo apt-get install jq  # ou yum install jq

# 3. Configurar permissões
chmod +x healthcheck.sh setup.sh
chmod 750 config logs

# 4. Configurar ambiente Informix
export INFORMIXDIR=/opt/IBM/informix
export PATH=$INFORMIXDIR/bin:$PATH
export LD_LIBRARY_PATH=$INFORMIXDIR/lib:$LD_LIBRARY_PATH
```

### Instalação via Docker (Futuro)

```bash
# Em desenvolvimento
docker pull yourusername/informix-healthcheck:latest
docker run -v ./config:/app/config informix-healthcheck
```

---

## ⚙️ Configuração

### 1. Configuração Principal (`config/healthcheck.json`)

```json
{
  "database": {
    "hosts_file": "config/hosts.conf",
    "connection_timeout": 30,
    "query_timeout": 300
  },
  "thresholds": {
    "backup": {
      "critical_age_hours": 24,
      "warning_age_hours": 20
    },
    "dbspace": {
      "critical_free_gb": 10,
      "warning_free_gb": 20
    }
  },
  "email": {
    "enabled": true,
    "smtp_server": "smtp.yourdomain.com",
    "from": "informix@yourdomain.com",
    "to": ["dba-team@yourdomain.com"]
  }
}
```

### 2. Configuração de Hosts (`config/hosts.conf`)

```bash
# Formato: hostname|instance_name|port|description
prod-db01|informix_prod|9088|Production Database Server 1
prod-db02|informix_prod|9088|Production Database Server 2
dev-db01|informix_dev|9088|Development Database Server
```

### 3. Variáveis de Ambiente

```bash
# Adicione ao ~/.bashrc ou ~/.bash_profile

# Informix
export INFORMIXDIR=/opt/IBM/informix
export INFORMIXSERVER=informix_prod
export PATH=$INFORMIXDIR/bin:$PATH
export LD_LIBRARY_PATH=$INFORMIXDIR/lib:$LD_LIBRARY_PATH

# HealthCheck
export HEALTHCHECK_SMTP_PASSWORD='your-smtp-password'
```

### 4. Personalização de Thresholds

Edite `config/healthcheck.json` para ajustar os limites:

```json
"thresholds": {
  "backup": {
    "critical_age_hours": 24,     // Backup mais antigo que 24h = Crítico
    "warning_age_hours": 20       // Backup mais antigo que 20h = Warning
  },
  "dbspace": {
    "critical_free_gb": 10,       // Menos de 10GB livre = Crítico
    "warning_free_gb": 20,        // Menos de 20GB livre = Warning
    "min_report_threshold_gb": 15 // Só reporta dbspaces com < 15GB
  },
  "pages": {
    "critical_threshold": 13421772,  // ~80% do limite de 16M páginas
    "warning_threshold": 10000000,   // 10M páginas
    "max_pages_limit": 16777215      // Limite hard do Informix
  }
}
```

---

## 📖 Uso

### Uso Básico

```bash
# Health check completo com envio de email
./healthcheck.sh

# Health check sem envio de email
./healthcheck.sh --no-email

# Health check com modo verbose
./healthcheck.sh --verbose

# Health check com debug
./healthcheck.sh --debug --verbose
```

### Opções Avançadas

```bash
# Usar configuração customizada
./healthcheck.sh --config /path/to/custom-config.json

# Usar arquivo de hosts customizado
./healthcheck.sh --hosts /path/to/custom-hosts.conf

# Diretório de output customizado
./healthcheck.sh --output /custom/reports/dir

# Combinando opções
./healthcheck.sh --config custom.json --no-email --verbose
```

### Agendamento Automático (Cron)

```bash
# Editar crontab
crontab -e

# Executar diariamente às 8:00 AM
0 8 * * * /path/to/HealthCheck_Informix/healthcheck.sh >> /path/to/logs/cron.log 2>&1

# Executar a cada 6 horas
0 */6 * * * /path/to/HealthCheck_Informix/healthcheck.sh

# Executar de segunda a sexta às 7:00 AM
0 7 * * 1-5 /path/to/HealthCheck_Informix/healthcheck.sh
```

### Exemplos de Uso

```bash
# Verificar apenas um servidor específico
echo "server01|informix_prod|9088|Test" | ./healthcheck.sh --hosts /dev/stdin

# Gerar relatório sem alertas
./healthcheck.sh --no-email > /tmp/healthcheck.log

# Debug de problemas de conexão
./healthcheck.sh --debug 2>&1 | tee debug.log
```

---

## 📁 Estrutura do Projeto

```
HealthCheck_Informix/
│
├── healthcheck.sh              # Script principal
├── setup.sh                    # Script de instalação/setup
├── README.md                   # Esta documentação
├── LICENSE                     # Licença GPL v3
│
├── config/                     # Configurações
│   ├── healthcheck.json        # Configuração principal
│   ├── hosts.conf              # Lista de hosts Informix
│   └── hosts.conf.example      # Exemplo de configuração
│
├── lib/                        # Bibliotecas core
│   ├── utils.sh                # Funções utilitárias e logging
│   └── version_detect.sh       # Detecção de versão do Informix
│
├── modules/                    # Módulos funcionais
│   ├── collector.sh            # Coleta de dados do Informix
│   ├── report_generator.sh    # Geração de relatórios HTML
│   └── notifier.sh             # Sistema de notificações
│
├── templates/                  # Templates HTML
│   └── report_template.html   # Template do relatório
│
├── reports/                    # Relatórios gerados
│   └── HealthCheck_Report_*.html
│
├── logs/                       # Arquivos de log
│   └── healthcheck_*.log
│
└── data/                       # Dados coletados
    ├── collections/            # Coletas brutas
    └── history/                # Histórico de métricas
```

---

## 📊 Reports e Visualizações

### Dashboard Overview

O dashboard principal exibe:

- **Health Status Cards**: Resumo visual do estado geral
- **Critical Issues Counter**: Contador de problemas críticos
- **Warning Alerts**: Alertas que requerem atenção
- **System Metrics**: Métricas chave do sistema

### Seções do Relatório

#### 1. 💾 Backup Status
- Status dos backups (BAR)
- Horário de início e término
- Duração dos backups
- Alertas de backups desatualizados

#### 2. 💿 DBSpace Usage
- Uso de espaço por dbspace
- Espaço livre disponível
- Percentual de utilização
- Alertas de espaço crítico

#### 3. 📄 Table Page Usage
- Tabelas próximas ao limite de páginas (16M)
- Uso de páginas por tabela
- Fragmentação
- Recomendações de ação

#### 4. 👥 Active Sessions
- Sessões ativas no momento
- Long-running queries
- Usuários conectados
- Programas em execução

#### 5. 🔒 Locks & Deadlocks
- Locks ativos
- Lock waits
- Deadlocks detectados
- Objetos bloqueados

#### 6. ⚠️ System Alerts
- Alertas do ph_alert
- Mensagens do scheduler
- Avisos do sistema
- Erros recentes

#### 7. 📊 Performance Metrics
- I/O de disco (reads/writes)
- Buffer waits
- Lock waits
- Checkpoint duration

### Recursos Interativos

- 🔍 **Busca em tempo real** em todas as tabelas
- 🎯 **Filtros por status** (Critical, Warning, OK)
- 📈 **Gráficos interativos** com Chart.js
- 📱 **Navegação por abas** entre seções
- 🖨️ **Exportação para PDF** (via print)
- 📧 **Compartilhamento** via email

---

## 🔍 Checks Realizados

### Checks de Backup

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| Backup Age | Idade do último backup | Critical: >24h, Warning: >20h |
| Backup Status | Status da execução do BAR | Critical: Failed |
| Backup Duration | Tempo de execução | Warning: Aumentos significativos |

### Checks de Espaço

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| DBSpace Free | Espaço livre em GB | Critical: <10GB, Warning: <20GB |
| DBSpace Percent | Percentual livre | Warning: <10% |
| Chunk Allocation | Alocação de chunks | Info |

### Checks de Páginas

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| Pages Used | Páginas usadas por tabela | Critical: >13.4M, Warning: >10M |
| Page Fragmentation | Fragmentação de páginas | Warning: Alto |

### Checks de Sessões

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| Active Sessions | Sessões ativas | Info |
| Long Running | Queries > 1 hora | Warning |
| Session Count | Total de sessões | Warning: Próximo ao limite |

### Checks de Locks

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| Lock Waits | Locks aguardando | Warning: >0 |
| Deadlocks | Deadlocks detectados | Critical: >0 |
| Lock Timeouts | Timeouts de lock | Warning: >0 |

### Checks de Performance

| Check | Descrição | Threshold |
|-------|-----------|-----------|
| Disk I/O | Taxa de leitura/escrita | Info |
| Buffer Waits | Waits por buffer | Warning: Alto |
| Checkpoint Duration | Tempo de checkpoint | Warning: >300s |
| Logical Logs | Logs livres | Warning: <5 |

---

## 🔔 Notificações

### Email

Configuração completa de envio via SMTP:

```json
"email": {
  "enabled": true,
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 587,
  "use_tls": true,
  "auth_user": "healthcheck@yourdomain.com",
  "auth_password_env": "HEALTHCHECK_SMTP_PASSWORD",
  "from": "informix@yourdomain.com",
  "to": ["dba-team@yourdomain.com", "manager@yourdomain.com"],
  "cc": ["backup-list@yourdomain.com"],
  "subject": "Informix HealthCheck Report - %DATE%",
  "send_on_critical_only": false
}
```

### Slack

Integração via webhook:

```json
"notifications": {
  "slack_enabled": true,
  "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}
```

Exemplo de notificação Slack:
```
🏥 Informix HealthCheck Report

🚨 *3 critical issue(s)* detected

Critical Issues: 3
Warnings: 5

Report generated: 2024-01-15 08:00:00
```

### Microsoft Teams

Integração via webhook do Teams:

```json
"notifications": {
  "teams_enabled": true,
  "webhook_url": "https://outlook.office.com/webhook/YOUR/WEBHOOK/URL"
}
```

### Notificações Condicionais

```json
"email": {
  "send_on_critical_only": true  // Só envia email se houver problemas críticos
}
```

---

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. "INFORMIXDIR not set"

```bash
# Solução
export INFORMIXDIR=/opt/IBM/informix
export PATH=$INFORMIXDIR/bin:$PATH
```

#### 2. "dbaccess: command not found"

```bash
# Verificar instalação
which dbaccess

# Adicionar ao PATH
export PATH=$INFORMIXDIR/bin:$PATH
```

#### 3. "Cannot connect to database"

```bash
# Testar conexão
echo "SELECT FIRST 1 1 FROM systables;" | dbaccess sysmaster

# Verificar sqlhosts
cat $INFORMIXDIR/etc/sqlhosts

# Testar conectividade
telnet hostname 9088
```

#### 4. "Email not sending"

```bash
# Verificar mailx
which mailx

# Testar envio
echo "Test" | mailx -s "Test" your@email.com

# Verificar variável de ambiente
echo $HEALTHCHECK_SMTP_PASSWORD
```

#### 5. "Permission denied"

```bash
# Dar permissões de execução
chmod +x healthcheck.sh setup.sh

# Verificar permissões de diretórios
chmod 750 config logs reports
```

### Debug Mode

```bash
# Executar com máximo debug
./healthcheck.sh --debug --verbose 2>&1 | tee debug.log

# Verificar logs
tail -f logs/healthcheck_$(date +%Y%m%d).log

# Verificar queries executadas
grep "Executing" logs/healthcheck_*.log
```

### Validação

```bash
# Validar JSON de configuração
jq . config/healthcheck.json

# Testar coleta de dados
./healthcheck.sh --no-email --verbose

# Verificar relatório gerado
ls -lh reports/
```

---

## 🙌 Contribuindo

Contribuições são bem-vindas! Este é um projeto open source e sua participação é importante.

### Como Contribuir

1. **Fork** o repositório
2. **Clone** seu fork
3. Crie uma **branch** para sua feature (`git checkout -b feature/AmazingFeature`)
4. **Commit** suas mudanças (`git commit -m 'Add some AmazingFeature'`)
5. **Push** para a branch (`git push origin feature/AmazingFeature`)
6. Abra um **Pull Request**

### Diretrizes

- Siga o estilo de código existente
- Adicione comentários em código complexo
- Atualize a documentação conforme necessário
- Teste suas mudanças antes de submeter
- Um PR por feature/fix

### Áreas para Contribuição

- 🐛 **Bug fixes** e correções
- ✨ **Novas features** e melhorias
- 📖 **Documentação** e exemplos
- 🌍 **Traduções** para outros idiomas
- 🧪 **Testes** e validações
- 🎨 **UI/UX** dos relatórios

### Reportar Issues

Ao reportar problemas, inclua:

- Versão do Informix
- Sistema operacional
- Versão do HealthCheck
- Logs de erro
- Passos para reproduzir

---

## 📄 Licença

Este projeto está licenciado sob a **GNU General Public License v3.0**.

Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

```
Copyright (C) 2024 HealthCheck_Informix Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

---

## 📞 Suporte

### Documentação

- 📖 [README.md](README.md) - Este arquivo
- 📋 [config/healthcheck.json](config/healthcheck.json) - Configuração completa
- 💡 [Wiki](https://github.com/yourusername/HealthCheck_Informix/wiki) - Guias e tutoriais

### Comunidade

- 🐛 [Issues](https://github.com/yourusername/HealthCheck_Informix/issues) - Reportar bugs
- 💬 [Discussions](https://github.com/yourusername/HealthCheck_Informix/discussions) - Discussões
- 📧 Email: support@yourdomain.com

---

## 🎉 Agradecimentos

- IBM Informix Team pela documentação
- Comunidade Open Source
- Todos os contribuidores do projeto
- DBAs que testaram e forneceram feedback

---

## 🗺️ Roadmap

### v2.1 (Próxima Release)
- [ ] Dashboard web em tempo real
- [ ] API REST para integração
- [ ] Suporte a container (Docker/Kubernetes)
- [ ] Alertas via WhatsApp/Telegram
- [ ] Machine Learning para previsão de problemas

### v2.2 (Futuro)
- [ ] Suporte a múltiplos bancos (PostgreSQL, Oracle)
- [ ] Interface gráfica web (Vue.js/React)
- [ ] Autenticação e controle de acesso
- [ ] Relatórios comparativos entre ambientes
- [ ] Integração com ferramentas de monitoramento (Grafana, Prometheus)

---

<div align="center">

**Feito com ❤️ para a comunidade Informix**

[⬆ Voltar ao topo](#-informix-healthcheck-v20)

</div>
