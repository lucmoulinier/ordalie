# Alignment > Editor (mode seqlab) : actions des touches, appelées par leurs procédures (curseur posé avec
# « cursor ») : Espace = gap dans la séquence, lettre = résidu (refusé si verrouillé), Retour arrière,
# Maj+flèche (push). Save & Return : alignement, Sequences et features (mêmes résidus couverts) mis à jour,
# instance modifiée ; sauvegarde ORD et réouverture ; Cancel ne change rien.
# Usage : tclsh8.6 test/saisies/editeur_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Rang {y} {Q "join \[lindex \$::LSSeqlab [expr {$y-1}]\] {}"}
proc Curseur {y x} {Q "\$::NomTextSeq cursor $y.$x"}
# bouton d'après son libellé
proc Bouton {texte} {
    Q [string map [list @T $texte] {
	set L [list .]; set b ""
	while {$L ne {}} {
	    set L [lassign $L x]; lappend L {*}[winfo children $x]
	    if {[winfo class $x] eq "Button" && [$x cget -text] eq {@T}} {set b $x; break}
	}
	set b
    }]
}
proc Brut {s} {string map {. ""} $s}
# résidus couverts par chaque élément d'une feature : {début fin résidus}
proc Couverts {n f} {
    Q [string map [list @N $n @F $f] {
	set r {}
	if {[info exists ::TabSF(@N,@F)]} {
	    foreach e $::TabSF(@N,@F) {lappend r [string map {. ""} [string range $::Sequences(@N) [dict get $e fstart] [dict get $e fstop]]]}
	}
	set r
    }]
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    # une séquence portant des éléments PFAM-A
    set n [lindex [Q {lmap k [lsort [array names ::TabSF *,PFAM-A]] {string range $k 0 end-7}}] 2]
    set y [expr {[lsearch [Q {lmap n $::LNOrdali {string trim $n}}] $n] + 1}]
    set s0 [Q "set ::Sequences($n)"]
    set e0 [lindex [Q "set ::TabSF($n,PFAM-A)"] 0]
    set c [expr {[dict get $e0 fstart] - 5}]
    while {[string index $s0 $c] eq "."} {incr c -1}
    set Cov0 [Couverts $n PFAM-A]
    puts "     $n (ligne $y), colonne $c, élément [dict get $e0 fstart]-[dict get $e0 fstop]"
    F "Editor" {ChangeMode seqlab} 60000
    V "mode Editor" {[Q InSeqlabMode]}
    V "Editor : même séquence" {[Rang $y] eq $s0}
    set w [Q {set ::NomTextSeq}]
    # verrouillé : pas de résidu
    Q {set ::LockSeqs 1; EtatLockSeqs}
    Curseur $y $c
    F "lettre W (verrouillé)" "BindTextKey $w w"
    V "verrouillé : résidu refusé" {[Brut [Rang $y]] eq [Brut $s0]} [string range [Rang $y] [expr {$c-3}] [expr {$c+3}]]
    # gap
    Curseur $y $c
    F "Espace" "BindTextSpace $w nogroup"
    set s1 [Rang $y]
    V "Espace : gap à la colonne $c" {[string index $s1 $c] eq "." && [string range $s1 0 [expr {$c-1}]] eq [string range $s0 0 [expr {$c-1}]] && [string range $s1 [expr {$c+1}] [string length $s0]] eq [string range $s0 $c end]} [string range $s1 [expr {$c-3}] [expr {$c+3}]]
    V "Espace : mêmes résidus" {[Brut $s1] eq [Brut $s0]}
    # retour arrière derrière le gap : le gap part
    Curseur $y [expr {$c+1}]
    F "Retour arrière (gap)" "ActionSeqlab $w backspace"
    V "Retour arrière : gap retiré" {[string range [Rang $y] 0 [expr {[string length $s0]-1}]] eq $s0} [string range [Rang $y] [expr {$c-3}] [expr {$c+3}]]
    # retour arrière derrière un résidu, verrouillé : refusé
    Curseur $y [expr {$c+1}]
    F "Retour arrière (résidu, verrouillé)" "ActionSeqlab $w backspace"
    V "verrouillé : résidu gardé" {[Brut [Rang $y]] eq [Brut $s0]}
    # déverrouillé : résidu inséré puis retiré
    Q {set ::LockSeqs 0; EtatLockSeqs}
    Curseur $y $c
    F "lettre W (déverrouillé)" "BindTextKey $w w"
    set s2 [Rang $y]
    V "déverrouillé : W inséré" {[string index $s2 $c] eq "W" && [Brut $s2] eq "[Brut [string range $s0 0 [expr {$c-1}]]]W[Brut [string range $s0 $c end]]"} [string range $s2 [expr {$c-3}] [expr {$c+3}]]
    Curseur $y [expr {$c+1}]
    F "Retour arrière (W)" "ActionSeqlab $w backspace"
    V "W retiré" {[Brut [Rang $y]] eq [Brut $s0]}
    Q {set ::LockSeqs 1; EtatLockSeqs}
    # deux gaps gardés pour la suite
    Curseur $y $c
    F "Espace" "BindTextSpace $w nogroup"
    Curseur $y $c
    F "Espace" "BindTextSpace $w nogroup"
    set sE [Rang $y]
    F "Save & Return" "[Bouton {Save & Return}] invoke" 120000
    V "retour au mode normal" {! [Q InSeqlabMode]}
    V "Sequences mis à jour" {[string trimright [Q "set ::Sequences($n)"] .] eq [string trimright $sE .]} [string range [Q "set ::Sequences($n)"] [expr {$c-3}] [expr {$c+3}]]
    V "mêmes résidus" {[Brut [Q "set ::Sequences($n)"]] eq [Brut $s0]}
    V "features : mêmes résidus couverts" {[Couverts $n PFAM-A] eq $Cov0} "[lindex [Couverts $n PFAM-A] 0] / [lindex $Cov0 0]"
    set e1 [lindex [Q "set ::TabSF($n,PFAM-A)"] 0]
    V "élément décalé de 2 colonnes" {[dict get $e1 fstart] == [dict get $e0 fstart] + 2} "[dict get $e1 fstart] (avant [dict get $e0 fstart])"
    V "instance modifiée" {[Q VueEditee]}
    Inv "après Save & Return"
    set sR [Q "set ::Sequences($n)"]
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/e.ord] 120000
    Stop
    Start $Tmp/e.ord
    V "réouverture : séquence éditée" {[Q "set ::Sequences($n)"] eq $sR}
    V "réouverture : features" {[Couverts $n PFAM-A] eq $Cov0}
    Inv "réouverture"

    puts "=== Cancel"
    set sC [Q "set ::Sequences($n)"]
    F "Editor" {ChangeMode seqlab} 60000
    Curseur $y $c
    F "Espace" "BindTextSpace [Q {set ::NomTextSeq}] nogroup"
    F "Cancel" "[Bouton Cancel] invoke" 120000
    V "Cancel : séquence inchangée" {[Q "set ::Sequences($n)"] eq $sC}
    V "Cancel : affichage inchangé" {[lindex [Q {$::NomTextSeq output all}] [expr {$y-1}]] eq $sC}
    V "Cancel : instance non modifiée" {! [Q VueEditee]}
    Inv "après Cancel"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
