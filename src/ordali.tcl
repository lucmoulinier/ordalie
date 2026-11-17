#!/usr/local/bin/tclsh
###!/home/moumou/tcl/bin/wish8.6
###!/home/moumou/tk8.6.11/inst/bin/wish8.6
###!/home/moumou/tcl9/bin/wish9.0
###!/home/moumou/tk/bin/wish8.6
###!/usr/local/ActiveTcl/bin/tclsh




# Test if we are in a starpack or not
set InStarPack [regexp {app-ordalie} [info script]]
if {! $InStarPack} {
    if {$tcl_version <= 8.5} {
	package require TclOO
    }
    
    if {[info exists env(ORDALIDIR)]} {
	set OrdaliDir $env(ORDALIDIR)
    } else {
	set script [info script]
	if {! [catch {file link $script}]} {
	    set script [file link $script]
	}
	set OrdaliDir [file join {*}[lrange [file split [file normalize $script]] 0 end-2]]
    }

    if {[info exists env(GSCOPEDIR)]} {
	set GscopeDir $env(GSCOPEDIR)
    }
    if {$::env(USER) eq "moumou"} {
	if {[info exists [file join $OrdaliDir .. gscoperso]]} {
	    source [file join $OrdaliDir .. gscoperso gscope_source.tcl]
	}
    }
} else {
    # in starpack
    set OrdaliDir [file normalize [file join [file dirname [file normalize [info script]]] .. .. ..]]
    if {[string range $OrdaliDir end-2 end] eq "bin"} {
	set OrdaliDir [file normalize [file join $OrdaliDir ..]]
    }
    puts "info script [info script]"
    puts "OrdaliDir $OrdaliDir"
}

package require platform
if {! $InStarPack} {
    if {[string first "linu" [::platform::generic]] == -1} {
	set OrdLibDir [file join $OrdaliDir Build [::platform::generic] lib]
    } else {
	# pour biolo
	set OrdLibDir [file join $OrdaliDir lib]
    }
} else {
    # in startpack
    set OrdLibDir [file join $OrdaliDir lib]
}
set OrdEtcDir [file join $OrdaliDir etc]
set OrdSrcDir [file join $OrdaliDir src]

set ::auto_path [linsert $::auto_path 0 $OrdLibDir]
    

################
# special profiling arguments
if {[lindex $argv 0] eq "-OProfiling"} {
    proc TurluRename {args} {
	puts "$args"
    }
    #trace add execution rename leave TurluRename

    package require profiler
    ::profiler::init
    set argv [lreplace $argv 0 0]
}


###########
# Source the code
set GlobalsAuDepart [info globals]
set ProcsAuDepart   [info procs]
if {! $InStarPack} {
    if {! [info exists GscopeDir]} {
	source [file join $OrdSrcDir LesProcsDeGscope.tcl]
	    set GscopeDir $OrdaliDir
    } else {
	set OrdaliDejaSource 1
	source [file join $GscopeDir gscope_source.tcl]
    }
    
    set OrdaliDejaSource 0
    source [file join $OrdSrcDir ordali_source.tcl]
}

set VariablesAuDepart [info globals]

### Launch ORDALIE ######
# Main program

InitLesDefauts

set retour [InterpreteLaLigneDeCommande $argv]

LoadTclPackages
if {[ModeI]} {
    LoadTkAndPackages
}

if {$retour eq ""} {
    LanceOrdali master 
}

######## Ca finit ici #####################

