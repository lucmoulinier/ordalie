# Outils communs des tests de la phase 3 (pilotage d'une instance par le banc, voir test/banc/README.txt).
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set Test [file dirname [file dirname [file normalize [info script]]]]
set Sonde [file join $Test phase3 sonde.tcl]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] phase3_[pid]]
file mkdir $Tmp

proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 400]"
    if {! $ok} {incr ::Echecs}
    return $ok
}
proc Start {f} {
    exec $::P/gui_instance.sh start $::N {*}[expr {$f eq "" ? "" : [list $f]}] </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    W::ask [list source $::Sonde]
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
# action lancée hors du gestionnaire de la sonde ; échec si erreur, erreur de fond ou blocage
proc F {tag cmd {ms 180000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
    return $r
}
proc Dialogues {r} {expr {[dict exists $r dialogs] ? [dict get $r dialogs] : ""}}
# contrôles d'état de la sonde
proc Inv {tag} {
    set v [W::ask ::P3::Invariants]
    V "$tag : état cohérent" {$v eq ""} [join $v " ; "]
}
# compare deux empreintes clé par clé
proc Same {tag a b} {
    set n 0
    foreach k [lsort -unique [concat [dict keys $a] [dict keys $b]]] {
	set va [expr {[dict exists $a $k] ? [dict get $a $k] : "(absent)"}]
	set vb [expr {[dict exists $b $k] ? [dict get $b $k] : "(absent)"}]
	if {$va ne $vb} {
	    V "$tag : $k identique" 0 "avant <[string range $va 0 150]> après <[string range $vb 0 150]>"
	    incr n
	}
    }
    if {! $n} {V "$tag : [dict size $a] éléments identiques" 1}
    return [expr {$n == 0}]
}
proc Fin {} {
    catch {file delete -force $::Tmp}
    puts "BILAN : $::Echecs échec(s)"
    exit [expr {$::Echecs ? 1 : 0}]
}
