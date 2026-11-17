# Phase 3 : chaque contrôle de la sonde doit échouer quand on provoque le défaut qu'il surveille.
# Usage : tclsh8.6 test/phase3/sensibilite_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
source [file join [file dirname [file normalize [info script]]] commun.tcl]

proc Provoque {tag code motif {defait ""}} {
    W::ask $code
    set v [W::ask ::P3::Invariants]
    V "$tag : détecté" {[lsearch -glob $v $motif] >= 0} [join $v " ; "]
    if {$defait ne ""} {W::ask $defait}
    Inv "$tag : retour à la normale"
}

if {[catch {
    Start $Test/I_maj.xml
    Inv "ouverture"
    Provoque "I1 nom inconnu dans ListePDB" {lappend ::ListePDB XXXX_A} "I1 *" {set ::ListePDB [lrange $::ListePDB 0 end-1]}
    Provoque "I2 structure hors de ListePDB" {set ::GardePDB $::ListePDB; set ::ListePDB [lrange $::ListePDB 1 end]} "I2 *" {set ::ListePDB $::GardePDB}
    Provoque "I3 nom non coloré" {$::NomNomSeq tag remove PDB} "I3 *" {RepeintNomsEtSeqs; list}
    Provoque "I4 séquence de longueur différente" {lset ::LSOrdali 1 "[lindex $::LSOrdali 1]X"} "I4 *" {lset ::LSOrdali 1 [string range [lindex $::LSOrdali 1] 0 end-1]}
    Provoque "I5 Please Wait restée ouverte" {FaireAttendre "test"} "I5 *" {FaireLaSuite}
    Provoque "I5 Please Wait détruite sans FaireLaSuite" {FaireAttendre "test"; destroy .fattendre} "I5 *" {unset -nocomplain ::TFAt; list}
    Provoque "I8 transaction ouverte (base principale)" {$::db eval {BEGIN}} "I8 *" {$::db eval {ROLLBACK}}
    set mol [W::ask {lindex [info class instances Structure] 0}]
    Provoque "I8 transaction ouverte (structure)" "\[::P3::DbStruct $mol\] eval {BEGIN}" "I8 *" "\[::P3::DbStruct $mol\] eval {ROLLBACK}"
    F "viewer" VisualiseStructure
    for {set i 0} {$i < 100 && ! [W::ask {winfo exists .ordogl}]} {incr i} {after 200}
    Inv "viewer ouvert"
    set o [W::ask "lindex \[$mol _ListeObjets\] 0"]
    Provoque "I7 objet sans table" "\[::P3::DbStruct $mol\] eval {alter table $o rename to zz_test}" "I7 *" "\[::P3::DbStruct $mol\] eval {alter table zz_test rename to $o}"
    F "fermeture du fichier" {FermeFichier nosave}
    Inv "fichier fermé"
    Provoque "I6 structure restée après Close" {Structure create ::ZZTEST} "I6 *" {::ZZTEST destroy}
    # empreinte : sensible à un changement de coordonnées, de feature et de groupe
    F "réouverture" [list OuvrirFichierAlignementDansOrdali Unk $Test/I_maj.xml] 300000
    set E0 [W::ask ::P3::Empreinte]
    set n [lindex [dict get $E0 ListePDB] 0]
    set m [W::ask [list DonneIdDeAccessPDB $n]]
    set chn [W::ask [list DonneChainDeAccessPDB $n]]
    W::ask "\[::P3::DbStruct ::$m\] eval {update atoms set x = x + 1 where pk_atoms = (select min(a.pk_atoms) from atoms a, residues r, chains c where a.pk_residues = r.pk_residues and r.pk_chains = c.pk_chains and c.name = '$chn')}"
    set f [lindex [dict get $E0 features] 0]
    W::ask "set k \[lindex \[array names ::TabSF *,$f\] 0\]; set ::TabSF(\$k) {}"
    W::ask {lappend ::SDG(Group1) ZZ}
    set E1 [W::ask ::P3::Empreinte]
    foreach k [list "coordonnées $n" "feature $f" "groupe Group1"] {
	V "empreinte : $k change" {[dict get $E0 $k] ne [dict get $E1 $k]}
    }
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
