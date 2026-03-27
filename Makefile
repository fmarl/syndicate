BINDIR = @bindir@
SRC=$(shell ls boot.nasm)
OBJ=$(shell ls boot.nasm | sed -e 's/nasm/bin/')
IMAGE_NAME = test

all: compile
	@echo "[1] Done."

compile: ${OBJ}
	@echo "[0] Compiling loader.bin"

${OBJ}: ${SRC}
	@nasm -f bin $< -o loader.bin

# Build Hadron Stage 2 bootloader
.PHONY: hadron-stage2
hadron-stage2:
	@echo "[*] Building Hadron Stage 2 bootloader"
	$(MAKE) -C hadron stage2

# Create bootable test image with Syndicate + Hadron
.PHONY: image
image: compile hadron-stage2
	@echo "[*] Creating bootable test image"
	@rm -f $(IMAGE_NAME).img
	@dd if=/dev/zero of=$(IMAGE_NAME).img bs=1M count=32
	@dd if=loader.bin of=$(IMAGE_NAME).img conv=notrunc bs=512 count=1
	@mformat -i $(IMAGE_NAME).img@@1M -F -v "HADRON" ::
	@mcopy -i $(IMAGE_NAME).img@@1M hadron/boot/KERNEL.BIN ::/KERNEL.BIN
	@echo "[*] Test image created: $(IMAGE_NAME).img"

# Run test image in QEMU
.PHONY: run
run: image
	@echo "[*] Starting QEMU"
	qemu-system-x86_64 -drive file=$(IMAGE_NAME).img,format=raw -m 128M

.PHONY: clean install

install:
	install -d $(BINDIR)
	install -t $(BINDIR) loader.bin

clean:
	@echo "Cleaning"
	@rm -rf *.bin *.o *.img
	@if [ -d hadron ]; then $(MAKE) -C hadron clean; fi
