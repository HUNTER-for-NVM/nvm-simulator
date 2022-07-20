#!/usr/bin/bash

bzimage_path=$1
initramfs_path=$2
debug_on=$3

echo "Run GDB vmlinux in another terminal. Press Ctrl + A + X to stop"

if [ ! "$debug_on" ]; then
    qemu-system-x86_64 \
    -kernel "$bzimage_path" \
    -nographic \
    -smp 32 \
    -initrd "$initramfs_path" \
    -append "root=/dev/ram rdinit=/sbin/init console=ttyS0 nokaslr memmap=16G!16G" \
    -m 32G
else
    qemu-system-x86_64 \
    -kernel "$bzimage_path" \
    -nographic \
    -smp 32 \
    -initrd "$initramfs_path" \
    -append "root=/dev/ram rdinit=/sbin/init console=ttyS0 nokaslr memmap=16G!16G" \
    -s -S \
    -m 32G
fi

