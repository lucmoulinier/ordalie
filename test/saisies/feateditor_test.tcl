# Alignment/Sequences > Features Editor : les actions du menu contextuel, appelées avec des positions
# « ligne.colonne » à la place des clics. Define New (séquence, groupe), Edit Item (plage en colonnes de la
# règle, couleur, score, note), valeurs refusées, Propagate to group, Delete selected, Delete Feature,
# Save puis sauvegarde ORD et réouverture ; Cancel remet les features.
# Usage : tclsh8.6 test/saisies/feateditor_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Feat {f} {Q "\$::EFeat(FeatCombo) set [list $f]; ChangeFeatureForEditing"}
# lance une action qui ouvre la fenêtre .wedtf, remplit les champs, valide ; renvoie les messages
proc Fenetre {action champs {bouton ok}} {
    set id [Q [list probe::fire $action]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .wedtf}]} {
	if {[clock milliseconds] - $t0 > 20000} {return "pas de fenêtre"}
	after 200
    }
    set lu [Q {list $::EFeat(ZoneX1) $::EFeat(ZoneX2)}]
    foreach {k v} $champs {Q [list set ::EFeat($k) $v]}
    set r [W::fire ".wedtf.fb.$bouton invoke" 20000]
    set msg [Dialogues $r]
    if {[Q {winfo exists .wedtf}]} {Q {.wedtf.fb.dis invoke}}
    W::waitfor $id 20000
    return [list $lu $msg]
}
proc Items {n f} {Q "expr {\[info exists ::TabSF($n,$f)\] ? \$::TabSF($n,$f) : {}}"}
proc Ligne {n} {expr {[lsearch [Q {lmap n $::LNOrdali {string trim $n}}] $n] + 1}}
proc Region {y x1 x2 {portee seq}} {
    F "sélection de région $y.$x1-$x2 ($portee)" "CmdsMenuFeatures selreg; SelectSeqRegion $y.$x1 stock [expr {$portee eq "seq" ? "" : $portee}]; SelectSeqRegion $y.$x2 motion $portee; SelectSeqRegion $y.$x2 $portee"
}
proc Item {y x {portee seq}} {F "sélection de l'élément $y.$x" "CmdsMenuFeatures selitem; SelectItemFeatureForEditing $portee $y.$x"}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set Ln [Q {lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : [string trim $n]}}}]
    set a [lindex $Ln 3]; set ya [Ligne $a]
    set g [Q "set ::GroupeDeLaSequence($a)"]
    set Lg [Q "set ::SDG($g)"]
    F "mode Features Editor" {ChangeMode feateditor} 60000
    Feat PFAM-A

    puts "=== Define New"
    Region $ya 100 120
    lassign [Fenetre {CmdsMenuFeatures define} {Name "Ma feature" Color red Score 2.5 Note n1}] lu msg
    V "Define New : sans message" {$msg eq ""} $msg
    V "Define New : feature créée (espaces en _)" {"Ma_feature" in [Q {set ::ListeTypesDeFeatures}]}
    set e [lindex [Items $a Ma_feature] 0]
    V "$a : élément 100-120 red 2.5 n1" {[dict get $e fstart] == 100 && [dict get $e fstop] == 120 && [dict get $e fcolor] eq "red" && [dict get $e fscore] == 2.5 && [dict get $e fnote] eq "n1"} $e
    # sur le groupe
    Region $ya 200 210 group
    lassign [Fenetre {CmdsMenuFeatures define} {Name Ma_feature Color blue Score "" Note grp}] lu msg
    set n [llength [lmap s $Lg {expr {[lsearch -index 9 [Items $s Ma_feature] grp] >= 0 ? 1 : [continue]}}]]
    V "Define New sur le groupe $g : [llength $Lg] séquences" {$n == [llength $Lg]} $n
    V "score par défaut 0.0" {[dict get [lindex [Items $a Ma_feature] end] fscore] == 0.0}
    # valeurs refusées
    Region $ya 300 310
    lassign [Fenetre {CmdsMenuFeatures define} {Name "" Color red}] lu msg
    V "sans nom : message" {[string match "*name*" $msg]} $msg
    Region $ya 300 310
    lassign [Fenetre {CmdsMenuFeatures define} {Name X Color pasunecouleur}] lu msg
    V "couleur inconnue : message" {[string match "*color*" $msg]} $msg
    Region $ya 300 310
    lassign [Fenetre {CmdsMenuFeatures define} {Name X Color red Score abc}] lu msg
    V "score non numérique : message" {[string match "*real number*" $msg]} $msg
    V "rien créé par les refus" {"X" ni [Q {set ::ListeTypesDeFeatures}]}

    puts "=== Edit Item"
    Feat Ma_feature
    Item $ya 110
    lassign [Fenetre {CmdsMenuFeatures edit} {ZoneX1 51 ZoneX2 60 Color blue Score 3 Note n2}] lu msg
    V "Edit : plage affichée en colonnes de la règle (101-121)" {$lu eq {101 121}} $lu
    V "Edit : sans message" {$msg eq ""} $msg
    set e [lsearch -inline -index 9 [Items $a Ma_feature] n2]
    V "Edit : 51-60 sur la règle = colonnes 50-59, blue, 3, n2" {$e ne "" && [dict get $e fstart] == 50 && [dict get $e fstop] == 59 && [dict get $e fcolor] eq "blue" && [dict get $e fscore] == 3} $e
    V "Edit : ancien élément remplacé" {[lsearch -index 9 [Items $a Ma_feature] n1] < 0}
    Item $ya 55
    lassign [Fenetre {CmdsMenuFeatures edit} {ZoneX1 0 ZoneX2 10}] lu msg
    V "Edit : plage hors alignement : message" {[string match "*Range*" $msg]} $msg
    Item $ya 55
    lassign [Fenetre {CmdsMenuFeatures edit} {ZoneX1 1x ZoneX2 10}] lu msg
    V "Edit : plage non entière : message" {[string match "*integer*" $msg]} $msg
    V "Edit : élément intact après les refus" {[lsearch -inline -index 9 [Items $a Ma_feature] n2] eq $e}

    puts "=== Propagate, Delete"
    Item $ya 55
    F "Propagate to this group" {CmdsMenuFeatures propagitem}
    set n [llength [lmap s $Lg {expr {[lsearch -index 9 [Items $s Ma_feature] n2] >= 0 ? 1 : [continue]}}]]
    V "propagé au groupe" {$n == [llength $Lg]} "$n / [llength $Lg]"
    Item $ya 55
    F "Delete selected" {CmdsMenuFeatures delete}
    V "élément supprimé de $a" {[lsearch -index 9 [Items $a Ma_feature] n2] < 0}
    V "les autres séquences le gardent" {[lsearch -index 9 [Items [lindex [lsearch -all -inline -not -exact $Lg $a] 0] Ma_feature] n2] >= 0}
    Feat Cons-T80
    F "Delete Feature (Cons-T80, toutes les séquences)" {DeleteFeature all ""}
    V "Cons-T80 retirée" {"Cons-T80" ni [Q {set ::ListeTypesDeFeatures}]}
    set Avant [Q {lsort [lmap k [array names ::TabSF *,Ma_feature] {list $k $::TabSF($k)}]}]
    F "Save" {RetourEditFeatures save} 60000
    V "instance marquée modifiée" {[Q VueEditee]}
    V "scores de Cons-T80 retirés" {[Q {array names ::ScoreMeth Cons-T80,*}] eq ""}
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/f.ord] 120000
    Stop
    Start $Tmp/f.ord
    set Apres [Q {lsort [lmap k [array names ::TabSF *,Ma_feature] {list $k $::TabSF($k)}]}]
    V "réouverture : Ma_feature identique" {$Apres eq $Avant} "[llength $Avant] / [llength $Apres] ; [lindex [lmap x $Avant y $Apres {expr {$x eq $y ? [continue] : "$x <> $y"}}] 0]"
    V "réouverture : pas de Cons-T80" {"Cons-T80" ni [Q {set ::ListeTypesDeFeatures}]} [Q {set ::ListeTypesDeFeatures}]
    Inv "réouverture"

    puts "=== Cancel"
    set P0 [Q {lsort [lmap k [array names ::TabSF *,PFAM-A] {list $k $::TabSF($k)}]}]
    F "mode Features Editor" {ChangeMode feateditor} 60000
    Feat PFAM-A
    F "Delete Feature (PFAM-A)" {DeleteFeature all ""}
    F "Cancel" {RetourEditFeatures dismiss} 60000
    V "Cancel : PFAM-A remise" {"PFAM-A" in [Q {set ::ListeTypesDeFeatures}] && [Q {lsort [lmap k [array names ::TabSF *,PFAM-A] {list $k $::TabSF($k)}]}] eq $P0}
    V "Cancel : instance non modifiée" {! [Q VueEditee]}
    Inv "après Cancel"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
