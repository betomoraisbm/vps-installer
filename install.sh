#!/bin/bash

# ============================================
# VARIÁVEIS GLOBAIS
# ============================================
POSTGRES_PASSWORD="admin@2026"
REDIS_PASSWORD="admin@2026"
MINIO_USER="admin"
MINIO_PASSWORD="admin@2026"
NETWORK_NAME="docker_admin"
COMPOSE_PROJECT_NAME="vps"

# ============================================
# CORES
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# FUNÇÕES UTILITÁRIAS
# ============================================
show_banner() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   VPS INSTALLER - BETO MORAIS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

write_step() {
    local message=$1
    local status=$2
    case $status in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
        "OK")    echo -e "${GREEN}[OK]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SKIP")  echo -e "${YELLOW}[SKIP]${NC} $message" ;;
    esac
}

create_network() {
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        docker network create "$NETWORK_NAME" &>/dev/null || true
    fi
}

# ============================================
# MENU PRINCIPAL
# ============================================
show_menu() {
    show_banner
    echo -e "${CYAN}[MENU PRINCIPAL]${NC}"
    echo -e "========================================"
    echo -e "1 - INSTALAR TUDO (Docker + Portainer + NPM + PG + Redis + MinIO)"
    echo -e "2 - Instalar Docker"
    echo -e "3 - Instalar PostgreSQL"
    echo -e "4 - Instalar Redis"
    echo -e "5 - Instalar MinIO"
    echo -e "6 - Instalar Nginx Proxy Manager"
    echo -e "7 - Instalar Portainer"
    echo -e "8 - Instalar Typebot"
    echo -e "9 - Instalar N8N"
    echo -e "10 - Instalar Evolution API"
    echo -e "11 - Instalar Wuzapi"
    echo -e "12 - Instalar OpenClaw"
    echo -e "13 - Ver Status"
    echo -e "0 - Sair"
    echo -e ""
    echo -e "========================================"
}

# ============================================
# INSTALAR DOCKER
# ============================================
install_docker() {
    show_banner
    echo -e "${CYAN}[DOCKER]${NC}"
    echo -e "========================================"
    echo ""

    if docker --version &>/dev/null; then
        write_step "Docker já está instalado: $(docker --version)" "SKIP"
        return
    fi

    write_step "Atualizando sistema..." "INFO"
    apt-get update -qq

    write_step "Instalando dependências..." "INFO"
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    write_step "Adicionando repositório Docker..." "INFO"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    write_step "Instalando Docker..." "INFO"
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    write_step "Docker instalado: $(docker --version)" "OK"
}

# ============================================
# INSTALAR POSTGRESQL
# ============================================
install_postgres() {
    show_banner
    echo -e "${CYAN}[POSTGRESQL]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^postgres$"; then
        write_step "PostgreSQL já existe!" "SKIP"
        return
    fi

    create_network

    write_step "Criando volume para PostgreSQL..." "INFO"
    docker volume create postgres_data &>/dev/null || true

    write_step "Instalando PostgreSQL 15..." "INFO"
    docker run -d \
        --name postgres \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB=app \
        -v postgres_data:/var/lib/postgresql/data \
        postgres:15-alpine

    write_step "Aguardando PostgreSQL iniciar..." "INFO"
    sleep 5

    write_step "PostgreSQL instalado!" "OK"
    echo "  Host: postgres"
    echo "  Porta: 5432"
    echo "  Database: app"
    echo "  Senha: $POSTGRES_PASSWORD"
}

# ============================================
# INSTALAR REDIS
# ============================================
install_redis() {
    show_banner
    echo -e "${CYAN}[REDIS]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^redis$"; then
        write_step "Redis já existe!" "SKIP"
        return
    fi

    create_network

    write_step "Criando volume para Redis..." "INFO"
    docker volume create redis_data &>/dev/null || true

    write_step "Instalando Redis 7..." "INFO"
    docker run -d \
        --name redis \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 6379:6379 \
        -v redis_data:/data \
        redis:7-alpine \
        redis-server --requirepass "$REDIS_PASSWORD"

    write_step "Redis instalado!" "OK"
    echo "  Host: redis"
    echo "  Porta: 6379"
    echo "  Senha: $REDIS_PASSWORD"
}

# ============================================
# INSTALAR MINIO
# ============================================
install_minio() {
    show_banner
    echo -e "${CYAN}[MINIO]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^minio$"; then
        write_step "MinIO já existe!" "SKIP"
        return
    fi

    create_network

    write_step "Criando volume para MinIO..." "INFO"
    docker volume create minio_data &>/dev/null || true

    write_step "Instalando MinIO..." "INFO"
    docker run -d \
        --name minio \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 9002:9002 \
        -p 9003:9003 \
        -e MINIO_ROOT_USER="$MINIO_USER" \
        -e MINIO_ROOT_PASSWORD="$MINIO_PASSWORD" \
        -v minio_data:/data \
        minio/minio:latest \
        server /data --console-address ":9003"

    write_step "Aguardando MinIO iniciar..." "INFO"
    sleep 5

    write_step "MinIO instalado!" "OK"
    echo "  Console: http://localhost:9003"
    echo "  API: http://localhost:9002"
    echo "  Usuário: $MINIO_USER"
    echo "  Senha: $MINIO_PASSWORD"
}

# ============================================
# INSTALAR NGINX PROXY MANAGER
# ============================================
install_npm() {
    show_banner
    echo -e "${CYAN}[NGINX PROXY MANAGER]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^npm$"; then
        write_step "NPM já existe!" "SKIP"
        return
    fi

    create_network

    write_step "Criando volume para NPM..." "INFO"
    docker volume create npm_data &>/dev/null || true

    write_step "Instalando Nginx Proxy Manager..." "INFO"
    docker run -d \
        --name npm \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 80:80 \
        -p 443:443 \
        -p 81:81 \
        -p 444:444 \
        -v npm_data:/data \
        -v npm_letsencrypt:/etc/letsencrypt \
        jc21/nginx-proxy-manager:latest

    write_step "Aguardando NPM iniciar..." "INFO"
    sleep 10

    write_step "Nginx Proxy Manager instalado!" "OK"
    echo "  URL: http://localhost:81"
    echo "  Login: admin@example.com"
    echo "  Senha: changeme"
}

# ============================================
# CONFIGURAR PROXY HOST NO NPM
# ============================================
configure_proxy_host() {
    local domain=$1
    local target_host=$2
    local target_port=$3
    local max_attempts=5
    local attempt=1

    write_step "Configurando Proxy Host no NPM..." "INFO"

    local email="admin@example.com"
    local password="changeme"
    local npm_api="http://localhost:81"

    while [ $attempt -le $max_attempts ]; do
        local token=$(curl -s -X POST "$npm_api/api/tokens" \
            -H "Content-Type: application/json" \
            -d "{\"identity\":\"$email\",\"secret\":\"$password\"}" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$token" ]; then
            curl -s -X POST "$npm_api/api/proxy-hosts" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -d "{\"domain_names\":[\"$domain\"],\"forward_scheme\":\"http\",\"forward_host\":\"$target_host\",\"forward_port\":$target_port,\"ssl_enabled\":false,\"enabled\":true}"

            write_step "Proxy Host criado: $domain -> $target_host:$target_port" "OK"
            return
        fi

        write_step "Tentativa $attempt/$max_attempts - aguardando NPM..." "WARN"
        sleep 5
        attempt=$((attempt + 1))
    done

    write_step "Não foi possível configurar Proxy Host automaticamente" "ERROR"
}

# ============================================
# INSTALAR PORTAINER
# ============================================
install_portainer() {
    show_banner
    echo -e "${CYAN}[PORTAINER]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        write_step "Portainer já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$PORTAINER_DOMAIN" ]; then
        echo -e "Digite o domínio para o Portainer (ex: portainer.seudominio.com):"
        read -p "Domínio: " PORTAINER_DOMAIN
    fi

    write_step "Criando volume para Portainer..." "INFO"
    docker volume create portainer_data &>/dev/null || true

    write_step "Instalando Portainer..." "INFO"
    docker run -d \
        --name portainer \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 9000:9000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    sleep 5

    configure_proxy_host "$PORTAINER_DOMAIN" "portainer" "9000"

    write_step "Portainer instalado!" "OK"
    echo "  URL: https://$PORTAINER_DOMAIN"
    echo "  Login: admin"
    echo "  Senha: admin@2026"
}

# ============================================
# INSTALAR TYPEBOT
# ============================================
install_typebot() {
    show_banner
    echo -e "${CYAN}[TYPEBOT]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^typebot$"; then
        write_step "Typebot já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$TYPEBOT_DOMAIN" ]; then
        echo -e "Digite o domínio para o Typebot (ex: typebot.seudominio.com):"
        read -p "Domínio: " TYPEBOT_DOMAIN
    fi

    write_step "Criando volume para Typebot..." "INFO"
    docker volume create typebot_data &>/dev/null || true

    write_step "Instalando Typebot..." "INFO"
    docker run -d \
        --name typebot \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3000:3000 \
        -v typebot_data:/app/.data \
        -e DATABASE_URL="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app" \
        -e NEXTAUTH_URL="https://$TYPEBOT_DOMAIN" \
        -e NEXT_PUBLIC_URL="https://$TYPEBOT_DOMAIN" \
        typebot/typebot/latest

    sleep 5

    configure_proxy_host "$TYPEBOT_DOMAIN" "typebot" "3000"

    write_step "Typebot instalado!" "OK"
    echo "  URL: https://$TYPEBOT_DOMAIN"
    echo "  Database: postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app"
}

# ============================================
# INSTALAR N8N
# ============================================
install_n8n() {
    show_banner
    echo -e "${CYAN}[N8N]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^n8n$"; then
        write_step "N8N já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$N8N_DOMAIN" ]; then
        echo -e "Digite o domínio para o N8N (ex: n8n.seudominio.com):"
        read -p "Domínio: " N8N_DOMAIN
    fi

    write_step "Criando volume para N8N..." "INFO"
    docker volume create n8n_data &>/dev/null || true

    write_step "Instalando N8N..." "INFO"
    docker run -d \
        --name n8n \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 5678:5678 \
        -v n8n_data:/home/node/.n8n \
        -e WEBHOOK_URL="https://$N8N_DOMAIN" \
        -e DB_TYPE="postgresdb" \
        -e DB_POSTGRESDB_HOST="postgres" \
        -e DB_POSTGRESDB_PORT="5432" \
        -e DB_POSTGRESDB_DATABASE="app" \
        -e DB_POSTGRESDB_USER="postgres" \
        -e DB_POSTGRESDB_PASSWORD="$POSTGRES_PASSWORD" \
        n8nio/n8n:latest

    sleep 5

    configure_proxy_host "$N8N_DOMAIN" "n8n" "5678"

    write_step "N8N instalado!" "OK"
    echo "  URL: https://$N8N_DOMAIN"
    echo "  Database: postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app"
}

# ============================================
# INSTALAR EVOLUTION API
# ============================================
install_evolution() {
    show_banner
    echo -e "${CYAN}[EVOLUTION API]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^evolution$"; then
        write_step "Evolution API já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$EVOLUTION_DOMAIN" ]; then
        echo -e "Digite o domínio para o Evolution API (ex: api.seudominio.com):"
        read -p "Domínio: " EVOLUTION_DOMAIN
    fi

    write_step "Criando volume para Evolution..." "INFO"
    docker volume create evolution_data &>/dev/null || true

    write_step "Instalando Evolution API..." "INFO"
    docker run -d \
        --name evolution \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 8080:8080 \
        -v evolution_data:/evolution/instances \
        atendai/evolution-api:latest

    sleep 5

    configure_proxy_host "$EVOLUTION_DOMAIN" "evolution" "8080"

    write_step "Evolution API instalado!" "OK"
    echo "  URL: https://$EVOLUTION_DOMAIN"
    echo "  Database: postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app"
}

# ============================================
# INSTALAR WUZAPI
# ============================================
install_wuzapi() {
    show_banner
    echo -e "${CYAN}[WUZAPI]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^wuzapi$"; then
        write_step "Wuzapi já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$WUZAPI_DOMAIN" ]; then
        echo -e "Digite o domínio para o Wuzapi (ex: wuzapi.seudominio.com):"
        read -p "Domínio: " WUZAPI_DOMAIN
    fi

    write_step "Criando volume para Wuzapi..." "INFO"
    docker volume create wuzapi_data &>/dev/null || true

    write_step "Instalando Wuzapi..." "INFO"
    docker run -d \
        --name wuzapi \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3001:3000 \
        -v wuzapi_data:/app/data \
        -e DATABASE_URL="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app" \
        -e REDIS_URL="redis://:$REDIS_PASSWORD@redis:6379" \
        wuzapi/wuzapi:latest

    sleep 5

    configure_proxy_host "$WUZAPI_DOMAIN" "wuzapi" "3000"

    write_step "Wuzapi instalado!" "OK"
    echo "  URL: https://$WUZAPI_DOMAIN"
    echo "  Database: postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app"
}

# ============================================
# INSTALAR OPENCLAW
# ============================================
install_openclaw() {
    show_banner
    echo -e "${CYAN}[OPENCLAW]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^openclaw$"; then
        write_step "OpenClaw já existe!" "SKIP"
        return
    fi

    create_network

    if [ -z "$OPENCLAW_DOMAIN" ]; then
        echo -e "Digite o domínio para o OpenClaw (ex: openclaw.seudominio.com):"
        read -p "Domínio: " OPENCLAW_DOMAIN
    fi

    write_step "Criando volume para OpenClaw..." "INFO"
    docker volume create openclaw_data &>/dev/null || true

    write_step "Instalando OpenClaw..." "INFO"
    docker run -d \
        --name openclaw \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3002:3000 \
        -v openclaw_data:/app/data \
        -e DATABASE_URL="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app" \
        -e REDIS_URL="redis://:$REDIS_PASSWORD@redis:6379" \
        openclaw/openclaw:latest

    sleep 5

    configure_proxy_host "$OPENCLAW_DOMAIN" "openclaw" "3000"

    write_step "OpenClaw instalado!" "OK"
    echo "  URL: https://$OPENCLAW_DOMAIN"
    echo "  Database: postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app"
}

# ============================================
# VER STATUS
# ============================================
show_status() {
    show_banner
    echo -e "${CYAN}[STATUS DOS SERVIÇOS]${NC}"
    echo -e "========================================"
    echo ""

    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^(CONTAINER|postgres|redis|minio|npm|portainer|typebot|n8n|evolution|wuzapi|openclaw)" || echo "Nenhum container encontrado"
}

# ============================================
# INSTALAÇÃO COMPLETA
# ============================================
install_all() {
    show_banner
    echo -e "${CYAN}[INSTALAÇÃO COMPLETA]${NC}"
    echo -e "========================================"
    echo ""

    echo -e "${YELLOW}Digitel o dominio para o Portainer (ex: portainer.seudominio.com):${NC}"
    read -p "Domínio: " PORTAINER_DOMAIN
    echo ""

    install_docker
    install_postgres
    install_redis
    install_minio
    install_npm
    install_portainer

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   ACESSOS${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}PostgreSQL:${NC}"
    echo -e "  Host: postgres"
    echo -e "  Porta: 5432"
    echo -e "  Database: app"
    echo -e "  Senha: $POSTGRES_PASSWORD"
    echo ""
    echo -e "${YELLOW}Redis:${NC}"
    echo -e "  Host: redis"
    echo -e "  Porta: 6379"
    echo -e "  Senha: $REDIS_PASSWORD"
    echo ""
    echo -e "${YELLOW}MinIO:${NC}"
    echo -e "  Console: http://localhost:9003"
    echo -e "  API: http://localhost:9002"
    echo -e "  Usuário: $MINIO_USER"
    echo -e "  Senha: $MINIO_PASSWORD"
    echo ""
    echo -e "${YELLOW}Nginx Proxy Manager:${NC}"
    echo -e "  URL: http://localhost:81"
    echo -e "  Login: admin@example.com"
    echo -e "  Senha: changeme"
    echo ""
    echo -e "${YELLOW}Portainer:${NC}"
    echo -e "  URL: https://$PORTAINER_DOMAIN"
    echo -e "  Login: admin"
    echo -e "  Senha: admin@2026"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA!${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    read -p "Pressione ENTER para ver o menu..."
}

# ============================================
# LOOP PRINCIPAL
# ============================================
while true; do
    show_menu
    read -p "Escolha uma opção: " choice
    case $choice in
        1) install_all ;;
        2) install_docker ;;
        3) install_postgres ;;
        4) install_redis ;;
        5) install_minio ;;
        6) install_npm ;;
        7) install_portainer ;;
        8) install_typebot ;;
        9) install_n8n ;;
        10) install_evolution ;;
        11) install_wuzapi ;;
        12) install_openclaw ;;
        13) show_status ;;
        0) echo "Saindo..."; exit 0 ;;
        *) echo -e "${RED}Opção inválida!${NC}" ;;
    esac
    echo ""
done