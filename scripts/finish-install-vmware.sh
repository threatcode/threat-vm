#!/bin/sh

set -e

# XXX Do it with threat-tweaks when it supports non-interactive mode
install /usr/lib/threat_tweaks/data/mount-shared-folders /usr/local/bin/mount-shared-folders
install /usr/lib/threat_tweaks/data/restart-vm-tools /usr/local/bin/restart-vm-tools
