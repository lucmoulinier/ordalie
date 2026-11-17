# Alignment > Barcode : dessin comparé à un calcul indépendant. Une bande par groupe (nom et nombre de
# séquences) ; blocs sombres = colonnes où au moins 10 % des séquences du groupe ont un résidu ; Feature :
# éléments de la feature dans chaque bande ; PDB : structures du groupe ; PFAM ; Groups décoché : une bande
# « all » ; changement d'instance puis Barcode : nouvelle instance ; Close.
# Usage : tclsh8.6 test/saisies/barcode_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# bandes attendues {nom n}
proc Bandes {grp} {
    Q [string map [list @G $grp] {
	set r {}
	if {@G} {
	    foreach g $::LNDG {
		if {$g in {GroupeToutLeMonde bidon grise} || ! [info exists ::SDG($g)] || $::SDG($g) eq ""} continue
		set nom [expr {[info exists ::SDG(Equiv,$g)] && $::SDG(Equiv,$g) ne "" ? $::SDG(Equiv,$g) : $g}]
		lappend r "$nom ([llength $::SDG($g)])"
	    }
	}
	if {$r eq ""} {lappend r "all ([llength [lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : 1}}]])"}
	set r
    }]
}
# blocs sombres attendus : {bande début fin} (colonnes, fin exclue), seuil 10 %
proc Blocs {} {
    Q {
	set r {}
	foreach lane $::DS(Lanes) {
	    lassign $lane n Ls
	    set L [lmap s $Ls {set ::Sequences($s)}]
	    set lg [LongueurDeLAlignement]; set deb -1
	    for {set i 0} {$i <= $lg} {incr i} {
		set ok 0
		if {$i < $lg} {
		    set nr 0
		    foreach s $L {if {[string index $s $i] ni {. " " - ""}} {incr nr}}
		    set ok [expr {$nr > 0 && $nr >= 0.1*[llength $L]}]
		}
		if {$ok && $deb < 0} {set deb $i} elseif {! $ok && $deb >= 0} {lappend r [list $n $deb $i]; set deb -1}
	    }
	}
	set r
    }
}
# blocs dessinés : x des rectangles « ali » ramenés en colonnes
proc Dessin {tag} {
    Q [string map [list @T $tag] {
	set r {}
	foreach i [$::DS(Can) find withtag @T] {
	    lassign [$::DS(Can) coords $i] x1 y1 x2 y2
	    set n ""
	    foreach lane $::DS(Lanes) {lassign $::DS(Y,[lindex $lane 0]) a b; if {$y2 > $a && $y1 < $b} {set n [lindex $lane 0]}}
	    lappend r [list $n [expr {round(($x1-$::DS(X0))*$::DS(AliLg)/double($::DS(LaneW)))}] [expr {round(($x2-$::DS(X0))*$::DS(AliLg)/double($::DS(LaneW)))}]]
	}
	lsort $r
    }]
}
proc Textes {tag} {Q "lmap i \[\$::DS(Can) find withtag $tag\] {\$::DS(Can) itemcget \$i -text}"}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    F "Barcode" BarcodeAlignment 60000
    V "fenêtre" {[Q {winfo exists .barcode}]}
    set lanes [Q {lmap i [$::DS(Can) find withtag lane] {lindex [lsearch -inline -glob [$::DS(Can) gettags $i] R*] 0}}]
    set noms [Q {set r {}; foreach l $::DS(Lanes) {lappend r "[lindex $l 0] ([llength [lindex $l 1]])"}; set r}]
    V "une bande par groupe, avec le nombre de séquences" {$noms eq [Bandes 1]} "$noms / [Bandes 1]"
    V "textes des bandes" {[lsort [lmap t [Q {lmap i [$::DS(Can) find all] {expr {[lsearch -glob [$::DS(Can) gettags $i] T*] >= 0 ? [$::DS(Can) itemcget $i -text] : [continue]}}}] {set t}]] eq [lsort [Bandes 1]]}
    set b [Blocs]; set d [Dessin ali]
    V "blocs sombres : [llength $b] attendus" {[lsort $b] eq $d} "dessinés [llength $d], premier écart [lindex [lmap x [lsort $b] y $d {expr {$x eq $y ? [continue] : "$x <> $y"}}] 0]"
    # feature
    Q {set ::DS(FeatSel) PFAM-A}
    F "Feature PFAM-A" BarcodeView 60000
    set att [Q {set r {}; foreach lane $::DS(Lanes) {lassign $lane n Ls; set L {}; foreach s $Ls {if {[info exists ::TabSF($s,PFAM-A)]} {foreach e $::TabSF($s,PFAM-A) {lappend L [list $n [dict get $e fstart] [expr {[dict get $e fstop]+1}] [dict get $e fcolor]]}}}; lappend r {*}[lsort -unique $L]}; lsort [lmap e $r {lrange $e 0 2}]}]
    V "Feature : éléments PFAM-A de chaque bande ([llength $att])" {[Dessin feat] eq $att && $att ne ""} "[llength [Dessin feat]]"
    # PDB
    Q {set ::DS(AddPDB) 1}
    F "PDB" BarcodeView 60000
    set pdb [Q {set r {}; foreach lane $::DS(Lanes) {set Lp {}; foreach s [lindex $lane 1] {if {$s in $::ListePDB} {lappend Lp [regsub -nocase {^PDB_} $s ""]}}; if {$Lp ne ""} {lappend r [join $Lp " "]}}; set r}]
    V "PDB : structures de chaque groupe" {[lsort [Textes pdb]] eq [lsort $pdb] && $pdb ne ""} "[Textes pdb] / $pdb"
    # PFAM
    Q {set ::DS(Pfam) 1}
    F "PFAM" BarcodeView 60000
    V "PFAM : domaines dessinés" {[llength [Q {$::DS(Can) find all}]] > [llength $d]}
    # Groups décoché
    Q {set ::DS(AddGrps) 0; set ::DS(Pfam) 0; set ::DS(FeatSel) None}
    F "Groups décoché" BarcodeView 60000
    V "une seule bande « all »" {[Q {set r {}; foreach l $::DS(Lanes) {lappend r "[lindex $l 0] ([llength [lindex $l 1]])"}; set r}] eq [Bandes 0]}
    V "blocs de la bande all" {[lsort [Blocs]] eq [Dessin ali]}
    F "Close" BarcodeClose
    V "fermée" {! [Q {winfo exists .barcode}]}
    # autre instance
    F "instance M5" {MiseAJourMac x {M5 - Kinetoplatids}} 120000
    F "Barcode M5" BarcodeAlignment 60000
    V "M5 : bandes de M5" {[Q {set r {}; foreach l $::DS(Lanes) {lappend r "[lindex $l 0] ([llength [lindex $l 1]])"}; set r}] eq [Bandes [Q {set ::DS(AddGrps)}]]}
    V "M5 : blocs" {[lsort [Blocs]] eq [Dessin ali]}
    F "Close" BarcodeClose
    Inv "après Barcode"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
