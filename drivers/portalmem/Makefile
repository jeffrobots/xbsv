obj-m += portalmem.o

export KROOT=$(DEVICE_XILINX_KERNEL)

DRIVER_VERSION=$(shell git log -n 1 --oneline -- portalmem.c portalmem.h)

ccflags-y := -D DRIVER_VERSION_RAW="$(DRIVER_VERSION)"

default: portalmem.ko
	cp portalmem.ko ~/adb_scripts/

portalmem.ko: portalmem.h portalmem.c
	@$(MAKE) ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- -C $(KROOT) xilinx_zynq_portal_defconfig
	@$(MAKE) ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- -C $(KROOT) oldconfig
	@$(MAKE) -j 8 ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- -C $(KROOT) zImage
	@$(MAKE) ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- -C $(KROOT) M=$(PWD) DRIVER_VERSION="$(DRIVER_VERSION)" modules

clean:
	@$(MAKE) ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- -C $(KROOT) M=$(PWD) clean
