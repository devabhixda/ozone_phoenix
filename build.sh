#!/usr/bin/env bash

# Copyright (C) 2018-19 Akhil Narang
# SPDX-License-Identifier: GPL-3.0-only
# Kernel build script

# shellcheck disable=SC1090
# SC1090: Can't follow non-constant source. Use a directive to specify location.

KERNELDIR="/home/devabhi/kernel"
DEVICE=phoenix
# These won't change
export SRCDIR="${KERNELDIR}/${DEVICE}"
export OUTDIR="${KERNELDIR}/${DEVICE}/obj"
export ANYKERNEL="${KERNELDIR}/AnyKernel3"
export ARCH="arm64"
CCACHE="$(command -v ccache)"
export CLANG_DIR="${KERNELDIR}/clang"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CC="${CLANG_DIR}/bin/clang"
KBUILD_COMPILER_STRING=$(${CC} --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
export GCC_DIR="${KERNELDIR}/aarch64-linux-android-4.9"
CROSS_COMPILE="$GCC_DIR/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="${KERNELDIR}/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-"
export DEFCONFIG="${DEVICE}_defconfig"
export ZIP_DIR="/home/devabhi/ftp/Ozone"
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz"
export DTBO="${OUTDIR}/arch/${ARCH}/boot/dtbo.img"
export DTB="${OUTDIR}/arch/${ARCH}/boot/dts/qcom/sdmmagpie.dtb"
if [[ -z ${JOBS} ]]; then
    JOBS="$(grep -c '^processor' /proc/cpuinfo)"
fi
export DEVICE CCACHE KBUILD_COMPILER_STRING JOBS CROSS_COMPILE

function make_wrapper() {
    time make -j"${JOBS}" \
        O="${OUTDIR}" \
        ARCH="${ARCH}" \
        CC="${CCACHE} ${CC}" \
        CLANG_TRIPLE="${CLANG_TRIPLE}" \
        CROSS_COMPILE="${CROSS_COMPILE}" \
        CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
        "${@}"
}

export NAME="Ozone"
NAME="${NAME}-${DEVICE}-$(date +%Y%m%d-%H%M)"
export NAME
export ZIPNAME="${NAME}.zip"
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"

[ ! -d "${ZIP_DIR}" ] && mkdir -pv "${ZIP_DIR}"
[ ! -d "${OUTDIR}" ] && mkdir -pv "${OUTDIR}"

cd "${SRCDIR}" || exit
rm -fv "${IMAGE}"

$mkdtbs && make_flag="dtbs" || make_flag=""

make_wrapper $DEFCONFIG || (echo "Failed to build with ${DEFCONFIG}, exiting!" &&
    exit 1)

START=$(date +"%s")
[[ $* =~ "upload" ]] && tg "Building!"
if [[ $* =~ "quiet" ]]; then
    make_wrapper |& ag -ia "error:|warning:"
else
    make_wrapper
fi
END=$(date +"%s")
DIFF=$((END - START))
echo -e "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."
[[ $* =~ "upload" ]] && tg "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."

if [[ ! -f ${IMAGE} ]]; then
    echo -e "Build failed :P"
    [[ $* =~ "upload" ]] && tg "Build failed!"
    exit 1
else
    echo -e "Build Succesful!"
fi

echo -e "Copying kernel image"
cp -v "${IMAGE}" "${ANYKERNEL}/"
cp -v "${DTBO}" "${ANYKERNEL}/"
cp -v "${DTB}" "${ANYKERNEL}/dtb"
cd - || exit
cd "${ANYKERNEL}" || exit
zip -r9 "${FINAL_ZIP}" ./* -x ".git/*" "README.md" ".gitignore" "*.zip"
cd - || exit

if [ -f "$FINAL_ZIP" ]; then
    echo -e "$NAME zip can be found at $FINAL_ZIP"
else
    echo -e "Zip Creation Failed =("
fi # FINAL_ZIP check
