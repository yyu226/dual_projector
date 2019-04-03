
# PlanAhead Launch Script for Post-Synthesis pin planning, created by Project Navigator

create_project -name dualpro -dir "C:/Users/Ying Yu/Desktop/Mojo_v3/dualpro/planAhead_run_2" -part xc6slx9tqg144-3
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "C:/Users/Ying Yu/Desktop/Mojo_v3/dualpro/top.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {C:/Users/Ying Yu/Desktop/Mojo_v3/dualpro} {ipcore_dir} }
add_files [list {ipcore_dir/ddsc.ncf}] -fileset [get_property constrset [current_run]]
set_param project.pinAheadLayout  yes
set_property target_constrs_file "top.ucf" [current_fileset -constrset]
add_files [list {top.ucf}] -fileset [get_property constrset [current_run]]
link_design
