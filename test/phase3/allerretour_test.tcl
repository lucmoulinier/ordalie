# Phase 3 : aller-retour d'état. Pour chaque fichier, l'empreinte de chaque instance (séquences,
# features, groupes, structures et leurs coordonnées, structures secondaires, objets 3D, arbres dessinés,
# noms colorés, description) est prise, le fichier est sauvé en ORD puis rouvert, et l'empreinte doit être
# la même. Puis deux Overwrite de l'instance courante et un nouvel aller-retour : rien ne doit dériver.
# Usage : tclsh8.6 test/phase3/allerretour_test.tcl [numéro d'instance] [fichiers...]
set N [expr {$argc ? [lindex $argv 0] : 7}]
source [file join [file dirname [file normalize [info script]]] commun.tcl]
set Fichiers [lrange $argv 1 end]
if {$Fichiers eq ""} {
    set Fichiers [list $Test/T_tutorial_maj.ord $Test/R_tutorial_maj.ord $Test/I_maj.xml]
    set riche $env(HOME)/.cache/claude-ordalie-tests/donnees/T_riche.ord
    if {[file exists $riche]} {lappend Fichiers $riche}
}

proc Ouvre {f} {
    Start $f
    Inv "[file tail $f] : ouverture"
}

foreach f $Fichiers {
    set t [file tail $f]
    puts "=== $t"
    if {[catch {
	Ouvre $f
	set E0 [W::ask ::P3::EmpreinteFichier]
	set M0 [W::ask {MacCourant name}]
	dict for {m e} $E0 {V "$t, $m : état cohérent" {[dict get $e invariants] eq ""} [join [dict get $e invariants] " ; "]}
	Inv "$t : après le tour des instances"
	F "$t : sauvegarde ORD" [list SauveLAlignement ORD $Tmp/a.ord]
	Stop
	Ouvre $Tmp/a.ord
	V "$t : même instance courante" {[W::ask {MacCourant name}] eq $M0} [W::ask {MacCourant name}]
	set E1 [W::ask ::P3::EmpreinteFichier]
	V "$t : mêmes instances" {[dict keys $E1] eq [dict keys $E0]} [dict keys $E1]
	dict for {m e} $E0 {
	    if {[dict exists $E1 $m]} {Same "$t, $m, après réouverture" $e [dict get $E1 $m]}
	}
	# Overwrite répété de l'instance courante (le défaut C8 s'accumulait ainsi)
	F "$t : Overwrite 1" {SauveLeMac 0}
	F "$t : Overwrite 2" {SauveLeMac 0}
	Inv "$t : après Overwrite"
	Same "$t, $M0, après deux Overwrite" [dict remove [dict get $E1 $M0] invariants] [W::ask ::P3::Empreinte]
	F "$t : deuxième sauvegarde ORD" [list SauveLAlignement ORD $Tmp/b.ord]
	Stop
	Ouvre $Tmp/b.ord
	set E2 [W::ask ::P3::EmpreinteFichier]
	dict for {m e} $E0 {
	    if {[dict exists $E2 $m]} {Same "$t, $m, après le deuxième aller-retour" $e [dict get $E2 $m]}
	}
	Stop
    } m]} {
	V "$t : script" 0 $m
	catch Stop
    }
}
Fin
