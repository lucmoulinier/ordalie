#
# GroupSim + ConsWin (src/ordali_groupsim.tcl) against the reference code
# of Capra & Singh 2008, column by column, tolerance 1e-6.
#   tclsh8.6 test/groupsim_vs_ref.tcl <group_sim_sdp.py> <workdir> [reference options] alignfile gid1 gid2 ...
# Reference options : -w window -l lambda -c column gaps -g group gaps -n
# Needs python2.7. Prints "OK <ncols> <max |diff|>" or the differences.
#
set Here [file dirname [file normalize [info script]]]
source [file join [file dirname $Here] src ordali_groupsim.tcl]

lassign $argv RefScript WorkDir
set Largs [lrange $argv 2 end]
set Opts {}
set i 0
while {[string index [lindex $Largs $i] 0] eq "-"} {
    set o [lindex $Largs $i]
    switch -- $o {
	-w {lappend Opts -window [lindex $Largs [incr i]]}
	-l {lappend Opts -lambda [lindex $Largs [incr i]]}
	-c {lappend Opts -colgap [lindex $Largs [incr i]]}
	-g {lappend Opts -grpgap [lindex $Largs [incr i]]}
	-n {lappend Opts -norm 1}
	default {error "unknown option $o"}
    }
    incr i
}
set Out [file join $WorkDir [file rootname [file tail [lindex $Largs $i]]].gs]
exec python2.7 -E -s [file join $Here groupsim_refrun.py] $RefScript $Out {*}$Largs 2>@1

set Lseqs {} ; set Lgi {}
set f [open $Out.aln]
foreach l [split [string trimright [read $f] \n] \n] {
    lassign [split $l \t] n g s
    lappend Lseqs $s
    lappend Lgi $g
}
close $f
set Lref {}
set f [open $Out]
foreach l [split [string trimright [read $f] \n] \n] {
    lappend Lref [lindex [split $l \t] 1]
}
close $f

set Lmoi [ScoreDeGroupSim $Lseqs $Lgi {*}$Opts]
set max 0.0 ; set nerr 0 ; set nnone 0
foreach r $Lref m $Lmoi k [lsearch -all $Lref *] {
    if {$r eq "None" || $m == -999.0} {
	if {$r ne "None" || $m != -999.0} {
	    incr nerr
	    puts "col $k : reference $r, Ordalie $m"
	}
	incr nnone
	continue
    }
    set d [expr {abs($r - $m)}]
    if {$d > $max} {set max $d}
    if {$d > 1e-6} {
	incr nerr
	puts "col $k : reference $r, Ordalie $m"
    }
}
puts [format "%s %s : %d columns (%d not scored), %d groups, max |diff| %.3g" \
	  [expr {$nerr ? "FAILED" : "OK"}] [file tail [lindex $Largs $i]] [llength $Lref] $nnone \
	  [expr {[tcl::mathfunc::max {*}$Lgi] + 1}] $max]
exit [expr {$nerr != 0}]
