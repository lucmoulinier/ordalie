# Sequences > Export Feature to file : aller-retour avec Add feature from file. Les features choisies sont
# écrites, relues sous un autre nom, et chaque élément relu doit être identique à l'original (début, fin,
# couleur, score, note, système de coordonnées). Option « selected sequences ». Note avec ';' ou espaces.
# Valeurs refusées : aucun nom de fichier, aucune feature, aucune séquence sélectionnée.
# Usage : tclsh8.6 test/saisies/export_features_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Exporte {feats fichier {seqs all}} {
    F "fenêtre Export" WindowWriteFeatureFile 30000
    foreach f [Q {array names ::WFeat LFeat,*}] {Q "set ::WFeat($f) 0"}
    foreach f $feats {Q [list set ::WFeat(LFeat,$f) 1]}
    Q [list set ::WFeat(file) $fichier]
    Q [list set ::WFeat(seqs) $seqs]
    F "OK" {.writefeat.f.fbut.ok invoke} 30000
}
# éléments d'une feature, triés : {séquence élément}
proc Elements {f {seqs ""} {c ""}} {
    Q [string map [list @F $f @S $seqs @C $c] {
	set r {}
	foreach k [lsort [array names ::TabSF *,@F]] {
	    set s [string range $k 0 end-[string length ,@F]]
	    if {"@S" ne "" && $s ni {@S}} continue
	    foreach e $::TabSF($k) {
		array unset T; array set T $e
		# système de coordonnées : celui attendu après export (global si l'élément commence ou finit sur un gap)
		set cs $T(fcsys)
		if {"@C" eq "export" && $cs eq "local" && ([string index $::Sequences($s) $T(fstart)] eq "." || [string index $::Sequences($s) $T(fstop)] eq ".")} {set cs global}
		lappend r [list $s $T(fstart) $T(fstop) $T(fcolor) [expr {double($T(fscore))}] $T(fnote) $cs]
	    }
	}
	lsort $r
    }]
}
proc Renomme {fichier suffixe} {
    set c [open $fichier]; set t [read $c]; close $c
    regsub -all -line {^FEATURE (\S+)} $t "FEATURE \\1$suffixe" t
    set c [open $fichier w]; puts -nonewline $c $t; close $c
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    # une feature locale (structure : numéros de résidus PDB) et des globales
    set Lf [Q {set ::ListeTypesDeFeatures}]
    puts "     features : $Lf"
    set Choix [lmap f {PFAM-A STRUCT Cons-T80 REGION} {expr {$f in $Lf ? $f : [continue]}}]
    V "features à exporter" {[llength $Choix] >= 2} $Choix
    # une note avec des espaces et un ';' (séparateur du format)
    set s0 [lindex [Q {lsort [array names ::TabSF *,[lindex $::ListeTypesDeFeatures 0]]}] 0]
    Exporte $Choix $Tmp/a.feat
    V "fichier écrit" {[file exists $Tmp/a.feat]}
    Renomme $Tmp/a.feat _relu
    set r [F "relecture" [list ReadRawFeatureFile $Tmp/a.feat] 120000]
    V "relecture sans message" {[Dialogues $r] eq ""} [string range [Dialogues $r] 0 300]
    foreach f $Choix {
	set a [Elements $f "" export]; set b [Elements ${f}_relu]
	V "$f : [llength $a] éléments relus à l'identique" {$a eq $b && [llength $a] > 0} "[llength $a] / [llength $b] ; premier écart : [lindex [lmap x $a y $b {expr {$x eq $y ? [continue] : "$x <> $y"}}] 0]"
    }
    V "features relues dans la liste" {[llength [Q {lsearch -all -glob $::ListeTypesDeFeatures *_relu}]] == [llength $Choix]}

    puts "=== séquences sélectionnées"
    set Ln [Q {lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : [string trim $n]}}}]
    set f [lindex $Choix 0]
    set avec [lmap n $Ln {expr {[Q "info exists ::TabSF($n,$f)"] ? $n : [continue]}}]
    set sel [lrange $avec 0 1]
    Q {set ::PosInitNom 1.0}
    set premier 1
    foreach n $sel {
	set y [expr {[lsearch [Q {lmap n $::LNOrdali {string trim $n}}] $n] + 1}]
	W::fire [list SelectNomSeq [expr {$premier ? "une" : "ctr"}] $y.0] 20000
	set premier 0
    }
    Exporte [list $f] $Tmp/b.feat selected
    Renomme $Tmp/b.feat _sel
    F "relecture" [list ReadRawFeatureFile $Tmp/b.feat] 120000
    V "$f : seulement les séquences sélectionnées" {[lsort -unique [lmap e [Elements ${f}_sel] {lindex $e 0}]] eq [lsort $sel]} [lsort -unique [lmap e [Elements ${f}_sel] {lindex $e 0}]]
    V "$f : leurs éléments" {[Elements ${f}_sel] eq [Elements $f $sel export]}

    puts "=== note avec ';'"
    set n [lindex $Ln 2]
    Q [list lappend ::TabSF($n,NoteSpe) [list fstart 10 fstop 20 fcolor red fscore 1.5 fnote "a b;c d" fcsys global]]
    Q {lappend ::ListeTypesDeFeatures NoteSpe}
    Exporte NoteSpe $Tmp/c.feat
    Renomme $Tmp/c.feat _relu
    set r [F "relecture" [list ReadRawFeatureFile $Tmp/c.feat] 60000]
    V "note avec ';' relue" {[Elements NoteSpe_relu] eq [Elements NoteSpe]} "[Elements NoteSpe_relu] ; [Dialogues $r]"

    puts "=== valeurs refusées"
    F "fenêtre Export" WindowWriteFeatureFile 30000
    foreach f [Q {array names ::WFeat LFeat,*}] {Q "set ::WFeat($f) 0"}
    Q {set ::WFeat(seqs) all; set ::WFeat(file) ""}
    set r [F "sans nom de fichier" {.writefeat.f.fbut.ok invoke}]
    V "sans nom de fichier : message" {[string match -nocase "*file name*" [Dialogues $r]]} [Dialogues $r]
    Q [list set ::WFeat(file) $Tmp/d.feat]
    set r [F "sans feature" {.writefeat.f.fbut.ok invoke}]
    V "sans feature : message" {[string match "*No feature*" [Dialogues $r]]} [Dialogues $r]
    Q {set ::NomSeqSel {}; set ::WFeat(seqs) selected}
    Q [list set ::WFeat(LFeat,[lindex $Choix 0]) 1]
    set r [F "sans séquence sélectionnée" {.writefeat.f.fbut.ok invoke}]
    V "sans séquence : message" {[string match "*No sequences*" [Dialogues $r]]} [Dialogues $r]
    F "Cancel" {.writefeat.f.fbut.cancel invoke}
    V "rien d'écrit" {! [file exists $Tmp/d.feat]}
    Inv "après Export"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
