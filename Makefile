m=$(shell date)

all:
	mkdir -p build
	bash -c "source /tools/Xilinx/Vitis/2023.2/settings64.sh && cd build && vivado -mode batch -source ../run.tcl"
git:
	git add .
	git commit -m "$(m)"
	git push origin main


clean:
	rm -rf build
