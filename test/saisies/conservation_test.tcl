# Alignment > Conservation : chaque méthode de la liste (Threshold, BILD, Liu, Mean Distances, JSD, Shannon,
# Vector Norm, Multi, GroupSim) calcule sans erreur une feature temporaire ; Threshold : toute colonne où
# toutes les séquences ont le même résidu (sans gap) est « identité », et une colonne « identité » n'a qu'un
# résidu ; Only Global : pas de catégorie de groupe ; titre ; Save (feature Cons-, scores) ; Export (CSV).
# Usage : tclsh8.6 test/saisies/conservation_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Calcule {m {global 0} {multi ""}} {
    Q [list set ::Cons(Method) $m]
    Q [list set ::Cons(OnlyGlobal) $global]
    set avant [Q {lsearch -all -inline -glob $::ListeTypesDeFeatures tmpCons*}]
    if {$m eq "Multi"} {
	set id [Q [list probe::fire LanceCalculConservation]]
	set t0 [clock milliseconds]
	while {! [Q {winfo exists .choosemeth.f.btn.cebon}] && [clock milliseconds] - $t0 < 20000} {after 200}
	foreach x $multi {Q [list set ::Cons(multi,meth-$x) 1]}
	Q {.choosemeth.f.btn.cebon invoke}
	set r [W::waitfor $id 600000]
    } else {
	set r [W::fire LanceCalculConservation 600000]
    }
    V "$m[expr {$global ? " (Only Global)" : ""}] : sans erreur" {! [Err $r]} [expr {[Err $r] ? [string range [dict get $r errorInfo] 0 300] : [Dialogues $r]}]
    set ft [lmap x [Q {lsearch -all -inline -glob $::ListeTypesDeFeatures tmpCons*}] {expr {$x in $avant ? [continue] : $x}}]
    if {$m eq "GroupSim"} {set ft [Q {lsearch -all -inline -glob $::ListeTypesDeFeatures *GroupSim*}]}
    V "$m : une feature créée" {[llength $ft] >= 1} "$ft"
    return [lindex $ft end]
}
proc Notes {ft} {Q "set r {}; foreach k \[array names ::TabSF *,$ft\] {foreach e \$::TabSF(\$k) {lappend r \[dict get \$e fnote\]}}; lsort -unique \$r"}
# colonnes notées n
proc Colonnes {ft n} {Q "set r {}; foreach k \[array names ::TabSF *,$ft\] {foreach e \$::TabSF(\$k) {if {\[dict get \$e fnote\] eq {$n}} {for {set i \[dict get \$e fstart\]} {\$i <= \[dict get \$e fstop\]} {incr i} {lappend r \$i}}}}; lsort -unique -integer \$r"}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    F "mode Conservation" {ChangeMode conservation} 60000
    # Threshold
    set ft [Calcule Threshold]
    set nt [Notes $ft]
    V "Threshold : catégories identité et conservation" {"IdenGlob" in $nt && "ConsGlob" in $nt} $nt
    set Id [Colonnes $ft IdenGlob]
    set Tot [Q {
	set Ls [lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : $::Sequences([string trim $n])}}]
	set r {}
	for {set i 0} {$i < [string length [lindex $Ls 0]]} {incr i} {
	    set c [lsort -unique [lmap s $Ls {string index $s $i}]]
	    if {[llength $c] == 1 && $c ne "."} {lappend r $i}
	}
	set r
    }]
    V "Threshold : colonnes entièrement identiques ([llength $Tot]) marquées identité" {[llength [lmap c $Tot {expr {$c in $Id ? [continue] : $c}}]] == 0} [lmap c $Tot {expr {$c in $Id ? [continue] : $c}}]
    set plusieurs [Q "set r {}; foreach i {$Id} {set c \[lsort -unique \[lmap n \$::LNOrdali {expr {\[string trim \$n\] eq {} ? \[continue\] : \[string index \$::Sequences(\[string trim \$n\]) \$i\]}}\]\]; set c \[lsearch -all -inline -not -exact \$c .\]; if {\[llength \$c\] > 1} {lappend r \$i:\$c}}; set r"]
    V "Threshold : une colonne identité n'a qu'un résidu" {$plusieurs eq ""} [lrange $plusieurs 0 3]
    # méthodes automatiques
    foreach m {BILD Liu "Mean Distances" JSD Shannon "Vector Norm"} {
	set f [Calcule $m]
	V "$m : scores enregistrés" {[Q "llength \[array names ::ScoreMeth [list $f],*\]"] > 0}
    }
    set f [Calcule Multi 0 {JSD BILD}]
    # Only Global : seulement les catégories globales
    set f [Calcule Threshold 1]
    V "Only Global : pas de catégorie de groupe" {[lsearch -all -inline -not -regexp [Notes $f] {Glob$}] eq ""} [Notes $f]
    # GroupSim
    set f [Calcule GroupSim]
    # titre, Save, Export
    Q {set ::Cons(Method) JSD}
    set f [Calcule JSD]
    Q {$::Cons(Entry) delete 0 end; $::Cons(Entry) insert 0 "Mon titre"}
    Q "set ::Cons(ConsCou) \[lsearch -inline -index 0 \$::Cons(ListeCons) [list $f]\]"
    set r [W::fire SauveConservation 60000]
    V "Save : sans erreur" {! [Err $r]} [expr {[Err $r] ? [dict get $r errorInfo] : ""}]
    set cons [Q {lsearch -all -inline -glob $::ListeTypesDeFeatures Cons-JSD*}]
    V "Save : feature Cons-JSD" {$cons ne ""} [Q {set ::ListeTypesDeFeatures}]
    V "Save : scores de la feature" {[Q "llength \[array names ::ScoreMeth [lindex $cons 0],*\]"] > 0}
    Q "set ::Cons(ConsCou) [list [lindex $cons 0]]"
    set r [W::fire ExporteScoreConservation 60000]
    set csv "[file rootname [Q {set ::Defauts(Fichier[TypeAli])}]]_[lindex $cons 0].csv"
    V "Export : fichier CSV" {[Q [list file exists $csv]]} $csv
    if {[Q [list file exists $csv]]} {
	set L [split [string trim [Q "set c \[open [list $csv]\]; set t \[read \$c\]; close \$c; set t"]] \n]
	V "Export : une ligne par groupe, des scores" {[llength $L] >= 2 && [llength [split [lindex $L 1] ,]] > 100} "[llength $L] lignes"
    }
    F "Return" {QuitteModeConservation $::FrmBouton.cons} 60000
    V "Return : feature sauvée gardée" {[lindex $cons 0] in [Q {set ::ListeTypesDeFeatures}]}
    V "Return : features temporaires retirées" {[Q {lsearch -all -inline -glob $::ListeTypesDeFeatures tmpCons*}] eq ""}
    Inv "après Conservation"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
