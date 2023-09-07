#!/usr/bin/env sh

cd /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher && \
rm -Rf management-state && k3d cluster delete local && k3d cluster create local && \
go run -gcflags="-N -l" main.go --add-local=true --no-cacerts=false --debug=true

