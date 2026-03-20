# ============================================
# SCRIPT DE TROCA DE DOMINIO
# Docker & Portainer VPS
# ============================================

$ErrorActionPreference = "Continue"

$DomainConfig = @{
    Domain = ""
    Email = ""
    PortainerPort = "9000"
    NginxPort = "80"
    HTTPSPort = "443"
}

function Show-Banner {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       BETO MORAIS                   " -ForegroundColor Cyan
    Write-Host "       TROCA DE DOMINIO                " -ForegroundColor Cyan
    Write-Host "   Docker & Portainer VPS Installer    " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Load-Config {
    $configFile = "$env:ProgramData\DockerVPS\domain.conf"
    if (Test-Path $configFile) {
        $content = Get-Content $configFile
        foreach ($line in $content) {
            if ($line -match "DOMAIN=(.+)") { $DomainConfig.Domain = $matches[1].Trim() }
            if ($line -match "EMAIL=(.+)") { $DomainConfig.Email = $matches[1].Trim() }
            if ($line -match "PORTAINER_PORT=(.+)") { $DomainConfig.PortainerPort = $matches[1].Trim() }
            if ($line -match "NGINX_PORT=(.+)") { $DomainConfig.NginxPort = $matches[1].Trim() }
            if ($line -match "HTTPS_PORT=(.+)") { $DomainConfig.HTTPSPort = $matches[1].Trim() }
        }
        return $true
    }
    return $false
}

function Save-Config {
    $configDir = "$env:ProgramData\DockerVPS"
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $configFile = "$configDir\domain.conf"
    $configContent = @"
DOMAIN=$($DomainConfig.Domain)
EMAIL=$($DomainConfig.Email)
PORTAINER_PORT=$($DomainConfig.PortainerPort)
NGINX_PORT=$($DomainConfig.NginxPort)
HTTPS_PORT=$($DomainConfig.HTTPSPort)
"@
    $configContent | Out-File -FilePath $configFile -Encoding UTF8
}

function Show-CurrentConfig {
    Write-Host "[CONFIGURACAO ATUAL]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "  Dominio: " -NoNewline
    if ($DomainConfig.Domain) {
        Write-Host $DomainConfig.Domain -ForegroundColor Green
    } else {
        Write-Host "Nao configurado" -ForegroundColor Gray
    }
    Write-Host "  Email SSL: " -NoNewline
    if ($DomainConfig.Email) {
        Write-Host $DomainConfig.Email -ForegroundColor Green
    } else {
        Write-Host "Nao configurado" -ForegroundColor Gray
    }
    Write-Host "  Porta Portainer: $($DomainConfig.PortainerPort)"
    Write-Host "  Porta Nginx HTTP: $($DomainConfig.NginxPort)"
    Write-Host "  Porta Nginx HTTPS: $($DomainConfig.HTTPSPort)"
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Set-NewDomain {
    Show-Banner
    Show-CurrentConfig

    Write-Host "[NOVO DOMINIO]" -ForegroundColor Yellow
    Write-Host ""

    $newDomain = Read-Host "Digite o novo dominio (ex: exemplo.com)"
    if (-not $newDomain) {
        Write-Host "[ERRO] Dominio nao pode ser vazio!" -ForegroundColor Red
        return $false
    }

    $email = Read-Host "Digite o email para SSL (ex: admin@exemplo.com)"
    if (-not $email) {
        Write-Host "[ERRO] Email nao pode ser vazio!" -ForegroundColor Red
        return $false
    }

    $DomainConfig.Domain = $newDomain
    $DomainConfig.Email = $email
    Save-Config

    Write-Host ""
    Write-Host "[OK] Dominio atualizado com sucesso!" -ForegroundColor Green
    Write-Host "  Novo dominio: $newDomain" -ForegroundColor Cyan
    Write-Host "  Email: $email" -ForegroundColor Cyan

    return $true
}

function Set-CustomPorts {
    Show-Banner
    Show-CurrentConfig

    Write-Host "[PORTAS PERSONALIZADAS]" -ForegroundColor Yellow
    Write-Host ""

    $portainerPort = Read-Host "Porta do Portainer (default: $($DomainConfig.PortainerPort))"
    $nginxHttp = Read-Host "Porta Nginx HTTP (default: $($DomainConfig.NginxPort))"
    $nginxHttps = Read-Host "Porta Nginx HTTPS (default: $($DomainConfig.HTTPSPort))"

    if ($portainerPort) { $DomainConfig.PortainerPort = $portainerPort }
    if ($nginxHttp) { $DomainConfig.NginxPort = $nginxHttp }
    if ($nginxHttps) { $DomainConfig.HTTPSPort = $nginxHttps }

    Save-Config

    Write-Host ""
    Write-Host "[OK] Portas atualizadas!" -ForegroundColor Green
    return $true
}

function Reset-Config {
    Show-Banner
    Write-Host "[REMOVER CONFIGURACAO]" -ForegroundColor Red
    Write-Host ""
    Write-Host "Isso ira remover toda a configuracao de dominio." -ForegroundColor Yellow
    Write-Host "ATENCAO: Os containers continuarao rodando." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Tem certeza? (SIM para confirmar)"
    if ($confirm -eq "SIM") {
        $DomainConfig.Domain = ""
        $DomainConfig.Email = ""
        Save-Config
        Write-Host "[OK] Configuracao removida!" -ForegroundColor Green
        return $true
    }

    Write-Host "[INFO] Operacao cancelada!" -ForegroundColor Yellow
    return $false
}

function Test-DomainPropagation {
    param([string]$domain)

    Write-Host ""
    Write-Host "[TESTANDO PROPAGACAO DNS]" -ForegroundColor Yellow
    Write-Host "Dominio: $domain" -ForegroundColor Cyan
    Write-Host ""

    try {
        $ips = @()
        $dnsResults = Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue
        if ($dnsResults) {
            $ips = $dnsResults | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress
        }

        if ($ips) {
            Write-Host "[OK] DNS propagado para:" -ForegroundColor Green
            $ips | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
            return $true
        }
        else {
            Write-Host "[AVISO] DNS pode ainda nao estar propagado" -ForegroundColor Yellow
            Write-Host "[INFO] Tente novamente em alguns minutos" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "[ERRO] Falha ao verificar DNS: $_" -ForegroundColor Red
        return $false
    }
}

function Show-Menu {
    Show-Banner
    Show-CurrentConfig

    Write-Host "[MENU DE OPCAO]" -ForegroundColor Cyan
    Write-Host "1. Alterar dominio" -ForegroundColor Yellow
    Write-Host "2. Alterar portas" -ForegroundColor Yellow
    Write-Host "3. Testar propagacao DNS" -ForegroundColor Yellow
    Write-Host "4. Ver configurao atual" -ForegroundColor Gray
    Write-Host "5. Remover configuracao" -ForegroundColor Red
    Write-Host "0. Sair" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    $hasConfig = Load-Config

    while ($true) {
        Show-Menu
        $choice = Read-Host "Escolha uma opcao"

        switch ($choice) {
            "1" {
                $result = Set-NewDomain
                if ($result) {
                    Write-Host ""
                    Read-Host "Pressione ENTER para continuar"
                }
            }
            "2" {
                $result = Set-CustomPorts
                if ($result) {
                    Write-Host ""
                    Read-Host "Pressione ENTER para continuar"
                }
            }
            "3" {
                if ($DomainConfig.Domain) {
                    Test-DomainPropagation -domain $DomainConfig.Domain
                    Write-Host ""
                    Read-Host "Pressione ENTER para continuar"
                }
                else {
                    Write-Host "[ERRO] Nenhum dominio configurado!" -ForegroundColor Red
                    Write-Host ""
                    Read-Host "Pressione ENTER para continuar"
                }
            }
            "4" {
                Show-Banner
                Show-CurrentConfig
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "5" {
                $result = Reset-Config
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
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
