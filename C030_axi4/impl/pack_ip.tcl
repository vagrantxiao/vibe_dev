
create_project project_1 ./project_1 -part xczu3eg-sbva484-1-i -force
set_property board_part avnet.com:ultra96v2:part0:1.1 [current_project]
add_files -norecurse {../hdl/axi4_ar.sv \
                      ../hdl/datamover_m1_m_axi.sv \
                      ../hdl/skid_buffer.sv \
                      ../hdl/axi4_r.sv \
                      ../hdl/axi4_w.sv \
                      ../hdl/axi4_aw.sv}
update_compile_order -fileset sources_1
ipx::package_project -root_dir ./my_ip -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false
ipx::unload_core ./my_ip/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ./my_ip ./my_ip/component.xml
update_compile_order -fileset sources_1
set_property core_revision 2 [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::move_temp_component_back -component [ipx::current_core]
close_project -delete
set_property  ip_repo_paths  ./my_ip [current_project]
update_ip_catalog
