
DONE_MASK=0x00000002
tool_path=/opt/xilinx/dma_ip_drivers/XDMA/linux-kernel/tools
isDone=0

read_reg_value() {
	local addr=$1
	sudo ${tool_path}/reg_rw /dev/xdma0_bypass ${addr} w | sed -n 's/.*: \(0x[0-9a-fA-F]\+\)$/\1/p' | tail -n1
}

print_reg_hex_dec() {
	local name=$1
	local addr=$2
	local value_hex
	value_hex=$(read_reg_value ${addr})
	echo "  ${name} (${addr}): ${value_hex} ($((${value_hex})))"
}

wait_kernel_done() {
	isDone=0
	while [ "$isDone" -eq 0 ]
	do
		echo "Kernel is running..."
		sleep 1
		# Read the control register from the kernel
		ctrl_reg=$(read_reg_value 0x00000000)
		echo "ctrl_reg: ${ctrl_reg} ($((${ctrl_reg})))"
		isDone=$(( ((ctrl_reg & DONE_MASK)) == 2 ))
	done
}

dump_delay_regs() {
	echo "Delay registers:"
	print_reg_hex_dec "rd_delay_1" 0x00000088
	print_reg_hex_dec "rd_delay_2" 0x00000090
	print_reg_hex_dec "rd_delay_3" 0x00000098
	print_reg_hex_dec "rd_delay_4" 0x000000A0
	print_reg_hex_dec "wr_delay_1" 0x000000A8
	print_reg_hex_dec "wr_delay_2" 0x000000B0
	print_reg_hex_dec "wr_delay_3" 0x000000B8
	print_reg_hex_dec "wr_delay_4" 0x000000C0
}


# Execute the kernel to read data from memory address 0~1MB
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00010000 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000010 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000010 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000018 w 0x00004000 # data chunk size=0x4000*512bits=1MB
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000018 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000020 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000020 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000028 w 0x00000000 # Read data from address 0 
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000028 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x0000002C w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x0000002C w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000034 w 0x40000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000034 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000038 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000038 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000000 w 0x00000001

wait_kernel_done

echo "Kernel reading is finished!"
dump_delay_regs


# Execute the kernel to writ data to memory address 1024MB~1025MB
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00010000 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000010 w 0x00000001
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000010 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000018 w 0x00004000 # data chunck size=0x4000*512bits=1MB
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000018 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000020 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000020 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000028 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000028 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x0000002C w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x0000002C w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000034 w 0x40000000 # Write data from address 1GB
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000034 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000038 w 0x00000000
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000038 w
sudo ${tool_path}/reg_rw /dev/xdma0_bypass 0x00000000 w 0x00000001

wait_kernel_done

echo "Kernel writing is finished!"
dump_delay_regs
