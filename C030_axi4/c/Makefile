# Copyright 2023 RapidStream Design Automation, Inc.
# All Rights Reserved.


# Makefile for Digit_reg of Rosetta benchmarks
#
# Author: Yuanlong Xiao (ylxiao@seas.upenn.edu)
#
# Targets:
#   all   - Builds hardware and software in SDSoC.



app=tapa_accel
VPATH=.
INCLUDE=-I ${XILINX_HLS}/include
OPT_LEVEL=-O3
CFLAGS=$(INCLUDE) $(OPT_LEVEL) -DSIM
CXX=g++
SRC_FILES=$(wildcard $(VPATH)/*.cpp)

all: main
	./main

main:$(SRC_FILES)
	$(CXX) $(CFLAGS) -o main $^

csyn:
	vitis_hls ./tcl/script.tcl

echo:
	echo $(SRC_FILES)

m := $(shell date)
branch := $(shell git branch --show-current)
git:
	@git add .
	@git commit -m "$(m)"
	@git push origin $(branch)



clean:
	rm -rf ./*.o main *.log $(app)
