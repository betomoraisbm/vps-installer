#!/bin/bash

# ============================================
# VARIÁVEIS GLOBAIS
# ============================================
POSTGRES_PASSWORD="admin@2026"
REDIS_PASSWORD="admin@2026"
MINIO_USER="admin"
MINIO_PASSWORD="admin@2026"
EVOLUTION_API_KEY="evolucao_v2_$(openssl rand -hex 16 2>/dev/null || echo $(date +%s%N))"
NETWORK_NAME="docker_admin"
COMPOSE_PROJECT_NAME="vps"
LOG_FILE="/var/log/vps-installer.log"
CADDYFILE="/opt/caddy/Caddyfile"

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
# INICIALIZAÇÃO
# ============================================
init() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo "========================================" | tee -a "$LOG_FILE"
    echo "VPS Installer iniciado em $(date)" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
}

# ============================================
# FUNÇÕES UTILITÁRIAS
# ============================================
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

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
    local timestamp=$(date '+%H:%M:%S')
    case $status in
        "INFO")  echo -e "${BLUE}[$timestamp][INFO]${NC} $message" ;;
        "OK")    echo -e "${GREEN}[$timestamp][OK]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp][WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[$timestamp][ERROR]${NC} $message" ;;
        "SKIP")  echo -e "${YELLOW}[$timestamp][SKIP]${NC} $message" ;;
    esac
    log "[$status] $message"
}

check_error() {
    if [ $? -ne 0 ]; then
        write_step "$1" "ERROR"
        return 1
    fi
    return 0
}

create_network() {
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        write_step "Criando rede $NETWORK_NAME..." "INFO"
        docker network create "$NETWORK_NAME" 2>/dev/null || true
    fi
}

check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1
    fi
    return 0
}

check_resources() {
    local mem=$(free -m | awk '/^Mem:/{print $2}')
    local disk=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4);print $4}')

    write_step "Verificando recursos do sistema..." "INFO"
    write_step "Memória: ${mem}MB | Disco: ${disk}GB" "INFO"

    if [ "$mem" -lt 1800 ]; then
        write_step "Memória insuficiente! Mínimo recomendado: 2GB" "WARN"
    fi

    if [ "$disk" -lt 10 ]; then
        write_step "Disco insuficiente! Mínimo recomendado: 10GB" "WARN"
    fi
}

check_dns() {
    local domain=$1
    local ip=$(curl -s ifconfig.me 2>/dev/null || echo "")

    write_step "Verificando DNS para $domain..." "INFO"
    local domain_ip=$(dig +short "$domain" 2>/dev/null | tail -1)

    if [ -z "$domain_ip" ]; then
        write_step "DNS não configurado para $domain!" "WARN"
        return 1
    fi

    if [ "$domain_ip" = "$ip" ]; then
        write_step "DNS OK: $domain -> $ip" "OK"
        return 0
    else
        write_step "DNS incorreto! Esperado: $ip, Atual: $domain_ip" "WARN"
        return 1
    fi
}

cleanup_failed() {
    local container=$1
    write_step "Limpando container com falha: $container" "WARN"
    docker rm -f "$container" 2>/dev/null || true
}

# ============================================
# MENU PRINCIPAL
# ============================================
show_menu() {
    show_banner
    echo -e "${CYAN}[MENU PRINCIPAL]${NC}"
    echo -e "========================================"
    echo -e "1 - INSTALAR TUDO (Completo)"
    echo -e "2 - Instalar Docker"
    echo -e "3 - Instalar PostgreSQL"
    echo -e "4 - Instalar Redis"
    echo -e "5 - Instalar MinIO"
    echo -e "6 - Instalar Caddy"
    echo -e "7 - Instalar Portainer"
    echo -e "8 - Instalar Typebot"
    echo -e "9 - Instalar N8N"
    echo -e "10 - Instalar Evolution V2"
    echo -e "11 - Instalar Wuzapi"
    echo -e "12 - Instalar OpenClaw"
    echo -e "--------------------------------"
    echo -e "13 - Ver Status"
    echo -e "14 - Ver Logs"
    echo -e "15 - Menu Desinstalação"
    echo -e "0 - Sair"
    echo -e ""
    echo -e "========================================"
}

# ============================================
# MENU DESINSTALAÇÃO
# ============================================
show_uninstall_menu() {
    show_banner
    echo -e "${CYAN}[MENU DESINSTALAÇÃO]${NC}"
    echo -e "========================================"
    echo -e "1 - Desinstalar Evolution V2"
    echo -e "2 - Desinstalar Wuzapi"
    echo -e "3 - Desinstalar OpenClaw"
    echo -e "4 - Desinstalar Typebot"
    echo -e "5 - Desinstalar N8N"
    echo -e "6 - Desinstalar Portainer"
    echo -e "7 - Desinstalar MinIO"
    echo -e "8 - Desinstalar Redis"
    echo -e "9 - Desinstalar PostgreSQL"
    echo -e "10 - Desinstalar Caddy"
    echo -e "11 - Limpar TUDO (CUIDADO!)"
    echo -e "0 - Voltar"
    echo -e ""
    echo -e "========================================"
}

uninstall_container() {
    local container=$1
    local volume=$2

    if docker ps -a | grep -q "$container"; then
        write_step "Removendo $container..." "INFO"
        docker rm -f "$container" 2>/dev/null || true
        if [ -n "$volume" ]; then
            docker volume rm "$volume" 2>/dev/null || true
        fi
        write_step "$container removido!" "OK"
    else
        write_step "$container não existe." "SKIP"
    fi
}

uninstall_evolution_v2() { uninstall_container "evolution_v2" "evolution_v2_data"; sed -i "/bmevoapi/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_wuzapi() { uninstall_container "wuzapi" "wuzapi_data"; sed -i "/wuzapi/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_openclaw() { uninstall_container "openclaw" "openclaw_data"; sed -i "/openclaw/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_typebot() { uninstall_container "typebot" "typebot_data"; sed -i "/typebot/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_n8n() { uninstall_container "n8n" "n8n_data"; sed -i "/n8n/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_portainer() { uninstall_container "portainer" "portainer_data"; sed -i "/portainer/d" "$CADDYFILE" 2>/dev/null || true; }
uninstall_minio() { uninstall_container "minio" "minio_data"; }
uninstall_redis() { uninstall_container "redis" "redis_data"; }
uninstall_postgres() { uninstall_container "postgres" "postgres_data"; }
uninstall_caddy() { uninstall_container "caddy" ""; }

uninstall_all() {
    show_banner
    echo -e "${RED}[ATENÇÃO!]${NC}"
    echo -e "Isso vai remover TODOS os containers e volumes!"
    echo -e "Esta ação NÃO pode ser desfeita!"
    echo ""
    read -p "Tem certeza? Digite 'SIM' para confirmar: " confirm

    if [ "$confirm" != "SIM" ]; then
        write_step "Operação cancelada." "WARN"
        return
    fi

    write_step "Removendo todos os containers..." "WARN"
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    write_step "Removendo todos os volumes..." "WARN"
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    rm -rf /opt/caddy 2>/dev/null || true
    write_step "Sistema limpo!" "OK"
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

    check_resources

    write_step "Atualizando sistema..." "INFO"
    apt-get update -qq || apt-get update

    write_step "Instalando dependências..." "INFO"
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    write_step "Adicionando repositório Docker..." "INFO"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    write_step "Instalando Docker..." "INFO"
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if check_error "Falha ao instalar Docker"; then
        systemctl enable docker 2>/dev/null || true
        write_step "Docker instalado: $(docker --version)" "OK"
    fi
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

    sleep 5

    if docker ps | grep -q "^postgres$"; then
        write_step "PostgreSQL instalado!" "OK"
    else
        cleanup_failed "postgres"
        write_step "Falha ao iniciar PostgreSQL!" "ERROR"
    fi
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

    sleep 5

    if docker ps | grep -q "^redis$"; then
        write_step "Redis instalado!" "OK"
    else
        cleanup_failed "redis"
        write_step "Falha ao iniciar Redis!" "ERROR"
    fi
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

    sleep 5

    if docker ps | grep -q "^minio$"; then
        write_step "MinIO instalado!" "OK"
    else
        cleanup_failed "minio"
        write_step "Falha ao iniciar MinIO!" "ERROR"
    fi
}

# ============================================
# INSTALAR CADDY (PROXY REVERSO)
# ============================================
install_caddy() {
    show_banner
    echo -e "${CYAN}[CADDY]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^caddy$"; then
        write_step "Caddy já existe!" "SKIP"
        return
    fi

    create_network

    write_step "Instalando Caddy..." "INFO"
    mkdir -p /opt/caddy

    cat > "$CADDYFILE" << 'EOF'
:80 {
    respond "Caddy OK"
}
EOF

    docker run -d \
        --name caddy \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 80:80 \
        -p 443:443 \
        -p 443:443/udp \
        -v "$CADDYFILE:/etc/caddy/Caddyfile" \
        -v /opt/caddy/data:/data \
        caddy:latest

    sleep 5

    if docker ps | grep -q "^caddy$"; then
        write_step "Caddy instalado!" "OK"
    else
        cleanup_failed "caddy"
        write_step "Falha ao iniciar Caddy!" "ERROR"
    fi
}

# ============================================
# CONFIGURAR DOMÍNIO NO CADDY
# ============================================
configure_domain_caddy() {
    local domain=$1
    local target_host=$2
    local target_port=$3

    write_step "Configurando $domain -> ${target_host}:${target_port}..." "INFO"

    if [ ! -f "$CADDYFILE" ]; then
        touch "$CADDYFILE"
    fi

    if grep -q "http://$domain" "$CADDYFILE" 2>/dev/null; then
        write_step "Domínio $domain já configurado, atualizando..." "WARN"
        sed -i "/http:\/\/${domain}/,/}/{s/reverse_proxy [^}]*/reverse_proxy ${target_host}:${target_port}/}" "$CADDYFILE"
    else
        cat >> "$CADDYFILE" << EOF
http://${domain} {
    reverse_proxy ${target_host}:${target_port}
}
EOF
    fi

    docker exec caddy caddy reload --config "$CADDYFILE" --adapter caddyfile 2>/dev/null || true
    sleep 2
    write_step "Domínio $domain configurado!" "OK"
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

    if docker ps | grep -q "^portainer$"; then
        write_step "Portainer instalado!" "OK"
    else
        cleanup_failed "portainer"
        write_step "Falha ao iniciar Portainer!" "ERROR"
    fi
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

    echo -e "Escolha a versão do Typebot:"
    echo -e "  1) latest"
    echo -e "  2) 2.20.0"
    echo -e "  3) 2.21.0"
    echo -e "  4) 2.22.0"
    echo -e "  5) 2.23.0"
    read -p "Versão [1]: " TYPEBOT_VERSION_CHOICE
    case $TYPEBOT_VERSION_CHOICE in
        2) TYPEBOT_VERSION="2.20.0" ;;
        3) TYPEBOT_VERSION="2.21.0" ;;
        4) TYPEBOT_VERSION="2.22.0" ;;
        5) TYPEBOT_VERSION="2.23.0" ;;
        *) TYPEBOT_VERSION="latest" ;;
    esac

    check_dns "$TYPEBOT_DOMAIN" || write_step "Continuando mesmo assim..." "WARN"

    write_step "Criando volume para Typebot..." "INFO"
    docker volume create typebot_data &>/dev/null || true

    write_step "Instalando Typebot $TYPEBOT_VERSION..." "INFO"
    docker run -d \
        --name typebot \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3000:3000 \
        -v typebot_data:/app/.data \
        -e DATABASE_URL="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app" \
        -e NEXTAUTH_URL="https://$TYPEBOT_DOMAIN" \
        -e NEXT_PUBLIC_URL="https://$TYPEBOT_DOMAIN" \
        typebot/typebot:$TYPEBOT_VERSION

    sleep 5

    if docker ps | grep -q "^typebot$"; then
        configure_domain_caddy "$TYPEBOT_DOMAIN" "typebot" "3000"
        write_step "Typebot instalado!" "OK"
    else
        cleanup_failed "typebot"
        write_step "Falha ao iniciar Typebot!" "ERROR"
    fi
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

    echo -e "Escolha a versão do N8N:"
    echo -e "  1) latest"
    echo -e "  2) 1.65.0"
    echo -e "  3) 1.70.0"
    echo -e "  4) 1.75.0"
    echo -e "  5) 1.80.0"
    read -p "Versão [1]: " N8N_VERSION_CHOICE
    case $N8N_VERSION_CHOICE in
        2) N8N_VERSION="1.65.0" ;;
        3) N8N_VERSION="1.70.0" ;;
        4) N8N_VERSION="1.75.0" ;;
        5) N8N_VERSION="1.80.0" ;;
        *) N8N_VERSION="latest" ;;
    esac

    check_dns "$N8N_DOMAIN" || write_step "Continuando mesmo assim..." "WARN"

    write_step "Criando volume para N8N..." "INFO"
    docker volume create n8n_data &>/dev/null || true

    write_step "Instalando N8N $N8N_VERSION..." "INFO"
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
        n8nio/n8n:$N8N_VERSION

    sleep 5

    if docker ps | grep -q "^n8n$"; then
        configure_domain_caddy "$N8N_DOMAIN" "n8n" "5678"
        write_step "N8N instalado!" "OK"
    else
        cleanup_failed "n8n"
        write_step "Falha ao iniciar N8N!" "ERROR"
    fi
}

# ============================================
# INSTALAR EVOLUTION V2
# ============================================
install_evolution_v2() {
    show_banner
    echo -e "${CYAN}[EVOLUTION V2]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^evolution_v2$"; then
        write_step "Evolution V2 já existe!" "SKIP"
        return
    fi

    if ! docker ps | grep -q "^postgres$"; then
        write_step "PostgreSQL não está rodando!" "ERROR"
        return
    fi

    if ! docker ps | grep -q "^redis$"; then
        write_step "Redis não está rodando!" "ERROR"
        return
    fi

    if ! docker ps | grep -q "^minio$"; then
        write_step "MinIO não está rodando!" "ERROR"
        return
    fi

    create_network

    if [ -z "$EVOLUTION_DOMAIN" ]; then
        echo -e "Digite o domínio para o Evolution V2 (ex: evo.seudominio.com):"
        read -p "Domínio: " EVOLUTION_DOMAIN
    fi

    check_dns "$EVOLUTION_DOMAIN" || write_step "Continuando mesmo assim..." "WARN"

    write_step "Criando bucket no MinIO..." "INFO"
    docker exec minio mc mb minio/evolution --force 2>/dev/null || true
    docker exec minio mc anonymous set download minio/evolution 2>/dev/null || true

    write_step "Criando volume para Evolution V2..." "INFO"
    docker volume create evolution_v2_data &>/dev/null || true

    echo -e "Escolha a versão do Evolution V2:"
    echo -e "  1) v2.3.7 (recommended)"
    echo -e "  2) v2.4.0"
    echo -e "  3) v2.5.0"
    echo -e "  4) v2.6.0"
    read -p "Versão [1]: " EVOLUTION_VERSION_CHOICE
    case $EVOLUTION_VERSION_CHOICE in
        2) EVOLUTION_VERSION="v2.4.0" ;;
        3) EVOLUTION_VERSION="v2.5.0" ;;
        4) EVOLUTION_VERSION="v2.6.0" ;;
        *) EVOLUTION_VERSION="v2.3.7" ;;
    esac

    write_step "Instalando Evolution V2 $EVOLUTION_VERSION..." "INFO"
    docker run -d \
        --name evolution_v2 \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 8081:8080 \
        -e AUTHENTICATION_API_KEY="$EVOLUTION_API_KEY" \
        -e AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES="true" \
        -e CACHE_LOCAL_ENABLED="false" \
        -e CACHE_REDIS_ENABLED="true" \
        -e CACHE_REDIS_PREFIX_KEY="evolution_v2" \
        -e CACHE_REDIS_SAVE_INSTANCES="false" \
        -e CACHE_REDIS_URI="redis://:$REDIS_PASSWORD@redis:6379/1" \
        -e DATABASE_ENABLED="true" \
        -e DATABASE_PROVIDER="postgresql" \
        -e DATABASE_CONNECTION_CLIENT_NAME="evolution_v2" \
        -e DATABASE_CONNECTION_URI="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/evolution" \
        -e S3_ENABLED="true" \
        -e S3_BUCKET="evolution" \
        -e S3_ACCESS_KEY="$MINIO_USER" \
        -e S3_SECRET_KEY="$MINIO_PASSWORD" \
        -e S3_ENDPOINT="minio" \
        -e S3_PORT="9000" \
        -e S3_USE_SSL="false" \
        -e LANGUAGE="pt-br" \
        -e QRCODE_COLOR="#175197" \
        -e QRCODE_LIMIT="30" \
        -e LOG_BAILEYS="error" \
        -e LOG_LEVEL="ERROR" \
        -e SERVER_URL="http://$EVOLUTION_DOMAIN" \
        -e TELEMETRY="false" \
        -e WEBSOCKET_ENABLED="true" \
        -v evolution_v2_data:/evolution/instances \
        evoapicloud/evolution-api:$EVOLUTION_VERSION

    sleep 10

    if docker ps | grep -q "^evolution_v2$"; then
        docker network connect "$NETWORK_NAME" evolution_v2 2>/dev/null || true
        configure_domain_caddy "$EVOLUTION_DOMAIN" "evolution_v2" "8080"
        write_step "Evolution V2 instalado!" "OK"
        echo ""
        echo -e "${YELLOW}ACESSOS:${NC}"
        echo "  URL: http://$EVOLUTION_DOMAIN"
        echo "  API Key: $EVOLUTION_API_KEY"
    else
        cleanup_failed "evolution_v2"
        write_step "Falha ao iniciar Evolution V2!" "ERROR"
    fi
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

    echo -e "Escolha a versão do Wuzapi:"
    echo -e "  1) latest"
    echo -e "  2) 2.5.0"
    echo -e "  3) 2.6.0"
    echo -e "  4) 2.7.0"
    echo -e "  5) 2.8.0"
    read -p "Versão [1]: " WUZAPI_VERSION_CHOICE
    case $WUZAPI_VERSION_CHOICE in
        2) WUZAPI_VERSION="2.5.0" ;;
        3) WUZAPI_VERSION="2.6.0" ;;
        4) WUZAPI_VERSION="2.7.0" ;;
        5) WUZAPI_VERSION="2.8.0" ;;
        *) WUZAPI_VERSION="latest" ;;
    esac

    check_dns "$WUZAPI_DOMAIN" || write_step "Continuando mesmo assim..." "WARN"

    write_step "Criando volume para Wuzapi..." "INFO"
    docker volume create wuzapi_data &>/dev/null || true

    write_step "Instalando Wuzapi $WUZAPI_VERSION..." "INFO"
    docker run -d \
        --name wuzapi \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3001:3000 \
        -v wuzapi_data:/app/data \
        -e DATABASE_URL="postgresql://postgres:$POSTGRES_PASSWORD@postgres:5432/app" \
        -e REDIS_URL="redis://:$REDIS_PASSWORD@redis:6379" \
        wuzapi/wuzapi:$WUZAPI_VERSION

    sleep 5

    if docker ps | grep -q "^wuzapi$"; then
        configure_domain_caddy "$WUZAPI_DOMAIN" "wuzapi" "3000"
        write_step "Wuzapi instalado!" "OK"
    else
        cleanup_failed "wuzapi"
        write_step "Falha ao iniciar Wuzapi!" "ERROR"
    fi
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

    check_dns "$OPENCLAW_DOMAIN" || write_step "Continuando mesmo assim..." "WARN"

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

    if docker ps | grep -q "^openclaw$"; then
        configure_domain_caddy "$OPENCLAW_DOMAIN" "openclaw" "3000"
        write_step "OpenClaw instalado!" "OK"
    else
        cleanup_failed "openclaw"
        write_step "Falha ao iniciar OpenClaw!" "ERROR"
    fi
}

# ============================================
# VER STATUS
# ============================================
show_status() {
    show_banner
    echo -e "${CYAN}[STATUS DOS SERVIÇOS]${NC}"
    echo -e "========================================"
    echo ""

    if command -v ss &>/dev/null; then
        echo -e "${YELLOW}Portas em uso:${NC}"
        ss -tlnp 2>/dev/null | grep -E "(9000|9002|9003|5432|6379|80|443|8081|3000|3001|3002|5678)" || echo "Nenhuma porta encontrada"
        echo ""
    fi

    echo -e "${YELLOW}Containers:${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^(CONTAINER|postgres|redis|minio|caddy|portainer|typebot|n8n|evolution|wuzapi|openclaw)" || echo "Nenhum container encontrado"
    echo ""

    if [ -f "$CADDYFILE" ]; then
        echo -e "${YELLOW}Caddyfile:${NC}"
        cat "$CADDYFILE"
        echo ""
    fi
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        echo "Nenhum log encontrado"
    fi
}

# ============================================
# INSTALAÇÃO COMPLETA
# ============================================
install_all() {
    show_banner
    echo -e "${CYAN}[INSTALAÇÃO COMPLETA]${NC}"
    echo -e "========================================"
    echo ""

    check_resources

    echo -e "${YELLOW}Digite o domínio para o Portainer (ex: portainer.seudominio.com):${NC}"
    read -p "Domínio: " PORTAINER_DOMAIN
    echo ""

    install_docker
    install_postgres
    install_redis
    install_minio
    install_caddy
    install_portainer

    sleep 3
    configure_domain_caddy "$PORTAINER_DOMAIN" "portainer" "9000"

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
    echo -e "${YELLOW}Caddy (Proxy Reverso):${NC}"
    echo -e "  URL: http://$PORTAINER_DOMAIN"
    echo ""
    echo -e "${YELLOW}Portainer:${NC}"
    echo -e "  URL: http://$PORTAINER_DOMAIN"
    echo -e "  Login: admin"
    echo -e "  Senha: admin@2026"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${GREEN}INSTALAÇÃO CONCLUÍDA!${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Logs salvos em: $LOG_FILE${NC}"
    echo ""
    read -p "Pressione ENTER para ver o menu..."
}

# ============================================
# UNINSTALL LOOP
# ============================================
uninstall_loop() {
    while true; do
        show_uninstall_menu
        read -p "Escolha uma opção: " choice
        case $choice in
            1) uninstall_evolution_v2 ;;
            2) uninstall_wuzapi ;;
            3) uninstall_openclaw ;;
            4) uninstall_typebot ;;
            5) uninstall_n8n ;;
            6) uninstall_portainer ;;
            7) uninstall_minio ;;
            8) uninstall_redis ;;
            9) uninstall_postgres ;;
            10) uninstall_caddy ;;
            11) uninstall_all ;;
            0) break ;;
            *) echo -e "${RED}Opção inválida!${NC}" ;;
        esac
        echo ""
        read -p "Pressione ENTER para continuar..."
    done
}

# ============================================
# LOOP PRINCIPAL
# ============================================
init
while true; do
    show_menu
    read -p "Escolha uma opção: " choice
    case $choice in
        1) install_all ;;
        2) install_docker ;;
        3) install_postgres ;;
        4) install_redis ;;
        5) install_minio ;;
        6) install_caddy ;;
        7) install_portainer ;;
        8) install_typebot ;;
        9) install_n8n ;;
        10) install_evolution_v2 ;;
        11) install_wuzapi ;;
        12) install_openclaw ;;
        13) show_status ;;
        14) show_logs ;;
        15) uninstall_loop ;;
        0) echo "Saindo..."; exit 0 ;;
        *) echo -e "${RED}Opção inválida!${NC}" ;;
    esac
    echo ""
done