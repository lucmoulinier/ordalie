# --- ordali_pdb.tcl
#

proc SelectSSDeType {type} {
    global PositionInitiale ListePDB NomNomSeq NomTextSeq
    
    # colonnes ou toutes les chaines (ayant une structure
    # secondaire definie) sont dans un element de type $type
    set final ""
    set LSansSS {}
    foreach elt $ListePDB {
	lassign $elt MolId PDB
	set chn [DonneChainDeAccessPDB $MolId]
	if {$chn eq ""} {set chn "a"}
	set Mol [DonneIdDeAccessPDB $MolId]
	
	set lss [$Mol SSBin $type $chn]
	# pas de structure secondaire pour cette chaine
	if {$lss eq "" || [string first 1 $lss] == -1} {
	    lappend LSansSS $MolId
	    continue
	}
	
	if {$final eq ""} {
	    set final $lss
	} else {
	    set tmp ""
	    foreach a [split $final ""] b [split $lss ""] {
		if {$a eq ""} {set a 0}
		if {$b eq ""} {set b 0}
		append tmp [expr {$a & $b}]
	    }
	    set final $tmp
	}
    }
    if {$LSansSS ne {}} {
	puts "SelectSSDeType $type : no $type in [join $LSansSS]"
    }
    if {$final eq ""} {
	FaireLire "No structure has $type secondary structure elements !"
	return
    }
    
    # selectionne chaque segment [d,f] (bornes incluses)
    append final 0
    set d -1
    set i 0
    foreach e [split $final ""] {
	if {$e} {
	    if {$d == -1} {set d $i}
	} elseif {$d != -1} {
	    set PositionInitiale "1.$d"
	    SelectLesColonnes "1.[expr {$i-1}]"
	    set d -1
	}
	incr i
    }
    
    return
}


proc MetDesUnsDansSS {str deb fin} {

    set lesuns [string repeat "1" [expr {$fin-$deb+1}]]
    set mod [string replace $str $deb $fin $lesuns]

    return $mod
}


proc DecortiqueSS {ss aElt aNomChnDep aNomResDep aNomResFin aRmk} {
    upvar $aElt Elt $aNomChnDep NomChnDep $aNomResDep NomResDep $aNomResFin NomResFin $aRmk Rmk
   
    set sstype [string range $ss 0 3]
    switch $sstype {
	"Heli" {
	    lassign $ss Elt Type HelNm NomChnDep NomResDep TypResDep NomResFin TypResFin LongHel 
	    set Elt $Type
	    # ORD files saved before 2026-11-04 (AlphaFold models)
	    if {$Elt eq "helix"} {set Elt "Alpha"}
	    set Rmk "$HelNm"
	}
	"Shee" {
	    set SensStrd 0
	    lassign $ss Elt SheetID StrandID NomChnDep NomResDep TypResDep NomResFin TypResFin SensStrd 
	    if {$SensStrd < 0} {
		set Rmk "-$StrandID"
	    } else {
		set Rmk "$StrandID"
	    }
	}
	"Turn" {
	    lassign $ss Elt tmp TurnNm NomChnDep NomResDep TypResDep NomResFin TypResFin 
	    set Rmk " "
	}
	"Coil" {
	    lassign $ss Elt a d NomChnDep NomResDep d NomResFin 
	    set Rmk " "
	}
    }
    
    return
}


proc LitHelixDansPDB {laligne {chaine ""}} {
    # Numerotation format PDB commence a 1 et TCL a 0.
    # Rajoute un blanc en debut de ligne pour avoir coherence
    set laligne " $laligne"

    set HelNm [string range $laligne  8 10]
    set HelID [string range $laligne 12 14]
    
    set TypResDep [string range $laligne 16 18]
    set NomChnDep [string range $laligne 20 20]
    set NomResDep [string range $laligne 22 25]
    
    set TypResFin [string range $laligne 28 30]
    set NomChnFin [string range $laligne 32 32]
    set NomResFin [string range $laligne 34 37]
    
    set ClassHel  [string range $laligne 39 40]
    set LongHel   [string range $laligne 72 76]
    
    switch $ClassHel {
	1  {set Type "Alpha"}
	3  {set Type "Pi"}
	5  {set Type "3_10"}
	10 {set Type "polyP"}
	default {set Type "Alpha"}
    }
    
    if {$NomChnDep eq $chaine || $chaine eq ""} {
	return "Helix $Type $HelNm $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin $LongHel"
    } else {
	return "PasBon"
    }
}


proc LitSheetDansPDB {laligne {chaine ""}} {
    # Numerotation format PDB commence a 1 et TCL a 0.
    # Rajoute un blanc en debut de ligne pour avoir coherence
    set laligne " $laligne"
    
    set StrandID  [string range $laligne  8 10]
    set SheetID   [string range $laligne 12 14]
    set NbStrd    [string range $laligne 15 16]
    
    set TypResDep [string range $laligne 18 20]
    set NomChnDep [string range $laligne 22 22]
    set NomResDep [string range $laligne 23 26]
    
    set TypResFin [string range $laligne 29 31]
    set NomChnFin [string range $laligne 33 33]
    set NomResFin [string range $laligne 34 37]
    
    set SensStrd  [string range $laligne 39 40]
    
    if {$NomChnDep ne $NomChnFin} {
	set NomChnDep "cesttroplebordel"
    }
    
    if {$NomChnDep == $chaine || $chaine == ""} {
	return "Sheet $SheetID $StrandID $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin $SensStrd"
    } else {
	return "PasBon"
    }
    
}


proc LitTurnDansPDB {laligne {chaine ""}} {
    # Numerotation format PDB commence a 1 et TCL a 0.
    # Rajoute un blanc en debut de ligne pour avoir coherence
    set laligne " $laligne"
    
    set TurnNm [string range $laligne  8 10]
    
    set TypResDep [string range $laligne 16 18]
    set NomChnDep [string range $laligne 20 20]
    set NomResDep [string range $laligne 21 24]
    
    set TypResFin [string range $laligne 27 29]
    set NomChnFin [string range $laligne 31 31]
    set NomResFin [string range $laligne 32 35]
    
    if {$NomChnDep eq $chaine || $chaine eq ""} {
	return "Turn XXX $TurnNm $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin"
    } else {
	return "PasBon"
    }
}


proc ExtraitBornesDesSS {ref} {
    global Sequences ListePDB
    
    set liste {}
    set idx [lsearch -index 0 $ListePDB $ref]
    set n [lindex $ListePDB $idx]
    lassign $n MolCh fnom
    set chn   [DonneChainDeAccessPDB $MolCh]
    set MolId [DonneIdDeAccessPDB $MolCh]
    if {$chn eq ""} {set chn "a"}    
    set nom [BonAccess ${MolId}_$chn]

    global PDB_[set MolId]_SecStr
    
    set SeqAss [set Sequences($nom)]
    
    foreach ss [set PDB_[set MolId]_SecStr($chn)] {
	DecortiqueSS $ss Elt NomChnDep NomResDep NomResFin Rmk
	if {$Elt eq "Coil"} {continue}
	set DebAli [CorrespondancePDBGen $nom $NomResDep]
	set FinAli [CorrespondancePDBGen $nom $NomResFin]

	lappend liste [list $Elt $DebAli $FinAli $NomResDep $NomResFin]
    }

    return $liste
}


proc RecupereSecStrDeFeature {pdbid} {
    global Sequences TabSF
    
    set Bpid [BonAccess $pdbid]
    set pid  [DonneIdDeAccessPDB $Bpid]
    set chn  [DonneChainDeAccessPDB $pdbid]
    global PDB_[set pid]_SecStr
    
    set seq [set Sequences($Bpid)]
    regsub -all {\.} $seq "" seq
    set nH 1
    set nS 1
    set nT 1
    set SStmp {}
    foreach e [array names TabSF -regexp ",STRUCT"] {
	lassign [split $e ,] n f 
	if {! [regexp -nocase $n $Bpid]} {continue}
	if {$f != "STRUCT"} {continue}
	
	foreach ft [set TabSF($e)] {
	    DecortiqueUneFeature $ft dg fg col score note
	    set lg [expr {$fg - $dg + 1}]
	    set nrd [string index $seq $dg]
	    set nrf [string index $seq $fg]
	    
	    set ss "pasbon"
	    switch $note {
		"HELIX"  {
		    set ss "Helix Alpha $nH $chn $dg $nrd $fg $nrf $lg"
		    incr nH
		}
		"STRAND" {
		    set ss "Sheet 1 $nS $chn $dg $nrd $fg $nrf 1"
		    incr nS
		}
		"TURN"   {
		    set ss "Turn XXX $nT $chn $dg $nrd $fg $nrf"
		    incr nT
		}
	    }
	    if {$ss != "pasbon"} {lappend SStmp $ss}
	}
    }
    
    set PDB_[set pid]_SecStr($chn) [CombleSSParCoil $SStmp $pid $chn]
    
    return
}


proc ExtraitSecStrucDuPDB {Fichier {mol "TRUC"}} {
    set MolId [DonneIdDeAccessPDB $mol]
    set chn   [DonneChainDeAccessPDB $mol]
    if {$chn eq ""} {set chn "a"}
    
    global PDB_[set MolId]_SecStr
    global PDB_[set MolId]_SSBin
    global PDB_[set MolId]_Header
    global PDB_[set MolId]_ChnIdn
    
    set LesLignes [set PDB_[set MolId]_Header]
    foreach chn [set PDB_[set MolId]_ChnIdn] {
	set ssbh [string repeat "0" [LongueurAlignement]]
	set ssbs [string repeat "0" [LongueurAlignement]]
	
	set SStmp {}
	set lhelix "PasBon"
	foreach l $LesLignes {
	    set t [string range $l 0 4]
	    switch $t {
		"HELIX" {set lhelix [LitHelixDansPDB $l $chn]}
		"SHEET" {set lhelix [LitSheetDansPDB $l $chn]}
		"TURN " {set lhelix [LitTurnDansPDB  $l $chn]}
		default {continue}
	    }
	    if {$lhelix eq "PasBon"} {continue}

	    set ss [OteLesBlancsEnTrop $lhelix]	    
	    DecortiqueSS $ss Elmt NomChnDep NomResDep NomResFin Rmk
	    set DebAli [CorrespondancePDBGen $mol $NomResDep]
	    set FinAli [CorrespondancePDBGen $mol $NomResFin]
	    
	    lappend SStmp $ss
	    
	    switch $Elmt {
		"Alpha" {
		    set ssbh [MetDesUnsDansSS $ssbh $DebAli $FinAli]
		}
		"Sheet" {
		    set ssbs [MetDesUnsDansSS $ssbs $DebAli $FinAli]
		}
	    }
	}
	
	set SStmp [lsort -integer -index 4 $SStmp]
	set SStmp [CombleSSParCoil $SStmp $MolId $chn]
	set PDB_[set MolId]_SecStr($chn) $SStmp
	
	set PDB_[set MolId]_SSBin($chn) $ssbh
	lappend PDB_[set MolId]_SSBin($chn) $ssbs
    }
    
    return
}


proc ExtraitLignesAtomesDuPDB {LesLignesTmp} {
    set LesLignes {}
    
    # NMR structure --> PREND 1er MODELE !!
    set lafin "END"
    set idx [lsearch -regexp $LesLignesTmp "EXPDTA"]
    if {$idx != -1} {
	set ya [string first "NMR" [lindex $LesLignesTmp $idx]]
	if {$ya != -1} {
	    set lafin "ENDMDL"
	}
    }
    
    # Read atoms
    # Keep only the first model is there are several
    set isModel 0
    foreach l $LesLignesTmp {
	if {[regexp {^MODEL } $l]} {
	    if {$isModel} {
		break
	    } else {
		set isModel 1
	    }
	}
	    if {[regexp "^${lafin}" $l]} {break}
	#	if {[regexp {^TER} $l]} {continue}
	if {[regexp {^ATOM|^HETATM|^TER} $l]} {lappend LesLignes $l}
    }
    
    if {[llength $LesLignes] == 0} {
	FaireLire "I can't find the ATOM record in your PDB file !"
    }
    
    return $LesLignes
}


proc ExtraitHeadDuPDB LesLignesTmp {
    
    set head {}
    set i 0
    set iLA1 -1
    set iLA2 -1
    foreach l $LesLignesTmp {
	set IdxAtom [string first "ATOM " $l]
	if {$IdxAtom == -1} {
	    if {[string first "HETATM" $l] != -1} {set iLA1 $i}
	    if {[string first "MSE" $l]    != -1} {set iLA2 $i}
	}
	
	if {$IdxAtom == -1 || $IdxAtom > 0} {
	    lappend head $l
	} else {
	    break
	}
	incr i
    }
    
    if {$i == [llength $LesLignesTmp]} {
	if {$iLA1 != -1} {
	    set head [lrange $head 0 [expr {$iLA1-1}]]
	}
    }
    
    return $head
}



proc ExtraitHeadDuPDB2 LesLignesTmp {
    
    set head {}
    set IAtm [lsearch -regexp $LesLignesTmp {^ATOM |^HETATM}]
    if {$IAtm == -1} {set IAtm "end"}
    set head [lrange $LesLignesTmp 0 $IAtm]
    
    return $head
}



proc ExtraitSiteActifDuPDB {lignes} {
    
    set ncou ""
    set lsite {}
    foreach l $lignes {
	set l " $l"
	if {[string range $l 1 6] != "SITE  "} {continue}
	# site name
	set ns [string trim [string range $l 12 14]]
	
	if {$ns != $ncou} {
	    if {$ncou != ""} {
		set site($ncou) $lsite
		set lsite {}
	    }
	}
	
	foreach i {0 1 2 3} {
	    set p [expr {$i * 11}]
	    set nm$i [string range $l 19+$p 21+$p]
	    set ch$i [string range $l 23+$p 23+$p]
	    set rn$i [string range $l 24+$p 27+$p]
	    set rn$i [string trim [set rn$i]]
	    if {[set rn$i] ne ""} {
		lappend lsite [set rn$i] [set ch$i] [set nm$i]
	    }
	}
	set ncou $ns
    }
    
    if {$lsite != {} } {set site($ncou) $lsite}
    
    set ltab {}
    if {[info exists site]} {set ltab [array get site]}
    
    return $ltab
}



proc LectureDeChainePDB {LesLignes MolId {Polymer 1}} {
    global PDB_[set MolId]_TypAtm
    global PDB_[set MolId]_NomAtm
    global PDB_[set MolId]_NomRes1l
    global PDB_[set MolId]_NomRes3l
    global PDB_[set MolId]_NmrRes
    global PDB_[set MolId]_ChnIdn
    global PDB_[set MolId]_AtmXYZ
    global PDB_[set MolId]_AtmBQ
    global PDB_[set MolId]_Sequence
    global PDB_[set MolId]_Header
    global PDB_[set MolId]_Site
    
    set Vraia 0
    set ChaineCourant -1
    set ResiduCourant -999
    set AlterLocRes ""
    set CC ""
    set PremRes 1
    set Latmn {}
    set Latmx {}
    set Latmb {}
    set Latmz {}

    foreach ligne $LesLignes {
	set ee " $ligne"
	set AtomName      [string range $ee 13 16]
	#	set AlterLocRes   [string index $ee 17]
	set NomRes3L      [string range $ee 18 20]
	set NomRes1L      [AutreCodeLuc $NomRes3L]
	scan              [string range $ee 23 27] "%s" ResidueNumber
	scan              [string range $ee 31 54] "%8f%8f%8f" x y z
	set AtomXYZ       [list $x $y $z]
	scan              [string range $ee 55 66] "%6f%6f" q b
	set AtomBQ        [list $b $q]
	set AtomNA        [NoAtomicDe [string trim [string range $ee 77 78]]]

	## ATTENTION !!
	# Cette version ne lit pas les hydrogenes !
	if {$AtomNA==1} {continue}
#	if {[regexp {^[0-9H]} [string trim $AtomName]]} {continue}

	set ChainIdent    [string index $ee 22]

	# if {$AlterLocRes ne ""} {continue}
	if {$ResiduCourant == -999} {
	    set ResiduCourant $ResidueNumber
	    set CC $ChainIdent
	}

	if {$ResidueNumber != $ResiduCourant} {
	    lappend PDB_[set MolId]_TypRes($CC) $Polymer
	    lappend PDB_[set MolId]_NomRes1l($CC) $N1LCou
	    lappend PDB_[set MolId]_NomRes3l($CC) $N3LCou
	    lappend PDB_[set MolId]_NmrRes($CC) $ResiduCourant
	    lappend PDB_[set MolId]_NomAtm($CC) $Latmn
	    lappend PDB_[set MolId]_AtmXYZ($CC) $Latmx
	    lappend PDB_[set MolId]_AtmBQ($CC)  $Latmb
	    lappend PDB_[set MolId]_AtmNA($CC)  $Latmz

	    set Latmn {}
	    set Latmx {}
	    set Latmb {}
	    set Latmz {}

	    if {$ChainIdent ne $ChaineCourant} {
		lappend PDB_[set MolId]_ChnIdn $ChainIdent
		set ChaineCourant $ChainIdent
		set CC $ChainIdent
	    }
	}

	lappend Latmn $AtomName
	lappend Latmx $AtomXYZ
	lappend Latmb $AtomBQ
	lappend Latmz $AtomNA

	set ResiduCourant $ResidueNumber
	set N3LCou $NomRes3L
	set N1LCou $NomRes1L
    }
    if { ! [info exists N1LCou]} { return 0 }
    #    lappend ChnIdn $CC
    lappend PDB_[set MolId]_TypRes($CC) $Polymer
    lappend PDB_[set MolId]_NomRes1l($CC) $N1LCou
    lappend PDB_[set MolId]_NomRes3l($CC) $N3LCou
    lappend PDB_[set MolId]_NmrRes($CC) $ResiduCourant
    lappend PDB_[set MolId]_NomAtm($CC) $Latmn
    lappend PDB_[set MolId]_AtmXYZ($CC) $Latmx
    lappend PDB_[set MolId]_AtmBQ($CC)  $Latmb
    lappend PDB_[set MolId]_AtmNA($CC)  $Latmz

    return $Vraia











    set PremiereChaine ""
    
    if {! [info exists PDB_[set MolId]_ChnIdn]} {
	set LdesC {}
    } else {
	set LdesC [set PDB_[set MolId]_ChnIdn]
    }
    
    set ChaineCourant -1
    set AtmTypCourant ""
    set NomResCourant ""
    set ResiduCourant -999
    set AlterLocRes ""
    set CC ""
    set PremRes 1
    set Latmn {}
    set Latmx {}
    set Latmb {}
    
    foreach ligne $LesLignes {
	set ee " $ligne"
	set AtmTyp        [string range $ee 1 4]
	set AtomName      [string range $ee 13 16]
	#	set AlterLocRes   [string index $ee 17]
	set ResidueName   [string range $ee 18 20]
	set ChainIdent    [string range $ee 22 22]
	
	if {$PremiereChaine eq ""} {set PremiereChaine $ChainIdent}
	
	scan              [string range $ee 23 27] "%s" ResidueNumber
	scan              [string range $ee 31 54] "%8f%8f%8f" x y z
	set AtomXYZ       [list $x $y $z]
	scan              [string range $ee 55 66] "%6f%6f" q b
	set AtomBQ        [list $b $q]
	
	# ATTENTION ! On ne prend pas les hydrogenes !
	if {[string index [string trim $AtomName] 0] eq "H"} {continue}
	
	if {[lsearch $LdesC $ChainIdent] != -1} {continue}
	#	if {$AlterLocRes ne ""} {continue}
	if {$ResiduCourant == -999} {
	    set ResiduCourant $ResidueNumber
	    set NomRes1L [AutreCodeLuc $ResidueName]
	    set CC $ChainIdent
	    set AtmTyp $AtmTyp
	}
	
	if {$ResidueNumber != $ResiduCourant} {
	    set NomRes1L [AutreCodeLuc $ResidueName]
	    lappend PDB_[set MolId]_NomRes($CC) $NomResCourant
	    lappend PDB_[set MolId]_NmrRes($CC) $ResiduCourant
	    lappend PDB_[set MolId]_TypAtm($CC) $AtmTypCourant
	    lappend PDB_[set MolId]_NomAtm($CC) $Latmn
	    lappend PDB_[set MolId]_AtmXYZ($CC) $Latmx
	    lappend PDB_[set MolId]_AtmBQ($CC)  $Latmb
	    
	    set Latmn {}
	    set Latmx {}
	    set Latmb {}
	    
	    if {$ChainIdent ne $ChaineCourant} {
		lappend PDB_[set MolId]_ChnIdn $ChainIdent
		set ChaineCourant $ChainIdent
		set CC $ChainIdent
	    }
	}
	
	lappend Latmx $AtomXYZ
	lappend Latmb $AtomBQ
	lappend Latmn $AtomName
	
	set AtmTypCourant $AtmTyp
	set ResiduCourant $ResidueNumber
	set NomResCourant $NomRes1L
    }
    
    #    lappend PDB_[set MolId]_ChnIdn $ChainIdent
    
    if {$NomResCourant ne "XXX"} {
	lappend PDB_[set MolId]_NomRes($CC) $NomResCourant
	lappend PDB_[set MolId]_NmrRes($CC) $ResiduCourant
	lappend PDB_[set MolId]_TypAtm($CC) $AtmTypCourant
	lappend PDB_[set MolId]_NomAtm($CC) $Latmn
	lappend PDB_[set MolId]_AtmXYZ($CC) $Latmx
	lappend PDB_[set MolId]_AtmBQ($CC)  $Latmb
    }
    
    return $Vraia
}


proc DecortiqueUnPDB {Fichier {LaMolId ""}} {
    global Defauts
    
    if {! [info exists Defauts]} {LesDefauts}
    if {[llength $Fichier] == 1} {
	if {! [regsub {\.} $Fichier "" tmp]} {
	    set lignes [RecupereUnFichierSurWeb $Fichier]
	} else {
	    set lignes [LesLignesDuFichier $Fichier]
	}
    } else {
	set lignes $Fichier
    }
    set MolId [DonneIdDeAccessPDB $LaMolId]
    
    set lignesPDB [ExtraitLignesAtomesDuPDB $lignes]
    if {$MolId eq ""} {set MolId [file rootname [file tail $Fichier]]}
    
    global PDB_[set MolId]_Header
    global PDB_[set MolId]_Site
    
    set Header [ExtraitHeadDuPDB $lignes]
    set PDB_[set MolId]_Header $Header
    
    if {[llength $lignesPDB] == 0} {return 0}
    
    # Traite chaines apres chaines
    set Vraia 0
    set Lter [lsearch -regexp -all $lignesPDB {^TER}]
    set Lter [linsert $Lter 0 "0"]
    set Lter [linsert $Lter end "end"]

    set LterAr [lrange $Lter 1 end]
    set d [lindex $Lter 0]
    foreach f $LterAr {
	set deb $d
	set fin $f
	if {$deb != 0} {incr deb}
	if {$fin ne "end"} {incr fin -1}
	set LLignesChn [lrange $lignesPDB $deb $fin]
	if {$LLignesChn == {}} {
	    set d $f
	    continue
	}
	if {[lsearch -regexp $LLignesChn {^ATOM  }] != -1} {set polymer 1} {set polymer 0}
	set Yaa [LectureDeChainePDB $LLignesChn $MolId]
	if {$Yaa} {set Vraia 1}
	set d $f
    }
    
    set lsite [ExtraitSiteActifDuPDB $Header]
    if {$lsite != {}} {array set PDB_[set MolId]_Site $lsite}
    
    # Remet chaine a si elle n'existe pas
    global PDB_[set MolId]_ChnIdn
    if {0 && ! $Vraia} {
	set c [lindex [set PDB_[set MolId]_ChnIdn] 0]
	foreach n {AtmXYZ AtmBQ NomAtm NomRes NmrRes} {
	    global PDB_[set MolId]_${n}
	    set PDB_[set MolId]_${n}(a) [set PDB_[set MolId]_${n}($c)]
	}
	lappend PDB_[set MolId]_ChnIdn "a"
    }
    
    return 1
}


proc ChercheMeilleureChaineDuPDB {SeqAss MolId} {
    global PDB_[set MolId]_ChnIdn
    global PDB_[set MolId]_NomRes
    
    set NbrChn [llength PDB_[set MolId]_ChnIdn]
    set scoremax -999
    set maxcc -1
    
    set LesChaines [set PDB_[set MolId]_ChnIdn]
    foreach cc $LesChaines {
	set str [join [set PDB_[set MolId]_NomRes($cc)] ""]
	set score($cc) [CalculeAlignt $str $SeqAss $cc $MolId]
	if {[set score($cc)] > $scoremax} {
	    set scoremax [set score($cc)]
	    set maxcc $cc
	}
    }
    
    return $maxcc
}


proc ExtraitSeqEtStrDuPdb {Fichier name {SeqPdb ""}} {
    global LNOrdali Sequences OrdTmpDir Defauts
    
    set cherchemaxcc 0
    
    set VerifChn 0
    set MolId [DonneIdDeAccessPDB $name]
    set chn   [DonneChainDeAccessPDB $name]
    if {[regexp {[a-z]} $chn] || $chn eq ""} {
	set VerifChn 1
    }
    if {[string trim $chn] eq ""} {set chn "a"}

    set rep [DecortiqueUnPDB $Fichier $MolId]
    if {! $rep} {
	if {[ModeI]} {
	    FaireLire "Problem with PDB file !"
	}
	return 0
    }
    global PDB_[set MolId]_NomRes1l
    global PDB_[set MolId]_ChnIdn
    global PDB_[set MolId]_Sequence
    
    set LesChaines [set PDB_${MolId}_ChnIdn]
    foreach cc $LesChaines {
	if {[lsearch [array names PDB_[set MolId]_NomRes1l] $cc] == -1} {
	    set idx [lsearch [set PDB_[set MolId]_ChnIdn] $cc]
	    set PDB_[set MolId]_ChnIdn [lreplace [set PDB_[set MolId]_ChnIdn] $idx $idx]
	}
    }
    
    set LesChaines [set PDB_[set MolId]_ChnIdn]
    if {$VerifChn} {
	if {[lsearch $LesChaines $chn] == -1} {
	    FaireLire "Can't find chain $chn in pdb file $MolId !"
	    return 0
	}
    }
    
    set str [join [set PDB_[set MolId]_NomRes1l($chn)] ""]
    set PDB_[set MolId]_Sequence($chn) $str
    
    return 1
}


proc ChercheMeilleureChaine {} {
    
    if {$SeqAss == ""} {return}
    
    if {$cherchemaxcc} {
	set chn [ChercheMeilleureChaineDuPDB $SeqAss $MolId]
    } else {
	regsub -all {\.} $SeqPdb "" SeqDegape
	set PDB_[set MolId]_Sequence($chn) $SeqDegape
	lappend PDB_[set MolId]_Sequence($chn) $SeqPdb
	return $chn
    }
    set fic "[SigneFichier [string trim [file join $OrdTmpDir [pid]_tmp${MolId}$chn]].msf]"
    
    # Seq PDB alignee sur la sequence ref degapee
    
    set NomDuFichierMSF $fic
    DecortiqueUnMSF $NomDuFichierMSF NomSwNomPDB SeqSwSeqPDB
    regsub -all {\-} $SeqSwSeqPDB(seqtest) "." laseq
    set PDB_[set MolId]_Sequence($chn) $laseq
    
    # Seq PDB alignee sur la sequence ref TELLE QU ELLE EST DANS ALIGNT
    
    set laseqref [set Sequences($SeqAss)]
    set laseq [join [set PDB_[set MolId]_NomRes($chn)] ""]
    set seqali [CalculeAligntContreGlobal $laseqref $laseq $MolId]
    lappend PDB_[set MolId]_Sequence($chn) $seqali
    
    return $chn
}



proc FichierSwDuPdb {Lignes chnin} {
    
    global LNOrdali
    
    set idx -1
    set noms [ExtraitDbRefDuPdb $Lignes $chnin]
    set nom1 [lindex $noms 0]
    set nom2 [lindex $noms 1]
    
    if {$nom1 != "" && $nom2 != ""} {
	set idx "none"
	if {[lsearch $LNOrdali $nom1] != -1} {
	    set idx [lsearch $LNOrdali $nom1]
	}
	if {[lsearch $LNOrdali $nom2] != -1} {
	    set idx [lsearch $LNOrdali $nom2]
	}
    }
    
    if {$idx == "none"} {
	return $nom1
    }
    if {[regexp {[0-9]} $idx]} {
	return $idx
    }
    return -1
}



proc ExtraitDbRefDuPdb {Lignes chncou} {
    #DBREF  1ASY A   68   557  UNP    P04802   SYDC_YEAST      67    556
    #01234567890123456789012345678901234567890123456789012345678901234567890
    #            R             TYP    nmv1     nwv2     
    set idx -1
    set nmw1 ""
    set nmw2 ""
    foreach l $Lignes {
	if {! [regexp {^DBREF} $l]} {continue}

	set chn [string index $l 12]
	set type [string range $l 26 30]
	set type [string trim $type]
	if {$chn == $chncou && ($type eq "SWS" || $type eq "UNP")} {
	    set nmw1 [string range $l 33 40]
	    set nmw2 [string range $l 42 53]
	    set nmw1 [string trim $nmw1]
	    set nmw2 [string trim $nmw2]
	}
    }
    
    return [list $nmw1 $nmw2]
}



proc EcritLePDB {id Fichier} {
    global PDB_[set id]_NomAtm
    global PDB_[set id]_NomRes
    global PDB_[set id]_NmrRes
    global PDB_[set id]_ChnIdn
    global PDB_[set id]_AtmXYZ
    global PDB_[set id]_AtmBQ
    global PDB_[set id]_Header
    
    if {$Fichier eq ""} {set Fichier [DemandeEtSauveFichier "pdb"]}
    
    set f [open $Fichier w]
    puts $f [join [set PDB_[set id]_Header] "\n"]
    
    set i 1
    foreach c [set PDB_[set id]_ChnIdn] {
	if {$i != 1} {puts $f "TER "}
	foreach nmr [set PDB_[set id]_NomRes($c)] nbr [set PDB_[set id]_NmrRes($c)] lan [set PDB_[set id]_NomAtm($c)] lax [set PDB_[set id]_AtmXYZ($c)] lab [set PDB_[set id]_AtmBQ($c)] {
	    foreach lx $lax lb $lab n $lan {
		lassign $lx x y z
		lassign $lb b q
		set chn $c
		if {$c eq "a"} {set chn " "}
		set NomR [AutreCodeLuc $nmr]
		set ligne [format "%6s%5d %4s %3s %1s%4d    %8.3f%8.3f%8.3f%6.2f%6.2f" "ATOM  " $i $n $NomR $chn $nbr $x $y $z $q $b]
		puts $f $ligne
		incr i
	    }
	}
    }
    puts $f "END"
    close $f
    
    return
}


proc ListeDesPDBDB {} {
    return [lsort -unique [$::db eval {select nom from pdb}]]
}


proc DonneChainesDe {{n1 ""} {n2 ""} {op ""}} {
    global SP

    # SP(Mol) is a structure (1EFW), not a sequence name (PDB_1EFW_A)
    set SP(ListeChn) [lsort [::$SP(Mol) _chains]]
    set SP(LaChn) [lindex $SP(ListeChn) 0]
    set w $SP(ChnMenu)
    destroy $w
    tk_optionMenu $w SP(LaChn) {*}$SP(ListeChn)
    grid $w -row 1 -column 1 -sticky w

    update

    return
}


proc FinSauvePDBParams {quoi} {
    global SP
    
    if {$quoi eq "ok"} {
	if {$SP(ChnAll) eq "all"} {
	    set chn "all"
	} else {
	    set chn $SP(LaChn)
	}
	
	if {$SP(ResAll) eq "all"} {
	    set d "all" ; set f "all"
	} else {
	    if {! [string is integer -strict $SP(ResFrom)] || ! [string is integer -strict $SP(ResTo)]} {
		FaireLire "Warning !\nPlease supply a valid residue range !"
		return
	    }
	    set d $SP(ResFrom)
	    set f $SP(ResTo)
	}
	
	::$SP(Mol) save $chn $d $f
    }
    trace remove variable SP(Mol) write DonneChainesDe

    destroy $SP(Top)
    unset SP

    return
}


proc SauveLesPDB {} {
    global SP ListePDB Defauts

    if {[TypeAli] eq "pasdali"} {return}
    if {$ListePDB == {}} {return}

    if {[winfo exists .sp]} {
	raise .sp

	return
    }

    toplevel .sp
    wm title .sp "Select parameters ..."
    wm protocol .sp WM_DELETE_WINDOW KillParLaCroix
    wm resizable .sp 0 0
    set SP(Top) .sp

    set f [frame .sp.f]
    grid $f -row 0 -column 0 -sticky news
    grid columnconfig $f 0 -weight 1
    
    label $f.lbl \
	-text "Select parameters ..." \
	-font TitleFont \
	-fg $Defauts(ForeAppli) \
	-anchor w -justify left
    grid $f.lbl  -row 0 -column 0 -sticky w -padx 10 -pady 10
    
    frame $f.fmol
    grid $f.fmol -row 1 -column 0 -sticky ew -padx 10 -pady {10 5}
    # the structures, not the sequences (PDB_1EFW_A, PDB_1EFW_B -> 1EFW)
    set Lmol {}
    foreach p $ListePDB {
	set m [string toupper [DonneIdDeAccessPDB $p]]
	if {$m ni $Lmol && [info object isa object ::$m]} {
	    lappend Lmol $m
	}
    }
    if {$Lmol eq {}} {
	destroy .sp
	return
    }
    set SP(Mol) [lindex $Lmol 0]
    label $f.fmol.lbl \
	-text "Select molecule :" \
	-fg $Defauts(ForeAppli) \
	-anchor w -justify left
    tk_optionMenu $f.fmol.mol SP(Mol) {*}$Lmol
    trace remove variable SP(Mol) write DonneChainesDe
    trace add variable SP(Mol) write DonneChainesDe
    grid $f.fmol.lbl -row 0 -column 0 -sticky w
    grid $f.fmol.mol -row 0 -column 1 -sticky w
    
    set SP(ListeChn) "Choose"
    set SP(ChnAll) "all"
    set SP(ChnMenu) $f.fchn.lch
    frame $f.fchn
    grid $f.fchn -row 2 -column 0 -sticky ew -padx 10 -pady 5
    label $f.fchn.lbl \
	-text "Select chain :" \
	-fg $Defauts(ForeAppli) \
	-anchor w -justify left
    checkbutton $f.fchn.chk -text "all" \
	-relief flat -anchor w -justify left \
	-variable SP(ChnAll) \
	-onvalue "all" \
	-offvalue "one"
    tk_optionMenu $f.fchn.lch SP(LaChn) {*}$SP(ListeChn)
    grid $f.fchn.lbl -row 0 -column 0 -columnspan 2 -sticky w
    grid $f.fchn.chk -row 1 -column 0 -sticky w
    grid $f.fchn.lch -row 1 -column 1 
    grid columnconfig $f.fchn all -weight 1
    # chains of the first structure
    DonneChainesDe
    
    set SP(ResAll) "all"
    frame $f.fres
    grid $f.fres -row 3 -column 0 -sticky ew -padx 10 -pady {5 10}
    label $f.fres.lbl \
	-text "Select residues range :" \
	-fg $Defauts(ForeAppli) -anchor w -justify left
    checkbutton $f.fres.chk -text "all" \
	-relief flat -anchor w -justify left \
	-variable SP(ResAll) \
	-onvalue "all" -offvalue "rng"
    label $f.fres.lfr \
	-text "from" \
	-anchor w -justify left
    entry $f.fres.efr \
	-width 4 \
	-textvariable SP(ResFrom)
    label $f.fres.lto \
	-text "to" \
	-anchor w -justify left
    entry $f.fres.eto \
	-width 4 \
	-textvariable SP(ResTo)
    grid $f.fres.lbl -row 0 -column 0 -columnspan 5 -sticky w
    grid $f.fres.chk -row 1 -column 0 -sticky w -padx {1 5}
    grid $f.fres.lfr -row 1 -column 1 -sticky w -padx {5 1}
    grid $f.fres.efr -row 1 -column 2 -sticky w -padx {1 2}
    grid $f.fres.lto -row 1 -column 3 -sticky w -padx {2 1}
    grid $f.fres.eto -row 1 -column 4 -sticky w
    
    frame $f.fbut
    grid $f.fbut -row 4 -column 0 -sticky ew -padx 10 -pady 10
    button $f.fbut.bok \
	-text " OK " \
	-bg green1 \
	-command [list FinSauvePDBParams ok]
    button $f.fbut.bdi \
	-text "Dismiss" \
	-bg red \
	-command [list FinSauvePDBParams dismiss]
    grid $f.fbut.bdi -row 0 -column 0 -sticky w -padx {1 10}
    grid $f.fbut.bok -row 0 -column 1 -sticky e -padx {10 1}
    grid columnconfig $f.fbut all -weight 1
    
    set oldGrab [grab current]
    grab .sp
    FenetreAuCentre $SP(Top)
    
    tkwait window $SP(Top)
    
    if {$oldGrab ne ""} {
	grab $oldGrab
    }
    unset -nocomplain SP

    return
}


proc SauveLePDB {lignes mol}  {
    
    global OrdTmpDir
    global env
    
    if {! [info exists OrdTmpDir]} {
	set labas [RepertoireDeTravail]
	set lepid ""
    } else {
	set labas $OrdTmpDir
	set lepid "[pid]_"
    }
    
    set file [file join $labas "${lepid}pdb${mol}.ent"]
    
    set f [open $file w]
    puts $f [join $lignes "\n"]
    close $f
    
    return $file
}


proc DistanceDe {A B} {
    lassign $A x1 y1 z1 
    lassign $B x2 y2 z2 

    set d [expr {sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2)}]

    return $d
}


proc ResiduesEnContact {pdbid chn {Seuil 3.4}} {
    global PDB_[set pdbid]_AtmXYZ
    global PDB_[set pdbid]_NmrRes
    
    set Lr [set PDB_[set pdbid]_AtmXYZ($chn)]
    set Ld [lrange $Lr 0 end-1]
    set La [lrange $Lr 1 end]
    
    set Contact {}
    set i 0
    foreach d $Ld {
	incr i
	set j 1
	foreach a $La {
	    incr j
	    
	    foreach rd $d {
		lassign $rd x1 y1 z1 
		foreach ra $a {
		    lassign $ra x2 y2 z2 
		    set dist [expr {sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2)}]
		    if {$dist > $Seuil} {continue}
		    lappend Contact "$i $j"
		}
	    }
	}
    }
    
    return $Contact
}


proc EcritGrapheContacts {fpdb mol chn} {
    
    DecortiqueUnPDB $fpdb
    set Cnct [ResiduesEnContact $mol $chn]
    set f [open "${mol}_contact.txt" w]
    puts $f "${mol}_${chn}"
    puts $f [join $Cnct "\n"]
    close $f
    
    return
}



proc EstUnBonResidu {La} {
    if {" N  " in $La && " CA " in $La && " C  " in $La && " O  " in $La} {return 1}
    if {" P  " in $La && " OP1" in $La && " O5'" in $La && " C5'" in $La && " C4'" in $La} {return 1}
    
    return 0
}


proc PourNico {} {
    set Ll [LesLignesDuFichier "/home/moumou/deplacements.txt"]
    set sda 0
    set sa2 0
    set sdc 0
    set sc2 0
    set ia 0
    set ic 0
    set ma -1
    set mc -1
    set mx -1
    set na 99999
    set nc 99999
    set mn 9999
    foreach l $Ll {
	regsub -all { +} $l " " l
	set nl [split $l " "]
	set dp [lindex $nl end]
	set c  [lindex $nl end-3]
	set r  [lindex $nl end-2]
	if {$c eq "A"} {
	    set sda [expr {$sda+$dp}]
	    if {$dp > $ma} {set ma $dp}
	    if {$dp < $na} {set na $dp}
	    incr ia
	} else {
	    set sdc [expr {$sdc+$dp}]
	    if {$dp > $mc} {set mc $dp}
	    if {$dp < $nc} {set nc $dp}
	    incr ic
	    incr r 1000
	}
	if {$dp > $mx} {set mx $dp}
	if {$dp < $mn} {set mn $dp}
	set T($c,$r) $dp
    }
    
    set sum 0
    foreach e [array names T] {
	set sum [expr {$sum+[set T($e)]}]
    }
    set moy [expr {$sum/[llength [array names T]]}]
    
    puts "Nb atm  A $ia"
    puts "Nb atm  C $ic"
    puts "Min/Max chn A $na/$ma"
    puts "Min/Max chn C $nc/$mc"
    puts "Moy chn A [expr {$sda/$ia}]"
    puts "Moy chn C [expr {$sdc/$ic}]"
    puts ""
    puts "Moy totale  $moy"
    puts "Min/Max tot $mn/$mx"
    
    # Ramene dans l'intervalle 10 - 200
    set LesV {}
    set mxv -9999.
    set mnv  9999.
    foreach e [array names T] {
	set x [set T($e)]
	set r [expr {(double($x)-$mn)/($mx-$mn)}]
	set v [expr {(10.) + (200.-10.)*$r}]
	if {$v > $mxv} {set mxv $v}
	if {$v < $mnv} {set mnv $v}
	set T($e) $v
	lappend LesV $v
    }
    
    puts ""
    puts "apres trans :"
    puts "Min/Max $mnv/$mxv"
    puts ""
    
    DecortiqueUnPDB "dimmixte.pdb"
    global PDB_dimmixte_AtmBQ
    global PDB_dimmixte_NmrRes
    
    foreach ccou {A C} {
	set Lnew {}
	set Lbq [set PDB_dimmixte_AtmBQ($ccou)]
	set Lnm [set PDB_dimmixte_NmrRes($ccou)]
	foreach r $Lnm bq $Lbq {
	    set x [set T($ccou,$r)]
	    set Nx {}
	    foreach a $bq {
		lassign $a b q
		lappend Nx [list $x $q]
	    }
	    lappend Lnew $Nx
	}
	set PDB_dimmixte_AtmBQ($ccou) $Lnew
    }
    
    EcritLePDB dimmixte new_dimmixte.pdb
    
    set histo [CreeHistogramme $LesV 50 graph]
    #   array set Th $histo
    #   parray Th
    
    
    #    exit
}


proc ResiduesInterface_old {Lxml pdb chn} {
    set RId [dom parse -simple $Lxml]
    set doc [$RId documentElement]

    set Lent [$doc selectNodes //pisa_interfaces/pdb_entry]
    set found 0
    foreach ent $Lent {
	set npc [$ent selectNodes ./pdb_code]
	if {[$npc selectNode string(.)] eq "[string toupper $pdb]"} {
	    set found 1
	    break
	}
    }
    if {! $found} {
	puts "  ==> PDB $pdb not found in interfaces !"
	$RId delete
	update

	return {}
    }

    # check 
    set ni [lindex [$ent selectNodes ./interface] 0]
    if {$ni eq ""} {
	puts "  ==> No interfaces found for $pdb !"
	$RId delete
	update

	return {}
    }

    set gc 0
    set Lres {}
    set Lb [$ni selectNodes ./h-bonds/bond]
    foreach nb $Lb {
	set Lv [$nb childNodes]
	set nr "" ; set nm ""
	foreach nv $Lv {
	    switch [$nv nodeName] {
		"chain-1" -
		"chain-2" {
		    set v [$nv selectNode string(.)]
		    if {$v eq $chn} {
			set gc 1
		    }
		}
		"seqnum-1" -
		"seqnum-2" {
		    set v [$nv selectNode string(.)]
		    if {$gc} {
			set nr $v
			set gc 0
		    }
		}
		"res-1" -
		"rse-2" {
		    set v [$nv selectNode string(.)]
		    if {$gc} {
			set nm $v
			set gc 0
		    }
		}
	    }
	    if {$nr ne ""} {
		lappend Lres [list $nr $nm]
	    }
	}
    }

    $RId delete
    update

    return [lsort -unique -integer -index 0 $Lres]
}

proc ResiduesInterface {Lxml pdb chn} {
    set aT [ResInterProcessXML-SAX $Lxml]
    if {$aT != {} } {
	array set T $aT
	if {! [info exists T($pdb,h-bonds)]} {
	    return {}
	}
	set Lres {}
	foreach b [set T($pdb,h-bonds)] {
	    lassign $b c1 t1 n1 c2 t2 n2
	    if {$c1 eq $chn} {
		lappend Lres [list $n1 $t1]
	    } 
	    if {$c2 eq $chn} {
		lappend Lres [list $n2 $t2]
	    } 
	}
	set Lres [lsort -unique -integer -index 0 $Lres]
    } else {
	set Lres {}
    }

    return $Lres
}


proc ResInterProcessXML-SAX {Lxml} {
    global TParser

    unset -nocomplain TParser
    set p [expat \
	    -elementstartcommand  RIst \
	    -characterdatacommand RIch \
	    -elementendcommand    RIed ]
    if [catch {$p parse $Lxml} res] {
	puts "ERROR while parsing XML !"
	puts "$res"
	$p free
	unset p

	return {}
    }
    $p free
    unset p

    return [array get TParser]
}


proc RIst {name atts} {
    global TParser

    lappend TParser(S) $name ;# push
    switch $name {
	"interface" {
	    set id [set TParser(Id)]
	    incr TParser($id,Interface)

	}
	"h-bonds" {
	    set id [set TParser(Id)]
	    if {[set TParser($id,Interface)] < 2} {
		set TParser($id,parent) $name
		set TParser($id,$name) {}
	    }
	}
	"bond" {
	    set id [set TParser(Id)]
	    set TParser($id,chain-1) "" ; set TParser($id,chain-2) ""
	    set TParser($id,seqnum-1) "" ; set TParser($id,seqnum-2) ""
	    set TParser($id,res-1) "" ; set TParser($id,res-2) ""
	}
    }

    return
}


proc RIch {str} {
    set type [lindex $::TParser(S) end]
    switch $type {
	"pdb_code" {
	    set ::TParser(Id) $str
	    lappend ::TParser(LId) $str
	    set ::TParser($str,Interface) 0
	}
	"chain-1" -
	"chain-2" -
	"seqnum-1" -
	"seqnum-2" -
	"res-1" -
	"res-2" {
	    set id [set ::TParser(Id)]
	    set ::TParser($id,$type) $str
	}
	default return
    }

    return
}


proc RIed {name} {
    global TParser

    set TParser(S) [lrange $TParser(S) 0 end-1] ;# pop
    switch $name {
	"bond" {
	    set id [set TParser(Id)]
	    if {[set TParser($id,Interface)] > 1} {
		return
	    }

	    set bnd [list $TParser($id,chain-1) $TParser($id,res-1) $TParser($id,seqnum-1) $TParser($id,chain-2) $TParser($id,res-2) $TParser($id,seqnum-2)]
	    set par [set TParser($id,parent)]
	    lappend TParser($id,$par) $bnd
	}
	default return
    }

    return
}


proc tRI {} {
    set xml [PDBeInterface 1OCP]
    puts "$xml"
    puts "[ResiduesInterface $xml 1OCP A]"

    exit
}


proc ReadDSSPOutput {TextOrFile} {
    if {[file exists TextOrFile]} {
	set text [LesLignesDuFichier $TextOrFile]
    } else {
	set text $TextOrFile
    }
    
    set i [lsearch -regexp $text {^  \#  }]
    
    foreach l [lrange $text $i+1 end-1] {
	#regsub -all { +} $l " " l
	#lassign [split $l] tmp nmr chn res str
	scann "%5d%5d%2d%2d%3s" tmp nmr chn res str
	lappend Tss($chn) $str
    }

    foreach k [array names Tss] {
	puts "$k [join $Tss($k) \"\"]"
    }
    
    
    return
}


proc ReadNAccessOutput {text} {
    if {! [regexp {^REM } $text]} {
	return {}
    }
    set Ll [split $text \n]
    # RES MET B  31   135.05  69.6 112.19  71.6  22.86  60.9 116.03  73.5  19.02  52.4
    # RES MET B1031   135.05  69.6 112.19  71.6  22.86  60.9 116.03  73.5  19.02  52.4
    foreach l $Ll {
	if {! [regexp {^RES } $l]} {
	    continue
	}
	scan $l "%s %s %1s%d %f %f %f" tmp res chn num tmp rsa tmp
	lappend RSA(rsa,$chn) $rsa
	lappend RSA(seq,$chn) [AutreCodeLuc $res]
	lappend RSA(nmr,$chn) [string trim $num]
    }

    return [array get RSA]
}


proc ReadStrideOutput {FileOrTextOrList} {
    if {[file exists $FileOrTextOrList]} {
	set LesLignes [LesLignesDuFichier $FileOrTextOrList]
    } elseif {[string first "\n" $FileOrTextOrList] >= 0} {
	set LesLignes [split $FileOrTextOrList \n]
    } else {
	set LesLignes $FileOrTextOrList
    }

    # H G I : helix
    # E strand
    # T turn
    foreach l $LesLignes {
	if {[string first "REM " $l] == 0} {
	    continue
	}

	# read secondary structures
	#LOC  AlphaHelix   ALA    54 A      GLU     62 A                            1IL2
	regsub -all { +} $l " " l
	switch -regexp $l {
	    {^LOC } {
		lassign [split $l " "] tmp type resDep nmrDep chn resFin nmrFin chn tmp
		if {$type ne "Disulfide"} {
		    lappend Str(SS,$chn) [list $type $resDep $nmrDep $resFin $nmrFin]
		}
	    }
	    {^CHN } {
		lassign $l tmp tmp chn tmp
		set Str(seq,$chn) {}
		set Str(nmr,$chn) {}
		set Str(SS,$chn)  {}
		set Str(SA,$chn)  {}
		set Str(iS,$chn)  ""
	    }
	    {^ASG } {
		lassign $l asg res chn nmr sti sec1 sec phi psi asa tmp
		lappend Str(seq,$chn) [AutreCodeLuc $res]
		lappend Str(nmr,$chn) $nmr
		lappend Str(SA,$chn)  $asa
		append  Str(iS,$chn)  $sec1
	    }
	}
    }

    return [array get Str]
}


proc CalculeAccessibiliteDuPDB {pdbfile} {



    return
}


proc TraiteComponent {} {
    # components.cif dictionary
    #
    # dictionary of all components types (residues, lignads, ...) found in PDB structures
    # found at https://www.wwpdb.org/data/ccd
    #
    # extract info from components.cif
    # distributed by rcsb
    # 
    set Ll [LesLignesDuFichier components.cif]
    foreach l $Ll {
	switch -regexp $l {
	    {^data_} {
		set cmp [string range $l 5 7]
	    }
	    {^_chem_comp\.type } {
		regsub -all { +} $l " " l
		set type [string toupper [join [lrange [split $l " "] 1 end]]]
	    }
	    {^_chem_comp\.pdbx_type } {
		regsub -all { +} $l " " l
		set ptyp [lindex [split $l " "] 1]
	    }
	    {^_chem_comp\.one_letter_code } {
		regsub -all { +} $l " " l
		set 1ltc [lindex [split $l " "] 1]
		lappend res [list $cmp $type $ptyp $1ltc]
	    }
	}
    }
    
    set res [lsort -index 2 $res]
    set f [open comp.txt w]
    foreach e $res {
	puts $f [join $e \t]
    }
    close $f
    
    exit
}


proc Seqres2Seq {seqres} {
    set seqres [join $seqres \n]
    regsub -all { +} $seqres " " seqres
    set seq ""
    foreach aa [split $seqres] {
	if {$aa ne "SEQRES"} {
	    append seq [AutreCodeLuc $aa]
	}
    }
    
    return $seq
}


proc tstride {} {
    cd /home/moumou/tclstride

    load ./libtclstride.so

    set res [doStride 1il2.pdb]
    puts "res= $res"
    set out [split $res \n]
    array set T [ReadStrideOutput $out]
    parray T
    
    foreach elt $T(SS,A) {
	lassign $elt type
	lappend Ltype $type
    }
    set Ltype [lsort  -unique $Ltype]
    puts [join $Ltype \n]
    
    exit
}


proc ResidueCDM {Latm} {
    set n [llength $Latm]
    set sx 0.0 ; set sy 0.0 ; set sz 0.0
    foreach l $Latm {
	lassign $l x y z
	set sx [expr {$sx + $x}]
	set sy [expr {$sy + $y}]
	set sz [expr {$sz + $z}]
    }
    set sx [expr {$sx/$n}]
    set sy [expr {$sy/$n}]
    set sz [expr {$sz/$n}]
    
    return [list $sx $sy $sz]
}


proc GetIDFromPDBFile {file} {
    set Ll [LesLignesDuFichier $file]
    if {[string first "HEADER" [lindex $Ll 0]] == 0} {
	regsub -all { +} [lindex $Ll 0] " " l
	set id [lindex [split $l] end]
    } else {
	set id -1
    }

    return $id
}


proc BestPDBChainByIdentity {Ln Ls pdbid Lchn} {
    set Lns {}
    foreach n $Ln s $Ls {
	lappend Lns $n $s
    }
    array set TPCI [CalculeLesPCIGenerique $Lns]
    
    set pcmax -1.0
    set chnMax ""
    set closest ""
    foreach c $Lchn {
	if {! [EstUnUniProt $pdbid]} {
	    set nom [BonNomPDB "${pdbid}_$c"]
	} else {
	    set nom "${pdbid}_$c"
	}
	    set Lk [array names TPCI "*,$nom"]
	foreach k $Lk {
	    lassign [split $k ,] name tmp
	    if {$name eq $nom || [EstUnAccessPDB $name]} {
		continue
	    }
	    set pc [lindex $TPCI($k) 0]
	    if {$pc > $pcmax} {
		set pcmax $pc
		set closest $name
		set chnMax $nom
	    }
	}
    }

    return [list $closest $chnMax $pcmax]
}






    
