// Copyright 2023 RapidStream Design Automation, Inc.
// All Rights Reserved.

#include <cstdio>
#include <cassert>
#include "read_and_write.h"

#define SIZE 1024
#define INC 1

int main() {
    data_t imem_1[SIZE_MAX];
    data_t imem_2[SIZE_MAX];
    data_t imem_3[SIZE_MAX];
    data_t imem_4[SIZE_MAX];
    data_t omem_1[SIZE_MAX];
    data_t omem_2[SIZE_MAX];
    data_t omem_3[SIZE_MAX];
    data_t omem_4[SIZE_MAX];
    hls::stream< data_t > Output_1("kernel_out1");
    hls::stream< data_t > Output_2("kernel_out2");
    hls::stream< data_t > Output_3("kernel_out3");
    hls::stream< data_t > Output_4("kernel_out4");
    data_t sum = 0;
    int size = SIZE;
    int inc = INC;
    for(int i=0; i<size; i++){ sum += i;}

    tapa_write(imem_1);
    tapa_write(imem_2);
    tapa_write(imem_3);
    tapa_write(imem_4);
    datamover(READ , size, inc, imem_1, imem_2, imem_3, imem_4, omem_1, omem_2, omem_3, omem_4);
    datamover(WRITE, size, inc, imem_1, imem_2, imem_3, imem_4, omem_1, omem_2, omem_3, omem_4);
    tapa_read(omem_1, Output_1);
    tapa_read(omem_2, Output_2);
    tapa_read(omem_3, Output_3);
    tapa_read(omem_4, Output_4);

    for(int i=0; i<size; i++){
    	data_t out = Output_1.read();
    	if(out != sum+inc){
       		printf("omem_1[%d](%x) != %x, error!\n", i, out.to_int(), sum);
       		return 1;
      	}
    }

    for(int i=0; i<size; i++){
    	data_t out = Output_2.read();
    	if(out != sum+inc){
       		printf("omem_2[%d](%x) != %x, error!\n", i, out.to_int(), sum);
       		return 1;
      	}
    }

    for(int i=0; i<size; i++){
    	data_t out = Output_3.read();
    	if(out != sum+inc){
       		printf("omem_3[%d](%x) != %x, error!\n", i, out.to_int(), sum);
       		return 1;
      	}
    }

    for(int i=0; i<size; i++){
    	data_t out = Output_4.read();
    	if(out != sum+inc){
       		printf("omem_4[%d](%x) != %x, error!\n", i, out.to_int(), sum);
       		return 1;
      	}
    }

    printf("PASSED!\n");
    return 0;
}
