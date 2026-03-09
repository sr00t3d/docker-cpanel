# 🐳 cPanel Dev Environment (AlmaLinux 8 on Docker)

Read me: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/dbsearch) ![Docker Script](https://img.shields.io/badge/language-Docker-green.svg)

<img width="700" src="docker-cpanel-cover.webp" />

This repository provides a robust infrastructure to run a full **cPanel & WHM** instance inside a Docker container using AlmaLinux 8.

The architecture was specifically designed for **plugin development and integration testing**, solving common boot issues with `systemd`, log file locks caused by storage drivers (such as `overlay2`), and data persistence.

## Main Features

* **Isolation and Persistence:** Uses named volumes to ensure that no configuration or installation is lost when recreating the container.
* **systemd Ready:** The container is started in privileged mode (`privileged: true`) with the required `capabilities` (`NET_ADMIN`, `SYS_ADMIN`, `SYS_RAWIO`) for managing internal services.
* **Automatic Mocking:** The startup script dynamically creates `/etc/fstab` and injects basic dependencies (`wget`, `perl`, `network-scripts`) before boot, preventing failures in the cPanel installer.
* **Core Mirroring:** The `cpanel_core` volume captures the `/usr/local/cpanel` directory, allowing the creation of *symlinks* on the Host for real-time code editing via VS Code.

## Initial Configuration

Before starting the environment, rename or create the `.env` file at the root of the project with your settings. The file allows you to customize the machine identification, such as the `HOSTNAME` and the root password (`ROOT_PASSWORD`).

You can also adjust port mappings and hardware resources. By default, the host HTTP port (`8080`) is mapped to the container port `80`.

**Example `.env`:**

```env
# --- Identification ---
CONTAINER_NAME=cpanel-server
HOSTNAME=srv.seudominio.com.br
ROOT_PASSWORD=YourStrongPasswordHere

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

# --- Features (Recommended for cPanel) ---
CPU_LIMIT=2.0
MEM_LIMIT=4G
MEM_RESERVATION=2G

# --- System ---
TIMEZONE=America/Sao_Paulo
LANG=C.utf8
```

## How to Start and Install

1. **Start the Container:**

Run Compose in the background. Docker will create the network structure and volumes based on `almalinux:8`.

```bash
docker-compose up -d
```

## Optional

### **Run the cPanel Installation:**

The base image already triggers the cPanel installer when the container starts, but if you want to reinstall with the container already running:

```bash
docker exec -it cpanel-server bash -c "cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest && sh latest"
```

*Note: The installation process may take from 15 to 45 minutes depending on the allocated resources.*

## Development Workflow (Real-Time Editing)

If you are developing plugins for cPanel, you can connect your IDE (such as VS Code) directly to the container files using the Host as a bridge, without needing manual `docker cp` commands.

The `docker-compose.yaml` already configures a named volume called `cpanel_core` that physically stores the installation at `/usr/local/cpanel`.

To edit the files continuously:

1. Create a development folder on your Host:

```bash
mkdir -p /home/cpanel/dev
```

## Optional (if you mapped /usr/local/cpanel)

Create a *Symbolic Link* on the Host pointing to the real volume managed by Docker (adjust the prefix name according to your project directory):

```bash
ln -s /var/lib/docker/volumes/NOME_DO_DIRETORIO_cpanel_core/_data /home/cpanel/dev/core
```

3. Open the `/home/cpanel/dev` folder in VS Code. Any changes made here will reflect **instantly** inside the container.

## Security Warnings

* **Privileged Mode:** This container runs with `privileged: true`. This setup is designed strictly for **development and integration testing environments**. Do not expose this container directly in production without reverse proxy layers and aggressive host hardening.
* **Passwords:** Change the default `ROOT_PASSWORD` as soon as you access WHM on port `2087` for the first time.

## Legal Notice

> [!WARNING]
> This software is provided “as is”. Always ensure you have explicit permission before running it. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## Detailed Tutorial

For a complete step-by-step guide, check out my full article:

👉 **Installing cPanel on Docker**  
https://perciocastelo.com.br/blog/installing-cpanel-in-docker.html

## License

This project is licensed under the **GNU General Public License v3.0**. See the **LICENSE** file for more details.