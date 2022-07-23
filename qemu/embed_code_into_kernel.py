#!/usr/bin/env python3
import argparse
from copy import copy
import os
import sys
from enum import Enum
import re
import shutil

class KObject(Enum):
    arch = 1
    block = 2
    certs = 3
    crypto = 4
    drivers = 5
    fs = 6
    init = 7
    kernel = 8
    ipc = 9
    lib = 10
    mm = 11
    net = 12
    security = 13
    sound = 14
    tools = 15
    virt = 16
    
    @staticmethod
    def get_object_by_name(name):
        for k in KObject:
            if k.name == name:
                return k
        return None

class SrcCode(object):
    def __init__(self, code_dir_path, code_object_name) -> None:
        self.code_dir_path = code_dir_path
        self.code_object = KObject.get_object_by_name(code_object_name)
    
    def update_makefile(self, target_dir_path):
        makefile_path = os.path.join(target_dir_path, "Makefile")
        print("makefile_path: " + makefile_path)
        with open(makefile_path, "r") as f:
            lines = f.readlines()
            for i in range(len(lines)):
                line = lines[i]
                if line.startswith("obj-m"):
                    lines[i] = line.replace("obj-m", "obj-y")
            
            lines_copy = copy(lines)
            for line_copy in lines_copy:
                if line_copy.find("make") != -1 or line_copy.find("$(MAKE)") != -1:
                    lines.remove(line_copy)
                if re.match("[a-zA-Z]+:", line_copy, flags = 0):
                    lines.remove(line_copy)
            lines_copy = []
        
        with open(makefile_path, "w") as f:
            f.writelines(lines)

class KernelTree(object):
    def __init__(self, kernel_src_path) -> None:
        self.kernel_src_path = kernel_src_path

    def get_object_path(self, kobj):
        return os.path.join(self.kernel_src_path, kobj.name)

    def incorporate_code_into_kernel(self, src : SrcCode):
        code_dir_path = src.code_dir_path
        code_object = src.code_object
        code_name = os.path.basename(code_dir_path)
        target_dir = self.get_object_path(code_object) + "/" + code_name
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)
        shutil.copytree(code_dir_path, target_dir)
        return target_dir

    def clean_code_from_kernel(self, src : SrcCode):
        self.update_makefile(src, "clean")
        self.incorporate_code_into_kernel(src)
        code_dir_path = src.code_dir_path
        code_object = src.code_object
        code_name = os.path.basename(code_dir_path)
        target_dir = self.get_object_path(code_object) + "/" + code_name
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)

    def update_makefile(self, src : SrcCode, mode = "add"):
        code_dir_path = src.code_dir_path
        code_object = src.code_object
        code_name = os.path.basename(code_dir_path)
        object_path = self.get_object_path(code_object)
        makefile_path = os.path.join(object_path, "Makefile")
        
        if mode == "clean":
            with open(makefile_path, "r") as f:
                lines = f.readlines()
                for line in lines:
                    if line.find(code_name) != -1:
                        lines.remove(line)
                        break
            with open(makefile_path, "w") as f:
                f.writelines(lines)

        elif mode == "add":
            is_exist = False
            with open(makefile_path, "r") as f:
                lines = f.readlines()
                for line in lines:
                    if line.find(code_name) != -1:
                        is_exist = True
                        break
            if not is_exist:
                with open(makefile_path, "a") as f:
                    f.write("obj-y +=" + code_name + "/\n")

parser = argparse.ArgumentParser(description = "Embed code into kernel src")
parser.add_argument("-c", "--code_dir_path", required = True, type = str, help = "Src Code directory that to be embedded. (e.g., kernel modules codes)")
parser.add_argument("-m", "--kernel_object", required = True, type = str, help = "Which directory in Kernel that src code belongs to? (e.g., arch, block, certs, crypto, drivers, fs...)")
parser.add_argument("-k", "--kernel_dir_path", required = True, type = str, help = "Kernel Src directory that to be embedded. (e.g., linux-5.1.0)")
parser.add_argument("-o", type = str, default = "Add", help = "Options: [Add], [Clean]")

args = parser.parse_args()
code_dir_path = args.code_dir_path
code_obj_name = args.kernel_object
kernel_dir_path = args.kernel_dir_path
option = args.o

k_tree = KernelTree(kernel_dir_path)
src_tree = SrcCode(code_dir_path, code_obj_name)

if option == "Add":
    target_dir_path = k_tree.incorporate_code_into_kernel(src_tree)
    k_tree.update_makefile(src_tree, "add")
    src_tree.update_makefile(target_dir_path)
elif option == "Clean":
    k_tree.clean_code_from_kernel(src_tree)
    k_tree.update_makefile(src_tree, "clean")
else:
    print("Invalid option")
    exit(1)
