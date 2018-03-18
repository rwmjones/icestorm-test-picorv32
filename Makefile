all: hx8kdemo.bin firmware.bin

%.bin: %.asc
	icepack $< $@

hx8kdemo.asc: hx8kdemo.blif
# The seed that works (for me) was found randomly.  If it doesn't
# place or route, try replacing -s NNN with -r.
	arachne-pnr -s 3692926061 -d 8k -o $@ -p picorv32/picosoc/hx8kdemo.pcf hx8kdemo.blif

hx8kdemo.blif:  picorv32/picosoc/hx8kdemo.v picorv32/picosoc/spimemio.v \
		picorv32/picosoc/simpleuart.v picorv32/picosoc/picosoc.v \
		picorv32/picorv32.v
	yosys -ql hx8kdemo.log -p 'synth_ice40 -top hx8kdemo -blif $@' $^

# Firmware.
firmware.bin: firmware.elf
	riscv32-linux-gnu-objcopy -O binary $< /dev/stdout | \
		tail -c +1048577 > $@

firmware.hex: firmware.elf
	riscv32-linux-gnu-objcopy -O verilog $< /dev/stdout | \
		sed -e '1 s/@00000000/@00100000/; 2,65537 d;' > $@

firmware.elf: picorv32/picosoc/sections.lds picorv32/picosoc/start.s \
	      picorv32/picosoc/firmware.c
	riscv32-linux-gnu-gcc -march=rv32imc -mabi=ilp32 \
		-Wl,-Bstatic \
		-Wl,-T,picorv32/picosoc/sections.lds \
		-Wl,--strip-debug \
		-Wl,--build-id=none \
		-ffreestanding -nostdlib \
		-o $@ picorv32/picosoc/start.s picorv32/picosoc/firmware.c

# Program the bitstring to the board.
# NB for this to work as a non-root user, you must add this
# udev rule in file /etc/udev/rules.d/53-lattice-ftdi.rules
# ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0660", GROUP="plugdev", TAG+="uaccess"
prog: hx8kdemo.bin firmware.bin
	iceprog $<
	iceprog -o 1M firmware.bin

clean:
	rm -f *.bin *.elf *.hex *.asc *.blif *.log
	rm -f *~
