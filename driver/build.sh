#/bin/bash -ne
if [[ `uname -m` != "armv"* ]] && [ -z "${CROSS_COMPILE}" ]; then
	export ARCH=arm
	export CROSS_COMPILE="arm-linux-gnueabi-"
fi

if [ -z "${KERNELDIR}" ]; then
	export KERNELDIR="${HOME}/dev/linux"
fi

make
