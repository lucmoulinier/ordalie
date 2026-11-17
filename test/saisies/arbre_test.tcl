# Alignment > Tree building : options du panneau. La matrice de distances donnée à FastME est comparée à
# un calcul indépendant (1 - identité sur la plage choisie ; Global : seulement les colonnes sans gap) ;
# feuilles de l'arbre avec et sans les séquences PDB ; nombre de sites ; bootstrap ; plage absente ou trop
# courte : message.
# Usage : tclsh8.6 test/saisies/arbre_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# distances attendues : {noms distances} sur les colonnes d..f
proc Attendu {d f global pdb {sel ""}} {
    Q [string map [list @d $d @f $f @g $global @p $pdb @S $sel] {
	set Ln {}; set Ls {}
	foreach n $::LNOrdali {
	    set n [string trim $n]
	    if {$n eq "" || (! @p && $n in $::ListePDB)} continue
	    if {{@S} ne "" && $n ni {@S}} continue
	    set s [string range $::Sequences($n) @d @f]
	    if {[string length [string map {. "" " " ""} $s]] == 0} continue
	    lappend Ln $n; lappend Ls $s
	}
	if {@g} {
	    set Lc {}
	    for {set i 0} {$i < [string length [lindex $Ls 0]]} {incr i} {
		set ok 1; foreach s $Ls {if {[string index $s $i] in {. " "}} {set ok 0; break}}
		if {$ok} {lappend Lc $i}
	    }
	    set Ls [lmap s $Ls {join [lmap i $Lc {string index $s $i}] ""}]
	}
	set D {}
	foreach a $Ls {
	    foreach b $Ls {
		set p 0
		foreach x [split $a ""] y [split $b ""] {if {$x ne "." && $x eq $y} {incr p}}
		set la [string length [string map {. ""} $a]]; set lb [string length [string map {. ""} $b]]
		lappend D [expr {min($la,$lb) ? 1.0 - double($p)/min($la,$lb) : 1.0}]
	    }
	}
	list $Ln $D [string length [lindex $Ls 0]]
    }]
}
proc Arbre {reglages} {
    foreach {k v} $reglages {Q [list set ::Defauts($k) $v]}
    Q {set ::FastmeArgs {}}
    set r [W::fire CalculeUnArbre 600000]
    list [expr {[Err $r] ? [string range [dict get $r errorInfo] 0 300] : ""}] [Dialogues $r] [Q {set ::FastmeArgs}] [Q {lindex $::Abr(Liste) end}]
}
proc Proche {a b} {
    if {[llength $a] != [llength $b]} {return 0}
    foreach x $a y $b {if {abs($x-$y) > 1e-6} {return 0}}
    return 1
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    # FastME intercepté : arguments gardés
    Q {rename fastme fastme_vrai; proc fastme {Ln Ld} {set ::FastmeArgs [list $Ln $Ld]; fastme_vrai $Ln $Ld}}
    F "mode Tree" {ChangeMode arbres} 60000
    set d 200; set f 499
    Q "set ::ZoneSelect {{$d $f}}"
    # sélection de 8 séquences (au-delà de 3, l'arbre ne prend qu'elles) : assez de colonnes sans gap pour Global
    set LN [Q {set ::LNOrdali}]
    set Li [lsearch -all -not -regexp $LN {^\s*$}]
    set Rows [lmap i [lrange $Li 0 7] {expr {$i+1}}]
    set Sel [lmap y $Rows {string trim [lindex $LN $y-1]}]
    foreach {tag global pdb sel} {pairwise_sansPDB 0 0 0 pairwise_avecPDB 0 1 0 pairwise_selection 0 0 1 global_selection 1 0 1} {
	Q "set ::NomSeqSel {[expr {$sel ? [lmap y $Rows {set x $y.0}] : ""}]}"
	lassign [Arbre [list TypeGapTree [expr {$global ? "global" : "pairwise"}] PDBTree $pdb TreeBoot 0]] err msg args aid
	V "$tag : sans erreur" {$err eq "" && $msg eq ""} "$err $msg"
	lassign [Attendu $d $f $global $pdb [expr {$sel ? $Sel : ""}]] Ln D nsites
	lassign $args Lfn Lfd
	V "$tag : séquences ([llength $Ln])" {$Lfn eq $Ln} "[llength $Lfn]"
	V "$tag : distances" {[Proche $Lfd $D]} "[lrange $Lfd 1 3] / [lrange $D 1 3]"
	V "$tag : nombre de sites ($nsites)" {[Q "set ::Abr($aid,NbrSites)"] == $nsites} [Q "set ::Abr($aid,NbrSites)"]
	set feuilles [lsort [Q "\$::Abr(Arbre,$aid) leaves"]]
	V "$tag : feuilles de l'arbre" {[llength $feuilles] == [llength $Ln]} "[llength $feuilles]"
	V "$tag : PDB [expr {$pdb ? "présentes" : "absentes"}]" {$pdb ? [llength [Q "set r 0; foreach n {$Ln} {if {\$n in \$::ListePDB} {incr r}}; set r"]] > 0 : [Q "set r 0; foreach n {$Lfn} {if {\$n in \$::ListePDB} {incr r}}; set r"] == 0}
    }
    V "Global : moins de sites que Pairwise" {[Q "set ::Abr([lindex [Q {set ::Abr(Liste)}] end],NbrSites)"] < [Q "set ::Abr([lindex [Q {set ::Abr(Liste)}] end-1],NbrSites)"]}
    Q {set ::NomSeqSel {}}
    # bootstrap
    lassign [Arbre {TypeGapTree pairwise PDBTree 0 TreeBoot 1 TreeNBoot 10}] err msg args aid
    V "bootstrap 10 : sans erreur" {$err eq ""} $err
    V "bootstrap fait" {[Q "set ::Abr($aid,BootDone)"] == 1 && [Q "set ::Abr($aid,TreeNBoot)"] == 10}
    # plage trop courte, absente
    Q {set ::ZoneSelect {{200 205}}}
    lassign [Arbre {TypeGapTree pairwise TreeBoot 0}] err msg
    V "moins de 10 sites : message" {[string match "*Less than 10 sites*" $msg]} $msg
    Q {set ::ZoneSelect {}}
    lassign [Arbre {TypeGapTree pairwise TreeBoot 0}] err msg
    V "sans plage : message" {[string match "*No residue range*" $msg]} $msg
    F "Return" RetourDesArbres 60000
    Inv "après Tree building"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
