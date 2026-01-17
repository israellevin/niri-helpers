#!/bin/bash -e
docker build . -t niri-builder --build-arg NEW_HYP="$(date +%s)"
docker run --rm --name niri-builder -dp 80:8000 niri-builder
docker cp niri-builder:/xwayland-satellite/target/release/xwayland-satellite .
docker cp niri-builder:/niri/target/release/niri .
docker rm -f niri-builder
