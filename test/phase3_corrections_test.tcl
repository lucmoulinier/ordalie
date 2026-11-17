# Test des corrections F1 à F3 (bugs trouvés par la phase 3, 2026-11-06) et des titres des fenêtres :
# F1 Cons-T80 stable après Overwrite et réouverture, F2 Re-align : séparateurs et Sequences à la nouvelle
# longueur, F3 couleur des structures après retrait des séparateurs, titres « Instance <nom> ».
# Usage : tclsh8.6 test/phase3_corrections_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Cons {} {Q {set r {}; foreach k [lsort [array names ::TabSF *,Cons-T80]] {lappend r $k [llength $::TabSF($k)]}; set r}}
proc Doublons {} {Q {set n 0; foreach k [array names ::TabSF *,Cons-*] {incr n [expr {[llength $::TabSF($k)] - [llength [lsort -unique $::TabSF($k)]]}]}; set n}}
proc Sel {lignes} {
    Q {set ::PosInitNom 1.0}
    set premier 1
    foreach l $lignes {
	W::fire [list SelectNomSeq [expr {$premier ? "une" : "ctr"}] $l.0] 20000
	set premier 0
    }
}

if {[catch {
    puts "=== F1"
    Start $Test/T_tutorial_maj.ord
    set C0 [Cons]
    V "F1 : feature Cons-T80 présente" {[llength $C0] > 0}
    F "F1 : Overwrite" {SauveLeMac 0}
    F "F1 : sauvegarde" [list SauveLAlignement ORD $Tmp/f1.ord]
    Stop
    Start $Tmp/f1.ord
    V "F1 : Cons-T80 identique après Overwrite et réouverture" {[Cons] eq $C0} [lrange [Cons] 0 3]
    F "F1 : deuxième Overwrite" {SauveLeMac 0}
    F "F1 : deuxième sauvegarde" [list SauveLAlignement ORD $Tmp/f1b.ord]
    Stop
    Start $Tmp/f1b.ord
    V "F1 : identique après un deuxième cycle" {[Cons] eq $C0} [lrange [Cons] 0 3]
    V "F1 : aucun élément en double" {[Doublons] == 0} [Doublons]
    Stop

    puts "=== F2"
    Start $Test/T_tutorial_maj.ord
    Sel {3 4}
    V "F2 : deux séquences sélectionnées" {[llength [Q {set ::NomSeqSel}]] == 2} [Q {set ::NomSeqSel}]
    F "F2 : Re-align" ReAlignSeqs 600000
    set Lg [Q {lsort -unique [lmap s $::LSOrdali {expr {$s eq "" ? [continue] : [string length $s]}}]}]
    V "F2 : séparateurs compris, une seule longueur" {[llength $Lg] == 1} $Lg
    V "F2 : longueur = LongueurTotale" {$Lg == [Q {set ::LongueurTotale}]} "$Lg [Q {set ::LongueurTotale}]"
    V "F2 : Sequences mis à jour" {[Q {set r 0; foreach n $::LNOrdali s $::LSOrdali {set n [string trim $n]; if {$n ne "" && $::Sequences($n) ne $s} {incr r}}; set r}] == 0}
    V "F2 : Please Wait fermée" {! [Q {winfo exists .fattendre}]}
    Inv "F2"
    Stop

    puts "=== F3"
    Start $Test/T_tutorial_maj.ord
    set ns [Q {llength [lsearch -all -regexp $::LNOrdali {^\s*$}]}]
    F "F3 : Remove All separators" RemoveAllSeparators
    V "F3 : séparateurs retirés (sauf premier et dernier)" {[Q {llength [lsearch -all -regexp $::LNOrdali {^\s*$}]}] <= 2} "avant $ns"
    Inv "F3 : après Remove All separators"
    Sel {5}
    F "F3 : ajout d'un séparateur" AddSpaceSeq
    Inv "F3 : après ajout d'un séparateur"
    set y [expr {[lsearch -regexp [lrange [Q {set ::LNOrdali}] 1 end] {^\s*$}] + 2}]
    Sel [list $y]
    F "F3 : retrait de ce séparateur" RemoveSpaceSeq
    Inv "F3 : après retrait d'un séparateur"
    Stop

    puts "=== titres"
    Start $Test/T_tutorial_maj.ord
    foreach a [Q {set ::Abr(Liste)}] {
	set pk [Q "set ::Abr($a,Mac)"]
	set nm [Q "\$::db onecolumn {select name from snapshot where pk_snap = $pk}"]
	set t [Q "wm title .arbre$a"]
	V "arbre $a : instance dans le titre" {$t eq "Tree No $a - Instance $nm"} $t
    }
    F "overview" AfficheOverview
    set o [Q {lindex $::Ovw(Liste) end}]
    set t [Q "wm title .overview$o"]
    V "overview : instance dans le titre" {$t eq "Overview No $o - Instance [Q {MacCourant name}]"} $t
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
