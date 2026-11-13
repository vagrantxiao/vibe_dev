// Copyright 2023 RapidStream Design Automation, Inc.
// All Rights Reserved.

#ifndef READ_AND_WRITE_H
#define READ_AND_WRITE_H

#include <hls_stream.h>
#include <ap_int.h>

using data_t = ap_uint<512>;

#ifdef SIM
#define SIZE_MAX     1024
#else
#define SIZE_MAX     1024*1024*128 //8GB
#endif

#define FIFO_DEPTH 2048
void tapa_write(
		data_t output_1[SIZE_MAX]);

void datamover(
		int readwrite,
		int size,
		int inc,
		data_t input_1[SIZE_MAX],
		data_t input_2[SIZE_MAX],
		data_t input_3[SIZE_MAX],
		data_t input_4[SIZE_MAX],
		data_t output_1[SIZE_MAX],
		data_t output_2[SIZE_MAX],
		data_t output_3[SIZE_MAX],
		data_t output_4[SIZE_MAX]);

void tapa_read(
		data_t input_1[SIZE_MAX],
		hls::stream<data_t>& output_1);


#define READ  0
#define WRITE 1
#endif
