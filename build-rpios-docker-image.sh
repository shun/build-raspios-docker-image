#!/bin/bash

# target sources
SRC=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip
QEMUARM=https://github.com/multiarch/qemu-user-static/releases/download/v5.2.0-2/qemu-arm-static

set -e
mkdir -p raspios-tmp
cd raspios-tmp

filename=`basename $SRC`
if [ ! -e $filename ]; then
    echo "Download image..."
    wget --trust-server-names $SRC
fi

DISK_IMG=$(ls *.zip | sed 's/.zip$//')
if [ ! -e $DISK_IMG.img ]; then
    unzip *.zip
fi

OFFSET=$(fdisk -lu $DISK_IMG.img | sed -n "s/\(^[^ ]*img2\)\s*\([0-9]*\)\s*\([0-9]*\)\s*\([0-9]*\).*/\2/p")

mkdir rootfs
sudo  mount -o loop,offset=$(($OFFSET*512)) $DISK_IMG.img rootfs
# Disable preloaded shared library to get everything including networking to work on x86
sudo mv rootfs/etc/ld.so.preload rootfs/etc/ld.so.preload.bak

filename=`basename $QEMUARM`
if [ ! -e $filename ]; then
    echo "Download image..."
    wget $QEMUARM
fi
chmod 755 ./qemu-arm-static
sudo cp ./qemu-arm-static rootfs/usr/bin

# Create docker images
cd rootfs
sudo tar -c . | sudo docker import - kudoshunsuke/raspios-lite-for-x86_64:$DISK_IMG
cd ..

# Clean-up
sudo umount rootfs
rmdir rootfs
rm $DISK_IMG.img
sudo docker images | grep raspios

echo "Test the image with:"
echo "docker run -ti --rm kudoshunsuke/raspios-lite-for-x86_64:$DISK_IMG /bin/bash -c \'uname -a\'"
if docker run -ti --rm kudoshunsuke/raspios-lite-for-x86_64:$DISK_IMG /bin/bash -c 'uname -a' | grep armv7l; then echo OK; else echo FAIL; fi

