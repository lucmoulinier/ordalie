# Test des corrections G1 à G8 (bugs trouvés par la phase 4, 2026-11-09) :
# G1 Remove All separators efface les bonnes lignes, G3 clustering et G6 réalignement gardés à la
# sauvegarde ORD, G4 groupes après conservation et Remove All separators, G5 structure déjà ajoutée
# dans une autre instance, G7 Re-align sans séquence dans la sélection, G8 sélection périmée
# (ligne hors de l'alignement : Ordalie se fermait sur Add separator).
# Usage : tclsh8.6 test/phase4_corrections_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
set Donnees $Test
proc Q {s} {W::ask $s}
proc Sel {lignes} {
    Q {set ::PosInitNom 1.0}
    set premier 1
    foreach l $lignes {
	W::fire [list SelectNomSeq [expr {$premier ? "une" : "ctr"}] $l.0] 20000
	set premier 0
    }
}
# noms affichés (Biotext) = LNOrdali
proc Affiche {} {Q {expr {[lmap n [$::NomNomSeq output all] {string trim $n}] eq [lmap n $::LNOrdali {string trim $n}]}}}
proc Seps {} {Q {llength [lsearch -all -regexp $::LNOrdali {^\s*$}]}}
proc Empr {} {Q {dict remove [::P3::Empreinte] invariants}}
# sauvegarde ORD et réouverture, puis comparaison de l'empreinte de l'instance
proc AllerRetour {tag} {
    set E [Empr]
    F "$tag : sauvegarde" [list SauveLAlignement ORD $::Tmp/g.ord]
    Stop
    Start $::Tmp/g.ord
    set n 0
    set E1 [Empr]
    foreach k [dict keys $E] {
	if {[string match "arbre *" $k] || $k in {instance description}} continue
	if {! [dict exists $E1 $k] || [dict get $E1 $k] ne [dict get $E $k]} {
	    V "$tag : $k identique après réouverture" 0 [expr {[dict exists $E1 $k] ? [string range [dict get $E1 $k] 0 150] : "absent"}]
	    incr n
	}
    }
    if {! $n} {V "$tag : instance identique après réouverture" 1}
}

if {[catch {
    puts "=== G1"
    Start $Test/R_tutorial_maj.ord
    V "G1 : affichage cohérent avant" {[Affiche]}
    F "G1 : Remove All separators" RemoveAllSeparators
    V "G1 : séparateurs retirés (sauf premier et dernier)" {[Seps] <= 2} [Seps]
    V "G1 : noms affichés = liste des séquences" {[Affiche]}
    V "G1 : instance marquée modifiée" {[Q VueEditee]}
    V "G1 : un seul groupe" {[Q {set ::LNDG}] eq "GroupeToutLeMonde"} [Q {set ::LNDG}]
    Inv "G1"
    F "G1 : Add sequences (fichier)" "AjouteSequenceOrPDB seqfile; set ::TAddS(SeqFileIn) $Donnees/G_ajout.tfa; .was.fbut.ok invoke" 600000
    Inv "G1 : après Add sequences"
    AllerRetour "G1"
    Stop

    puts "=== G4"
    Start $Test/T_tutorial_maj.ord
    F "G4 : conservation" {ChangeMode conservation; set ::Cons(Method) Threshold; set ::Cons(Title) g4; LanceCalculConservation; SauveConservation; QuitteModeConservation $::FrmBouton.cons} 300000
    F "G4 : Remove All separators" RemoveAllSeparators
    AllerRetour "G4"
    Stop

    puts "=== G3"
    Start $Test/R_tutorial_maj.ord
    set g0 [Q {set ::LNDG}]
    F "G3 : clustering" {ChangeMode cluster; foreach k [array names ::Clus LCrit,*] {set ::Clus($k) 0}; set ::Clus(LCrit,length) 1; set ::Clus(Method) "hierarchic / secator"; NouveauClustering; ChangeMode feature} 300000
    V "G3 : instance marquée modifiée" {[Q VueEditee]}
    V "G3 : feature de conservation retirée" {[Q {lsearch -all -inline $::ListeTypesDeFeatures Cons-*}] eq ""}
    AllerRetour "G3"
    V "G3 : pas de conservation recréée" {[Q {lsearch -all -inline $::ListeTypesDeFeatures Cons-*}] eq ""} [Q {lsearch -all -inline $::ListeTypesDeFeatures Cons-*}]
    Stop

    puts "=== G6"
    Start $Test/T_tutorial_maj.ord
    Sel {3 4}
    F "G6 : Re-align" ReAlignSeqs 600000
    V "G6 : instance marquée modifiée" {[Q VueEditee]}
    AllerRetour "G6"
    Stop

    puts "=== G7"
    Start $Test/T_tutorial_maj.ord
    # sélection restée d'une autre instance, qui désigne ici un séparateur (marche 78) :
    # l'interface ne laisse pas sélectionner un séparateur seul
    set y [lindex [Q {lsearch -all -regexp $::LNOrdali {^\s*$}}] 1]
    Q "set ::NomSeqSel [list [expr {$y + 1}].0]"
    set r [F "G7 : Re-align d'un séparateur" ReAlignSeqs 120000]
    V "G7 : message" {[string match "*at least one sequence*" [Dialogues $r]]} [Dialogues $r]
    V "G7 : Please Wait fermée" {! [Q {winfo exists .fattendre}]}
    Stop

    puts "=== G8"
    Start $Test/R_tutorial_maj.ord
    set n [Q {llength $::LNOrdali}]
    Sel [list [expr {$n - 1}]]
    F "G8 : Remove All separators" RemoveAllSeparators
    V "G8 : sélection vidée après Remove All separators" {[Q {set ::NomSeqSel}] eq ""} [Q {set ::NomSeqSel}]
    Sel {3}
    F "G8 : changement d'instance" {probe::answer tk_dialog 0; MiseAJourMac x {M2 - macsims alignment}}
    V "G8 : sélection vidée au changement d'instance" {[Q {set ::NomSeqSel}] eq ""} [Q {set ::NomSeqSel}]
    # sélection hors de l'alignement (Ordalie se fermait)
    Q "set ::NomSeqSel [list [expr {$n + 40}].0]"
    set r [F "G8 : ajout d'un séparateur hors de l'alignement" AddSpaceSeq]
    V "G8 : message" {[string match "*select one sequence*" [Dialogues $r]]} [Dialogues $r]
    V "G8 : Ordalie répond encore" {[Q {expr 1}] == 1}
    Inv "G8"
    Stop

    puts "=== G5"
    Start $Test/R_tutorial_maj.ord
    set cif "AjouteSequenceOrPDB pdbfile; set ::TAddS(StrucFileIn) $Donnees/AF-Q3KRD0-F1-model_v6.cif; .was.fbut.ok invoke"
    F "G5 : ajout de la structure" $cif 300000
    F "G5 : passage en M1" {probe::answer tk_dialog 0; MiseAJourMac x {M1 - original alignment}}
    F "G5 : sauvegarde et réouverture" "SauveLAlignement ORD $Tmp/g5.ord; FermeFichier nosave; OuvrirFichierAlignementDansOrdali Unk $Tmp/g5.ord" 600000
    F "G5 : nouvel ajout de la structure en M1" $cif 300000
    V "G5 : structure dans HashPDB" {[Q {info exists ::HashPDB(Q3KRD0)}]}
    F "G5 : viewer et objet" {VisualiseStructure; set m [lindex $::Liste3dMol 0]; DefineNewObj $m {}; set ::NwOj(Obj) g5; foreach e [array names ::NwOjR] {lset ::NwOjR($e) 1 7; lset ::NwOjR($e) 2 blue}; FinNewObj ok; QuitteViandox} 300000
    Inv "G5"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
