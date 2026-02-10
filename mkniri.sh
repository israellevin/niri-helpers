#!/bin/bash -e

dockerfile() {
    cat <<'EOF'
FROM debian:sid

# Install dependencies.
RUN apt update
RUN apt install -y \
    build-essential \
    clang \
    curl \
    gcc \
    git \
    libdbus-1-dev \
    libdisplay-info-dev \
    libegl1-mesa-dev \
    libgbm-dev \
    libinput-dev \
    libpango1.0-dev \
    libpipewire-0.3-dev \
    libseat-dev \
    libsystemd-dev \
    libudev-dev \
    libwayland-dev \
    libxcb-cursor-dev \
    libxkbcommon-dev

# Install Rust and cargo-strip.
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --force cargo-strip

# Use `docker build --build-arg NEW_NIRI=$(date +%s)` to force rebuild from here.

# Build niri
ARG NEW_NIRI
RUN git clone https://github.com/niri-wm/niri.git /niri
WORKDIR /niri
RUN cargo build --release
RUN cargo strip

# Build xwayland-satellite, for X, you know.
RUN git clone https://github.com/Supreeeme/xwayland-satellite /xwayland-satellite
WORKDIR /xwayland-satellite
RUN cargo build --release
RUN cargo strip

# Copy and build ned.
COPY ned /ned
WORKDIR /ned
RUN cargo build --release
RUN cargo strip

CMD sleep infinity
EOF
}

make() {
    local clean_flag
    [ "$1" = clean ] && clean_flag="--build-arg NEW_NIRI=$(date +%s)"

    # shellcheck disable=SC2086  # Allow word splitting for clean_flag
    dockerfile | docker build . -t niri-builder $clean_flag -f -
    docker run --rm --name niri-builder -dp 5020:80 niri-builder
    mkdir -p ./build
    docker cp niri-builder:/niri/target/release/niri ./build/.
    docker cp niri-builder:/xwayland-satellite/target/release/xwayland-satellite ./build/.
    docker cp niri-builder:/ned/target/release/ned ./build/.
    echo Binaries copied to ./build directory
    docker rm -f niri-builder
}

make "$@"
