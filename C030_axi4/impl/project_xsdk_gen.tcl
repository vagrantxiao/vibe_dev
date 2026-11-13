#!/usr/bin/xsct
# Vitis 2022.2 flow (run with: xsct project_xsdk_gen.tcl)
# sudo minicom -D /dev/ttyUSB1 -b 115200 -8 -o

set project_name  "my_app"
set platform_name "floorplan_static_wrapper"
set core_name     "psu_cortexa53_0"
set language      "c++"

# .xsa replaces the old .hdf exported by Vivado
set xsa_file "/home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/prj/design_1_wrapper.xsa"

# Set the Vitis workspace
setws /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws

# Create the hardware platform (replaces the old hw + bsp projects).
# Providing -proc and -os creates the default standalone domain.
platform create -name ${platform_name}_hw_platform_0 \
	-hw ${xsa_file} \
	-proc ${core_name} -os standalone
platform generate

# Create the application against the generated platform/domain.
app create -name ${project_name} \
	-platform ${platform_name}_hw_platform_0 \
	-domain standalone_domain \
	-template {Empty Application (C++)} -lang ${language}

# Remove the default generated source and import your own sources.
file delete -force /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/${project_name}/src/main.cc
importsources -name ${project_name} -path /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/sdk

# Overwrite the auto-generated linker script with the custom one.
file copy -force /home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/sdk/lscript.ld \
	/home/ylxiao/ws222/job_hunting/F004_vcoding/C030_axi4/out/sdk_ws/${project_name}/src/lscript.ld

# Build the application (also builds the platform if needed).
app build -name ${project_name}
