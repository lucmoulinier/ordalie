# Sequences > Features Summary : séquences choisies dans la liste, features cochées ; chaque élément de
# feature des séquences choisies est dessiné (et seulement eux) ; noms affichés (Seq. Name, Accession,
# Bank Id) ; recherche d'un nom ; taille de police ; notes ; Return puis réouverture ; depuis l'éditeur.
# Usage : tclsh8.6 test/saisies/featsummary_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# éléments dessinés : {feature séquence début fin}, sans doublon (un élément peut couper une ligne)
proc Dessines {} {
    Q {
	set r {}
	foreach i [$::EFeat(PAD) find withtag TNote] {
	    set t [lsearch -inline -glob [$::EFeat(PAD) gettags $i] TCoord@*]
	    lappend r [lrange [split $t @] 1 end]
	}
	lsort -unique $r
    }
}
proc Attendus {seqs feats} {
    Q [string map [list @S $seqs @F $feats] {
	set r {}
	foreach n {@S} {foreach f {@F} {
	    if {! [info exists ::TabSF($n,$f)]} continue
	    foreach e $::TabSF($n,$f) {lappend r [list $f $n [dict get $e fstart] [dict get $e fstop]]}
	}}
	lsort -unique $r
    }]
}
proc Choisit {lignes} {
    Q "\$::EFeat(Listbox) selection clear 0 end; foreach i {$lignes} {\$::EFeat(Listbox) selection set \$i}; event generate \$::EFeat(Listbox) <<ListboxSelect>>; update"
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    F "Features Summary" FeatureSummary 30000
    set w [Q {set ::EFeat(SumWindow)}]
    V "fenêtre" {[Q "winfo exists $w"]}
    set LN [Q {set ::LNOrdali}]
    # deux séquences (indices de la liste = lignes - 1)
    set Li [lsearch -all -not -regexp $LN {^\s*$}]
    set i1 [lindex $Li 3]; set i2 [lindex $Li 10]
    set s1 [string trim [lindex $LN $i1]]; set s2 [string trim [lindex $LN $i2]]
    set feats {PFAM-A STRUCT}
    foreach f $feats {Q "set ::EFeat(LFeat,$f) 1"}
    Choisit [list $i1 $i2]
    V "séquences choisies" {[Q "list \$::EFeat(LMSeq,$s1) \$::EFeat(LMSeq,$s2)"] eq {1 1}}
    set d [Dessines]; set a [Attendus [list $s1 $s2] $feats]
    V "éléments dessinés = éléments des 2 séquences ([llength $a])" {$d eq $a && [llength $a] > 0} "dessinés [llength $d], attendus [llength $a]"
    # une feature décochée
    Q {set ::EFeat(LFeat,STRUCT) 0; TracageFeatureSummary}
    V "STRUCT décochée : plus dessinée" {[Dessines] eq [Attendus [list $s1 $s2] PFAM-A]}
    Choisit [list $i2]
    V "une seule séquence : seulement elle" {[Dessines] eq [Attendus [list $s2] PFAM-A]}
    # noms affichés
    foreach {mode t} {Accession TDesAccess "Bank Id" TDesBId "Seq. Name" TDesSeqnames} {
	Q [list set ::EFeat(NomsAff) $mode]
	F "noms : $mode" UpdateListboxSeqFeat
	V "liste : $mode" {[lindex [Q {set ::EFeat(ListboxListe)}] $i1] eq [Q "set ::${t}($s1)"]} "[lindex [Q {set ::EFeat(ListboxListe)}] $i1]"
    }
    # recherche d'un nom (sous-chaîne, sans tenir compte de la casse)
    set part [string toupper [string range $s2 1 5]]
    Q [list set ::EFeat(SearchNom) $part]
    F "recherche $part" ChercheNomDansListe
    set act [Q {$::EFeat(Listbox) index active}]
    V "recherche : nom trouvé" {[string match -nocase "*$part*" [lindex [Q {set ::EFeat(ListboxListe)}] $act]]} [lindex [Q {set ::EFeat(ListboxListe)}] $act]
    # taille de police
    Q {set ::EFeat(FontSize) 14}
    F "police 14" {ChangeFontEFeat 14}
    V "police 14" {[Q {font configure FontFeat -size}] == 14}
    V "toujours dessiné après la police" {[Dessines] eq [Attendus [list $s2] PFAM-A]}
    # notes
    Q {set ::EFeat(ShowNote) 1}
    F "notes" ShowFeatNote
    set it [lindex [Q {$::EFeat(PAD) find withtag TNote}] 0]
    V "notes : bulle sur les éléments" {[Q "\$::EFeat(PAD) bind $it <Enter>"] ne ""}
    # Return, puis réouverture
    F "Return" RetourFeatSummary
    V "fenêtre fermée" {! [Q "winfo exists $w"]}
    F "réouverture" FeatureSummary 30000
    V "réouverture : fenêtre" {[Q {winfo exists $::EFeat(SumWindow)}]}
    F "Return" RetourFeatSummary
    # depuis l'éditeur de features
    F "Features Editor" {ChangeMode feateditor} 60000
    F "Features Summary depuis l'éditeur" FeatureSummary 30000
    F "Save de l'éditeur (ferme le résumé)" {RetourEditFeatures save} 60000
    V "résumé fermé" {! [Q {expr {[info exists ::EFeat(SumWindow)] && [winfo exists $::EFeat(SumWindow)]}}]}
    Inv "après Features Summary"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
