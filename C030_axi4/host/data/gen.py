#!/usr/bin/env python3
import struct



###############################################

#data = b'\xff\xff\xff\xff'
#with open('2.bin', 'wb') as file:
#	for i in range(1000):
#		file.write(data)

###############################################

#num=268435456*4
num=1024*1024

def gen_bin(out_file, uniform_value):
	with open(out_file, 'wb') as fout:
		for j in range(num>>8):
			for i in range(256):
				packed_data = struct.pack('B', uniform_value)
				fout.write(packed_data)	


gen_bin("0_in.bin", 0)
gen_bin("1_in.bin", 0)
gen_bin("0_out.bin", 0)
gen_bin("1_out.bin", 0)
