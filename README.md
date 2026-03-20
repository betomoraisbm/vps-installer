# VPS Installer - BETO MORAIS

Instalador automatizado para VPS com Docker, Portainer e aplicações.

## Sistemas Suportados

- **Ubuntu 24.04** (Hetzner e outros provedores)
- **Windows Server** (com Docker Desktop)

## Aplicações Incluídas

### Infraestrutura
- Docker
- PostgreSQL 15
- Redis 7
- MinIO (Storage)
- Nginx Proxy Manager (SSL automático)
- Portainer (Gerenciamento Docker)

### Aplicações
- Typebot
- N8N
- Evolution API
- Wuzapi
- OpenClaw

## Como Usar

### Ubuntu 24.04

1. Clone o repositório no VPS:
```bash
git clone https://github.com/seu-usuario/vps-installer.git
cd vps-installer
```

2. Torne o script executável:
```bash
chmod +x install.sh
```

3. Execute:
```bash
./install.sh
```

4. Siga o menu:
   - **1-6**: Instalar infraestrutura (Docker, PostgreSQL, Redis, MinIO, Nginx Proxy Manager, Portainer)
   - **7-11**: Instalar aplicações (Typebot, N8N, Evolution API, Wuzapi, OpenClaw)
   - **12**: Ver status dos serviços

### Windows Server

1. Copie o script para o servidor
2. Execute no PowerShell como Administrador:
```powershell
.\install-docker-portainer.ps1
```

## Acesso aos Serviços

| Serviço | URL |
|---------|-----|
| Portainer | http://localhost:9000 |
| Nginx Admin | http://localhost:81 |
| MinIO Console | http://localhost:9001 |
| Typebot | http://localhost:3000 |
| N8N | http://localhost:5678 |
| Evolution API | http://localhost:8080 |
| Wuzapi | http://localhost:3001 |
| OpenClaw | http://localhost:3002 |

## Configuração de Domínio

1. No script, quando solicitado, informe o domínio:
   - Exemplo: `typebot.seudominio.com`
2. Após a instalação, configure o Nginx Proxy Manager:
   - Acesse `http://IP_DO_VPS:81`
   - Login: `admin@example.com` / Senha: `changeme`
   - Crie um Proxy Host apontando para o serviço

## Senhas Padrão

| Serviço | Senha |
|---------|-------|
| PostgreSQL | BetoM2025!? |
| Redis | BetoR2025!? |
| MinIO | BetoM2025!? |
| Nginx Proxy Manager | changeme (mude!) |

## Requisitos Mínimos

- 4GB RAM (8GB recomendado)
- 40GB disco
- Ubuntu 24.04 ou Windows Server 2019/2022

## Rede Docker

Todos os containers usam a rede `docker_beto` para comunicação interna.

## Suporte

Para problemas, verifique os logs:
```bash
docker logs nome_do_container
```

## Licença

BETO MORAIS - Todos os direitos reservados
