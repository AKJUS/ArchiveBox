#!/usr/bin/env bash
# ArchiveBox Setup Script (Ubuntu/Debian/FreeBSD/macOS)
#   - Project Homepage: https://github.com/ArchiveBox/ArchiveBox
#   - Install Documentation: https://github.com/ArchiveBox/ArchiveBox/wiki/Install
# Script Usage:
#    curl -fsSL 'https://raw.githubusercontent.com/ArchiveBox/ArchiveBox/dev/bin/setup.sh' | bash
#           (aka https://docker-compose.archivebox.io)

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
# set -x
# shopt -s nullglob
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
# IFS=$'\n'

clear

ARCHIVEBOX_BRANCH="${ARCHIVEBOX_BRANCH:-dev}"
ARCHIVEBOX_IMAGE="${ARCHIVEBOX_IMAGE:-archivebox/archivebox:dev}"
ARCHIVEBOX_PYTHON="${ARCHIVEBOX_PYTHON:-3.13}"
ARCHIVEBOX_PACKAGE="${ARCHIVEBOX_PACKAGE:-archivebox @ https://github.com/ArchiveBox/ArchiveBox/archive/refs/heads/${ARCHIVEBOX_BRANCH}.zip}"
ARCHIVEBOX_PLATFORM="${ARCHIVEBOX_PLATFORM:-}"
ARCHIVEBOX_COMPOSE_URL="${ARCHIVEBOX_COMPOSE_URL:-https://raw.githubusercontent.com/ArchiveBox/ArchiveBox/${ARCHIVEBOX_BRANCH}/docker-compose.yml}"
DOCKER_PLATFORM_ARGS=()
if [ -n "$ARCHIVEBOX_PLATFORM" ]; then
    DOCKER_PLATFORM_ARGS=(--platform "$ARCHIVEBOX_PLATFORM")
fi

wait_for_archivebox() {
    local url="http://127.0.0.1:8000/health/"
    local host_header="admin.archivebox.localhost:8000"
    local attempts=60
    local attempt

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if curl -fsS -H "Host: ${host_header}" "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "[!] Server process started, but health check did not become ready at $url after ${attempts}s."
    echo "    Run the logs command below to inspect startup progress."
    return 0
}

open_archivebox() {
    if command -v open > /dev/null; then
        open "http://127.0.0.1:8000" || true
    fi
}

ensure_uv() {
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    if command -v uv > /dev/null 2>&1; then
        return 0
    fi

    echo "[+] Installing uv..."
    if command -v curl > /dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget > /dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "[X] curl or wget is required to install uv."
        exit 1
    fi

    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if ! command -v uv > /dev/null 2>&1; then
        echo "[X] uv was installed, but the uv command was not found in PATH."
        echo "    Add ~/.local/bin to PATH, then run this script again."
        exit 1
    fi
}

install_archivebox_with_uv() {
    local uv_tool_bin_dir

    ensure_uv

    echo
    echo "[+] Installing ArchiveBox python tool using uv from $ARCHIVEBOX_PACKAGE..."
    if uv --no-config tool add --help > /dev/null 2>&1; then
        uv --no-config tool add --python "$ARCHIVEBOX_PYTHON" --upgrade "$ARCHIVEBOX_PACKAGE"
    else
        uv --no-config tool install --python "$ARCHIVEBOX_PYTHON" --upgrade "$ARCHIVEBOX_PACKAGE"
    fi

    uv_tool_bin_dir="$(uv --no-config tool dir --bin)"
    export PATH="$uv_tool_bin_dir:$PATH"
    uv --no-config tool update-shell || true
}

if [ "$(id -u)" -eq 0 ]; then
    echo
    echo "[X] You cannot run this script as root. You must run it as a non-root user with sudo ability."
    echo "    Create a new non-privileged user 'archivebox' if necessary."
    echo "      adduser archivebox && usermod -a archivebox -G sudo && su archivebox"
    echo "    https://www.digitalocean.com/community/tutorials/how-to-create-a-new-sudo-enabled-user-on-ubuntu-20-04-quickstart"
    echo "    https://www.vultr.com/docs/create-a-sudo-user-on-freebsd"
    echo "    Then re-run this script as the non-root user."
    echo
    exit 2
fi

if (command -v docker > /dev/null && docker compose version > /dev/null && docker pull "${DOCKER_PLATFORM_ARGS[@]}" "$ARCHIVEBOX_IMAGE"); then
    echo "[+] Initializing an ArchiveBox data folder at ~/archivebox/data using Docker Compose..."
    mkdir -p ~/archivebox/data || exit 1
    cd ~/archivebox
    if [ -f "./index.sqlite3" ]; then
        mv -i ~/archivebox/* ~/archivebox/data/
    fi
    curl -fsSL "$ARCHIVEBOX_COMPOSE_URL" > docker-compose.yml
    export ARCHIVEBOX_IMAGE ARCHIVEBOX_PLATFORM
    docker compose run --rm archivebox init --install
    echo
    echo "[+] Starting ArchiveBox server using: docker compose up -d..."
    docker compose up -d
    wait_for_archivebox
    open_archivebox
    echo
    echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivebox/data. Usage:"
    echo "    cd ~/archivebox"
    echo "    docker compose ps"
    echo "    docker compose down"
    echo "    ARCHIVEBOX_IMAGE=$ARCHIVEBOX_IMAGE docker compose pull"
    echo "    docker compose up"
    echo "    docker compose run archivebox manage createsuperuser"
    echo "    docker compose run archivebox add 'https://example.com'"
    echo "    docker compose run archivebox list"
    echo "    docker compose run archivebox help"
    exit 0
elif (command -v docker > /dev/null && docker pull "${DOCKER_PLATFORM_ARGS[@]}" "$ARCHIVEBOX_IMAGE"); then
    echo "[+] Initializing an ArchiveBox data folder at ~/archivebox/data using Docker..."
    mkdir -p ~/archivebox/data || exit 1
    cd ~/archivebox
    if [ -f "./index.sqlite3" ]; then
        mv -i ~/archivebox/* ~/archivebox/data/
    fi
    cd ./data
    docker run "${DOCKER_PLATFORM_ARGS[@]}" -v "$PWD":/data -it --rm "$ARCHIVEBOX_IMAGE" init --install
    echo
    echo "[+] Starting ArchiveBox server using: docker run -d archivebox/archivebox..."
    docker run "${DOCKER_PLATFORM_ARGS[@]}" -v "$PWD":/data -it -d -p 8000:8000 --name=archivebox "$ARCHIVEBOX_IMAGE"
    wait_for_archivebox
    open_archivebox
    echo
    echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivebox/data. Usage:"
    echo "    cd ~/archivebox/data"
    echo "    docker ps --filter name=archivebox"
    echo "    docker kill archivebox"
    echo "    docker pull $ARCHIVEBOX_IMAGE"
    echo "    docker run ${DOCKER_PLATFORM_ARGS[*]} -v $PWD:/data -d -p 8000:8000 --name=archivebox $ARCHIVEBOX_IMAGE"
    echo "    docker run ${DOCKER_PLATFORM_ARGS[*]} -v $PWD:/data -it $ARCHIVEBOX_IMAGE manage createsuperuser"
    echo "    docker run ${DOCKER_PLATFORM_ARGS[*]} -v $PWD:/data -it $ARCHIVEBOX_IMAGE add 'https://example.com'"
    echo "    docker run ${DOCKER_PLATFORM_ARGS[*]} -v $PWD:/data -it $ARCHIVEBOX_IMAGE list"
    echo "    docker run ${DOCKER_PLATFORM_ARGS[*]} -v $PWD:/data -it $ARCHIVEBOX_IMAGE help"
    exit 0
fi

echo
echo "[!] It's highly recommended to use ArchiveBox with Docker, but Docker wasn't found."
echo
echo "    ⚠️ If you want to use Docker, press [Ctrl-C] to cancel now. ⚠️"
echo "        Get Docker: https://docs.docker.com/get-docker/"
echo "        After you've installed Docker, run this script again."
echo
echo "Otherwise, install will continue with apt/brew/pkg + uv in 12s... (press [Ctrl+C] to cancel)"
echo
sleep 12 || exit 1
echo "Proceeding with system package manager..."
echo

echo "[i] ArchiveBox Setup Script 📦"
echo
echo "    This is a helper script which installs ArchiveBox and bootstraps its Python/Node runtimes."
echo "    You may be prompted for a sudo password in order to install the following:"
echo
echo "        - archivebox"
echo "        - python3, uv, nodejs, npm             (languages used by ArchiveBox and plugin installers)"
echo "        - curl, wget                           (used to bootstrap package installation)"
echo "        - extractor/plugin dependencies        (installed/discovered by archivebox init --install)"
echo
echo "    If you'd rather install these manually as-needed, you can find detailed documentation here:"
echo "        https://github.com/ArchiveBox/ArchiveBox/wiki/Install"
echo
echo "Continuing in 12s... (press [Ctrl+C] to cancel)"
echo
sleep 12 || exit 1
echo "Proceeding to install dependencies..."
echo

# On Linux:
if which apt-get > /dev/null; then
    echo "[+] Installing ArchiveBox system dependencies using apt..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-venv wget curl nodejs npm
    install_archivebox_with_uv
# On Mac:
elif which brew > /dev/null; then
    echo "[+] Installing ArchiveBox using Homebrew..."
    brew tap archivebox/archivebox
    brew update
    brew install archivebox
elif which pkg > /dev/null; then
    echo "[+] Installing ArchiveBox system dependencies using pkg and uv..."
    sudo pkg install -y python3 py39-sqlite3 npm wget curl
    install_archivebox_with_uv
else
    echo "[!] Warning: Could not find aptitude/homebrew/pkg! May not be able to install all dependencies automatically."
    echo
    echo "    If you're on macOS, make sure you have homebrew installed:     https://brew.sh/"
    echo "    If you're on Linux, only Ubuntu/Debian/BSD systems are officially supported with this script."
    echo "    If you're on Windows, this script is not officially supported (Docker is recommended instead)."
    echo
    echo "See the README.md for Manual Setup & Troubleshooting instructions if you you're unable to run ArchiveBox after this script completes."
fi

echo

if ! which archivebox > /dev/null 2>&1; then
    ensure_uv
    export PATH="$(uv --no-config tool dir --bin):$PATH"
fi

if ! which archivebox > /dev/null 2>&1; then
    echo "[X] archivebox command was not found in PATH after installing!"
    echo "    Check to see if a previous step failed."
    exit 1
fi

echo
echo "[+] Initializing ArchiveBox data folder at ~/archivebox/data..."
mkdir -p ~/archivebox/data || exit 1
cd ~/archivebox
if [ -f "./index.sqlite3" ]; then
    mv -i ~/archivebox/* ~/archivebox/data/
fi
cd ./data
: | archivebox init --install   # pipe in empty command to make sure stdin is closed
# init shows version output at the end too
echo
echo "[+] Starting ArchiveBox server using: nohup archivebox server &..."
nohup archivebox server 0.0.0.0:8000 > ./logs/server.log 2>&1 &
wait_for_archivebox
open_archivebox
echo
echo "[√] Server started on http://0.0.0.0:8000 and data directory initialized in ~/archivebox/data. Usage:"
echo "    cd ~/archivebox/data                               # see your data dir"
echo "    archivebox server --quick-init 0.0.0.0:8000        # start server process"
echo "    archivebox manage createsuperuser                  # add an admin user+pass"
echo "    ps aux | grep archivebox                           # see server process pid"
echo "    pkill -f archivebox                                # stop the server"
echo "    uv tool install --python $ARCHIVEBOX_PYTHON --upgrade '$ARCHIVEBOX_PACKAGE'; archivebox init  # update versions"
echo "    archivebox add 'https://example.com'"              # archive a new URL
echo "    archivebox list                                    # see URLs archived"
echo "    archivebox help                                    # see more help & examples"
