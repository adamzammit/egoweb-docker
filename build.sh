#!/bin/bash

#Fail on any error
set -e

docker buildx build --pull --no-cache --push --platform linux/amd64,linux/arm64,linux/ppc64le,linux/mips64le,linux/arm/v7,linux/arm/v6,linux/s390x -t acspri/egoweb:215700eade32e -t acspri/egoweb:latest  .

