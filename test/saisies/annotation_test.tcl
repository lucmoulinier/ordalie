# Alignment > Annotate instance : vrais événements souris sur l'alignement (event generate, aux coordonnées
# des cases) : zone tirée sur deux séquences, fenêtre (couleur, texte avec ' { }), OK ; Maj+clic : édition ;
# Ctrl+clic : suppression ; Return (enregistre) ou Cancel ; table annotation de l'instance ; sauvegarde ORD,
# réouverture ; annotations d'une autre instance non mélangées.
# Usage : tclsh8.6 test/saisies/annotation_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Px {y x} {Q "::Champs::Pixel \$::NomTextSeq $y $x"}
proc Clic {y x {etat 0}} {
    lassign [Px $y $x] px py
    W::fire "event generate \$::NomTextSeq <ButtonPress-1> -x $px -y $py -state $etat; event generate \$::NomTextSeq <ButtonRelease-1> -x $px -y $py -state [expr {$etat | 0x100}]" 20000
}
proc Tire {y1 x1 y2 x2} {
    lassign [Px $y1 $x1] a b
    lassign [Px $y2 $x2] c d
    W::fire "event generate \$::NomTextSeq <ButtonPress-1> -x $a -y $b; event generate \$::NomTextSeq <Motion> -x $c -y $d -state 0x100; event generate \$::NomTextSeq <ButtonRelease-1> -x $c -y $d -state 0x100" 20000
}
proc Remplit {texte couleur} {
    Q "set ::Anno(Color) [list $couleur]; \$::Anno(WText) delete 1.0 end; \$::Anno(WText) insert end [list $texte]"
    W::fire {.frAnno.f.fbut.butok invoke} 20000
}
proc Base {} {Q {set p [MacCourant]; $::db eval {select annotation, color, zone from annotation where pk_snap = $p order by pk_annotation}}}
proc Mode {} {
    F "mode Annotation" {ChangeMode annotation} 60000
    Q [list source $::Ici/champs.tcl]
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set B0 [Base]
    Mode
    set LN [Q {set ::LNOrdali}]
    set Li [lsearch -all -not -regexp $LN {^\s*$}]
    set y1 [expr {[lindex $Li 4] + 1}]; set y2 [expr {$y1 + 1}]
    if {[string trim [lindex $LN $y2-1]] eq ""} {incr y2}
    set n1 [string trim [lindex $LN $y1-1]]; set n2 [string trim [lindex $LN $y2-1]]
    Tire $y1 30 $y2 40
    V "zone tirée : fenêtre de l'annotation" {[Q {winfo exists .frAnno}]}
    V "zone : 2 séquences, colonnes 30-40" {[Q {$::NomTextSeq tag ranges selZoneAnno}] eq [list $y1.30 $y1.40 $y2.30 $y2.40]} [Q {$::NomTextSeq tag ranges selZoneAnno}]
    set texte {Mon {annotation} l'été}
    Remplit $texte red
    V "fenêtre fermée" {! [Q {winfo exists .frAnno}]}
    V "annotation enregistrée en mémoire" {[llength [Q {set ::Anno(Lanno)}]] == [llength $B0]/3 + 1}
    V "annotation affichée" {[Q {lsearch -all -inline -glob [$::NomTextSeq tag names] Anno_*}] ne ""}
    # édition : Maj+clic sur la zone
    Clic $y1 35 1
    V "Maj+clic : fenêtre d'édition" {[Q {winfo exists .frAnno}]}
    V "édition : texte relu" {[Q {string trim [$::Anno(WText) get 1.0 end]}] eq $texte} [Q {$::Anno(WText) get 1.0 end}]
    Remplit "texte modifié" blue
    set a [lindex [Q {set ::Anno(Lanno)}] end]
    V "édition : texte et couleur" {[lindex $a 1] eq "texte modifié" && [lindex $a 2] eq "blue"} $a
    # deuxième annotation puis suppression par Ctrl+clic
    Tire $y1 60 $y1 65
    Remplit "à supprimer" green
    Clic $y1 62 4
    V "Ctrl+clic : supprimée" {[lsearch -index 1 [Q {set ::Anno(Lanno)}] "à supprimer"] < 0}
    F "Return (enregistre)" {QuitAnnotation ok} 60000
    set B1 [Base]
    V "base : une annotation de plus" {[llength $B1] == [llength $B0] + 3} "[expr {[llength $B1]/3}] (avant [expr {[llength $B0]/3}])"
    lassign [lrange $B1 end-2 end] t c z
    V "base : texte, couleur" {$t eq "texte modifié" && $c eq "blue"} "$t $c"
    V "base : zone par noms" {$z eq [list [list $n1 30 40] [list $n2 30 40]]} $z
    V "instance modifiée (annotations)" {[Q FichierModifie]}
    # Cancel : rien n'est enregistré
    Mode
    Tire $y1 80 $y1 90
    Remplit "annulée" red
    F "Cancel" {QuitAnnotation dismiss} 60000
    V "Cancel : base inchangée" {[Base] eq $B1}
    # une autre instance : ses annotations seulement
    F "instance M2" {MiseAJourMac x {M2 - macsims alignment}} 120000
    set B2 [Base]
    V "M2 : pas l'annotation de M4" {[lsearch -exact $B2 "texte modifié"] < 0}
    F "instance M4" {MiseAJourMac x {M4 - mito-extended}} 120000
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/a.ord] 120000
    Stop
    Start $Tmp/a.ord
    V "réouverture : annotation gardée" {[lrange [Base] end-2 end] eq [list "texte modifié" blue [list [list $n1 30 40] [list $n2 30 40]]]} [lrange [Base] end-2 end]
    Mode
    V "réouverture : affichée dans le mode" {[lsearch -index 1 [Q {set ::Anno(Lanno)}] "texte modifié"] >= 0}
    F "Return" {QuitAnnotation ok} 60000
    Inv "après Annotation"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
