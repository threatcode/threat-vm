#!/usr/bin/env bash
#
# ./$0
# CONTAINER=docker ./$0
#

set -eu

CONTAINER=${CONTAINER:-}
IMAGE=kali-build/vm
OPTS=()

# Use escape sequences only if both stdout/stderr are opened on a terminal
if [ -t 1 ] && [ -t 2 ]; then
    _bold=$(tput bold)
    _reset=$(tput sgr0)
else
    _bold=
    _reset=
fi

b() { echo -n "${_bold}$@${_reset}"; }
fail() { echo "ERROR: $@" 1>&2; exit 1; }
# Last program in this script should use exec
vexec() { b "# $@"; echo; exec "$@"; }
vrun()  { b "# $@"; echo;      "$@"; }

if [ -x "$(which podman)" ] && \
  ([ -z $CONTAINER ] || [ $CONTAINER == "podman" ]); then
    CONTAINER=podman

    # We don't want stdout in the journal
    OPTS+=(--log-driver none)
elif [ -x "$(which docker)" ] && \
    ([ -z $CONTAINER ] || [ $CONTAINER == "docker" ]); then
    CONTAINER=docker
else
    fail "No container engine detected, aborting"
fi

if [ -t 0 ]; then
    OPTS+=(--interactive --tty)
fi
OPTS+=(
    --rm --net host
    --device /dev/kvm --group-add $(stat -c "%g" /dev/kvm)
    --security-opt label=disable
    --volume $(pwd):/recipes --workdir /recipes
)

# Kernel-based Virtual Machine
# Check if virtualization extensions is enabled (in BIOS/UEFI)
[ -e /dev/kvm ] \
    && OPTS+=(--device /dev/kvm --group-add "$(stat -c "%g" /dev/kvm)") \
    || fail "Missing /dev/kvm, aborting"

# Check root privileges
# Stop fakemachine warning (does not want to be root)
[ "$(id -u)" -eq 0 ] \
    && OPTS+=(--user "$(stat --format="%u:%g" .)")

if ! $CONTAINER inspect --type image $IMAGE >/dev/null 2>&1; then
    vrun $CONTAINER build -t $IMAGE .
    echo
fi

vexec $CONTAINER run "${OPTS[@]}" $IMAGE ./build.sh "$@"
