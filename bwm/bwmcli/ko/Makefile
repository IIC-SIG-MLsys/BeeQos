CONFIG_MODULE_SIG=n

obj-m := bwm.o

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

LINUX_VER ?= $(shell ls /usr/src/ | grep linux)
USERSRC ?= /usr/src/$(LINUX_VER)
EXTRA_CFLAGS = -I$(USERSRC)

all:
	$(MAKE) -C $(KERNELDIR) M=$(PWD)
clean:
	@rm -rf *.o *.mod *.mod.c *.mod.o *.ko *.order *.symvers .*.cmd

