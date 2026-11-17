# Couverture des procédures : tclsh couverture.tcl REP SORTIE.md ODIR
# REP contient <tag>.cov et <tag>.cov.inv (voir GUI_PROBE_COV dans probe.tcl) ; les tags T_* sont les tests ciblés.
lassign $argv rep out odir
set Inv [dict create]
foreach f [glob -nocomplain $rep/*.cov.inv] {
    set fh [open $f]; while {[gets $fh l] >= 0} {dict set Inv [lindex $l 0] [lindex $l 1]}; close $fh
}
set Audit [dict create]; set Tests [dict create]; set Demarrage [dict create]; set ParTag [dict create]
foreach f [glob -nocomplain $rep/*.cov] {
    set tag [file rootname [file tail $f]]
    set fh [open $f]
    while {[gets $fh l] >= 0} {
	lassign $l n act
	dict set ParTag $tag $n 1
	if {[string match T_* $tag]} {dict set Tests $n 1} else {dict set Audit $n 1}
	if {$act eq ""} {dict set Demarrage $n 1}
    }
    close $fh
}
# références dans le code : un nom vu seulement à sa définition n'a pas d'appelant connu
set Ref [dict create]
foreach f [lsort -unique [dict values $Inv]] {
    set fh [open $odir/src/$f]; fconfigure $fh -encoding binary; set txt [read $fh]; close $fh
    foreach w [regexp -all -inline {[A-Za-z_][\w:]*} $txt] {dict incr Ref $w}
}
proc sansappel {n} {
    set c [namespace tail [string map {Structure:: ""} $n]]
    expr {! [dict exists $::Ref $c] || [dict get $::Ref $c] <= 1}
}
proc pct {a b} {expr {$b ? round(100.0*$a/$b) : 0}}
foreach {n t} $Inv {
    dict lappend ParF $t $n
}
set fo [open $out w]
set N [dict size $Inv]
set nA 0; set nT 0; set nU 0; set nM 0
dict for {n t} $Inv {
    set a [dict exists $Audit $n]; set b [dict exists $Tests $n]
    incr nA $a; incr nT $b
    if {$a || $b} {incr nU} elseif {[sansappel $n]} {incr nM}
}
puts $fo "# Couverture des procédures d'Ordalie\n\nGénéré le [clock format [clock seconds] -format {%Y-%m-%d %H:%M}].\n"
puts $fo "| Mesure | Procédures | % |\n|---|---|---|"
puts $fo "| Total (procédures et méthodes d'`ordali_*.tcl` chargées) | $N | 100 |"
puts $fo "| Atteintes par l'audit | $nA | [pct $nA $N] |"
puts $fo "| Atteintes par les tests ciblés | $nT | [pct $nT $N] |"
puts $fo "| Atteintes par l'un ou l'autre | $nU | [pct $nU $N] |"
puts $fo "| Atteintes dès le démarrage | [dict size $Demarrage] | [pct [dict size $Demarrage] $N] |"
puts $fo "| Jamais atteintes, sans appelant connu (code mort probable) | $nM | [pct $nM $N] |"
puts $fo "| Jamais atteintes, avec appelant | [expr {$N-$nU-$nM}] | [pct [expr {$N-$nU-$nM}] $N] |\n"
puts $fo "## Par fichier\n\n| Fichier | Total | Audit | Tests | Total atteint | % | Non atteintes avec appelant |\n|---|---|---|---|---|---|---|"
set Lignes {}
dict for {t Ln} $ParF {
    set a 0; set b 0; set u 0; set p 0
    foreach n $Ln {
	set x [dict exists $Audit $n]; set y [dict exists $Tests $n]
	incr a $x; incr b $y
	if {$x || $y} {incr u} elseif {! [sansappel $n]} {incr p}
    }
    lappend Lignes [list $p $t [llength $Ln] $a $b $u [pct $u [llength $Ln]]]
}
foreach l [lsort -integer -decreasing -index 0 $Lignes] {
    lassign $l p t tot a b u pc
    puts $fo "| $t | $tot | $a | $b | $u | $pc | $p |"
}
puts $fo "\n## Apport de chaque exécution\n\nProcédures atteintes par elle seule.\n\n| Exécution | atteintes | seule à les atteindre |\n|---|---|---|"
dict for {tag d} $ParTag {
    set seul 0
    dict for {n _} $d {
	set autres 0
	dict for {t2 d2} $ParTag {if {$t2 ne $tag && [dict exists $d2 $n]} {set autres 1; break}}
	if {! $autres} {incr seul}
    }
    puts $fo "| $tag | [dict size $d] | $seul |"
}
puts $fo "\n## Jamais atteintes, avec appelant\n"
foreach t [lsort [dict keys $ParF]] {
    set l [lsort [lmap n [dict get $ParF $t] {if {[dict exists $Audit $n] || [dict exists $Tests $n] || [sansappel $n]} continue; set n}]]
    if {[llength $l]} {puts $fo "- **$t** ([llength $l]) : [join $l {, }]\n"}
}
puts $fo "## Jamais atteintes, sans appelant connu\n\nUn appel construit dynamiquement n'est pas vu : ce sont des candidats, pas des certitudes.\n"
foreach t [lsort [dict keys $ParF]] {
    set l [lsort [lmap n [dict get $ParF $t] {if {[dict exists $Audit $n] || [dict exists $Tests $n] || ! [sansappel $n]} continue; set n}]]
    if {[llength $l]} {puts $fo "- **$t** ([llength $l]) : [join $l {, }]\n"}
}
close $fo
puts "$out : $N procédures, audit $nA, tests $nT, union $nU, mort probable $nM"
