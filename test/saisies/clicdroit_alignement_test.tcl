# Clics droits dans la fenêtre de l'alignement, par de vrais événements (event generate) :
# - noms : bouton droit appuyé = informations longues de la séquence (texte de LongInfoSeq), relâché = cachées ;
# - modes Identity, Tree, Clustering, Superposition : clic gauche puis clic droit = plage de colonnes ajoutée
#   une seule fois (même après plusieurs passages dans les modes) ; Ctrl + clic droit dans la plage = retirée ;
# - Features Editor : menu contextuel, chaque entrée choisie comme à la souris (tk::MenuInvoke) : Select Item,
#   Select All Items, Select region (puis Define New proposé), Clear selection, Edit Item, Define New,
#   Propagate to group / to all, Delete selected ;
# - hors Features Editor (avant et après) : le clic droit n'ouvre pas son menu et ne fait pas d'erreur.
# Usage : tclsh8.6 test/saisies/clicdroit_alignement_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# événement souris sur la case ligne.colonne du widget Biotext w
proc Ev {w y x ev} {
    lassign [Q "::Champs::Pixel $w $y $x"] px py
    W::fire "event generate $w <$ev> -x $px -y $py -rootx \[expr {\[winfo rootx $w\]+$px}\] -rooty \[expr {\[winfo rooty $w\]+$py}\]; update" 60000
}
# clic complet ; renvoie le résultat de l'appui (erreurs, messages)
proc Clic {w y x b {mod ""}} {
    set e [expr {$mod eq "" ? "" : "$mod-"}]
    set r [Ev $w $y $x "${e}ButtonPress-$b"]
    Ev $w $y $x "${e}ButtonRelease-$b"
    return $r
}
proc Sans {tag r} {V "$tag : sans erreur" {! [Err $r]} [expr {[dict exists $r errorInfo] ? [dict get $r errorInfo] : ""}][expr {[dict exists $r bgerrors] ? [dict get $r bgerrors] : ""}]}
# menu du Features Editor : posté ? entrées
proc MenuFeat {} {Q {set m $::NomTextSeq.ctxm; expr {[winfo exists $m] && [winfo ismapped $m]}}}
proc Entrees {} {Q {set m $::NomTextSeq.ctxm; set r {}; for {set i 0} {$i <= [$m index end]} {incr i} {if {[$m type $i] eq "command"} {lappend r [$m entrycget $i -label]}}; set r}}
proc Ferme {} {Q {catch {tk::MenuUnpost $::NomTextSeq.ctxm}}}
# clic droit en y.x puis choix de l'entrée lab comme à la souris
proc Choisit {y x lab} {
    Sans "clic droit ($lab)" [Clic $::Seq $y $x 3]
    set L [Entrees]
    set i [lsearch $L $lab]
    if {! [V "menu : entrée « $lab »" {[MenuFeat] && $i >= 0} $L]} {Ferme; return}
    set i [Q "set m \$::NomTextSeq.ctxm; for {set i 0} {\$i <= \[\$m index end\]} {incr i} {if {\[\$m type \$i\] eq {command} && \[\$m entrycget \$i -label\] eq [list $lab]} break}; set i"]
    return [W::fire "\$::NomTextSeq.ctxm activate $i; tk::MenuInvoke \$::NomTextSeq.ctxm 1; update" 60000]
}
# fenêtre ouverte par une entrée (Edit Item, Define New) : fermée par Dismiss
proc AvecFenetre {y x lab} {
    Sans "clic droit ($lab)" [Clic $::Seq $y $x 3]
    set i [lsearch [Entrees] $lab]
    V "menu : entrée « $lab »" {$i >= 0} [Entrees]
    set i [Q "set m \$::NomTextSeq.ctxm; for {set i 0} {\$i <= \[\$m index end\]} {incr i} {if {\[\$m type \$i\] eq {command} && \[\$m entrycget \$i -label\] eq [list $lab]} break}; set i"]
    set id [Q [list probe::fire "\$::NomTextSeq.ctxm activate $i; tk::MenuInvoke \$::NomTextSeq.ctxm 1"]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .wedtf}] && [clock milliseconds] - $t0 < 20000} {after 200}
    V "« $lab » : fenêtre ouverte" {[Q {winfo exists .wedtf}]}
    if {[Q {winfo exists .wedtf}]} {Q {.wedtf.fb.dis invoke}}
    W::waitfor $id 20000
}
proc Selection {} {Q {expr {[info exists ::EFeat(LItemSel)] ? $::EFeat(LItemSel) : "?"}}}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    Q "source [list $Ici/champs.tcl]"
    set Seq [Q {set ::NomTextSeq}]; set Nom [Q {set ::NomNomSeq}]
    set Ln [Q {lmap n $::LNOrdali {string trim $n}}]

    puts "=== noms : informations longues"
    set y [expr {[lsearch -not -exact $Ln ""] + 4}]
    set n [lindex $Ln $y-1]
    lassign [Q "::Champs::Pixel $Nom $y 1"] px py
    Sans "bouton droit sur $n" [W::fire "event generate $Nom <ButtonPress-3> -x $px -y $py; update" 30000]
    V "informations de $n affichées" {[Q {winfo exists .ordali.longinfo}] && [Q {.ordali.longinfo cget -text}] eq [Q [list LongInfoSeq $n]]} [Q {expr {[winfo exists .ordali.longinfo] ? [.ordali.longinfo cget -text] : "absent"}}]
    Sans "bouton droit relâché" [W::fire "event generate $Nom <ButtonRelease-3> -x $px -y $py; update" 30000]
    V "informations cachées" {! [Q {winfo exists .ordali.longinfo}]}

    puts "=== mode Feature : pas de menu"
    set r [Clic $Seq 4 60 3]
    Sans "clic droit en mode Feature" $r
    V "pas de menu du Features Editor" {! [MenuFeat]}; Ferme

    puts "=== sélection de colonnes"
    # deux tours : le second vérifie qu'un passage dans les modes ne double pas la sélection
    foreach tour {1 2} {
	foreach {mode retour} {donnepci RetourModePCI arbres RetourDesArbres cluster {QuitteModeClusters $::FrmBouton.clusel} superpose RetourModeSuperposition} {
	    F "tour $tour : mode $mode" "ChangeMode $mode" 120000
	    Q {set ::ZoneSelect {}}
	    Sans "$mode : clic gauche 3.100" [Clic $Seq 3 100 1]
	    Sans "$mode : clic droit 8.120" [Clic $Seq 8 120 3]
	    V "$mode : plage 100-120 ajoutée une fois" {[Q {set ::ZoneSelect}] eq {{100 120}}} [Q {set ::ZoneSelect}]
	    V "$mode : pas de menu du Features Editor" {! [MenuFeat]}; Ferme
	    Sans "$mode : clic gauche 3.200" [Clic $Seq 3 200 1]
	    Sans "$mode : clic droit 6.210" [Clic $Seq 6 210 3]
	    V "$mode : deuxième plage" {[Q {set ::ZoneSelect}] eq {{100 120} {200 210}}} [Q {set ::ZoneSelect}]
	    Sans "$mode : Ctrl + clic droit 5.110" [Clic $Seq 5 110 3 Control]
	    V "$mode : plage 100-120 retirée" {[Q {set ::ZoneSelect}] eq {{200 210}}} [Q {set ::ZoneSelect}]
	    F "$mode : Return" $retour 120000
	}
    }

    puts "=== Features Editor : menu contextuel"
    F "mode Features Editor" {ChangeMode feateditor} 60000
    Q {$::EFeat(FeatCombo) set PFAM-A; ChangeFeatureForEditing}
    # une séquence avec au moins un élément PFAM-A long, dans un groupe d'au moins deux séquences
    foreach nom $Ln {
	if {$nom eq "" || ! [Q "info exists ::TabSF($nom,PFAM-A)"]} continue
	if {[llength [Q "set ::SDG(\$::GroupeDeLaSequence($nom))"]] < 2} continue
	foreach e [Q "set ::TabSF($nom,PFAM-A)"] {if {[dict get $e fstop] - [dict get $e fstart] > 20} break}
	break
    }
    set y [expr {[lsearch -exact $Ln $nom]+1}]; set x [expr {[dict get $e fstart]+5}]
    set note [dict get $e fnote]
    puts "élément $note de $nom (ligne $y), colonnes [dict get $e fstart]-[dict get $e fstop]"
    Sans "menu sans sélection : Clear selection" [Choisit $y $x "Clear selection ..."]
    V "pas de sélection" {[Selection] eq ""} [Selection]
    # Select Item
    Sans "Select Item" [Choisit $y $x "Select Item ..."]
    Sans "clic sur l'élément" [Clic $Seq $y $x 1]
    V "Select Item : l'élément est sélectionné" {[lindex [Selection] 0 1] eq $note && [llength [Selection]] == 1} [Selection]
    Sans "clic droit (sélection)" [Clic $Seq $y $x 3]
    V "menu avec sélection" {[Entrees] eq {{Edit Item ...} {Define New ...} {Delete selected Items ...} {Propagate Item to this group} {Propagate Item to all} {Clear selection ...}}} [Entrees]
    Ferme
    Sans "Clear selection" [Choisit $y $x "Clear selection ..."]
    V "Clear selection : plus de sélection" {[Selection] eq "" && [lindex [Q {bindtags $::NomTextSeq}] end] eq [Q {set ::NomTextSeq}]} "[Selection] / [Q {bindtags $::NomTextSeq}]"
    # Select All Items
    Sans "Select All Items" [Choisit $y $x "Select All Items ..."]
    Sans "clic sur la séquence" [Clic $Seq $y $x 1]
    V "Select All Items : tous les éléments de $nom" {[llength [Selection]] == [llength [Q "set ::TabSF($nom,PFAM-A)"]]} "[llength [Selection]] / [llength [Q "set ::TabSF($nom,PFAM-A)"]]"
    Sans "Clear selection" [Choisit $y $x "Clear selection ..."]
    # Select region, puis Define New proposé
    Sans "Select region" [Choisit $y $x "Select region ..."]
    Sans "appui" [Ev $Seq $y [expr {$x-3}] ButtonPress-1]
    Sans "glisser" [Ev $Seq $y [expr {$x+4}] B1-Motion]
    Sans "relâcher" [Ev $Seq $y [expr {$x+4}] ButtonRelease-1]
    V "Select region : région choisie" {[Q {set ::EFeat(ZonesSel)}] ne ""} [Q {set ::EFeat(ZonesSel)}]
    Sans "clic droit (région)" [Clic $Seq $y $x 3]
    V "région : le menu propose Define New" {"Define New ..." in [Entrees]} [Entrees]
    Ferme
    AvecFenetre $y $x "Define New ..."
    Sans "Clear selection" [Choisit $y $x "Clear selection ..."]
    # Edit Item
    Sans "Select Item" [Choisit $y $x "Select Item ..."]
    Clic $Seq $y $x 1
    AvecFenetre $y $x "Edit Item ..."
    # Propagate to group
    set g [Q "set ::SDG(\$::GroupeDeLaSequence($nom))"]
    Sans "Clear selection" [Choisit $y $x "Clear selection ..."]
    Sans "Select Item" [Choisit $y $x "Select Item ..."]
    Clic $Seq $y $x 1
    Sans "Propagate Item to this group" [Choisit $y $x "Propagate Item to this group"]
    set avec [llength [lmap s $g {expr {[Q "info exists ::TabSF($s,PFAM-A)"] && [lsearch -index 9 [Q "set ::TabSF($s,PFAM-A)"] $note] >= 0 ? 1 : [continue]}}]]
    V "propagé au groupe ([llength $g] séquences)" {$avec == [llength $g]} "$avec / [llength $g]"
    # Propagate to all
    Sans "Select Item" [Choisit $y $x "Select Item ..."]
    Clic $Seq $y $x 1
    Sans "Propagate Item to all" [Choisit $y $x "Propagate Item to all"]
    set Lt [lsearch -all -inline -not -exact $Ln ""]
    set avec [llength [lmap s $Lt {expr {[Q "info exists ::TabSF($s,PFAM-A)"] && [lsearch -index 9 [Q "set ::TabSF($s,PFAM-A)"] $note] >= 0 ? 1 : [continue]}}]]
    V "propagé à toutes les séquences" {$avec == [llength $Lt]} "$avec / [llength $Lt]"
    # Delete selected
    set n0 [llength [Q "set ::TabSF($nom,PFAM-A)"]]
    Sans "Select Item" [Choisit $y $x "Select Item ..."]
    Clic $Seq $y $x 1
    Sans "Delete selected Items" [Choisit $y $x "Delete selected Items ..."]
    V "élément supprimé de $nom" {[llength [Q "expr {\[info exists ::TabSF($nom,PFAM-A)\] ? \$::TabSF($nom,PFAM-A) : {}}"]] == $n0 - 1}
    F "Cancel" {RetourEditFeatures dismiss} 60000

    puts "=== après le Features Editor"
    set r [Clic $Seq 4 60 3]
    Sans "clic droit en mode Feature" $r
    V "pas de menu du Features Editor" {! [MenuFeat]}; Ferme
    F "mode Tree" {ChangeMode arbres} 60000
    Q {set ::ZoneSelect {}}
    Clic $Seq 3 100 1
    Sans "Tree : clic droit" [Clic $Seq 8 120 3]
    V "Tree : sélection de colonnes" {[Q {set ::ZoneSelect}] eq {{100 120}}} [Q {set ::ZoneSelect}]
    V "Tree : pas de menu du Features Editor" {! [MenuFeat]}; Ferme
    F "Return" RetourDesArbres 60000
    Inv "après les clics droits"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
