

set PART "xczu3eg-sbva484-1-i"

proc log_info {msg} {
  puts "\[INFO\] $msg"
}

proc log_warn {msg} {
  puts stderr "\[WARNING\] $msg"
}

proc fail {msg} {
  puts stderr "\[ERROR\] $msg"
  error $msg
}

proc source_or_add_files {dir} {
  set contents [lsort [glob -nocomplain -directory $dir *]]
  foreach item $contents {
    if {[file isdirectory $item]} {
      continue
    }
    if { [file extension $item] eq ".tcl" } {
      source $item
    } else {
      add_files -norecurse $item
    }
  }
}

proc require_exists {path label} {
  if {![file exists $path]} {
    fail "$label does not exist: $path"
  }
}

proc require_directory {path label} {
  require_exists $path $label
  if {![file isdirectory $path]} {
    fail "$label is not a directory: $path"
  }
}

proc main {argv} {
  global PART
  set script_dir [file dirname [file normalize [info script]]]
  set repo_root [file normalize [file join $script_dir .. .. ..]]

  if {[llength $argv] < 2} {
    fail "Usage: vivado -tclargs <top> <src_dir1> <src_dir2> ..."
  }

  set top [lindex $argv 0]
  log_info "Using top: $top"

  set_param general.maxThreads  8
  set logFileId [open ./runme.log "w"]
  set start_time [clock seconds]
  create_project prj prj -part ${PART} -force
  # set_property board_part avnet.com:ultra96v2:part0:1.1 [current_project]
  set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]

  set src_dirs [lrange $argv 1 end]
  foreach dir $src_dirs {
    set dir [file normalize $dir]
    require_directory $dir "dir"
    log_info "Adding files from: $dir"
    source_or_add_files $dir
  }
  set_property top ${top} [current_fileset]
  update_compile_order -fileset sources_1

  # launch_runs synth_1 -jobs 6 -mode out_of_context
  # wait_on_run synth_1
  synth_design -top ${top} -part ${PART} -mode out_of_context
  
  # open_run synth_1 -name synth_1
  write_checkpoint -force page_netlist.dcp
  set end_time [clock seconds]
  set total_seconds [expr $end_time - $start_time]
  puts $logFileId "syn: $total_seconds seconds"
  report_utilization -hierarchical > utilization.rpt
}

main $argv



