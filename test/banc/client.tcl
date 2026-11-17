# client : tclsh client.tcl PORT ?-fire? ?-wait ms? script
#   sans -fire : évalue script dans l'instance et affiche le résultat
#   -fire : lance script par probe::fire, attend la fin (ou -wait ms), affiche le bilan
set port [lindex $argv 0]
set argv [lrange $argv 1 end]
set fire 0; set wait 30000
while {[string match -* [lindex $argv 0]]} {
    switch -- [lindex $argv 0] {
	-fire {set fire 1; set argv [lrange $argv 1 end]}
	-wait {set wait [lindex $argv 1]; set argv [lrange $argv 2 end]}
	default break
    }
}
set script [join $argv " "]
if {[catch {socket 127.0.0.1 $port} ch]} {puts "NOCONNECT $ch"; exit 3}
fconfigure $ch -buffering line -translation lf -encoding utf-8
proc ask {s} {
    puts $::ch [binary encode base64 [encoding convertto utf-8 $s]]
    set r [encoding convertfrom utf-8 [binary decode base64 [gets $::ch]]]
    return $r
}
if {! $fire} {
    set r [ask $script]
    if {[dict get $r status] eq "error"} {puts "ERROR: [dict get $r errorInfo]"; exit 1}
    puts [dict get $r result]
    exit 0
}
set id [dict get [ask [list probe::fire $script]] result]
set t0 [clock milliseconds]
while 1 {
    set d [dict get [ask [list probe::status $id]] result]
    if {[dict get $d state] eq "done"} break
    if {[clock milliseconds]-$t0 > $wait} {
	puts "BLOCKED id=$id after ${wait}ms"
	foreach k {tops0 tops1 grab stack dialogs bgerrors} {if {[dict exists $d $k]} {puts "  $k: [dict get $d $k]"}}
	exit 2
    }
    after 150
}
puts "id=$id code=[dict get $d code] ms=[dict get $d ms] mode=[dict get $d mode0]->[dict get $d mode1]"
set new [lmap w [dict get $d tops1] {expr {$w in [dict get $d tops0] ? [continue] : $w}}]
set gone [lmap w [dict get $d tops0] {expr {$w in [dict get $d tops1] ? [continue] : $w}}]
puts "  newtops: $new  closed: $gone"
foreach k {dialogs bgerrors} {if {[dict exists $d $k]} {foreach x [dict get $d $k] {puts "  [string range $k 0 end-1]: $x"}}}
if {[dict get $d code] == 1} {puts "  ERROR: [join [lrange [split [dict get $d errorInfo] \n] 0 12] "\n    "]"} else {puts "  result: [string range [dict get $d result] 0 300]"}
exit [expr {[dict get $d code] == 1 || [dict exists $d bgerrors]}]
