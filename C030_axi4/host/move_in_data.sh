
tool_path=/opt/xilinx/dma_ip_drivers/XDMA/linux-kernel/tools
data_len=$1


time_command_start=$(date +%s%N)  # Record start time in nanoseconds
sudo ${tool_path}/dma_to_device   -d /dev/xdma0_h2c_0 -f ./data/0_in.bin  -s ${data_len} -a 0x00000000 -c 1
time_command_end=$(date +%s%N)    # Record end time in nanoseconds
elapsed_time_ms=$((($time_command_end - $time_command_start) / 1000000))  # Convert to milliseconds
echo "Elapsed time: ${elapsed_time_ms} ms"


time_command_start=$(date +%s%N)  # Record start time in nanoseconds
sudo ${tool_path}/dma_from_device -d /dev/xdma0_c2h_0 -f ./data/recv0.bin -s ${data_len} -a 0x00000000 -c 1
time_command_end=$(date +%s%N)    # Record end time in nanoseconds
elapsed_time_ms=$((($time_command_end - $time_command_start) / 1000000))  # Convert to milliseconds
echo "Elapsed time: ${elapsed_time_ms} ms"


time_command_start=$(date +%s%N)  # Record start time in nanoseconds
sudo ${tool_path}/dma_to_device   -d /dev/xdma0_h2c_0 -f ./data/1_in.bin  -s ${data_len} -a 0x40000000 -c 1
time_command_end=$(date +%s%N)    # Record end time in nanoseconds
elapsed_time_ms=$((($time_command_end - $time_command_start) / 1000000))  # Convert to milliseconds
echo "Elapsed time: ${elapsed_time_ms} ms"


time_command_start=$(date +%s%N)  # Record start time in nanoseconds
sudo ${tool_path}/dma_from_device -d /dev/xdma0_c2h_0 -f ./data/recv1.bin -s ${data_len} -a 0x40000000 -c 1
time_command_end=$(date +%s%N)    # Record end time in nanoseconds
elapsed_time_ms=$((($time_command_end - $time_command_start) / 1000000))  # Convert to milliseconds
echo "Elapsed time: ${elapsed_time_ms} ms"



