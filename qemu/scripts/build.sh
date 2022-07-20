#!/usr/bin/bash
cur_dir=$(pwd)
function build_fio () {
    mkdir -p fio_build
    git clone https://github.com/axboe/fio.git && cd fio || exit
    ./configure --build-static --disable-optimizations --prefix="$cur_dir"/fio_build
    make -j"$(nproc)" && make install
    cd - || exit
}

function build_filebench () {
    mkdir -p filebench_build
    git clone https://github.com/filebench/filebench.git && cd filebench || exit
    libtoolize
    aclocal
    autoheader
    automake --add-missing
    autoconf
    ./configure LDFLAGS="-static -Wl,--gc-sections" CFLAGS="-static -ffunction-sections -fdata-sections" CPPFLAGS="-static-libstdc++" --prefix="$cur_dir"/filebench_build
    orig='$(LIBTOOLFLAGS) --mode=link $(CCLD) $(AM_CFLAGS) $(CFLAGS)'
    new='$(LIBTOOLFLAGS) --mode=link $(CCLD) -all-static $(AM_CFLAGS) $(CFLAGS)'
    sed -i "s/$orig/$new/g" Makefile
    make -j"$(nproc)" && make install
    cd - || exit
}

build_fio
build_filebench