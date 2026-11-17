# Bouton droit dans le viewer 3D et dans la fenêtre New Object, par de vrais événements :
# - viewer : appui droit puis glisser = translation de la molécule (xTra augmente vers la droite, yTra
#   diminue vers le bas, proportionnellement au déplacement), relâcher ne change rien ;
# - New Object : clic droit sur un résidu = type de représentation suivant (0 à 7 puis 0), le type enregistré
#   est celui dessiné ; l'objet créé suit le type choisi (Ribbon : FlagRib).
# Usage : tclsh8.6 test/saisies/clicdroit_3d_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Sans {tag r} {V "$tag : sans erreur" {! [Err $r]} [expr {[dict exists $r errorInfo] ? [dict get $r errorInfo] : ""}][expr {[dict exists $r bgerrors] ? [dict get $r bgerrors] : ""}]}
proc Type {} {lindex [Q "set ::NwOjR($::chn,$::n)"] 1}
proc Dessin {} {string range [lsearch -inline -regexp [Q "$::cv gettags \[lindex \[$::cv find withtag {NBox && $::nb}\] 0\]"] {^Type}] 4 end}

if {[catch {
    Start $Test/I_maj.xml
    F "viewer 3D" VisualiseStructure 180000
    for {set i 0} {$i < 100 && ! [Q {winfo exists .ordogl}]} {incr i} {after 200}
    set c [Q {set ::pgl(wogl)}]
    lassign [Q {list $::pgl(xTra) $::pgl(yTra) $::Rad $::pgl(width) $::pgl(height)}] x0 y0 Rad W H
    Sans "appui droit" [W::fire "event generate $c <ButtonPress-3> -x 100 -y 100; update" 30000]
    Sans "glisser" [W::fire "event generate $c <B3-Motion> -x 160 -y 130; update" 30000]
    lassign [Q {list $::pgl(xTra) $::pgl(yTra)}] x1 y1
    V "translation : x + 1.5 R dx / largeur" {abs($x1 - ($x0 + 1.5*$Rad*60/$W)) < 1e-6} "$x1 / [expr {$x0 + 1.5*$Rad*60/$W}]"
    V "translation : y - 1.5 R dy / hauteur" {abs($y1 - ($y0 - 1.5*$Rad*30/$H)) < 1e-6} "$y1 / [expr {$y0 - 1.5*$Rad*30/$H}]"
    Sans "relâcher" [W::fire "event generate $c <ButtonRelease-3> -x 160 -y 130; update" 30000]
    V "relâcher : rien de plus" {[Q {list $::pgl(xTra) $::pgl(yTra)}] eq [list $x1 $y1]}

    puts "=== New Object"
    set m [lindex [Q {lsort $::Liste3dMol}] 0]
    F "New Object" "DefineNewObj $m {}" 60000
    set cv [Q {set ::NwOj(Can)}]
    set b [lindex [Q "$cv find withtag BgRes"] 10]
    set nb [lsearch -inline -regexp [Q "$cv gettags $b"] {^Nbr}]
    set n [string range $nb 3 end]; set chn [Q {set ::NwOj(Chain)}]
    lassign [Q "$cv coords $b"] bx1 by1 bx2 by2
    set x [expr {int(($bx1+$bx2)/2)}]; set y [expr {int(($by1+$by2)/2)}]
    set t0 [Type]
    V "résidu $chn $n : type enregistré = type dessiné ($t0)" {$t0 == [Dessin]}
    set ok 1; set vu {}
    for {set k 1} {$k <= 8} {incr k} {
	set r [W::fire "event generate $cv <Motion> -x $x -y $y; event generate $cv <ButtonPress-3> -x $x -y $y; event generate $cv <ButtonRelease-3> -x $x -y $y; update" 30000]
	if {[Err $r]} {set ok 0}
	lappend vu [Type]/[Dessin]
	if {[Type] != ($t0 + $k) % 8 || [Type] != [Dessin]} {set ok 0}
    }
    V "8 clics droits : types successifs, enregistré = dessiné, retour au départ" {$ok && [Type] == $t0} $vu
    # Ribbon (3) sur ce résidu : l'objet a un ruban
    while {[Type] != 3} {W::fire "event generate $cv <Motion> -x $x -y $y; event generate $cv <ButtonPress-3> -x $x -y $y; event generate $cv <ButtonRelease-3> -x $x -y $y; update" 30000}
    Q {set ::NwOj(Obj) clicdroit1}
    F "OK : ruban d'un seul résidu" {FinNewObj ok} 60000
    V "objet créé (un résidu : pas de ruban possible)" {[Q "dict get \[set \[info object namespace ::$m\]::obj_clicdroit1\] FlagRib"] == 1}
    V "pas de transaction laissée ouverte" {! [Q "::P3::TransactionOuverte \[::P3::DbStruct ::$m\]"]}
    # rubans de 4 et 6 résidus consécutifs : sous 5 résidus pas de ruban (lissage d'ordre 5), mais pas
    # d'erreur ; à partir de 5, un ruban
    foreach k {4 6} {
	F "New Object ($k résidus)" "DefineNewObj $m {}" 60000
	set Lb [lrange [Q "$cv find withtag BgRes"] 10 [expr {9+$k}]]
	foreach b $Lb {
	    lassign [Q "$cv coords $b"] bx1 by1 bx2 by2
	    set x [expr {int(($bx1+$bx2)/2)}]; set y [expr {int(($by1+$by2)/2)}]
	    set nbk [string range [lsearch -inline -regexp [Q "$cv gettags $b"] {^Nbr}] 3 end]
	    for {set i 0} {$i < 8 && [lindex [Q "set ::NwOjR($chn,$nbk)"] 1] != 3} {incr i} {W::fire "event generate $cv <Motion> -x $x -y $y; event generate $cv <ButtonPress-3> -x $x -y $y; event generate $cv <ButtonRelease-3> -x $x -y $y; update" 30000}
	}
	Q "set ::NwOj(Obj) clicdroit$k"
	F "OK : ruban de $k résidus" {FinNewObj ok} 60000
	set nrib [llength [lsearch -all -not -exact [Q "dict get \[set \[info object namespace ::$m\]::obj_clicdroit$k\] ribvec"] {}]]
	if {$k < 5} {
	    V "$k résidus : pas de ruban" {$nrib == 0} $nrib
	} else {
	    V "$k résidus : ruban tracé" {$nrib >= 1} $nrib
	}
	V "$k résidus : pas de transaction laissée ouverte" {! [Q "::P3::TransactionOuverte \[::P3::DbStruct ::$m\]"]}
    }
    Inv "après les clics droits 3D"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
