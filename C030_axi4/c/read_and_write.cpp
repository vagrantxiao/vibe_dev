// Copyright 2023 RapidStream Design Automation, Inc.
// All Rights Reserved.

#include "read_and_write.h"


//void top(hls::stream<data_t>& mem_0, hls::stream<data_t>& mem_1)

void tapa_write(
		data_t output_1[SIZE_MAX])
{
#pragma HLS INTERFACE mode=m_axi port=output_1 bundle=aximm1

	for(int i=0; i<SIZE_MAX; i++){
#pragma HLS PIPELINE II=1
		output_1[i] = i;
	}
}


data_t read_proc1(data_t *din, int size)
{
	data_t sum=0;
	for(int i=0; i<size; i++){
#pragma HLS PIPELINE II=1
		sum += din[i];
	}
	return sum;
}

void write_proc1(data_t sum, data_t *dout, int size)
{
	for(int i=0; i<size; i++){
#pragma HLS PIPELINE II=1
		dout[i] = sum;
	}
}




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
		data_t output_4[SIZE_MAX])
{
#pragma HLS INTERFACE mode=s_axilite port=readwrite
#pragma HLS INTERFACE mode=s_axilite port=size
#pragma HLS INTERFACE mode=s_axilite port=inc
#pragma HLS INTERFACE mode=s_axilite port=return
#pragma HLS INTERFACE mode=m_axi port=input_1  bundle=m1
#pragma HLS INTERFACE mode=m_axi port=input_2  bundle=m2
#pragma HLS INTERFACE mode=m_axi port=input_3  bundle=m3
#pragma HLS INTERFACE mode=m_axi port=input_4  bundle=m4
#pragma HLS INTERFACE mode=m_axi port=output_1 bundle=m1
#pragma HLS INTERFACE mode=m_axi port=output_2 bundle=m2
#pragma HLS INTERFACE mode=m_axi port=output_3 bundle=m3
#pragma HLS INTERFACE mode=m_axi port=output_4 bundle=m4

#pragma HLS DATAFLOW disable_start_propagation

  static data_t sum1=0;
  static data_t sum2=0;
  static data_t sum3=0;
  static data_t sum4=0;

  if (readwrite == READ){
	  sum1 = read_proc1(input_1, size);
	  sum2 = read_proc1(input_2, size);
	  sum3 = read_proc1(input_3, size);
	  sum4 = read_proc1(input_4, size);
  }else{
	  sum1 += inc;
	  sum2 += inc;
	  sum3 += inc;
	  sum4 += inc;
	  write_proc1(sum1, output_1, size);
	  write_proc1(sum2, output_2, size);
	  write_proc1(sum3, output_3, size);
	  write_proc1(sum4, output_4, size);
  }
}





void tapa_read(
		data_t input_1[SIZE_MAX],
		hls::stream<data_t>& output_1)
{
#pragma HLS INTERFACE mode=m_axi port=input_1 bundle=aximm1
#pragma HLS INTERFACE mode=axis register_mode=both port=output_1 register



//#pragma HLS DATAFLOW disable_start_propagation

	data_t buffer_1[SIZE_MAX];

	for(int i=0; i<SIZE_MAX; i++){
#pragma HLS PIPELINE II=1
		buffer_1[i] = input_1[i];
	}

	for(int i=0; i<SIZE_MAX; i++){
#pragma HLS PIPELINE II=1
		output_1.write(buffer_1[i]);
	}
}
