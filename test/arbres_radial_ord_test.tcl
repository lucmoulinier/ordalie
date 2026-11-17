# Test des arbres radiaux d'un fichier ORD : le fichier s'ouvre, l'arbre restauré est dessiné
# comme avant la sauvegarde, et il réagit encore aux commandes.
# Usage : tclsh8.6 test/arbres_radial_ord_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    # coordonnées arrondies de tous les éléments du canvas de l'arbre
    W::ask {proc ::Dessin {a} {
	set c $::Abr($a,PAD)
	lmap i [$c find all] {lmap x [$c coords $i] {format %.1f $x}}
    }}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 60000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
}
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] arbres_[pid]]
file mkdir $Tmp
set ord $Tmp/a.ord

Start $Test/T_tutorial.ord
set La [W::ask {set ::Abr(Liste)}]
V "ouverture : arbres présents" {[llength $La] > 0} $La
V "ouverture : arbres radiaux" {[W::ask {lsort -unique [lmap a $::Abr(Liste) {set ::Abr($a,TypeTree)}]}] eq "radial"}
foreach a $La {
    V "arbre $a : fenêtre et dessin" {[W::ask "winfo exists \$::Abr($a,PAD)"] && [W::ask "llength \[\$::Abr($a,PAD) find all\]"] > 0}
    set D($a) [W::ask [list Dessin $a]]
}
set a [lindex $La 0]
# même état après un aller-retour dendrogramme / radial, redessiné par le code normal
F "redessin direct" [list OnReDessineArbre $a]
V "arbre $a : redessin identique" {[W::ask [list Dessin $a]] eq $D($a)}
F "sauvegarde ORD" [list SauveLAlignement ORD $ord]
Stop

Start $ord
V "réouverture : mêmes arbres" {[W::ask {set ::Abr(Liste)}] eq $La}
foreach a $La {
    set d [W::ask [list Dessin $a]]
    V "arbre $a : dessin identique après réouverture" {$d eq $D($a)} "[llength $d] éléments"
}
set a [lindex $La 0]
F "passage en dendrogramme" "set ::Abr($a,TypeTree) dendrogram; OnReDessineArbre $a"
F "retour en radial" "set ::Abr($a,TypeTree) radial; OnReDessineArbre $a"
V "arbre $a : retour radial identique" {[W::ask [list Dessin $a]] eq $D($a)}
Stop
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
