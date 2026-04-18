#!/bin/bash
set -e

echo "Iniciando container cPanel..."

# Configuração básica
mkdir -p /etc /var/lib/dhcpd /var/log/cpanel-install /var/lib/rpm
touch /etc/fstab /var/lib/dhcpd/dhcpd.leases /var/lib/rpm/.rpm.lock 2>/dev/null || true

# Install dependencies if not present
if ! command -v systemctl &> /dev/null; then
    echo "Instalando dependências..."
    dnf install -y openssh-server passwd systemd iptables-services network-scripts \
        wget perl hostname sudo curl tar gzip which curl ca-certificates 2>/dev/null || true
fi

# Configurar SSH
echo "root:devcp2026" | chpasswd
sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
systemctl enable sshd 2>/dev/null || true

# Check if cPanel is already installed
if [ -f /usr/local/cpanel/cpsrvd ]; then
    echo "cPanel já instalado, iniciando serviços..."
    exec /usr/local/cpanel/cpsrvd --ssl
else
    echo "Instalando cPanel..."
    cd /home
    
    # Download installer if not present
    if [ ! -f /home/latest ]; then
        echo "Baixando instalador cPanel..."
        curl -o latest -L https://securedownloads.cpanel.net/latest
        chmod +x latest
    fi
    
    # Run installer
    echo "Executando instalação..."
    ./latest --force --skip-all-imunify --skip-wptoolkit 2>&1 | tee /var/log/cpanel-install.log
    
    # Start cPanel after installation
    echo "Iniciando cPanel..."
    exec /usr/local/cpanel/cpsrvd --ssl
fi
