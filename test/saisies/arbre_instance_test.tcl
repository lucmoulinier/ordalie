# Arbre d'une autre instance que la courante (arbre de M4 manipulé alors que M2 est affichée) : les
# couleurs des clusters restent celles des groupes de M4 quand l'arbre est redessiné (Dendro/Radial,
# zoom, largeur, show clusters) ; la légende prend les groupes de M4 ; changer le label donne un message
# avec le nom des instances et la liste revient au label affiché ; aucune erreur, même pour les feuilles
# absentes de M2 (tag d'une feuille) ; l'arbre de l'instance courante prend ses propres groupes.
# Usage : tclsh8.6 test/saisies/arbre_instance_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# couleur dessinée de chaque feuille {feuille couleur}
proc Couleurs {A} {
    Q "set r {}; foreach n \[\$::Abr(Arbre,$A) leaves\] {set f \[\$::Abr(Arbre,$A) get \$n name\]; lappend r \$f \[\$::Abr($A,PAD) itemcget \[lindex \[\$::Abr($A,PAD) find withtag feuille-\$f\] 0\] -fill\]}; set r"
}
# couleur attendue de chaque feuille d'après les groupes de l'instance affichée (calcul indépendant)
proc Attendues {A} {
    Q "set r {}; foreach n \[\$::Abr(Arbre,$A) leaves\] {set f \[\$::Abr(Arbre,$A) get \$n name\]; set c black; foreach g \$::LNDG {if {\$g ni {GroupeToutLeMonde All all grise bidon} && \[info exists ::SDG(\$g)\] && \$f in \$::SDG(\$g)} {set c \[CouleurO2Ordali \[CouleurDuGroupe \[string range \$g 5 end\]\]\]}}; lappend r \$f \$c}; set r"
}
proc Differences {a b} {
    set n 0
    foreach {f c} $a {if {[dict get $b $f] ne $c} {incr n}}
    return $n
}
proc Fire {tag cmd} {
    set r [W::fire $cmd 120000]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] && [dict exists $r errorInfo] ? [dict get $r errorInfo] : [expr {[Err $r] ? $r : ""}]}]
    return $r
}
set M2 {M2 - macsims alignment}
set M4 {M4 - mito-extended}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set A [Q {foreach a $::Abr(Liste) {if {$::Abr($a,Mac) == 4} {set r $a}}; set r}]
    set A2 [Q {foreach a $::Abr(Liste) {if {$::Abr($a,Mac) == 2} {set r $a}}; set r}]
    V "arbres de M4 ($A) et de M2 ($A2)" {$A ne "" && $A2 ne ""}
    # dans M4 : couleurs des clusters de M4
    Q "set ::Abr($A,ShClusters) 1"
    Fire "M4 : show clusters" "PeintParClusters $A"
    set att4 [Attendues $A]
    set c4 [Couleurs $A]
    V "M4 : couleurs des groupes de M4 ([llength [lsort -unique [dict values $c4]]] couleurs)" {[Differences $c4 $att4] == 0 && [llength [lsort -unique [dict values $c4]]] > 2} "[Differences $c4 $att4] feuilles différentes"
    set g4 [Q {set ::LNDG}]
    # dans M2 : l'arbre de M4 redessiné garde les couleurs de M4
    Fire "instance M2" [list MiseAJourMac x $M2]
    set att2 [Attendues $A]
    V "M2 : groupes différents de ceux de M4 (le test a un sens)" {[Differences $att4 $att2] > 0} "[Differences $att4 $att2]"
    set t0 [Q "set ::Abr($A,TypeTree)"]
    Q "set ::Abr($A,TypeTree) [expr {$t0 eq "dendrogram" ? "radial" : "dendrogram"}]"
    Fire "M2 : Dendro/Radial sur l'arbre de M4" "OnReDessineArbre $A"
    V "M2 : Dendro/Radial, couleurs de M4" {[Differences [Couleurs $A] $c4] == 0} "[Differences [Couleurs $A] $c4] feuilles changées"
    Q "set ::Abr($A,TypeTree) $t0"
    Fire "M2 : retour" "OnReDessineArbre $A"
    V "M2 : redessin, couleurs de M4" {[Differences [Couleurs $A] $c4] == 0} "[Differences [Couleurs $A] $c4] feuilles changées"
    if {$t0 eq "dendrogram"} {
	Fire "M2 : largeur" "WidthMode $A 20; AppliqueWidth $A 20"
    } else {
	Fire "M2 : zoom" "ZoomMode $A zplus; AppliqueZoom $A zplus 100 100"
    }
    V "M2 : zoom/largeur, couleurs de M4" {[Differences [Couleurs $A] $c4] == 0} "[Differences [Couleurs $A] $c4] feuilles changées"
    Q "set ::Abr($A,ShClusters) 0"
    Fire "M2 : show clusters décoché" "PeintParClusters $A"
    Q "set ::Abr($A,ShClusters) 1"
    Fire "M2 : show clusters coché" "PeintParClusters $A"
    V "M2 : show clusters, couleurs de M4" {[Differences [Couleurs $A] $c4] == 0} "[Differences [Couleurs $A] $c4] feuilles changées"
    # légende : groupes de l'arbre
    V "M2 : groupes de la légende = groupes de M4" {[lindex [Q "GroupesDeLArbre $A"] 0] eq $g4} [lindex [Q "GroupesDeLArbre $A"] 0]
    # tag d'une feuille absente de M2
    set absente [Q "set r {}; foreach n \[\$::Abr(Arbre,$A) leaves\] {set f \[\$::Abr(Arbre,$A) get \$n name\]; if {\[lsearch -exact \[lmap x \$::LNOrdali {string trim \$x}\] \$f\] < 0} {set r \$f; break}}; set r"]
    V "feuille de M4 absente de M2 : $absente" {$absente ne ""}
    Q "set ::Abr($A,DoTagLeaf) 1; set ::Abr($A,LeafSel) \[lindex \$::Abr($A,LSeq) \[lsearch \$::Abr($A,LSeqOri) [list $absente]\]\]"
    Fire "M2 : tag de la feuille absente" "ModeTagLeaf $A"
    V "M2 : feuille absente marquée" {[Q "\$::Abr($A,PAD) find withtag Rtagged"] ne ""}
    # label : refusé avec un message clair, la liste revient
    set l0 [Q "set ::Abr($A,TAff)"]
    set autre [lindex [lsearch -all -inline -not -exact [Q {set ::Abr(TypeAff)}] $l0] 0]
    Q "set ::Abr($A,TAff) [list $autre]"
    set r [Fire "M2 : label $autre" "ChangeLabelTree $A"]
    V "M2 : label, message avec les noms des instances" {[string match "*another instance*($M4)*current one (M2*" [Dialogues $r]]} [Dialogues $r]
    V "M2 : label, la liste revient à « $l0 »" {[Q "set ::Abr($A,TAff)"] eq $l0} [Q "set ::Abr($A,TAff)"]
    # arbre de l'instance courante : ses propres groupes
    Q "set ::Abr($A2,ShClusters) 1"
    Fire "M2 : show clusters sur l'arbre de M2" "PeintParClusters $A2"
    V "arbre de M2 : couleurs des groupes de M2" {[Differences [Couleurs $A2] [Attendues $A2]] == 0} "[Differences [Couleurs $A2] [Attendues $A2]] feuilles différentes"
    # retour en M4 : label accepté
    Fire "instance M4" [list MiseAJourMac x $M4]
    Q "set ::Abr($A,TAff) [list $autre]"
    set r [Fire "M4 : label $autre" "ChangeLabelTree $A"]
    V "M4 : label accepté sans message" {[Dialogues $r] eq "" && [Q "set ::Abr($A,TAff)"] eq $autre} "[Dialogues $r] [Q "set ::Abr($A,TAff)"]"
    V "M4 : couleurs de M4" {[Differences [Couleurs $A] [Attendues $A]] == 0} "[Differences [Couleurs $A] [Attendues $A]] feuilles différentes"
    Inv "après arbres de deux instances"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
