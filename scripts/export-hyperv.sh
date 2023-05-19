#!/bin/sh

set -eu

SCRIPTSDIR=$RECIPEDIR/scripts
START_TIME=$(date +%s)

info() { echo "INFO:" "$@"; }

image=
keep=0
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -k) keep=1 ;;
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

cd $ARTIFACTDIR

info "Generate $image.vhdx"
qemu-img convert -O vhdx $image.raw $image.vhdx

[ $keep -eq 1 ] || rm -f $image.raw

info "Create install-vm.bat"
cat << 'EOF' > install-vm.bat
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './create-vm.ps1'"
EOF

info "Generate create-vm.ps1"
$SCRIPTSDIR/generate-powershell.sh $image.vhdx create-vm.ps1

if [ $zip -eq 1 ]; then
    info "Compress to $image.7z"
    mkdir $image
    mv $image.vhdx install-vm.bat create-vm.ps1 $image
    7zr a -sdel -mx=9 $image.7z $image
fi

for fn in create-vm.ps1 install-vm.bat $image.*; do
    [ -e $fn ] || continue
    [ $(stat -c %Y $fn) -ge $START_TIME ] && echo $fn
done > .artifacts
