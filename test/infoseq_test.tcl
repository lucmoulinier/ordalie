# Test du menu Sequences > Edit Seq. information (fenêtre « Sequence Information », 2026-11-09) :
#  - la fenêtre s'ouvre et affiche chaque séquence de chaque instance (liste déroulante), sans erreur ;
#  - champs modifiés (access, organisme, domaine, E.C., Taxa Id, description avec ' " { }, champ vidé) :
#    gardés en mémoire, puis après sauvegarde ORD et réouverture (étaient perdus sans renommage) ;
#  - nouveau Sequence Name : affiché, et gardé après réouverture ;
#  - valeurs refusées (E.C. mal formé, Taxa Id non entier, nom vide, nom déjà pris) : message, ancienne valeur.
# Usage : tclsh8.6 test/infoseq_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Champ {n t} {Q "expr {\[info exists ::${t}($n)\] ? \$::${t}($n) : {ABSENT}}"}
# ouvre la fenêtre sur la ligne y (1 = premier séparateur)
proc Ouvre {y} {F "ouverture sur la ligne $y" "set ::PosInitNom 1.0; SelectNomSeq une $y.0; SequencesInformation" 30000}
proc Ferme {} {F "Close" {.infoseq.f.btn.ok invoke} 30000}
set Desc {description "modifiée" l'été {accolade} [crochet] $dollar}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    puts "=== chaque séquence de chaque instance"
    foreach m [Q LesMacs] {
	F "instance $m" [list MiseAJourMac x $m] 120000
	Ouvre 2
	set nb [Q {llength [.infoseq.f.top.seq cget -values]}]
	set err [Q {
	    set r {}
	    for {set i 0} {$i < [llength [.infoseq.f.top.seq cget -values]]} {incr i} {
		.infoseq.f.top.seq current $i
		if {[catch {GetInfoOfSeq .infoseq.f.top.seq} e]} {lappend r "[.infoseq.f.top.seq get] : $e"}
	    }
	    set r
	}]
	V "[lindex $m 0] : les $nb séquences s'affichent" {$err eq ""} [lrange $err 0 2]
	V "[lindex $m 0] : une séquence par ligne de l'alignement" {$nb == [Q {llength [lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : 1}}]}]} $nb
	Ferme
    }
    F "retour en M4" {MiseAJourMac x {M4 - mito-extended}} 120000

    puts "=== modification sans renommage"
    set a [Q {string trim [lindex $::LNOrdali 5]}]
    set org0 [Champ $a TDesOrganismes]
    Ouvre 6
    V "séquence affichée : celle sélectionnée" {[Q {set ::TEdit(seqname)}] eq $a} [Q {set ::TEdit(seqname)}]
    Q [list set ::Desc $Desc]
    Q {set ::TEdit(orga) "Homo sapiens"; set ::TEdit(lifed) Bacteria; set ::TEdit(ec) 6.1.1.3; set ::TEdit(taxid) 9606; set ::TEdit(access) ""; set ::TEdit(bid) BID_1; $::TEdit(tdes) delete 1.0 end; $::TEdit(tdes) insert end $::Desc}
    Ferme
    set Attendu [list {Homo sapiens} Bacteria 6.1.1.3 9606 {} BID_1 $Desc]
    set Lt {TDesOrganismes TDesPhylum TDesEC TDesTaxId TDesAccess TDesBId TDesDescriptifs}
    V "$a : modifié en mémoire" {[lmap t $Lt {Champ $a $t}] eq $Attendu} [lmap t $Lt {Champ $a $t}]
    V "$a : nom inchangé" {[Champ $a TDesSeqnames] eq $a}

    puts "=== renommage"
    set b [Q {string trim [lindex $::LNOrdali 3]}]
    Ouvre 4
    Q {set ::TEdit(seqname) Nouveau_nom; set ::TEdit(orga) "Mus musculus"}
    Ferme
    V "$b renommé : nom affiché" {[Q {string trim [lindex [$::NomNomSeq output all] 3]}] eq "Nouveau_nom"} [Q {string trim [lindex [$::NomNomSeq output all] 3]}]
    V "instance marquée modifiée" {[Q VueEditee]}

    puts "=== valeurs refusées"
    set c [Q {string trim [lindex $::LNOrdali 6]}]
    set ec0 [Champ $c TDesEC]; set tx0 [Champ $c TDesTaxId]
    Ouvre 7
    Q {set ::TEdit(ec) 6.1.x; set ::TEdit(taxid) 12a}
    set r [Ferme]
    V "E.C. mal formé : message" {[string match "*E.C. number*badly formatted*" [Dialogues $r]]} [Dialogues $r]
    V "Taxa Id non entier : message" {[string match "*Taxa Id*integer*" [Dialogues $r]]} [Dialogues $r]
    V "$c : E.C. et Taxa Id inchangés" {[Champ $c TDesEC] eq $ec0 && [Champ $c TDesTaxId] eq $tx0} "[Champ $c TDesEC] [Champ $c TDesTaxId]"
    Ouvre 7
    Q {set ::TEdit(seqname) ""}
    set r [Ferme]
    V "nom vide : message" {[string match "*can not be empty*" [Dialogues $r]]} [Dialogues $r]
    Ouvre 7
    Q [list set ::TEdit(seqname) $a]
    set r [Ferme]
    V "nom déjà pris : message" {[string match "*already exists*" [Dialogues $r]]} [Dialogues $r]
    V "$c : nom inchangé" {[Champ $c TDesSeqnames] eq $c} [Champ $c TDesSeqnames]
    Inv "après les modifications"

    puts "=== sauvegarde et réouverture"
    F "sauvegarde ORD" [list SauveLAlignement ORD $Tmp/i.ord]
    Stop
    Start $Tmp/i.ord
    V "$a : modifications gardées" {[lmap t $Lt {Champ $a $t}] eq $Attendu} [lmap t $Lt {Champ $a $t}]
    V "Nouveau_nom : à la ligne 4" {[Q {string trim [lindex $::LNOrdali 3]}] eq "Nouveau_nom"} [Q {string trim [lindex $::LNOrdali 3]}]
    V "Nouveau_nom : organisme gardé" {[Champ Nouveau_nom TDesOrganismes] eq "Mus musculus"} [Champ Nouveau_nom TDesOrganismes]
    V "$c : E.C. inchangé" {[Champ $c TDesEC] eq $ec0} [Champ $c TDesEC]
    Ouvre 6
    V "fenêtre : description relue" {[Q {string trim [$::TEdit(tdes) get 1.0 end]}] eq $Desc} [Q {$::TEdit(tdes) get 1.0 end}]
    Ferme
    Inv "réouverture"
    F "instance M2" {MiseAJourMac x {M2 - macsims alignment}} 120000
    V "M2 : $b garde son nom" {[lsearch [Q {lmap n $::LNOrdali {string trim $n}}] $b] >= 0}
    Inv "M2"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
