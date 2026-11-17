# Menu contextuel des fenêtres d'arbre (clic droit sur le dessin), entrées choisies comme à la souris
# (tk::MenuInvoke), puis clic gauche sur le dessin quand l'entrée attend un clic :
# - radial : Zoom + (échelle + pas), Zoom - (échelle - pas, pas en dessous du pas), Rotate + / - (angle des
#   feuilles - / + pi/8, et retour), Pointer (un clic ne change plus rien) ;
# - dendrogramme : Width + / - (pas des branches ± 20, pas en dessous de 5), Height + / - (espacement ± 5,
#   jamais en dessous de 5 : l'arbre ne se retourne pas), Pointer ;
# - aucune erreur ; le menu proposé suit la représentation.
# Usage : tclsh8.6 test/saisies/clicdroit_arbre_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Sans {tag r} {V "$tag : sans erreur" {! [Err $r]} [expr {[dict exists $r errorInfo] ? [dict get $r errorInfo] : ""}][expr {[dict exists $r bgerrors] ? [dict get $r bgerrors] : ""}]}
proc EvC {ev {x 200} {y 150}} {W::fire "set c \$::Abr($::A,PAD); event generate \$c <$ev> -x $x -y $y -rootx \[expr {\[winfo rootx \$c\]+$x}\] -rooty \[expr {\[winfo rooty \$c\]+$y}\]; update" 60000}
proc ClicG {tag} {Sans "$tag : clic gauche" [EvC ButtonPress-1]; EvC ButtonRelease-1}
proc LeMenu {} {Q "expr {\$::Abr($::A,TypeTree) eq {dendrogram} ? \"\$::Abr($::A,ContextMenu)Den\" : \"\$::Abr($::A,ContextMenu)Rad\"}"}
proc Entrees {m} {Q "set r {}; for {set i 0} {\$i <= \[$m index end\]} {incr i} {lappend r \[$m entrycget \$i -label\]}; set r"}
proc Choisit {lab} {
    Sans "clic droit ($lab)" [EvC ButtonPress-3]
    EvC ButtonRelease-3
    set m [LeMenu]
    set i [lsearch [Entrees $m] $lab]
    if {! [V "menu posté, entrée « $lab »" {[Q "winfo ismapped $m"] && $i >= 0} [Entrees $m]]} {Q "catch {tk::MenuUnpost $m}"; return}
    Sans "« $lab »" [W::fire "$m activate $i; tk::MenuInvoke $m 1; update" 60000]
}
proc G {k} {Q "set ::Abr($::A,$k)"}
proc Theta {} {Q "\$::Abr(Arbre,$::A) get \[lindex \[\$::Abr(Arbre,$::A) leaves\] 0\] theta"}
proc Proche {a b} {expr {abs($a-$b) < 1e-6}}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set A [Q {foreach a $::Abr(Liste) {if {$::Abr($a,Mac) == [MacCourant]} {set r $a}}; set r}]
    V "arbre de l'instance courante" {$A ne ""}
    set pi8 [Q PiS8]

    puts "=== radial"
    Q "set ::Abr($A,TypeTree) radial"; F "radial" "OnReDessineArbre $A" 60000
    V "menu radial" {[Entrees [LeMenu]] eq {Pointer {Zoom +} {Zoom -} {Rotate +} {Rotate -}}} [Entrees [LeMenu]]
    Q "catch {tk::MenuUnpost [LeMenu]}"
    set s0 [G ScaleR]; set p [G incrScaleR]
    Choisit "Zoom +"
    V "Zoom + : rien avant le clic" {[Proche [G ScaleR] $s0]}
    ClicG "Zoom +"
    V "Zoom + : échelle + pas" {[Proche [G ScaleR] [expr {$s0+$p}]]} "[G ScaleR] / [expr {$s0+$p}]"
    ClicG "Zoom + (2)"
    Choisit "Zoom -"
    ClicG "Zoom -"
    V "Zoom - : échelle - pas" {[Proche [G ScaleR] [expr {$s0+$p}]]} "[G ScaleR] / [expr {$s0+$p}]"
    ClicG "Zoom - (2)"
    V "Zoom - : échelle de départ" {[Proche [G ScaleR] $s0]} "[G ScaleR] / $s0"
    for {set i 0} {$i < 8} {incr i} {EvC ButtonPress-1; EvC ButtonRelease-1}
    V "Zoom - : jamais en dessous du pas" {[Proche [G ScaleR] $p]} "[G ScaleR] / $p"
    set t0 [Theta]
    Choisit "Rotate +"
    V "Rotate + : angle - pi/8" {[Proche [Theta] [expr {$t0-$pi8}]]} "[Theta] / [expr {$t0-$pi8}]"
    ClicG "Rotate +"
    V "Rotate + : clic, encore - pi/8" {[Proche [Theta] [expr {$t0-2*$pi8}]]} [Theta]
    Choisit "Rotate -"
    ClicG "Rotate -"
    V "Rotate - : angle de départ" {[Proche [Theta] $t0]} "[Theta] / $t0"
    Choisit "Pointer"
    set s1 [G ScaleR]; set t1 [Theta]
    ClicG "Pointer"
    V "Pointer : un clic ne change rien" {[Proche [G ScaleR] $s1] && [Proche [Theta] $t1]}

    puts "=== dendrogramme"
    Q "set ::Abr($A,TypeTree) dendrogram"; F "dendrogramme" "OnReDessineArbre $A" 60000
    V "menu dendrogramme" {[Entrees [LeMenu]] eq {Pointer {Width +} {Width -} {Height +} {Height -}}} [Entrees [LeMenu]]
    set w0 [G Increment]
    Choisit "Width +"
    ClicG "Width +"
    V "Width + : pas + 20" {[Proche [G Increment] [expr {$w0+20}]]} [G Increment]
    Choisit "Width -"
    ClicG "Width -"
    V "Width - : pas de départ" {[Proche [G Increment] $w0]} [G Increment]
    for {set i 0} {$i < 8} {incr i} {EvC ButtonPress-1; EvC ButtonRelease-1}
    V "Width - : jamais en dessous de 5" {[G Increment] >= 5} [G Increment]
    set h0 [G OffsetY]
    set H0 [lindex [Q "\$::Abr($A,PAD) bbox all"] 3]
    Choisit "Height +"
    V "Height + : espacement + 5" {[G OffsetY] == $h0 + 5} [G OffsetY]
    ClicG "Height +"
    V "Height + : clic, encore + 5" {[G OffsetY] == $h0 + 10} [G OffsetY]
    V "Height + : arbre plus haut" {[lindex [Q "\$::Abr($A,PAD) bbox all"] 3] > $H0}
    Choisit "Height -"
    ClicG "Height -"
    V "Height - : espacement de départ" {[G OffsetY] == $h0} [G OffsetY]
    for {set i 0} {$i < 12} {incr i} {EvC ButtonPress-1; EvC ButtonRelease-1}
    V "Height - : jamais en dessous de 5" {[G OffsetY] >= 5} [G OffsetY]
    # les feuilles restent dans l'ordre, de haut en bas
    set Ly [Q "lmap n \[\$::Abr(Arbre,$A) leaves\] {lindex \[\$::Abr($A,PAD) coords \[lindex \[\$::Abr($A,PAD) find withtag feuille-\[\$::Abr(Arbre,$A) get \$n name\]\] 0\]\] 1}"]
    V "Height - : feuilles pas retournées ni superposées" {[llength [lsort -unique -real $Ly]] == [llength $Ly]} "[llength [lsort -unique -real $Ly]] / [llength $Ly]"
    Choisit "Pointer"
    set o [G OffsetY]; set w [G Increment]
    ClicG "Pointer"
    V "Pointer : un clic ne change rien" {[G OffsetY] == $o && [Proche [G Increment] $w]}
    Inv "après les menus des arbres"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
