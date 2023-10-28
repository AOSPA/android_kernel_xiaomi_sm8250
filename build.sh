#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck source=/dev/null
#
# Copyright (C) 2020-22 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if ! [ -d "$HOME/tc/aosp-clang" ]; then
echo "aosp clang not found! Cloning..."
if ! git clone -q https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone.git --depth=1 ~/tc/aosp-clang; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "$HOME/tc/aarch64-linux-android-4.9" ]; then
echo "aarch64-linux-android-4.9 not found! Cloning..."
if ! git clone -q https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 --single-branch ~/tc/aarch64-linux-android-4.9; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

GCC_64_DIR="$HOME/tc/aarch64-linux-android-4.9"
KBUILD_COMPILER_STRING=$($HOME/tc/aosp-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
KBUILD_LINKER_STRING=$($HOME/tc/aosp-clang/bin/ld.lld --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' | sed 's/(compatible with [^)]*)//')
export KBUILD_COMPILER_STRING
export KBUILD_LINKER_STRING

DEVICE=$1

if [ "${DEVICE}" = "alioth" ]; then
DEFCONFIG=vendor/alioth_defconfig
elif [ "${DEVICE}" = "apollo" ]; then
DEFCONFIG=vendor/apollo_defconfig
elif [ "${DEVICE}" = "lmi" ]; then
DEFCONFIG=vendor/lmi_defconfig
elif [ "${DEVICE}" = "munch" ]; then
DEFCONFIG=vendor/munch_defconfig
elif [ "${DEVICE}" = "psyche" ]; then
DEFCONFIG=vendor/psyche_defconfig
fi

#
# Enviromental Variables
#

DATE=$(date '+%Y%m%d-%H%M')

# Set our directory
OUT_DIR=out/

VERSION="Uvite-${DEVICE}-${DATE}"

# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
    COUNT="$(grep -c '^processor' /proc/cpuinfo)"
    export KEBABS="$((COUNT + 2))"
fi

echo "Jobs: ${KEBABS}"

ARGS="ARCH=arm64 \
O=${OUT_DIR} \
CC=clang \
LLVM=1 \
LLVM_IAS=1 \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- \
-j${KEBABS}"

dts_source=arch/arm64/boot/dts/vendor/qcom

START=$(date +"%s")

# Set compiler Path
export PATH="$HOME/tc/aosp-clang/bin:$PATH"
export LD_LIBRARY_PATH=${HOME}/tc/aosp-clang/lib64:$LD_LIBRARY_PATH

echo "------ Starting Compilation ------"

# Make defconfig
make -j${KEBABS} ${ARGS} ${DEFCONFIG}

# Make olddefconfig
cd ${OUT_DIR} || exit
make -j${KEBABS} ${ARGS} CC="ccache clang" HOSTCC="ccache gcc" HOSTCXX="cache g++" olddefconfig
cd ../ || exit

make -j${KEBABS} ${ARGS} CC="ccache clang" HOSTCC="ccache gcc" HOSTCXX="ccache g++" 2>&1 | tee build.log

find ${OUT_DIR}/$dts_source -name '*.dtb' -exec cat {} + >${OUT_DIR}/arch/arm64/boot/dtb

git checkout arch/arm64/boot/dts/vendor &>/dev/null

echo "------ Finishing Build ------"

END=$(date +"%s")
DIFF=$((END - START))
zipname="$VERSION.zip"
if [ -f "out/arch/arm64/boot/Image" ] && [ -f "out/arch/arm64/boot/dtbo.img" ] && [ -f "out/arch/arm64/boot/dtb" ]; then
        if [ "${DEVICE}" = "alioth" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b alioth
        elif [ "${DEVICE}" = "apollo" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b apollo
        elif [ "${DEVICE}" = "lmi" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b lmi
        elif [ "${DEVICE}" = "munch" ]; then
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b munch-uvite
        else
          git clone -q https://github.com/madmax7896/AnyKernel3.git -b psyche
	fi
	cp out/arch/arm64/boot/Image AnyKernel3
	cp out/arch/arm64/boot/dtb AnyKernel3
	cp out/arch/arm64/boot/dtbo.img AnyKernel3
	rm -f *zip
	cd AnyKernel3
	zip -r9 "../${zipname}" * -x '*.git*' README.md *placeholder >> /dev/null
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo ""
	echo -e ${zipname} " is ready!"
	echo ""
        curl --upload-file ${zipname} https://free.keep.sh
else
	echo -e "\n Compilation Failed!"
fi
