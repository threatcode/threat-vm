#!/bin/bash

set -eu

IMAGE=kali-rolling/vm-builder
OPTS=()

# Use escape sequences only if both stdout/stderr are opened on a terminal
if [ -t 1 ] && [ -t 2 ]; then
    _bold=$(tput bold) _reset=$(tput sgr0)
else
    _bold= _reset=
fi

b() { echo -n "${_bold}$@${_reset}"; }
fail() { echo "ERROR:" "$@" >&2; exit 1; }
vrun() { echo $(b "$ $@"); "$@"; }
vexec() { echo $(b "$ $@"); exec "$@"; }

if [ -t 0 ]; then
    OPTS+=(--interactive --tty)
fi
OPTS+=(
    --rm --net host
    --device /dev/kvm --group-add $(stat -c "%g" /dev/kvm)
    --security-opt label=disable
    --volume $(pwd):/recipes --workdir /recipes
)

if [ -x /usr/bin/podman ]; then
    PODMAN=podman
    if [ $(id -u) -eq 0 ]; then
        OPTS+=(--user $(stat -c "%u:%g" .))
    fi
    OPTS+=(--log-driver none)    # we don't want stdout in the journal
elif [ -x /usr/bin/docker ]; then
    PODMAN=docker
    OPTS+=(--user $(stat -c "%u:%g" .))
else
    fail "No container engine detected, aborting."
fi

if ! $PODMAN inspect --type image $IMAGE >/dev/null 2>&1; then
    vrun $PODMAN build -t $IMAGE .
    echo
fi

vexec $PODMAN run "${OPTS[@]}" $IMAGE ./build.sh "$@"
