#!/bin/bash
set -euo pipefail

log() { echo "[cpanel-entrypoint] $*"; }

log "Iniciando container cPanel ($(date -Is))"

# --- Pre-requisitos de boot (systemd/fstab dentro do container) ---
mkdir -p /etc /var/lib/dhcpd /var/log/cpanel-install /var/lib/rpm /usr/local/cpanel/logs
touch /etc/fstab /var/lib/dhcpd/dhcpd.leases /var/lib/rpm/.rpm.lock 2>/dev/null || true
touch /usr/local/cpanel/logs/error_log /usr/local/cpanel/logs/access_log 2>/dev/null || true

# --- Dependencias basicas (somente se faltarem) ---
if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
  log "Instalando dependencias basicas..."
  dnf install -y --setopt=install_weak_deps=False     openssh-server passwd systemd iptables-services network-scripts     wget perl hostname sudo curl tar gzip which ca-certificates || true
fi

# --- Credenciais: senha vem do .env, nunca fixa no script ---
if [ -n "${ROOT_PASSWORD:-}" ]; then
  printf "root:%s\n" "$ROOT_PASSWORD" | chpasswd
  log "Senha do root definida via variavel de ambiente"
else
  log "AVISO: ROOT_PASSWORD vazio - mantendo senha atual"
fi

# --- SSH: desabilitar login root por senha (producao) ---
if [ -f /etc/ssh/sshd_config ]; then
  sed -i -E "s/^#?PermitRootLogin.*/PermitRootLogin ${SSH_ROOT_LOGIN:-no}/" /etc/ssh/sshd_config
  sed -i -E "s/^#?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
  log "SSH: PermitRootLogin=${SSH_ROOT_LOGIN:-no}, PasswordAuthentication=no"
fi

# --- cPanel ja instalado? ---
if [ -x /usr/local/cpanel/cpsrvd ]; then
  log "cPanel instalado - atualizando NAT e licenca..."
  /usr/local/cpanel/scripts/build_cpnat || true
  /usr/local/cpanel/cpkeyclt || true

  log "Iniciando daemon cpsrvd..."
  /usr/local/cpanel/cpsrvd --ssl || true

  log "cpsrvd em execucao. Container pronto e monitorando logs."
  exec tail -F /usr/local/cpanel/logs/error_log
fi

# --- Instalacao do cPanel ---
cd /home
if [ ! -f /home/latest ]; then
  log "Baixando instalador do cPanel..."
  curl -fsSL -o latest https://securedownloads.cpanel.net/latest
  chmod +x latest
fi

log "Executando instalacao (pode levar 15-45 min)..."
if ./latest --force --skip-all-imunify --skip-wptoolkit 2>&1 | tee /var/log/cpanel-install.log; then
  log "Instalacao concluida - configurando e iniciando cpsrvd"
  /usr/local/cpanel/scripts/build_cpnat || true
  /usr/local/cpanel/cpkeyclt || true
  /usr/local/cpanel/cpsrvd --ssl || true
  exec tail -F /usr/local/cpanel/logs/error_log
else
  log "ERRO: instalacao falhou - ver /var/log/cpanel-install.log"
  exit 1
fi
