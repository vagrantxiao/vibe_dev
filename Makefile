m=$(shell date)

all:
	mkdir -p build
	cd build && vivado -mode batch -source ../run.tcl
git:
	git add .
	git commit -m "$(m)"
	git push origin main

clean:
	rm -rf build