XBSV
====

The script genxpsprojfrombsv enables you to take a Bluespec System
Verilog (BSV) file and generate a bitstream for a Xilinx Zynq FPGA. 

It generates C++ and BSV stubs so that you can write code that runs on
the Zynq's ARM CPUs to interact with your BSV componet.

Preparation
-----------

1. Get Vivado 2013.2

Preparation for Zynq
--------------------

1. Download ndk toolchain from: 
     http://developer.android.com/tools/sdk/ndk/index.html
     (actual file might be:
         http://dl.google.com/android/ndk/android-ndk-r8e-linux-x86_64.tar.bz2
     )
2. Get the Zynq Base TRD files, which will contain zynq_fsbl.elf and u-boot.elf
     See: http://www.wiki.xilinx.com/Zynq+Base+TRD+14.3
     (this will require a xilinx login)
   Or:
      git clone git://github.com/cambridgehackers/zynq-axi-blue.git

Setting up the SD Card
----------------------

1. Download http://xbsv.googlecode.com/files/sdcard-130611.tar.bz
2. tar -jxvf sdcard-130611.tar.bz

Currently, all files must be in the first partition of an SD card.

3. Copy files
   cd sdcard-130611
   cp boot.bin devicetree.dtb ramdisk8M.image.gz zImage system.img /media/zynq
   cp empty.img /media/zynq/userdata.img

Eject the card and plug it into the zc702 and boot.

Preparation for PCIe
--------------------

1. Build the drivers

    cd drivers/pcie; make

2. Load the drivers

    cd drivers/pcie; make insmod

3. Install the Digilent cable driver
   cd /scratch/Xilinx/Vivado/2013.2/data/xicom/cable_drivers/lin64/digilent
   sudo ./install_digilent.sh


Echo Example
------------

    ## this has only been tested with the Vivado 2013.2 release
    . Xilinx/Vivado/2013.2/settings64.sh

    BOARD=zedboard make -C examples/echo
or
    BOARD=zc702 make -C examples/echo
or
    BOARD=kc705 make -C examples/echo
or
    BOARD=vc707 make -C examples/echo

To run on a zedboard with IP address aa.bb.cc.dd:
    RUNPARAM=aa.bb.cc.dd make echo.zedrun

Memcpy Example
--------------

    BOARD=vc707 make -C examples/memcpy


LoadStore Example
------------

    ## this has only been tested with the Vivado 2013.2 release
    . Xilinx/Vivado/2013.2/settings64.sh

    ./genxpsprojfrombsv -B kc705 -p loadstoreproj -b LoadStore examples/loadstore/LoadStore.bsv
or
    ./genxpsprojfrombsv -B vc707 -p loadstoreproj -b LoadStore examples/loadstore/LoadStore.bsv

    cd loadstoreproj; make verilog implementation

    ## building the test executable
    cd loadstoreproj/jni; make

    ## to install the bitfile
    make program

    ## run the example
    ./loadstoreproj/jni/loadstore

ReadBW
------

    ./genxpsprojfrombsv -B vc707 -p readbwproj -b ReadBW examples/readbw/ReadBW.bsv
or
    ./genxpsprojfrombsv -B kc705 -p readbwproj -b ReadBW examples/readbw/ReadBW.bsv


HDMI Example
------------

For example, to create an HDMI frame buffer from the example code:

To generate code for Zedboard:
    make hdmidisplay.zedboard

To generate code for a ZC702 board:
    make hdmidisplay.zc702

The result .bit file for this example will be:

    examples/hdmi/zedboard/hw/mkHdmiZynqTop.bit.bin.gz

Sending the bitfile:
    adb push mkHdmiZynqTop.bit.bin.gz /mnt/sdcard

Loading the bitfile on the device:
    mknod /dev/xdevcfg c 259 0
    cat /sys/devices/amba.0/f8007000.devcfg/prog_done
    zcat /mnt/sdcard/mkHdmiZynqTop.bit.bin.gz > /dev/xdevcfg
    cat /sys/devices/amba.0/f8007000.devcfg/prog_done
    chmod agu+rwx /dev/fpga0

On the zedboard, configure the adv7511:
   echo RGB > /sys/bus/i2c/devices/1-0039/format
On the zc702, configure the adv7511:
   echo RGB > /sys/bus/i2c/devices/0-0039/format

Restart surfaceflinger:
   stop surfaceflinger; start surfaceflinger

Sometimes multiple restarts are required.

Imageon Example
---------------

This is an example using the Avnet Imageon board and ZC702 (not tested with Zedboard yet):

To generate code for a ZC702 board:
    ./genxpsprojfrombsv  -B zc702 -p fooproj -x HDMI -x ImageonVita -b ImageCapture examples/imageon/ImageCapture.bsv bsv/BlueScope.bsv bsv/PortalMemory.bsv bsv/AxiSDma.bsv bsv/Imageon.bsv bsv/IserdesDatadeser.bsv bsv/HDMI.bsv

Test program:
    cp examples/imageon/testimagecapture.cpp fooproj/jni
    cp examples/imageon/i2c*h fooproj/jni
    ndk-build -C fooproj

Installation
------------

Install the bluespec compiler. Make sure the BLUESPECDIR environment
variable is set:
    export BLUESPECDIR=~/bluespec/Bluespec-2012.10.beta2/lib
	
Install the python-ply package, e.g.,

    sudo apt-get install python-ply

PLY's home is http://www.dabeaz.com/ply/

Zynq Portal Driver
-------------

To Build the zynq portal driver, Makefile needs to be pointed to the root of the kernel source tree:
   export DEVICE_XILINX_KERNEL=/scratch/mdk/device_xilinx_kernel/

The driver sources are located in the xbsv project:
   (cd drivers/zynqportal/; DEVICE_XILINX_KERNEL=`pwd`/../../../device_xilinx_kernel/ make zynqportal.ko)
   (cd drivers/portalmem/;  DEVICE_XILINX_KERNEL=`pwd`/../../../device_xilinx_kernel/ make portalmem.ko)
   adb push drivers/zynqportal/zynqportal.ko /mnt/sdcard
   adb push drivers/portalmem/portalmem.ko /mnt/sdcard

To update the zynq portal driver running on the Zync platform, set ADB_PORT appropriately and run the following commands:
   adb -s $ADB_PORT push zynqportal.ko /mnt/sdcard/
   adb -s $ADB_PORT shell "cd /mnt/sdcard/ && uname -r | xargs rm -rf"
   adb -s $ADB_PORT shell "cd /mnt/sdcard/ && uname -r | xargs mkdir"
   adb -s $ADB_PORT shell "cd /mnt/sdcard/ && uname -r | xargs mv zynqportal.ko"
   adb -s $ADB_PORT shell "modprobe -r zynqportal"
   adb -s $ADB_PORT shell "modprobe zynqportal"

Zynq Hints
-------------

To remount /system read/write:
    mount -o rw,remount /dev/block/mmcblk0p1 /system


