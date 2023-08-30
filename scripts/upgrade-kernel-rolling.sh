#!/bin/sh

set -eu

export DEBIAN_FRONTEND=noninteractive

# Do nothing if we're already building a kali-rolling image
if grep -q kali-rolling /etc/apt/sources.list; then
    exit 0
fi

# Otherwise, add kali-rolling and install the kernel from there
sed 's/kali-last-snapshot/kali-rolling/' /etc/apt/sources.list >> /etc/apt/sources.list
apt-get update
apt-get install -y linux-image-generic
apt-get purge   -y linux-image-6.3.0-kali1-amd64
apt-get clean
sed -i '/kali-rolling/d' /etc/apt/sources.list
