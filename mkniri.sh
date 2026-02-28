#!/bin/bash -e

usage() {
    echo "Usage: $0 [clean] [--branch <branch>] [--repo <repo>]"
    echo "  clean: Force rebuild of niri by using a new build argument."
    echo "  --branch <branch>: Specify the branch of the niri repository to use (default: main)."
    echo "  --repo <repo>: Specify the repository URL of niri to use (default: https://github.com/niri-wm/niri)."
    echo "  --build-directory <dir>: Specify the directory to copy the built files to (default: ./build)."
    exit 1
}

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
ARG NIRI_REPO=https://github.com/niri-wm/niri.git
ARG NIRI_BRANCH=main
RUN git clone --branch "$NIRI_BRANCH" --depth 1 "$NIRI_REPO" /niri
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
    local build_flags
    local branch
    local repo
    local build_directory="./build"
    while [ "$#" -gt 0 ]; do
        case "$1" in
            clean)
                build_flags+=" --build-arg NEW_NIRI=$(date +%s)"
                ;;
            --branch)
                [ "$branch" ] && echo "Branch already set to $branch, cannot set to $1" && exit 1
                shift
                branch="$1"
                build_flags+=" --build-arg NIRI_BRANCH=$branch"
                ;;
            --repo)
                [ "$repo" ] && echo "Repo already set to $repo, cannot set to $1" && exit 1
                shift
                repo="$1"
                build_flags+=" --build-arg NIRI_REPO=$repo"
                ;;
            --build-directory)
                shift
                build_directory="$1"
                ;;
            *)
                echo "Unknown argument: $1"
                usage
                ;;
        esac
        shift
    done

    # shellcheck disable=SC2086  # Allow word splitting for build_flags
    dockerfile | docker build . -t niri-builder $build_flags -f -
    docker run --rm --name niri-builder -dp 5020:80 niri-builder
    mkdir -p "$build_directory"
    docker cp niri-builder:/niri/target/release/niri "$build_directory"
    docker cp niri-builder:/xwayland-satellite/target/release/xwayland-satellite "$build_directory"
    docker cp niri-builder:/ned/target/release/ned "$build_directory"
    docker cp niri-builder:/ned/examples/ "$build_directory/ned_examples/"
    echo Files copied to ./build directory
    docker rm -f niri-builder
}

make "$@"
