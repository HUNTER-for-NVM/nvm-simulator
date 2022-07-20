#!/usr/bin/bash

# Cur Dir = Builds

initramfs_path=$1 

function install_fio () {
    cp fio_build/bin/fio "$initramfs_path"/bin/fio
}

function install_filebench () {
    cp filebench_build/bin/filebench "$initramfs_path"/bin/filebench
    cp filebench_build/lib/* "$initramfs_path"/lib/
    cp filebench_build/share/filebench -r "$initramfs_path"/share/
}

install_fio
install_filebench