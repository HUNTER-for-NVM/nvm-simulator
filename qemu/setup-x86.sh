#!/usr/bin/bash
# Reference: https://blog.csdn.net/weixin_44465434/article/details/121194613?spm=1001.2014.3001.5502
# Reference: https://seekstar.github.io/2020/12/28/%E7%BC%96%E8%AF%91%E5%AE%89%E8%A3%85linux%E5%86%85%E6%A0%B8/

abs_path=$(cd "$(dirname "$0")"; pwd)
download_path=$abs_path/downloads
builds_path=$abs_path/builds
scripts_path=$abs_path/scripts

function install_QEMU () {
    if ! qemu-system-x86_64 --version > /dev/null; then
        mkdir -p "$download_path"/QEMU
        cd "$download_path"/QEMU || exit
        wget https://download.qemu.org/qemu-5.1.0.tar.xz
        tar xvJf qemu-5.1.0.tar.xz
        cd qemu-5.1.0 || exit
        ./configure --disable-kvm --disable-werror --prefix=/usr/local --target-list="x86_64-softmmu" --enable-libpmem
        make -j"$(nproc)"
        make install
    fi
    qemu-system-x86_64 --version
}

function config_and_build_kernel () {
    cd "$download_path"/Kernel/linux-5.18-rc4 || exit
    if [ ! -f ".config" ]; then
        make ARCH=x86_64 defconfig

        ./scripts/config -e CONFIG_X86_PMEM_LEGACY_DEVICE
        ./scripts/config -e CONFIG_X86_PMEM_LEGACY
        
        ./scripts/config -e CONFIG_ARCH_ENABLE_MEMORY_HOTREMOVE
        ./scripts/config -e CONFIG_ARCH_ENABLE_THP_MIGRATION
        ./scripts/config -e CONFIG_MEMORY_ISOLATION
        ./scripts/config -e CONFIG_HAVE_BOOTMEM_INFO_NODE
        ./scripts/config -e CONFIG_MEMORY_HOTPLUG
        ./scripts/config -e CONFIG_MEMORY_HOTPLUG_SPARSE
        ./scripts/config -e CONFIG_MEMORY_HOTREMOVE

        ./scripts/config -e CONFIG_TRANSPARENT_HUGEPAGE
        ./scripts/config -e CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
        ./scripts/config -e CONFIG_ZONE_DEVICE
        ./scripts/config -e CONFIG_ARCH_HAS_HMM
        ./scripts/config -e CONFIG_DEV_PAGEMAP_OPS

        ./scripts/config -e CONFIG_LIBNVDIMM
        ./scripts/config -e CONFIG_NVDIMM_PFN
        ./scripts/config -e CONFIG_NVDIMM_DAX
        ./scripts/config -e CONFIG_DAX_DRIVER
        ./scripts/config -e CONFIG_DAX
        ./scripts/config -e CONFIG_DEV_DAX
        ./scripts/config -m CONFIG_DEV_DAX_PMEM
        ./scripts/config -e CONFIG_DEV_DAX_KMEM
        ./scripts/config -m CONFIG_DEV_DAX_PMEM_COMPAT
        ./scripts/config -e CONFIG_FS_DAX
        ./scripts/config -e CONFIG_FS_DAX_PMD

        ./scripts/config -e CONFIG_ARCH_HAS_GIGANTIC_PAGE
        ./scripts/config -e CONFIG_LIBCRC32C

        ./scripts/config -e CONFIG_GDB_SCRIPTS
        ./scripts/config -e CONFIG_DEBUG_INFO
        ./scripts/config -e CONFIG_DEBUG_SECTION_MISMATCH
        ./scripts/config -e CONFIG_FRAME_POINTER 
        ./scripts/config -d CONFIG_RANDOMIZE_BASE
        # KaSan
        ./scripts/config -e CONFIG_SLUB_DEBUG
        ./scripts/config -e CONFIG_KASA
    fi
    make -j"$(nproc)"
    cd - || exit
}

function build_and_install_static_bin () {
    cd "$abs_path" || exit
    mkdir -p "$builds_path"
    cd "$builds_path" || exit
    bash "$scripts_path"/build.sh
    cd "$abs_path" || exit
    cd "$builds_path" || exit
    bash "$scripts_path"/install.sh "$download_path"/RootFS/initramfs
    cd "$abs_path" || exit
}

function craft_root_fs () {
    mkdir -p "$download_path"/RootFS
    cd "$download_path"/RootFS || exit
    git clone https://github.com/Deadpoolmine/auto-make-rootfs.git
    cd auto-make-rootfs || exit
    make defconfig
    ./scripts/config -e STATIC
    make -j"$(nproc)" 
    make install
    cp _install ../initramfs -r 
    cd ../initramfs || exit
    mkdir -p proc sys dev etc lib share
    mkdir -p etc/init.d
    touch etc/init.d/rcS
    echo """
    #!bin/sh
    mount -t proc none /proc
    mount -t sysfs none /sys
    /sbin/mdev -s	# 扫描并填充/dev文件夹
    """ > etc/init.d/rcS
    chmod +x etc/init.d/rcS
    
    # build and install
    build_and_install_static_bin
    
    cd "$download_path"/RootFS/initramfs || exit
    
    find . -print0 | cpio --null -ov --format=newc > ../initramfs.cpio
    cd .. && ls
}

function download_kernel() {
    mkdir -p "$download_path"/Kernel
    if [ ! -d "$download_path"/Kernel/linux-5.18-rc4 ]; then    
        cd "$download_path"/Kernel || exit
        wget https://github.com/torvalds/linux/archive/refs/tags/v5.18-rc4.tar.gz
        tar -zxvf v5.18-rc4.tar.gz
        cd - || exit
    fi
}

function start_qemu () {
    bash "$scripts_path"/start.sh "$download_path"/Kernel/linux-5.18-rc4/arch/x86_64/boot/bzImage "$download_path"/RootFS/initramfs.cpio "$1"
}

function usage () {
    echo "Usage: $0 -d -g -r [k|rf|all]"
    echo " -d: Download QEMU and linux-5.18-rc4"
    echo " -g: QEMU GDB ON"
    echo " -r: [k|rf|all]"
    echo "  [k]:   build kernel"
    echo "  [rf]:  build rootfs"
    echo "  [all]: build kernel and craft rootfs"
    exit 0
}

debug_on=""

while getopts "dr:gh" arg #选项后面的冒号表示该选项需要参数
do
    case $arg in
        d)
        echo "Download QEMU and linux-5.18-rc4" #参数存在$OPTARG中
        install_QEMU
        download_kernel
        ;;
        g)
        echo "QEMU GDB ON"
        debug_on="-g"
        ;;
        r)
        if [[ "$OPTARG" == "k" ]]; then
            echo "Build Kernel"
            config_and_build_kernel
        fi

        if [[ "$OPTARG" == "rf" ]]; then
            echo "RootFS"
            craft_root_fs
        fi

        if [[ "$OPTARG" == "all" ]]; then
            echo "Build Kernel and Craft RootFS"
            config_and_build_kernel
            craft_root_fs
        fi
        ;;
        h)
        usage
        ;;
        ?) 
        echo "Unkonw argument"
        usage
        exit 1
        ;;
    esac
done

start_qemu "$debug_on"