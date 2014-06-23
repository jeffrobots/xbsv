
proc xbsv_set_board_part {} {
    global boardname
    if [catch {current_project}] {
	create_project -name synth_ip -in_memory
    }
    if {[lsearch [list_property [current_project]] board_part] >= 0} {
	set_property board_part "xilinx.com:$boardname:part0:1.0" [current_project]
    } else {
	## vivado 2013.2 uses the BOARD property instead
	set board_candidates [get_boards *$boardname*]
	set_property BOARD [lindex $board_candidates [expr [llength $board_candidates] - 1]] [current_project]
    }
}

proc xbsv_synth_ip {core_name core_version ip_name params} {
    global xbsvipdir boardname

    ## make sure we have a project configured for the correct board
    if [catch {current_project}] {
	xbsv_set_board_part
    }

    set generate_ip 0

    if [file exists $xbsvipdir/generated/xilinx/$boardname/$ip_name/$ip_name.xci] {
    } else {
	puts "no xci file $ip_name.xci"
	set generate_ip 1
    }
    if [file exists $xbsvipdir/generated/xilinx/$boardname/$ip_name/vivadoversion.txt] {
	gets [open $xbsvipdir/generated/xilinx/$boardname/$ip_name/vivadoversion.txt r] generated_version
	puts "generated_version $generated_version"
	set current_version [version -short]
	puts "current_version $current_version"
	if {$current_version != $generated_version} {
	    puts "vivado version does not match"
	    set generate_ip 1
	}
    } else {
	puts "no vivado version recorded"
	set generate_ip 1
    }

    ## check requested core version and parameters
    if [file exists $xbsvipdir/generated/xilinx/$boardname/$ip_name/coreversion.txt] {
	gets [open $xbsvipdir/generated/xilinx/$boardname/$ip_name/coreversion.txt r] generated_version
	set current_version "$core_name $core_version $params"
	puts "generated_version $generated_version"
	puts "current_version $current_version"
	if {$current_version != $generated_version} {
	    puts "core version or params does not match"
	    set generate_ip 1
	}
    } else {
	puts "no core version recorded"
	set generate_ip 1
    }

    puts "generate_ip $generate_ip"
    if $generate_ip {
	file delete -force $xbsvipdir/generated/xilinx/$boardname/$ip_name
	file mkdir $xbsvipdir/generated/xilinx/$boardname
	create_ip -name $core_name -version $core_version -vendor xilinx.com -library ip -module_name $ip_name -dir $xbsvipdir/generated/xilinx/$boardname
	set_property -dict $params [get_ips $ip_name]
	report_property [get_ips $ip_name]
	generate_target all [get_files $xbsvipdir/generated/xilinx/$boardname/$ip_name/$ip_name.xci]

	set versionfd [open $xbsvipdir/generated/xilinx/$boardname/$ip_name/vivadoversion.txt w]
	puts $versionfd [version -short]
	close $versionfd

	set corefd [open $xbsvipdir/generated/xilinx/$boardname/$ip_name/coreversion.txt w]
	puts $corefd "$core_name $core_version $params"
	close $corefd
    } else {
	read_ip $xbsvipdir/generated/xilinx/$boardname/$ip_name/$ip_name.xci
    }
    if [file exists $xbsvipdir/generated/xilinx/$boardname/$ip_name/$ip_name.dcp] {
    } else {
	catch {
	    synth_ip [get_ips $ip_name]
	}
    }
}
