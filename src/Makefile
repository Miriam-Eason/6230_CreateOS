all: bootloader.bin kernel.bin disk.img

bootloader.bin: bootloader.asm
	nasm -f bin -o bootloader.bin bootloader.asm

kernel.bin: myos_kernel.asm
	nasm -f bin -o kernel.bin myos_kernel.asm

disk.img: bootloader.bin kernel.bin
	cat bootloader.bin kernel.bin > disk.img
	# 填充到1.44MB软盘大小
	dd if=/dev/zero bs=1 count=1474560 >> disk.img
	dd if=disk.img of=disk.img conv=notrunc

run:
	qemu-system-i386 -fda disk.img -nographic -no-reboot -no-shutdown

clean:
	rm -f *.o *.bin *.img
