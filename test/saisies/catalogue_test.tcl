# Contrôle de l'audit : chaque item de la barre de menus qui ouvre une fenêtre ou un mode avec des champs de
# saisie doit avoir, dans catalogue.txt, au moins un test qui vérifie ce que ces champs produisent.
# L'inventaire du banc (banc/inventory.tcl) déclenche chaque item et relève les widgets ouverts ; un item à
# saisie absent du catalogue, ou dont un test n'existe pas, est un échec. Rien n'est vérifié du contenu des
# tests eux-mêmes : c'est leur rôle.
# Même contrôle pour le bouton droit : chaque binding du bouton droit des sources doit être dans clicdroit.txt.
# Usage : tclsh8.6 test/saisies/catalogue_test.tcl [numéro d'instance] [fichier]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set Fichier [expr {$argc > 1 ? [lindex $argv 1] : ""}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
if {$Fichier eq ""} {set Fichier $Test/T_tutorial_maj.ord}
set Saisies {Entry TEntry Text TCombobox Combobox Spinbox TSpinbox Checkbutton TCheckbutton Radiobutton TRadiobutton Scale TScale Listbox}

# catalogue
set Cat [dict create]
set c [open $Ici/catalogue.txt]
foreach l [split [read $c] \n] {
    if {[string trim $l] eq "" || [string index $l 0] eq "#"} continue
    lassign [split $l |] item tests
    dict set Cat [string trim $item] [string trim $tests]
}
close $c

if {[catch {
    Start $Fichier
    set out $Tmp/inventaire.txt
    exec [info nameofexecutable] [file join $Test banc inventory.tcl] [expr {4500+$N}] A $out >@stdout 2>@stderr
    Stop
    # un enregistrement peut tenir sur plusieurs lignes (messages d'erreur)
    set c [open $out]; set L {}; set cur ""
    foreach l [split [read $c] \n] {
	append cur $l \n
	if {[info complete $cur]} {lappend L [string trim $cur]; set cur ""}
    }
    close $c
    set n 0
    foreach rec $L {
	if {! [string match "item *" $rec]} continue
	set p [dict get $rec item]
	set cl {}
	foreach t [expr {[dict exists $rec newtops] ? [dict get $rec newtops] : {}}] {
	    foreach w [dict get $t widgets] {lappend cl [dict get $w class]}
	}
	foreach w [expr {[dict exists $rec modewidgets] ? [dict get $rec modewidgets] : {}}] {lappend cl [dict get $w class]}
	set es [lsort -unique [lmap x $cl {expr {$x in $Saisies ? $x : [continue]}}]]
	if {$es eq ""} continue
	incr n
	if {! [dict exists $Cat $p]} {
	    V "$p ([join $es ,]) : dans le catalogue" 0 "item à saisie sans test : ajouter un test et une ligne à catalogue.txt"
	    continue
	}
	set t [dict get $Cat $p]
	if {[string match "-*" $t]} {
	    V "$p : sans saisie ([string range $t 2 end])" 1
	    continue
	}
	set manque [lmap f $t {expr {[file exists [file join $Test $f]] ? [continue] : $f}}]
	V "$p ([join $es ,]) : tests présents" {$manque eq "" && $t ne ""} "manquent : $manque"
    }
    V "items à saisie trouvés par l'inventaire" {$n >= 15} $n
} m]} {
    V "script" 0 $m
    catch Stop
}

# Bouton droit : chaque binding du bouton droit des sources (procédure qui le pose) doit être dans
# clicdroit.txt, avec des tests présents ou une raison (binding inatteignable).
if {[catch {
    set CD [dict create]
    set c [open $Ici/clicdroit.txt]
    foreach l [split [read $c] \n] {
	if {[string trim $l] eq "" || [string index $l 0] eq "#"} continue
	lassign [split $l |] k t
	dict set CD [string trim $k] [string trim $t]
    }
    close $c
    set Src [file join [file dirname $Test] src]
    set vus {}
    foreach f [lsort [glob -directory $Src ordali_*.tcl]] {
	set p "(hors procédure)"
	set c [open $f]; fconfigure $c -encoding binary
	foreach l [split [read $c] \n] {
	    if {[regexp {^\s*proc\s+(\S+)} $l -> x]} {set p $x}
	    if {[regexp {^\s*oo::define\s+\S+\s+method\s+(\S+)} $l -> x]} {set p $x}
	    if {[regexp {^\s*#} $l]} continue
	    if {[regexp {bind} $l] && [regexp {<((Control|Shift|Double|Alt)-)?(Button-3|ButtonPress-3|ButtonRelease-3|3|B3-Motion)>} $l]} {
		lappend vus "[file tail $f]:$p"
	    }
	}
	close $c
    }
    set vus [lsort -unique $vus]
    foreach k $vus {
	if {! [dict exists $CD $k]} {
	    V "bouton droit $k : dans clicdroit.txt" 0 "binding du bouton droit sans test : ajouter un test et une ligne à clicdroit.txt"
	    continue
	}
	set t [dict get $CD $k]
	if {[string match "-*" $t]} {V "bouton droit $k : inatteignable ([string range $t 2 end])" 1; continue}
	set manque [lmap f $t {expr {[file exists [file join $Test $f]] ? [continue] : $f}}]
	V "bouton droit $k : tests présents" {$manque eq "" && $t ne ""} "manquent : $manque"
    }
    V "bindings du bouton droit trouvés dans les sources" {[llength $vus] >= 8} [llength $vus]
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
