# Overview faite sur une autre instance que la courante (M2 alors que M4 est affichée) : choisir une
# feature dans sa liste donne un message, la liste revient à la feature affichée, rien n'est dessiné ;
# + et - ne dessinent pas la feature avec les données de l'instance courante ; revenu sur M2, la
# feature est dessinée comme dans une overview neuve de M2 ; les overviews de l'instance courante
# marchent comme avant.
# Usage : tclsh8.6 test/saisies/overview_instance_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Choisit {Id ft} {
    Q "set ::Ovw(O$Id,Feat) [list $ft]"
    W::fire "MetAJourDessinOverview $Id .overview$Id.btn.combo" 120000
}
proc ImagesFX {Id} {Q "lmap i \[.overview$Id.c find withtag ImgFeature\] {.overview$Id.c gettags \$i}"}
# contenu de l'image d'une feature : liste des pixels non vides (x y couleur), échantillonnée
proc Contenu {Id ft} {
    Q [string map [list @I $Id @F $ft] {
	set img [.overview@I.c itemcget $::Ovw(O@I,@F) -image]
	set r {}
	for {set y 0} {$y < [image height $img]} {incr y 2} {
	    for {set x 0} {$x < [image width $img]} {incr x 2} {
		if {! [$img transparency get $x $y]} {lappend r $x $y [$img get $x $y]}
	    }
	}
	set r
    }]
}
set M2 {M2 - macsims alignment}
set M4 {M4 - mito-extended}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    V "instance courante M4" {[Q {MacCourant name}] eq $M4}
    F "instance M2" [list MiseAJourMac x $M2] 120000
    F "overview de M2" AfficheOverview 120000
    set Id [Q {lindex $::Ovw(Liste) end}]
    set f0 [Q "set ::Ovw(O$Id,Feat)"]
    F "retour sur M4" [list MiseAJourMac x $M4] 120000
    # choix dans la liste de l'overview M2
    set r [Choisit $Id Cons-T80]
    V "choix Cons-T80 dans l'overview M2 : sans erreur" {! [Err $r]} [expr {[Err $r] ? [dict get $r errorInfo] : ""}]
    V "choix : message (autre instance)" {[string match "*another instance*" [Dialogues $r]]} [Dialogues $r]
    V "choix : la liste revient à « $f0 »" {[Q "set ::Ovw(O$Id,Feat)"] eq $f0} [Q "set ::Ovw(O$Id,Feat)"]
    V "choix : rien dessiné" {[ImagesFX $Id] eq ""} [ImagesFX $Id]
    # + et - : pas de feature calculée avec les données de M4
    Q "set ::Ovw(O$Id,Feat) Cons-T80"
    F "+ sur l'overview M2" "ChangeEchelleOverview $Id plus" 120000
    F "- sur l'overview M2" "ChangeEchelleOverview $Id moins" 120000
    V "+/- : pas de feature dessinée avec les données de M4" {[ImagesFX $Id] eq ""} [ImagesFX $Id]
    V "+/- : pas de cadre de la vue de M4" {[Q ".overview$Id.c find withtag algtRegion"] eq ""}
    Q "set ::Ovw(O$Id,Feat) $f0"
    # overview de M4 : comme avant
    F "overview de M4" AfficheOverview 120000
    set Id4 [Q {lindex $::Ovw(Liste) end}]
    Choisit $Id4 Cons-T80
    V "overview M4 : Cons-T80 dessinée" {[Q "info exists ::Ovw(O$Id4,Cons-T80)"]}
    F "+ sur l'overview M4" "ChangeEchelleOverview $Id4 plus" 120000
    V "overview M4 : + garde la feature" {[Q "info exists ::Ovw(O$Id4,Cons-T80)"]}
    # retour sur M2 : la feature se dessine, comme dans une overview neuve de M2
    F "instance M2" [list MiseAJourMac x $M2] 120000
    set r [Choisit $Id Cons-T80]
    V "M2 : Cons-T80 dessinée sans message" {! [Err $r] && [Dialogues $r] eq "" && [Q "info exists ::Ovw(O$Id,Cons-T80)"]} [Dialogues $r]
    F "overview neuve de M2" AfficheOverview 120000
    set Idn [Q {lindex $::Ovw(Liste) end}]
    Choisit $Idn Cons-T80
    set a [Contenu $Id Cons-T80]; set b [Contenu $Idn Cons-T80]
    V "M2 : même image que dans une overview neuve de M2 ([expr {[llength $a]/3}] pixels)" {$a eq $b && $a ne ""} "[llength $a] / [llength $b]"
    Inv "après overviews de deux instances"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
