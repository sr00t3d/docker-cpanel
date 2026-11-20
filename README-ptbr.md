# Ambiente de Desenvolvimento cPanel (AlmaLinux 8 no Docker)

🇺🇸 [English](README.md) | 🇧🇷 **Português (BR)** | 🇪🇸 [Español](README-es.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/docker-cpanel/releases) [![Base](https://img.shields.io/badge/base-AlmaLinux%208-orange.svg)](docker-compose.yaml) [![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](docker-compose.yaml)

![Capa Docker cPanel](docker-cpanel-cover.webp)

Este repositório fornece uma infraestrutura reprodutível para executar uma instância completa do **cPanel & WHM** dentro de um contêiner Docker utilizando **AlmaLinux 8**.

A arquitetura foi projetada especificamente para **desenvolvimento de plugins e testes de integração**, resolvendo problemas comuns de boot com `systemd`, travas de arquivos de log causadas pelo driver de storage (`overlay2`), sincronização de NAT/licença e persistência de dados.

## Principais Recursos

- **Isolamento e Persistência:** utiliza volumes nomeados Docker (`cpanel_home`, `cpanel_etc`, `cpanel_var`, `cpanel_usr`, `cpanel_logs`, `cpanel_opt`) para preservar a instalação e configurações ao recriar o contêiner.
- **Pronto para systemd:** executa com `privileged: true`, sinal de parada `SIGRTMIN+3`, montagem de cgroups e capabilities explícitas (`NET_ADMIN`, `SYS_ADMIN`, `SYS_RAWIO`).
- **Entrypoint Unificado (`docker/entrypoint.sh`):** cria o `/etc/fstab` dinamicamente, injeta dependências essenciais (`wget`, `perl`, `network-scripts`), protege o acesso root/SSH (`SSH_ROOT_LOGIN=no` por padrão) e realiza o sync de NAT/licença.
- **Healthcheck Integrado:** monitora automaticamente a disponibilidade HTTPS do WHM (`:2087`) e cPanel (`:2083`).
- **Edição em Tempo Real do Core:** o volume nomeado `cpanel_usr` persiste `/usr/local/cpanel`, permitindo criar *symlinks* no Host para editar plugins direto no VS Code sem ciclos de `docker cp`.

## Configuração Inicial

Copie `.env.example` para `.env` e ajuste hostname, portas, limites de recursos e uma `ROOT_PASSWORD` forte:

```bash
cp .env.example .env
```

```env
# --- Identification ---
CONTAINER_NAME=cpanel-server
HOSTNAME=srv.seudominio.com.br
ROOT_PASSWORD=TroquePorUmaSenhaForte!

# --- Networks and Access ---
SSH_PORT_HOST=22028
SSH_PORT_CONTAINER=22
SSH_ROOT_LOGIN=no
CPANEL_SSL_PORT=2083
CPANEL_NON_SSL_PORT=2082
WHM_SSL_PORT=2087
WHM_NON_SSL_PORT=2086
HTTP_PORT_HOST=8091
HTTPS_PORT_HOST=8447
HTTP_PORT_CONTAINER=80
HTTPS_PORT_CONTAINER=443

# --- Resources (Recomendado para cPanel) ---
CPU_LIMIT=2.0
MEM_LIMIT=4G
MEM_RESERVATION=2G

# --- System ---
TIMEZONE=America/Sao_Paulo
LANG=C.utf8
```

## Como Subir

```bash
# Validar sintaxe do Compose
docker compose config --quiet

# Subir o contêiner em background
docker compose up -d

# Verificar status e healthcheck
docker compose ps
```

### Reinstalação Manual Opcional do cPanel

```bash
docker exec -it cpanel-server bash -c "cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest && sh latest"
```

*Nota: a instalação inicial do cPanel costuma levar de 15 a 45 minutos dependendo dos recursos de CPU, RAM e rede.*

## Fluxo de Desenvolvimento (Edição em Tempo Real)

Como o `docker-compose.yaml` armazena `/usr/local/cpanel` no volume nomeado `cpanel_usr`, você pode criar um link simbólico no Host para edição contínua:

```bash
mkdir -p /home/cpanel/dev
ln -s /var/lib/docker/volumes/<nome_do_diretorio>_cpanel_usr/_data /home/cpanel/dev/core
```

## Avisos de Segurança

- **Somente Laboratório / Desenvolvimento:** este contêiner opera com `privileged: true` para compatibilidade com `systemd`. Não utilize em produção; o cPanel em Docker não é suportado oficialmente pela cPanel Inc. e exige licença válida.
- **Rotação de Credenciais:** altere `ROOT_PASSWORD` imediatamente no primeiro acesso ao WHM (`https://<host>:2087`).

## Tutorial Detalhado

Confira o guia passo a passo completo: [Instalando cPanel no Docker](https://perciocastelo.com.br/blog/installing-cpanel-in-docker.html)

## Licença

Licenciado sob a [Apache License 2.0](LICENSE).
