#!/bin/bash
set -x

RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"

#init ksu next
git submodule init && git submodule update

#requirements
sudo apt-get update && sudo apt-get install cpio

#proton-12
if [ ! -d "toolchain" ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang -b master toolchain
fi

#export clang
export PATH=$PATH:"${RDIR}/toolchain/bin"

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

#kernelversion
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

#setting up localversion
echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-ravindu644-${BUILD_KERNEL_VERSION}\"\n" > "${RDIR}/arch/arm64/configs/version.config"

#path for binary files
export dt_tool="$RDIR/binaries"
export repacker="$dt_tool/AIK/repackimg.sh"
export VBMETA="$dt_tool/addons/vbmeta.img"

#OEM variabls
export ARCH=arm64
export PLATFORM_VERSION=12
export ANDROID_MAJOR_VERSION=s

#main variables
export ARGS="
CC=clang
LD=ld.lld
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_ARM32=arm-linux-gnueabi-
CLANG_TRIPLE=aarch64-linux-gnu-
AR=llvm-ar
NM=llvm-nm
AS=llvm-as
READELF=llvm-readelf
OBJCOPY=llvm-objcopy
OBJDUMP=llvm-objdump
OBJSIZE=llvm-size
STRIP=llvm-strip
LLVM_AR=llvm-ar
LLVM_DIS=llvm-dis
LLVM_NM=llvm-nm
LLVM=1
"

#building function
build_ksu(){
    make ${ARGS} exynos9820-d1_defconfig custom.config
    make ${ARGS} menuconfig || true
    make ${ARGS} || exit 1
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/arch/arm64/boot/Image" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    mkdir -p ${RDIR}/AIK-Linux/ramdisk/{debug_ramdisk,dev,metadata,mnt,proc,second_stage_resources,sys}
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

dtb_img() {
    $dt_tool/mkdtimg cfg_create "$RDIR/build/dt.img" "$dt_tool/exynos9825.cfg" -d "$RDIR/arch/arm64/boot/dts/exynos"
}

#build odin flashable tar
build_tar(){
    cp ${RDIR}/prebuilt-images/* ${RDIR}/build && cp "${VBMETA}" ${RDIR}/build && cd ${RDIR}/build
    tar -cvf "KernelSU-Next-NOTE-10-${BUILD_KERNEL_VERSION}.tar" boot.img dt.img vbmeta.img && rm boot.img dt.img vbmeta.img
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

clear

echo -e "[!] Building a KernelSU enabled kernel...\n"
build_ksu
build_boot
dtb_img
build_tar
