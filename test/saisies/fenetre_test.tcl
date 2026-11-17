# File > Save window as (TFA, MSF, ALN) : la partie visible de l'alignement (lignes et colonnes affichées,
# sans les séparateurs) est écrite ; relue par les lecteurs d'Ordalie (DecortiqueUnTFA / ALN / MSF), chaque
# séquence doit être la tranche de colonnes visible de la séquence de l'alignement. Après défilement.
# Usage : tclsh8.6 test/saisies/fenetre_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# partie visible : lignes et colonnes de la première et de la dernière case entièrement affichées
proc Visible {} {
    Q {
	update
	lassign [split [$::NomTextSeq index @0,0] .] y1 x1
	lassign [split [$::NomTextSeq index @[expr {[winfo width $::NomTextSeq]-1}],[expr {[winfo height $::NomTextSeq]-1}]] .] y2 x2
	set r {}
	for {set y $y1} {$y <= $y2} {incr y} {
	    set n [string trim [lindex $::LNOrdali $y-1]]
	    if {$n ne ""} {lappend r $n [string range $::Sequences($n) $x1 $x2]}
	}
	list $y1 $x1 $y2 $x2 $r
    }
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    foreach {defil} {{0 0} {0.4 0.3}} {
	lassign $defil fx fy
	Q "CoupleX moveto $fx; CoupleY moveto $fy; update"
	lassign [Visible] y1 x1 y2 x2 att
	puts "     visible : lignes $y1-$y2, colonnes $x1-$x2"
	V "défilement $defil : une partie seulement" {$x2 - $x1 < [Q LongueurDeLAlignement] - 1 && [llength $att] > 2}
	foreach fmt {tfa msf aln} lecteur {DecortiqueUnTFA DecortiqueUnMSF DecortiqueUnALN} {
	    set f $Tmp/w_[string map {. _} $fx].$fmt
	    F "Save window as $fmt" [list CreeLAlignementDeLaFenetre $fmt $f] 30000
	    V "$fmt : fichier écrit" {[file exists $f]}
	    if {! [file exists $f]} continue
	    set lu [Q "set L {}; catch {unset ::T_}; $lecteur [list $f] L ::T_; set r {}; foreach n \$L {lappend r \$n \[string map {- . ~ . { } .} \$::T_(\$n)\]}; set r"]
	    set a [lmap {n s} $att {list $n [string map {- . ~ . " " .} $s]}]
	    set b [lmap {n s} $lu {list $n $s}]
	    V "$fmt : [expr {[llength $att]/2}] séquences, tranche visible" {$a eq $b} "[llength $b] relues ; premier écart [lindex [lmap x $a y $b {expr {$x eq $y ? [continue] : "$x <> $y"}}] 0]"
	}
    }
    Inv "après Save window as"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
