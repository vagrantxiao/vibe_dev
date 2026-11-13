workspace := $(CURDIR)/out
ooc_dcp := $(workspace)/ooc.dcp
ooc_tcl := $(CURDIR)/impl/run_ooc.tcl
prj_tcl := $(CURDIR)/impl/create_prj.tcl
ip_tcl := $(CURDIR)/impl/pack_ip.tcl
syn_top := datamover

IVERILOG ?= iverilog
VVP ?= vvp
SURFER ?= surfer
GTKWAVE ?= gtkwave
export IVERILOG VVP

.PHONY: all regression test show create_prj ooc clean git

all: regression

regression test:
	@mkdir -p "$(workspace)"
	@if command -v vivado >/dev/null 2>&1; then \
		cd "$(workspace)" && bash ../script/run_xsim.sh; \
	elif command -v "$(IVERILOG)" >/dev/null 2>&1 && command -v "$(VVP)" >/dev/null 2>&1; then \
		cd "$(workspace)" && bash ../script/run_iverilog.sh; \
	else \
		echo "No supported simulator found. Install Icarus Verilog (iverilog/vvp) or configure Vivado."; \
		exit 1; \
	fi

show:
	@if [ -f "$(workspace)/dump.wdb" ]; then \
		cd "$(workspace)" && vivado dump.wdb; \
	elif [ -f "$(workspace)/dump.fst" ]; then \
		if command -v "$(SURFER)" >/dev/null 2>&1; then \
			cd "$(workspace)" && "$(SURFER)" -c ../script/surfer_wave.sucl "$(workspace)/dump.fst"; \
		elif command -v "$(GTKWAVE)" >/dev/null 2>&1; then \
			cd "$(workspace)" && "$(GTKWAVE)" dump.fst; \
		else \
			echo "No waveform viewer found. Install Surfer (brew install surfer) or GTKWave."; \
			exit 1; \
		fi; \
	else \
		echo "No waveform found in $(workspace). Run 'make' first."; \
		exit 1; \
	fi

create_prj:
	mkdir -p $(workspace)
	cd $(workspace) && \
	vivado -mode batch \
	-source $(prj_tcl) \
	-tclargs $(syn_top) $(CURDIR)/rtl


pack_ip:
	mkdir -p $(workspace)
	cd $(workspace) && \
	vivado -mode batch \
	-source $(ip_tcl)

ooc: $(ooc_dcp)

$(ooc_dcp):
	mkdir -p $(workspace)
	cd $(workspace) && \
	vivado -mode gui \
	-source $(ooc_tcl) \
	-tclargs $(syn_top) $(CURDIR)/hdl
	
	
m := $(shell date)
branch := $(shell git branch --show-current)
git:
	@git add .
	@git commit -m "$(m)"
	@git push origin $(branch)

uart:
	sudo minicom -D /dev/ttyUSB1 -b 115200 -8 -o

run:
	cd $(workspace) && xsct $(CURDIR)/impl/project_xsdk_run.tcl

sdk:
	cd $(workspace) && xsct $(CURDIR)/impl/project_xsdk_gen.tcl

clean:
	rm -rf $(workspace)
