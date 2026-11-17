# Inventaire (phase 1) : tclsh inventory.tcl PORT ETAT FICHIER_SORTIE
# Invoque chaque entrée de la barre de menus une fois, relève ce qu'elle ouvre
# (mode, fenêtres, dialogues), les widgets nouveaux, puis revient à l'état de départ.
lassign $argv port state out
source [file join [file dirname [info script]] walk.tcl]
W::connect $port
set fo [open $out w]
fconfigure $fo -buffering line

proc sigs {root} {lmap d [W::widgets $root] {W::sig $d}}
proc newwidgets {before root} {
    set b [dict create]
    foreach s $before {dict set b $s 1}
    set l {}
    foreach d [W::widgets $root] {
	if {! [dict exists $b [W::sig $d]] && [dict get $d class] ne "Menu"} {lappend l $d}
    }
    return $l
}
# ferme une fenêtre : bouton de fermeture s'il existe, sinon destroy
proc closetop {t} {
    foreach d [W::widgets $t] {
	if {[dict exists $d text] && [dict exists $d command] &&
	    [regexp -nocase {^\s*(close|dismiss|cancel|quit|done|ok|return)\s*$} [dict get $d text]]} {
	    set r [W::fire [list [dict get $d path] invoke] 20000]
	    if {! [W::ask [list winfo exists $t]]} {return "button [string trim [dict get $d text]]"}
	}
    }
    catch {W::ask [list destroy $t]}
    return destroy
}
set mode0 [W::ask probe::mode]
set skip {{File > Close} {File > Quit Ordalie}}
set items [W::menuitems]
puts $fo [list STATE $state mode0 $mode0 nitems [llength $items] macs [W::ask {catch {LesMacs} r; set r}]]
foreach it [concat [lmap i $items {expr {[dict get $i path] in $skip ? [continue] : $i}}] \
		[lmap i $items {expr {[dict get $i path] in $skip ? $i : [continue]}}]] {
    set p [dict get $it path]
    if {$p eq "File > Quit Ordalie"} {set wait 5000} else {set wait 45000}
    set before [sigs .]
    set tops0 [W::ask probe::tops]
    set m [dict get $it menu]; set i [dict get $it index]
    set d [W::fire [list $m invoke $i] $wait]
    set rec [dict create item $p type [dict get $it type] command [dict get $it command] accel [dict get $it accel]]
    dict set rec state [dict get $d state]
    if {[dict get $d state] eq "blocked"} {
	dict set rec stack [dict get $d stack]
	dict set rec grab [dict get $d grab]
    }
    # fenêtres nouvelles (ouvertes et éventuellement en attente)
    set tops1 [W::ask probe::tops]
    set newtops {}
    foreach t $tops1 {
	if {$t ni $tops0} {
	    set title ""; catch {set title [W::ask [list wm title $t]]}
	    lappend newtops [dict create top $t title $title widgets [lmap w [W::widgets $t] {
		dict filter $w key path class text label command values}]]
	}
    }
    dict set rec newtops $newtops
    set mode1 [W::ask probe::mode]
    dict set rec mode $mode1
    if {$mode1 ne $mode0} {
	dict set rec modewidgets [lmap w [newwidgets $before .] {dict filter $w key path class text label command values}]
    }
    # fermeture des fenêtres nouvelles
    set closed {}
    foreach t $newtops {lappend closed [dict get $t top] [closetop [dict get $t top]]}
    dict set rec closedby $closed
    if {[dict get $d state] eq "blocked"} {
	set d [W::waitfor [dict get $d id] 20000]
	dict set rec state_after_close [dict get $d state]
    }
    foreach k {code ms result errorInfo dialogs bgerrors} {
	if {[dict exists $d $k]} {dict set rec $k [dict get $d $k]}
    }
    # retour au mode de départ : bouton Return/Done du mode, sinon ChangeMode
    if {[W::ask probe::mode] ne $mode0} {
	set how ""
	set ws [W::widgets .ordali]
	foreach pat {return cancel {save & return} done back dismiss close} {
	    foreach w $ws {
		if {[dict exists $w text] && [dict exists $w command] &&
		    [string equal -nocase [string trim [dict get $w text]] $pat]} {
		    set r [W::fire [list [dict get $w path] invoke] 30000]
		    set how "button [string trim [dict get $w text]] ([dict get $w path]) -> [W::ask probe::mode]"
		    if {[dict exists $r bgerrors]} {append how " bgerrors: [dict get $r bgerrors]"}
		    if {[dict exists $r dialogs]} {append how " dialogs: [dict get $r dialogs]"}
		    if {[dict get $r state] eq "blocked"} {append how " BLOCKED"} elseif {[dict get $r code] == 1} {append how " ERROR: [lindex [split [dict get $r errorInfo] \n] 0]"}
		    break
		}
	    }
	    if {$how ne ""} break
	}
	if {[W::ask probe::mode] ne $mode0} {
	    set r [W::fire [list ChangeMode $mode0] 30000]
	    append how " ; ChangeMode $mode0 -> [W::ask probe::mode]"
	}
	dict set rec return $how
    }
    # case à cocher : on la remet dans son état
    if {[dict get $it type] in {checkbutton}} {W::fire [list $m invoke $i] 20000}
    puts $fo $rec
    puts "[format %-50s $p] [dict get $rec state] mode=$mode1 tops=[llength $newtops] [expr {[dict exists $rec code] && [dict get $rec code]==1 ? "ERROR" : ""}][expr {[dict exists $rec bgerrors] ? " BGERR" : ""}]"
}
close $fo
