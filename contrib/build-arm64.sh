#!/bin/sh -veu

# Compile Crystal project statically for arm64 (aarch64)
#docker run --rm --privileged multiarch/qemu-user-static:register --reset
docker run --rm --privileged aptman/qus -- -r
docker run --rm --privileged aptman/qus -s -- -p aarch64
docker build --pull --platform=linux/arm64/v8 --network host -t erdnaxeli/castblock:aarch64 -f contrib/Dockerfile.aarch64 .
