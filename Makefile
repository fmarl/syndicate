NASM		?= nasm
PREFIX		?= /usr/local
DATADIR		?= $(PREFIX)/share/syndicate

STAGE2_FILE	?= STAGE2.BIN
KERNEL_FILE	?= KERNEL.BIN

IMAGE		= test.img
IMAGE_MB	= 64
PART_START	= 2048
PART_OFFSET	= $$(( $(PART_START) * 512 ))
PART_SIZE	= $$(( $(IMAGE_MB) * 2048 - $(PART_START) ))

LOADER		= loader.bin
SRCS		= boot.nasm print.nasm disk.nasm a20.nasm fat32.nasm fio.nasm

# Rebuild when the file names change
CONFIG		= .build-config
CONFIG_VAL	= $(STAGE2_FILE) $(KERNEL_FILE)
$(shell echo '$(CONFIG_VAL)' | cmp -s - $(CONFIG) || echo '$(CONFIG_VAL)' > $(CONFIG))

.PHONY: all image run install clean

all: $(LOADER)

$(LOADER): $(SRCS) $(CONFIG)
	$(NASM) -f bin -o $@ \
		-DSTAGE2_FILE='"$(STAGE2_FILE)"' -DKERNEL_FILE='"$(KERNEL_FILE)"' \
		boot.nasm

image: $(LOADER)
	@test -n "$(STAGE2)" -a -n "$(KERNEL)" || \
		{ echo "usage: make image STAGE2=<file> KERNEL=<file>"; exit 1; }
	rm -f $(IMAGE)
	dd if=/dev/zero of=$(IMAGE) bs=1M count=$(IMAGE_MB) status=none
	echo 'start=$(PART_START), type=c, bootable' | sfdisk -q $(IMAGE)
	mformat -i $(IMAGE)@@$(PART_OFFSET) -F -T $(PART_SIZE) -v SYNDICATE ::
	mcopy -i $(IMAGE)@@$(PART_OFFSET) $(STAGE2) ::/$(STAGE2_FILE)
	mcopy -i $(IMAGE)@@$(PART_OFFSET) $(KERNEL) ::/$(KERNEL_FILE)
	dd if=$(LOADER) of=$(IMAGE) bs=446 count=1 conv=notrunc status=none
	dd if=$(LOADER) of=$(IMAGE) bs=512 skip=1 seek=1 conv=notrunc status=none

run: image
	qemu-system-x86_64 -drive file=$(IMAGE),format=raw -m 128M

install: $(LOADER)
	install -d $(DESTDIR)$(DATADIR)
	install -m 644 $(LOADER) $(DESTDIR)$(DATADIR)

clean:
	rm -f $(LOADER) $(IMAGE) $(CONFIG)
