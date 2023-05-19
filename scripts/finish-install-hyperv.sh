#!/bin/sh

set -e

# Enable the xrdp services
cd /etc/systemd/system/multi-user.target.wants
ln -s /lib/systemd/system/xrdp.service
ln -s /lib/systemd/system/xrdp-sesman.service

# Configure xrdp
# XXX Do it with kali-tweaks when it supports non-interactive mode
/usr/lib/kali_tweaks/helpers/hyperv-enhanced-mode enable
