# Structures > Color Sec. Str by identity : fenêtre « Select parameters » (moyenne des structures ou une
# structure de référence, gamme couleur ou gris, étendue min-max ou 0-100). Feature SS-Cons : une zone par
# élément de structure secondaire, en colonnes de l'alignement (référence : bornes = résidus de l'élément) ;
# identité moyenne de la zone recalculée indépendamment ; couleur de la gamme ; feature affichable.
# Usage : tclsh8.6 test/saisies/colorie_ss_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Lance {champs} {
    set id [Q [list probe::fire ColorieSSSelonConservation]]
    set t0 [clock milliseconds]
    while {! [Q {winfo exists .pss}] && [clock milliseconds] - $t0 < 20000} {after 200}
    after 300
    foreach {k v} $champs {Q [list set ::PSS($k) $v]}
    Q {FinColorieSSParams ok}
    set r [W::waitfor $id 600000]
    V "calcul sans erreur" {! [Err $r]} [expr {[Err $r] ? [string range [dict get $r errorInfo] 0 300] : ""}]
}
# identité moyenne (en %) des paires de séquences sur les colonnes d..f
proc Moyenne {d f} {
    Q [string map [list @d $d @f $f] {
	set L {}
	foreach n $::LNOrdali s $::LSOrdali {
	    if {[string trim $n] eq ""} continue
	    set x [string range $s @d @f]
	    set l [string length [string map {. "" " " "" Z ""} $x]]
	    if {$l} {lappend L [list [split $x ""] $l]}
	}
	set m 0.0; set k 0
	for {set i 0} {$i < [llength $L]} {incr i} {
	    for {set j [expr {$i+1}]} {$j < [llength $L]} {incr j} {
		lassign [lindex $L $i] a la; lassign [lindex $L $j] b lb
		set p 0; foreach x $a y $b {if {$x ne "." && $x eq $y} {incr p}}
		set m [expr {$m + double($p)/min($la,$lb)}]; incr k
	    }
	}
	expr {$k ? 100.*$m/$k : -1}
    }]
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set p [lindex [Q {set ::ListePDB}] 0]
    set mol [Q "DonneIdDeAccessPDB $p"]; set chn [Q "DonneChainDeAccessPDB $p"]
    set ba [Q "BonAccess $p"]
    foreach {mode ramp ext} {ref color minmax mean grey zerocent} {
	puts "=== $mode $ramp $ext"
	Lance [list MeanRef $mode PDBRef $p Ramp $ramp RExtend $ext BFactor 0]
	set F [Q "set ::TabSF($ba,SS-Cons)"]
	V "$mode : zones ([llength $F])" {[llength $F] > 3}
	if {$mode eq "ref"} {
	    # bornes : résidus d'un élément de structure secondaire de la référence
	    set El [lmap e [Q "$mol SecStr -chain $chn"] {list [lindex $e 4] [lindex $e 6]}]
	    set faux {}
	    foreach e $F {
		set r [list [Q "DonnePosGS $p [dict get $e fstart]"] [Q "DonnePosGS $p [dict get $e fstop]"]]
		if {$r ni $El} {lappend faux "[dict get $e fstart]-[dict get $e fstop] -> $r"}
	    }
	    V "ref : bornes = résidus des éléments de $p" {$faux eq ""} [lrange $faux 0 3]
	}
	# identité moyenne et couleur
	set Ls [lmap e $F {dict get $e fscore}]
	if {$ext eq "minmax"} {set mn [::tcl::mathfunc::min {*}$Ls]; set mx [::tcl::mathfunc::max {*}$Ls]} else {set mn 0.; set mx 100.}
	set step [expr {($mx-$mn)/10.}]
	set fauxm {}; set fauxc {}
	foreach e $F {
	    set att [Moyenne [dict get $e fstart] [dict get $e fstop]]
	    if {abs($att - [dict get $e fscore]) > 0.01} {lappend fauxm "[dict get $e fstart]-[dict get $e fstop] [dict get $e fscore] / $att"}
	    set ic [expr {$step > 0 ? min(9, int(([dict get $e fscore]-$mn)/$step)) : 0}]
	    set g [expr {$ramp eq "color" ? "GammeCoul" : "GammeGris"}]
	    set ok [expr {[dict get $e fcolor] eq [Q "set ::Defauts($g$ic)"] || ($ic > 0 && [dict get $e fcolor] eq [Q "set ::Defauts($g[expr {$ic-1}])"])}]
	    if {! $ok} {lappend fauxc "[dict get $e fscore] : [dict get $e fcolor]"}
	}
	V "$mode : identité moyenne de chaque zone" {$fauxm eq ""} [lrange $fauxm 0 2]
	V "$mode : couleur de la gamme $ramp" {$fauxc eq ""} [lrange $fauxc 0 2]
	set r [F "$mode : affichage de SS-Cons" {AppliqueFeature Clear; AppliqueFeature SS-Cons}]
	V "$mode : zones affichées" {[Q {lsearch -all -inline -glob [$::NomTextSeq tag names] FX_SS-Cons_*}] ne ""}
    }
    # zone sans aucune séquence : pas d'erreur
    F "identités sur une zone vide" {CalculeLesPCI 0 0 "" "" 1}
    Inv "après Color Sec. Str"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
