#!/bin/bash

set -eu

SUPPORTED_ARCHITECTURES="amd64"
SUPPORTED_BRANCHES="kali-dev kali-last-snapshot kali-rolling"
SUPPORTED_DESKTOPS="gnome i3 kde xfce"
SUPPORTED_TYPES="generic qemu rootfs virtualbox"

DEFAULT_ARCH=amd64

WELL_KNOWN_PROXIES="\
3142 apt-cacher-ng
8000 squid-deb-proxy
9999 approx"

ARCH=
BRANCH=kali-rolling
DESKTOP=xfce
MIRROR=http://http.kali.org/kali
ROOTFS=
SIZE=80
TYPE=generic
VERSION=
ZIP=false

fail() { echo "$@" >&2; exit 1; }
b() { tput bold; echo -n "$@"; tput sgr0; }

ask_confirmation() {
    local question=${1:-"Do you want to continue?"}
    local answer=
    local choices=
    local default=yes
    local timeout=10
    local ret=0

    # Capitalize the default choice
    [ $default = yes ] && choices="[Y/n]" || choices="[y/N]"

    # Discard chars pending on stdin
    while read -r -t 0; do read -n 256 -r -s; done

    # Ask the question
    read -r -t $timeout -p "$question $choices " answer || ret=$?
    if [ $ret -gt 128 ]; then
        echo "No answer, assuming $default."
        answer=$default
        ret=0
    fi
    [ $ret -eq 0 ] || exit $ret
    [ "$answer" ] && answer=${answer,,} || answer=$default
    case "$answer" in
        (y|yes) return 0 ;;
        (*)     return 1 ;;
    esac
}

[ $(id -u) -eq 0 ] && fail "No need to be root. Please run as normal user."

USAGE="Usage: $(basename $0) [<option>...]

Build a Kali Linux OS image.

Options:
  -a ARCH     Build an image for this architecture, default: $DEFAULT_ARCH
  -b BRANCH   Kali branch used to build the image, default: $BRANCH
  -d DESKTOP  Desktop environment installed in the image, default: $DESKTOP
  -m MIRROR   Mirror used to build the image, default: $MIRROR
  -r ROOTFS   Rootfs to use to build the image, default: none
  -s SIZE     Size of the disk image created in GB, default: $SIZE
  -t TYPE     Type of image to build (see below for details), default: $TYPE
  -v VERSION  Release version of Kali, defaults: ${BRANCH#kali-}
  -z          Zip images and metadata files after the build.

Supported values for some options:
  ARCH        $SUPPORTED_ARCHITECTURES
  BRANCH      $SUPPORTED_BRANCHES
  DESKTOP     $SUPPORTED_DESKTOPS
  TYPE        $SUPPORTED_TYPES

The different types of images that can be built are:
  generic     Build a $(b raw) disk image, install all virtualization support packages.
  qemu        Build a $(b qcow2) image, install virtualization support for QEMU.
  virtualbox  Build a $(b ova) image, install virtualization support for VirtualBox.
  rootfs      Build a rootfs (no bootloader/kernel), pack it in a $(b .tar.gz) archive.

Supported environment variables:
  http_proxy  HTTP proxy URL, refer to the README for more details.
"

while getopts ":a:b:d:hm:r:s:t:v:z" opt; do
    case $opt in
        (a) ARCH=$OPTARG ;;
        (b) BRANCH=$OPTARG ;;
        (d) DESKTOP=$OPTARG ;;
        (h) echo "$USAGE" && exit 0 ;;
        (m) MIRROR=$OPTARG ;;
        (r) ROOTFS=$OPTARG ;;
        (s) SIZE=$OPTARG ;;
        (t) TYPE=$OPTARG ;;
        (v) VERSION=$OPTARG ;;
        (z) ZIP=true ;;
        (*) fail "$USAGE" ;;
    esac
done
shift $((OPTIND - 1))

# When building an image from an existing rootfs, ARCH and VERSION are picked
# from the rootfs name. Otherwise it's set either from the command line, or
# from the defaults.
if [ "$ROOTFS" ]; then
    [ $TYPE != rootfs ] \
        || fail "Option -r can only be used to build $(b images)"
    [ -z "$ARCH" ] \
        || fail "Option -a can't be used together with option -r"
    [ -z "$VERSION" ] \
        || fail "Option -v can't be used together with option -r"
    ARCH=$(basename $ROOTFS | cut -d. -f1 | rev | cut -d- -f1 | rev)
    VERSION=$(basename $ROOTFS | sed -E "s/^rootfs-(.*)-$ARCH\..*/\1/")
else
    [ "$ARCH" ] || ARCH=$DEFAULT_ARCH
    [ "$VERSION" ] || VERSION=${BRANCH#kali-}
fi

# Validate build options
echo $SUPPORTED_ARCHITECTURES | grep -qw $ARCH \
    || fail "Unsupported architecture '$ARCH'"
echo $SUPPORTED_BRANCHES | grep -qw $BRANCH \
    || fail "Unsupported branch '$BRANCH'"
echo $SUPPORTED_DESKTOPS | grep -qw $DESKTOP \
    || fail "Unsupported desktop '$DESKTOP'"
echo $SUPPORTED_TYPES | grep -qw $TYPE \
    || fail "Unsupported type '$TYPE'"

[[ $SIZE =~ ^[0-9]+$ ]] && SIZE=${SIZE}GB \
    || fail "Size must be given in GB and must contain only digits"

# Attempt to detect well-known http caching proxies on localhost,
# cf. bash(1) section "REDIRECTION". This is not bullet-proof.
echo "# Proxy configuration:"
if ! [ -v http_proxy ]; then
    while read port proxy; do
        (</dev/tcp/localhost/$port) 2>/dev/null || continue
        echo "Detected caching proxy $(b $proxy) on port $(b $port)."
        export http_proxy="http://10.0.2.2:$port"
        break
    done <<< "$WELL_KNOWN_PROXIES"
fi
if [ "${http_proxy:-}" ]; then
    echo "Using a proxy via env variable: $(b http_proxy=$http_proxy)."
else
    echo "No http proxy configured, all packages will be downloaded from Internet."
fi

# Print a summary of the build options
echo "# Build options:"
if [ $TYPE = rootfs ]; then
    echo "Build a Kali $(b $TYPE) for the $(b $ARCH) architecture."
    echo "Get packages from the $(b $BRANCH) branch, from mirror $(b $MIRROR)."
    echo "Install the $(b $DESKTOP) desktop environment."
elif [ "$ROOTFS" ]; then
    echo "Build a Kali $(b $TYPE) image based on $(b $ROOTFS). Disk size: $(b $SIZE)."
else
    echo "Build a Kali $(b $TYPE) image for the $(b $ARCH) architecture. Disk size: $(b $SIZE)."
    echo "Get packages from the $(b $BRANCH) branch, from mirror $(b $MIRROR)."
    echo "Install the $(b $DESKTOP) desktop environment."
fi

# Ask for confirmation before starting the build
ask_confirmation || fail "Abort."

# XXX Size required shouldn't change, but user should be allowed to decide
# whether they want to use RAM or DISK . Default should be disk, while RAM
# shouldn't be allowed if not enough free RAM.

mkdir -p images

OPTS="-m 4G --scratchsize=16G"

if [ $TYPE = rootfs ]; then
    echo "Building rootfs from recipe $(b rootfs.yaml) ..."
    ROOTFS=images/rootfs-$VERSION-$ARCH.tar.gz
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t mirror:$MIRROR \
        -t rootfs:$ROOTFS \
        rootfs.yaml
    exit 0
fi

IMAGE=images/kali-linux-$VERSION-$TYPE-$ARCH

if [ "$ROOTFS" ]; then
    echo "Building image from recipe $(b image.yaml) ..."
    debos $OPTS \
        -t arch:$ARCH \
        -t imagename:$IMAGE \
        -t rootfs:$ROOTFS \
        -t size:$SIZE \
        -t type:$TYPE \
        -t zip:$ZIP \
        image.yaml
else
    echo "Building image from recipe $(b full.yaml) ..."
    debos $OPTS \
        -t arch:$ARCH \
        -t branch:$BRANCH \
        -t desktop:$DESKTOP \
        -t imagename:$IMAGE \
        -t mirror:$MIRROR \
        -t size:$SIZE \
        -t type:$TYPE \
        -t zip:$ZIP \
        full.yaml
fi
