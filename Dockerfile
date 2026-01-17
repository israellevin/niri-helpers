# Dockerfile to build niri.
FROM debian:sid

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

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --force cargo-strip

WORKDIR /
RUN git clone https://github.com/Supreeeme/xwayland-satellite
WORKDIR /xwayland-satellite
RUN cargo build --release
RUN cargo strip

# Use `docker build --build-arg NEW_NIRI=$(date +%s)` to force rebuild from here.
ARG NEW_NIRI
WORKDIR /
RUN git clone https://github.com/YaLTeR/niri
WORKDIR /niri
RUN cargo build --release
RUN cargo strip

CMD sleep infinity
