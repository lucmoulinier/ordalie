# Sequences > Search motif : nombre d'occurrences et place des zones rouges (tag Cherche) comparés à un
# calcul indépendant (motif traduit à la main en expression régulière, séquences sans gaps), pour plusieurs
# formes de la syntaxe FindPatterns ; casse ignorée ; motif mal formé : message ; Find Next ; Return ;
# recherche depuis l'Editor (seqlab) ; après un changement d'instance.
# Usage : tclsh8.6 test/saisies/motif_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
# zones attendues : {ligne.colonne_début ligne.colonne_fin} dans l'alignement affiché
proc Attendu {re} {
    Q [string map [list @RE@ $re] {
	set r {}
	set i 0
	foreach n $::LNOrdali s [$::NomTextSeq output all] {
	    incr i
	    if {[string trim $n] eq ""} continue
	    set Lcol [regexp -all -inline -indices {[^. ]} $s]
	    set sdg [string toupper [string map {"." "" " " ""} $s]]
	    foreach e [regexp -all -inline -indices -- {@RE@} $sdg] {
		lassign $e d f
		lappend r $i.[lindex $Lcol $d 0] $i.[lindex $Lcol $f 0]
	    }
	}
	set r
    }]
}
proc Cherche {motif} {
    Q [list set ::Chrc(Motif) $motif]
    F "recherche de $motif" {$::FrmBouton.fsearch.fse.sea invoke} 60000
}
# motif FindPatterns -> expression régulière écrite à la main
set Cas {
    KMSKS        KMSKS
    kmsks        KMSKS
    H(X){2}GH    H.{2}GH
    G(X){1,3}G   G.{1,3}G
    R(K,R)~P     R[KR][^P]
    GC~(A,T)C    GC[^AT]C
    <M           ^M
    K>           K$
    RG{2}        RG{2}
}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    F "mode Search motif" {ChangeMode search} 30000
    V "champ du motif" {[Q {winfo exists $::FrmBouton.fsearch.fse.ent}]}
    foreach {m re} $Cas {
	set att [Attendu $re]
	Cherche $m
	set n [expr {[llength $att] / 2}]
	V "$m : $n occurrences" {[Q {set ::Chrc(NbrOccus)}] eq "$n found"} [Q {set ::Chrc(NbrOccus)}]
	# zones : le tag couvre chaque occurrence, de son début à sa fin
	set tag [Q {$::NomTextSeq tag ranges Cherche}]
	set ok [expr {[lsort $tag] eq [lsort $att] || [Q {llength $::Chrc(LOccus)}] == [llength $att] && [lsort [Q {set ::Chrc(LOccus)}]] eq [lsort $att]}]
	V "$m : zones aux bonnes colonnes" {$ok} "attendu [lrange $att 0 5] ; trouvé [lrange [Q {set ::Chrc(LOccus)}] 0 5]"
	if {$n > 1} {
	    set i0 [Q {set ::Chrc(IdxMotif)}]
	    F "$m : Find Next" {$::FrmBouton.fsearch.frbt.next invoke}
	    V "$m : occurrence suivante" {[Q {set ::Chrc(IdxMotif)}] == ($i0 + 1) % $n} [Q {set ::Chrc(IdxMotif)}]
	}
    }
    V "Editor : motif présent" {[llength [Attendu {H.{2}GH}]] > 0}
    V "au moins un motif trouvé plusieurs fois" {[llength [Attendu G.{1,3}G]] > 4}
    # motifs mal formés : message, pas d'erreur, ancien résultat effacé ou gardé sans erreur
    foreach m {G(X G\{2 GX)( G(,A) G<A <G<A GA>K Z1} {
	Q [list set ::Chrc(Motif) $m]
	set r [F "motif mal formé $m" {$::FrmBouton.fsearch.fse.sea invoke} 30000]
	V "$m : message" {[Dialogues $r] ne ""} ""
    }
    # Return
    F "Return" {$::FrmBouton.fsearch.frbt.dismiss invoke} 30000
    V "Return : fond blanc" {[Q {$::NomTextSeq cget -background}] eq "white"} [Q {$::NomTextSeq cget -background}]
    V "Return : plus de zones rouges" {"Cherche" ni [Q {$::NomTextSeq tag names}]}
    V "Return : mode normal" {[Q QuelMode] in {ordali feature}} [Q QuelMode]
    Inv "après Search motif"

    puts "=== depuis une autre instance"
    F "instance M5" {MiseAJourMac x {M5 - Kinetoplatids}} 120000
    F "mode Search motif" {ChangeMode search} 30000
    set att [Attendu {G.{1,3}G}]
    Cherche {G(X){1,3}G}
    V "M5 : occurrences" {[Q {set ::Chrc(NbrOccus)}] eq "[expr {[llength $att]/2}] found"} [Q {set ::Chrc(NbrOccus)}]
    F "Return" {$::FrmBouton.fsearch.frbt.dismiss invoke} 30000

    puts "=== depuis l'Editor"
    F "Editor" {ChangeMode seqlab} 60000
    F "Search motif depuis l'Editor" {ChangeMode search} 30000
    set att [Attendu {H.{2}GH}]
    Cherche {H(X){2}GH}
    V "Editor : occurrences" {[Q {set ::Chrc(NbrOccus)}] eq "[expr {[llength $att]/2}] found"} [Q {set ::Chrc(NbrOccus)}]
    F "Return" {$::FrmBouton.fsearch.frbt.dismiss invoke} 30000
    V "retour dans l'Editor" {[Q QuelMode] eq "seqlab"} [Q QuelMode]
    Inv "Editor après Search motif"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
