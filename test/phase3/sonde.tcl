# Phase 3 du plan de tests : contrôles exécutés DANS l'instance d'Ordalie (sourcé par le banc).
#   ::P3::Invariants        -> liste des violations (vide si tout va bien)
#   ::P3::Empreinte         -> dict de l'état de l'instance (alignement) courante
#   ::P3::EmpreinteFichier  -> dict instance -> empreinte, pour toutes les instances
namespace eval ::P3 {}

proc ::P3::Noms {} {
    if {! [info exists ::LNOrdali]} {return {}}
    lmap n $::LNOrdali {set n [string trim $n]; expr {$n eq "" ? [continue] : $n}}
}

# structures (objets) dont la chaîne est celle d'une séquence de l'instance
proc ::P3::NomsStructures {} {
    set Lo [info class instances Structure]
    set r {}
    foreach n [Noms] {
	if {[catch {set mol [DonneIdDeAccessPDB $n]; set chn [DonneChainDeAccessPDB $n]}]} continue
	if {"::$mol" ni $Lo} continue
	if {[catch {::$mol _chains} Lc] || $chn ni $Lc} continue
	lappend r $n
    }
    return $r
}

proc ::P3::DbStruct {o} {
    set v [info object namespace $o]::db
    expr {[info exists $v] ? [set $v] : ""}
}

proc ::P3::Invariants {} {
    set V {}
    if {[TypeAli] eq "pasdali"} {
	if {[llength [info class instances Structure]]} {
	    lappend V "I6 structures sans fichier ouvert : [info class instances Structure]"
	}
	return $V
    }
    set Noms [Noms]
    # I1, I2 : ListePDB = les structures de l'instance
    if {! [info exists ::ListePDB]} {
	lappend V "I1 ListePDB absente"
    } else {
	set Lp [lmap e $::ListePDB {lindex $e 0}]
	foreach n $Lp {
	    if {$n ni $Noms} {lappend V "I1 $n dans ListePDB mais pas dans l'instance"}
	}
	foreach n [NomsStructures] {
	    if {$n ni $Lp} {lappend V "I2 structure $n de l'instance absente de ListePDB"}
	}
	# I3 : noms colorés (tag PDB)
	if {[ModeI] && ! [catch {$::NomNomSeq tag ranges PDB} Lr]} {
	    # Biotext n'a pas de "get" : le tag couvre des lignes, ligne y = nom y-1
	    set Lv [expr {[InSeqlabMode] ? $::LNSeqlab : $::LNOrdali}]
	    set Ltag {}
	    foreach {a b} $Lr {
		lappend Ltag [string trim [lindex $Lv [expr {int($a)-1}]]]
	    }
	    foreach n $Lp {
		if {$n ni $Ltag} {lappend V "I3 $n de ListePDB sans couleur PDB"}
	    }
	}
    }
    # I4 : séquences cohérentes
    if {[llength $::LNOrdali] != [llength $::LSOrdali]} {
	lappend V "I4 LNOrdali ([llength $::LNOrdali]) et LSOrdali ([llength $::LSOrdali]) de longueurs différentes"
    }
    set Ll [lsort -unique [lmap s $::LSOrdali {expr {$s eq "" ? [continue] : [string length $s]}}]]
    if {[llength $Ll] > 1} {lappend V "I4 séquences de longueurs différentes : $Ll"}
    foreach n $Noms {
	if {! [info exists ::Sequences($n)]} {lappend V "I4 Sequences($n) absente"}
    }
    # I5 : Please Wait fermée quand rien ne tourne
    set tourne 0
    if {[namespace exists ::probe] && [info exists ::probe::A]} {
	foreach {k v} [array get ::probe::A] {if {[dict get $v state] eq "running"} {set tourne 1}}
    }
    if {! $tourne} {
	if {[winfo exists .fattendre]} {lappend V "I5 Please Wait encore ouverte"}
	if {[info exists ::TFAt(WtLabel)] && ! [winfo exists $::TFAt(WtLabel)]} {lappend V "I5 TFAt(WtLabel) sans fenêtre"}
    }
    # I7, I8 : bases sqlite sans transaction ouverte, objets 3D dans le dictionnaire et dans la base
    if {! $tourne} {
	if {[info exists ::db] && [info commands $::db] ne "" && [TransactionOuverte $::db]} {
	    lappend V "I8 transaction ouverte dans la base principale"
	}
	foreach o [info class instances Structure] {
	    set db [DbStruct $o]
	    if {$db eq "" || [info commands $db] eq ""} {lappend V "I8 $o sans base"; continue}
	    if {[TransactionOuverte $db]} {lappend V "I8 transaction ouverte dans la base de $o"}
	    if {[catch {lsort [$o _ListeObjets]} Ld]} continue
	    set Lt [lsort [$db eval {select name from sqlite_master where type='table' and name glob 'obj_*'}]]
	    foreach x $Ld {if {$x ni $Lt} {lappend V "I7 objet $x de $o sans table"}}
	    # (une table sans objet est normale : les objets d'un ORD ne sont
	    # chargés qu'à l'ouverture du viewer, LoadObjFromDB)
	}
    }
    return $V
}

# transaction ouverte ? (l'interface Tcl de sqlite n'expose pas autocommit)
proc ::P3::TransactionOuverte {db} {
    if {[catch {$db eval {BEGIN}} m]} {return [string match "*within a transaction*" $m]}
    $db eval {ROLLBACK}
    return 0
}

proc ::P3::Crc {s} {format %08x [zlib crc32 $s]}

proc ::P3::Empreinte {} {
    set E [dict create]
    set m [MacCourant]
    dict set E instance [MacCourant name]
    catch {dict set E description [DescriptionDuMac]}
    set Noms [Noms]
    dict set E noms $Noms
    dict set E seqs [Crc [lmap n $Noms {set ::Sequences($n)}]]
    dict set E features [lsort $::ListeTypesDeFeatures]
    foreach f [lsort $::ListeTypesDeFeatures] {
	set L {}
	foreach k [lsort [array names ::TabSF "*,$f"]] {lappend L $k $::TabSF($k)}
	dict set E "feature $f" [Crc $L]
    }
    if {[info exists ::LNDG]} {
	dict set E groupes [lmap g $::LNDG {expr {$g in {bidon grise} ? [continue] : $g}}]
	foreach g [dict get $E groupes] {
	    if {[info exists ::SDG($g)]} {dict set E "groupe $g" [lsort $::SDG($g)]}
	}
    }
    dict set E ListePDB [lsort [lmap e $::ListePDB {lindex $e 0}]]
    # structures : coordonnées (superposition comprise), structures secondaires, objets 3D
    foreach n [lsort [dict get $E ListePDB]] {
	set o ::[DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	if {[info commands $o] eq ""} {dict set E "structure $n" absente; continue}
	set db [DbStruct $o]
	dict set E "coordonnées $n" [$db eval {select count(*), round(sum(a.x),1), round(sum(a.y),1), round(sum(a.z),1)
	    from atoms a, residues r, chains c where a.pk_residues = r.pk_residues and r.pk_chains = c.pk_chains and c.name = $chn}]
	set ns [info object namespace $o]
	foreach v {SecStr} {
	    if {[array exists ${ns}::$v]} {
		dict set E "$v $n" [Crc [lsort -stride 2 [concat {*}[lmap {k x} [array get ${ns}::$v] {expr {[string match "$chn*" $k] ? [list $k $x] : [continue]}}]]]]
	    }
	}
	# objets 3D gardés dans la base (le dictionnaire n'est rempli qu'à l'ouverture du viewer)
	dict set E "objets $o" [lsort [$db eval {select name from sqlite_master where type='table' and name glob 'obj_*'}]]
    }
    # arbres de l'instance : coordonnées du dessin
    if {[info exists ::Abr(Liste)]} {
	foreach a $::Abr(Liste) {
	    if {! [info exists ::Abr($a,Mac)] || $::Abr($a,Mac) != $m} continue
	    set c [expr {[info exists ::Abr($a,PAD)] ? $::Abr($a,PAD) : ""}]
	    set d absent
	    if {$c ne "" && [winfo exists $c]} {
		set d [Crc [lmap i [$c find all] {lmap x [$c coords $i] {format %.0f $x}}]]
	    }
	    dict set E "arbre $a" [list $::Abr($a,TypeTree) [llength [$::Abr(Arbre,$a) leaves]] $d]
	}
    }
    return $E
}

proc ::P3::EmpreinteFichier {} {
    set m0 [MacCourant name]
    set R [dict create]
    foreach m [LesMacs] {
	if {$m ne [MacCourant name]} {MiseAJourMac x $m}
	# contrôles d'état sur chaque instance affichée (C1 et C6 n'apparaissaient qu'au changement d'instance)
	dict set R $m [dict merge [Empreinte] [dict create invariants [Invariants]]]
    }
    if {$m0 ne [MacCourant name]} {MiseAJourMac x $m0}
    return $R
}
