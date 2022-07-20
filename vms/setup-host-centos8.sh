#!/usr/bin/bash
# Reference: https://seekstar.github.io/2021/01/21/%E5%9C%A8%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%94%A8qemu%E5%88%B6%E4%BD%9C%E8%99%9A%E6%8B%9F%E6%9C%BA/
# Reference: https://www.jianshu.com/p/5af449e07c11?u_atoken=ec747037-b1c6-4ca9-b761-7c66213a590a&u_asession=01Fdh7eOjsqF2_beEkWK6zM_AJze4xovkw9jvRZqbrjeIg3OSQOe-NvtFqrG2Ba6tSX0KNBwm7Lovlpxjd_P_q4JsKWYrT3W_NKPr8w6oU7K8yf-LM3IvfW36jXP8p0RCkPpcarp92QKzyJKyYjREPlmBkFo3NEHBv0PZUm6pbxQU&u_asig=05EMpCYTQwkHLvyfViyF1-fGhWwguBZ95LodJBmLKP8-8H9SDg3_4_g7xRtb31thRUv5zhQQTiN4n90CWnRMvVguTR2aSbopbubvFNdPvDW4Z-6zuf-QoTkQIpMnUupjSg5INdrdBFpZqwKccSGRgN80QUZO7fyGwII7Wfw3qo_tf9JS7q8ZD7Xtz2Ly-b0kmuyAKRFSVJkkdwVUnyHAIJzcs5dXLxbXDV2MNaW56t3CbCbZBkeKdZ-UZIpZv3l7cJWPRPQyB_SKrj-61LB_f61u3h9VXwMyh6PgyDIVSG1W9qtZzdrk6SC-Rw_8RMQYXmKtBp_GYAoTfNrX2yA44vCgTcESBodKu_xdZAhK1EtmM3l7_K8K2DzgVxMbj-qdO9mWspDxyAEEo4kbsryBKb9Q&u_aref=lC8Q4NNFH62S3fRDnmXlgyG5VTI%3D
# Reference: https://blog.csdn.net/Ming2017123123/article/details/102657098

function download_OS () {
    mkdir -p ~/Downloads/ISOs
    mkdir -p ~/Downloads/DISKs
    cd ~/Downloads/ISOs || exit
    if [ ! -f "CentOS-Stream-8-x86_64-20220712-dvd1.iso" ]; then
        wget http://mirrors.ustc.edu.cn/centos/8-stream/isos/x86_64/CentOS-Stream-8-x86_64-20220712-dvd1.iso
    fi
    cd - || exit
}

function install_prerequisite () {
    sudo yum install qemu-kvm
    sudo yum install libvirt virt-install
}

function enable_kvm() {
    if test ! -z "$(lsmod | grep kvm)"; then
        echo "KVM is already enabled."
    else
        if ! modprobe kvm-intel; then
            echo "KVM install failed. See more at: https://seekstar.github.io/2021/01/21/%E5%9C%A8%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%94%A8qemu%E5%88%B6%E4%BD%9C%E8%99%9A%E6%8B%9F%E6%9C%BA/"
            echo "Output message: "
            dmesg | grep kvm
            exit 1
        fi
    fi
}

function install_OS () {
    cd ~ || exit
    home_path=$(pwd)
    cd - || exit

    # Fail, Why?
    sudo virsh net-start default
    sudo virsh net-autostart default
    
    sudo virt-install --name=centos8 --memory=2048 --vcpus=4 --os-type=linux --accelerate --os-variant=rhel8.4 --location="$home_path"/Downloads/ISOs/CentOS-Stream-8-x86_64-20220712-dvd1.iso --disk path="$home_path"/Downloads/DISKs/centos.img,size=1 --graphics=none --console=pty,target_type=serial --extra-args="console=tty0 console=ttyS0"
}

install_prerequisite
enable_kvm
download_OS
install_OS