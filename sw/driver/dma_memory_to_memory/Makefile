ifneq ($(KERNELRELEASE),)
# kbuild part of makefile
obj-m  := dma_mm.o
dma_mm-y := dma_mm_interface.o msgdma/msgdma.o

ccflags-y := -std=gnu89 -g -Wall -Wno-unused-function -Wno-declaration-after-statement -I${SOCEDS_DEST_ROOT}/ip/altera/hps/altera_hps/hwlib/include

else
# normal makefile
#KDIR ?=

# Check this is a Linux platform
ERR_TEXT=This example is intended to be built on a Linux platform, not on Windows.  To debug this example, please build the project in Linux platform first
ifdef WINDIR
#  Building on Windows
$(error $(ERR_TEXT))
endif

ifdef windir
#  Building on Windows
$(error $(ERR_TEXT))
endif

ifeq ($(KDIR),)
ERR_TEXT=Have you untarred your kernel source tree? Please set KDIR to the root of the kernel source
$(error $(ERR_TEXT))
endif 


all:

	$(MAKE) clean
	$(MAKE) -C $(KDIR) M=$$PWD
#ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

clean:
	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c modules.order Module.symvers msgdma/*.o msgdma/.*.cmd
	rm -rf .tmp_versions

endif
