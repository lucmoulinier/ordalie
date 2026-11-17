# Consolidation des résultats de l'audit : tclsh consolide.tcl DIR SORTIE.md
lassign $argv dir out
proc recs {f} {
    set fh [open $f]; set acc ""; set l {}
    while {[gets $fh x] >= 0} {
	append acc $x \n
	if {! [info complete $acc]} continue
	set d [string trim $acc]; set acc ""
	if {$d ne ""} {lappend l $d}
    }
    close $fh
    return $l
}
proc norm {m} {
    regsub -all {\.[a-zA-Z0-9_#.]+} $m {<w>} m
    regsub -all {\d+} $m N m
    return $m
}
set tot [dict create]
set groups [dict create]
set msgs [dict create]
set valids [dict create]
set runs {}
foreach f [lsort [glob -nocomplain $dir/*.dat]] {
    set tag [file rootname [file tail $f]]
    if {[string match test_* $tag]} continue
    set n 0; set secs ?
    foreach d [recs $f] {
	set k [dict get $d kind]
	if {$k eq "end"} {set secs [dict get $d secs]}
	if {$k eq "restart"} {dict incr tot "$tag,restart"}
	if {$k eq "ctxfail"} {
	    set key "CTXFAIL [norm [lindex [split [dict get $d reason] \n] 0]]"
	    dict lappend groups $key [list $tag [dict get $d ctx] "" [dict get $d reason]]
	}
	if {$k ni {action scenario}} continue
	incr n
	set res [dict get $d result]
	dict incr tot "$tag,$res"
	dict incr tot "ALL,$res"
	set where [expr {$k eq "scenario" ? "scénario [dict get $d name]" : "[dict get $d ctx] → [dict get $d label] / [dict get $d action]"}]
	switch -- $res {
	    ERROR - BGERROR - DEAD - HANG {
		set ei ""
		if {[dict exists $d errorInfo]} {set ei [dict get $d errorInfo]}
		if {[dict exists $d bgerrors]} {append ei "\nbgerror: [join [dict get $d bgerrors] { ; }]"}
		set first [lindex [split [string trim $ei] \n] 0]
		if {$res in {DEAD HANG}} {set first "$res [expr {[dict exists $d stack] ? [lrange [dict get $d stack] 2 end-2] : ""}]"}
		set key "$res [norm $first]"
		dict lappend groups $key [list $tag $where [expr {[dict exists $d command] ? [dict get $d command] : ""}] $ei]
	    }
	    INVARIANT {
		foreach x [dict get $d invariants] {
		    set key "INVARIANT [norm [regsub {^(I[0-9]+) .*$} $x {\1}]] [norm [string range $x 0 70]]"
		    dict lappend groups $key [list $tag $where [expr {[dict exists $d command] ? [dict get $d command] : ""}] [join [dict get $d invariants] \n]]
		}
	    }
	    MSG - VALID {
		foreach x [dict get $d dialogs] {
		    if {[string match "exit:*" $x] || [string match "LanceDoc*" $x] || [string match "LogInBrowser*" $x] || [string match "PrintSetup*" $x]} continue
		    set key [norm [regsub {:.*} $x ""]]:[norm [string range [regsub {^[^:]*: } $x ""] 0 80]]
		    dict lappend msgs $key "$tag : $where"
		    if {$res eq "VALID" && [string match "FaireLire*" $x]} {dict lappend valids $key "$tag : $where"}
		}
	    }
	}
    }
    lappend runs [list $tag $n $secs]
}
set fo [open $out w]
puts $fo "# Résultats bruts de l'audit[expr {[info exists ::env(PHASE)] ? " (phase $::env(PHASE))" : ""}]\n"
puts $fo "Généré le [clock format [clock seconds] -format {%Y-%m-%d %H:%M}].\n"
puts $fo "## Totaux\n"
puts $fo "| Exécution | actions | OK | MSG | VALID | ERROR | BGERROR | DEAD | HANG | INVARIANT | autres | redémarrages | durée (s) |"
puts $fo "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
foreach r $runs {
    lassign $r tag n secs
    set c {}
    foreach k {OK MSG VALID ERROR BGERROR DEAD HANG INVARIANT} {lappend c [expr {[dict exists $tot "$tag,$k"] ? [dict get $tot "$tag,$k"] : 0}]}
    set other [expr {$n - [tcl::mathop::+ {*}$c]}]
    set rs [expr {[dict exists $tot "$tag,restart"] ? [dict get $tot "$tag,restart"] : 0}]
    puts $fo "| $tag | $n | [join $c { | }] | $other | $rs | $secs |"
}
puts $fo "\n## Erreurs regroupées ([dict size $groups] groupes)\n"
foreach key [lsort [dict keys $groups]] {
    set l [dict get $groups $key]
    puts $fo "### $key\n"
    puts $fo "- Occurrences : [llength $l] ; exécutions : [lsort -unique [lmap x $l {lindex $x 0}]]"
    set shown 0
    foreach x [lsort -unique -index 1 $l] {
	if {[incr shown] > 6} {puts $fo "- …"; break}
	puts $fo "- [lindex $x 0] : [lindex $x 1][expr {[lindex $x 2] ne "" ? " (commande `[string range [lindex $x 2] 0 80]`)" : ""}]"
    }
    set ei [lindex $l 0 3]
    puts $fo "\n```\n[join [lrange [split $ei \n] 0 14] \n]\n```\n"
}
puts $fo "\n## Actions bloquées par la validation ([dict size $valids] messages distincts)\n"
puts $fo "Le code après le message n'a pas été atteint. Un message très fréquent signale une saisie que le banc ne sait pas encore donner.\n"
foreach {key l} [lsort -stride 2 -index 0 $valids] {
    puts $fo "- **$key** — [llength $l] fois, ex. [lindex $l 0]"
}
puts $fo "\n## Messages affichés à l'utilisateur ([dict size $msgs] distincts)\n"
puts $fo "La plupart sont des messages de contexte attendus. Ils sont listés ici pour repérer ceux qui n'ont pas lieu d'être.\n"
foreach key [lsort [dict keys $msgs]] {
    set l [dict get $msgs $key]
    puts $fo "- **$key** — [llength $l] fois, ex. [lindex $l 0]"
}
close $fo
puts "écrit $out : [dict size $groups] groupes d'erreurs, [dict size $msgs] messages"
