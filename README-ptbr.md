# 🐳 cPanel Dev Environment (AlmaLinux 8 on Docker)

Read me: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Docker Script](https://img.shields.io/badge/language-Docker-green.svg)

<img width="700" src="docker-cpanel-cover.webp" />

Este repositório fornece uma infraestrutura robusta para rodar uma instância completa do **cPanel & WHM** dentro de um container Docker utilizando AlmaLinux 8. 

A arquitetura foi projetada especificamente para o **desenvolvimento de plugins e testes de integração**, resolvendo problemas comuns de boot com o `systemd`, bloqueios de arquivos de log pelo driver de storage (como `overlay2`) e persistência de dados.

## Principais Recursos

* **Isolamento e Persistência:** Utiliza volumes nomeados para garantir que nenhuma configuração ou instalação seja perdida ao recriar o container.
* **Pronto para systemd:** O container é iniciado no modo privilegiado (`privileged: true`) com as `capabilities` necessárias (`NET_ADMIN`, `SYS_ADMIN`, `SYS_RAWIO`) para o gerenciamento de serviços internos.
* **Mocking Automático:** O script de inicialização cria o `/etc/fstab` dinamicamente e injeta dependências básicas (`wget`, `perl`, `network-scripts`) antes do boot, evitando quebras no instalador do cPanel.
* **Espelhamento de Core:** O volume `cpanel_core` captura a pasta `/usr/local/cpanel`, permitindo a criação de *symlinks* no Host para edição de código em tempo real via VS Code.

## Configuração Inicial

Antes de subir o ambiente, renomeie ou crie o arquivo `.env` na raiz do projeto com as suas configurações. O arquivo permite personalizar a identificação da máquina, como o `HOSTNAME` e a senha de root (`ROOT_PASSWORD`). 

Você também pode ajustar o mapeamento de portas e recursos de hardware. Por padrão, a porta HTTP do host (`8080`) é mapeada para a porta `80` do container.

**Exemplo de `.env`:**

```env
# --- Identification ---
CONTAINER_NAME=cpanel-server
HOSTNAME=srv.seudominio.com.br
ROOT_PASSWORD=SuaSenhaForteAqui

# --- Networks and Access ---
SSH_PORT_HOST=22028
SSH_PORT_CONTAINER=22028
CPANEL_SSL_PORT=2083
CPANEL_NON_SSL_PORT=2082
WHM_SSL_PORT=2087
WHM_NON_SSL_PORT=2086
HTTP_PORT_HOST=8080
HTTPS_PORT_HOST=8443
HTTP_PORT_CONTAINER=80
HTTPS_PORT_CONTAINER=443

# --- Features (Recomendado para cPanel) ---
CPU_LIMIT=2.0
MEM_LIMIT=4G
MEM_RESERVATION=2G

# --- System ---
TIMEZONE=America/Sao_Paulo
LANG=C.utf8
```

## Como Subir e Instalar

1. **Inicie o Container:**

Execute o Compose em background. O Docker criará a estrutura de rede e os volumes baseados no `almalinux:8`.
```bash
docker-compose up -d
```

## Opcional

### **Execute a Instalação do cPanel:**

A imagem base já dispara o instalador do cPanel ao subir o container, mas caso queira reinstalar com o container startado:

```bash
docker exec -it cpanel-server bash -c "cd /home && curl -o latest -L [https://securedownloads.cpanel.net/latest](https://securedownloads.cpanel.net/latest) && sh latest"
```

*Nota: O processo de instalação pode levar de 15 a 45 minutos dependendo dos recursos alocados.*

## Fluxo de Desenvolvimento (Edição em Tempo Real)

Se você está desenvolvendo plugins para o cPanel, pode conectar sua IDE (como o VS Code) diretamente aos arquivos do container usando o Host como ponte, sem precisar de comandos `docker cp` manuais.

O `docker-compose.yaml` já configura um volume nomeado chamado `cpanel_core` que guarda fisicamente a instalação de `/usr/local/cpanel`.

Para editar os arquivos de forma contínua:

1. Crie uma pasta de desenvolvimento no seu Host:
```bash
mkdir -p /home/cpanel/dev

```
## Opcional (caso tenha mapeado o /usr/local/cpanel)

Crie um *Link Simbólico* no Host apontando para o volume real gerenciado pelo Docker (ajuste o nome do prefixo conforme o diretório do seu projeto):

```bash
ln -s /var/lib/docker/volumes/NOME_DO_DIRETORIO_cpanel_core/_data /home/cpanel/dev/core
```

3. Abra a pasta `/home/cpanel/dev` no VS Code. Qualquer alteração feita aqui refletirá **instantaneamente** dentro do container.

## Avisos de Segurança

* **Modo Privilegiado:** Este container roda com `privileged: true`. Este setup é desenhado estritamente para **ambientes de desenvolvimento e testes de integração**. Não exponha este container diretamente em produção sem camadas de proxy reverso e hardening agressivo no Host.
* **Senhas:** Altere o `ROOT_PASSWORD` padrão assim que acessar o WHM na porta `2087` pela primeira vez.

## Aviso Legal

> [!WARNING]
> Este software é fornecido “como está”. Sempre garanta que você possui permissão explícita antes de executá-lo. O autor não é responsável por qualquer uso indevido, consequências legais ou impacto em dados causados por esta ferramenta.

## Tutorial detalhado

Para um guia completo passo a passo, confira meu artigo completo:

👉 [**Instalando cPanel no Docker**](https://perciocastelo.com.br/blog/installing-cpanel-in-docker.html)

## Licença

Este projeto é licenciado sob a **GNU General Public License v3.0**. Consulte o arquivo **LICENSE** para mais detalhes.