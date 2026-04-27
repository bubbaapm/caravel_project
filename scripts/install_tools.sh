#!/bin/bash
set -e

echo "=============================================="
echo "EDA Tool Installation"
echo "=============================================="

echo "Installing system dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    build-essential git vim xauth x11-apps m4 tcsh csh \
    libx11-dev tcl-dev tk-dev libcairo2-dev mesa-common-dev \
    libglu1-mesa-dev libncurses-dev flex bison libxpm-dev \
    libxaw7-dev libreadline-dev libgtk-3-dev xterm wget \
    python3 python3-pip python3-venv pipx direnv

BUILD_DIR=$(mktemp -d)
echo "Using temporary build directory: $BUILD_DIR"
trap "rm -rf $BUILD_DIR" EXIT

# Compiler flags to allow legacy C code to compile on Ubuntu 24.04+ (GCC 14)
export CFLAGS="-std=gnu17 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=strict-prototypes"

build_magic() {
    if ! command -v magic &>/dev/null; then
        echo "Building Magic..."
        cd "$BUILD_DIR"
        git clone https://github.com/RTimothyEdwards/magic.git
        cd magic
        ./configure --enable-cairo-offscreen
        make -j"$(nproc)"
        sudo make install
    else
        echo "Magic already installed."
    fi
}

build_xschem() {
    if ! command -v xschem &>/dev/null; then
        echo "Building Xschem..."
        cd "$BUILD_DIR"
        git clone https://github.com/StefanSchippers/xschem.git
        cd xschem
        ./configure
        make -j"$(nproc)"
        sudo make install
    else
        echo "Xschem already installed."
    fi
}

build_ngspice() {
    if ! command -v ngspice &>/dev/null; then
        echo "Building Ngspice (v41 with OSDI)..."
        cd "$BUILD_DIR"
        wget -O ngspice-41.tar.gz https://sourceforge.net/projects/ngspice/files/ng-spice-rework/old-releases/41/ngspice-41.tar.gz/
        tar -xzf ngspice-41.tar.gz
        cd ngspice-41
        mkdir -p release && cd release
        ../configure --with-x --enable-xspice --disable-debug --enable-cider \
            --with-readlines=yes --enable-predictor --enable-osdi --enable-openmp
        make -j"$(nproc)"
        sudo make install
    else
        echo "Ngspice already installed."
    fi
}

build_gaw() {
    if ! command -v gaw &>/dev/null; then
        echo "Building GAW (Waveform Viewer)..."
        cd "$BUILD_DIR"
        wget -O gaw3-20220315.tar.gz https://web.archive.org/web/20241111041845/https://download.tuxfamily.org/gaw/download/gaw3-20220315.tar.gz
        tar -xzf gaw3-20220315.tar.gz
        cd gaw3-20220315
        ./configure
        make -j"$(nproc)"
        sudo make install
    else
        echo "GAW already installed."
    fi
}

build_netgen() {
    if ! command -v netgen &>/dev/null; then
        echo "Building Netgen..."
        cd "$BUILD_DIR"
        git clone https://github.com/RTimothyEdwards/netgen.git
        cd netgen
        ./configure
        make -j"$(nproc)"
        sudo make install
    else
        echo "Netgen already installed."
    fi
}

build_openvaf() {
    if ! command -v openvaf &>/dev/null; then
        echo "Installing OpenVAF..."
        cd "$BUILD_DIR"
        wget -O openvaf.tar.xz https://openva.fra1.cdn.digitaloceanspaces.com/openvaf_23_2_0_linux_amd64.tar.xz
        tar xf openvaf.tar.xz
        sudo mv openvaf /usr/local/bin/openvaf
    else
        echo "OpenVAF already installed."
    fi
}

install_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Installing Docker Engine..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        if ! getent group docker > /dev/null; then
            sudo groupadd docker
        fi
        
        sudo usermod -aG docker $USER
        echo "Docker installed and user added to docker group."
    else
        echo "Docker already installed."
    fi
}

install_cf_cli() {
    if ! command -v cf &>/dev/null; then
        echo "Installing ChipFoundry CLI..."
        pipx install chipfoundry-cli
        pipx ensurepath
    else
        echo "ChipFoundry CLI already installed."
    fi
}

build_magic
build_xschem
build_ngspice
build_gaw
build_netgen
build_openvaf
install_docker
install_cf_cli

echo "Tool installation phase complete. Returning to master setup."
