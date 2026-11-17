# Bibliothèque client pour parcourir l'interface d'une instance sondée.
#   source walk.tcl ; W::connect PORT ; W::ask script ; W::fire script ?ms?
namespace eval W {variable ch ""}

proc W::connect {port} {
    variable ch
    if {$ch ne ""} {catch {close $ch}}
    set ch [socket 127.0.0.1 $port]
    fconfigure $ch -buffering line -translation lf -encoding utf-8
}
proc W::raw {s} {
    variable ch
    puts $ch [binary encode base64 [encoding convertto utf-8 $s]]
    return [encoding convertfrom utf-8 [binary decode base64 [gets $ch]]]
}
# évaluation directe ; erreur Tcl de la sonde -> erreur locale
proc W::ask {s} {
    set r [W::raw $s]
    if {[dict get $r status] eq "error"} {error "probe: [dict get $r errorInfo]"}
    return [dict get $r result]
}
# lance une action et attend ; renvoie le bilan (dict) avec state done ou blocked
proc W::fire {s {ms 60000}} {
    set id [W::ask [list probe::fire $s]]
    set t0 [clock milliseconds]
    while 1 {
	set d [W::ask [list probe::status $id]]
	if {[dict get $d state] eq "done"} {dict set d id $id; return $d}
	if {[clock milliseconds]-$t0 > $ms} {dict set d state blocked; dict set d id $id; return $d}
	after 100
    }
}
# attend la fin d'une action déjà lancée
proc W::waitfor {id {ms 30000}} {
    set t0 [clock milliseconds]
    while 1 {
	set d [W::ask [list probe::status $id]]
	if {[dict get $d state] eq "done"} {dict set d id $id; return $d}
	if {[clock milliseconds]-$t0 > $ms} {dict set d state blocked; dict set d id $id; return $d}
	after 100
    }
}
# widgets visibles avec une commande (ou de saisie) : liste de dicts
proc W::widgets {{root .}} {
    set l {}
    foreach d [W::ask [list probe::widgets $root]] {
	if {[dict get $d class] eq "Menu" || [dict get $d mapped]} {lappend l $d}
    }
    return $l
}
proc W::sig {d} {
    set s [dict get $d path]
    foreach k {class text label command values} {if {[dict exists $d $k]} {append s "|[dict get $d $k]"}}
    return $s
}
# entrées de la barre de menus, à plat : {chemin-libellé menu index type commande}
proc W::menuitems {{m .menuBar} {prefix ""}} {
    set out {}
    foreach e [W::ask [list probe::menuentries $m]] {
	set t [dict get $e type]
	if {$t in {separator tearoff}} continue
	set lab [string trim [dict get $e label]]
	set p [expr {$prefix eq "" ? $lab : "$prefix > $lab"}]
	if {$t eq "cascade"} {
	    lappend out {*}[W::menuitems [dict get $e menu] $p]
	} else {
	    set cmd [expr {[dict exists $e command] ? [dict get $e command] : ""}]
	    set acc [expr {[dict exists $e accelerator] ? [dict get $e accelerator] : ""}]
	    lappend out [dict create path $p menu $m index [dict get $e i] type $t command $cmd accel $acc]
	}
    }
    return $out
}
