#####################start of rapidstream modification##########################
#                                                                              #
#                                                                              #
# Set the project name

puts ${argc}

if {${argc} != 8} {
	puts stderr "Should -tclargs <ipi source dir> <kernel_hbm frequency (HZ)> <CARD> <PART> <BOARD> <config file path> <kernal_name> <app_name>. Too few arguments. Exiting."
	exit 1
}

set ABS_DIR     "[lindex $argv 0]"

set FREQS       "[lindex $argv 1]"
set values      [split $FREQS "_"]
set KL_FREQ     [lindex $values 0]
set HBM_FREQ    [lindex $values 1]

set CARD        "[lindex $argv 2]"
set PART        "[lindex $argv 3]"
set BOARD       "[lindex $argv 4]"
set CONFIG_FILE "[lindex $argv 5]"

set KERNAL_NAME "[lindex $argv 6]"
set APP_NAME    "[lindex $argv 7]"

set _xil_proj_name_ "${APP_NAME}_${CARD}"
set kernel_name ${KERNAL_NAME}

proc number_of_processor {} {
    global tcl_platform env
    switch ${tcl_platform(platform)} {
        "windows" {
            return $env(NUMBER_OF_PROCESSORS)
        }

        "unix" {
            if {![catch {open "/proc/cpuinfo"} f]} {
                set cores [regexp -all -line {^processor\s} [read $f]]
                close $f
                if {$cores > 0} {
                    return $cores
                }
            }
        }

        "Darwin" {
            if {![catch {exec {*}$sysctl -n "hw.ncpu"} cores]} {
                return $cores
            }
        }

        default {
            puts "Unknown System"
            return 1
        }
    }
}

proc add_src_to_project { dir } {
  set contents [glob -nocomplain -directory $dir *]
  foreach item $contents {
    if { [regexp {.*\.tcl} $item] } {
      source $item
    } else {
      add_files $item
    }
  }
}





proc create_axi_mem_intercon { mem_num } {
  # Create and connect axi bar
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_intercon${mem_num}
  set_property CONFIG.NUM_MI {1} [get_bd_cells axi_mem_intercon${mem_num}]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/ACLK]        [get_bd_pins kernel_clk/clk_out1]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/S00_ACLK]    [get_bd_pins kernel_clk/clk_out1]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/ARESETN]     [get_bd_pins kernel_sys_reset/interconnect_aresetn]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/S00_ARESETN] [get_bd_pins kernel_sys_reset/interconnect_aresetn]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/M00_ACLK]    [get_bd_pins hbm_axi_clk/clk_out1]
  connect_bd_net [get_bd_pins axi_mem_intercon${mem_num}/M00_ARESETN] [get_bd_pins hbm_sys_reset/interconnect_aresetn]

  # Create and connect axi slice
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 axi_register_slice_${mem_num}
  set_property CONFIG.PROTOCOL {AXI3} [get_bd_cells axi_register_slice_${mem_num}]
  connect_bd_intf_net [get_bd_intf_pins axi_register_slice_${mem_num}/S_AXI] -boundary_type upper [get_bd_intf_pins axi_mem_intercon${mem_num}/M00_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_register_slice_${mem_num}/M_AXI] [get_bd_intf_pins hbm_0/SAXI_${mem_num}]
  connect_bd_net [get_bd_pins axi_register_slice_${mem_num}/aclk] [get_bd_pins hbm_axi_clk/clk_out1]
  connect_bd_net [get_bd_pins axi_register_slice_${mem_num}/aresetn] [get_bd_pins hbm_sys_reset/peripheral_aresetn]

}

proc enable_hbm_axi { mem_num } {
  set_property CONFIG.USER_SAXI_${mem_num} {true} [get_bd_cells hbm_0]
  connect_bd_net [get_bd_pins hbm_0/AXI_${mem_num}_ACLK]     [get_bd_pins hbm_axi_clk/clk_out1] -quiet
  connect_bd_net [get_bd_pins hbm_0/AXI_${mem_num}_ARESET_N] [get_bd_pins hbm_sys_reset/peripheral_aresetn] -quiet
}


proc connect_kernel2memory { kernel_port mem_type mem_num_raw} {
  global kernel_name
  if { $mem_type != "HBM" } {
    error "Your are using ${mem_type}, but we only support HBM now"
  }
  if { $mem_num_raw < 10 } {
    set mem_num "0${mem_num_raw}"
  } else {
    set mem_num "${mem_num_raw}"
  }
  enable_hbm_axi ${mem_num}
  create_axi_mem_intercon ${mem_num}

  connect_bd_intf_net [get_bd_intf_pins ${kernel_name}_0/${kernel_port}] -boundary_type upper [get_bd_intf_pins axi_mem_intercon${mem_num}/S00_AXI]

}

proc extract_mem_interface { input_string } {
  # Use the regexp command to match the pattern in the input string
  if {[regexp {(\w+)\[(\d+)\]} $input_string match mem_type port_num]} {
      if { $mem_type != "HBM" && $mem_type != "DDR" && $mem_type != "PLRAM" } {
        error "Memory type not supported, please use HBM, DDR or PLRAM"
        return 
      }
      return [list $mem_type $port_num]
  } else {
      error "Pattern not found in the input string, eg. HBM[0]"
      return
  }
}


proc connect_kernel { kernel_params } {
  # Check if the json package is available; if not, install it
  if {[catch {package require json}]} {
      package require json
  }

  # Read the contents of a JSON file into a variable
  set filename "${kernel_params}"
  set file_content [open $filename r]
  set json_data [read $file_content]
  close $file_content

  # Parse the JSON data into a dictionary
  set parsed_dict [json::json2dict $json_data]
  set arg2hbm [dict get $parsed_dict "arg2hbm"]

  # Iterate over the dictionary using the dict for command
  dict for {kernel_port mem_port} $arg2hbm {
    set result [extract_mem_interface $mem_port]
    # Split the result list into two strings
    lassign $result mem_type mem_num
    puts "Kernel port: $kernel_port, Memory type: $mem_type, Memory number: $mem_num"
    connect_kernel2memory $kernel_port  $mem_type $mem_num
  }
}

proc create_cl_hier { kernel_params } {
  global kernel_name
  
  # Check if the json package is available; if not, install it
  if {[catch {package require json}]} {
      package require json
  }

  # Read the contents of a JSON file into a variable
  set filename "${kernel_params}"
  set file_content [open $filename r]
  set json_data [read $file_content]
  close $file_content

  # Parse the JSON data into a dictionary
  set parsed_dict [json::json2dict $json_data]
  set arg2hbm [dict get $parsed_dict "arg2hbm"]

  # create a hier (cl) for kernel first.
  group_bd_cells cl [get_bd_cells ${kernel_name}_0]
  
  # Iterate over the dictionary using the dict for command
  dict for {kernel_port mem_port} $arg2hbm {
    set result [extract_mem_interface $mem_port]
    # Split the result list into two strings
    lassign $result mem_type mem_num

    # make sure mem_num has two digits
    if { $mem_num < 10 } {
      set mem_num "0${mem_num}"
    } else {
      set mem_num "${mem_num}"
    }

    move_bd_cells [get_bd_cells cl] [get_bd_cells axi_mem_intercon$mem_num]
    set_property name $kernel_port [get_bd_intf_pins cl/M00_AXI]
  }

  # Move xdma bypass peripheral to cl
  move_bd_cells [get_bd_cells cl] [get_bd_cells xdma_0_axi_periph]
  set_property name s_axi_control [get_bd_intf_pins cl/S00_AXI]

  # Move xdma peripheral to cl
  move_bd_cells [get_bd_cells cl] [get_bd_cells axi_mem_intercon0]
  set_property name m_axi_xdma [get_bd_intf_pins cl/M00_AXI]
  set_property name s_axi_xdma [get_bd_intf_pins cl/S00_AXI]
}

proc add_kernel { config_file kernel_name } {

  delete_bd_objs [get_bd_intf_nets xdma_0_axi_periph_M00_AXI] [get_bd_intf_nets tapa_accel1_0_m_axi_m1] [get_bd_cells tapa_accel1_0]
  delete_bd_objs [get_bd_intf_nets axi_mem_intercon1_M00_AXI] [get_bd_cells axi_mem_intercon1]
  create_bd_cell -type module -reference ${kernel_name} ${kernel_name}_0
  
  # Connect control interface
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins xdma_0_axi_periph/M00_AXI] [get_bd_intf_pins ${kernel_name}_0/s_axi_control]
  connect_bd_net [get_bd_pins ${kernel_name}_0/ap_clk] [get_bd_pins kernel_clk/clk_out1]
  connect_bd_net [get_bd_pins ${kernel_name}_0/ap_rst_n] [get_bd_pins kernel_sys_reset/peripheral_aresetn]
  
  # Connect memory interfaces for the kernel
  connect_kernel "${config_file}"


}


proc set_kernel_frequency { KL_FREQ } {

  if {${KL_FREQ} == 450} {
    startgroup
    set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {104.289} \
    CONFIG.CLKOUT1_PHASE_ERROR {153.873} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {23.625} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.625} \
    ] [get_bd_cells kernel_clk]
    endgroup
  } elseif {${KL_FREQ} == 400} {
  	startgroup
  	set_property -dict [list \
  	  CONFIG.CLKOUT1_DRIVES {Buffer} \
  	  CONFIG.CLKOUT1_JITTER {146.303} \
  	  CONFIG.CLKOUT1_PHASE_ERROR {222.305} \
  	  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {400.000} \
  	  CONFIG.CLKOUT2_DRIVES {Buffer} \
  	  CONFIG.CLKOUT3_DRIVES {Buffer} \
  	  CONFIG.CLKOUT4_DRIVES {Buffer} \
  	  CONFIG.CLKOUT5_DRIVES {Buffer} \
  	  CONFIG.CLKOUT6_DRIVES {Buffer} \
  	  CONFIG.CLKOUT7_DRIVES {Buffer} \
  	  CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
  	  CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
  	  CONFIG.MMCM_CLKFBOUT_MULT_F {48.000} \
  	  CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.000} \
  	  CONFIG.MMCM_COMPENSATION {AUTO} \
  	  CONFIG.MMCM_DIVCLK_DIVIDE {5} \
  	  CONFIG.PRIMITIVE {MMCM} \
  	] [get_bd_cells kernel_clk]
  	endgroup
  } elseif {${KL_FREQ} == 350} {
  	startgroup
  	set_property -dict [list \
  	  CONFIG.CLKOUT1_DRIVES {Buffer} \
  	  CONFIG.CLKOUT1_JITTER {151.657} \
  	  CONFIG.CLKOUT1_PHASE_ERROR {222.060} \
  	  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {350} \
  	  CONFIG.CLKOUT2_DRIVES {Buffer} \
  	  CONFIG.CLKOUT3_DRIVES {Buffer} \
  	  CONFIG.CLKOUT4_DRIVES {Buffer} \
  	  CONFIG.CLKOUT5_DRIVES {Buffer} \
  	  CONFIG.CLKOUT6_DRIVES {Buffer} \
  	  CONFIG.CLKOUT7_DRIVES {Buffer} \
  	  CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
  	  CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
  	  CONFIG.MMCM_CLKFBOUT_MULT_F {47.250} \
  	  CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.375} \
  	  CONFIG.MMCM_COMPENSATION {AUTO} \
  	  CONFIG.MMCM_DIVCLK_DIVIDE {5} \
  	  CONFIG.PRIMITIVE {MMCM} \
  	] [get_bd_cells kernel_clk]
  	endgroup
  } elseif {${KL_FREQ} == 300} {
  startgroup
  	set_property -dict [list \
  	  CONFIG.CLKOUT1_DRIVES {Buffer} \
  	  CONFIG.CLKOUT1_JITTER {152.330} \
  	  CONFIG.CLKOUT1_PHASE_ERROR {222.305} \
  	  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {300.000} \
  	  CONFIG.CLKOUT2_DRIVES {Buffer} \
  	  CONFIG.CLKOUT3_DRIVES {Buffer} \
  	  CONFIG.CLKOUT4_DRIVES {Buffer} \
  	  CONFIG.CLKOUT5_DRIVES {Buffer} \
  	  CONFIG.CLKOUT6_DRIVES {Buffer} \
  	  CONFIG.CLKOUT7_DRIVES {Buffer} \
  	  CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
  	  CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
  	  CONFIG.MMCM_CLKFBOUT_MULT_F {48.000} \
  	  CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.000} \
  	  CONFIG.MMCM_COMPENSATION {AUTO} \
  	  CONFIG.MMCM_DIVCLK_DIVIDE {5} \
  	  CONFIG.PRIMITIVE {MMCM} \
  	] [get_bd_cells kernel_clk]
  	endgroup
  } elseif {${KL_FREQ} == 250} {
  	startgroup
  	set_property -dict [list \
  	  CONFIG.CLKOUT1_DRIVES {Buffer} \
  	  CONFIG.CLKOUT1_JITTER {95.013} \
  	  CONFIG.CLKOUT1_PHASE_ERROR {86.070} \
  	  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250.000} \
  	  CONFIG.CLKOUT2_DRIVES {Buffer} \
  	  CONFIG.CLKOUT3_DRIVES {Buffer} \
  	  CONFIG.CLKOUT4_DRIVES {Buffer} \
  	  CONFIG.CLKOUT5_DRIVES {Buffer} \
  	  CONFIG.CLKOUT6_DRIVES {Buffer} \
  	  CONFIG.CLKOUT7_DRIVES {Buffer} \
  	  CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
  	  CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
  	  CONFIG.MMCM_CLKFBOUT_MULT_F {9.500} \
  	  CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.750} \
  	  CONFIG.MMCM_COMPENSATION {AUTO} \
  	  CONFIG.MMCM_DIVCLK_DIVIDE {1} \
  	  CONFIG.PRIMITIVE {MMCM} \
  	] [get_bd_cells kernel_clk]
  	endgroup
  } elseif {${KL_FREQ} == 200} {
  	startgroup
  	set_property -dict [list \
  	  CONFIG.CLKOUT1_JITTER {161.295} \
  	  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200} \
  	  CONFIG.MMCM_CLKOUT0_DIVIDE_F {6.000} \
  	  CONFIG.MMCM_COMPENSATION {AUTO} \
  	  CONFIG.PRIMITIVE {MMCM} \
  	] [get_bd_cells kernel_clk]
  	endgroup
  } elseif {${KL_FREQ} == 150} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {125.400} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {150.000} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
      CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    ] [get_bd_cells kernel_clk]
    endgroup
  } elseif {${KL_FREQ} == 100} {
  	startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {134.506} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000} \
      CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    ] [get_bd_cells kernel_clk]
    endgroup
  } else {
  	puts stderr "No valid Kernel Frequency <200MHz, 250MHz, 300MHz, 350MHz, 400MHz>..."
  	exit 1
  }

}

proc set_hbm_frequency { HBM_FREQ } {
  if {${HBM_FREQ} == 100} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {134.506} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup
  } elseif {${HBM_FREQ} == 150} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {125.400} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {150} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
      CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup
  } elseif {${HBM_FREQ} == 200} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {119.392} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {6.000} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup
  } elseif {${HBM_FREQ} == 250} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {85.152} \
      CONFIG.CLKOUT1_PHASE_ERROR {78.266} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {4.750} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.750} \
      CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup

    # HBM to 250MHz
    startgroup
    set_property -dict [list \
    CONFIG.USER_AXI_CLK1_FREQ {250} \
    CONFIG.USER_AXI_CLK_FREQ {250} \
    ] [get_bd_cells hbm_0]
    endgroup
  } elseif {${HBM_FREQ} == 300} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {111.430} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {300} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.000} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup

    # HBM to 300MHz
    startgroup
    set_property -dict [list \
    CONFIG.USER_AXI_CLK1_FREQ {300} \
    CONFIG.USER_AXI_CLK_FREQ {300} \
    ] [get_bd_cells hbm_0]
    endgroup
  } elseif {${HBM_FREQ} == 350} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {108.882} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {350} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.375} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup

    # HBM to 350MHz
    startgroup
    set_property -dict [list \
    CONFIG.USER_AXI_CLK1_FREQ {350} \
    CONFIG.USER_AXI_CLK_FREQ {350} \
    ] [get_bd_cells hbm_0]
    endgroup
  } elseif {${HBM_FREQ} == 400} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {106.119} \
      CONFIG.CLKOUT1_PHASE_ERROR {154.678} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {400} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.000} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup

    # HBM to 400MHz
    startgroup
    set_property -dict [list \
    CONFIG.USER_AXI_CLK1_FREQ {400} \
    CONFIG.USER_AXI_CLK_FREQ {400} \
    ] [get_bd_cells hbm_0]
    endgroup
  } elseif {${HBM_FREQ} == 450} {
    startgroup
    set_property -dict [list \
      CONFIG.CLKOUT1_JITTER {104.289} \
      CONFIG.CLKOUT1_PHASE_ERROR {153.873} \
      CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450} \
      CONFIG.MMCM_CLKFBOUT_MULT_F {23.625} \
      CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.625} \
    ] [get_bd_cells hbm_axi_clk]
    endgroup
    
    # HBM to 450MHz
    startgroup
    set_property -dict [list \
    CONFIG.USER_AXI_CLK1_FREQ {450} \
    CONFIG.USER_AXI_CLK_FREQ {450} \
    ] [get_bd_cells hbm_0]
    endgroup
  } else {
    puts stderr "No valid Kernel Frequency <100MHz, 150MHz, 200MHz, 250MHz, 300MHz, 350MHz, 400MHz, 450MHz>..."
  	exit 1
  } 
}


set freq_mhz ${KL_FREQ}
create_project ${_xil_proj_name_}_ipi_prj ${_xil_proj_name_}_${FREQS}M_ipi_prj -part ${PART} -force

# Set project properties
set obj [current_project]
set_property -name "board_part" -value ${BOARD} -objects $obj

#add_files ${ABS_DIR}/${_xil_proj_name_}/hdl/gnd_driver.v
#add_files ${ABS_DIR}/${_xil_proj_name_}/hdl/papb_intf.v
add_src_to_project "${ABS_DIR}/hls/solution/syn/verilog"
add_src_to_project "${ABS_DIR}/hdl"

add_files -fileset constrs_1 -norecurse ${ABS_DIR}/xdc/only_pins_${CARD}.xdc
set_property target_constrs_file ${ABS_DIR}/xdc/only_pins_${CARD}.xdc [current_fileset -constrset]
#                                                                              #
#                                                                              #

#######################End of rapidstream modification##########################


################################################################
# This is a generated script based on design: design_1
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2022.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source design_1_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# gnd_driver, tapa_accel1

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcu50-fsvh2104-2-e
   set_property BOARD_PART xilinx.com:au50dd:part0:1.0 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name design_1

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:hbm:1.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:xdma:4.1\
xilinx.com:ip:xlconstant:1.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
gnd_driver\
tapa_accel1\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set hbm_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 hbm_clk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {100000000} \
   ] $hbm_clk

  set pci_express_x1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x1 ]

  set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {100000000} \
   ] $pcie_refclk


  # Create ports
  set HBM_CATTRIP [ create_bd_port -dir O HBM_CATTRIP ]
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn

  # Create instance: axi_mem_intercon0, and set properties
  set axi_mem_intercon0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_intercon0 ]
  set_property CONFIG.NUM_MI {1} $axi_mem_intercon0


  # Create instance: axi_mem_intercon1, and set properties
  set axi_mem_intercon1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_mem_intercon1 ]
  set_property CONFIG.NUM_MI {1} $axi_mem_intercon1


  # Create instance: gnd_driver_0, and set properties
  set block_name gnd_driver
  set block_cell_name gnd_driver_0
  if { [catch {set gnd_driver_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $gnd_driver_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: hbm_0, and set properties
  set hbm_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0 ]
  set_property -dict [list \
    CONFIG.USER_APB_EN {false} \
    CONFIG.USER_AXI_CLK_FREQ {450} \
    CONFIG.USER_CLK_SEL_LIST0 {AXI_00_ACLK} \
    CONFIG.USER_HBM_DENSITY {8GB} \
    CONFIG.USER_SAXI_01 {true} \
    CONFIG.USER_SAXI_02 {false} \
    CONFIG.USER_SAXI_03 {false} \
    CONFIG.USER_SAXI_04 {false} \
    CONFIG.USER_SAXI_05 {false} \
    CONFIG.USER_SAXI_06 {false} \
    CONFIG.USER_SAXI_07 {false} \
    CONFIG.USER_SAXI_08 {false} \
    CONFIG.USER_SAXI_09 {false} \
    CONFIG.USER_SAXI_10 {false} \
    CONFIG.USER_SAXI_11 {false} \
    CONFIG.USER_SAXI_12 {false} \
    CONFIG.USER_SAXI_13 {false} \
    CONFIG.USER_SAXI_14 {false} \
    CONFIG.USER_SAXI_15 {false} \
    CONFIG.USER_SAXI_16 {false} \
    CONFIG.USER_SAXI_17 {false} \
    CONFIG.USER_SAXI_18 {false} \
    CONFIG.USER_SAXI_19 {false} \
    CONFIG.USER_SAXI_20 {false} \
    CONFIG.USER_SAXI_21 {false} \
    CONFIG.USER_SAXI_22 {false} \
    CONFIG.USER_SAXI_23 {false} \
    CONFIG.USER_SAXI_24 {false} \
    CONFIG.USER_SAXI_25 {false} \
    CONFIG.USER_SAXI_26 {false} \
    CONFIG.USER_SAXI_27 {false} \
    CONFIG.USER_SAXI_28 {false} \
    CONFIG.USER_SAXI_29 {false} \
    CONFIG.USER_SAXI_30 {false} \
    CONFIG.USER_SAXI_31 {false} \
  ] $hbm_0


  set_property -dict [ list \
   CONFIG.CLK_DOMAIN {} \
 ] [get_bd_pins /hbm_0/APB_0_PCLK]

  set_property -dict [ list \
   CONFIG.CLK_DOMAIN {} \
 ] [get_bd_pins /hbm_0/APB_1_PCLK]

  # Create instance: hbm_axi_clk, and set properties
  set hbm_axi_clk [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hbm_axi_clk ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_JITTER {104.289} \
    CONFIG.CLKOUT1_PHASE_ERROR {153.873} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450.000} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {23.625} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.625} \
    CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    CONFIG.PRIM_IN_FREQ {250.000} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $hbm_axi_clk


  # Create instance: hbm_sys_reset, and set properties
  set hbm_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hbm_sys_reset ]

  # Create instance: kernel_clk, and set properties
  set kernel_clk [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 kernel_clk ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {40.0} \
    CONFIG.CLKOUT1_DRIVES {Buffer} \
    CONFIG.CLKOUT1_JITTER {95.013} \
    CONFIG.CLKOUT1_PHASE_ERROR {86.070} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250.000} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.750} \
    CONFIG.MMCM_CLKIN1_PERIOD {4.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.750} \
    CONFIG.MMCM_COMPENSATION {AUTO} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.PLL_CLKIN_PERIOD {8.000} \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_IN_FREQ {250.000} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.USE_LOCKED {true} \
  ] $kernel_clk


  # Create instance: kernel_sys_reset, and set properties
  set kernel_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 kernel_sys_reset ]

  # Create instance: proc_sys_reset_2, and set properties
  set proc_sys_reset_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_2 ]

  # Create instance: tapa_accel1_0, and set properties
  set block_name tapa_accel1
  set block_cell_name tapa_accel1_0
  if { [catch {set tapa_accel1_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $tapa_accel1_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /tapa_accel1_0/m_axi_m1]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
 ] [get_bd_intf_pins /tapa_accel1_0/s_axi_control]

  # Create instance: util_ds_buf, and set properties
  set util_ds_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf ]
  set_property -dict [list \
    CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $util_ds_buf


  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0 ]
  set_property -dict [list \
    CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {hbm_clk} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $util_ds_buf_0


  # Create instance: xdma_0, and set properties
  set xdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0 ]
  set_property -dict [list \
    CONFIG.PCIE_BOARD_INTERFACE {pci_express_x1} \
    CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
    CONFIG.axi_data_width {64_bit} \
    CONFIG.axist_bypass_en {true} \
    CONFIG.axisten_freq {250} \
    CONFIG.cfg_mgmt_if {false} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pcie_extended_tag {false} \
    CONFIG.pf0_class_code_base {05} \
    CONFIG.pf0_class_code_sub {80} \
    CONFIG.pf0_device_id {7021} \
    CONFIG.pf0_interrupt_pin {NONE} \
    CONFIG.pf0_msi_enabled {false} \
    CONFIG.pf0_msix_enabled {true} \
    CONFIG.pf0_sub_class_interface_menu {Generic_XT_compatible_serial_controller} \
    CONFIG.pl_link_cap_max_link_speed {16.0_GT/s} \
    CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
    CONFIG.xdma_num_usr_irq {16} \
    CONFIG.xdma_rnum_chnl {1} \
    CONFIG.xdma_wnum_chnl {1} \
  ] $xdma_0


  # Create instance: xdma_0_axi_periph, and set properties
  set xdma_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 xdma_0_axi_periph ]
  set_property CONFIG.NUM_MI {1} $xdma_0_axi_periph


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {16} \
  ] $xlconstant_0


  # Create interface connections
  connect_bd_intf_net -intf_net axi_mem_intercon1_M00_AXI [get_bd_intf_pins axi_mem_intercon1/M00_AXI] [get_bd_intf_pins hbm_0/SAXI_01]
  connect_bd_intf_net -intf_net axi_mem_intercon_M00_AXI [get_bd_intf_pins axi_mem_intercon0/M00_AXI] [get_bd_intf_pins hbm_0/SAXI_00]
  connect_bd_intf_net -intf_net hbm_clk_1 [get_bd_intf_ports hbm_clk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
  connect_bd_intf_net -intf_net tapa_accel1_0_m_axi_m1 [get_bd_intf_pins axi_mem_intercon1/S00_AXI] [get_bd_intf_pins tapa_accel1_0/m_axi_m1]
  connect_bd_intf_net -intf_net xdma_0_M_AXI [get_bd_intf_pins axi_mem_intercon0/S00_AXI] [get_bd_intf_pins xdma_0/M_AXI]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_BYPASS [get_bd_intf_pins xdma_0/M_AXI_BYPASS] [get_bd_intf_pins xdma_0_axi_periph/S00_AXI]
  connect_bd_intf_net -intf_net xdma_0_axi_periph_M00_AXI [get_bd_intf_pins tapa_accel1_0/s_axi_control] [get_bd_intf_pins xdma_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net xdma_1_pcie_mgt [get_bd_intf_ports pci_express_x1] [get_bd_intf_pins xdma_0/pcie_mgt]

  # Create port connections
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins axi_mem_intercon1/ACLK] [get_bd_pins axi_mem_intercon1/S00_ACLK] [get_bd_pins kernel_clk/clk_out1] [get_bd_pins kernel_sys_reset/slowest_sync_clk] [get_bd_pins tapa_accel1_0/ap_clk] [get_bd_pins xdma_0_axi_periph/M00_ACLK]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins kernel_clk/locked] [get_bd_pins kernel_sys_reset/dcm_locked]
  connect_bd_net -net clk_wiz_1_clk_out1 [get_bd_pins axi_mem_intercon0/M00_ACLK] [get_bd_pins axi_mem_intercon1/M00_ACLK] [get_bd_pins hbm_0/AXI_00_ACLK] [get_bd_pins hbm_0/AXI_01_ACLK] [get_bd_pins hbm_axi_clk/clk_out1] [get_bd_pins hbm_sys_reset/slowest_sync_clk]
  connect_bd_net -net clk_wiz_1_locked [get_bd_pins hbm_axi_clk/locked] [get_bd_pins hbm_sys_reset/dcm_locked]
  connect_bd_net -net gnd_driver_0_dout [get_bd_ports HBM_CATTRIP] [get_bd_pins gnd_driver_0/dout]
  connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins xdma_0/sys_rst_n]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axi_mem_intercon1/ARESETN] [get_bd_pins axi_mem_intercon1/S00_ARESETN] [get_bd_pins kernel_sys_reset/peripheral_aresetn] [get_bd_pins tapa_accel1_0/ap_rst_n] [get_bd_pins xdma_0_axi_periph/M00_ARESETN]
  connect_bd_net -net proc_sys_reset_1_interconnect_aresetn [get_bd_pins axi_mem_intercon0/M00_ARESETN] [get_bd_pins axi_mem_intercon1/M00_ARESETN] [get_bd_pins hbm_sys_reset/interconnect_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins hbm_0/APB_0_PRESET_N] [get_bd_pins hbm_0/APB_1_PRESET_N] [get_bd_pins proc_sys_reset_2/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn1 [get_bd_pins hbm_0/AXI_00_ARESET_N] [get_bd_pins hbm_0/AXI_01_ARESET_N] [get_bd_pins hbm_sys_reset/peripheral_aresetn]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins hbm_0/APB_0_PCLK] [get_bd_pins hbm_0/APB_1_PCLK] [get_bd_pins hbm_0/HBM_REF_CLK_0] [get_bd_pins hbm_0/HBM_REF_CLK_1] [get_bd_pins proc_sys_reset_2/slowest_sync_clk] [get_bd_pins util_ds_buf_0/IBUF_OUT]
  connect_bd_net -net util_ds_buf_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
  connect_bd_net -net util_ds_buf_IBUF_OUT [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
  connect_bd_net -net xdma_0_axi_aclk [get_bd_pins axi_mem_intercon0/ACLK] [get_bd_pins axi_mem_intercon0/S00_ACLK] [get_bd_pins hbm_axi_clk/clk_in1] [get_bd_pins kernel_clk/clk_in1] [get_bd_pins xdma_0/axi_aclk] [get_bd_pins xdma_0_axi_periph/ACLK] [get_bd_pins xdma_0_axi_periph/S00_ACLK]
  connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins axi_mem_intercon0/ARESETN] [get_bd_pins axi_mem_intercon0/S00_ARESETN] [get_bd_pins hbm_axi_clk/resetn] [get_bd_pins hbm_sys_reset/ext_reset_in] [get_bd_pins kernel_clk/resetn] [get_bd_pins kernel_sys_reset/ext_reset_in] [get_bd_pins proc_sys_reset_2/ext_reset_in] [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins xdma_0_axi_periph/ARESETN] [get_bd_pins xdma_0_axi_periph/S00_ARESETN]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xdma_0/usr_irq_req] [get_bd_pins xlconstant_0/dout]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM00] -force
  assign_bd_address -offset 0x10000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM01] -force
  assign_bd_address -offset 0x20000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM02] -force
  assign_bd_address -offset 0x30000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM03] -force
  assign_bd_address -offset 0x40000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM04] -force
  assign_bd_address -offset 0x50000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM05] -force
  assign_bd_address -offset 0x60000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM06] -force
  assign_bd_address -offset 0x70000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM07] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM08] -force
  assign_bd_address -offset 0x90000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM09] -force
  assign_bd_address -offset 0xA0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM10] -force
  assign_bd_address -offset 0xB0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM11] -force
  assign_bd_address -offset 0xC0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM12] -force
  assign_bd_address -offset 0xD0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM13] -force
  assign_bd_address -offset 0xE0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM14] -force
  assign_bd_address -offset 0xF0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM15] -force
  assign_bd_address -offset 0x000100000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM16] -force
  assign_bd_address -offset 0x000110000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM17] -force
  assign_bd_address -offset 0x000120000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM18] -force
  assign_bd_address -offset 0x000130000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM19] -force
  assign_bd_address -offset 0x000140000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM20] -force
  assign_bd_address -offset 0x000150000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM21] -force
  assign_bd_address -offset 0x000160000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM22] -force
  assign_bd_address -offset 0x000170000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM23] -force
  assign_bd_address -offset 0x000180000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM24] -force
  assign_bd_address -offset 0x000190000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM25] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM26] -force
  assign_bd_address -offset 0x0001B0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM27] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM28] -force
  assign_bd_address -offset 0x0001D0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM29] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM30] -force
  assign_bd_address -offset 0x0001F0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces tapa_accel1_0/m_axi_m1] [get_bd_addr_segs hbm_0/SAXI_01/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM00] -force
  assign_bd_address -offset 0x10000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM01] -force
  assign_bd_address -offset 0x20000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM02] -force
  assign_bd_address -offset 0x30000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM03] -force
  assign_bd_address -offset 0x40000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM04] -force
  assign_bd_address -offset 0x50000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM05] -force
  assign_bd_address -offset 0x60000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM06] -force
  assign_bd_address -offset 0x70000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM07] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM08] -force
  assign_bd_address -offset 0x90000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM09] -force
  assign_bd_address -offset 0xA0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM10] -force
  assign_bd_address -offset 0xB0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM11] -force
  assign_bd_address -offset 0xC0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM12] -force
  assign_bd_address -offset 0xD0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM13] -force
  assign_bd_address -offset 0xE0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM14] -force
  assign_bd_address -offset 0xF0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM15] -force
  assign_bd_address -offset 0x000100000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM16] -force
  assign_bd_address -offset 0x000110000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM17] -force
  assign_bd_address -offset 0x000120000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM18] -force
  assign_bd_address -offset 0x000130000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM19] -force
  assign_bd_address -offset 0x000140000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM20] -force
  assign_bd_address -offset 0x000150000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM21] -force
  assign_bd_address -offset 0x000160000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM22] -force
  assign_bd_address -offset 0x000170000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM23] -force
  assign_bd_address -offset 0x000180000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM24] -force
  assign_bd_address -offset 0x000190000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM25] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM26] -force
  assign_bd_address -offset 0x0001B0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM27] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM28] -force
  assign_bd_address -offset 0x0001D0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM29] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM30] -force
  assign_bd_address -offset 0x0001F0000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI] [get_bd_addr_segs hbm_0/SAXI_00/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_BYPASS] [get_bd_addr_segs tapa_accel1_0/s_axi_control/reg0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  #save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""




#####################start of rapidstream modification##########################
#                                                                              #
#                                                                              #
#

# Add kernel and connect the bus to memory according to ${CONFIG_FILE}
add_kernel ${CONFIG_FILE} ${kernel_name}

# Change the DCM frequency for the kernel
set_kernel_frequency ${KL_FREQ}

# Change the DCM frequency for the hbm axi
set_hbm_frequency ${HBM_FREQ}

# Set the kernel AXI buses to the correct frequencies
set_property CONFIG.FREQ_HZ [expr ${KL_FREQ} * 1000000] [get_bd_intf_pins /${kernel_name}_0/s_axi_control*]
set_property CONFIG.FREQ_HZ [expr ${KL_FREQ} * 1000000] [get_bd_intf_pins /${kernel_name}_0/m_axi_*]
assign_bd_address

# Create a hierarchical design for the kernel and interconnects 
# create_cl_hier ${CONFIG_FILE}
set_property -dict [list CONFIG.PROTOCOL.VALUE_SRC PROPAGATED CONFIG.DATA_WIDTH.VALUE_SRC USER] [get_bd_cells axi_register_slice_*]
set_property -dict [list CONFIG.DATA_WIDTH {256}] [get_bd_cells axi_register_slice_*]
set_property -dict [list CONFIG.PROTOCOL.VALUE_SRC USER] [get_bd_cells axi_register_slice_*]
set_property -dict [list CONFIG.PROTOCOL {AXI3}] [get_bd_cells axi_register_slice_*]

validate_bd_design
save_bd_design

set wrapper_path [make_wrapper -fileset sources_1 -files [ get_files -norecurse design_1.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper_path

set obj [get_filesets sources_1]
set_property -name "top" -value "design_1_wrapper" -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [get_designs impl_1]

#generate_target all [get_files ${_xil_proj_name_}_${freq_mhz}M_ipi_prj/${_xil_proj_name_}_${freq_mhz}M_ipi_prj.srcs/sources_1/bd/design_1/design_1.bd]

#launch_runs synth_1 -jobs 2
#wait_on_run synth_1

#launch_runs impl_1 -to_step write_bitstream -jobs 2
#wait_on_run impl_1

#                                                                              #
#                                                                              #
#######################end of rapidstream modification##########################
