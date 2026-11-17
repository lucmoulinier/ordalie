# Test du groupe des séquences (GroupeDeLaSequence) au changement d'instance et après l'ajout d'une
# structure, signalé par l'utilisateur le 2026-11-09 : sur T_tutorial_maj.ord, la lecture de E9AEW4.feat
# (FEATURE ... PROPAGATE group) donnait « can't read GroupeDeLaSequence(E9AEW4_A) ».
#  - après chaque changement d'instance, chaque séquence a un groupe, et seulement celles de l'instance ;
#  - en M4, ajout de la structure E9AEW4 par son access UniProt, déjà chargée pour M5 (était refusé) ;
#  - lecture de E9AEW4.feat en M4 et en M5, puis viewer 3D.
# Usage : tclsh8.6 test/groupes_instance_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Groupes {t} {
    set sans [Q {set r {}; foreach n $::LNOrdali {set n [string trim $n]; if {$n ne "" && ! [info exists ::GroupeDeLaSequence($n)]} {lappend r $n}}; set r}]
    set trop [Q {set r {}; set L [lmap n $::LNOrdali {string trim $n}]; foreach n [array names ::GroupeDeLaSequence] {if {$n ni $L} {lappend r $n}}; set r}]
    V "$t : chaque séquence a un groupe" {$sans eq ""} "[llength $sans] sans groupe : [lrange $sans 0 5]"
    V "$t : pas de groupe pour une séquence absente" {$trop eq ""} "[llength $trop] : [lrange $trop 0 5]"
}
proc Lit {t} {
    set r [F "$t : lecture de E9AEW4.feat" [list ReadRawFeatureFile $::Test/E9AEW4.feat] 120000]
    V "$t : sans message" {[Dialogues $r] eq ""} [Dialogues $r]
    V "$t : feature kinetoSpe sur E9AEW4_A" {[Q {info exists ::TabSF(E9AEW4_A,kinetoSpe)}]}
    set g [Q {set ::GroupeDeLaSequence(E9AEW4_A)}]
    set n [Q "llength \[array names ::TabSF *,kinetoSpe\]"]
    V "$t : propagée au groupe $g" {$n == [Q "llength \$::SDG($g)"]} "$n séquences, groupe de [Q "llength \$::SDG($g)"]"
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    Groupes "ouverture (M4)"
    foreach m {{M1 - original alignment} {M3 - reclustering-Secator} {M5 - Kinetoplatids} {M2 - macsims alignment} {M4 - mito-extended}} {
	F "instance $m" [list MiseAJourMac x $m] 120000
	Groupes "[lindex $m 0]"
    }
    set r [F "M4 : ajout de E9AEW4 par access UniProt" {AjouteSequenceOrPDB pdbid; set ::TAddS(StrucIdIn) E9AEW4; .was.fbut.ok invoke} 300000]
    V "M4 : ajout accepté (structure chargée pour M5)" {! [string match "*already loaded*" [Dialogues $r]]} [Dialogues $r]
    V "M4 : E9AEW4_A ajoutée" {"E9AEW4_A" in [Q {lmap n $::LNOrdali {string trim $n}}]}
    V "M4 : E9AEW4_A est une structure" {"E9AEW4_A" in [Q {set ::ListePDB}]}
    Groupes "M4 après l'ajout"
    Lit "M4"
    set r [F "M4 : deuxième ajout refusé" {AjouteSequenceOrPDB pdbid; set ::TAddS(StrucIdIn) E9AEW4; .was.fbut.ok invoke} 300000]
    V "M4 : message « already loaded »" {[string match "*already loaded*" [Dialogues $r]]} [Dialogues $r]
    F "viewer 3D" VisualiseStructure 300000
    V "viewer : E9AEW4 présente" {[Q {winfo exists $::pgl(frObjc).fE9AEW4}]}
    F "fermeture du viewer" QuitteViandox
    Inv "M4"
    F "instance M5" {probe::answer tk_dialog 0; MiseAJourMac x {M5 - Kinetoplatids}} 120000
    Groupes "M5"
    Lit "M5"
    Inv "M5"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
