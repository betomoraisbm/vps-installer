# ============================================
# SCRIPT DE VERIFICACAO E ATUALIZACAO
# Docker & Portainer VPS
# ============================================

$ErrorActionPreference = "Continue"

function Show-Banner {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       BETO MORAIS                   " -ForegroundColor Cyan
    Write-Host "   VERIFICACAO E ATUALIZACAO          " -ForegroundColor Cyan
    Write-Host "   Docker & Portainer VPS Installer    " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-DockerVersion {
    try {
        $version = docker --version 2>$null
        if ($version) {
            return $version.Split(",")[0].Replace("Docker version ", "")
        }
    }
    catch {}
    return $null
}

function Get-DockerComposeVersion {
    try {
        $version = docker-compose --version 2>$null
        if ($version) {
            return $version.Split(",")[0].Replace("Docker Compose version ", "")
        }
    }
    catch {}
    return $null
}

function Get-PortainerVersion {
    try {
        $image = docker images portainer/portainer-ce:latest --format "{{.Tag}}"
        if ($image) {
            return $image
        }
    }
    catch {}
    return $null
}

function Get-ContainerStatus {
    param([string]$Name)

    try {
        $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $Name }
        if ($running) {
            $info = docker ps --filter "name=$Name" --format "{{.Status}}"
            return @{ Status = "Rodando"; Info = $info }
        }

        $stopped = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $Name }
        if ($stopped) {
            $info = docker ps -a --filter "name=$Name" --format "{{.Status}}"
            return @{ Status = "Parado"; Info = $info }
        }

        return @{ Status = "Nao existe"; Info = "" }
    }
    catch {
        return @{ Status = "Erro"; Info = $_.Exception.Message }
    }
}

function Get-LatestDockerVersion {
    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/repos/docker/docker-ce/releases/latest" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $json = $response.Content | ConvertFrom-Json
            return $json.tag_name -replace "v", ""
        }
    }
    catch {}
    return $null
}

function Get-LatestDockerComposeVersion {
    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/repos/docker/compose/releases/latest" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $json = $response.Content | ConvertFrom-Json
            return $json.tag_name -replace "v", ""
        }
    }
    catch {}
    return $null
}

function Get-LatestPortainerVersion {
    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/repos/portainer/portainer/releases/latest" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $json = $response.Content | ConvertFrom-Json
            return $json.tag_name -replace "v", ""
        }
    }
    catch {}
    return $null
}

function Show-SystemInfo {
    Write-Host "[INFORMACOES DO SISTEMA]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "  SO: " -NoNewline
    Write-Host (Get-CimInstance Win32_OperatingSystem).Caption -ForegroundColor Green
    Write-Host "  Hostname: " -NoNewline
    Write-Host $env:COMPUTERNAME -ForegroundColor Green
    Write-Host "  Arquitetura: " -NoNewline
    Write-Host $env:PROCESSOR_ARCHITECTURE -ForegroundColor Green
    Write-Host "  Memoria Total: " -NoNewline
    $mem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Write-Host "$mem GB" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-DockerInfo {
    Write-Host "[DOCKER]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    if (Test-CommandExists "docker") {
        $installed = Get-DockerVersion
        $latest = Get-LatestDockerVersion

        Write-Host "  Status: " -NoNewline
        Write-Host "INSTALADO" -ForegroundColor Green

        Write-Host "  Versao atual: " -NoNewline
        Write-Host $installed -ForegroundColor Yellow

        Write-Host "  Versao mais recente: " -NoNewline
        if ($latest) {
            Write-Host $latest -ForegroundColor Cyan
            if ($installed -ne $latest) {
                Write-Host "  Atualizacao disponivel!" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Nao verificado" -ForegroundColor Gray
        }

        Write-Host "  Info: " -NoNewline
        docker version --format "{{.Server.Version}}" 2>$null | ForEach-Object {
            Write-Host "Server $_" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  Status: " -NoNewline
        Write-Host "NAO INSTALADO" -ForegroundColor Red
    }
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-DockerComposeInfo {
    Write-Host "[DOCKER COMPOSE]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    if (Test-CommandExists "docker-compose") {
        $installed = Get-DockerComposeVersion
        $latest = Get-LatestDockerComposeVersion

        Write-Host "  Status: " -NoNewline
        Write-Host "INSTALADO" -ForegroundColor Green

        Write-Host "  Versao atual: " -NoNewline
        Write-Host $installed -ForegroundColor Yellow

        Write-Host "  Versao mais recente: " -NoNewline
        if ($latest) {
            Write-Host $latest -ForegroundColor Cyan
        }
        else {
            Write-Host "Nao verificado" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  Status: " -NoNewline
        Write-Host "NAO INSTALADO" -ForegroundColor Red
    }
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-PortainerInfo {
    Write-Host "[PORTAINER]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    $status = Get-ContainerStatus "portainer"

    Write-Host "  Status: " -NoNewline
    switch ($status.Status) {
        "Rodando" { Write-Host $status.Status -ForegroundColor Green }
        "Parado" { Write-Host $status.Status -ForegroundColor Yellow }
        default { Write-Host $status.Status -ForegroundColor Red }
    }

    if ($status.Info) {
        Write-Host "  Info: $($status.Info)" -ForegroundColor Gray
    }

    $localVersion = Get-PortainerVersion
    $latestVersion = Get-LatestPortainerVersion

    if ($localVersion) {
        Write-Host "  Versao local: " -NoNewline
        Write-Host $localVersion -ForegroundColor Yellow
    }

    if ($latestVersion) {
        Write-Host "  Versao mais recente: " -NoNewline
        Write-Host $latestVersion -ForegroundColor Cyan
    }

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-NginxProxyInfo {
    Write-Host "[NGINX PROXY]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    $status = Get-ContainerStatus "nginx-proxy"

    Write-Host "  Status: " -NoNewline
    switch ($status.Status) {
        "Rodando" { Write-Host $status.Status -ForegroundColor Green }
        "Parado" { Write-Host $status.Status -ForegroundColor Yellow }
        "Nao existe" { Write-Host "Nao instalado" -ForegroundColor Gray }
        default { Write-Host $status.Status -ForegroundColor Red }
    }

    if ($status.Info) {
        Write-Host "  Info: $($status.Info)" -ForegroundColor Gray
    }
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ContainerList {
    Write-Host "[TODOS OS CONTAINERS]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    try {
        $containers = docker ps -a --format "{{.Names}} - {{.Status}}"
        if ($containers) {
            $containers | ForEach-Object {
                $parts = $_ -split " - "
                $name = $parts[0]
                $info = $parts[1]

                $running = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $name }
                $statusColor = if ($running) { "Green" } else { "Yellow" }

                Write-Host "  $name" -ForegroundColor $statusColor -NoNewline
                Write-Host " - $info" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  Nenhum container encontrado" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Erro ao listar containers" -ForegroundColor Red
    }

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-DiskUsage {
    Write-Host "[USO DE DISCO]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    try {
        $drive = Get-PSDrive C
        $used = [math]::Round(($drive.Used / 1GB), 2)
        $free = [math]::Round(($drive.Free / 1GB), 2)
        $total = $used + $free
        $percentUsed = [math]::Round(($used / $total) * 100, 1)

        Write-Host "  Drive C: " -NoNewline
        Write-Host "${used} GB / ${total} GB usado" -ForegroundColor Yellow
        Write-Host "  Livre: " -NoNewline
        Write-Host "$free GB" -ForegroundColor Green
        Write-Host "  Porcentagem: " -NoNewline
        if ($percentUsed -gt 90) {
            Write-Host "$percentUsed%" -ForegroundColor Red
        }
        elseif ($percentUsed -gt 75) {
            Write-Host "$percentUsed%" -ForegroundColor Yellow
        }
        else {
            Write-Host "$percentUsed%" -ForegroundColor Green
        }

        try {
            $dockerSize = docker system df --format "{{.Size}}" 2>$null
            if ($dockerSize) {
                Write-Host "  Docker disk usage: " -NoNewline
                Write-Host $dockerSize -ForegroundColor Cyan
            }
        }
        catch {}
    }
    catch {
        Write-Host "  Erro ao verificar disco" -ForegroundColor Red
    }

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-NetworkPorts {
    Write-Host "[PORTAS DE REDE]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan

    $ports = @(
        @{ Port = "9000"; Service = "Portainer"; Description = "Interface Web" },
        @{ Port = "8000"; Service = "Portainer"; Description = "Porta Edge Agent" },
        @{ Port = "80"; Service = "Nginx Proxy"; Description = "HTTP" },
        @{ Port = "443"; Service = "Nginx Proxy"; Description = "HTTPS" }
    )

    $ports | ForEach-Object {
        $tcpConnection = Get-NetTCPConnection -LocalPort $_.Port -ErrorAction SilentlyContinue
        $status = if ($tcpConnection) { "Ocupada" } else { "Livre" }
        $statusColor = if ($status -eq "Ocupada") { "Green" } else { "Gray" }

        Write-Host "  $($_.Port)/TCP - $($_.Service)" -ForegroundColor Cyan -NoNewline
        Write-Host " ($($_.Description)): " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
    }

    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Update-Docker {
    Show-Banner
    Write-Host "[ATUALIZANDO DOCKER]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-CommandExists "docker")) {
        Write-Host "[ERRO] Docker nao esta instalado!" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Host "[INFO] Verificando atualizacoes..." -ForegroundColor Yellow
    $latest = Get-LatestDockerVersion
    $current = Get-DockerVersion

    if ($latest -and $current -and $current -ge $latest) {
        Write-Host "[OK] Docker ja esta na versao mais recente!" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Uma nova versao esta disponivel: $latest" -ForegroundColor Cyan
        Write-Host "[INFO] Para atualizar, reinstale o Docker" -ForegroundColor Yellow
    }

    Read-Host "Pressione ENTER para continuar"
}

function Update-DockerCompose {
    Show-Banner
    Write-Host "[ATUALIZANDO DOCKER COMPOSE]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-CommandExists "docker-compose")) {
        Write-Host "[ERRO] Docker Compose nao esta instalado!" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Host "[INFO] Verificando atualizacoes..." -ForegroundColor Yellow
    $latest = Get-LatestDockerComposeVersion
    $current = Get-DockerComposeVersion

    if ($latest -and $current -and $current -ge $latest) {
        Write-Host "[OK] Docker Compose ja esta na versao mais recente!" -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Uma nova versao esta disponivel: $latest" -ForegroundColor Cyan
        Write-Host "[INFO] Para atualizar, baixe do GitHub" -ForegroundColor Yellow
    }

    Read-Host "Pressione ENTER para continuar"
}

function Update-Portainer {
    Show-Banner
    Write-Host "[ATUALIZANDO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    $status = Get-ContainerStatus "portainer"
    if ($status.Status -eq "Nao existe") {
        Write-Host "[ERRO] Portainer nao esta instalado!" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $wasRunning = ($status.Status -eq "Rodando")

    Write-Host "[INFO] Parando Portainer..." -ForegroundColor Yellow
    if ($wasRunning) {
        docker stop portainer
    }

    Write-Host "[INFO] Baixando nova versao..." -ForegroundColor Yellow
    docker pull portainer/portainer-ce:latest

    if ($wasRunning) {
        Write-Host "[INFO] Iniciando Portainer..." -ForegroundColor Yellow
        docker start portainer
        Start-Sleep -Seconds 5
    }

    $newStatus = Get-ContainerStatus "portainer"
    if ($newStatus.Status -eq "Rodando") {
        Write-Host "[OK] Portainer atualizado com sucesso!" -ForegroundColor Green
    }
    else {
        Write-Host "[ERRO] Falha ao atualizar Portainer!" -ForegroundColor Red
    }

    Read-Host "Pressione ENTER para continuar"
}

function Clean-DockerSystem {
    Show-Banner
    Write-Host "[LIMPEZA DO DOCKER]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Isso ira remover:" -ForegroundColor Cyan
    Write-Host "  - Imagens nao utilizadas" -ForegroundColor Gray
    Write-Host "  - Containers parados" -ForegroundColor Gray
    Write-Host "  - Volumes orfaos" -ForegroundColor Gray
    Write-Host "  - Redes nao utilizadas" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Continuar? (SIM para confirmar)"
    if ($confirm -ne "SIM") {
        Write-Host "[INFO] Operacao cancelada!" -ForegroundColor Yellow
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Show-Banner
    Write-Host "[INFO] Executando limpeza..." -ForegroundColor Yellow

    try {
        docker system prune -f --volumes
        Write-Host "[OK] Limpeza concluida!" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERRO] Falha na limpeza: $_" -ForegroundColor Red
    }

    Read-Host "Pressione ENTER para continuar"
}

function Show-Menu {
    Show-Banner
    Show-SystemInfo
    Show-DockerInfo
    Show-DockerComposeInfo
    Show-PortainerInfo
    Show-NginxProxyInfo
    Show-ContainerList
    Show-DiskUsage
    Show-NetworkPorts

    Write-Host "[MENU DE OPCAO]" -ForegroundColor Cyan
    Write-Host "1. Verificar atualizacao do Docker" -ForegroundColor Yellow
    Write-Host "2. Verificar atualizacao do Docker Compose" -ForegroundColor Yellow
    Write-Host "3. Atualizar Portainer" -ForegroundColor Yellow
    Write-Host "4. Limpar sistema Docker" -ForegroundColor Red
    Write-Host "5. Ver todos os servicos novamente" -ForegroundColor Cyan
    Write-Host "0. Sair" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Escolha uma opcao"

        switch ($choice) {
            "1" { Update-Docker }
            "2" { Update-DockerCompose }
            "3" { Update-Portainer }
            "4" { Clean-DockerSystem }
            "5" { }
            "0" {
                Show-Banner
                Write-Host "Obrigado!" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "[ERRO] Opcao invalida!" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

Main
