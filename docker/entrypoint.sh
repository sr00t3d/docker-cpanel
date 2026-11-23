#!/bin/bash
set -euo pipefail

log() { echo "[cpanel-entrypoint] $*"; }

log "Iniciando container cPanel dev-lab ($(date -Is))"

# --- Pre-requisitos de boot (systemd / fstab / diretorios) ---
mkdir -p /etc /var/lib/dhcpd /var/log/cpanel-install /var/lib/rpm /usr/local/cpanel/logs /etc/systemd/system /var/cpanel/activate /var/cpanel/analytics
touch /etc/fstab /etc/.whostmgrft /var/lib/dhcpd/dhcpd.leases /var/lib/rpm/.rpm.lock 2>/dev/null || true
touch /usr/local/cpanel/logs/error_log /usr/local/cpanel/logs/access_log 2>/dev/null || true

# --- Resolver conflito de coreutils-single do AlmaLinux minimal ---
if rpm -q coreutils-single >/dev/null 2>&1; then
  log "Substituindo coreutils-single por coreutils completo..."
  dnf install -y --allowerasing coreutils procps-ng || true
fi

# --- Dependencias basicas para operacao do cPanel e systemd ---
if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1 || ! command -v ps >/dev/null 2>&1; then
  log "Instalando dependencias basicas..."
  dnf install -y --setopt=install_weak_deps=False --allowerasing \
    openssh-server passwd systemd iptables-services network-scripts \
    wget perl hostname sudo curl tar gzip which ca-certificates procps-ng iproute || true
fi

# --- Credenciais: senha do root via variavel de ambiente ---
if [ -n "${ROOT_PASSWORD:-}" ]; then
  printf "root:%s\n" "$ROOT_PASSWORD" | chpasswd
  log "Senha do root definida via variavel de ambiente"
else
  log "AVISO: ROOT_PASSWORD vazio - mantendo senha atual"
fi

# --- SSH: configuracao de seguranca do lab ---
if [ -f /etc/ssh/sshd_config ]; then
  sed -i -E "s/^#?PermitRootLogin.*/PermitRootLogin ${SSH_ROOT_LOGIN:-no}/" /etc/ssh/sshd_config
  sed -i -E "s/^#?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
  log "SSH configurado: PermitRootLogin=${SSH_ROOT_LOGIN:-no}, PasswordAuthentication=no"
fi

# --- Caso 1: cPanel ja instalado (boot normal ou restart) ---
if [ -x /usr/local/cpanel/cpsrvd ]; then
  log "cPanel instalado - atualizando NAT e licenca..."
  /usr/local/cpanel/scripts/build_cpnat || true
  /usr/local/cpanel/cpkeyclt || true

  # Habilita servicos no systemd se ainda nao habilitados
  systemctl --root=/ enable cpanel.service mariadb.service named.service 2>/dev/null || true

  # Aceitar EULA e marcar assistente inicial como concluido (evita loop no initial_setup_wizard)
  touch /etc/.whostmgrft
  mkdir -p /var/cpanel/activate /var/cpanel/analytics
  touch /var/cpanel/activate/2026-05.v01.GDPR.CPWHMEULA
  /usr/local/cpanel/3rdparty/bin/perl -MWhostmgr::Setup::Completed -MWhostmgr::Setup::EULA -e '
    eval { Whostmgr::Setup::EULA::set_accepted(user => "root", remote_ip => "127.0.0.1"); };
    eval { Whostmgr::Setup::Completed::set_complete(); };
  ' 2>/dev/null || true

  log "Iniciando systemd como PID 1..."
  exec /usr/sbin/init
fi

# --- Caso 2: Primeiro boot (instalacao unattended sob systemd) ---
log "Configurando instalador cPanel para rodar como servico systemd no primeiro boot..."

cat << 'INITSVC' > /etc/systemd/system/cpanel-firstboot-install.service
[Unit]
Description=cPanel First Boot Unattended Installer
After=network-online.target dbus.service
Wants=network-online.target
Before=cpanel.service
ConditionPathExists=!/usr/local/cpanel/cpsrvd

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=3600
ExecStart=/docker-install.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
INITSVC

cat << 'INSTALLSH' > /docker-install.sh
#!/bin/bash
set -euo pipefail
echo "=========================================================="
echo " [cPanel First Boot] Iniciando instalacao oficial cPanel  "
echo "=========================================================="

cd /home
if [ ! -f /home/latest ]; then
  echo "[cPanel First Boot] Baixando instalador oficial..."
  curl -fsSL -o latest https://securedownloads.cpanel.net/latest
  chmod +x latest
fi

echo "[cPanel First Boot] Executando ./latest com systemd ativo..."
./latest --force --skip-all-imunify --skip-wptoolkit 2>&1 | tee /var/log/cpanel-install.log || true

echo "[cPanel First Boot] Finalizando ajustes pos-instalacao..."
/usr/local/cpanel/scripts/build_cpnat || true
/usr/local/cpanel/cpkeyclt || true

# Aceitar EULA e marcar assistente inicial como concluido (evita loop no initial_setup_wizard)
touch /etc/.whostmgrft
mkdir -p /var/cpanel/activate /var/cpanel/analytics
touch /var/cpanel/activate/2026-05.v01.GDPR.CPWHMEULA
if [ -x /usr/local/cpanel/3rdparty/bin/perl ]; then
  /usr/local/cpanel/3rdparty/bin/perl -MWhostmgr::Setup::Completed -MWhostmgr::Setup::EULA -e '
    eval { Whostmgr::Setup::EULA::set_accepted(user => "root", remote_ip => "127.0.0.1"); };
    eval { Whostmgr::Setup::Completed::set_complete(); };
  ' 2>/dev/null || true
fi

systemctl enable --now cpanel.service mariadb.service named.service || true
echo "[cPanel First Boot] cPanel e servicos ativos no systemd com wizard ignorado."
INSTALLSH
chmod +x /docker-install.sh

# Habilitar o servico de primeiro boot de forma offline
systemctl --root=/ enable cpanel-firstboot-install.service 2>/dev/null || true

log "Entregando execucao para /usr/sbin/init (systemd PID 1)..."
exec /usr/sbin/init
