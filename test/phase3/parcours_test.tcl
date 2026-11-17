# Phase 3 : parcours complets, menés jusqu'au résultat, avec les contrôles d'état après chaque étape :
# arbre puis radial, clustering, conservation sauvée, ajout de séquences (fichier, UniProt) et de
# structures (CIF, identifiant PDB), superposition puis viewer, nouvelle instance, puis aller-retour ORD.
# Usage : tclsh8.6 test/phase3/parcours_test.tcl [numéro d'instance]   (P3_RESEAU=0 : sans réseau)
set N [expr {$argc ? [lindex $argv 0] : 7}]
source [file join [file dirname [file normalize [info script]]] commun.tcl]
set Reseau [expr {[info exists env(P3_RESEAU)] ? $env(P3_RESEAU) : 1}]
set Donnees $env(HOME)/.cache/claude-ordalie-tests/donnees
proc Q {s} {W::ask $s}
proc Etape {tag cmd {ms 300000}} {
    set r [F $tag $cmd $ms]
    Inv $tag
    return $r
}
proc Bouton {cmd} {
    Q [list apply {{cmd} {
	set l [list .]
	while {$l ne {}} {
	    set l [lassign $l w]
	    lappend l {*}[winfo children $w]
	    if {! [catch {$w cget -command} c] && [string match "$cmd*" $c]} {return $w}
	}
	return ""
    }} $cmd]
}
# hélices et brins déclarés dans un CIF (boucle _struct_conf, colonne conf_type_id)
proc StructuresDuCIF {f} {
    set c [open $f]; set L [split [read $c] \n]; close $c
    set r [dict create Helix 0 Sheet 0]; set dans 0
    foreach l $L {
	if {[string match "_struct_conf.*" $l]} {set dans 1; continue}
	if {! $dans} continue
	if {[string match "#*" $l]} break
	set t [lindex $l 6]
	if {[string match HELX* $t]} {dict incr r Helix}
	if {[string match STRN* $t]} {dict incr r Sheet}
    }
    return $r
}
proc Ajout {tag what var val} {
    W::fire [list AjouteSequenceOrPDB $what] 5000
    Q [list set ::TAddS($var) $val]
    Etape $tag {.was.fbut.ok invoke} 600000
    V "$tag : fenêtre fermée" {! [Q {winfo exists .was}]}
}

if {[catch {
    # P3_FICHIER : autre fichier de départ (il doit avoir des structures, dont un modèle AlphaFold)
    Start [expr {[info exists env(P3_FICHIER)] ? $env(P3_FICHIER) : "$Test/T_tutorial_maj.ord"}]
    Inv "ouverture"
    Q {probe::answer tk_dialog 1}

    puts "=== arbre"
    set La0 [Q {expr {[info exists ::Abr(Liste)] ? $::Abr(Liste) : {}}}]
    Etape "mode arbres" {ChangeMode arbres}
    Etape "toutes les colonnes" {SelectionneToutesColonnes}
    Etape "calcul de l'arbre" CalculeUnArbre
    set La [Q {set ::Abr(Liste)}]
    set A [lindex $La end]
    V "arbre : nouveau" {[llength $La] == [llength $La0] + 1} $La
    V "arbre : instance courante" {[Q "set ::Abr($A,Mac)"] eq [Q MacCourant]}
    set fe [Q "lsort \[\$::Abr(Arbre,$A) leaves\]"]
    # les structures n'entrent dans l'arbre que si « include PDB » est coché (Defauts(PDBTree))
    set no [Q {lsort [expr {$::Defauts(PDBTree) ? [::P3::Noms] : [lmap n [::P3::Noms] {expr {$n in $::ListePDB ? [continue] : $n}}]}]}]
    V "arbre : toutes les séquences" {[llength $fe] == [llength $no]} "[llength $fe] feuilles, [llength $no] séquences ; absentes de l'arbre : [lrange [lmap x $no {expr {$x in $fe ? [continue] : $x}}] 0 10] ; feuilles inconnues : [lrange [lmap x $fe {expr {$x in $no ? [continue] : $x}}] 0 10]"
    Etape "arbre en radial" "set ::Abr($A,TypeTree) radial; OnReDessineArbre $A"
    V "arbre radial dessiné" {[Q "llength \[\$::Abr($A,PAD) find all\]"] > 0}
    Etape "retour au mode normal" {ChangeMode feature}

    puts "=== clustering"
    set G0 [Q {set ::LNDG}]
    Etape "mode clustering" {ChangeMode cluster}
    Etape "clustering secator, longueur" {
	foreach k [array names ::Clus LCrit,*] {set ::Clus($k) 0}
	set ::Clus(LCrit,length) 1
	set ::Clus(Method) "hierarchic / secator"
	NouveauClustering
    }
    Etape "retour" {ChangeMode feature}
    V "clustering : groupes refaits" {[Q {set ::LNDG}] ne $G0 && [llength [Q {set ::LNDG}]] > 2} [Q {set ::LNDG}]

    puts "=== conservation"
    Etape "mode conservation" {ChangeMode conservation}
    Etape "calcul" {set ::Cons(Method) Threshold; set ::Cons(Title) parcours; LanceCalculConservation}
    set ft [Etape "sauvegarde" SauveConservation]
    set Lf [Q {set ::ListeTypesDeFeatures}]
    V "conservation : feature gardée" {[llength [lsearch -all -glob $Lf Cons-T80*]] >= 1} $Lf
    Etape "retour" "[Bouton QuitteModeConservation] invoke"

    puts "=== ajouts"
    set n0 [Q {llength [::P3::Noms]}]
    set na [regexp -all -line {^>} [exec cat $Donnees/ajout.tfa]]
    Ajout "séquences d'un fichier ($na)" seqfile SeqFileIn $Donnees/ajout.tfa
    set n1 [Q {llength [::P3::Noms]}]
    V "fichier : séquences ajoutées" {$n1 == $n0 + $na} "$n0 -> $n1"
    if {$Reseau} {
	Ajout "séquence UniProt F7CP98" database SeqIdIn F7CP98
	V "UniProt : séquence ajoutée" {"F7CP98" in [Q ::P3::Noms] || [Q {llength [::P3::Noms]}] == $n1 + 1}
    }
    set p0 [Q {llength $::ListePDB}]
    Ajout "structure CIF AlphaFold Q3KRD0" pdbfile StrucFileIn $Donnees/AF-Q3KRD0-F1-model_v6.cif
    V "CIF : structure ajoutée et colorée" {[Q {llength $::ListePDB}] == $p0 + 1} [Q {set ::ListePDB}]
    # structures secondaires lues = celles du fichier (hélices HELX_*, brins STRN de _struct_conf)
    set Att [StructuresDuCIF $Donnees/AF-Q3KRD0-F1-model_v6.cif]
    set Lues [Q {set ns [info object namespace ::Q3KRD0]; set r [dict create Helix 0 Sheet 0]; foreach e [set ${ns}::SecStr(A)] {set t [lindex $e 0]; if {$t in {Helix Sheet}} {dict incr r $t}}; set r}]
    V "CIF : hélices et brins du fichier tous lus" {$Lues eq $Att} "fichier $Att, lus $Lues"
    if {$Reseau} {
	set p1 [Q {llength $::ListePDB}]
	Ajout "structure PDB 1IL2 par identifiant" pdbid StrucIdIn 1IL2
	V "PDB : structure ajoutée" {[Q {llength $::ListePDB}] > $p1} [Q {set ::ListePDB}]
    }

    puts "=== superposition puis viewer"
    Q {proc ::Dlg {} {
	if {[winfo exists .pdbchooser]} {.pdbchooser.btn.selall invoke; update; .pdbchooser.btn.cebon invoke}
	if {[winfo exists .pdbref]} {set ::chxmolref [lindex $::ListePDB 0]; update; .pdbref.btn.cebon invoke}
	after 300 Dlg
    }}
    set n [lindex [Q {set ::ListePDB}] 0]
    set C0 [dict get [Q ::P3::Empreinte] "coordonnées [lindex [Q {set ::ListePDB}] 1]"]
    Q {unset -nocomplain ::SupRotTrans; ChangeMode superpose; $::FrmBouton.select.falcl.sal invoke; after 300 Dlg}
    Etape "superposition" {$::FrmBouton.select.frmsst.fin invoke}
    Q {foreach i [after info] {if {[lindex [after info $i] 0] eq "Dlg"} {after cancel $i}}}
    V "superposition : structures transformées" {[llength [Q {array names ::SupRotTrans}]] >= 2} [Q {array names ::SupRotTrans}]
    Etape "viewer" VisualiseStructure
    for {set i 0} {$i < 100 && ! [Q {winfo exists .ordogl}]} {incr i} {after 200}
    V "viewer ouvert" {[Q {winfo exists .ordogl}]}
    Inv "viewer"
    Etape "fermeture du viewer" QuitteViandox
    Etape "retour au mode normal" {ChangeMode feature}

    puts "=== nouvelle instance et aller-retour ORD"
    set m0 [llength [Q LesMacs]]
    Etape "nouvelle instance" {SauveLeMac 1 Parcours "parcours phase 3"}
    V "nouvelle instance" {[llength [Q LesMacs]] == $m0 + 1} [Q LesMacs]
    set E0 [Q ::P3::EmpreinteFichier]
    Inv "tour des instances"
    Etape "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/p.ord]
    Stop
    Start $Tmp/p.ord
    Inv "réouverture"
    set E1 [Q ::P3::EmpreinteFichier]
    dict for {m e} $E0 {
	if {[V "instance $m présente" {[dict exists $E1 $m]}]} {Same "$m après réouverture" $e [dict get $E1 $m]}
    }
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
