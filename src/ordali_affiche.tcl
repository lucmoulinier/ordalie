
#
#
# --- ordali_affiche.tcl
# 


proc FinDemarrage {{w ""}} {
    if {! [ModeI]} {
	return                          
    }
    
    # the splash image is created again at each loading : free it
    set ph ""
    catch {set ph [$w.dmg.l cget -image]}
    if {$w eq ""} {
	catch {destroy $w.dmg}
    } else {
	destroy [winfo toplevel $w.dmg]
    }
    if {$ph ne ""} {
	catch {image delete $ph}
    }

    update idletasks
    
    return
}


proc DemarrageOrdali {{w ""}} {
    global OrdEtcDir PBV PBW
    
    if {! [ModeI]} {
	return
    }

    set year [clock format [clock seconds] -format %Y]
    set fimg [file join $OrdEtcDir OrdaliNuage_$year.png]
    if {! [file exists $fimg]} {
	set ph [PutYearOnOrdaliImage]
    } else {
	set ph [image create photo]
	$ph read $fimg -format png
    }

    if {$w ne ""} {
	set top $w
	toplevel $w
    } else {
	set top .
	set w ""
    }

    wm title $top "Loading Ordalie"
    wm withdraw $top

    set PBV 0.
    set PBW "loading ..."

    frame $w.dmg
    grid $w.dmg -row 0 -column 0 -sticky news
    label $w.dmg.l \
	-image $ph
    label $w.dmg.w \
	-textvariable PBW \
	-anchor w \
	-bg white
    ttk::progressbar $w.dmg.p \
	-variable PBV

    grid $w.dmg.l -row 0 -column 0 -sticky ew
    grid $w.dmg.w -row 1 -column 0 -sticky ew
    grid $w.dmg.p -row 2 -column 0 -sticky ew

    wm deiconify $top
    update idletasks
    
    FenetreAuCentre $w.dmg

    wm attributes $top -topmost
    
    raise $top
    update idletasks

    return
}


proc MetAJourFenetreOrdali {} {
    global WOrdali ListeDesMacs

    set wdt [PlusLongEltDe $ListeDesMacs]
    $WOrdali(combomac) configure -values $ListeDesMacs
    $WOrdali(combomac) current [expr {[llength $ListeDesMacs]-1}]

    return
}


proc LoadingAlignement {} {
    global LongueurTotale ListeTypesDeFeatures Defauts TabSF db
    global LNOrdali Sequences AlnName AlnScore AlnNote
    
    if {[TypeAli] eq "pasdali"} {
	return ""
    }
    
    set fic [set Defauts(Fichier[TypeAli])]
    if {!  [file exists $fic]} {
	puts "\nError !\nFile $fic does not exists \n"
	return 0
    }
    if {! [VerifieFormatAlignement $fic [TypeAli]]} {
	return 0
    }
    set AlnName [file rootname [file tail $fic]]
    regsub -all " " $AlnName "_" AlnName
    
    InitInfoArrays
    if {[TypeAli] ne "ORD"} {
	set db [FabriqueDeTables [set Defauts(TablesDB1.1)] "OrdDB_root_main_[pid]_[clock seconds]" "memory"]
    }
    
    switch [TypeAli] {
	"XML" {
	    set AlnScore 0.0
	    set AlnNote ""
	    DecortiqueUnXml2 $fic
	}
	"TFA" {
	    DecortiqueUnTFA $fic LNOrdali Sequences
	}
	"ALN" {
	    DecortiqueUnALN $fic LNOrdali Sequences
	}
	"MSF" {
	    DecortiqueUnMSF $fic LNOrdali Sequences
	}
	"RSF" {
	    DecortiqueUnRSF $fic LNOrdali Sequences TabSF
	    set ListeTypesDeFeatures [set TabSF(LesTypesDeFeatures)]
	}
	"ORD" {
	    DecortiqueUnORD $fic
	    LesDefauts FichierORD $fic
	    LesDefauts FirstPass 1
	}
    }

    if {[TypeAli] ne "ORD"} {
	if {! [InitSequences]} {
	    return 0
	}
	
	InitPremierGroupe
	if {[TypeAli] eq "XML"} {
	    DonneTabFeature TabSF
	} elseif {[TypeAli] eq "RSF"} {
	    DonneTabFeatureDuRsf TabSF
	}
    }

    AssignSeqToGroup
    InitInfoSeqs
    InitConsensus

    if {[TypeAli] ne "ORD"} {
	RemplitOrdaliDB
    }
    FichierModifie 0
    
    return $fic
}


proc DecortiqueEtAfficheUnMSF {{FichierMSF ""}} {
    global LeFichierMSFDeDepart
    global LNOrdali
    global Sequences

    set LeFichierMSFDeDepart $FichierMSF
    if {! [VerifieFormatAlignement $FichierMSF MSF]} {
	return
    }

    DecortiqueUnMSF $FichierMSF LNOrdali Sequences
    if {! [InitSequences]} {
	return
    }
    
    InitPremierGroupe
    InitAffichage
    BindingsOrdali
    BindModeNormal

    OrdaliDefaultTags
    OrdaliDefaultMapping
    
    MontreStrSecDansAlignement
    
    return
}



proc SequencesSelectionnees {{ix "name"}} {
    global LNOrdali
    global NomSeqSel

    if {$NomSeqSel eq ""} {return ""}
    foreach v $NomSeqSel {
	lassign [split $v .] y x
	lappend Li [expr {$y-1}]
	lappend Lg $y
	lappend Ln [lindex $LNOrdali [expr {$y-1}]]
    }

    switch $ix {
	"index"   {return $Li}
	"graphic" {return $Lg}
	"name"    {return $Ln}
    }
}


proc DetruitUnPDB {pdbid} {
    global db ListePDB

    # detruit objets assicies
    $pdbid deleteObjects
    $pdbid destroy

    $db transaction {
    set pkpdb [$::db eval {select pk_pdb from pdb where nom=$pdbid}]
    $db eval {delete from atomes where pk_pdb=$pkpdb}
    $db eval {delete from residues where pk_pdb=$pkpdb}
    $db eval {delete from chaines where pk_pdb=$pkpdb}
    $db eval {delete from pdb where pk_pdb=$pkpdb}
    }

    set Li [lsearch -regexp -all $ListePDB $pdbid]
    foreach i [lreverse $Li] {
	set ListePDB [lreplace $ListePDB $i $i]
    }

    return
}


proc AjoutePDBId {{what "ok"}} {
    global TAddS LNOrdali ListePDB NomNomSeq NomTextSeq

    if {$what ne "ok"} {
	destroy $TAddS(Win)
	unset TAddS

	return
    }

    if {$TAddS(IDIn) eq ""} {
	FaireLire "Please supply a PDB ID"
	return
    }

    if {! [EstUnAccessPDB $TAddS(IDIn)]} {
	FaireLire "Please supply a valid PDB ID!"
	return
    }
    
    set pdbid [LoadNouveauPDB $TAddS(IDIn) $pdbid]
    regsub " superseed.+$" $pdbid "" pdbid

    AjouteDBGenerique $pdbid

    return
}


proc AjoutePDBFile {{what "ok"}} {
    global TAddS LNOrdali ListePDB

    if {$what ne "ok"} {
	destroy $TAddS(Win)
	unset TAddS

	return
    }

    if {$TAddS(FileIn) eq ""} {
	FaireLire "Please supply a PDB file name !"
	return
    }

    if {! [file exists $TAddS(FileIn)]} {
	FaireLire "The file :\n$TAddS(FileIn)\ndoes not exists !"
	return
    }

    if {$TAddS(Replace) eq ""} {
	FaireLire "Please select <<Replace>> or give the new PDB Id"
	return
    }
    
    if {$TAddS(Replace)} {
	if {$TAddS(Id) eq "Choose"} {
	    FaireLire "Please choose the PDB Id to be replaced"
	    return
	}

	DetruitUnPDB $TAddS(Id)
	set pdbid $TAddS(Id)
    } else {
	if {! [EstUnAccessPDB $TAddS(NewId)]} {
	    FaireLire "Please give a valid PDB Id for this structure\nIt should be on the form : NXXX_Y where N is a number (0-9), X can be a number or a letter, and Y an alphanumaric character"
	    return
	}

	set pdbid $TAddS(NewId)
    }

    destroy $TAddS(Win)
    FaireAttendre "Please wait ...\nLoading PDB ..."

    #rR LoadNouveauPDB $TAddS(File) $pdbid
    set pdbid [LoadNouveauPDB $TAddS(FileIn) $pdbid]
    regsub " superseed.+$" $pdbid "" pdbid

    foreach c [$pdbid _chains] {
	set nom [BonNomPDB ${pdbid}_$c]
	if {$nom in $LNOrdali && $nom ni $ListePDB} {
	    lappend ListePDB $nom
	}
    }

    unset TAddS

    return
}


proc AjoutePDBGenerique {pdbid} {
    global TAddS NomNomSeq NomTextSeq

    # first align PDB chain sequences
    set LNpdbSeq {}
    set LSpdbSeq {}
    set Lchains {}
    foreach c [$pdbid _chains] {
	if {[$pdbid _chainIs $c] ne "Protein"} {
	    continue
	}
	set n [BonNomPDB "${pdbid}_$c"]
	set s [$pdbid _resname -chain $c -polymer]

	lappend LNpdbSeq $n
	lappend LSpdbSeq $s
	lappend Lchains $c
    }

    set LNomsAli [$NomNomSeq output all]
    set LSeqsAli [$NomTextSeq output all]
    set LNomsOri $LNomsAli
    set LSeqsOri $LSeqsAli

    # Now align with MAFFT ...
    lassign [AlignSeqsAgainstReference $LNpdbSeq $LSpdbSeq $LNomsAli $LSeqsAli] LNAligned LSAligned aSAligned
    if {$LNAligned eq ""} {
	# Something went wrong while aligning ...
	return
    }
    array set SAligned $aSAligned

    # Now determine the best chain if necessary
    set Lns {}
    foreach n$LNAligned s $LSAligned {
	lappend Lns $n $s
    }

    # determine best chain
    array set Tpci [CalculeLesPCIGenerique $Lns]
    set pmax -1.0
    set chnMax ""
    set nomMax ""
    foreach c $Lchains {
	set nom [BonNomPDB "${pdbid}_$c"]
	set Lk [array names Tpci "$nom,*"]
	foreach k $Lk {
	    lassign [split $k ,] tmp name
	    if {$name eq $nom} {
		continue
	    }
	    if {[lindex $Tpci($k) 0] > $pmax} {
		set pmax [lindex $Tpci($k) 0]
		set chnMax $nom
		set nomMax $name
	    }
	}
    }
    set nom $chnMax
    set closest $nomMax
    
    return
}


proc FinAfficheAskAddSeqs {what} {
    global TAddS

    if {$what eq "dismiss"} {
	set TAddS(ok) 0
	destroy .affas
	update idletasks
	
	return ""
    }

    # check sequence file
    set file $TAddS(FileIn)
    if {$file eq "" || ! [file exists $file]} {
	FaireLire "The file >$file< does not exists !"

	return
    }

    set format [FormatDuFichierSequence $file]
    if {$format ni {MSF TFA ALN}} {
	FaireLire "Beware ! You can only add sequence(s) as a TFA, MSF or CLUSTAL (ALN) file !"

	return
    }

    # Verify form fields have been filled
    if {$TAddS(CopySkip) == -1} {
	FaireLire "Please specify what to do with duplicated sequences !"
	return
    }
    
    set TAddS(ok) 1
    update
    if {[winfo exists .affas]} {destroy .affas}
    
    return 
}


proc InitAddSeqs {} {
    global TAddS LNDG

    set TAddS(SeqIdIn) ""
    set TAddS(SeqFileIn) ""
    set TAddS(StrucFileIn)      ""
    set TAddS(StrucIdIn)      ""
    set TAddS(associatedId) ""
    set TAddS(chnType) ""
    set TAddS(Align)     1
    set TAddS(CopySkip)  1
    set TAddS(Position)  "end"
    set TAddS(seqInsert) ""

    if {[llength $LNDG] > 1} {
	set TAddS(KeepClus) 1
    } else {
	set TAddS(KeepClus) 0
    }

    if {0} {
	set TAddS(FileIn) "H_add.tfa"
	set TAddS(Position) "end"
	set TAddS(seqInsert) "A9TJG7"
	set TAddS(Align) 1
    }

    return
}


proc AskAddSeqs {} {
    global TAddS LNDG

    InitAddSeqs

    if {[ModeI]} {
	set res [AfficheAskAddSeqs]
    }

    return $res
}


proc InsertionSequencesDansGroupes {LNAli LSAli LNAdd LSAdd} {
    global SDG LNDG

    # only one group
    if {[llength [lsearch -regexp -all $LNDG {^Group}]] == 1} {
	set g [lindex $LNDG 0]
	set Ln [lmap n $LNAli {if {[string trim $n] eq ""} {continue} {set n}}]
	set Ls [lmap s $LSAli {if {[string trim $s] eq ""} {continue} {set s}}]
	set Ln [concat $Ln $LNAdd]
	set Ls [concat $Ls $LSAdd]
	set Ln [linsert $Ln 0 {}]
	set Ls [linsert $Ls 0 {}]
	lappend Ln {}
	lappend Ls {}

	foreach n $LNAdd {
	    lappend SDG($g) [string trim $n]
	}

	return [list $Ln $Ls]
    }

    set Lns {}
    foreach n $LNAli s $LSAli {
	set n [string trim $n]
	if {$n ne ""} {
	    lappend Lns $n $s
	}
    }
    foreach n $LNAdd s $LSAdd {
	lappend Lns $n $s
    }

    array set TPCI [CalculeLesPCIGenerique $Lns]

    DefineGroupForNewSeq $LNAdd TPCI

    # rebuild seq list
    set Lg [lrange $LNDG 1 end]
    set Ln {} ; set Ls {}
    foreach g $Lg {
	if {! [regexp {^Group} $g]} {continue}

	lappend Ln {}
	lappend Ls {}
	foreach nm [set SDG($g)] {
	    set i [lsearch -exact $Lns $nm]
	    set sq [lindex $Lns $i+1]
	    lappend Ls $sq
	    lappend Ln $nm
	}
	lappend Ln {}
	lappend Ls {}
    }

    return [list $Ln $Ls]
}


proc InsertionSequencesAPosition {Lnoms Lseqs Lnadd Lsadd iInsert} {
    # insertion after a given seq
    if {$iInsert eq "end"} {
	# find index of last non-empty element
	set i [expr {[llength $Lnoms] - 1}]
	set nom [string trim [lindex $Lnoms $i]]
	while {$nom eq ""} {
	    incr i -1
	    set nom [string trim [lindex $Lnoms $i]]
	}
    }
    
    incr i
    foreach n $Lnadd s $Lsadd {
	set Lnoms [linsert $Lnoms $i $n]
	set Lseqs [linsert $Lseqs $i $s]
	incr i
    }

    return [list $Lnoms $Lseqs]
}

proc PreComputeAddPDB {seqType} {
    global TAddS ListePDB

    set Lcmds [info commands]
    if {$seqType eq "pdbid"} {
	# First test if the command exists, i.e. already loaded : refused
	# only if its chains are already in this instance (the structure
	# may have been added to an other instance of the ORD file)
	if {$TAddS(StrucIdIn) in $Lcmds} {
	    set id $TAddS(StrucIdIn)
	    set Lnoms [lmap n $::LNOrdali {string trim $n}]
	    set Lchn [$id _chains -type Protein]
	    set Lici [lmap c $Lchn {
		set n [expr {[EstUnAccessPDB $id] ? [BonNomPDB "${id}_$c"] : "${id}_$c"}]
		expr {$n in $Lnoms ? $n : [continue]}
	    }]
	    if {$Lchn eq {} || [llength $Lici] == [llength $Lchn]} {
		FaireLire "The entry $TAddS(StrucIdIn) is already loaded !"
		return 0
	    }
	}

	# This can be either a PDB ID or a UniProt accesssion
	set ret [LoadNewStructure $TAddS(StrucIdIn) $TAddS(StrucIdIn)]
	lassign $ret what desc
	if {$what eq "StrucID"} {
	    set pdbid $desc
	} elseif {$what eq "Error"} {
	    FaireLire "Problem while retreiving structure !"
	    return 0
	}
    } else {
	# we have a structure file
	set ret [LoadNewStructure $TAddS(StrucFileIn)]
	lassign $ret what desc
	if {$what eq "StrucID"} {
	    set pdbid $desc
	} elseif {$what eq "Error"} {
	    FaireLire "Problem while retreiving structure !"
	    return 0
	}
    }
    set TAddS(currPDBId) $pdbid
    
    set Lchains [$pdbid _chains -type Protein]
    if {$Lchains == {}} {
	FaireLire "Error ! Structure >$pdbid< does not contain protein chains !"
	return 0
    }
    if {$TAddS(chnType) eq "chnid"} {
	set chn $TAddS(ChnId)
	if {$chn ni $Lchains} {
	    FaireLire "Chain >$chn< not in structure !"
	    return 0
	}
	set Lchains $chn
    }

    set LNAddSeq {}
    set LSAddSeq {}
    foreach c $Lchains {
	# _resname returns a list of residues
	set s [join [$pdbid _resname -chain $c -polymer] ""]
	if {[EstUnAccessPDB $pdbid]} {
	    set n [BonNomPDB "${pdbid}_$c"]
	} else {
	    set n "${pdbid}_$c"
	}
	    lappend LNAddSeq $n
	lappend LSAddSeq $s
    }

    return [list $LNAddSeq $LSAddSeq]
}


proc PreComputeAddDatabase {} {
    global TAddS
    
    set Lv $TAddS(SeqIdIn)
    set Lv [string map {"\n" " " , " "} $Lv]
    regsub -all { +} $Lv " " Lv
    set Lv [string toupper $Lv]
    set Lv [split $Lv]

    array set Res [FetchInfosSeqs $Lv]

    set Lnot  {}
    set LNAddSeq {}
    set LSAddSeq {}
    foreach n $Lv {
	if {[info exists Res($n,currAC)] && [info exists Res($n,Sequence)]} {
	    lappend LNAddSeq $Res($n,currAC)
	    lappend LSAddSeq $Res($n,Sequence)
	} else {
	    lappend Lnot $n
	}
    }

    if {$Lnot != {}} {
	FaireLire "Beware !\nThe following sequences were not found in databases :\n[join $Lnot \n]"
    }
    if {$LNAddSeq == {}} {
	return 0
    }

    return [list $LNAddSeq $LSAddSeq]
}


proc PreComputeAddSequenceFile {} {
    global TAddS ListePDB

    # Load sequences and verify format
    # Only MSF, TFA or ALN file format accepted
    set file $TAddS(SeqFileIn)
    set LNTank {}
    if {[EstLeBonFormat $file TFA]} {
	DecortiqueUnTFA $file LNTank TTank
    } elseif {[EstLeBonFormat $file ALN]} {
	DecortiqueUnALN $file LNTank TTank
    } elseif {[EstLeBonFormat $file MSF]} {
	DecortiqueUnMSF $file LNTank TTank
    } else {
	FaireLire "Error !\nOnly Fasta, Clustal or MSF file format accepted !"
	return 0
    }

    # Nothing read ...
    if {[llength $LNTank] == 0} {
	FaireLire "Error !\nNothing was read from the file $file !"
	
	return 0
    }

    set LNAddSeq {}
    set LSAddSeq {}
    foreach n $LNTank {
	set s $TTank($n)
	set nogap [string map {" " "" "~" "" "-" "" "." ""} $s]
	if {! [string length $nogap]} {
	    FaireLire "You have empty sequences !\n>$n< will be left out !"
	    continue
	}
	# No duplication of PDB sequences
	if {$n in $ListePDB} {
	    continue
	}

	lappend LNAddSeq $n
	lappend LSAddSeq $s
    }

    return [list $LNAddSeq $LSAddSeq]
}


proc CheckAddSeqsParameters {seqType} {
    global TAddS
    
    if {$seqType in {"seqfile" "pdbfile"}} {
	if {$seqType eq "pdbfile"} {
	    set key "StrucFileIn"
	} else {
		    set key "SeqFileIn"
	}
	
	if {$TAddS($key) eq ""} {
	    FaireLire "Please supply afile name !"
	    return 0
	}
	
	if {! [file exists $TAddS($key)]} {
	    FaireLire "The file :\n$TAddS($key)\ndoes not exists !"
	    return 0
	}
    } elseif {$seqType eq "database"} {
	# ask for UniProt/RefSeq accession/ID
		if {$TAddS(SeqIdIn) eq ""} {
	    FaireLire "Please supply UniProt/RefSeq accessions/IDs separated by commas or line feed !"
	    return 0
	}
    } else {
	# PDB or UniProt ID to download structure
	# Treat PDBIdIn
	# IDs are case insensitive, tests below and
	# structure names are upper-case
	set TAddS(StrucIdIn) [string toupper [string trim $TAddS(StrucIdIn)]]
		if {$TAddS(StrucIdIn) eq ""} {
	    FaireLire "Please supply a PDB or UniProt ID !"
	    return 0
	}

	set isPDB [EstUnAccessPDB $TAddS(StrucIdIn)]
	set isUniProt [EstUnAccUniProt $TAddS(StrucIdIn)]
	if {! $isPDB && ! $isUniProt} {
	    FaireLire "Please supply a valid PDB ID or UniProt accession"
	    return 0
	}
    }

    if {$TAddS(chnType) eq "chnid"} {
	set TAddS(ChnId) [string trim $TAddS(ChnId)]
	if {$TAddS(ChnId) eq ""} {
	    FaireLire "Provide a chain ID"
	    return 0
	}

	if {[string length $TAddS(ChnId)] > 1} {
	    FaireLire "The chain ID must be ONE letter long !"
	    return 0
	}
    }
    
    return
}


proc ComputeAddSeqs {seqType what} {
    global TAddS ListePDB LNOrdali LSOrdali LNSeqlab LSSeqlab Sequences TScrollY NomNomSeq NomTextSeq

    if {$what ne "ok"} {
	destroy $TAddS(win)
	unset TAddS
	return
    }

    set out [CheckAddSeqsParameters $seqType]
    if {$out == 0} {
	destroy $TAddS(win)
	unset TAddS
	return
    }
    
    FaireAttendre "Please wait ...\nLoading and parsing new sequences ..."
    
    # Record scrollbar position
    lassign [$TScrollY get] yscr tmp
    
    # destroy graphical interface
    # command is catch-ed in case this proc is called outside GUI !
    catch {destroy $TAddS(win)}
    update idletasks
    
    switch $seqType {
	"database" {set out [PreComputeAddDatabase]}
	"seqfile" {set out [PreComputeAddSequenceFile]}
	"pdbfile" -
	"pdbid" {set out [PreComputeAddPDB $seqType]}
    }
	    
    if {$out == 0} {
	unset TAddS
	FaireLaSuite
	return
    }

    # reference sequences
    if {! [InSeqlabMode]} {
	set LNomsOri $LNOrdali
    } else {
	set LNomsOri $LNSeqlab
    }
    set LSeqsOri [$NomTextSeq output all]
    
    # LNomsAli and LSeqsAli have NO empty sequences !
    set LNomsAli [lmap n $LNomsOri {if {[string trim $n] ne ""} {set n} {continue}}]
    set LSeqsAli [lmap s $LSeqsOri {if {[string trim $s] ne ""} {set s} {continue}}]
    
    # sequences to be added
    lassign $out LNTank LSTank

    # record sequence as structure if necessary
    if {$seqType in {"pdbid" "pdbfile"}} {
	foreach n $LNTank {
	    set pdbid [DonneIdDeAccessPDB $n]
	    set chn   [DonneChainDeAccessPDB $n]
	    if {$chn eq ""} {
		set chn "A"
	    }
	    # ListePDB holds the sequence names
	    # (PDB_1ABC_A, or Q12345_A for AlphaFold),
	    # not pdbid_chn : otherwise the new sequence
	    # is not seen as a structure (DonnePosSG ...)
	    if {$n ni $ListePDB} {
		lappend ListePDB $n
	    }

	    # if >n< is a uniprot , change it to pdb
	    if {[EstUnUniProt $n]} {
		set n "${n}_$chn"
	    }
	}
    }
    
    # Cleaning ...
    # If we have added a uniprot structure , check if it was already present in the alignment
    RetourneTableauAccession ::TDesAccess TAc

    set LNAddSeq {}
    set LSAddSeq {}
    foreach n $LNTank s $LSTank {
	# If <n> is an access uniprot, take its seqname counterpart
	if {[info exists TAc($n)]} {
	    set n $TAc($n)
	}
	# TAc covers all the instances : the sequence can
	# be added if it is not in this one
	if {$n in $LNomsAli} {
	    # sequence already exists
	    switch $TAddS(CopySkip) {
		1 {
		    continue
		}
		0 {
		    # the sequence already exists. So the new copy as index "__2" or more
		    set pi 2
		    while {"${n}__$pi" in $LNomsAli} {
			incr pi
		    }
		    set n "${n}__$pi"
		    }
	    }
	}
	set n [string trim $n]
	set SAddSeq($n) $s
	lappend LNAddSeq $n
	lappend LSAddSeq $s
    }

    # no sequences to add
    if {$LNAddSeq == {} } {
	FaireLaSuite
	FaireLire "There are no sequences to be added."
	unset TAddS
	return 0
    }

    # should we align the new sequences ?
    set DoAlign $TAddS(Align)
    if {$DoAlign} {
	# returned lists contains ALL sequences and no empty ones
	lassign [AlignSeqsAgainstReference $LNAddSeq $LSAddSeq $LNomsAli $LSeqsAli] LNAligned LSAligned aSAligned

	if {$LNAligned == {}} {
	    # Problem while aligning with Mafft ...
	    set DoAlign 0
	    set TAddS(Position) "end"
	} else {
	    # alignment worked OK !
	    array set SAligned $aSAligned

	    # record aligned sequences
	    set LSeqsAli [lmap n $LNomsAli {set SAligned($n)}]
	    set LSAddSeq [lmap n $LNAddSeq {set SAligned($n)}]

	    if {$seqType in {"pdbid" "pdbfile"} && $TAddS(chnType) eq "auto"} {
		# Determine the best chain
		set pdbid $TAddS(currPDBId)
		set Lchains [$pdbid _chains -type Protein]
		lassign [BestPDBChainByIdentity $LNAligned $LSAligned $pdbid $Lchains] closest best pcMax

		# Keep the best chain only
		foreach c $Lchains {
		    if {! [EstUnUniProt $pdbid]} {
			set nom [BonNomPDB "${pdbid}_$c"]
		    } else {
			set nom "${pdbid}_$c"
		    }
			if {$nom eq $best} {
			continue
		    }
		    set i [lsearch $LNAddSeq $nom]
		    set LNAddSeq [lreplace $LNAddSeq $i $i]
		    set LSAddSeq [lreplace $LSAddSeq $i $i]
		    # chain not kept : not a structure of
		    # the alignment
		    set ListePDB [lsearch -all -inline -exact -not $ListePDB $nom]
		    update
		}
	    }
	}
    }

    if {! $DoAlign} {
	# Do not align sequences, or alignment creation failed
	# Just add sequences, taking care of legth differences
	set LSAddSeq [DonneMemeLongueurListe $LSAddSeq "."]
	lassign [AdjusteLongueurSequences $LSeqsAli $LSAddSeq] LSeqsAli LSAddSeq
    }
    
    # Rebuild name/sequence lists as shown in GUI
    set tmpS {}
    foreach n $LNomsOri {
	set n [string trim $n]
	if {$n eq ""} {
	    lappend tmpS ""
	} else {
	    set i [lsearch $LNomsAli $n]
	    lappend tmpS [lindex $LSeqsAli $i]
	}
    }
    set LSeqsAli $tmpS
    set LNomsAli $LNomsOri
    
    # insertion of new sequences
    if {$TAddS(Position) eq "cluster"} {
	# choose closest cluster to insert each new sequence
	lassign [InsertionSequencesDansGroupes $LNomsAli $LSeqsAli $LNAddSeq $LSAddSeq] LNomsAli LSeqsAli
    } else {
	if {$TAddS(Position) eq "afterseq"} {
	    set i [lsearch -exact $LNomsAli $TAddS(seqInsert)]
	} else {
	    set i "end"
	}
	lassign [InsertionSequencesAPosition $LNomsAli $LSeqsAli $LNAddSeq $LSAddSeq $i] LNomsAli LSeqsAli
    }

    # update Sequences table
    foreach n $LNomsAli s $LSeqsAli {
	if {[string trim $n] ne ""} {
	    set Sequences($n) $s
	}
    }
    # special case for alphafold
    if {$seqType in {"pdbid" "pdbfile"}} {
	foreach n $LNAddSeq {
	    # names from PreComputeAddPDB already carry
	    # the chain (Q12345_A) : only add the _A entry
	    # for a bare UniProt name (else Q12345_A_A)
	    if {[EstUnUniProt $n] && [DonneChainDeAccessPDB $n] eq ""} {
		set i [lsearch $LNomsAli $n]
		set s [lindex $LSeqsAli $i]
		set Sequences(${n}_A) $s
	    }		
	}
    }

    # adjust features positions (sequences and names lists were
    # swapped : the features were never moved)
    UpdateFeaturesPositions $LNomsOri $LSeqsOri $LNomsAli $LSeqsAli
    InfosDesPDB
    
    # sequences have been checked
    InitInfoSeqs $LNAddSeq
    
    if {[InSeqlabMode]} {
	set LNSeqlab $LNomsAli
	set LSSeqlab [lmap s $LSeqsAli {split $s ""}]
    } else {
	set LNOrdali $LNomsAli
	set LSOrdali $LSeqsAli
	CalculeLesPCIDuMac
    }

    # Calculs divers
    AssigneLesPoids
    TraiteAABizarres
    CalculeLength
    CalculeComposition
    CalculePI
    CalculeMolecularWeight
    
    # Update Fenetre alignement
    MetAJourGroupes

    if {! [InSeqlabMode]} {
	InitWRegle
	AfficheRegle
    }
    
    set WdtNom [PlusLongEltDe $LNomsAli]
    if {$WdtNom > $::Defauts(LongNom)} {
	LesDefauts LongNom $WdtNom
	if {[info exists NomNomSeq]} { 
	    $NomNomSeq configure -state normal
	    $NomNomSeq configure -width $WdtNom 
	    $NomNomSeq configure -state disabled
	}
    }    

    ChangeNomsAff $::Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs

    # remet ascenceur
    CoupleY moveto $yscr

    update idletasks

    # the view has changed : it will be recorded in the
    # database when saving (needed by the ORD format)
    VueEditee 1

    FaireLaSuite

    return
}

    
proc WindowAddSeqs {what} {
    global TAddS ListePDB NomNomSeq LNDG Defauts LNOrdali

    set w .was
    if {[winfo exists $w]} {
	raise $w
	return
    }

    set TAddS(win) $w
    toplevel $w
    wm title $w "Add Sequences ..."
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    grid columnconfig $w 0 -weight 1
    grid rowconfig $w 0 -weight 1

    # Create Graphical Interface
    #
    # elements of the interface depends on the type of
    #  sequences to be added : PDB ID, PDB File or Sequence File

    set wf $w.ffile
    frame $wf
    grid $wf -row 0 -column 0 -sticky ew -padx 5 -pady 5
    
    if {$what eq "database"} {
	grid columnconfig $wf 1 -weight 1
	label $wf.lgen \
	    -font TitleFont \
	    -text "Give a UniProt/RefSeq accession/IDs list separated by commas or line feed" \
	    -fg $Defauts(ForeAppli) \
	    -relief flat
	label $wf.lbl \
	    -text "Accessions/IDs :" \
	    -relief flat
	entry $wf.eid \
	    -width 20 \
	    -textvariable TAddS(SeqIdIn) \
	    -background white
	grid $wf.lgen -row 0 -column 0 -columnspan 2 -sticky ew -padx 5 
	grid $wf.lbl -row 1 -column 0 -sticky w
	grid $wf.eid -row 1 -column 1 -sticky ew 
    } elseif {$what eq "pdbid"} {
	grid columnconfig $wf 1 -weight 1
	label $wf.lgen \
	    -font TitleFont \
	    -text "Give a PDB or UniProt IDin order to download the corresponding structure or Alphafold model." \
	    -fg $Defauts(ForeAppli) \
	-relief flat
	label $wf.lbl \
	    -text "PDB/UniProt ID : " \
	    -relief flat
	entry $wf.eid \
	    -width 15 \
	    -textvariable TAddS(StrucIdIn) \
	    -background white
	grid $wf.lgen -row 0 -column 0 -columnspan 2 -sticky ew -padx 5 
	grid $wf.lbl -row 1 -column 0 -sticky w
	grid $wf.eid -row 1 -column 1 -sticky ew 
    } else {
	# pdbfile or seqfile
	if {$what eq "pdbfile"} {
	    set textLabel "PDB or CIF (.cif / .mmcif) File :"
	    set key "StrucFileIn"
	} else {
	    set textLabel "Sequence File :"
	    set key "SeqFileIn"
	}

	label $wf.lbl \
	    -font TitleFont \
	-text "Please enter the name of a $textLabel " \
	    -relief flat
	entry $wf.ent \
	    -background white \
	    -textvariable TAddS($key)
	button $wf.but \
	    -text "Browse..." \
	    -background cyan \
	    -command "set TAddS($key) \[DemandeEtOuvreFichier *\]"
	grid $wf.lbl -row 0 -column 0 -columnspan 2 -sticky w
	grid $wf.ent -row 1 -column 0 -sticky ew
	grid $wf.but -row 1 -column 1 -sticky ew
    }
    
    set iRow 1

    # For PDB decide how to manage chains
    if {$what in {"pdbid" "pdbfile"}} {
	set wc $w.fchn
	frame $wc
	#grid columnconfig $wc 1 -weight 1
	grid $wc -row $iRow -column 0 -sticky ew -padx 5 -pady 5

	label $wc.lgen \
	    -relief flat \
	    -text "Define chain(s) to consider :" \
	-font TitleFont
	radiobutton $wc.rid \
	    -text "chain "\
	    -value "chnid" \
	    -relief flat \
	    -variable TAddS(chnType)
	entry $wc.eid \
	    -relief flat \
	    -background white \
	    -width 2 \
	    -textvariable TAddS(ChnId)
	radiobutton $wc.rau \
	    -text "automatically selected " \
	-value "auto" \
	    -relief flat \
	    -variable TAddS(chnType)
	radiobutton $wc.ral \
	    -text "take all" \
	-value "all" \
	    -relief flat \
	    -variable TAddS(chnType)
	grid $wc.lgen -row 0 -column 0 -columnspan 4
	grid $wc.rid -row 1 -column 0 -sticky w
	grid $wc.eid -row 1 -column 1 -sticky w
	grid $wc.rau -row 1 -column 2 -sticky ew
	grid $wc.ral -row 1 -column 3 -sticky e

	incr iRow
    }	

    # align Sequences
    set wa $w.fali
    frame $wa
    grid $wa -row $iRow -column 0 -sticky ew -padx 5
    label $wa.lgen \
	-relief flat \
	-text "The imported sequences should be :"
    radiobutton $wa.align \
	-text "aligned against the alignment (using MAFFT)" \
	-relief flat \
	-value 1 \
	-variable TAddS(Align)
    radiobutton $wa.alone \
	-text "kept unchanged" \
	-relief flat \
	-value 0 \
	-variable TAddS(Align)
    grid $wa.lgen -row 0 -column 0 -columnspan 2 -sticky w -padx 5 -pady {15 5}
    grid $wa.align -row 1 -column 0 -sticky w -padx {30 5}
    grid $wa.alone -row 1 -column 1 -sticky w
    
    # what to do with seqs already existing (in double) ?
    set wk $w.fck
    frame $wk
    grid $wk -row [incr iRow] -column 0 -sticky ew -padx 5
    grid columnconfig $wk {0 1} -weight 1
    label $wk.lbdup \
	-relief flat \
	-text "If a sequence name already exists in the alignment,"
    radiobutton $wk.copy \
	-text "create a copy" \
	-relief flat \
	-value 0 \
	-variable TAddS(CopySkip)
    radiobutton $wk.skip \
	-text "skip the imported sequence" \
	-relief flat \
	-value 1 \
	-variable TAddS(CopySkip)
    grid $wk.lbdup -row 0 -column 0 -columnspan 2 -sticky w -pady {15 5} -padx 5
    grid $wk.copy -row 1 -column 0 -sticky w -padx 5
    grid $wk.skip -row 1 -column 1 -sticky w
    
    # Define insertion point
    set wp $w.finsert
    frame $wp
    grid $wp -row [incr iRow] -column 0 -sticky ew -padx 5
    label $wp.lgen \
	-text "The imported sequences should be :" \
	-relief flat
    radiobutton $wp.bott \
	-relief flat \
	-text "inserted at the bottom of the alignment" \
	-value "end" \
	-variable TAddS(Position)
    radiobutton $wp.afse \
	-relief flat \
	-text "inserted after this sequence :" \
	-value "afterseq" \
	-variable TAddS(Position)
    set Lseqnames {}
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n ne ""} {
	    lappend Lseqnames $n
	}
    }
    set Lseqnames [linsert $Lseqnames 0 "Choose ..."]
    set width [PlusLongEltDe $Lseqnames]
    ttk::combobox $wp.cbs \
	-state readonly \
	-background white \
	-width $width\
	-values $Lseqnames
    bind $wp.cbs <<ComboboxSelected>> {set TAddS(seqInsert) [%W get]}
    grid $wp.bott -row 1 -column 0 -sticky w
    grid $wp.afse -row 1 -column 1 -sticky w
    grid $wp.cbs  -row 1 -column 2 -sticky w -padx {10 0}
    set ncol 3
    if {[llength $LNDG] > 1} {
	radiobutton $wp.clus \
	    -relief flat \
	    -text "inserted into their corresponding cluster \naccording to sequences identity" \
	    -justify left \
	    -value "cluster" \
	    -variable TAddS(Position)
	grid $wp.clus  -row 1 -column 3 -sticky w -padx {30 5}
	set ncol 4
    }
    grid $wp.lgen -row 0 -column 0 -columnspan $ncol -sticky w -pady {15 5} -padx 5

    # OK / Dismiss
    set wo $w.fbut
    frame $wo
    grid $wo -row [incr iRow] -column 0 -sticky ew -pady {40 10} -padx 5
    grid columnconfig $wo {0 1} -weight 1

    button $wo.dis \
	-background red \
	-text " Cancel " \
	-command [list ComputeAddSeqs $what dismiss]
    button $wo.ok \
	-background green1 \
	-text " OK " \
	-command [list ComputeAddSeqs $what ok]
    grid $wo.dis -row 0 -column 0 -sticky w -padx 5
    grid $wo.ok  -row 0 -column 1 -sticky e -padx 5

    FenetreAuCentre $w

    return
    }


proc AjouteSequenceOrPDB {{what "seqfile"}} {
    global LNSeqlab LSSeqlab LNOrdali LSOrdali LongueurTotale ListePDB Sequences TAddS NomNomSeq NomTextSeq
    
    if {[TypeAli] eq "pasdali"} {
	FaireLire "There are no sequences yet.\nPlease load an alignment first."
	return
    }
    
    if {[InSeqlabMode]} {
	FaireLire "You can't add sequences in Editor mode !\nLeave the Editor to add sequences."
	return
    }

    # Parameters used to add sequences are stored in table TaddS
    InitAddSeqs

    WindowAddSeqs $what

    return
}


proc DetruitLogConsole {what} {
    global wtlog TexteDuLog

    if {$what eq "clear"} {
	$wtlog delete 1.0 end
	set TexteDuLog ""

	return
    }

    if {[info exists wtlog] && [winfo exists $wtlog]} {
	destroy [winfo toplevel $wtlog]
	unset wtlog
    }

    update

    return
}


proc AuLogText {{args ""}} {
    global TexteDuLog Defauts
    
    switch [lindex $args 0] {
	"-nonewline" {
	    set bn ""
	    set txt [lindex $args 1]
	}
	"LClean" {
	    set TexteDuLog ""
	    return
	}
	"LOutput" {
	    set what [lindex $args 1]
	    if {$what eq ""} {
		set what HTML
	    }
	    set fout [lindex $args 2]
	    set add  [lindex $args 3]
	    OutputTLog $what "$TexteDuLog" $fout $add

	    return
	}
	default {
	    set bn "\n"
	    #set txt [join $args]
	    set txt $args
	}
    }
    
    # voir ordali_tlog ....
    if {$::Defauts(OnlyTLog) && ! [regexp {^@} $txt]} {
	set txt "@text $txt"
    }
    if {[regexp {^\@text} $txt]} {
	regsub -all "\n" $txt "AlALiGNe" txt
    } 
    #append TexteDuLog "${txt}$bn"
    lappend TexteDuLog $txt
    return
}


proc TraiteLogTampon {line} {
    global inBeginLog LogTampon

    switch -regexp -- $line {
	{^\@begin} {incr inBeginLog}
	{^\@end}   {incr inBeginLog -1}
    }
    append LogTampon $line

    set res ""
    if {! $inBeginLog} {
	set res [OutputTLog Text $LogTampon]
	set LogTampon ""
    }

    return $res
}


proc AuLogWindow {{args "JSuisBidon"}} {
    global TexteDuLog NomFenetreOrdali wtlog Defauts inBeginLog

    switch [lindex $args 0] {
	"-nonewline" {
	    set bn ""
	    set txt [lindex $args 1]
	}
	"LOutput" {
	    set what [lindex $args 1]
	    OutputTLog $what "$TexteDuLog"
	    return
	}
	default {
	    set bn "\n"
	    set txt [join $args " "]
	}
    }
    
    # see ordali_tlog ....
    if {[regexp {^\@text} $txt]} {
	regsub -all "\n" $txt "AlALiGNe" txt
    }

    if {! [info exists wtlog]} {
	set inBeginLog 0
	set wlog ".wlog"
	toplevel $wlog
	wm title $wlog "Ordalie Log Console"
	wm iconname $wlog "ordali log"
	wm protocol $wlog WM_DELETE_WINDOW KillParLaCroix
	lower $wlog $NomFenetreOrdali
	
	set wtlog "$wlog.frmt.text"
	frame $wlog.frmt
	grid $wlog.frmt -row 0 -column 0 -sticky news

	scrollbar $wlog.frmt.scrolly \
	    -width 8 \
	    -command "$wlog.frmt.text yview "
	scrollbar $wlog.frmt.scrollx \
	    -orient horiz \
	-width 8 \
	    -command "$wlog.frmt.text xview "
	text $wlog.frmt.text \
	    -height 25 -width 80 \
	    -yscrollcommand "$wlog.frmt.scrolly set" \
	    -xscrollcommand "$wlog.frmt.scrollx set" \
	    -font "Courier 10" \
	    -bg white
        grid $wlog.frmt.text -row 0 -column 0 -sticky news
	grid $wlog.frmt.scrolly -row 0 -column 1 -sticky ns
	grid $wlog.frmt.scrollx -row 1 -column 0 -sticky ew

	if {$::tcl_platform(platform) ne "unix"} {
	    bind $wlog.frmt.text <MouseWheel> {%W yview scroll [expr {-%D/120}] units ; break}
	} else {
	    bind $wlog.frmt.text <4> {%W yview scroll -[set Defauts(DeltaYScroll)] units ; break}
	    bind $wlog.frmt.text <5> {%W yview scroll  [set Defauts(DeltaYScroll)] units ; break}
	}
	
	ttk::frame $wlog.frmb \
	    -style FrmBtnCtrl.TFrame
	grid $wlog.frmb -row 1 -column 0 -sticky ew -padx 5 -pady 10
	
	button $wlog.frmb.save \
	    -text " Save " \
	    -background green1 \
	    -command "SauveLeLog"
	button $wlog.frmb.clear \
	    -text " Clear " \
	    -background white \
	    -command {DetruitLogConsole clear}
	button $wlog.frmb.destroy \
	    -text " Close " \
	    -background red \
	    -command [list ToggleAuLog]
	grid $wlog.frmb.destroy -row 0 -column 0 
	grid $wlog.frmb.clear -row 0 -column 1
	grid $wlog.frmb.save -row 0 -column 2
	
	set y [expr {[winfo screenheight $wlog] - 2*[winfo reqheight $wlog]}]
	
	wm geom $wlog +0+$y
	
	if {[set toPrint [OutputTLog Text $TexteDuLog]] ne ""} {
	    $wtlog insert end $toPrint
	    $wtlog see end
	}
    }
    
    if {$txt ne "JSuisBidon"} {
	append TexteDuLog "${txt}$bn"
	if {[set toPrint [TraiteLogTampon "${txt}$bn"]] ne ""} {
	    $wtlog insert end $toPrint
	    $wtlog see end
	}
    }

    return
}


proc AuLogOld args {
    global TexteDuLog Toggle NomFenetreOrdali wtlog

    if {![info exists TexteDuLog]} {set TexteDuLog ""}

    if {[lindex $args 0] eq "-nonewline"} {
	set bn ""
	set txt [lindex $args 1]
    } else {
	set bn "\n"
	set txt [join $args " "]
    }

    if {! [ModeI] || ! [info exists Toggle]} {
	# Dans tous les cas on ajoute au texte
	append TexteDuLog "$txt${bn}"
	return
    }

    if {$Toggle(AuLog)} {
	if {! [info exists wtlog]} {
	    set wlog ".wlog"
	    toplevel $wlog
	    wm title $wlog "Ordalie Log Console"
	    wm iconname $wlog "ordali log"
	    wm protocol $wlog WM_DELETE_WINDOW KillParLaCroix
	    lower $wlog $NomFenetreOrdali

	    set wtlog "$wlog.frmt.text"
	    frame $wlog.frmt
	    scrollbar $wlog.frmt.scroll \
		-width 8 \
		-command "$wlog.frmt.text yview "
	    text $wlog.frmt.text \
		-height 25 -width 80 \
		-yscrollcommand "$wlog.frmt.scroll set" \
		-font "Courier 10" \
		-bg white
	    pack $wlog.frmt.text -fill both -side left -expand 1
	    pack $wlog.frmt.scroll -side left -fill y
	    pack $wlog.frmt -side top

	    frame $wlog.frmb
	    pack $wlog.frmb -side bottom -fill x -padx 5 -pady 10

	    button $wlog.frmb.save -text " Save " -background green1 -command "SauveLeLog"
	    button $wlog.frmb.clear -text " Close " -background red -command "DetruitLogConsole"
	    pack $wlog.frmb.clear $wlog.frmb.save -side left -expand 1

	    set y [expr {[winfo screenheight $wlog] - 2*[winfo reqheight $wlog]}]

	    wm geom $wlog +0+$y

	    $wtlog insert end "$TexteDuLog${bn}"
	    $wtlog see end
	}

	$wtlog insert end "$txt${bn}"
	$wtlog see end
    }

    # Dans tous les cas on ajoute au texte
    append TexteDuLog "$txt${bn}"

    return
}


proc SequencesInformation {} {
    global LNOrdali TEdit nseqCurr
    global ListeDesAcidesAmines TDesSeqnames

    if {[TypeAli] eq "pasdali"} {
	return
    }

    # already here
    set w ".infoseq"
    if {[winfo exists $w]} {
	raise $w
	return
    }

    # LNOrdali always corresponds to seq-name
    set Ln {}
    foreach e $LNOrdali {
	set e [string trim $e]
	if {$e ne ""} {
	    lappend Ln [set TDesSeqnames($e)]
	}
    }
    set TEdit(win) $w
    set TEdit(Lvalues) $Ln
    
    # compute global alignment AA composition
    foreach {a p} [CompositionAADuGroupe] {
	set TEdit(compAll,$a) [format %5.1f $p]
    }

    # GUI
    toplevel $w
    wm title $w "Sequence Information"
    wm resizable $w 0 0
    # closing the window = Close (changes are kept)
    wm protocol $w WM_DELETE_WINDOW [list CloseInfoSeq $w]

    set wf "$w.f"
    frame $w.f
    grid $w.f -row 0 -column 0 -sticky news
    grid columnconfig $w 0 -weight 1
    grid rowconfig    $w 0 -weight 1
    grid columnconfig $wf all -weight 1
    grid rowconfig    $wf   1 -weight 1

    # first selected sequence, or the first one
    set nseq [lindex $Ln 0]
    foreach p $::NomSeqSel {
	set n [string trim [lindex $LNOrdali [lindex [split $p .] 0]-1]]
	if {$n ne "" && [info exists TDesSeqnames($n)]} {
	    set nseq $TDesSeqnames($n)
	    break
	}
    }
    RetourneTableau TDesSeqnames Tret
    set nseqCurr $Tret($nseq)

    set LMx [PlusLongEltDe $Ln]
    set TEdit(FWarn) $wf.top

    frame $wf.top
    label $wf.top.lab \
	-text "Sequence " \
	-font EdtTitre \
	-anchor w \
	-justify left
    set TEdit(nseqCombo) $nseqCurr
    ttk::combobox $wf.top.seq \
	-font EdtTitre \
    -background white \
	-width $LMx \
	-state readonly \
	-values $TEdit(Lvalues) \
	-textvariable TEdit(nseqCombo)
    $wf.top.seq current [lsearch -exact $Ln $nseq]
    set TEdit(combo) $wf.top.seq
    bind $wf.top.seq <<ComboboxSelected>> [list GetInfoOfSeq %W]
    grid $wf.top.lab -column 0 -row 0 -sticky w
    grid $wf.top.seq -column 1 -row 0 -sticky w
    grid $wf.top -row 0 -column 0 -columnspan 2 -sticky w -padx 10 -pady 15
    grid columnconfig $wf.top all -weight 1
    
    # two frames : left and right
    # left frame
    frame $wf.g
    # Frame infos generales
    set wgen $wf.g.gen
    labelframe $wgen \
	-borderwidth 2 \
	-relief groove \
	-font EdtTitre \
	-text "General" \
	-fg blue
    set l [LgtDescriptif]
    set nl [expr {$l/40+1>3?$l/40+1:3}]
    label $wgen.lsqn \
	-text "Sequence Name" \
	-anchor w \
	-justify left \
	-font EdtItem
    entry $wgen.esqn \
	-justify left \
	-textvariable TEdit(seqname)
    label $wgen.lacc \
	-text "Accession" \
	-anchor w -justify left -font EdtItem
    entry $wgen.eacc \
	-justify left \
	-textvariable TEdit(access)
    label $wgen.lnid \
	-text "Bank Id" \
	-anchor w -justify left -font EdtItem
    entry $wgen.enid \
	-justify left \
	-textvariable TEdit(bid)
    label $wgen.lec \
	-text "E.C." \
	-anchor w -justify left -font EdtItem
    entry $wgen.eec \
	-justify left \
	-textvariable TEdit(ec)
    set TEdit(tdes) "$wgen.edes"
    label $wgen.ldes \
	-text "Description" \
	-anchor w -justify left -font EdtItem
    text $wgen.edes \
	-width 30 \
	-relief flat \
	-height $nl \
	-wrap word \
	-state disabled
    # packing Frame Generales
    grid $wgen.lsqn -row 0 -column 0 -sticky ew
    grid $wgen.esqn -row 0 -column 1 -sticky ew
    grid $wgen.lacc -row 1 -column 0 -sticky ew
    grid $wgen.eacc -row 1 -column 1 -sticky ew
    grid $wgen.lnid -row 2 -column 0 -sticky ew
    grid $wgen.enid -row 2 -column 1 -sticky ew
    grid $wgen.lec  -row 3 -column 0 -sticky ew
    grid $wgen.eec  -row 3 -column 1 -sticky ew
    grid $wgen.ldes -row 4 -column 0 -sticky ne
    grid $wgen.edes -row 4 -column 1 -sticky ew
    grid $wgen -row 0 -column 0 -sticky news -padx {10 5} -pady 5
    grid columnconfig $wgen 0 -weight 0
    grid columnconfig $wgen 1 -weight 1

    # Frame infos Evolution/Phylogeny
    set wphy $wf.g.phy
    labelframe $wphy \
	-borderwidth 2 \
	-relief groove \
	-font EdtTitre \
	-text "Evolution / Phylogeny" \
	-fg blue
    label $wphy.lorg \
	-text "Organism" \
	-anchor w -justify left -font EdtItem
    entry $wphy.eorg \
	-justify left \
	-textvariable TEdit(orga)
    label $wphy.llfd \
	-text "Life domain" \
	-anchor w -justify left -font EdtItem
    ttk::combobox $wphy.elfd \
	-state readonly \
	-values [list "" Eukaryota Archaea Bacteria Viruses] \
	-textvariable TEdit(lifed)
    label $wphy.ltxd \
	-text "Taxa Id" \
	-anchor w -justify left -font EdtItem
    entry $wphy.etxd \
	-justify left \
	-textvariable TEdit(taxid)
    set TEdit(tlin) "$wphy.elin"
    label $wphy.llin \
	-text "Lineage" \
	-anchor w -justify left -font EdtItem
    text $wphy.elin \
	-width 30 \
	-relief flat \
	-height $nl \
	-wrap word \
	-state disabled
    # packing Frame Evolution/Phylogeny
    grid $wphy.lorg -row 0 -column 0 -sticky ew
    grid $wphy.eorg -row 0 -column 1 -sticky ew
    grid $wphy.llfd -row 1 -column 0 -sticky ew
    grid $wphy.elfd -row 1 -column 1 -sticky ew
    grid $wphy.ltxd -row 2 -column 0 -sticky ew
    grid $wphy.etxd -row 2 -column 1 -sticky ew
    grid $wphy.llin -row 3 -column 0 -sticky ew
    grid $wphy.elin -row 3 -column 1 -sticky ew
    grid $wphy -row 1 -column 0 -sticky news -padx {10 5} -pady 5
    grid columnconfig $wphy 0 -weight 0
    grid columnconfig $wphy 1 -weight 1
    grid $wf.g -row 1 -column 0 -sticky news
    grid rowconfig $wf.g 1 -weight 1

    # frame de droite
    frame $wf.d
    # Frame Physico-Chimie
    set wphc $wf.d.phc
    labelframe $wphc \
	-borderwidth 2 \
	-relief groove \
	-font EdtTitre \
	-text "Physico-chemistry" \
	-fg blue
    label $wphc.lmmw \
	-text "Molecular Weight (Da)" \
	-font EdtItem \
	-anchor w -justify right
    label $wphc.emmw \
	-anchor w -justify left \
	-textvariable TEdit(molw)
    label $wphc.llgt \
	-text "Length (aa)" \
	-font EdtItem \
	-anchor w -justify right
    label $wphc.elgt \
	-anchor w -justify left \
	-textvariable TEdit(length)
    label $wphc.lhyd \
	-text "Hydrophobicity Index" \
	-font EdtItem \
	-anchor w -justify right
    label $wphc.ehyd \
	-anchor w -justify left \
	-textvariable TEdit(hydro)
    label $wphc.lpis \
	-text "Isoelectric Point" \
	-font EdtItem \
	-anchor w -justify right
    label $wphc.epis \
	-anchor w -justify left \
	-textvariable TEdit(pi)
    # packing Frame Physico-Chimie
    grid $wphc.lmmw -row 0 -column 0 -sticky ew
    grid $wphc.emmw -row 0 -column 1 -sticky ew
    grid $wphc.llgt -row 1 -column 0 -sticky ew
    grid $wphc.elgt -row 1 -column 1 -sticky ew
    grid $wphc.lhyd -row 2 -column 0 -sticky ew
    grid $wphc.ehyd -row 2 -column 1 -sticky ew
    grid $wphc.lpis -row 3 -column 0 -sticky ew
    grid $wphc.epis -row 3 -column 1 -sticky ew
    grid $wphc -row 0 -column 0 -sticky news -padx {5 10} -pady 5
    
    # Frame composition
    set wcmp $wf.d.cmp
    labelframe $wcmp \
	-borderwidth 2 \
	-relief groove \
	-font EdtTitre \
	-text "Composition" \
	-fg blue
    set r 0
    set c -1
    foreach a $ListeDesAcidesAmines {
	if {$a eq "Z" || $a eq "X"} {
	    continue
	}
	incr c
	# 7 amino acids per row (21 with B : 3 rows)
	if {$c > 7} {
	    set c 0
	    incr r 4
	}
	if {$c == 0} {
	    label $wcmp.ls$r \
		-text "Seq" \
		-anchor center -justify right
	    label $wcmp.lg$r \
		-text "Grp" \
		-anchor center -justify right
	    label $wcmp.la$r \
		-text "All" \
		-anchor center -justify right
	    grid $wcmp.ls$r -row [expr {$r+1}] -column $c -sticky ew
	    grid $wcmp.lg$r -row [expr {$r+2}] -column $c -sticky ew
	    grid $wcmp.la$r -row [expr {$r+3}] -column $c -sticky ew
	    incr c
	}
	label $wcmp.l$a \
	    -text "$a" \
	    -font EdtItem \
	    -anchor center -justify center
	label $wcmp.es$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compaa,$a)
	label $wcmp.eg$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compGrp,$a)
	label $wcmp.ea$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compAll,$a)
	grid $wcmp.l$a -row $r -column $c -sticky ew
	grid $wcmp.es$a -row [expr {$r+1}] -column $c -sticky ew
	grid $wcmp.eg$a -row [expr {$r+2}] -column $c -sticky ew
	grid $wcmp.ea$a -row [expr {$r+3}] -column $c -sticky ew
    }

    incr r 5
    set c -1
    foreach a {"AILMV" "KRH" "DEQN" "FYW" "PGST"} {
	incr c
	if {$c == 0} {
	    label $wcmp.ls$r \
		-text "Seq" \
		-anchor center -justify right
	    label $wcmp.lg$r \
		-text "Grp" \
		-anchor center -justify right
	    label $wcmp.la$r \
		-text "All" \
		-anchor center -justify right
	    grid $wcmp.ls$r -row [expr {$r+1}] -column $c -sticky ew
	    grid $wcmp.lg$r -row [expr {$r+2}] -column $c -sticky ew
	    grid $wcmp.la$r -row [expr {$r+3}] -column $c -sticky ew
	    incr c
	}
	label $wcmp.l$a \
	    -text "$a" -font EdtItem \
	    -anchor w -justify center
	label $wcmp.es$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compaa,$a)
	label $wcmp.eg$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compGrp,$a)
	label $wcmp.ea$a \
	    -anchor w -justify left \
	    -textvariable TEdit(compAll,$a)
	grid $wcmp.l$a -row $r -column $c -sticky ew
	grid $wcmp.es$a -row [expr {$r+1}] -column $c -sticky ew
	grid $wcmp.eg$a -row [expr {$r+2}] -column $c -sticky ew
	grid $wcmp.ea$a -row [expr {$r+3}] -column $c -sticky ew
    }
    grid $wcmp -row 1 -column 0 -sticky news -padx {5 10} -pady 5
    grid $wf.d -row 1 -column 1 -sticky news
    grid rowconfig $wf.d 1 -weight 1

    # Frame Boutons
    frame $wf.btn
    set TEdit(butok) $wf.btn.ok
    button $wf.btn.ok \
	-text " Close " \
	-bg green1 \
	-command "CloseInfoSeq $w"
    grid $wf.btn.ok -row 0 -column 0
    grid $wf.btn -row 2 -column 0 -columnspan 2 -sticky ew -pady 15
    grid columnconfig $wf.btn 0 -weight 1

    InfosDeLaSeq

    FenetreAuCentre $w
    update idletasks

    return
}


proc CloseInfoSeq {w} {
    global nseqCurr TEdit TDesSeqnames

    set nseqCombo [$TEdit(combo) get]
    RetourneTableau TDesSeqnames Tret
    set nseqCurr $Tret($nseqCombo)

    CheckChangesInSequenceInformation
    
    if {[VueEditee]} {
	#SauveLeMac 0
    }

    unset -nocomplain TEdit
    destroy $w

    ChangeNomsAff $::Defauts(NomsAffiches)
    AdjustNamesWidgetWidth
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs
    # life domains may have changed
    MetAJourPhylumArbre
    
    return
}


proc AcceptInfoSeq {w} {
    global Defauts TEdit {*}[info globals "TD*"] LNOrdali
    
    set nseqIn $TEdit(nseqCombo)
    set nseq [set TEdit(corr,$nseqIn)]
    if {$nseq in $LNOrdali} {
	FaireLire "Warning !\nSequence Name already exists ! Sequence Name should be unique !\nPlease choose an other Sequence Name for this sequence."
	
	return
    }
    
    foreach e [lsort [array names TEdit "*,*"]] {
	lassign [split $e ,] k nseqIn
	if {$k in {"corr" "compaa" "compGrp" "compAll"}} {
	    continue
	}
	
	set r [set TEdit($e)]
	switch $k {
	    "seqname" {
		set LT [array get TDesSeqnames]
		set Lr [lmap {a b} $LT {set $b}]
		if {[llength [lsearch -all $Lr $r]] == 1} {
		    set TDesSeqnames($nseq) $r
		}
	    }
	    "access" {set TDesAccess($nseq) $r}
	    "bid"    {set TDesBId($nseq) $r}
	    "desc"   {set TDesDescriptifs($nseq) $r}
	    "ec"     {
		if {! [EstUnEC $r]} {
		    FaireLire "Warning !\nThe E.C. number of sequence $nseq is badly formatted !\n It should be made of 4 positives numbers,\nseparated by a point character (.)."
		    return
		}
		set TDesEC($nseq) $r
	    }
	    "taxid"  {set TDesTaxId($nseq) $r}
	    "groupe" {set TDuGroupeDesSeqs($nseq) $r}
	    "orga"   {set TDesOrganismes($nseq) $r}
	    "frag"   {set TDesFragment($nseq) $r}
	    "lifed"  {set TDesPhylum($nseq) $r}
	}
    }
    
    destroy $w
    
    EnregistreInfosSeqs

    ChangeNomsAff $Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs
    
    return
}


proc LitTextesInfoSeq {} {
    # Description and Lineage are edited in text widgets,
    # not linked to TEdit : read them back
    global TEdit

    foreach k {desc lineage} wt {tdes tlin} {
	if {[info exists TEdit($wt)] && [winfo exists $TEdit($wt)]} {
	    set TEdit($k) [string trim [$TEdit($wt) get 1.0 end-1c]]
	}
    }

    return
}


proc CheckChangesInSequenceInformation {} {
    global nseqCurr TEdit {*}[info globals "TD*"] LNOrdali seqnameChanged

    LitTextesInfoSeq

    # It is important to check the seqname first
    # as everything is referenced with it
    set seqnameChanged 0
    set TEdit(seqname) [string trim $TEdit(seqname)]
    if {$TEdit(seqname) ne $TDesSeqnames($nseqCurr)} {
	set Lautres {}
	foreach n [array names TDesSeqnames] {
	    if {$n ne $nseqCurr} {
		lappend Lautres $TDesSeqnames($n)
	    }
	}
	if {$TEdit(seqname) eq "" || [regexp {\s} $TEdit(seqname)]} {
	    FaireLire "Warning !\nSequence Name can not be empty or contain spaces !\nSequence Name of $TDesSeqnames($nseqCurr) is not changed."
	    set TEdit(seqname) $TDesSeqnames($nseqCurr)
	} elseif {$TEdit(seqname) in $Lautres} {
	    FaireLire "Warning !\nSequence Name $TEdit(seqname) already exists ! Sequence Name should be unique !\nSequence Name of $TDesSeqnames($nseqCurr) is not changed."
	    set TEdit(seqname) $TDesSeqnames($nseqCurr)
	} else {
	    set seqnameChanged 1
	}
    }

    # E.C. : 4 fields, '-' allowed for partial numbers
    set TEdit(ec) [string trim $TEdit(ec)]
    if {$TEdit(ec) ne "" && ! [regexp {^[0-9]+\.([0-9]+|-)\.([0-9]+|-)\.(n?[0-9]+|-)$} $TEdit(ec)]} {
	FaireLire "Warning !\nThe E.C. number $TEdit(ec) is badly formatted !\nIt should be made of 4 numbers separated by a point (.), like 6.1.1.12 or 6.1.-.-\nE.C. number is not changed."
	set TEdit(ec) $TDesEC($nseqCurr)
    }

    # Taxa Id : an integer
    set TEdit(taxid) [string trim $TEdit(taxid)]
    if {$TEdit(taxid) ne "" && ! [string is integer -strict $TEdit(taxid)]} {
	FaireLire "Warning !\nThe Taxa Id $TEdit(taxid) should be an integer !\nTaxa Id is not changed."
	set TEdit(taxid) [expr {[info exists TDesTaxId($nseqCurr)] ? $TDesTaxId($nseqCurr) : ""}]
    }

    set hasChanged 0
    foreach key {seqname access bid desc ec groupe orga frag lifed taxid lineage } tb {TDesSeqnames TDesAccess TDesBId TDesDescriptifs TDesEC TDuGroupeDesSeqs TDesOrganismes TDesFragment TDesPhylum TDesTaxId TDuLineage} {
	set old ""
	if {[info exists ${tb}($nseqCurr)]} {
	    set old [set ${tb}($nseqCurr)]
	}
	if {$key eq "lineage"} {
	    # lineage is stored as a list of taxa
	    set new [LineageEnListe $TEdit(lineage)]
	    if {[join $new] eq [join [LineageEnListe [join $old]]]} {
		continue
	    }
	} else {
	    # ignore leading/trailing blanks (text widgets)
	    set new $TEdit($key)
	    if {[string trim $new] eq [string trim $old]} {
		continue
	    }
	}

	set hasChanged 1
	set ${tb}($nseqCurr) $new
	if {$key ne "seqname"} {
	    lappend Lchg $key $new
	}
    }

    # information of the sequence (table seqinfo, shared by the
    # instances) : written now, otherwise lost when the ORD file is
    # saved and opened again. A new Sequence Name is recorded when the
    # instance is saved (VerifSeqs creates the sequence of this name)
    if {[info exists Lchg]} {
	EcritInfosSeqDansBase $nseqCurr $Lchg
	FichierModifie 1
    }
    if {$seqnameChanged} {
	VueEditee 1
    }

    return
}


proc EcritInfosSeqDansBase {nseq Lchg} {
    # Lchg : key value ... (keys of the Sequence Information window)
    array set Col {access access bid bid desc description ec ec groupe cgroup orga organism frag fragment lifed phylum taxid taxid lineage lineage}

    foreach {k v} $Lchg {
	if {! [info exists Col($k)]} {
	    continue
	}
	set c $Col($k)
	if {$v eq ""} {
	    $::db eval "update seqinfo set $c = NULL where seqname = :nseq"
	} else {
	    $::db eval "update seqinfo set $c = :v where seqname = :nseq"
	}
    }

    return
}


proc GetInfoOfSeq {w} {
    global nseqCurr TDesSeqnames seqnameChanged LNOrdali
    
    CheckChangesInSequenceInformation

    if {$seqnameChanged} {
	set idx [$w current]
	set Ln {}
	foreach n $LNOrdali {
	    if {[string trim $n] ne ""}  {
		lappend Ln $TDesSeqnames($n)
	    }
	}
	$w configure -values $Ln
	$w current $idx
    }
    
    set nseqCombo [$w get]
    RetourneTableau TDesSeqnames Tret
    set nseqCurr $Tret($nseqCombo)

    InfosDeLaSeq

    return
}


proc InfosDeLaSeq {} {
    global nseqCurr TEdit {*}[info globals "TD*"]
    global ListeDesAcidesAmines GroupeDeLaSequence

    set ww [set TEdit(FWarn)]
    if {[winfo exists ${ww}.wrn]} {
	grid forget ${ww}.wrn
	destroy ${ww}.wrn
    }
    
    if {[ExisteAABizarres $nseqCurr]} {
	label ${ww}.wrn \
	    -background red -foreground white \
	    -text "Warning !\n The values given below\nare only indicative as this sequence\ncontains unhandled amino acids" \
	    -justify left -anchor w
	grid ${ww}.wrn -column 2 -row 0 -pady 10 -padx 10 -sticky w
    }
    
    set TEdit(seqname) [set TDesSeqnames($nseqCurr)]
    set TEdit(access)  [set TDesAccess($nseqCurr)]
    set TEdit(bid)     [set TDesBId($nseqCurr)]
    set TEdit(desc)    [set TDesDescriptifs($nseqCurr)]
    set TEdit(ec)      [set TDesEC($nseqCurr)]
    set TEdit(groupe)  [set TDuGroupeDesSeqs($nseqCurr)]
    set TEdit(orga)    [set TDesOrganismes($nseqCurr)]
    set TEdit(frag)    [set TDesFragment($nseqCurr)]
    set TEdit(lifed)   [set TDesPhylum($nseqCurr)]
    set TEdit(taxid)   [set TDesTaxId($nseqCurr)]
    set TEdit(lineage) [join [set TDuLineage($nseqCurr)]]
    set TEdit(pi)      [format %.2f [set TDespI($nseqCurr)]]
    set TEdit(molw)    [format %.2f [set TDesMolW($nseqCurr)]]
    set TEdit(hydro)   [set TDesHydro($nseqCurr)]
    set TEdit(length)  [DonneLongueurDe $nseqCurr]
    set TEdit(comppc)  [set TDesCompos($nseqCurr,pc)]
    foreach a $ListeDesAcidesAmines v [set TDesCompos($nseqCurr,aa)] {
	if {$v eq ""} {
	    set v 0.0
	}
	set TEdit(compaa,$a) [format "%5.1f" $v]
    }
    foreach a {"AILMV" "KRH" "DEQN" "FYW" "PGST"} v [set TDesCompos($nseqCurr,pc)] {
	if {$v eq ""} {
	    set v 0.0
	}
	set TEdit(compaa,$a) [format "%5.1f" $v]
    }
    if {[set grp [set GroupeDeLaSequence($nseqCurr)]] eq "Group0"} {
	set grp ""
    }
    foreach {a p} [CompositionAADuGroupe $grp] {
	set TEdit(compGrp,$a) [format %5.1f $p]
    }

    if {[info exists TEdit(tdes)]} {
	[set TEdit(tdes)] configure -state normal
	[set TEdit(tdes)] delete 1.0 end
	[set TEdit(tdes)] insert end [set TEdit(desc)]
	#[set TEdit(tdes)] configure -state disabled

	[set TEdit(tlin)] configure -state normal
	[set TEdit(tlin)] delete 1.0 end
	[set TEdit(tlin)] insert end [set TEdit(lineage)]
	#[set TEdit(tlin)] configure -state disabled
    }

    return
}


proc LongInfoSeq {n} {
    global TDesOrganismes TDesDescriptifs TDesBId TDesAccess TDesLength
    
    set Org "Unknown"
    set Des "None"
    
    set Acc [set TDesAccess($n)]
    set Bid [set TDesBId($n)]
    set Org [set TDesOrganismes($n)]
    set Des [set TDesDescriptifs($n)]
    set Len [set TDesLength($n)]
    
    set D 0
    set nl -1
    while {$D < [string length $Des]} {
	incr nl
	set F [expr {$D+29}]
	set ib [string wordstart [string range $Des $D $F] $F]
	if {$ib <= 0} {
	    set Ic 30
	} else {
	    set Ic $ib
	    set F [expr {$D+$ib-1}]
	}
	set L [string range $Des $D $F]
	incr D $Ic
	set TDes($nl) $L
    }
    
    set rep "Acc ...: $Acc\n"
    append rep "BId ...: $Bid\n"
    append rep "Org ...: $Org\n"
    append rep "Len ...: $Len\n"
    foreach l [lsort -integer [array names TDes]] {
	if {$l == 0} {
	    set pref "Des ...:"
	} else {
	    set pref "       :"
	}
	append rep "$pref [set TDes($l)]\n"
    }

	return $rep
    }


proc Nuancier {n {c1 "red"} {c2 "blue"}} {
	if {[ModeI]} {
	    lassign [winfo rgb . $c1] r1 g1 b1
	    lassign [winfo rgb . $c2] r2 g2 b2
	} else {
	    lassign [RGBDeLaTkCol $c1] r1 g1 b1
	    lassign [RGBDeLaTkCol $c2] r2 g2 b2
	    # RGBDeLaTkCol : reel entre 0. et 1.
	    foreach k {r1 g1 b1 r2 g2 b2} {
		set $k [expr {[set $k]*255}]
	    }
	}

	# Normalize intensities to 0 to 255, 1 byte colors
	foreach el {r1 g1 b1 r2 g2 b2} {
	    set $el [expr {[set $el] * 255 / 65535}]
	}

	if {$n == 1} {
	    set r_step 0.0 ; set g_step 0.0 ; set b_step 0.0
	} else {
	    set r_step [expr {abs($r2 - $r1) / ($n-1)}]
	    set g_step [expr {abs($g2 - $g1) / ($n-1)}]
	    set b_step [expr {abs($b2 - $b1) / ($n-1)}]
	}

	set steps {}
	for {set i 0} {$i < $n} {incr i} {
	    set r [expr {int($r_step * $i)}]
	    set g [expr {int($g_step * $i)}]
	    set b [expr {int($b_step * $i)}]

	    lappend steps [format "#%02X%02X%02X" $r $g $b]
	}

	return $steps
    }


    proc AppliqueCouleurs {type w} {
	global ListePDB

	if {[QuelMode] eq "seqlab"} {
	    global LNSeqlab LSSeqlab

	    set LesSeqs $LSSeqlab
	    set LesNoms $LNSeqlab
	} else {
	    global LNOrdali LSOrdali

	    set LesSeqs $LSOrdali
	    set LesNoms $LNOrdali
	}

	# configuration tags
	set Lgaa [list STAC DE ILMV FYW P RK Q G HN SPC]
	#    set Lfreg [list "S|T|A|C" "D|E" "I|L|M|V" "F|Y|W" "p" "R|K" "Q" "G" "H|N" "\\\."]
	set Lfreg [list "S|T|A|C" "D|E" "I|L|M|V" "F|Y|W" "P" "R|K" "Q" "G" "H|N"]

	set y 0
	foreach s $LesSeqs n $LesNoms {
	    incr y
	    if {[string trim $n] eq ""} {continue}
	    if {[string trim $n] in $ListePDB} {continue}
	    foreach a $Lgaa freg $Lfreg {
		set lt {}
		set lv [regexp -all -inline -indices -- $freg $s]
		foreach e $lv {
		    lassign $e d f 
		    lappend lt $y.$d $y.[expr {$f+1}]
		}
		if {$lt != {}} {$w tag add Tag$a {*}$lt}
	    }
	}

	update idletasks

	return
    }

    # la proc de JJG
proc TailleFonte {{increment ""}} {
    #rR modifié 2023/02/27 
    #set size [font configure SeqFont -size]
    set size $::Defauts(SeqFontSize)
    puts "size in $size"
	if {$increment=="" || $increment==0} {
	    return $size
	}

	set Ok 0
	#rR attentin on ne fait que des increments de 1 même si on demande plus ... a corriger ailleurs d'abord
	if {[regexp {^\+[0-9]+$}    $increment]} {
	    set Ok 1
	    incr size
	}
	if {[regexp {^\-[0-9]+$}    $increment]} {
	    set Ok 1
	    incr size -1
	}
	if {[regexp {^[1-9][0-9]?$} $increment]} {
	    set Ok 1
	    set size $increment
	}
	if { ! $Ok } {
	    return $size
	}
	#Espionne size $size
	if {$size > 2 && $size < 55} {
	    $::NomTextSeq font size $size
	    $::NomNomSeq font size $size
	    $::WTexteRegle font size $size

	    # retreive real size. It was read in "font metrics", whose
	    # 6th element is the line height in pixels (-linespace), not
	    # the font size : each change, even "smaller", made the font
	    # bigger. Old biotext versions have no "font size" getter.
	    if {! [catch {$::NomNomSeq font size} s] && [string is integer -strict $s] && $s > 0} {
		set size $s
	    }

	    font configure SeqFont -size $size
	    set ::Defauts(SeqFontSize) $size
	}
    puts "size out $size"
	update idletasks
	ReDessineLesScores

	return $size
    }


proc SwitchWindows {sens} {
	#return
	set Stack [wm stackorder .]
	
	if {$sens eq "up"} {
	    set w [lindex $Stack 0]
	    wm attributes $w -topmost 1
	} else {
	    set uw [lindex $Stack end]
	    set w  [lindex $Stack end-1]
	    lower $uw
	}
	
	update idletasks
	
	return
    }


proc OrdaliDefaultMapping {} {
    set map [set ::Defauts(Mapping)]
    $::NomTextSeq mapping $map
	
    return
}


proc OrdaliDefaultTags {} {
    $::NomNomSeq configure -state normal
    $::NomNomSeq tag state on
    $::NomNomSeq tag configure InvNm -background black -foreground white
    #$::NomNomSeq tag configure PDB -background red -foreground black
    $::NomNomSeq tag configure PDB -background "#cca9dd" -foreground black

    # tags for phylum coloring
    $::NomNomSeq tag configure NPEuk \
	-background $::Defauts(BgEukaryota) \
	-foreground $::Defauts(FgEukaryota)
    $::NomNomSeq tag configure NPArk \
	-background $::Defauts(BgArchaea) \
	-foreground $::Defauts(FgArchaea)
    $::NomNomSeq tag configure NPPro \
	-background $::Defauts(BgBacteria) \
	-foreground $::Defauts(FgBacteria)
    $::NomNomSeq tag configure NPVir \
	-background $::Defauts(BgViruses) \
	-foreground $::Defauts(FgViruses)

	$::NomNomSeq configure -state disabled

	$::NomTextSeq tag state on
	$::NomTextSeq tag configure Fnd -foreground black -background white
	$::NomTextSeq tag configure Hel -foreground black -background red
	$::NomTextSeq tag configure She -foreground black -background green1
	$::NomTextSeq tag configure Tur -foreground black -background cyan
	$::NomTextSeq tag configure H31 -foreground black -background magenta
    $::NomTextSeq tag configure Marque -background black -foreground black
	return
    }


    proc ResizeApp2 {w NewH NewW} {
	global OldAppW OldAppH AppChangeSize NomNomSeq NomTextSeq NomFenetreOrdali
	#JeMeSignale
	update idletasks

	
	global ZeMessage
	#rR j'ai enlevé la fenetre mess
	if {0 && ! [winfo exists .mess]} {
	    toplevel .mess
	    label .mess.lab \
		-fg white -bg black \
		-font "Helvetica 22 bold" \
		-textvariable ZeMessage
	    grid .mess.lab -row 0 -column 0 -sticky news
	    FenetreAuCentre .mess
	}
	set ZeMessage "VIDE !"
	Espionne Zoomed [wm attributes . -zoomed] fullscreen [wm attributes . -fullscreen]
	if {1 || [wm attributes . -zoomed]} {
	    set HNom [winfo height $NomNomSeq]
	    set HSeq [winfo height $NomTextSeq]
	    set HFnt [font metrics SeqFont -linespace]

	    puts "Nom $HNom"
	    puts "Seq $HSeq"
	    if {1 || $HNom != $HSeq} {
		set nLines [expr {$HSeq / $HFnt}]
		puts "$HNom != $HSeq $HSeq / $HFnt [expr {$HSeq / $HFnt}] "
		puts "nLines $nLines x HFnt $HFnt = [expr {$nLines * $HFnt}] "
		bind $::NomFenetreOrdali <Configure> ""
		update idletasks
		$NomNomSeq configure -height $nLines
		$NomTextSeq configure -height $nLines
		update idletasks
		#bind $::NomFenetreOrdali <Configure> {ResizeApp2 %W %w %h}
		Espionne nouveau Nom [winfo height $NomNomSeq]
		Espionne nouveau Seq [winfo height $NomTextSeq]
		append ZeMessage "\nNom $HNom Seq $HSeq nLines $nLines"
	    }
	}

	return
	
	if {[QuelMode] ne "feature"} {return}
	if {$AppChangeSize} {return}

	bind $::NomFenetreOrdali <Configure> ""
	set AppChangeSize 1
	if {abs($OldAppW-$NewW) > 50 || abs($OldAppH-$NewH) > 50} {
	    # ChangeMode sans arguments recharge le mode
	    ChangeMode
	    set OldAppH $NewH
	    set OldAppW $NewW
	}
	set AppChangeSize 0
	update

	#bind $::NomFenetreOrdali <Configure> {ResizeApp2 %W %w %h}
	#bind $::NomTextSeq <Configure> {ResizeApp2 %W %w %h ; break}

	return
    }


    proc FromMenu {w mode} {
	if {$mode eq "overview"} {
	    AfficheOverview
	    
	    return
	}
	if {$mode eq "couleurs"} {
	    ToggleMapResidues

	    return
	}
	if {[QuelMode] in {"ordali" "feature"}} {
	    ChangeMode $mode
	}
	
	return
    }


    proc BindMenuItems {{what "bind"}} {
	set tw [winfo toplevel $::NomFenetreOrdali]

	if {$what eq "bind"} {
	    # Modes shortcuts / Raccourcis
	    bind $tw <A> {FromMenu %W annotation}
	    bind $tw <C> {FromMenu %W conservation}
	    bind $tw <E> {FromMenu %W seqlab}
	    bind $tw <F> {FromMenu %W feature}
	    bind $tw <G> {FromMenu %W cluster}
	    bind $tw <I> {FromMenu %W donnepci}
	    bind $tw <M> {FromMenu %W search}
	    bind $tw <O> {FromMenu %W overview}
	    bind $tw <Q> {FromMenu %W couleurs}
	    bind $tw <S> {FromMenu %W superpose}
	    bind $tw <T> {FromMenu %W arbres}
	} else {
	    # remove bindings
	    bind $tw <A> ""
	    bind $tw <C> ""
	    bind $tw <E> ""
	    bind $tw <F> ""
	    bind $tw <G> ""
	    bind $tw <I> ""
	    bind $tw <M> ""
	    bind $tw <O> ""
	    bind $tw <Q> ""
	    bind $tw <S> ""
	    bind $tw <T> ""
	}

	return
    }


    proc BindModeColors {} {
	set Ls [bindtags $::TScrollX]
	set Ls [linsert $Ls 1 BScCols]
	bindtags $::TScrollX $Ls

	set Ls [bindtags $::TScrollY]
	set Ls [linsert $Ls 1 BScCols]
	bindtags $::TScrollY $Ls

	set Lt [bindtags $::NomTextSeq]
	set Lt [linsert $Lt 1 BColors BTxCols]
	bindtags $::NomTextSeq $Lt

	set Lt [bindtags $::NomNomSeq]
	set Lt [linsert $Lt 1 BColors]
	bindtags $::NomNomSeq $Lt

	return
    }


    proc BindModeNormal {} {
	# BNum : a number then an arrow key scrolls the view
	set LNTags [list all . $::NomFenetreOrdali Biotext BFocus BFont BNLab BNSel BWhN BNum $::NomNomSeq]
	set LSTags [list all . $::NomFenetreOrdali Biotext BFocus BFont BTLab BWhS BNum BTStatus $::NomTextSeq]
	bindtags $::NomNomSeq  $LNTags
	bindtags $::NomTextSeq $LSTags
	
	# saving shortcut
	bind . <Control-Key-s> [list SauveLAlignement]
	
	update idletasks
	
	return
    }


    proc BindModeSelection {} {
	set state [$::NomTextSeq cget -state]
	$::NomTextSeq configure -state normal
	$::NomTextSeq tag configure Marque -background black -foreground black
	$::NomTextSeq tag configure slct -background LightGrey -foreground black
	
	# once : a second BTSel would select every range twice
	set lt [bindtags $::NomTextSeq]
	if {"BTSel" ni $lt} {
	    set lt [linsert $lt 1 BTSel]
	    bindtags $::NomTextSeq $lt
	}

	$::NomTextSeq configure -state $state

	return
    }


proc BindModeSeqlab {} {
    # BTSeqlab before Biotext : its bindings replace some of the
    # class ones (BackSpace, Shift-Left/Right) to keep LSSeqlab up to date
    set LStags [list all . $::NomFenetreOrdali BTSeqlab Biotext BFont BFocus BWhS BNum BTStatus $::NomTextSeq]
    bindtags $::NomTextSeq $LStags
    
    set LNtags [list all . $::NomFenetreOrdali Biotext BFocus BFont BNLab BNSel BWhN BNum $::NomNomSeq]
    bindtags $::NomNomSeq $LNtags
	
    #bind $::NomNomSeq  <M> {ChangeMode search}
    #bind $::NomTextSeq <M> {ChangeMode search}
	
    # backup current alignment
    bind all <Control-Key-t> {SauveTempSeqlab}
	
    update idletasks
	
    return
}


proc BindingsOrdali {} {
    global Defauts PosInitNom NomTextSeq tcl_platform NomFenetreOrdali
    
    # Always active
    bind all <Alt-F4> {AdieuOrdali}
    bind all <Alt-p> {wm attributes . -fullscreen 1 ; puts "Zoomed !"}
    
    bind BFocus <Enter> {focus %W}
    
    # labels
    # names : description
    #bind BNLab <Any-Motion> {ShowDescription @%x,%y}
    #bind BNLab <Any-Leave>  {ShowDescription -1.-1}
    #bind BNLab <ButtonPress-3> [list ShowNameContextMenu @%x,%y]
    bind BNLab <ButtonPress-3> [list ShowLongInfoSeq "%x,%y"]
    bind BNLab <ButtonRelease-3> [list ShowLongInfoSeq -1,-1]

    # On text, show tags, pointer location
    bind BTLab <Any-Motion> [list ShowFeatureDescription @%x,%y]
    bind BTLab <Any-Leave>  [list ShowFeatureDescription @%x,%y 0]
    bind BTLab <Double-1> [list ChangeFeatAffOrder @%x,%y]
    
    # Cut / Copy / Paste
    bind BNSel <Control-Key-x> CutLesNoms
    bind BNSel <Control-Key-c> CopyLesNoms
    bind BNSel <Control-Key-v> PasteLesNoms
    
    # Selection seq names
    bind BNSel <1> {SelectNomSeq "une" "@0,%y"}
    bind BNSel <Control-1> {SelectNomSeq ctr "@0,%y"}
    bind BNSel <Shift-1>    {SelectNomSeq shf "@0,%y"}
    bind BNSel <Control-Key-a> {SelectNomSeq all "@0,%y"}
    
    # selection of alignment zone
    bind BTSel <1> {StockPosition %W @%x,%y}
    bind BTSel <3> {SelectLesColonnes @%x,%y}
    bind BTSel <Control-3> {DeselectLesColonnes %W @%x,%y}
    # columns of the displayed feature item under the pointer
    bind BTSel <Control-1> {SelectLaFeature @%x,%y ; break}
    
    # Status pos seq - gen
    bind BTStatus <Any-Motion> [list AffichePosGenSeq %W @%x,%y]
    
    # Status pos seq - gen SeqLab MODE !
    #bind BTStatusSL <Any-Motion> [list AffichePosGenSeqSL %W @%x,%y]
    
    # MouseWheel
    # name frame
    if {1 && $::tcl_platform(platform) ne "unix"} {
	bind BWhN <MouseWheel> {CoupleY scroll [expr {-%D/120}] units ; break}
	bind BWhN <Control-MouseWheel> {CoupleX scroll [expr {-%D/120}] units ; break}
    } else {
	bind BWhN <4> {CoupleY scroll -[set Defauts(DeltaYScroll)] units ; break}
	bind BWhN <5> {CoupleY scroll  [set Defauts(DeltaYScroll)] units ; break}
	bind BWhN <Control-4> {CoupleX scroll -[set Defauts(DeltaXScroll)] units ; break}
	bind BWhN <Control-5> {CoupleX scroll  [set Defauts(DeltaXScroll)] units ; break}
    }
    # sequence frame
    if {1 && $::tcl_platform(platform) ne "unix"} {
	bind BWhS <Control-MouseWheel> {CoupleX scroll [expr {-%D/120}] units ; break}
	bind BWhS <MouseWheel> {CoupleY scroll [expr {-%D/120}] units ; break}
    } else {
	bind BWhS <Control-4> {CoupleX scroll -[set Defauts(DeltaXScroll)] units ; break}
	bind BWhS <Control-5> {CoupleX scroll  [set Defauts(DeltaXScroll)] units ; break}
	bind BWhS <4> {CoupleY scroll -[set Defauts(DeltaYScroll)] units ; break}
	bind BWhS <5> {CoupleY scroll  [set Defauts(DeltaYScroll)] units ; break}
    }
    
    # SEQLAB
    bind BSvSeqlab <Control-Key-t> SauveTempSeqlab
    # lettres .... Faudra faire diff entre prot et RNA
    bind BTSeqlab <KeyPress-space> {BindTextSpace %W nogroup}
    bind BTSeqlab <Shift-KeyPress-space> {BindTextSpace %W}
    # editions otherwise done by the biotext class bindings :
    # done here, then LSSeqlab and the ruler are updated.
    # (BTSeqlab is before Biotext in the bindtags, see BindModeSeqlab)
    bind BTSeqlab <BackSpace>       {ActionSeqlab %W backspace ; break}
    bind BTSeqlab <Shift-BackSpace> {ActionSeqlab %W sbackspace ; break}
    bind BTSeqlab <Shift-Left>      {ActionSeqlab %W left ; break}
    bind BTSeqlab <Shift-Right>     {ActionSeqlab %W right ; break}
    set Lc [split "acdefghiklmnpqrstvwxy" ""]
    foreach c $Lc {
	bind BTSeqlab "<KeyPress-$c>" {BindTextKey %W %A ; break}
	#bind BTSeqlab "<Shift-KeyPress-$c>" [list BindTextKey %W %A ; break]
    }
    
    # font size and screen size
    bind BFont <Control-KP_Add>  [list TailleFonte +2]
    bind BFont <Control-plus>    [list TailleFonte +2]
    bind BFont <Control-equal>   [list TailleFonte +2]
    bind BFont <Control-minus>   [list TailleFonte -2]
    bind BFont <Control-KP_Subtract> [list TailleFonte -2]
    
    # Configure
    set ::AppChangeSize 0
    set ::OldAppW 0 ; set ::OldAppH 0
    #bind $NomFenetreOrdali <Configure> {ResizeApp2 %W %w %h}

    # fullscreen, frame seq
    bind . <Control-KeyPress-F1> {ToggleFullScreen ; break}
    
    bind $NomFenetreOrdali <KeyPress-F2> ToggleShowSeqFrame
    
    # Arrows, preceded by a number : move n times.
    # The digits are recorded by the Biotext class bindings
    # (::tk::biotext::bufferNTimes, see lib/biotext1.0/biotext.tcl)
    bind BNum <Left>  {MoveToPos %W -1  0}
    bind BNum <Right> {MoveToPos %W  1  0}
    bind BNum <Up>    {MoveToPos %W  0 -1}
    bind BNum <Down>  {MoveToPos %W  0  1}

    set ::ZoneSelect {}
    set ::PosInitNom -1.-1

    bind all <Control-Shift-r> [list \
				    source [file join $::OrdSrcDir ordali_source.tcl] \
				    FaireLire "Re-read done"]

    return
}

proc bufferNTimes {what {n ""}} {
    global BufNTimes

    set res 1
    switch $what {
	"add" {append BufNTimes $n}
	"empty" {
	    if {$BufNTimes ne ""} {
		set res $BufNTimes
		set BufNTimes ""
	    }
	}
    }

    return $res
}


proc MoveToPos {w x y} {
    # Arrow keys, possibly preceded by a number n (typed on the
    # keyboard or the keypad) :
    # - Editor : the cursor moves n residues / lines,
    # - otherwise : the view scrolls n columns / lines.
    set n [::tk::biotext::bufferNTimes "empty"]
    if {! [string is integer -strict $n] || $n < 1} {
	set n 1
    }
    set t $::NomTextSeq

    if {$w ne $t || [$t cget -state] eq "disabled"} {
	if {$x} {
	    CoupleX scroll [expr {$x*$n}] units
	}
	if {$y} {
	    CoupleY scroll [expr {$y*$n}] units
	}
	update idletasks
	return
    }

    # editor : cursor kept inside the alignment
    lassign [split [$t cursor] .] r c
    # last line with a sequence (the list ends with separators)
    set nl [llength $::LNSeqlab]
    while {$nl > 1 && [string trim [lindex $::LNSeqlab $nl-1]] eq ""} {
	incr nl -1
    }
    set lg [LongueurAlignement seqlab]
    set r [expr {min(max($r + $n*$y, 1), $nl)}]
    set c [expr {min(max($c + $n*$x, 0), $lg - 1)}]
    $t cursor $r.$c
    $t see $r.$c
    # names and ruler follow the view
    $::NomNomSeq yview moveto [lindex [$t yview] 0]
    CoupleX moveto [lindex [$t xview] 0]
    update idletasks

    return
}


proc AddSpaceSeq {} {
    global LNSeqlab LSSeqlab LNOrdali LSOrdali NomTextSeq NomNomSeq NomSeqSel TScrollY
    
    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[llength $NomSeqSel] != 1} {
	FaireLire "Please select one sequence below\nwhich a separator should be inserted !"
	return
    }
    
    # store Y-scroll position
    lassign [$TScrollY get] ysc tmp
    
    lassign [split $NomSeqSel .] y x 
    set idx [expr {$y+1}]
    # a row beyond the alignment makes Biotext crash
    set nRows [llength [expr {[InSeqlabMode] ? $LNSeqlab : $LNOrdali}]]
    if {! [string is integer -strict $y] || $y < 1 || $y >= $nRows} {
	FaireLire "Please select one sequence below\nwhich a separator should be inserted !"
	return
    }

    if {[InSeqlabMode]} {
	set char "."
	set len [LongueurDeLAlignement seqlab]
    } else {
	VueEditee 1
	set char " "
	set len [LongueurDeLAlignement]
    }

    set sepNom [string repeat " " [string length [lindex $LNOrdali 0]]]
    set sepSeq [string repeat $char $len]
    puts ""
    puts "sepNom [string length $sepNom]"
    puts "sepSeq [string length $sepSeq]"
    
    $NomNomSeq configure -state normal
    #$NomNomSeq insert rows $y-1 1
    $NomNomSeq addseqs [list $sepNom] [expr {$y-1}]
    $NomNomSeq configure -state disabled
    
    $NomTextSeq configure -state normal
    #$NomTextSeq insert rows $y-1 1
    $NomTextSeq addseqs [list $sepSeq] [expr {$y-1}]
    if {! [InSeqlabMode]} {
	$NomTextSeq configure -state disabled
	
	set LNOrdali [linsert $LNOrdali $y $sepNom]
	set LSOrdali [linsert $LSOrdali $y $sepSeq]
    } else {
	set LNSeqlab [linsert $LNSeqlab $y $sepNom]
	set LSSeqlab [linsert $LSSeqlab $y $sepSeq]
    }
    
    MetAJourGroupes
    
    # re-position at original Y
    CoupleY moveto $ysc
    
    return
}


proc RemoveSpaceSeq {} {
    global NomTextSeq NomNomSeq NomSeqSel LSOrdali LNOrdali LNSeqlab LSSeqlab Defauts TScrollY
    
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {[llength $NomSeqSel] != 1} {
	FaireLire "Please select the sequence below which the separator should be removed !"
	return
    }
    
    if {! [InSeqlabMode]} {
	set LNoms $LNOrdali
    } else {
	set LNoms $LNSeqlab
    }
    
    lassign [split $NomSeqSel .] y x 
    set i [expr {$y+1}]
    if {$i >= [llength $LNoms]} {
	return
    }
    if {[string trim [lindex $LNoms $y]] ne ""} {
	return
    }
    
    # store Y-scroll position
    lassign [$TScrollY get] ysc tmp

    $NomNomSeq configure -state normal
    $NomNomSeq delete rows $y
    $NomNomSeq configure -state disabled
    
    if {! [InSeqlabMode]} {
	VueEditee 1
	
	$NomTextSeq configure -state normal
    }
    $NomTextSeq delete rows $y
    update idletasks

    if {! [InSeqlabMode]} {
	$NomTextSeq configure -state disabled

	set LNOrdali [lreplace $LNOrdali $y $y]
	set LSOrdali [lreplace $LSOrdali $y $y]
    } else {
	set LNSeqlab [lreplace $LNSeqlab $y $y]
	set LSSeqlab [lreplace $LSSeqlab $y $y]
    }
    
    MetAJourGroupes

    ChangeNomsAff $Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs

    # re-position at original Y
    CoupleY moveto $ysc
    
    return
}


proc FlagFeatureScore {e} {
    foreach f [array names ::ScoreMeth "*,Edit"] {
	set ::ScoreMeth($f) $e
    }

    return
}


proc EstCeUnPoint {pos t} {
    global LesPointsDuGroupe LNDG

    # ici on travaille avec string index --> commence a 0
    incr pos -1
    set ng [expr {[llength $LNDG]-2}]
    if {$ng > 3	&& [regexp "CoulG" $t]} {
	set nb [string range $t 5 end]
	set g [lindex $LNDG $nb]
	set str [set LesPointsDuGroupe($g)]

	if {[string index $str $pos] != " "} {
	    return 1
	} else {
	    return 0
	}
    }

    if {$ng <= 3} {
	foreach n [lrange $LNDG 1 end-1 ] {
	    set str [set LesPointsDuGroupe($n)]
	    if {[string index $str $pos] != " "} {
		return 1
	    }
	}
    }

    return 0
}


proc SauveLeLog {{fichier ""}} {
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {$fichier eq ""} {
	set fichier [DemandeEtSauveFichier "all"]
	if {$fichier eq ""} {
	    return
	}
    }

    set f [CheckOpen $fichier]
    if {$f eq ""} {
	return
    }
    global TexteDuLog
    if {[info exists TexteDuLog]} {
	puts $f [OutputTLog Text $TexteDuLog]
    }
    close $f

    return
}


proc AskFeatureFile {} {
    set w .askfeatfile
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    frame $w.top
    grid $w.top -row 0 -column 0

    label $w.top.titre \
	-font TitleFont \
	-text "Supply a feature file. "
    

    return
}


proc TotalWindowSize {win} {
    set top [winfo toplevel $win]
    wm geometry $top +2+2
    update idletasks

    # Recuperation geometrie (avec decoration)
    # Scan de la geometrie pour extraire les champs
    set g [wm geometry $top]
    scan $g "%dx%d%d%d" w h x y
    set w [winfo width $top]
    set h [winfo height $top]

    # Position absolue de la fenetre
    set tx [winfo rootx $top]
    set ty [winfo rooty $top]

    # Epaisseur de la bordure
    set borderw [expr {$tx-$x}]

    # Hauteur de la barre de titre
    set titleh [expr {$ty-$y}]
    #On peut alors, en supposant que la bordure est la
    #meme a gauche a droite et en bas, et que la barre
    # de titre est en haut, "deviner" les dimensions 
    # totales du toplevel
    set totalwidth  [expr {$w + 2*$borderw}]
    set totalheight [expr {$h + $titleh + $borderw}]

    return [list $totalwidth $totalheight]
}


proc FenetreAuCentre {f} {
    set win [winfo toplevel $f]

    lassign [TotalWindowSize $win] wdt hgt 
    scan [wm geometry $win] "%dx%d%d%d" w h x y

    if {0} {
	puts "enter [wm geometry $win] $w x $h $x $y"
	puts "width $w height $h"
	puts "screen width [winfo screenwidth .] screen height [winfo screenheight .]"
    }
    set x [expr {[winfo screenwidth  .]/2 - $w/2}]
    set y [expr {[winfo screenheight .]/2 - $h/2}]
    #puts "out $x $y"
    if {$x < 0} {set x 10}
    if {$y < 0} {set y 10}

    #set x 25 ; #rR 
    
    wm geometry $win ${w}x${h}+$x+$y

    return
}



proc KillParLaCroix {} {
    return
}


proc NYI {} {
    FaireLire "Not yet implemented !"
    return
}


proc FaireAttendre {tx {AvecPB 0}} {
    global tcl_platform TFAt Defauts FAPG
    
    if {1} {
	Espionne "\n-- FaireAttendre ------"
	Espionne "=> $tx"
	Espionne "------------------\n"
    }
    
    if {! [ModeI] && ! $Defauts(MarcheForcee)} {
	return
    }

    if {[info exists TFAt(WtLabel)]} {
	lappend TFAt(WtMsg) [$TFAt(WtLabel) cget -text]
	lappend TFAt(WithPB) [winfo ismapped $TFAt(WtPbar)]
	$TFAt(WtLabel) configure -text $tx
	if {$AvecPB} {
	    grid .fattendre.f.pbar -row 1 -column 0 -sticky ew -padx 10 -pady {1 10}
	    .fattendre.f.pbar start
	} else {
	    grid forget .fattendre.f.pbar
	}

	update idletasks

	return
    }

    set TFAt(oldFocus) [focus]
    
    set w .fattendre
    toplevel $w
    wm title $w "Please Wait ..."
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm attributes $w -topmost 1
    wm resizable $w 0 0
    # wm overrideredirect $w 1
    if {$tcl_platform(platform) eq "macintosh"} {
	unsupported1 style $w dBoxProc
    }

    set FAPG 0.
    set TFAt(Top) $w
    set TFAt(WtLabel) ".fattendre.f.label"
    set TFAt(WtPbar)  ".fattendre.f.pbar"
    frame $w.f
    label $w.f.label \
	-background cyan \
	-justify left -anchor nw \
	-text $tx 
    ttk::progressbar $w.f.pbar \
	-variable FAPG

    grid $w.f.label -row 0 -column 0 -sticky news -padx 10 -pady {10 5}
    grid $w.f.pbar  -row 1 -column 0 -sticky ew -padx 10 -pady {0 10}
    grid rowconfig    $w.f 0   -weight 1 -minsize 0
    grid columnconfig $w.f all -weight 1 -minsize 0

    grid $w.f -row 0 -column 0 -sticky news
    grid columnconfig $w all -weight 1
    grid rowconfig    $w all -weight 1

    if {"FontFAtt" ni [font names]} {
	set fdef [$w.f.label cget -font]
	set fml  [font configure $fdef -family]
	set size [font configure $fdef -size]
	font create FontFAtt -family $fml -size $size
    }
    $w.f.label configure -font FontFAtt

    if {! $AvecPB} {
	grid forget $w.f.pbar
	$w.f.pbar stop
    } else {
	$w.f.pbar start
    }
    update idletasks
    bind $w <Visibility> {raise [winfo toplevel %W] ; wm attributes [winfo toplevel %W] -topmost}
    
    FenetreAuCentre $w

    set TFAt(oldGrab) [grab current $w]
    if {$TFAt(oldGrab) ne ""} {
	set TFAt(grabStatus) [grab status $TFAt(oldGrab)]
    } else {
	set TFAt(grabStatus) ""
    }

    grab $w
    focus $w

    MesCouleurs $w
    raise $w

    update idletasks

    return
}


proc FaireLaSuite {{w ""}} {
    global TFAt Defauts

    if {! [ModeI] && ! $Defauts(MarcheForcee)} {
	return
    }
    if {! [winfo exists .fattendre]} {
	return
    }

    if {[info exists TFAt(WtMsg)]} {
	$TFAt(WtLabel) configure -text [lindex $TFAt(WtMsg) end]
	if {[lindex $TFAt(WithPB) end]} {
	    grid .fattendre.f.pbar -row 1 -column 0 -sticky news -padx 10 -pady {1 10}
	    .fattendre.f.pbar start
	} else {
	    grid forget .fattendre.f.pbar
	}

	set TFAt(WtMsg) [lreplace $TFAt(WtMsg) end end]
	set TFAt(WithPB) [lreplace $TFAt(WithPB) end end]
	if {! [llength $TFAt(WtMsg)]} {
	    array unset TFAt "WtMsg"
	    array unset TFAt "WithPB"
	}
	update

	return
    }

    wm protocol .fattendre WM_DELETE_WINDOW ""
    if {[winfo exists TFAt(oldFocus)]} {
	focus $TFAt(oldFocus)
    } else {
	array unset TFAt oldFocus
    }
    destroy .fattendre

    if {$TFAt(oldGrab) ne ""} {
	if {$TFAt(grabStatus) ne "global"} {
	    catch {grab $TFAt(oldGrab)}
	} else {
	    catch {grab -global $TFAt(oldGrab)}
	}
    }
    unset TFAt

    update idletasks

    return
}


proc EnfonceBtnFeature {w} {

    $w configure \
	-relief sunken \
	-background red \
	-activebackground red \
    -foreground white
    LesFeaturesUtilisees [$w cget -text] 1

    return
}


proc ReleveBtnFeature {w} {

    $w configure \
	-relief raised \
	-background green1 \
	-activebackground green1 \
	-foreground black
    LesFeaturesUtilisees [$w cget -text] 0

    return
}


proc EtatSeqsOut {quoi} {
    global LNOrdali SeqsOut NomSeqSel

    if {! [info exists NomSeqSel] || $NomSeqSel == {} } {return}

    if {$quoi eq "bloque"} {
	set Etat 1
    } else {
	set Etat 0
    }

    foreach e $NomSeqSel {
	lassign [split $e .] y x
	set seqass [string trim [lindex $LNOrdali $y]]
	if {$seqass eq ""} {
	    continue
	} else {
	    set SeqsOut($seqass) $Etat
	}
    }

    return
}


proc EtatBouton {b} {
    # returns :
    #   - 0 if button is RAISED
    #   - 1 if button is SUNKEN

    if {[$b cget -relief] eq "raised"} {
	return 0
    } else {
	return 1
    }
}


proc ResetDesBoutons {} {
    if {[QuelMode] ne "feature"} {
	return
    }
    
    foreach c [winfo children $::FrmBtnFea] {
	if {[EtatDuBouton $c]} {
	    ChangeEtatBouton $c
	}
    }

    update idletasks

    return
}


proc BtnDeLaFeature {f} {
    foreach c [winfo children $::FrmBtnFea] {
	if {[string trim [$c cget -text]] eq $f} {
	    return $c
	}
    }

    return ""
}


proc LesBoutonsEnfonces {{quoi "features"}} {
    global FrmBtnFea

    if {! [info exists FrmBtnFea] || ! [winfo exists $FrmBtnFea]} {
	return {}
    }

    set Lb {}
    foreach c [winfo children $FrmBtnFea] {
	if {[EtatDuBouton $c]} {
	    if {$quoi eq "features"} {
		lappend Lb [$c cget -text]
	    } else {
		lappend Lb $c
	    }
	}
    }

    return $Lb
}


proc ListeDesFeaturesUtilisees {} {
    if {! [info exists ::LFeatCourantes]} {
	#set ::LFeatCourantes {}
	set ::LFeatCourantes [LesBoutonsEnfonces]
    }

    return $::LFeatCourantes
}


proc LesFeaturesUtilisees {ft etat} {
    global LFeatCourantes
    
    if {! [info exists LFeatCourantes]} {
	set LFeatCourantes [LesBoutonsEnfonces]
    }
    
    if {$etat} {
	set LFeatCourantes [linsert $LFeatCourantes 0 $ft]
    set LFeatCourantes [lunique $LFeatCourantes]
    } else {
	set i [lsearch $LFeatCourantes $ft]
	set LFeatCourantes [lreplace $LFeatCourantes $i $i]
    }
    
    return $LFeatCourantes
}


proc EtatDuBouton {btn} {
    if {[$btn cget -relief] == "raised"} {
	return 0
    } else {
	return 1
    }
}


proc AutresNomsAff {quoi} {
    if {[TypeAli] eq "pasdali"} {
	return
    }
    ChangeNomsAff $quoi
    AdjustNamesWidgetWidth
    AfficheNomsEtSeqs
    RepeintNoms

    return
}


proc ChangeEtatBouton {btn} {
    global EtatBtnFeat
    
    set Relief [$btn cget -relief]
    if {$Relief eq "raised"} {
	EnfonceBtnFeature $btn
	set EtatBtnFeat($btn) 1
    } else {
	ReleveBtnFeature $btn
	set EtatBtnFeat($btn) 0
    }

    return [set EtatBtnFeat($btn)]
}


proc FromScrollYBiotext2Names {args} {
    # le widget biotext envoie un ordre pour que la scrollbar 
    # se reajuste EN TANT QUE WIDGET, pas qu'elle renvoie les 
    # infos aux widget auxquels elle est attaché, sinon on 
    # ferait une boucle ! 
    # mais il faut quand meme mettre à jour le widget noms
    
    $::NomNomSeq yview moveto [lindex $args 0]
    $::TScrollY set {*}$args

    return
}


proc CoupleY {args} {
    $::NomTextSeq yview {*}$args
    $::NomNomSeq  yview {*}$args

    return
}


proc CoupleX {args} {
    global Toggle FrmSequence WTexteRegle NomTextSeq
    
    $NomTextSeq  xview {*}$args
    $WTexteRegle xview {*}$args
    update idletasks

    if {! [set Toggle(Scores)]} {
	return
    }

    # The score frame is visible, updat position
    $FrmSequence.csc xview moveto [lindex [$FrmSequence.scrollxseq get] 0]
    update idletasks
    
    return
}


proc ChangeFeatAffOrder {pos} {
    set Lt [$::NomTextSeq tag names [$::NomTextSeq index $pos]]

    set LtF [lsearch -all -inline -regexp $Lt "FX_"]
    if {[llength $LtF] > 1} {
	$::NomTextSeq tag raise [lindex $LtF 0]
    }
    set LtD [lsearch -all -inline -regexp $Lt "FDisp_"]
    if {[llength $LtD] > 1} {
	$::NomTextSeq tag raise [lindex $LtD 0]
    }

    return
}



proc ShowFeatureDescription {pxy {show 1}} {
    set note ""
    if {$show} {
	set Ltg [$::NomTextSeq tag names $pxy]
	set Lf [lsearch -all -inline -glob $Ltg "FDisp_*"]
	foreach f $Lf {
	    lappend note [string range $f [string first "_" $f]+1 end]
	}
	# annotations of the snapshot
	foreach f [lsearch -all -inline -glob $Ltg "Anno_*"] {
	    set pk [string range $f 5 end]
	    if {[info exists ::AnnoTxt($pk)] && $::AnnoTxt($pk) ne ""} {
		lappend note $::AnnoTxt($pk)
	    }
	}
    }
    
    MontreCacheMessageSurSeq $pxy $note

    return
}


proc ShowLongInfoSeq_notready {nom} {
    set WindowLongDes "$::NomFenetreOrdali.longinfo"

    frame $WindowLongDes

    set LongDes [LongInfoSeq $nom]
    text $WindowLongDes.t \
    -relief flat \
	-width 30 \
	-wrap word \
	-background LightYellow \
	-foreground black \
	-highlightthickness 3
    $WindowLongDes.f.t insert end $LongDes

    button $WindowLongDes.f.b \
	-text " Close " \
	-background green1 \
	-command [list destroy $WindowLongDes]
    grid $WindowLongDes.f.t -row 0 -column 0 -sticky news
    grid $WindowLongDes.f.b -row 1 -column 1 -stickiy ew -pady {20 10}

    return
}


proc ShowLongInfoSeq {{pos ""}} {
    global NomNomSeq LNOrdali LNSeqlab WOrdali

    if {$pos eq "-1,-1"} {
	set Idx "0.0"
	set des ""
    } else {
	set Idx [$NomNomSeq index @$pos]
	lassign [split $Idx .] y x
	if {[InSeqlabMode]} {
	    set nom [lindex $LNSeqlab $y-1]
	} else {
	    set nom [lindex $LNOrdali $y-1]
	}
	if {[string trim $nom] eq ""} {
	    return
	}
	set des [LongInfoSeq $nom]
    }

    MontreCacheLongInfoSeq $Idx $des

    return
}


proc ShowDescription {pxy} {
    global NomNomSeq TDesDescriptifs LNOrdali LNSeqlab

    if {! [info exists TDesDescriptifs]} {return}
    if {$pxy eq "-1.-1"} {
	set ledes ""
    } else {
	lassign [split [$NomNomSeq index $pxy] .] y x 
	if {[QuelMode] eq "seqlab"} {
	    set nom [lindex $LNSeqlab $y-1]
	} else {
	    set nom [lindex $LNOrdali $y-1]
	}
	if {$nom eq ""} {return}
	if {[info exists TDesDescriptifs($nom)]} {
	    set ledes [set TDesDescriptifs($nom)]
	} else {
	    set ledes ""
	}
    }

    MontreCacheLeDescriptif $pxy $ledes

    return
}


proc AffichePosGenSeq {w {pos ""}} {
    # return conditions
    if {[TypeAli] eq "pasdali" || $pos eq ""} {
	return
    }
    
    lassign [split [$w index $pos] .] y x 
    if {! [string is integer -strict $y]} {
	return
    }
    
    if {[InSeqlabMode]} {
	set LNoms $::LNSeqlab
    } else {
	set LNoms $::LNOrdali
    }
    if {[set nom [string trim [lindex $LNoms $y-1]]] eq ""} {
	return
    }
    set seq [$::NomTextSeq output $y]
    
    set ::XGen [expr {$x+1}]
    set ::XSeq [DonnePosGS_new $nom $x $seq]

    return
}


proc AffichePosGenSeqSL {w {pos ""}} {
    # ==> Pour le Mode SeqLab !!
    #
    # return conditions
    if {[TypeAli] eq "pasdali"} {
	return
    }
    
    lassign [split [$w index $pos] .] y x 
    if {! [string is integer -strict $y]} {
	return
    }

    if {[set nom [string trim [lindex $::LNSeqlab $y-1]]] eq ""} {
	return
    }
    
    set ::XGen [expr {$x+1}]
    set ::XSeq [DonnePosGS_SL $nom $w $y $x]

    return
}


proc MontreCacheMessageSurSeq {pos {note ""}} {
    set winMsg $::NomFenetreOrdali.message
    if {$note eq ""} {
	if {[winfo exists $winMsg]} {
	    destroy $winMsg
	}
	set ::notePrev ""

	return
    }

    # Display note at given position 
    # compute position relative to master window
    lassign [winfo pointerxy $::NomFenetreOrdali] px py
    set rx [winfo rootx $::NomFenetreOrdali]
    set ry [winfo rooty $::NomFenetreOrdali]
    set x [expr {$px-$rx}]
    set y [expr {$py-$ry-10}]

    set note [join $note \n]
    set note [string map {_ " "} $note]
    if {! [info exists ::notePrev]} {
	set ::notePrev ""
    }
    if {$note ne $::notePrev} {
	if {[winfo exists $winMsg]} {
	    destroy $winMsg
	}
	message $winMsg \
	    -borderwidth 3 \
	    -relief raise \
	    -width 800 \
	    -justify left \
	    -text $note \
	    -background "lightyellow" \
	    -foreground "black"

	place $winMsg \
	    -x $x -y $y \
	    -anchor sw \
	    -in $::NomFenetreOrdali

	set ::notePrev $note
    } else {
	# note == notePrev, just move it
	place configure $winMsg \
	    -x $x -y $y
    }

    return
}


proc MontreCacheLeDescriptif {pos {des ""}} {
    global CestLeMessage NomFenetreOrdali

    if {[info exists CestLeMessage]} {destroy $CestLeMessage}
    if {$des == ""} {return}

    regsub -all "_" $des " " des
    set TexteActions "$des"
    set CestLeMessage "$NomFenetreOrdali.des"

    set px [winfo pointerx $NomFenetreOrdali]
    set py [winfo pointery $NomFenetreOrdali]
    set ry [winfo rooty $NomFenetreOrdali]
    set rx [winfo rootx $NomFenetreOrdali]

    set x [expr {$px-$rx}]
    set y [expr {$py-$ry-10}]

    message $CestLeMessage \
	-borderwidth 3 \
	-relief raise \
	-width 800 \
	-justify left \
	-text $TexteActions \
	-background "lightyellow" \
	-foreground "black"

    place $CestLeMessage \
	-x $x -y $y \
	-anchor sw \
	-in $NomFenetreOrdali

    return
}


proc MontreCacheLongInfoSeq {pos {des ""}} {
    global CestLeLongDes NomFenetreOrdali

    if {[info exists CestLeLongDes]} {
	destroy $CestLeLongDes
    }
    if {$des eq ""} {
	return
    }

    set TexteActions "$des"
    set CestLeLongDes "$NomFenetreOrdali.longinfo"

    set px [winfo pointerx $NomFenetreOrdali]
    set py [winfo pointery $NomFenetreOrdali]
    set ry [winfo rooty $NomFenetreOrdali]
    set rx [winfo rootx $NomFenetreOrdali]

    set x [expr {$px-$rx}]
    set y [expr {$py-$ry-10}]

    message $CestLeLongDes \
	-borderwidth 3 \
	-relief raise \
	-width 800 \
	-justify left \
	-text $TexteActions \
	-background "lightyellow" \
	-foreground "black"

    place $CestLeLongDes \
	-x $x -y $y \
	-anchor sw \
	-in $NomFenetreOrdali

    return
}


proc FinPCI {} {

    DetruitBoutonsOrdali
    AfficheBoutonsOrdali

    return
}


proc SummaryPCI {} {
    global LNDG SDG TPCI LNOrdali Defauts

    set top .spci
    #
    # TODO :
    # create as many window as wanted
    # For the moment, delete current window if exitst
    if {[winfo exists $top]} {
	destroy $top
    }
    toplevel $top
    wm title $top "Sequence Identity summary"

    labelframe $top.lbl \
	-text "Sequence Identity Summary" \
	-fg $Defauts(ForeAppli) \
	-relief flat \
    -font TitleFont \
	-labelanchor nw
    grid $top.lbl -row 0 -column 0 -sticky w -pady 10
    
    set Ln {}
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n ne ""} {
	    lappend Ln $n
	}
    }
    set lg [PlusLongEltDe $Ln]

    frame $top.fgr
    set dg 0 ; set r 0
    foreach g $LNDG {
	if {$g eq "grise" || $g eq "bidon"} {
	    continue
	}
	set Ln $SDG($g)
	if {$g eq "GroupeToutLeMonde"} {
	    set gt "Whole Alignment"
	} else {
	    set gt $g
	}

	frame $top.fgr.f$dg
	label $top.fgr.f$dg.ltt \
	    -text "$gt" \
	    -fg $Defauts(ForeAppli) \
	-font "Helvetica 12 bold" \
	    -anchor w -justify left
	
	set min 999. ; set max -999.
	set pmn "" ; set pmx ""
	set m 0.0 ; set m2 0.0
	set i 1 ; set npairs 0
	foreach n1 [lrange $Ln 0 end-1] {
	    foreach n2 [lrange $Ln $i end] {
		if {! [info exists TPCI($n1,$n2)]} {
		    continue
		}
		lassign [set TPCI($n1,$n2)] pc l1 l2 l1sl2
		if {$pc < 0} {
		    # empty sequence
		    continue
		}
		set pc [expr {100.*$pc}]
		set m  [expr {$m + $pc}]
		set m2 [expr {$m2 + $pc*$pc}]
		incr npairs
		if {$pc > $max} {
		    set max $pc
		    set pmx "[format %${lg}s $n1-$n2] [format %6.1f $max]"
		}
		if {$pc < $min} {
		    set min $pc
		    set pmn "[format %${lg}s $n1-$n2] [format %6.1f $min]"
		}
	    }
	    incr i
	}

	if {$npairs == 0} {
	    set m -1.0
	    set s -1.0
	} else {
	    set m [expr {$m/$npairs}]
	    set var [expr {$m2/$npairs - $m*$m}]
	    if {$var > 0.0001} {
		set s [expr {sqrt($var)}]
	    } else {
		set s 0.0
	    }
	}	

	if {$npairs == 0} {
	    set vms "no pair"
	    set vnx "no pair"
	} else {
	    set vms [format "%6.2f %6.2f" $m $s]
	    set vnx [format "%6.2f %6.2f" $min $max]
	}
	label $top.fgr.f$dg.lms \
	    -font "Helvetica 10" \
	    -text "Average/Std. dev" \
	    -justify left 
	label $top.fgr.f$dg.vms \
	    -font "Helvetica 10" \
	    -text $vms \
	    -justify left
	label $top.fgr.f$dg.lnx \
	    -font "Helvetica 10" \
	    -text "Minimum/Maximum" \
	    -justify left 
	label $top.fgr.f$dg.vnx \
	    -font "Helvetica 10" \
	    -text $vnx \
	    -justify left
	label $top.fgr.f$dg.lpn \
	    -font "Helvetica 10" \
	    -text "Pair with min Iden. :" \
	    -justify left 
	label $top.fgr.f$dg.vpn \
	    -font "Helvetica 10" \
	    -text $pmn \
	    -justify left
	label $top.fgr.f$dg.lpx \
	    -font "Helvetica 10" \
	    -text "Pair with max. iden. :" \
	    -justify left 
	label $top.fgr.f$dg.vpx \
	    -font "Helvetica 10" \
	    -text $pmx \
	    -justify left
	grid $top.fgr.f$dg.ltt -column 0 -row 0 -columnspan 2 -sticky w
	grid $top.fgr.f$dg.lms -column 0 -row 1 -sticky w
	grid $top.fgr.f$dg.vms -column 1 -row 1 -sticky w
	grid $top.fgr.f$dg.lnx -column 0 -row 2 -sticky w
	grid $top.fgr.f$dg.vnx -column 1 -row 2 -sticky w
	grid $top.fgr.f$dg.lpn -column 0 -row 3 -sticky w
	grid $top.fgr.f$dg.vpn -column 1 -row 3 -sticky w
	grid $top.fgr.f$dg.lpx -column 0 -row 4 -sticky w
	grid $top.fgr.f$dg.vpx -column 1 -row 4 -sticky w

	set c [expr {$dg%2}]
	grid $top.fgr.f$dg -row $r -column $c -sticky ew -ipadx 5 -ipady 5

	if {$dg%2} {incr r}
	incr dg
    }
    grid $top.fgr -row 1 -column 0 -padx 5 -pady 5

    button $top.bok \
	-text " OK " \
	-bg green1 \
	-command [list destroy $top]
    grid $top.bok -row 2 -column 0 -pady {15 5}
    
    FenetreAuCentre $top

    tkwait window $top

    return
}


proc ComputeIdentity {} {
    global NomSeqSel TPCI ZoneSelect ZonePCI
    
    FaireAttendre "Please wait ...\nComputing sequences identities ..."

    # use the selected columns (whole alignment if none)
    if {! [info exists ZoneSelect]} {
	set ZoneSelect {}
    }
    # merge overlapping zones (e.g. Select All + a range) so that
    # no column is counted twice
    set ZonePCI {}
    foreach z [lsort -integer -index 0 $ZoneSelect] {
	lassign $z x1 x2
	lassign [lindex $ZonePCI end] p1 p2
	if {$ZonePCI ne {} && $x1 <= $p2+1} {
	    lset ZonePCI end [list $p1 [expr {max($p2,$x2)}]]
	} else {
	    lappend ZonePCI [list $x1 $x2]
	}
    }

    set NSTmp $NomSeqSel
    set NomSeqSel {}
    AlignementDesSelections $ZonePCI SAli
    set NomSeqSel $NSTmp
    
    # forget previous values : sequences empty in the zone have no pair
    unset -nocomplain TPCI
    array set TPCI {}
    CalculeLesPCIGenerique $SAli TPCI
    
    FaireLaSuite

    return
}


proc ClosestDistantPCISequenceFrom {seq {what "All"}} {
    global TPCI SDG LNDG TDuGroupeDesSeqs

    switch $what {
	"All" {
	    set Lk [array names TPCI "$seq,*"]
	}
	"group" {
	    set g $TDuGroupeDesSeqs($seq)
	    set Lk [lmap s $SDG($g) {set tmp "$seq,$s"}]
	}
	"outside" {
	    set g $TDuGroupeDesSeqs($seq)
	    set l1 [lmap k [array names TPCI "$seq,*"] {lindex [split $k ,] 1}]
	    set l2 $SDG($g)
	    set Lk [lmap s [lor $l1 $l2] {set tmp "$seq,$s"}]
	}
    }
    if {[set i [lsearch $Lk "$seq,$seq"]] > -1} {
	set Lk [lreplace $Lk $i $i]
    }
    # keep pairs whose identity is known
    set Lk [lmap k $Lk {expr {[info exists TPCI($k)] && [lindex $TPCI($k) 0] >= 0 ? $k : [continue]}}]
    if {$Lk == {}} {
	return [list "none" 0.0 0 "none" 0.0 0]
    }
    
    # search min and max identity
    set pcmax -999.0
    set pcmin 999.0
    foreach k $Lk {
	lassign $TPCI($k) pci l1 l2
	if {$pci > $pcmax} {
	    set pcmax $pci
	    set lmax $l2
	    set seqmax [lindex [split $k ,] 1]
	}
	if {$pci < $pcmin} {
	    set pcmin $pci
	    set lmin $l2
	    set seqmin [lindex [split $k ,] 1]
	}
    }
    
    return [list $seqmax $pcmax $lmax $seqmin $pcmin $lmin]
}


proc DetailsCherchePCI {} {
    global TPCI nsq1 nsq2 pciLbl pl1Lbl pl2Lbl TDuGroupeDesSeqs Defauts

    if {$nsq1 eq "Select" || $nsq2 eq "Select"} {
	FaireLire "Please select a couple of sequences first !"
	return
    }
    
    # make sure the pair is computed and labels are up to date
    CherchePCI ""
    if {! [info exists TPCI($nsq1,$nsq2)]} {
	return
    }
    lassign $TPCI($nsq1,$nsq2) pci l1 l2
    set pci [expr {$pci * 100.}]
    if {[set TDuGroupeDesSeqs($nsq1)] ni {"Group0" "GroupeToutLeMonde"}} {
	set isGroup 1
    } else {
	set isGroup 0
    }

    if {$isGroup} {
	lassign [ClosestDistantPCISequenceFrom $nsq1 group] seq1maxGrp pc1maxGrp l1maxGrp seq1minGrp pc1minGrp l1minGrp
	lassign [ClosestDistantPCISequenceFrom $nsq2 group] seq2maxGrp pc2maxGrp l2maxGrp seq2minGrp pc2minGrp l2minGrp
	lassign [ClosestDistantPCISequenceFrom $nsq1 outside] seq1maxOut pc1maxOut l1maxOut seq1minOut pc1minOut l1minOut
	lassign [ClosestDistantPCISequenceFrom $nsq2 outside] seq2maxOut pc2maxOut l2maxOut seq2minOut pc2minOut l2minOut
    } else {
	lassign [ClosestDistantPCISequenceFrom $nsq1] seq1maxAll pc1maxAll l1maxAll seq1minAll pc1minAll l1minAll
	lassign [ClosestDistantPCISequenceFrom $nsq2] seq2maxAll pc2maxAll l2maxAll seq2minAll pc2minAll l2minAll
    }

    # GUI
    set top .detailspci
    if {[winfo exists $top]} {
	destroy $top
    }
    toplevel $top
    wm title $top "Sequence Identity summary"
    wm protocol $top WM_DELETE_WINDOW KillParLaCroix
    grid columnconfig $top 0 -weight 1

    label $top.lgen \
	-text "Details of sequence Identity" \
	-fg $Defauts(ForeAppli) \
	-relief flat \
    -font TitleFont
    grid $top.lgen -row 0 -column 0 -sticky w -pady {10 20}

    frame $top.f1
    grid $top.f1 -row 1 -column 0 -sticky ew -pady 10

    label $top.f1.lseq1 \
	-text $nsq1 \
	-justify left
    label $top.f1.lseq2 \
	-text $nsq2 \
	-justify left
    label $top.f1.len1 \
	-text "$pl1Lbl" \
	-justify left
    label $top.f1.len2 \
	-text "$pl2Lbl" \
	-justify left
    label $top.f1.lpci \
	-text "Identity : [format %5.1f $pci] %" \
	-justify left
    grid $top.f1.lseq1 -row 0 -column 0 -sticky w -padx {0 10}
    grid $top.f1.len1  -row 0 -column 1 -sticky w
    grid $top.f1.lseq2 -row 1 -column 0 -sticky w -padx {0 10}
    grid $top.f1.len2  -row 1 -column 1 -sticky w
    grid $top.f1.lpci  -row 2 -column 0 -columnspan 2 -sticky w

    frame $top.f2
    grid $top.f2 -row 2 -column 0 -sticky ew -pady 10

    label $top.f2.lseq1 \
	-text $nsq1 \
	-justify left
    label $top.f2.lseq2 \
	-text $nsq2 \
	-justify left
    grid $top.f2.lseq1 -row 0 -column 1 -sticky w
    grid $top.f2.lseq2 -row 0 -column 2 -sticky w
    # get font
    set fnt [$top.f2.lseq1 cget -font]
    set fml [font configure $fnt -family]
    set sze [font configure $fnt -size]
    if {"FontPCI" ni [font names]} {
	font create FontPCI -family $fml -size $sze -weight bold
    }
    # Display changes whether we are in a group or not
    if {! $isGroup} {
	# in whole alignement
	label $top.f2.ltitle \
	    -text "In the whole alignment" \
	    -font FontPCI \
	    -relief flat \
	    -justify left
	
	# closest seq
	label $top.f2.lclo \
	    -text "Closest" \
	    -justify left
	label $top.f2.sclo1 \
	    -text "$seq1maxAll ([format "%5.1f %%" [expr {100.*$pc1maxAll}]])" \
	    -justify left
	label $top.f2.sclo2 \
	    -text "$seq2maxAll ([format "%5.1f %%" [expr {100.*$pc2maxAll}]])" \
	    -justify left
	grid $top.f2.ltitle -row 1 -column 0 -columnspan 3 -sticky w
	grid $top.f2.lclo -row 2 -column 0 -sticky w
	grid $top.f2.sclo1 -row 2 -column 1 -sticky w
	grid $top.f2.sclo2 -row 2 -column 2 -sticky w

	# distant
	label $top.f2.ldis \
	    -text "Distant" \
	    -justify left
	label $top.f2.sdis1 \
	    -text "$seq1minAll ([format "%5.1f %%" [expr {100.*$pc1minAll}]])" \
	    -justify left
	label $top.f2.sdis2 \
	    -text "$seq2minAll ([format "%5.1f %%" [expr {100.*$pc2minAll}]])" \
	    -justify left
	grid $top.f2.ldis -row 3 -column 0 -sticky w
	grid $top.f2.sdis1 -row 3 -column 1 -sticky w
	grid $top.f2.sdis2 -row 3 -column 2 -sticky w
    } else {
	# sequences are in groups
	# show stats within and outside groups
	# inside group
	label $top.f2.ltitlei \
	    -text "Within their group" \
	    -font FontPCI \
	    -relief flat \
	    -justify left
	
	# closest seq
	label $top.f2.lcloi \
	    -text "Closest" \
	    -justify left
	label $top.f2.sclo1i \
	    -text "$seq1maxGrp ([format "%5.1f %%" [expr {100.*$pc1maxGrp}]])" \
	    -justify left
	label $top.f2.sclo2i \
	    -text "$seq2maxGrp ([format "%5.1f %%" [expr {100.*$pc2maxGrp}]])" \
	    -justify left
	grid $top.f2.ltitlei -row 1 -column 0 -columnspan 3 -sticky w
	grid $top.f2.lcloi -row 2 -column 0 -sticky w
	grid $top.f2.sclo1i -row 2 -column 1 -sticky w
	grid $top.f2.sclo2i -row 2 -column 2 -sticky w

	# distant
	label $top.f2.ldisi \
	    -text "Distant" \
	    -justify left
	label $top.f2.sdis1i \
	    -text "$seq1minGrp ([format "%5.1f %%" [expr {100.*$pc1minGrp}]])" \
	    -justify left
	label $top.f2.sdis2i \
	    -text "$seq2minGrp ([format "%5.1f %%" [expr {100.*$pc2minGrp}]])" \
	    -justify left
	grid $top.f2.ldisi -row 3 -column 0 -sticky w
	grid $top.f2.sdis1i -row 3 -column 1 -sticky w
	grid $top.f2.sdis2i -row 3 -column 2 -sticky w

	# outside group
	label $top.f2.ltitleo \
	    -text "Outside their group" \
	    -font FontPCI \
	    -relief flat \
	    -justify left
	
	# closest seq
	label $top.f2.lcloo \
	    -text "Closest" \
	    -justify left
	label $top.f2.sclo1o \
	    -text "$seq1maxOut ([format "%5.1f %%" [expr {100.*$pc1maxOut}]])" \
	    -justify left
	label $top.f2.sclo2o \
	    -text "$seq2maxOut ([format "%5.1f %%" [expr {100.*$pc2maxOut}]])" \
	    -justify left
	grid $top.f2.ltitleo -row 4 -column 0 -columnspan 3 -sticky w
	grid $top.f2.lcloo -row 5 -column 0 -sticky w
	grid $top.f2.sclo1o -row 5 -column 1 -sticky w
	grid $top.f2.sclo2o -row 5 -column 2 -sticky w

	# distant
	label $top.f2.ldiso \
	    -text "Distant" \
	    -justify left
	label $top.f2.sdis1o \
	    -text "$seq1minOut ([format "%5.1f %%" [expr {100.*$pc1minOut}]])" \
	    -justify left
	label $top.f2.sdis2o \
	    -text "$seq2minOut ([format "%5.1f %%" [expr {100.*$pc2minOut}]])" \
	    -justify left
	grid $top.f2.ldiso -row 6 -column 0 -sticky w
	grid $top.f2.sdis1o -row 6 -column 1 -sticky w
	grid $top.f2.sdis2o -row 6 -column 2 -sticky w
    }	
    
    button $top.bok \
	-text "Close" \
	-bg green1 \
	-command [list destroy $top]
    grid $top.bok -row 3 -column 0 -sticky ew -pady {20 10}

    FenetreAuCentre $top
    update idletasks
    
    tkwait window $top
    
    return
}


proc CherchePCI {w args} {
    global TPCI nsq1 nsq2 pciLbl pl1Lbl pl2Lbl
    
    if {$nsq1 eq "" || $nsq2 eq "" || $nsq1 eq "Select" || $nsq2 eq "Select"} {
	return
    }

    set pair1 "$nsq1,$nsq2"
    if {! [info exists TPCI($pair1)]} {
	# CalculeLesPCI fills TDesPCI, not TPCI
	CalculeLesPCI "" "" $nsq1 $nsq2
	update
	foreach k [list "$nsq1,$nsq2" "$nsq2,$nsq1"] {
	    if {[info exists ::TDesPCI($k)]} {
		set TPCI($k) $::TDesPCI($k)
	    }
	}
    }
    if {! [info exists TPCI($pair1)]} {
	FaireLire "Something wrong ...\nMaybe one of the sequences is empty ?"

	return
    }

    set val [set TPCI($pair1)]
    lassign $val pci pl1 pl2

    set pci [format "%5.1f" [expr {$pci * 100.}]]

    set pciLbl "Identity : $pci %"
    set pl1Lbl "length seq 1 : $pl1"
    set pl2Lbl "length seq 2 : $pl2"

    return
}


# ordali motif
# W(X){13,15}Y
proc ChercheMotif {} {
    global NomTextSeq LSOrdali Chrc LNOrdali LNSeqlab
    
    set BonMotif [EstUnBonPattern $Chrc(Motif)]
    if {$BonMotif == 0} {
	return
    }
    
    if {$Chrc(prevMode) eq "seqlab"} {
	set LNoms $LNSeqlab
	set LSeqs [$NomTextSeq output all]
    } else {
	set LNoms $LNOrdali
	set LSeqs $LSOrdali
    }

    set i 0
    set Chrc(NextOc) {}
    set Chrc(NbrOccus) ""
    set Loccu {}
    foreach seq $LSeqs nom $LNoms {
	incr i
	if {[string trim $nom] eq ""} {
	    continue
	}

	set sdg [string map {"." "" " " ""} $seq]

	set LIdx {}
	if {[catch {set LIdx [regexp -indices -all -inline -- $BonMotif $sdg]}]} {
	    FaireLire "Problem when searching motif pattern >$Chrc(Motif)< !\nPlease check your pattern !"

	    return
	}
	if {$LIdx == {} } {
	    continue
	}

	# column of each residue in the aligned sequence.
	# (DonnePosSG is wrong here for PDB sequences : it
	# expects a PDB residue number, not a sequence index)
	set Lcol [regexp -all -inline -indices {[^. ]} $seq]
	foreach e $LIdx {
	    lassign $e d f
	    set dg [lindex $Lcol $d 0]
	    set fg [lindex $Lcol $f 0]
	    lappend Loccu [list $i.$dg $i.[expr {$fg+1}]]
	}
    }

    set Chrc(LOccus) {}
    foreach o $Loccu {
	lassign $o d f
	lassign [split $f .] il ic
	set f "$il.[expr {$ic-1}]"
	lappend Chrc(NextOc) $d
	lappend Chrc(LOccus) $d $f
    }
    set Chrc(NbrOccus) "[llength $Chrc(NextOc)] found"
    set Chrc(IdxMotif) 0
    if {$Chrc(LOccus) != {}} {
	MontreOccurrenceMotif [lindex $Chrc(NextOc) $Chrc(IdxMotif)]
    }

    PeintHitsCherche

    return
}


proc PeintHitsCherche {} {
    global NomTextSeq Chrc

    $NomTextSeq configure -bg black -fg white
    if {$Chrc(prevMode) eq "seqlab"} {
	$NomTextSeq map off
	#$NomTextSeq tag state on
	update idletasks
    }
    $NomTextSeq tag configure Cherche -foreground white -background red

    # remove previous hits, even if nothing is found now
    $NomTextSeq tag remove Cherche
    if {[llength $Chrc(LOccus)] > 0} {
	$NomTextSeq tag add Cherche {*}$Chrc(LOccus)
    }

    return
}


proc ChercheMotifSuivant {{enplace 0}} {
    global NomTextSeq Chrc

    if {! [info exists Chrc] || ! [info exists Chrc(NextOc)]} {
	# the 'serch' or <return> button has not been 
	# pressed. Do it here
	ChercheMotif
	# no valid motif given
	if {! [info exists Chrc(NextOc)]} {return}
    }

    set lg [llength $Chrc(NextOc)]
    if {! $lg} {return}
    if {! $enplace} {
	if {$Chrc(IdxMotif) == $lg-1} {
	    set Chrc(IdxMotif) 0
	} else {
	    incr Chrc(IdxMotif)
	}
    }

    MontreOccurrenceMotif [lindex $Chrc(NextOc) $Chrc(IdxMotif)]

    return
}


proc MontreOccurrenceMotif {idx} {
    global NomTextSeq

    # 'see' moves the sequences only : names and ruler follow
    # the view (they stayed at their old position)
    $NomTextSeq see $idx
    $::NomNomSeq yview moveto [lindex [$NomTextSeq yview] 0]
    CoupleX moveto [lindex [$NomTextSeq xview] 0]

    return
}


proc FinCherche {} {
    global NomTextSeq Chrc CurrentMode

    if {$Chrc(prevMode) eq "seqlab"} {
	#$NomTextSeq tag state off
	$NomTextSeq map on
    }
    $NomTextSeq tag delete Cherche
    $NomTextSeq configure -background white -foreground black

    unset -nocomplain Chrc

    update idletasks

    DetruitBoutonsOrdali

    if {$CurrentMode eq "seqlab"} {
	QuelMode "$CurrentMode"
	# back in the Editor : restore the mode to go back to
	# when leaving it
	DepileMode
	update
	AfficheBoutonsSeqLab 1
    } else {
	ChangeMode $CurrentMode
    }

    return
}



proc FinAfficheDownloadPDB {{quoi ""} {w ""}} {
    global DwnPDB StrucAVoir ListePDB

    if {$quoi eq "dismiss"} {
	destroy $w
	return
    }

    foreach i [array names DwnPDB] {
	set n [set DwnPDB($i)]
	if {[string trim $n] eq ""} {return}
	if {! [file exists $n]} {
	    FaireLire "Error !\nThe file :\n${n}\ndoes not exist !"
	    return
	}
    }

    set i 1
    foreach s $StrucAVoir {
	set Nom   [string trim [set DwnPDB($i)]]
	set ix    [lsearch -regexp $ListePDB $s]
	set m     [lindex $ListePDB $ix]
	set pdbid [DonneIdDeAccessPDB $m]
	set chn   [DonneChainDeAccessPDB $m]
	
	if {[info commands $pdbid] ne ""} {
	    $pdbid destroy
	}
	#rR set cok [LoadNouveauPDB $pdbid $Nom]
	set pdbid [LoadNouveauPDB $pdbid $Nom]        ; #rR que fait-on avec le fait le pdbid qui est Nom normalement 
    }

    return
}


proc AfficheDownloadPDB {} {
    global StrucAVoir DwnPDB

    set w ".dwnpdb"
    toplevel $w
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    grid rowconfig    $w 0 -weight 1 -minsize 0
    grid columnconfig $w 0 -weight 0 -minsize 0
    grid columnconfig $w 1 -weight 1 -minsize 0
    grid columnconfig $w 2 -weight 0 -minsize 0

    label $w.l -text "Please specify PDB files to be used" -anchor w
    set i 1
    foreach s $StrucAVoir {
	label $w.l$i -text "$s"
	entry $w.e$i -bg white -width 25 -textvariable DwnPDB($i)
	button $w.b$i \
	    -text "browse ..." \
	    -bg cyan -width 10 \
	    -command [list eval set DwnPDB($i) \[DemandeEtOuvreFichier pdb 1\]]
	grid $w.l$i -padx 10 -pady 1 \
	    -row $i -column 0 -rowspan 1 -columnspan 1 -sticky news
	grid $w.e$i -padx 1 -pady 1 \
	    -row $i -column 1 -rowspan 1 -columnspan 1 -sticky news
	grid $w.b$i -padx 10 -pady 1 \
	    -row $i -column 2 -rowspan 1 -columnspan 1 -sticky news
	incr i
    }
    frame $w.f
    button $w.f.ok \
	-background green1 \
	-text " OK " \
	-command [list FinAfficheDownloadPDB "" $w]
    button $w.f.dis -bg red \
	-text "Cancel" \
	-command [list FinAfficheDownloadPDB dismiss $w]
    pack $w.f.dis $w.f.ok -side left -expand 1

    grid $w.l -padx 10 -pady 10 \
	-row 0 -column 0 -rowspan 1 -columnspan 3 -sticky news
    grid $w.f -padx 10 -pady 10 \
	-row $i -column 0 -rowspan 1 -columnspan 3 -sticky news

    FenetreAuCentre $w
    MesCouleurs $w

    tkwait window $w

    return
}



proc ChoixUnSeulPDB {} {
    global ListePDB Defauts

    set ls [llength $ListePDB]

    set lep [lindex $ListePDB 0]
    lassign $lep mol fpdb
    set molref [DonneIdDeAccessPDB $mol]

    if {$ls == 1} {
	return $molref
    }

    set w .pdbras
    toplevel $w
    wm title $w "Choose a structure ..."
    wm iconname $w "Choose PDB"

    frame $w.r \
	-relief flat \
	-borderwidth 2
    pack  $w.r -side top -pady 10
    label $w.r.t \
	-text "Choose a molecule :"\
	-font TitleFont \
	-fg Defauts(ForeAppli) \
	-justify left
    pack $w.r.t -pady 10

    frame $w.btn
    pack $w.btn -side bottom -pady 5 -padx 10
    button $w.btn.cancel \
	-text "Cancel" \
	-background red \
	-command "destroy $w"
    button $w.btn.cebon \
	-text " OK " \
	-background green1 \
	-command "set Retour \[set molref\]"
    pack $w.btn.cancel $w.btn.cebon -side left -padx 10 -pady 10 -fill x

    set i 0
    set fdrt "$w.r.d"
    set fgch "$w.r.g"
    frame $fdrt
    frame $fgch
    set d 1
    foreach elt $ListePDB {
	lassign $elt molc pdb
	set chn [DonneChainDeAccessPDB $molc]
	set mol [DonneIdDeAccessPDB $molc]
	set txt "$mol, chain $chn"

	if {$d == 1} {
	    set fbtni "${fdrt}.n$i"
	    set d 2
	} else {
	    set fbtni "${fgch}.n$i"
	    set d 1
	}
	radiobutton $fbtni \
	    -text $txt \
	    -relief flat \
	    -value "$molc" \
	    -highlightthickness 0 \
	    -variable molref 
	pack $fbtni -side top -pady 5 -padx 5
	incr i
    }

    pack $fdrt $fgch -side left -anchor n

    FenetreAuCentre $w
    tkwait window $w

    destroy $w
    update idletasks

    return
}


proc SelectionneTousLesPDB {} {
    global lesbts

    foreach p $lesbts {
	$p deselect
	$p select
    }

    return
}


proc FinChoixPlusieursPDB {w {quoi ""}} {
    global Defauts lesbts StrucAVoir

    set StrucAVoir {}

    set LSel {}
    foreach l $lesbts {
	set v [$l cget -variable]
	global $v
	if {[set $v] ne ""} {
	    lappend LSel [set $v]
	}
	unset $v
    }
    unset lesbts
    
    if {$quoi ne "dismiss"} {
	set StrucAVoir $LSel
    }

    destroy [winfo toplevel $w]
    update idletasks
    
    return
}


proc ChoixPlusieursPDB {} {
    global Defauts lesbts ListePDB LNOrdali

    set w .pdbchooser
    if {[winfo exists $w]} {
	raise $w
	return
    }

    set ls [llength $ListePDB]
    set lep [lindex $ListePDB 0]
    lassign $lep mol pdb
    set chn [DonneChainDeAccessPDB $mol]
    set mol [DonneIdDeAccessPDB $mol]
    
    set lamolrefdefaut $mol

    set lesbts {}

    toplevel $w
    wm title $w "Choose Structures"
    wm iconname $w "PDB Chooser"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    label $w.t \
	-text "Choose the molecules you want to display with\n 3D Viewer" \
	-font TitleFont \
    -fg $Defauts(ForeAppli) \
	-justify left \
	-anchor nw

    set fmol "$w.fmol"
    frame $fmol
    set fdrt "$w.fmol.d"
    set fgch "$w.fmol.g"
    frame $fdrt
    frame $fgch
    set i 0
    foreach elt $ListePDB {
	lassign $elt molname pdb
	if {$molname ni $LNOrdali} {
	    continue
	}

	set mol [DonneIdDeAccessPDB $molname]
	set chn [DonneChainDeAccessPDB $molname]
	set txt "$mol, chain $chn"

	if {! ($i % 2)} {
	    set fbtni "${fgch}.n$i"
	} else {
	    set fbtni "${fdrt}.n$i"
	}
	lappend lesbts $fbtni
	global molref$i
	checkbutton $fbtni \
	    -text $txt \
	    -variable molref$i \
	    -relief flat \
	    -highlightthickness 0 \
	    -onvalue "${mol}_${chn}" \
	    -offvalue ""
	set row [expr {($i%2?$i-1:$i)/2}]
	grid $fbtni -row $row -column 0 -padx 2 -pady 2 -sticky w
	incr i
    }
    grid $fgch -row 0 -column 0 -sticky ew
    grid $fdrt -row 0 -column 1 -sticky ew
    grid columnconfig $fmol all -weight 1
    puts "\nlesbts [llength $lesbts]\n"
    frame $w.sdl
    radiobutton $w.sdl.net \
	-text "Download PDB from the internet" \
	-value "internet" \
	-variable Defauts(DownloadPDB) \
	-anchor w -justify left \
	-relief flat
    radiobutton $w.sdl.loc \
	-text "Download local PDB files" \
	-value "local" \
	-variable Defauts(DownloadPDB) \
	-anchor w -justify left \
	-relief flat
    grid $w.sdl.net -row 0 -column 0 -columnspan 1 -pady 5 -sticky w
    grid $w.sdl.loc -row 1 -column 0 -columnspan 1 -pady 5 -sticky w
    
    frame $w.btn
    button $w.btn.cancel \
	-text "Cancel" \
	-background red \
	-command [list FinChoixPlusieursPDB $w dismiss]
    button $w.btn.selall \
	-text "Select All" \
	-background yellow \
	-command [list SelectionneTousLesPDB]
    set ::bcbon $w.btn.cebon 
    button $w.btn.cebon \
	-text " OK " \
	-background green1 \
	-command [list FinChoixPlusieursPDB $w]

    grid $w.btn.cancel -row 0 -column 0 -sticky w 
    grid $w.btn.selall -row 0 -column 1
    grid $w.btn.cebon  -row 0 -column 2 -sticky e
    grid columnconfig $w.btn all -weight 1
    
    grid $w.t -row 0 -column 0 \
	-padx 5 -pady 5 -sticky ew
    grid $w.fmol -row 1 -column 0 \
	-padx 5 -pady 5 -sticky ew
    grid $w.sdl -row 2 -column 0 \
	-padx 5 -pady 5 -sticky ew
    grid $w.btn -row 3 -column 0 \
	-padx 5 -pady 20 -sticky ew

    grid columnconfig $w 0 -weight 1 -minsize 0
    
    BoutonParDefaut $w.btn.selall
    
    MesCouleurs $w
    FenetreAuCentre $w
    
    update idletasks
    tkwait window $w
    
    return
}


proc DefinitStructuresAVoir {} {
    global StrucAVoir

    set StrucAVoir {}
    ChoixPlusieursPDB
    update

    # si pas de PDB selectionne, ou 1 seul pris,
    # pas de superposition a faire
    if {[llength $StrucAVoir] < 2} {return}

    set choix [tk_dialog .chx "Beware !" "Beware ! Structures may be not superposed !\nDo you want to superpose them ?" "" 0 " Yes " " No "]
    if {$choix == 0} {Superposition}

    return $StrucAVoir
}



proc FinChoixPDBReference {w quoi} {
    global chxmolref

    if {$chxmolref eq "" && $quoi eq "OK"} {
	faireLire "Warning !\nNo reference structure has been choosen !"
	return
	}

    if {$quoi ne "OK"} {
	set chxmolref ""
    }
    destroy [winfo toplevel $w]
    update idletasks
    
    return
}



proc ChoixPDBReference {} {
    global chxmolref StrucAVoir

    set chxmolref ""

    set w .pdbref
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    wm title $w "Choose Reference Structure"
    wm iconname $w "PDB reference"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    label $w.t \
	-text "Choose the reference structure \nfor superposition (the fixed structure)" \
	-justify left -anchor w
    
    set fmol "$w.fmol"
    frame $fmol
    set fdrt "$w.fmol.d"
    set fgch "$w.fmol.g"
    frame $fdrt
    frame $fgch
    set i 0
    foreach molc $StrucAVoir {
	set mol [DonneIdDeAccessPDB $molc]
	set chn [DonneChainDeAccessPDB $molc]
	set txt "${mol}, chain $chn"

	if {! ($i % 2)} {
	    set fbtni "${fgch}.n$i"
	} else {
	    set fbtni "${fdrt}.n$i"
	}
	radiobutton $fbtni \
	    -text $txt \
	    -variable chxmolref \
	    -relief flat \
	    -highlightthickness 0 \
	    -value "$molc"

	set row [expr {($i%2?$i-1:$i)/2}]
	grid $fbtni -row $row -column 0 -pady 2 -padx 2 -sticky w
	
	incr i
    }
    grid $fgch -row 0 -column 0 -sticky w
    grid $fdrt -row 0 -column 1 -sticky w
    
    frame $w.btn
    button $w.btn.cancel \
	-text " Cancel " \
	-background red \
	-command [list FinChoixPDBReference $w dismiss]
    button $w.btn.cebon \
	-text " OK " \
	-background green1 \
	-command [list FinChoixPDBReference $w OK]
    grid $w.btn.cancel -row 0 -column 0 -sticky w
    grid $w.btn.cebon  -row 0 -column 1 -sticky e
    grid columnconfig $w.btn all -weight 1

    grid $w.t    -row 0 -column 0 -pady {10 20} -sticky ew
    grid $w.fmol -row 1 -column 0 -sticky ew 
    grid $w.btn -row 2 -column 0  -pady 20 -padx 10 -sticky ew
    grid columnconfig $w 0 -weight 1

    raise $w

    MesCouleurs $w
    FenetreAuCentre $w

    update idletasks
    tkwait window $w

    return $chxmolref
}


# AfficheSnapshotAnnotations : see ordali_annotation.tcl


proc AfficheZonesClustering {} {
    global WOrdali NomTextSeq NomNomSeq LNOrdali

    if {[TypeAli] eq "pasdali"} {return}
    if {[QuelMode] eq "seqlab"} {
	FaireLire "Not available in Editor Mode !"

	return
    }
    
    $NomTextSeq configure -state normal
    $NomNomSeq configure -state normal
    
    $NomTextSeq tag configure TagZoneClus -background cyan -foreground black

    set bt $WOrdali(BoutZones)
    if {! [EtatBouton $bt]} {
	set Lz [lindex [ZonesClustering] 0]
	if {$Lz eq "all"} {set Lz [list [list 0 end]]}
	set Ltag {}
	foreach z $Lz {
	    lassign $z x1 x2
	    set i 1
	    foreach n $LNOrdali {
		if {[string trim $n] ne ""} {
		    lappend Ltag $i.$x1 $i.$x2
		}
		incr i
	    }
	}
	if {$Ltag != {}} {
	    $NomTextSeq tag add TagZoneClus {*}$Ltag
	}

	$bt configure -relief sunken -background red -foreground white
    } else {
	$NomTextSeq tag remove TagZoneClus
	$bt configure -relief raised -background cyan -foreground black
    }

    update idletasks
    $NomTextSeq configure -state disabled

    return
}


proc AfficheZonesSelectionneesSuper {} {
    global ZoneSuperposition

    if {! [info exists ZoneSuperposition]} {return}

    AfficheZonesSelectionnees $ZoneSuperposition

    return
}


proc AfficheZonesSelectionneesCluster {} {
    global ZoneClusterisation

    if {! [info exists ZoneClusterisation]} {return}

    AfficheZonesSelectionnees $ZoneClusterisation

    return
}


proc AfficheZonesSelectionnees {zone} {
    global PositionInitiale

    if {$zone == {}} {return}
    foreach z $zone {
	lassign $z d f
	set PositionInitiale "1.$d"
	set fin "1.$f"
	SelectLesColonnes $fin
    }
    unset PositionInitiale

    return
}


proc TraceStrSec {widget x1 x2 y1 Type} {

    set HautFont [font metrics SeqFont -displayof $widget -linespace ]
    set LargFont [font measure SeqFont -displayof $widget A]

    set y2   [expr {$y1+$HautFont}]
    set ymil [expr {$y1+$HautFont/2}]
    set y1t  [expr {$y1+$HautFont/3}]
    set y12t [expr {$y1+2*$HautFont/3+1}]

    set Id ""
    if {$Type == "Alpha"} {
	set Id [$widget create rectangle $x1 $y1 $x2 $y2 -fill red]
    }

    if {$Type == "Pi"} {
	set Id [$widget create rectangle $x1 $y1 $x2 $y2 -fill pink]
    }

    if {$Type == "3_10"} {
	set Id [$widget create rectangle $x1 $y1 $x2 $y2 -fill magenta]
    }

    if {$Type == "Sheet"} {
	set x1f [expr {$x2-$LargFont}]
	set Id [$widget create polygon $x1 $y1t $x1f $y1t $x1f $y1 $x2 $ymil $x1f $y2 $x1f $y12t $x1 $y12t -fill green -outline black]
    }

    if {$Type == "Turn"} {
	set Id [$widget create oval $x1 $y1 $x2 $y2 -fill blue]
    }

    if {$Type == "Coil"} {
	set xp [expr {$x2+$LargFont-1}]
	$widget create line $x1 $ymil $x2 $ymil
    }
    if {$Id != ""} {$widget raise $Id}

    return
}



proc MetAJourCanvasSecStr {widget cpt SeqAss SeqAlignee MolId} {

    $widget create text 0 0 -font SeqFont
    set HautFont [font metrics SeqFont -displayof $widget -linespace ]
    set LargFont [font measure SeqFont -displayof $widget A]

    set x1 0
    set y1 [expr {$cpt*4*$HautFont+4}]
    set x2 0
    set y2 [expr {$y1+$HautFont}]
    set x3 0
    set y3 [expr {$y2+$HautFont}]

    $widget create text $x1 $y1 -text $SeqAss -font SeqFont
    $widget create text $x2 $y2 -text $SeqAlignee -font SeqFont

    global PDB_[set MolId]_SecStr
    global PDB_[set MolId]_NmrRes

    set Rlt ""
    set NomResDep 0
    set NomResFin 0
    set Rmk ""

    foreach ss [set PDB_[set MolId]_SecStr] {
	DecortiqueSS $ss Elt NomChnDep NomResDep NomResFin Rmk
	set LesBornes [CorrespondancePDBAli $MolId $NomChnDep $NomResDep $NomResFin $SeqAlignee]
	set DebAli [lindex $LesBornes 0]
	set FinAli [lindex $LesBornes 1]

	# calcule position et trace struc. sec.

	set x1 [expr {$DebAli*$LargFont}]
	set x2 [expr {$FinAli*$LargFont}]

	TraceStrSec $widget $x1 $x2 $y3 $Elt
    }

    return
}



proc InitEtAfficheNomSeqSecStr {widget} {

    global NomEtSeqAssPDB
    global LNOrdali

    set TextAffiche ""
    foreach elt $NomEtSeqAssPDB {
	scan $elt "%s %s %s" PDB NomSeqAss MolId
	if {[regexp {^[0-9]} $NomSeqAss]} {
	    set NomSeq [lindex $LNOrdali $NomSeqAss]
	} else {
	    set NomSeq $NomSeqAss
	}

	set TextAffiche "[set TextAffiche][set NomSeq]\nPDB_[set MolId]\nSec. Str.\n\n"
    }

    $widget delete 0.0 end
    $widget insert end [set TextAffiche]

    $widget configure -state disabled

    return
}


proc MontreLesStrSecDetaillees {} {
    global NomEtSeqAssPDB
    global Sequences
    global SeqlabMode

    if {$SeqlabMode} {
	FaireLire "Not available in Seqlab mode !"
	return
    }

    # Cree la fenetre avec meme apparence que fenetre master d'ordali

    set w .secstr
    toplevel $w
    wm title $w "Detailed Secondary Structure"
    wm iconname $w "SecStr"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    frame $w.lesseq -borderwidth .5c

    canvas $w.lesseq.textsequence \
	-relief sunken \
	-borderwidth 2 \
	-cursor left_ptr \
	-xscrollcommand "$w.lesseq.scrollxseq set" \
	-yscrollcommand "$w.lesseq.scrollyseq set" \
	-background white \
	-selectforeground black \
	-selectbackground white
    
    label $w.lesseq.scrollxnom \
	-textvariable nomstatus \
	-relief sunken \
	-borderwidth 1 \
	-anchor w
    
    frame $w.lesseq.fpos -relief sunken -borderwidth 1
    label $w.lesseq.fpos.vposg \
	-textvariable XGen \
	-relief flat \
	-width 4 \
	-anchor e
    label $w.lesseq.fpos.tposs \
	-text " seq " \
	-relief flat \
	-width 5 \
	-anchor w
    label $w.lesseq.fpos.vposs \
	-textvariable XSeq \
	-relief flat \
	-width 4 \
	-anchor e
    grid $w.lesseq.fpos.tposg -row 0 -column 0 -padx 0
    grid $w.lesseq.fpos.vposg -row 0 -column 1 -padx 0
    grid $w.lesseq.fpos.tposs -row 0 -column 2 -padx 0
    grid $w.lesseq.fpos.vposs -row 0 -column 3 -padx 0
    
    text $w.lesseq.textnomseq \
	-relief flat \
	-borderwidth 0 \
	-cursor left_ptr \
	-font SeqFont \
	-yscrollcommand "$w.lesseq.scrolly set" \
	-wrap none \
	-width 15 \
	-foreground black \
	-background white \
	-setgrid 1
    
    text $w.lesseq.regle \
	-borderwidth 2 \
	-font SeqFont \
	-cursor left_ptr \
	-foreground black \
	-background white \
	-xscrollcommand "$w.lesseq.scrollxseq set" \
	-setgrid 1 \
	-wrap none \
	-height 3
    
    scrollbar $w.lesseq.scrollxseq \
	-orient horiz \
	-width 8 \
	-command [list CoupleX] \
	-borderwidth 2
    
    scrollbar $w.lesseq.scrolly \
	-width 8 \
	-command "CoupleY $w.lesseq.textsequence $w.lesseq.textnomseq " \
	-borderwidth 2
    
    pack $w.lesseq -side top -expand 1 -fill both
    
    grid rowconfig    $w.lesseq 0 -weight 1 -minsize 0
    grid columnconfig $w.lesseq 0 -weight 0 -minsize 0
    grid columnconfig $w.lesseq 1 -weight 0 -minsize 0
    grid columnconfig $w.lesseq 2 -weight 1 -minsize 0

    grid $w.lesseq.textnomseq -padx 1 -in $w.lesseq -pady 1 \
	-row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
    grid $w.lesseq.scrollxnom -in $w.lesseq -padx 1 -pady 1 \
	-row 2 -column 0 -rowspan 1 -columnspan 1 -sticky news
    grid $w.lesseq.textsequence -in $w.lesseq -padx 1 -pady 1 \
	-row 0 -column 1 -rowspan 1 -columnspan 2 -sticky news
    grid $w.lesseq.regle -in $w.lesseq -padx 1 -pady 1 \
	-row 1 -column 1 -rowspan 1 -columnspan 2 -sticky news
    grid $w.lesseq.fpos -in $w.lesseq -padx 1 -pady 1 \
	-row 2 -column 1 -rowspan 1 -columnspan 1 -sticky nws
    grid $w.lesseq.scrollxseq -in $w.lesseq -padx 1 -pady 1 \
	-row 2 -column 2 -rowspan 1 -columnspan 1 -sticky news
    grid $w.lesseq.scrolly -in $w.lesseq -padx 1 -pady 1 \
	-row 0 -column 3 -rowspan 1 -columnspan 1 -sticky news

    set Boutons $w.buttons

    frame $Boutons
    pack  $Boutons -side bottom -fill x -pady 2m
    button $Boutons.dismiss -text "Cancel" -background "red" -command "destroy $w"
    pack $Boutons.dismiss -side left -expand 1


    set HautFont [font metrics SeqFont -displayof $w.lesseq.textnomseq -linespace ]
    set LargFont [font measure SeqFont -displayof $w A]
    scan [lindex $NomEtSeqAssPDB 0] "%s %s %s" tmp SeqAss MolId
    set nomSeqAss $SeqAss

    set width  [string length [set Sequences($nomSeqAss)]]
    set width  [expr {$width*$LargFont}]
    set NbPDB  [llength $NomEtSeqAssPDB]
    set heigth [expr {$NbPDB*$HautFont*4}]

    $w.lesseq.textsequence configure -width 512 -height $heigth
    $w.lesseq.textsequence configure -scrollregion  [list 0 0 $width $heigth]

    InitEtAfficheNomSeqSecStr $w.lesseq.textnomseq
    AfficheRegle $w.lesseq

    set cpt 0
    foreach elt $NomEtSeqAssPDB {
	scan $elt "%s %s %s" PDB SeqAss MolId
	set chn [string index $MolId 5]
	set MolId [string range $MolId 0 3]

	global PDB_[set MolId]_NomAtm
	global PDB_[set MolId]_NomRes
	global PDB_[set MolId]_NmrRes
	global PDB_[set MolId]_ChnIdn
	global PDB_[set MolId]_Sequence

	set SeqAlignee [lindex [set PDB_[set MolId]_Sequence($chn)] 1]

	MetAJourCanvasSecStr $w.lesseq.textsequence $cpt [set Sequences($SeqAss)] $SeqAlignee $MolId

	incr cpt
    }

    MesCouleurs $w

    return
}


proc EnvoieDump {Quoi {Valeur ""}} {
    global CanalDuDump

    if {$Quoi == "CloseFile"} {
	if {[info exists CanalDuDump]} {
	    close $CanalDuDump
	    unset CanalDuDump
	}
	return
    }
    if {$Quoi == "Canal"} {
	set CanalDuDump $Valeur
	return $CanalDuDump
    }
    if {$Quoi == "OpenFile"} {
	set CanalDuDump [open $Valeur w]
	return $CanalDuDump
    }

    if {![info exists CanalDuDump]} {set CanalDuDump stdout}
    if {$Quoi == "Retourne"} {
	set PutOuLap "lappend"
	set CanalDuDump "Retour"
    } else {
	set PutOuLap "puts"
    }

    $PutOuLap $CanalDuDump "<$Quoi>"
    $PutOuLap $CanalDuDump "$Valeur"
    $PutOuLap $CanalDuDump "</$Quoi>"

    if {$Quoi == "Retourne"} {
	return [join $Retour "\n"]
    } else {
	return
    }
}



proc DumpOrdali {{FichierDump ""}} {
    global NomTextSeq
    global NomNomSeq
    global Defauts

    if {$FichierDump==""} {
	if {![set Defauts(Dump)]} {
	    set FichierDump "DumpOrdali"
	} else {
	    set FichierDump [set Defauts(Dump)]
	}
    }

    set parent [winfo parent $NomTextSeq]
    set wregle $parent.regle

    # sort la regle puis les noms puis les seqquences

    set DumpRegle [$wregle     dump -tag -text 1.0 end]
    set DumpNoms  [$NomNomSeq  dump -tag -text 1.0 end]
    set DumpTexte [$NomTextSeq dump -tag -text 1.0 end]

    set ltag [$NomTextSeq tag names]
    set ltag [lsort -unique $ltag]
    set fnt [$NomTextSeq cget -font ]
    foreach t $ltag {
	set fre [$NomTextSeq tag cget $t -foreground ]
	set bck [$NomTextSeq tag cget $t -background ]
	lappend lct "$t $fre $bck"
    }

    EnvoieDump "OpenFile" $FichierDump
    EnvoieDump font $fnt
    EnvoieDump tags $lct
    EnvoieDump regle $DumpRegle
    EnvoieDump noms  $DumpNoms
    EnvoieDump texte $DumpTexte
    EnvoieDump "CloseFile"

    return
}



proc EnleveLesPoints {} {
    global NomTextSeq LNOrdali LSOrdali LNSeqlab LSSeqlab

    $NomTextSeq configure -state normal
    
    if {[InSeqlabMode]} {
	set Ls $LSSeqlab
	set Ln $LNSeqlab
	set sep [lrepeat " " [llength [lindex $LSSeqlab 0]]] 
    } else {
	set Ln $LNOrdali
	set Ls $LSOrdali
	set sep [string repeat " " [string length [lindex $LSOrdali 0]]]
    }
    
    set Li {}
    set i -1
    foreach n $Ln s $Ls {
	incr i
	if {[string trim $n] ne ""} {
	    continue
	}
	if {! [regexp {\*} $s]} {
	    continue
	}
	lappend Li $i
    }

    foreach i $Li {
	lset Ls $i $sep
    }
    
    if {"PtBack" in [$NomTextSeq tag names]} {
	$NomTextSeq tag delete PtBack
    }

    if {[InSeqlabMode]} {
	set LSSeqlab $Ls
    } else {
	set LSOrdali $Ls
	$NomTextSeq configure -state disabled
    }

    return
}


proc AfficheLesPoints {} {
    global LNDG SDG NomTextSeq LesPointsDuGroupe

    set NbrGrp [expr {[llength $LNDG] - 2}]

    if {$NbrGrp <= 1} {
	return
    }

    $NomTextSeq configure -state normal
    $NomTextSeq tag configure PtBack -background LightGray -foreground black

    set Idx 1
    set ng 1
    set NbrSeq 0
    set IdxGrp 1
    foreach NmGrp $LNDG {
	if {$NmGrp in {"GroupeToutLeMonde" "bidon" "grise"}} {
	    continue
	}

	set col [RGBDeLaCouleur [CouleurDuGroupe $IdxGrp]]
	$NomTextSeq tag configure Pt$NmGrp -foreground $col -background LightGray
	set y [expr {$Idx+$NbrSeq+($ng-1)*2}]

	#	$NomTextSeq delete $y.0 "$y.0 lineend - 1c"
	#$NomTextSeq delete $y.0 "$y.0 lineend"
	#$NomTextSeq insert $y.0 [set LesPointsDuGroupe($NmGrp)]
	#$NomTextSeq tag add PtBack $y.0 "$y.0 lineend"
	set Li [regexp -all -indices -inline {\*} [set LesPointsDuGroupe($NmGrp)]]
	foreach c $Li {
	    lassign $c d f 
	    #$NomTextSeq tag add Pt$NmGrp $y.$d
	}

	set NbrSeq [expr {$NbrSeq + [llength [set SDG($NmGrp)]]}]
	incr ng
	incr IdxGrp
    }

    $NomTextSeq configure -state disabled

    return
}


proc GammeDeCouleursRVB {NbCouleurs {Ordre "Degrade"}} {

    if {$NbCouleurs <= 1} {return [list "blue"]} 

    set AngleEcart [expr {[Pi] / ($NbCouleurs - 1)}]
    set LesCouleurs {}
    for {set i 0} {$i < $NbCouleurs} {incr i} {
	set Angle [expr {$AngleEcart * $i}]

	if {0 < sin($Angle+[PiS2])} {set R [expr {round(sin($Angle+[PiS2])* 255)}]} else {set R 0}
	if {0 < sin($Angle)} {set V [expr {round(sin($Angle) * 255)}]} else {set V 0}
	if {0 < sin($Angle-[PiS2])} {set B [expr {round(sin($Angle-[PiS2])* 255)}]} else {set B 0}

	set RHexa [Deci2Hexa $R]
	set VHexa [Deci2Hexa $V]
	set BHexa [Deci2Hexa $B]

	lappend LesCouleurs "\#$RHexa$VHexa$BHexa"
    }

    if {$Ordre == "Random"} {
	return [lsort -command TrieAleatoirement $LesCouleurs]
    } else {
	return $LesCouleurs
    }
}


proc GammeDeCouleursDeGris {NbCouleurs {Ordre "Degrade"}} {

    if {$NbCouleurs <= 1} {return [list "white"]} 

    set LesCouleurs {}
    for {set i 0} {$i < $NbCouleurs} {incr i} {
	set Val [expr {255 - round($i * 255.0 / $NbCouleurs)}]
	set HexaVal [Deci2Hexa $Val]
	lappend LesCouleurs "\#$HexaVal$HexaVal$HexaVal"
    }

    if {$Ordre eq "Random"} {
	return [lsort -command TrieAleatoirement $LesCouleurs]
    } else {
	return $LesCouleurs
    }
}


proc CouleursOrdali {MolId} {

    set chnok [string trim [string index $MolId 5]]
    if {$chnok == ""} {set chnok "a"}
    set mol [string range $MolId 0 3]

    global Defauts
    global SDG
    global LNDG
    global Couleurs
    global Sequences
    global PDB_[set mol]_Sequence
    global TableauCouleurEtGroupe
    global ListeDesSpheres
    global LesPointsDuGroupe
    global NomEtSeqAssPDB

    set AColorier {}

    set NombreDeGroupes [llength $LNDG]
    set NbrGrp [expr {$NombreDeGroupes-2}]

    if {[lindex $LNDG end] != "grise"} {return}

    foreach elt $NomEtSeqAssPDB {
	scan $elt "%s %s %s" PDB NomSeqSel LaMolId
	if {$LaMolId == $MolId} {break}
    }
    set SeqSel $NomSeqSel
    set SeqAss [set Sequences($SeqSel)]
    set LongueurAli [string length $SeqAss]
    set SeqAlignee [lindex [set PDB_[set mol]_Sequence($chnok)] 1]
    set ListeDesSpheres($mol) {}

    set IdxDernierGroupe [expr {[llength $LNDG] - 2}]
    foreach groupe [lrange $LNDG 1 $IdxDernierGroupe] {
	set Ya [lsearch [set SDG($groupe)] $SeqSel]
	if {$Ya != -1} {
	    set NoGr [lsearch $LNDG $groupe]
	    set NmGr $groupe
	}
    }

    foreach e [array names TableauCouleurEtGroupe] {
	set Typecons [set TableauCouleurEtGroupe($e)]
	scan $e "%d,%d" ix iGr

	if {$NoGr != $iGr} {continue}
	if {[string index $SeqAss $ix] != "." && [string index $SeqAlignee $ix] !="."} {
	    set equiv [CorrespondanceAliPDB $MolId $ix $ix $SeqAss $SeqAlignee]
	    set NroRes [lindex $equiv 0]
	} else {
	    continue
	}

	if {[regexp "CoulG" $Typecons]} {
	    set CoulG [CouleurO2Ordali [CouleurDuGroupe $NoGr]]
	    set fgo $CoulG
	} else {
	    scan [set Couleurs($Typecons)] "%s %s" fg bg
	    set fgo $fg
	}

	if {$Typecons == "SimiGlob"} {
	    set fgo [set Defauts(CoulVariable)]
	}
	if {$Typecons == "IdenGlob"} {
	    set fgo $bg
	}
	if {$Typecons == "ConsGlob"} {
	    set fgo $bg
	}
	if {[regexp "InterG" $Typecons]} {
	    set fgo $bg
	}
	if {[regexp "IdenGr" $Typecons]} {
	    set fgo $bg
	}
	if {[regexp "Gris" $Typecons]} {
	    if {[set Defauts(SimiGris)]} {
		set fgo $fg
	    } else {
		set fgo [set Defauts(CoulVariable)]
	    }
	}
	set ResCou "$NroRes $fgo"

	if {[lindex [set LesPointsDuGroupe($NmGr)] $ix] == "*"} {
	    #		set ResCou "${chnok}$NroRes ${fgo}PTS"
	    set ResCou "$NroRes ${fgo}PTS"
	}
	lappend ListeDesSpheres($mol) $ResCou
	lappend AColorier [list $fgo ${chnok}$NroRes]
    }

    set AColorier [lsort -index 0 $AColorier]

    return $AColorier
}



proc ChangeOrdre {ordre} {

    global Sequences
    global LNOrdali
    global OrdrePrecedent
    global LNDG
    global ListeDesConsensusDuGroupe
    global SDG
    global TableauCouleurEtGroupe
    global lookupGrp
    global lookupCns
    global lookupInt

    if {[QuelMode] eq "seqlab"} {
	FaireLire "Not available in Seqlab mode !"
	return
    }

    set LongueurTotale [string length [set Sequences([lindex $LNOrdali 0])]]

    if {$OrdrePrecedent == $ordre } {return}

    set NombreDeGroupes [llength $LNDG]

    if {[lindex $LNDG end] == "grise"} {
	set DernierGroupe [expr {$NombreDeGroupes-2}]
	set NombreDeGroupes [expr {$NombreDeGroupes-1}]
	set ConsGlob 1
    } else {
	set DernierGroupe [expr {$NombreDeGroupes-1}]
	set ConsGlob 0
    }

    if {$NombreDeGroupes < 4} {
	FaireLire "You should have 3 groups to use this option !!"
	return
    }

    DefinitionLookups $ordre

    if {[info exist TableauCouleurEtGroupe]} {
	for {set i 0} {$i < $LongueurTotale} {incr i} {
	    for {set k 0} {$k <= 4} {incr k} {
		if {[info exist TableauCouleurEtGroupe($i,$k)]} {
		    set Conski [set TableauCouleurEtGroupe($i,$k)]
		    set T($i,[set lookupGrp($k)]) [set lookupCns($Conski)]
		}
	    }
	}

	unset TableauCouleurEtGroupe
	foreach x [array names T] {
	    set TableauCouleurEtGroupe($x) [set T($x)]
	}
    }

    lappend ListeNmGrpTmp [lindex $LNDG 0]
    lappend ListeNmGrpTmp $lookupGrp(1)
    lappend ListeNmGrpTmp $lookupGrp(2)
    lappend ListeNmGrpTmp $lookupGrp(3)

    if {$ConsGlob} {
	lappend ListeNmGrpTmp [lindex $LNDG end]
    }

    foreach Nm [lrange $ListeNmGrpTmp 1 $DernierGroupe] {
	foreach seq [set SDG($Nm)] {
	    lappend ListeSeqOrdreTmp $seq
	    lappend LesNomsSeqGrpTmp($Nm) $seq
	}
    }

    foreach Nm $ListeNmGrpTmp {
	if {![info exists ListeConsGrpTmp($Nm)]} {
	    set ListeConsGrpTmp($Nm) ""
	}
	append ListeConsGrpTmp($Nm) [set ListeDesConsensusDuGroupe($Nm)]
    }

    unset LNOrdali
    unset LNDG
    unset ListeDesConsensusDuGroupe
    set LNDG $ListeNmGrpTmp
    set LNOrdali $ListeSeqOrdreTmp

    foreach x [array names ListeConsGrpTmp] {
	set ListeDesConsensusDuGroupe($x) [set ListeConsGrpTmp($x)]
    }

    set g0 [lindex $LNDG 0]
    set cg0 [set ListeDesConsensusDuGroupe($g0)]
    regsub -all "7" $cg0 "b" cg0
    regsub -all "8" $cg0 "B" cg0
    regsub -all "9" $cg0 "o" cg0
    regsub -all "b" $cg0 "[set lookupInt(7)]" cg0
    regsub -all "B" $cg0 "[set lookupInt(8)]" cg0
    regsub -all "o" $cg0 "[set lookupInt(9)]" cg0

    set ListeDesConsensusDuGroupe($g0) $cg0

    set OrdrePrecedent "123"

    return
}


proc RemoveAllSeparators {} {
    global NomNomSeq NomTextSeq LNSeqlab LSSeqlab LNOrdali LSOrdali SDG LNDG

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[InSeqlabMode]} {
	set Lnoms $LNSeqlab
	set Lseqs $LSSeqlab
    } else {
	set Lnoms $LNOrdali
	set Lseqs $LSOrdali
    }

    set Li [lsearch -all -regexp $Lnoms {^\s*$}]
    set Li [lreverse $Li]
    set nAvant [llength $Lnoms]

    $NomNomSeq configure -state normal
    set state [$NomTextSeq cget -state]
    $NomTextSeq configure -state normal
    # Always keep first and last which are spaces seqs
    set iLast [expr {[llength $Lnoms] - 1}]
    foreach i $Li {
	if {$i == $iLast || $i == 0} {
	    continue
	}
	set Lnoms [lreplace $Lnoms $i $i]
	set Lseqs [lreplace $Lseqs $i $i]

	# Biotext rows start at 0, as list indices
	$NomNomSeq  delete rows $i
	$NomTextSeq delete rows $i
    }
    $NomNomSeq configure -state disabled
    $NomTextSeq configure -state $state

    if {[InSeqlabMode]} {
	set LNSeqlab $Lnoms
	set LSSeqlab $Lseqs
    } else {
	set LNOrdali $Lnoms
	set LSOrdali $Lseqs
	# the instance must be saved with its new layout
	if {[llength $Lnoms] != $nAvant} {
	    VueEditee 1
	}
    }
    # groups follow the separators, as in RemoveSpaceSeq : computed
    # once the lists are updated
    MetAJourGroupes
    # rows have moved : the selected row numbers are wrong
    if {[llength $Lnoms] != $nAvant} {
	ClearSelectionNoms
    }
    # rows removed : the colour of the structure names (tag PDB) must
    # follow their row
    if {[llength $Lnoms] != $nAvant} {
	RepeintNoms
    }

    return
}



proc InitWRegle {} {
    set Lgt [LongueurDeLAlignement [QuelMode]]

    set Comptr "1" ; set Tirets "|"
    for {set i 11} {$i <= $Lgt} {incr i 10} {
	append Tirets "         |"
	append Comptr "[format %10d $i]"
    }
    set reste [expr {($Lgt % 10)}]
    if {$reste == 0} {
	set reste 10
    }
    incr reste -1
    append Comptr [string repeat " " $reste]
    append Tirets [string repeat " " $reste]
    
    set ::TexteWRegle(Tirets) $Tirets
    set ::TexteWRegle(Comptr) $Comptr

    return
}


proc AfficheRegle {{w ".ordali.lessequences"}} {
    global WTexteRegle TexteWRegle

    if {! [ModeI]} {
	return
    }

    $WTexteRegle configure -state normal
    set LseqRegle {}
    lappend LseqRegle [set TexteWRegle(Tirets)]
    lappend LseqRegle [set TexteWRegle(Comptr)]
    $WTexteRegle sequences $LseqRegle
    $WTexteRegle configure -state disabled

    return
}


proc UpdateRegle {} {
    global WTexteRegle TexteWRegle 

    set lgOri [LongueurDeLAlignement [Quelqmode]]
    if {$lgOri == [set lgt [string length $TexteWRegle(Tirets)]]} {
	return
    }

    set diff [expr {$lgt - $lgOri}]
    if {$diff < 0} {
	# just cut to the right length
	set TextWRegle(Comptr) [string range $TexteWRegle(Comptr) 0 end-[expr {abs($diff)}]]
	set TextWRegle(Tirets) [string range $TexteWRegle(Tirets) 0 end-[expr {abs($diff)}]]
    } else {
    }

    $WTexteRegle configure -state normal
    $WTexteRegle delete 1.0 end
    $WTexteRegle  insert end "$TexteWRegle(Tirets)\n$TexteWRegle(Comptr)\n"
    $WTexteRegle configure -state disabled
    
    return
}


proc MarqueSequencesInactives {} {
    global NomNomSeq

    set iVue [MacCourant index]
    set iVis [VisCourante]
    set Li [LesSequencesInactives]

    foreach n $Li {
	set y [expr {[lsearch $LNOrdali $n] + 1}]
	$NomNomSeq tag add SLock $y.0 "$y.0 wordend"
    }

    return
}


proc LockSequencesOut {} {
    global SDG SeqsOut
    
    if {! [info exists SDG(GrSeqOut)]} {return}
    foreach s [set SDG(GrSeqOut)] {
	set SeqsOut($s) 1
    }

    return
}


proc DetectUnselectedSeqs {} {
    global NomSeqSel LNOrdali SeqsOut

    if {! [info exists NomSeqSel] || [llength $NomSeqSel] <= 3} {
	return
    }
    
    foreach p $NomSeqSel {
	lassign [split $p .] y x
	lappend Lsel [lindex $LNOrdali $y-1]
    }
    set Lreste [lor $Lsel $LNOrdali]
    foreach s $Lreste {
	if {[string trim $s] eq ""} {
	    continue
	}
	set SeqsOut($s) 1
    }

    return
}


proc RepeintNomsEtSeqs {} {
    if {! [ModeI]} {
	return
    }
    
    RepeintNoms
    RepeintSeqs
    update idletasks
    
    return
}


proc RepeintNoms {} {
    if {$::Defauts(AffPhy)} {
	ColorieNomsSelonPhylum show
    }
    if {$::Defauts(AffGrp)} {
	ColorieNomsSelonGroupes show
    }
    
    if {[InSeqlabMode]} {
	set LNoms $::LNSeqlab
    } else {
	set LNoms $::LNOrdali
    }

    $::NomNomSeq configure -state normal
    $::NomNomSeq tag remove
    set Ajout {}
    set y 0
    foreach n $LNoms {
	incr y
	if {[string trim $n] in $::ListePDB} {
	    lappend Ajout $y.0 $y.end
	}
    }
    if {$Ajout != {}} {
	$::NomNomSeq tag add PDB {*}$Ajout
    }
    
    if {[InSeqlabMode]} {
	set ListeTags [$::NomNomSeq tag names]
	foreach g [array names ::ListeSeqsGroupees] {
	    set tag "TC$g"
	    if {$tag ni $ListeTags} {
		set ig [string range $g 1 end]
		set bcoul [CouleurO2Ordali [CouleurDuGroupe $ig]]
		$::NomNomSeq tag configure $tag -background $bcoul -foreground black
	    }
	    set LtoAdd {}
	    foreach s [set ::ListeSeqsGroupees($g)] {
		set i [expr {[lsearch -exact $::LNSeqlab $s] + 1}]
		lappend LtoAdd $i.0 $i.end
	    }
	    if {$LtoAdd != {}} {
		$::NomNomSeq tag add "TC$g" {*}$LtoAdd
	    }
	}
    }
    $::NomNomSeq configure -state disabled
    
    TagNomsSelectionnes

    return
}


proc RepeintSeqs {} {
    global Cons Defauts ZoneSelect LFeatCourantes

    # displayed secondary structures are drawn again (ToggleSecStr
    # hid them : displayed with the menu item unchecked)
    if {[set Defauts(AffSS)]} {
	MontreStrSecDansAlignement
    }

    switch [QuelMode] {
	"feature" {
	    set Lf [lreverse $LFeatCourantes]
	    if {$Lf != {} } {
		ColorieSelonFeature "Clear"
		foreach f $Lf {	
		    ColorieSelonFeature $f
		}
	    }
	}
	"search" {
	    ChercheMotif
	}
	"annotation" {}
	"arbres" {
	    AfficheZonesSelectionnees $ZoneSelect
	}
	"conservation" {
	    AppliqueFeature Clear
	    set ft [lindex $Cons(ConsCou) 0]
	    if {$ft ne "None"} {
		AppliqueFeature $ft
	    }
	}
	"cluster" {
	    #	    ChangeFeaturePourCluster
	    AfficheZonesSelectionnees $ZoneSelect
	}
	"superpose" {
	    AfficheZonesSelectionneesSuper
	}
	default {}
    }

    return
}


proc RafraichitAffichage {} {

    MetAJourNomsEtSeqs
    ChangeNomsAff $::Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs

    return
}


proc InitAffichage {} {
    if {[TypeAli] eq "pasdali" || ! [ModeI]} {
	return
    }

    #InitWRegle
    #AfficheRegle

    MiseAJourMac
    #MontreStrSecDansAlignement
    
    return
}


proc AfficheNomsEtSeqs {} {
    global NomsAffiches LSOrdali LSSeqlab NomNomSeq NomTextSeq TScrollY
    
    if {! [ModeI]} {
	return
    }
    
    # Record Y-scrollbar position
    lassign [$TScrollY get] YPos tmp
    
    EffaceWNomsWSeqs

    $NomNomSeq configure -state normal
    set Ltmp [DonneMemeLongueurListe $NomsAffiches]
    $NomNomSeq sequences $Ltmp
    $NomNomSeq configure -state disabled

    $NomTextSeq configure -state normal
    if {! [InSeqlabMode]} {
	set Ltmp [DonneMemeLongueurListe $LSOrdali]
	$NomTextSeq sequences $Ltmp
	$NomTextSeq configure -state disabled
    } else {
	# in seqlab mode
	set bool [$NomTextSeq map]
	set Ltmp [lmap s $LSSeqlab {join $s ""}]
	set Ltmp [DonneMemeLongueurListe $Ltmp]
	$NomTextSeq sequences $Ltmp
	if {$bool} {
	    set map [set ::Defauts(Mapping)]
	    $NomTextSeq mapping $map
	    $NomTextSeq map $bool
	}
    }

    OrdaliDefaultTags
    TagNomsSelectionnes
    
    CoupleY moveto $YPos
    update idletasks
    
    return
}


proc EffaceWNomsWSeqs {} {
    global NomTextSeq NomNomSeq
    
    $NomNomSeq configure -state normal
    $NomNomSeq delete rows 0 end
    $NomNomSeq tag remove
    $NomNomSeq configure -state disabled
    
    $NomTextSeq configure -state normal
    $NomTextSeq delete rows 0 end
    $NomTextSeq tag remove
    $NomTextSeq configure -state disabled
    
    update idletasks    

    return
}


proc MetAJourNomsEtSeqsPourMisynpat {} {
    #rR pour eviter d'avoir des séquences en double
    global LNOrdali LSOrdali Sequences

    foreach s $LNOrdali {
	lappend LSOrdali [set Sequences($s)]
    }
    
    return 
}


proc MetAJourNomsEtSeqs {} {
    # Create display lists:
    # - LNOrdali, LSOrdali, LNSeqlab, ..
    # called by: CreeVue , RafraichitAffichage
    
    global LNOrdali LSOrdali SDG LNDG Sequences
    
    set Lnoms {}
    set Lseqs {}
    
    set LNDG [ReordonneGroupes $LNDG]
    if {[llength [lsearch -regexp -all $LNDG {^Group}]] > 1} {
	set Lg [lrange $LNDG 1 end]
    } else {
	set Lg [lindex $LNDG 0]
    }

    # Always one sequence in group GroupeToutLeMonde
    set tmpN [lindex $SDG(GroupeToutLeMonde) 0]
    set tmpS $Sequences($tmpN)
    set LgSeq [string length $tmpS]
    set LgNom [PlusLongEltDe [array names $SDG(GroupeToutLeMonde)]]

	       set sepS [string repeat " " $LgSeq]
    set sepN [string repeat " " $LgNom]
    
    foreach g $Lg {
	if {[string first "Group" $g] != 0} {
	    continue
	}
	
	lappend Lnoms $sepN
	lappend Lseqs $sepS
	foreach n [set SDG($g)] {
	    lappend Lnoms $n
	    lappend Lseqs [set Sequences($n)]
	}
	lappend Lnoms $sepN
	lappend Lseqs $sepS
    }
    
    set LNOrdali $Lnoms
    set LSOrdali $Lseqs
    
    return
}


proc ColorieNomsSelonGroupes {{quoi show}} {
    global SDG LNOrdali Defauts LNSeqlab NomNomSeq LNDG

    # group and phylum colors are exclusive : showing the groups
    # hides the phylum colors
    if {[set Defauts(AffPhy)]} {
	if {! $Defauts(AffGrp)} {
	    return
	}
	set Defauts(AffPhy) 0
	foreach t {NPEuk NPArk NPPro NPVir} {
	    catch {$NomNomSeq tag remove $t}
	}
    }

    if {[TypeAli] eq "pasdali"} {
	return
    }

    # seqlab ou pas
    if {[InSeqlabMode]} {
	set Lrefs $LNSeqlab
    } else {
	set Lrefs $LNOrdali
    }

    if {$Defauts(AffGrp)} {
	set quoi show
    } else {
	set quoi hide
    }

    set Lig {}
    foreach g $LNDG {
	if {! [regexp {^Group[0-9]+} $g]} {
	    continue
	}
	lappend Lig [string range $g 5 end]
    }
    if {$Lig == {}} {
	return
    }

    $NomNomSeq configure -state normal

    if {$quoi eq "hide"} {
	foreach i $Lig {
	    catch {$NomNomSeq tag remove TCG$i}
	}
	$NomNomSeq configure -state disabled

	return
    }

    if {"0" in $Lig} {set m 1} {set m 0}
    foreach icol $Lig {
	set g "Group$icol"
	set col [CouleurO2Ordali [CouleurDuGroupe [expr {$icol + $m}]]]
	$NomNomSeq tag configure TCG$icol -background $col -foreground black
	set Lt {}
	foreach n $SDG($g) {
	    set y [lsearch $Lrefs $n]
	    incr y
	    lappend Lt $y.0 "$y.end"
	}
	$NomNomSeq tag add TCG$icol {*}$Lt
    }
    $NomNomSeq tag raise PDB

    $NomNomSeq configure -state disabled

    return
}


proc ColorieNomsSelonPhylum {{quoi show}} {
    global NomNomSeq TDesPhylum LNOrdali Defauts LNSeqlab

    if {! [ModeI]} {
	return
    }

    # group and phylum colors are exclusive : showing the phylum
    # hides the group colors
    if {[set Defauts(AffGrp)]} {
	if {! $Defauts(AffPhy)} {
	    return
	}
	set Defauts(AffGrp) 0
	foreach t [lsearch -all -inline [$NomNomSeq tag names] TCG*] {
	    catch {$NomNomSeq tag remove $t}
	}
    }
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {! [info exists TDesPhylum]} {
	if {$quoi eq "hide"} {
	    return
	}
	FaireLire "No Life Domain information available !"
	return
    }

    if {[set Defauts(AffPhy)]} {
	set quoi show
    } else {
	set quoi hide
    }

    $NomNomSeq configure -state normal

    if {$quoi eq "hide"} {
	foreach t {NPEuk NPArk NPPro NPVir} {
	    catch {$NomNomSeq tag remove $t}
	}
	$NomNomSeq configure -state disabled

	return
    }

    # seqlab ou pas
    if {[InSeqlabMode]} {
	set Lrefs $LNSeqlab
    } else {
	set Lrefs $LNOrdali
    }

    $NomNomSeq tag configure NPEuk \
	-background $Defauts(BgEukaryota) \
	-foreground $Defauts(FgEukaryota)
    $NomNomSeq tag configure NPArk \
	-background $Defauts(BgArchaea) \
	-foreground $Defauts(FgArchaea)
    $NomNomSeq tag configure NPPro \
	-background $Defauts(BgBacteria) \
	-foreground $Defauts(FgBacteria)
    $NomNomSeq tag configure NPVir \
	-background $Defauts(BgViruses) \
	-foreground $Defauts(FgViruses)

    # attention problemen avec Retournetableau
    RetourneTableau TDesPhylum New
    foreach e {Eukaryota Archaea Bacteria Viruses} t {NPEuk NPArk NPPro NPVir} {
	if {! [info exists New($e)]} {
	    continue
	} else {
	    set Lnoms [set New($e)]
	}

	set Ltag {}
	foreach n $Lnoms {
	    if {[string trim $n] eq ""} {continue}
	    set i [lsearch $Lrefs $n]
	    if {$i == -1} {
		puts "\nColorieSeleonPhylum\n$n non trouve !"
		continue
	    }
	    incr i
	    lappend Ltag $i.0 "$i.end"
	}
	$NomNomSeq tag add $t {*}$Ltag
    }
    $NomNomSeq configure -state disabled

    return
}


proc ColorieStructureSelonFeature {ft MolId} {
    global TabSF

    set chnok [DonneChainDeAccessPDB $MolId]
    set mol   [DonneIdDeAccessPDB $MolId]
    global PDB_[set mol]_Sequence
    set MolId [BonAccess $MolId]

    set AColorier {}

    foreach f [set TabSF($MolId,$ft)] {
	DecortiqueUneFeature $f dg fg col score note
	set dg [expr {$dg-1}]
	if {$col eq "black"} {set col "white"}

	for {set i $dg} {$i < $fg} {incr i} {
	    set NroRes [CorrespondanceGenPDB $MolId $i]
	    lappend AColorier [list $col ${chnok}$NroRes]
	}
    }

    set AColorier [lunique [lsort -index 0 $AColorier]]

    return $AColorier
}


proc ColorieSelonFeature {ft {w ""}} {
    if {$ft ne "Clear"} {
	if {$w eq ""} {
	    set w [BtnDeLaFeature $ft]
	}
	set Etat [ChangeEtatBouton $w]
	LesFeaturesUtilisees $ft $Etat
    }

    AppliqueFeature $ft

    return
}


proc AppliqueFeature {ft} {
    global NomTextSeq ListeTypesDeFeatures LNOrdali TabSF ScoreMeth Defauts

    if {! [ModeI]} {
	return
    }
    
    set state [$NomTextSeq cget -state]
    $NomTextSeq configure -state normal
    
    if {$ft eq "Clear" || $ft eq "None"} {
	set Ltags [$NomTextSeq tag names]
	set ToDelete [lsearch -all -inline -regexp $Ltags {^(FX\_|FDisp\_)}]
	
	if {$ToDelete != {}} {
	    foreach ft $ToDelete {
		#$NomTextSeq tag remove $ft
		$NomTextSeq tag delete $ft
	    }
	}
	
	if {! [InSeqlabMode]} {
	    ResetDesBoutons
	    MetAJourDessinOverview -1 "" "None" 1
	    if {[lsearch -regexp $ListeTypesDeFeatures "Cons-T"] != -1} {
		EnleveLesPoints
	    }
	}
	
	$NomTextSeq configure -state $state
	update idletasks

	return
    }
    
    # Draw or Hide a given feature
    set ftnsp [string map {" " ""} $ft]
    
    set Lt [$NomTextSeq tag names]
    set LaFeat [lsearch -regexp -all -inline $Lt "_${ftnsp}_"]
    if {$LaFeat ne ""} {
	foreach remft $LaFeat {
	    #$NomTextSeq tag remove $remft
	    $NomTextSeq tag delete $remft
	}
	    MetAJourDessinOverview -1 "" $ft 0
	
	if {[QuelMode] eq "feature"} {
	    if {[regexp "Cons-" $ft]} {
		setTooltip [BtnDeLaFeature $ft] ""
	    }
	    if {[regexp "Cons-T" $ft]} {
		EnleveLesPoints
	    }
	}
	$NomTextSeq configure -state $state
	
	return
    }
    
    # Feature is not present
    if {[regexp {^Cons\-|^Score\-} $ft]} {
	if {[set ScoreMeth($ft,Edit)]} {
	    $NomTextSeq tag configure "EdtFnd_${ftnsp}_1" -background "#ffdddd" -foreground black
	    #$NomTextSeq tag add "EdtFnd_${ftnsp}_1" 1.0 end
	    if {[QuelMode] eq "feature"} {
		setTooltip [BtnDeLaFeature $ft] "Beware ! Conservation is not valid anymore\nas the alignment has changed !"
	    }
	}
	
	if {[regexp "Cons-T" $ft]} {
	    #AfficheLesPoints
	}
	DessineLesScores $ft
    }
    
    set LFeatUse {}
    array set ToTag {}
    set ToTag(Ltags) {}
    foreach key [array names TabSF "*,$ft"] {
	lassign [split $key ,] nom tmp
	set i [expr {[lsearch -exact $LNOrdali $nom] + 1}]
	if {$i == 0} {
	    puts "Erreur ! >$nom< not found in LNOrdali !"
	    continue
	}
	foreach feat [set TabSF($nom,$ft)] {
	    set fgCol "black"
	    DecortiqueUneFeature $feat dg fg bgCol sco note csys
	    
	    if {$Defauts(RemovePropagated) && [string range $note 0 4] eq "PROP_"} {
		continue
	    }
	    
	    if {$bgCol eq "black" || $bgCol eq "DimGray"} {
		set fgCol "white"
	    }
	    
	    set LeTag "FX_${ftnsp}_$bgCol"
	    if {$LeTag ni $ToTag(Ltags)} {
		lappend ToTag(Ltags) $LeTag
		lappend LFeatUse [list $LeTag $fgCol $bgCol]
	    }
	    lappend ToTag($LeTag) $i.$dg $i.$fg
	    
	    if {$note ne ""} {
		set lanote [string map {" " "_"} $note]
		set fdispTag "FDisp_${ftnsp}_$lanote"
		if {$fdispTag ni $ToTag(Ltags)} {
		    lappend ToTag(Ltags) $fdispTag
		    lappend LFeatUse [list $fdispTag "black" "yellow"]
		}
		
		lappend ToTag($fdispTag) $i.$dg $i.$fg
	    }
	}
    }
    set LFeatUse [lsort -index 0 -increasing $LFeatUse]
    foreach currTagObj $LFeatUse {
	lassign $currTagObj currTag fgCol bgCol
	$NomTextSeq tag configure $currTag -foreground $fgCol -background $bgCol
	$NomTextSeq tag add $currTag {*}$ToTag($currTag)
    }
    
    $NomTextSeq configure -state $state
    MetAJourDessinOverview -1 "" $ft 1
    
    return
}


proc DemandeEtSauveFichier {Extion {exc 0} {FichierParDefaut "Untitled"}} {

    set Extion [string tolower $Extion]
    set types {
	{{MSF files}		{.msf}		}
	{{Macsim/XML files}     {.xml}		}
	{{ORD ordalie files}    {.ord}		}
	{{Fasta files}		{.tfa .tfasta .fa}	}
	{{Clustal files}        {.aln}	        }
	{{Tree file}            {.ph}           }
	{{CSV file}            {.csv}           }
	{{PDB files}            {.pdb}          }
	{{O macro files}        {.omac}	        }
	{{Postscript files}     {.ps}	        }
	{{GIF files}	        {.gif}	        }
	{{PNG files}	        {.png}	        }
	{{Jpeg files}	        {.jpg .jpeg}    }
	{{PPM files}	        {.ppm}	        }
	{{All files}		*}
    }

    ReordonneType types $Extion $exc

    set file [tk_getSaveFile -filetypes $types -initialfile $FichierParDefaut]
    update idletasks

    if {[string tolower [file extension $file]] eq ".rsf"} {
	FaireLire "The RSF format is not supported anymore !"
	return ""
    }

    if {$file ne ""} {
	set o [CheckOpen $file]
	if {$o eq ""} {
	    return
	}
	# CheckOpen only checks that the file can be written
	close $o
    }

    return $file
}



proc DemandeEtOuvreFichier {Extion {exc ""} {options ""}} {
    set Extion [string tolower $Extion]

    set types {
	{{MSF files}		{.msf}		}
	{{Macsim/XML files}     {.xml .macsims}	}
	{{ORD Ordalie files}    {.ord}		}
	{{Fasta files}		{.tfa .tfasta .fasta .fa} }
	{{Clustal files}        {.aln .clustal}	        }
	{{PDB files}            {.pdb}          }
	{{CIF files}           {.cif .mmcif}   }
	{{GIF files}	        {.gif}	        }
	{{Jpeg files}	        {.jpg .jpeg}    }
	{{PNG files}	        {.png}	        }
	{{text files}	        {.txt}	        }
	{{CSV file}             {.csv}          }
	{{All files}		*}

    }

    if {$exc eq ""} {
	set exc 0
    }
    
    ReordonneType types $Extion $exc

    if {$Extion == ".msf"} {
	set Extion ""
    }

    set extra ""
    if {$options ne ""} {
	set file [eval tk_getOpenFile {*}$options]
    } else {
	set file [tk_getOpenFile]
    }
    #set file [tk_getOpenFile -filetypes $types]
    
    return $file
}


proc AdieuOrdali {} {
    global NomFenetreOrdali Defauts

    if {[set olog [set Defauts(SaveLog)]] != 0} {
	SauveLeLog $olog
    }
    
    FinDBProfile

    if {[VueEditee] || [FichierModifie]} {
	if {[ModeI]} {
	    set chx [tk_dialog .chx "Warning" "Warning !\nThis alignment has not been saved !\nDo you want to save it before to quit Ordalie ?" "" 0 "Yes" "No" "Cancel"]
	} else {
	    set chx 0
	}
	switch $chx {
	    0 {
		# file dialog closed / cancelled : "Yes" prevails,
		# do not leave without saving
		if {! [SauveLAlignement]} {
		    return
		}
	    }
	    1 {
		# nothing to restore : the ORD file is loaded in memory
		# and is not modified until it is saved. (the backup
		# file FichierOBK it was restored from is never created
		# anymore : "error renaming """)
	    }
	    2 {return}
	}
    }
    
    catch {$::db close}
    NettoieLeTmp

    if {[ModeI]} {
	if {[winfo exists .lulu]} {
	    QuitteViandox
	}
	#Espionne $NomFenetreOrdali
	destroy $NomFenetreOrdali
    }

    if {! [ModeI]} {
	exit
    } else {
	if {$NomFenetreOrdali eq ".ordali"} {
	    exit
	} else {
	    return
	}
    }
}


proc DetruitBoutonsOrdali {} {
    global FrmBouton

    if {! [ModeI]} {return}

    lassign [grid size $FrmBouton] nc nr
    for {set i 1} {$i < $nc} {incr i} {
	set Lf [grid slaves $FrmBouton -column $i]
	foreach f $Lf {
	    grid forget $f
	    #destroy {*}[winfo children $f]
	    foreach c [winfo children $f] {
		if {[catch {destroy $c} Msg]} {
		    puts "Error while deleting $c:\n$Msg\n"
		}
	    }
	    destroy $f
	    update idletasks
	}
    }

    return
}


proc AjouteBoutonFeature {bt cmd} {
    global FrmBtnFea

    # Attention ! Indices de grid commencent a 0 !

    set nc [expr {[lindex [grid size $FrmBtnFea] 0] - 1}]
    set nr [expr {[lindex [grid size $FrmBtnFea] 1] - 1}]

    regsub -all " " $bt "" btns
    set btns [string tolower $btns]
    button $FrmBtnFea.$btns  \
	-text "$bt" \
	-command "$cmd" \
	-width [string length $bt] \
	-background green1

    grid $FrmBtnFea.$btns -in $FrmBtnFea \
	-pady 1 -padx 1 \
	-row $nr -column $nc \
	-rowspan 1 -columnspan 1 -sticky news

    return
}


proc PrintCanvas {canvas {format ""} {imageFile ""}} {
    # empty canvas : no size to compute
    if {[$canvas bbox all] eq ""} {
	FaireLire "Nothing to print !"
	return
    }
    if {$format eq ""} {
	set format "png"
    }

    if {$imageFile eq ""} {
	set imageFile [DemandeEtSauveFichier $format]
	if {$imageFile eq ""} {
	    return
	}
    }
    update idletasks
    after 500

    ## Ensure that the window is on top of everything
    ## else, so as not to get white ranges 
    ## in the image, due to overlapped portions
    ## of the window with
    ## other windows...
    raise [winfo toplevel $canvas]
    update idletasks

    set border [expr {[$canvas cget -borderwidth]+[$canvas cget -highlightthickness]}]
    set view_height [expr {[winfo height $canvas]-2*$border}]
    set view_width  [expr {[winfo width  $canvas]-2*$border}]
    lassign [$canvas bbox all] x1 y1 x2 y2
    set x1 [expr {int($x1-10)}]
    set y1 [expr {int($y1-10)}]
    set x2 [expr {int($x2+10)}]
    set y2 [expr {int($y2+10)}]
    set width  [expr {$x2-$x1}]
    set height [expr {$y2-$y1}]
    set image [image create photo \
		   -height $height \
		   -width $width]

    ## Arrange the scrollregion of the canvas 
    ## to get the whole window visible,
    ## so as to grab it into an image...
    set scrollregion   [$canvas cget -scrollregion]
    set xscrollcommand [$canvas cget -xscrollcommand]
    set yscrollcommand [$canvas cget -yscrollcommand]
    $canvas configure -xscrollcommand {}
    $canvas configure -yscrollcommand {}

    set grabbed_x $x1
    set grabbed_y $y1
    set image_x 0
    set image_y 0
    while {$grabbed_y < $y2} {
	while {$grabbed_x < $x2} {
	    $canvas configure -scrollregion [list $grabbed_x $grabbed_y \
						 [expr {$grabbed_x+$view_width}] [expr {$grabbed_y+$view_height}]]
	    # the view must start at the corner of this piece
	    $canvas xview moveto 0
	    $canvas yview moveto 0

	    update idletasks
	    ## Take a screenshot of the visible canvas part...
	    ## (retried : just after a resize or a raise, the window
	    ## may not be displayed yet)
	    for {set essai 0} {$essai < 10} {incr essai} {
		if {! [catch {image create photo ${image}_tmp \
			-format window -data $canvas}]} {
		    break
		}
		update
		after 200
	    }
	    if {$essai == 10} {
		$canvas configure -scrollregion $scrollregion
		$canvas configure -xscrollcommand $xscrollcommand
		$canvas configure -yscrollcommand $yscrollcommand
		image delete $image
		FaireLire "Can't print the window : is it hidden by another window ?"
		return
	    }
	    ## Copy the screenshot to the target image...
 	    $image copy ${image}_tmp \
		-to $image_x $image_y -from $border $border
	    incr grabbed_x $view_width
	    incr image_x   $view_width
	    
	    image delete ${image}_tmp
	}
	set grabbed_x $x1
	set image_x 0
	incr grabbed_y $view_height
	incr image_y   $view_height
    }
    $canvas configure -scrollregion $scrollregion
    $canvas configure -xscrollcommand $xscrollcommand
    $canvas configure -yscrollcommand $yscrollcommand

    $image write $imageFile -format $format

    return $image
}



proc PrintCanvasToGif2 {w {fileout ""}} {

    if {$fileout eq ""} {
	set fileout [DemandeEtSauveFichier gif]
	if {$fileout eq ""} {return}
    }

    image create photo .savetogif -format window -data $w
    .savetogif write $fileout -format jpeg

    return $fileout
}


proc DetruitLaFeature {f} {
    global EtatBtnFeat TabSF ListeTypesDeFeatures

    set i [lsearch $ListeTypesDeFeatures $f]
    if {$i == -1} {return}

    if {[QuelMode] eq "feature"} {
	set w [BtnDeLaFeature $f]
	if {$w ne ""} {
	    if {[EtatDuBouton $w]} {ColorieSelonFeature $f $w}
	    catch {array unset EtatBtnFeat $w}
	}
    }
    set ListeTypesDeFeatures [lreplace $ListeTypesDeFeatures $i $i]
    catch {array unset TabSF "*,$f"}
    # scores of a conservation feature : EnregistreLeMac writes them
    # in the instance, and CreeVue creates the feature again from them
    if {[string match "Cons-*" $f]} {
	array unset ::ScoreMeth "$f,*"
    }

    return
}


proc EnleveConservation {} {
    global ListeTypesDeFeatures Toggle

    set Li [lsearch -regexp -all $ListeTypesDeFeatures "Cons-"]
    if {$Li == {}} {return}

    set Li [lsort -integer -decreasing $Li]
    foreach i $Li {
	set f [lindex $ListeTypesDeFeatures $i]
	DetruitLaFeature $f
	DessineLesScores ""
    }

    if {[set Toggle(Feature)] && [QuelMode] eq "feature"} {
	DetruitBoutonsOrdali
	AfficheBoutonsFeatures
    }
    if {[set Toggle(Scores)]} {
    }

    return
}


proc ReFaitText {} {
    global NomTextSeq NomNomSeq

    $NomNomSeq configure  -state normal
    $NomTextSeq configure -state normal
    catch {$NomNomSeq  edit redo}
    catch {$NomTextSeq edit redo}
    $NomNomSeq  configure -state disabled
    $NomTextSeq configure -state disabled

    return
}


proc GardeClustering {{quoi "new"}} {
    global Clus

    MetAJourGroupes
    if {$quoi eq "new"} {
	lassign [DemandeTitreEtDescDuMac] titre desc ctitre cdesc
	set Clus(Titre) $titre

	EnregistreLeMac $titre "[DescriptionDuMac]"
	MetAJourWMacs
    } else {
	EnregistreLeMac
    }
    
    set Clus(NewEntry) 1
    set Clus(MethodeCalculee) "User"

    LogClustering
    
    return
}


proc NouveauClustering {{quoi ""}} {
    global Clus ZoneSelect ZoneClusterisation NomSeqSel SDG LNDG LNOrdali

    # No criterion selected
    set LCriteres {}
    foreach f [array names Clus "LCrit,*"] {
	if {[set Clus($f)]} {
	    lassign [split $f ,] tmp type
	    lappend LCriteres "$type"
	}
    }
    if {$LCriteres == {} && $quoi != "nogroups"} {
	FaireLire "Beware !\nNo criterion selected !"
	return
    }

    if {[llength $LCriteres] > 1 && "Life Domain" in $LCriteres} {
	FaireLire "Beware !\n'Life Domain' criterion can only be used alone !"
	return
    }

    if {$quoi eq "" && "Life Domain" ni $LCriteres && \
	    (! [info exists Clus(Method)] || $Clus(Method) eq "")} {
	FaireLire "Beware !\nNo clustering method selected !"
	return
    }

    DetectUnselectedSeqs
    if {$NomSeqSel == {}} {
	# select all sequences
	set i 0
	foreach n [$::NomNomSeq output all] {
	    incr i
	    set n [string trim $n]
	    if {$n ne ""} {
		lappend NomSeqSel "$i.0"
	    }
	}
    }
    if {$ZoneSelect == {}} {
	SelectionneToutesColonnes
    }
    set ZoneClusterisation $ZoneSelect

    # alignement selections
    set Lvide [AlignementDesSelections $ZoneClusterisation SAli]
    set Lnom {} ; set Lseq {}
    foreach {n s} $SAli {
	lappend Lnom $n
	lappend Lseq $s
    }

    if {$quoi eq "nogroups"} {
	# no criterion to compute
	set LCriteres {}
    } elseif {[llength $Lnom] < 3} {
	# Tclcluspack crashes with less than 2 individuals
	FaireLire "Beware !\nLess than 3 selected sequences have residues\nin the selected columns !"
	return
    }

    # Prepare and compute criterions 
    #
    # Lvals : list to be clustered. Start with ID
    set Lval $Lnom
    foreach type $LCriteres {
	set Lv {}
	switch $type {
	    "% identity" {
		CalculeLesPCIGenerique $SAli TPCI
		foreach n1 $Lnom {
		    set tmp {}
		    foreach n2 $Lnom {
			lassign [set TPCI($n1,$n2)] pc l1 l2 lsl
			lappend tmp [expr {1.0 - $pc}]
		    }
		    lappend Lv $tmp
		}
	    }
	    "length" {
		foreach s $Lseq {
		    set tmp [string map {"." "" " " ""} $s]
		    lappend Lv [string length $tmp]
		}
		set Lv [Standardise $Lv]
	    }
	    "hydrophobicity" {
		set Lv {}
		foreach s $Lseq {
		    lappend Lv [DonneHydrophobicityDe $s]
		}
		set Lv [Standardise $Lv]
	    }
	    "pI" {
		set Lv {}
		foreach s $Lseq {
		    lappend Lv [DonnePIDe toto $s]
		}
		set Lv [Standardise $Lv]
	    }
	    "aa composition" {
		set Lv {}
		foreach s $Lseq {
		    set tmp [DonneCompositionDe toto $s]
		    set va {}
		    foreach a $tmp {
			lappend va [expr {$a/100.}]
		    }
		    lappend Lv $va
		}
	    }
	    "Life Domain" {
		set quoi "phylum"
		break
	    }
	}
	set tmp {}
	# add new values to be clustered to list
	foreach a $Lval v $Lv {
	    lappend a {*}$v
	    lappend tmp $a
	}
	set Lval $tmp
    }
    
    if {$quoi eq ""} {
	set quoi $Clus(Method)
    }
    # Tclcluspack raises a Tcl error when clustering fails
    # (e.g. EM never converges) : warn and keep current groups
    if {$quoi ni {phylum nogroups}} {
	switch $quoi {
	    "kmeans / DPC"         {set Lopt {-cm kmeans -nbc dpc}}
	    "hierarchic / secator" {set Lopt {-cm hierar -nbc secator}}
	    "mixture model / AIC"  {set Lopt {-cm mm -nbc aic}}
	    "mixture model / BIC"  {set Lopt {-cm mm -nbc bic}}
	    default {
		FaireLire "Beware !\nUnknown clustering method '$quoi' !"
		return
	    }
	}
	if {[catch {Tclcluspack $Lval -dt coordinates {*}$Lopt} Lgr]} {
	    FaireLire "Beware !\nClustering failed :\n$Lgr"
	    return
	}
    }
    switch $quoi {
	"kmeans / DPC" {
	    ClusterSeqsDeCluspackTcl $Lgr SDG LNDG
	    set Clus(MethodeCalculee) dpc
	}
	"hierarchic / secator" {
	    ClusterSeqsDeCluspackTcl $Lgr SDG LNDG
	    set Clus(MethodeCalculee) secator
	}
	"mixture model / AIC" {
	    ClusterSeqsDeCluspackTcl $Lgr SDG LNDG
	    set Clus(MethodeCalculee) mixturemodelaic
	}
	"mixture model / BIC" {
	    ClusterSeqsDeCluspackTcl $Lgr SDG LNDG
	    set Clus(MethodeCalculee) mixturemodelbic
	}
	"phylum" {
	    if {! [PhylumClustering LNDG SDG $Lnom]} {
		return
	    }
	    set Clus(MethodeCalculee) phylum
	    set ::Defauts(AffPhy) 1
	    update
	}
	"nogroups" {
	    set LNDG GroupeToutLeMonde
	    unset SDG
	    foreach n $LNOrdali {
		if {[string trim $n] ne ""} {
		    lappend SDG(GroupeToutLeMonde) $n
		}
	    }
	    set Clus(MethodeCalculee) nogroup
	    set Lvide {}
	}
    }
    
    AjouteGroupeToutLeMonde
    if {$Clus(ShowSeqOut)} {
	if {! [info exists Lvide]} {
	    set Lvide {}
	}
	GroupeRestant SDG LNDG $Lvide
    }
    AssignSeqToGroup
    # new groups : the instance must be saved
    VueEditee 1

    ClearSelections
    InitConsensus
    InitPoints
    
    ColorieSelonFeature "Clear"
    EnleveConservation
    RafraichitAffichage
    
    ChangeFeature $Clus(Combo)

    AfficheZonesSelectionneesCluster

    return
}


proc ChangeFeature {{w ""}} {
    global NomTextSeq
    
    if {$w eq ""} {
	return
    }
    
    set feat [$w get]
    AppliqueFeature "Clear"
    AppliqueFeature $feat

    set fnsp [string map {" " "_"} $feat]
    set Ltags [$NomTextSeq tag names]
    foreach t $Ltags {
	if {[regexp "FX_$fnsp" $t]} {
	    #$NomTextSeq tag bind $t <Control-1> {SelectLaFeature @%x,%y ; break}
	}
    }
    
    return
}


proc EditeClusterEntry {w} {
    if {$::Clus(NewEntry)} {
	$w delete 0 end
	set $::Clus(NewEntry) 0
    }

    return
}


proc LanceCalculConservation {} {
    global Cons ScoreMeth

    # specificity-determining positions : own feature and display
    if {$Cons(Method) eq "GroupSim"} {
	return [LanceCalculGroupSim]
    }
    if {$Cons(Method) eq "Multi"} {
	set ret [ChooseMethodsForMulti]
	if {$ret == 0} {
	    return
	}
    }
    
    set ft [PrepareRunOrdali]

    if {$Cons(Entry) ne ""} {
	set Cons(Title) [$Cons(Entry) get]
    }
    lappend Cons(ListeCons) [list $ft $Cons(Title)]
    if {$Cons(ComboSel) ne ""} {
	set Lfeat {}
	foreach fttl $Cons(ListeCons) {
	    lassign $fttl feat title
	    lappend Lfeat $feat
	}
	set wdt [PlusLongEltDe $Lfeat]

	$Cons(ComboSel) configure -values $Cons(ListeCons) -width $wdt
	$Cons(ComboSel) current [expr {[llength $Cons(ListeCons)]-1}]
    }
    set Cons(ConsCou) $ft

    set ScoreMeth($ft,Title)   $Cons(Title)
    set ScoreMeth($ft,Methode) $Cons(Method)

    ChangeConservation

    return $ft
}


proc ChangeConservation {} {
    global Cons

    set ccou [lindex [set Cons(ConsCou)] 0]
    set Cons(Title) [lrange $Cons(ConsCou) 1 end]
    
    RepeintNomsEtSeqs

    return
}


proc ExporteScoreConservation {} {
    # Save conservation score as CSV file
    global Cons TColScore Defauts

    if {$Cons(ConsCou) eq "None"} {
	return
    }

    # combobox entries are "feature title" : keep the feature name only
    set ft [lindex [SauveConservation] 0]

    set file "[file rootname $Defauts(Fichier[TypeAli])]_$ft.csv" 
    if {[file exists $file]} {
	file delete $file
    }
	
    set o [CheckOpen $file]
    if {$o eq ""} {
	FaireLire "Error ! File $file can not be saved !"
	return
    }

    set Li {}
    for {set i 1} {$i < [llength [lindex $TColScore($ft,Data) 0]]} {incr i} {
	lappend Li $i
    }
    puts $o ",[join $Li ,]"
    foreach gr $TColScore($ft,Owner) data $TColScore($ft,Data) {
	#set data [KirsleyData $data]
	puts $o "$gr,[join $data ,]"
    }
    close $o
    
    return
}


proc SauveConservation {} {
    global TabSF ListeTypesDeFeatures ScoreMeth Cons ConsMeth TColScore LNDG
    
    if {$Cons(ConsCou) eq "None"} {
	return
    }
    if {[regexp {^Cons\-} $Cons(ConsCou)]} {
	return [lindex $Cons(ConsCou) 0]
    }
    
    set ftold [lindex $Cons(ConsCou) 0]
    # check if feature to be saved already exists
    set ftnew [string range $ftold 3 end]
    set ifin [string last "_" $ftnew]
    if {$ifin > 4} {
	# is of form Cons_XXX_n
	set ext [string range $ftnew [string last "_" $ftnew]+1 end]
	if {[regexp {[0-9]*} $ext]} {
	    set ftnew [string range $ftnew 0 [string last "_" $ftnew]-1]
	}
    }
    set if 0
    set iftv [lsearch -all -regexp $ListeTypesDeFeatures "^$ftnew"]
    if {$iftv ne ""} {
	set if [llength $iftv]
    }
    
    # replace tmp feat by normal one
    set ftrad $ftnew
    if {$if > 0} {
	set ftnew "${ftnew}_$if"
    }

    # replace in TabSF
    set Lf [array names TabSF "*,$ftold"]
    foreach f $Lf {
	regsub ",$ftold" $f ",$ftnew" nf
	set TabSF($nf) [set TabSF($f)]
    }

    set Lf [array names ScoreMeth "${ftold},*"]
    foreach f $Lf {
	regsub "$ftold" $f "$ftnew" nf
	set ScoreMeth($nf) [set ScoreMeth($f)]
    }
    array unset ScoreMeth "${ftold},*"
    set ConsMeth(${nf},Title) [set Cons(Title)]

    DetruitLaFeature $ftold
    lappend ListeTypesDeFeatures $ftnew

    # update TColScore
    lappend TColScore(Names) $ftnew
    foreach g $LNDG {
	if {$g eq "grise" || $g eq "bidon"} {
	    continue
	}
	# are there data for this group ?
	if {! [info exists ScoreMeth($ftnew,Edit)]} {
	    continue
	}
	set Lv [lsort -dictionary [array names ScoreMeth "$ftnew,$g,*"]]
	set data {}
	set cmp -1
	foreach v $Lv {
	    lassign [split $v ,] tmp tmp i
	    while {$cmp < $i} {
		incr cmp
		lappend data 0
	    }
	    lappend data $ScoreMeth($v)
	    incr cmp
	}
	incr cmp
	for {set i $cmp} {$i < [LongueurDeLAlignement]} {incr i} {
	    lappend data 0
	}

	if {$data == {} || [llength [lsort -unique $data]] == 1} {
	    continue
	}
	if {$g eq "GroupeToutLeMonde"} {
	    set g "all"
	}
	lappend TColScore($ftnew,Data) $data
	lappend TColScore($ftnew,Owner) $g
	lappend TColScore($ftnew,Group) ""
	lappend TColScore($ftnew,Type) int
    }

    set i [lsearch -regexp $Cons(ListeCons) "$ftold"]
    set titre [lrange [lindex $Cons(ListeCons) $i] 1 end]
    set newf "$ftnew [join $titre]"
    set Cons(Title) ""
    set Cons(ConsCou) $ftnew
    if {[info exists Cons(ComboSel)] && $Cons(ComboSel) ne ""} {
	set Cons(ListeCons) [lreplace $Cons(ListeCons) $i $i $newf]
	$Cons(ComboSel) configure -values $Cons(ListeCons)
	$Cons(ComboSel) current $i
    }

    VueEditee 1

    return $ftnew
}


proc QuitteModeConservation {w} {
    global Cons ListeTypesDeFeatures ScoreMeth CurrentMode

    if {$Cons(Show)} {
	set Cons(Show) 0
	update idletasks
    }
    # "include PDB" only lasts while the tool is open
    set ::Defauts(PDBDansPilier) 0
    unset -nocomplain Cons
    set Li [lsearch -all -regexp $ListeTypesDeFeatures "tmpCons"]
    if {$Li ne ""} {
	set Li [lsort -decreasing -integer $Li]
	foreach i $Li {
	    # DetruitLaFeature also removes f from ListeTypesDeFeatures
	    DetruitLaFeature [lindex $ListeTypesDeFeatures $i]
	}
    }

    array unset ScoreMeth "tmpCons*"

    AppliqueFeature Clear

    destroy $w

	    ChangeMode $CurrentMode

    return
}


proc QuitteModeClusters {w} {
    unset -nocomplain ::Clus
    #    catch {unset ::ZoneCFlusterisation}

    ClearSelections
    destroy $w

    ChangeMode $::CurrentMode

    BindModeNormal
    
    return
}


proc InfosSurOrdali {} {
    global OrdEtcDir

    set fm [file join $OrdEtcDir "MACSIM_100px_transparent.gif"]
    image create photo imacs
    imacs read $fm -shrink
    set hgt [expr {[imacs cget -height] / 10}]

    set w ".info"
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    toplevel $w
    wm title $w "About Ordalie ..."
    wm iconname $w "Info"
    wm resizable $w 0 0
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    
    frame $w.f
grid $w.f -row 0 -column 0 -sticky news

    label $w.f.l \
	-image imacs \
	-height [imacs cget -height]
    grid $w.f.l -row 0 -column 0 -padx 10
    text $w.f.t \
	-borderwidth 0 \
	-font "Helvetica 14 bold" \
	-bg "#ffffffffe0e0" \
	-takefocus 0 \
	-width 40
    grid $w.f.t -row 0 -column 1 -padx 10
    set wt "$w.f.t"
    button $w.b \
	-text " Close " \
	-bg green1 \
	-command "destroy $w"
    grid $w.b -row 1 -column 0 -pady 20 

    $wt tag configure TresGrosGras -font "Helvetica 20 bold"
    $wt tag configure GrosGras -font "Helvetica 14 bold"
    $wt tag configure normal -font "Helvetica 12"
    $wt tag configure souli -underline on

    $wt insert end "\nOrdali    " TresGrosGras
    $wt insert end "Version : $::VersionDeOrdali\n\n\n" GrosGras
    $wt insert end "\251 1997-[clock format [clock scan now] -format %Y] Luc Moulinier and LBGI\n\n" normal
    $wt insert end "Bugs and comments should be address to\n" normal
    $wt insert end "luc.moulinier.fr@unistra.fr\n" souli

    set hgt [expr {[regsub -all "\n" [$wt get 1.0 end] "" tmp] + 2}]
    $wt configure -state disabled -height $hgt

    MesCouleurs $w
    FenetreAuCentre $w

    tkwait window $w

    return
}


proc MesCouleurs {f} {
    global Defauts

    set abg [set Defauts(BackAppli)]
    [winfo toplevel $f] configure -background $abg
    if {[winfo class $f] eq "Frame"} {
	$f configure -bg $abg
    }

    return

    set ori [set Defauts(BackAppliOri)]

    set Ll [winfo children $f]
    foreach e $Ll {
	if {[winfo children $e] != {} } {MesCouleurs $e}
	set type [string toupper [winfo class $e]]
	switch $type {
	    "BUTTON" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "NOTEBOOK" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "TEXT" {continue}
	    "LABEL" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "ENTRY" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "CANVAS" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "COMBOBOX" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    "RADIOBUTTON" {
		$e configure -activebackground $abg
	    }
	    "CHECKBUTTON" {
		$e configure -activebackground $abg
	    }
	    "SCALE" {
		if {[$e cget -background] != $ori} {continue}
	    }
	    default continue
	}
	$e configure -background $abg
    }
    $f configure -background $abg

    return
}


proc ToggleAuLog {{Init ""}} {
    global Toggle
    
    # no file loaded yet
    if {! [info exists ::TexteDuLog]} {
	set ::TexteDuLog ""
    }

    if {$Init ne ""} {
	set Toggle(AuLog) $Init
	if {! $Init} {
	    if {[info commands ::AuLog] eq "" && [info commands ::AuLogText] ne ""} {
		rename ::AuLogText ::AuLog
	    }
	} else {
	    if {[info commands ::AuLog] eq "" && [info commands ::AuLogWindow] ne ""} {
		rename ::AuLogWindow ::AuLog
	    }
	}

	return
    }
    
    set Toggle(AuLog) [expr {! $Toggle(AuLog)}]
    if {$Toggle(AuLog)} {
	# show log console
	rename ::AuLog ::AuLogText
	rename ::AuLogWindow ::AuLog
	AuLog
    } else {
	# hide the window
	rename ::AuLog ::AuLogWindow
	rename ::AuLogText ::AuLog
	DetruitLogConsole destroy
    }

    return
}


proc TagLaFenetre {args} {
    global NomTextSeq LSOrdali

    if {$::TypeSeq eq "DNA"} {
	set Lgaa [list A G C T U]
	set Lfreg [list A G C T U]
    } else {
	# set Lgaa  [list STAC DE IJL<MV FYW P RK Q G HN]
	# take one representative per group
	set Lgaa  [list S D I F P R Q G H]
	set Lfreg [list "S|T|A|C" "D|E" "I|J|L|M|V" "F|Y|W" "P" "R|K" "Q" "G" "H|N"]
    }

    $NomTextSeq configure -state normal

    lassign [$::TScrollX get] fx1 fx2
    lassign [$::TScrollY get] fy1 fy2
    set w [LongueurDeLAlignement]
    set h [llength $LSOrdali]

    set xm [expr {int($fx1*$w)-1}]
    set xx [expr {int($fx2*$w)+1}]
    set ym [expr {int($fy1*$h)-1}]
    set yx [expr {int($fy2*$h)+1}]

    foreach a $Lgaa freg $Lfreg {
	$NomTextSeq tag remove Tag$a 1.0 end
	set lt {}
	for {set y $ym ; set yt [expr {$ym-1}]} {$y <= $yx} {incr y ; incr yt} {
	    # set yt [expr {$y-1}]
	    set t [string range [lindex $LSOrdali $yt] $xm $xx]
	    set lv [regexp -all -inline -indices -- $freg $t]
	    foreach e $lv {
		lassign $e d f 
		lappend lt $y.[expr {$d+$xm+1}] $y.[expr {$f+$xm+2}]
	    }
	}
	if {$lt != {}} {
	    $NomTextSeq tag add Tag$a {*}$lt
	}
    }
    $NomTextSeq configure -state disabled

    return
}


proc ToggleMapResidues {{force 0}} {
    global Toggle NomTextSeq Defauts
    
    if {[TypeAli] eq "pasdali"} {
	return
    }

    # force > 0 means variable 'MapRes' has been already toggled
    if {! $force} {
	# toggle variable 
	if {! $Toggle(MapRes)} {
	    set Toggle(MapRes) 1
	} else {
	    set Toggle(MapRes) 0
	}
    }

    if {$Toggle(MapRes)} {
	$NomTextSeq map on
    } else {
	$NomTextSeq map off
    }
    
    return
}


proc ToggleToolbar {} {
    global FrmToolBar

    if {! [winfo exists $FrmToolBar]} {
	AfficheBarreBoutons
    } else {
	set Le [winfo children $FrmToolBar]
	destroy {*}$Le

	grid forget $FrmToolBar
	destroy $FrmToolBar
	
	update idletasks
    }

    return
}


proc AfficheBarreBoutons {} {
    global OrdEtcDir FrmToolBar NomFenetreOrdali

    set FrmToolBar $NomFenetreOrdali.tbb
    frame $FrmToolBar
    grid $FrmToolBar -row 0 -column 0 -sticky ew -padx 5

    set frm $FrmToolBar

    set fbopen [file join $OrdEtcDir open.gif]
    image create photo bopen -file $fbopen
    button $frm.btopen -image bopen -command OuvrirFichierAlignementDansOrdali

    set fbclose [file join $OrdEtcDir file_close.gif]
    image create photo bclose -file $fbclose
    button $frm.btclose -image bclose -command [list FermeFichier save]

    set freload [file join $OrdEtcDir file_reload.gif]
    image create photo breload -file $freload
    button $frm.btreload -image breload -command ReLoadFichier

    set fsave [file join $OrdEtcDir "save.gif"]
    image create photo bsave -file $fsave
    button $frm.btsave -image bsave -command SauveLAlignement

    set fbcut [file join $OrdEtcDir "cut.gif"]
    image create photo bcut -file $fbcut
    button $frm.btcut -image bcut -command CutLesNoms

    set fbcopy [file join $OrdEtcDir "copy.gif"]
    image create photo bcopy -file $fbcopy
    button $frm.btcopy -image bcopy -command CopyLesNoms

    set fbpaste [file join $OrdEtcDir "paste.gif"]
    image create photo bpaste -file $fbpaste
    button $frm.btpaste -image bpaste -command PasteLesNoms

    set fbinsp [file join $OrdEtcDir "inssep.gif"]
    image create photo binsp -file $fbinsp
    button $frm.btinsp -image binsp -command "AddSpaceSeq"

    set fbrems [file join $OrdEtcDir "remsep.gif"]
    image create photo brems -file $fbrems
    button $frm.btrems -image brems -command "RemoveSpaceSeq"

    set fboverview [file join $OrdEtcDir overview.gif]
    image create photo boverview -file $fboverview
    button $frm.btoverview -image boverview -command AfficheOverview

    set fbannote [file join $OrdEtcDir "notepad.gif"]
    image create photo bannote -file $fbannote
    #button $frm.btannote -image bannote -command [list ChangeMode annotation]

    set fbfind [file join $OrdEtcDir "find.gif"]
    image create photo bfind -file $fbfind
    button $frm.btfind -image bfind -command [list ChangeMode search]

    set fbprint [file join $OrdEtcDir "print.gif"]
    image create photo bprint -file $fbprint
    button $frm.btprint -image bprint -command PrintSetup

    set fbtree [file join $OrdEtcDir "buildtree.gif"]
    image create photo btree -file $fbtree
    set ::WOrdali(BtnArbres) $frm.bttree
    button $frm.bttree -image btree -command [list ChangeMode arbres]

    set fbclus [file join $OrdEtcDir "cluster.png"]
    image create photo bclus -file $fbclus
    button $frm.btclus -image bclus -command [list ChangeMode cluster]

    set fbeditor [file join $OrdEtcDir "editor.gif"]
    image create photo beditor -file $fbeditor
    button $frm.bteditor -image beditor -command [list ChangeMode seqlab]

    set fbo3d [file join $OrdEtcDir "ord3d.gif"]
    image create photo bo3d -file $fbo3d
    button $frm.bto3d -image bo3d -command [list VisualiseStructure]

    set fbsup [file join $OrdEtcDir "superpose.gif"]
    image create photo bsup -file $fbsup
    button $frm.btsup -image bsup -command [list ChangeMode superpose]

    grid $frm.btopen     -row 0 -column  0 -sticky w
    grid $frm.btclose    -row 0 -column  1 -sticky w
    grid $frm.btreload   -row 0 -column  2 -sticky w
    grid $frm.btsave     -row 0 -column  3 -sticky w 
    grid $frm.btprint    -row 0 -column  4 -sticky w -padx {1 5}

    grid $frm.btcut      -row 0 -column  5 -sticky w -padx {5 1}
    grid $frm.btcopy     -row 0 -column  6 -sticky w
    grid $frm.btpaste    -row 0 -column  7 -sticky w -padx {1 5}

    grid $frm.btclus     -row 0 -column  8 -sticky w -padx {5 1}
    grid $frm.btinsp     -row 0 -column  9 -sticky w
    grid $frm.btrems     -row 0 -column 10 -sticky w
    grid $frm.bttree     -row 0 -column 11 -sticky w
    grid $frm.bteditor   -row 0 -column 12 -sticky w -padx {1 5}

    grid $frm.bto3d      -row 0 -column 13 -sticky w -padx {5 1}
    grid $frm.btsup      -row 0 -column 14 -sticky w -padx {1 5}

    grid $frm.btfind     -row 0 -column 15 -sticky w -padx {5 1}
    grid $frm.btoverview -row 0 -column 16 -sticky w
    #grid $frm.btannote   -row 0 -column 16 -sticky w

    #    grid rowconfig    $frm 0   -weight 0
    #    grid columnconfig $frm all -weight 1
    #    grid columnconfig $frm {16 17} -weight 1
    #    grid columnconfig $frm 16 -minsize $wdt

    setTooltip $frm.btopen     "Open"
    setTooltip $frm.btclose    "Close"
    setTooltip $frm.btreload   "Reload"
    setTooltip $frm.btsave     "Save"
    setTooltip $frm.btcut      "Cut"
    setTooltip $frm.btcopy     "Copy"
    setTooltip $frm.btpaste    "Paste"
    #setTooltip $frm.btundo     "Edit backward"
    #setTooltip $frm.btredo     "Edit forward"
    setTooltip $frm.btinsp     "Add separator"
    setTooltip $frm.btrems     "Remove separator"
    setTooltip $frm.btoverview "Instance overview"
    #setTooltip $frm.btannote   "Annotate alignment"
    setTooltip $frm.btfind     "Search"
    setTooltip $frm.btprint    "Print"
    setTooltip $frm.btclus     "Cluster mode"
    setTooltip $frm.bttree     "Tree"
    setTooltip $frm.bteditor   "Editor"
    setTooltip $frm.bto3d      "Display 3D"
    setTooltip $frm.btsup      "Superpose"

    #update idletasks

    #MesCouleurs $frm

    return
}


proc UpdateNoms {} {
    ChangeNomsAff $::Defauts(NomsAffiches)
    $::NomNomSeq configure -state normal
    $::NomNomSeq delete 1.0 end
    $::NomNomSeq insert end $::NomsAffiches
    $::NomNomSeq configure -state disabled
    
    return
}


proc ChangeNomsAff {{quoi ""}} {
    # names displayed for the sequences (Sequences -> Names as).
    # Without argument : the current choice (Defauts(NomsAffiches)),
    # kept when the snapshot changes.
    # When the information is missing for a sequence, its sequence
    # name is displayed.
    global NomsAffiches Defauts ListePDB TDesOrganismes

    if {$quoi eq ""} {
	set quoi $Defauts(NomsAffiches)
    }
    if {[InSeqlabMode]} {
	set LNoms $::LNSeqlab
    } else {
	set LNoms $::LNOrdali
    }

    switch $quoi {
	"access"   {set t TDesAccess}
	"bid"      {set t TDesBId}
	"organism" {set t TDesOrganismes}
	"gen.sp"   {set t TDesGS}
	default    {
	    set quoi "seqname"
	    set t TDesSeqnames
	}
    }
    global $t

    set Ltmp {}
    foreach n $LNoms {
	if {[string trim $n] eq "" || $n in $ListePDB} {
	    lappend Ltmp $n
	    continue
	}
	# copies of a sequence are suffixed by __<n>
	if {[set ix [string last "__" $n]] > 0} {
	    set pre [string range $n 0 $ix-1]
	    set suf [string range $n $ix end]
	} else {
	    set pre $n
	    set suf ""
	}
	set v ""
	if {[info exists ${t}($pre)]} {
	    set v [string trim [set ${t}($pre)]]
	}
	# Genus.species built from the organism if needed
	if {$quoi eq "gen.sp" && $v eq "" && [info exists TDesOrganismes($pre)]} {
	    set GenreEspece [string map {"." " "} $TDesOrganismes($pre)]
	    lassign [regexp -all -inline {\S+} $GenreEspece] Genre Espece
	    if {$Genre ne "" && ! [string equal -nocase $Genre "unknown"]} {
		set v "[string range $Genre 0 3].[string range $Espece 0 3]"
	    }
	}
	if {$quoi eq "organism"} {
	    regsub -all { +} $v " " v
	}
	if {$v eq "" || [string equal -nocase $v "unknown"]} {
	    set v $pre
	}
	lappend Ltmp "$v$suf"
    }

    # Give same length just before insertion inside the widget
    set Ltmp [DonneMemeLongueurListe $Ltmp]
    set NomsAffiches $Ltmp
    set Defauts(NomsAffiches) $quoi
    
    return
}


proc ChangeEtatMenus {{etat "disabled"} {type ""}} {
    return
    global MenuFile
    global MenuEdit
    global MenuGroups
    global MenuDisplay
    global MenuStructure
    global MenuView

    $MenuFile entryconfigure  1 -state $etat
    $MenuFile entryconfigure  2 -state $etat
    $MenuFile entryconfigure  3 -state $etat
    $MenuFile entryconfigure  7 -state $etat
    $MenuFile entryconfigure  8 -state $etat
    $MenuFile entryconfigure 11 -state $etat

    $MenuEdit entryconfigure  0 -state $etat
    $MenuEdit entryconfigure  1 -state $etat
    $MenuEdit entryconfigure  2 -state $etat
    $MenuEdit entryconfigure  4 -state $etat
    $MenuEdit entryconfigure  6 -state $etat
    $MenuEdit entryconfigure  8 -state $etat
    $MenuEdit entryconfigure 10 -state $etat

    $MenuGroups entryconfigure  0 -state $etat
    $MenuGroups entryconfigure  1 -state $etat
    $MenuGroups entryconfigure  3 -state $etat
    $MenuGroups entryconfigure  4 -state $etat
    $MenuGroups entryconfigure  6 -state $etat
    $MenuGroups entryconfigure  8 -state $etat
    $MenuGroups entryconfigure 12 -state $etat
    $MenuGroups entryconfigure 14 -state $etat
    $MenuGroups entryconfigure 16 -state $etat

    $MenuDisplay entryconfigure 0 -state $etat
    $MenuDisplay entryconfigure 1 -state $etat
    $MenuDisplay entryconfigure 2 -state $etat

    $MenuStructure entryconfigure 0 -state $etat
    $MenuStructure entryconfigure 2 -state $etat
    $MenuStructure entryconfigure 4 -state $etat
    $MenuStructure entryconfigure 6 -state $etat
    $MenuStructure entryconfigure 7 -state $etat

    $MenuView entryconfigure 0 -state $etat
    $MenuView entryconfigure 1 -state $etat
    $MenuView entryconfigure 2 -state $etat
    $MenuView entryconfigure 4 -state $etat
    $MenuView entryconfigure 5 -state $etat

    if {$type == "xml"} {
	$MenuGroups entryconfigure 10 -state normal
    } else {
	$MenuGroups entryconfigure 10 -state disabled
    }

    return
}



proc ResizeApplication {} {
    return
    global OldGeom
    global EtatBtnFeat

    if {[QuelbMode] ne "seqlab"} {return}
    if {[QuelMode] != "feature"} {return}

    update
    set sg [wm geometry .]
    lassign [split $sg "+"] xy l h 
    lassign [split ${xy} "x"] x y 
    set Geom [list $x $y $l $h]
    if {! [info exists OldGeom]} {
	set OldGeom $Geom
	return
    }

    set AFaire 0
    foreach o $OldGeom v $Geom {
	if {[expr {abs($o-$v)}] > 100} {set AFaire 1 ; break}
    }
    if {$AFaire} {
	DetruitBoutonsOrdali
	AfficheBoutonsFeatures
	foreach b [array names EtatBtnFeat] {
	    if {[set EtatBtnFeat($b)]} {EnfonceBtnFeature $b}
	}
	set OldGeom $Geom
    }

    return
}


proc AfficheBarreMenus {} {
    global Defauts NomFenetreOrdali Toggle
    global MenuFile MenuEdit MenuView MenuStructure Toggle
    
    set bgm [set Defauts(BackAppli)]
    
    set w [winfo toplevel $NomFenetreOrdali]
    if {$w eq "."} {
	set mb ".menuBar"
    } else {
	set mb $w.menuBar
    }
    menu $mb -tearoff 0
    
    set mfi $mb.file
    set med $mb.edit
    set mvw $mb.view
    set mse $mb.sequence
    set mal $mb.alignement
    set mst $mb.structure
    set mhe $mb.help
    
    set MenuFile       $mfi
    set MenuEdit       $med
    set MenuView       $mvw
    set MenuSequence   $mse
    set MenuAlignement $mal
    set MenuStructure  $mst
    set MenuTools      $mst
    
    # create sub-menus
    menu $mfi -activebackground "#0083ffff0000" -foreground black
    menu $med -activebackground "#0083ffff0000" -foreground black
    menu $mvw -activebackground "#0083ffff0000" -foreground black
    menu $mse -activebackground "#0083ffff0000" -foreground black
    menu $mal -activebackground "#0083ffff0000" -foreground black
    menu $mst -activebackground "#0083ffff0000" -foreground black
    menu $mhe -activebackground "#0083ffff0000" -foreground black

    # Create the munu bar itself
    $mb add cascade -label File -menu $mfi -underline 0
    $mb add cascade -label Edit -menu $med -underline 0
    $mb add cascade -label View -menu $mvw -underline 0
    $mb add cascade -label Sequences -menu $mse -underline 0
    $mb add cascade -label Alignment -menu $mal -underline 0
    $mb add cascade -label Structures -menu $mst -underline 0
    $mb add cascade -label Help -menu $mhe -underline 0

    # 
    # Menu file
    set mfiti "$mfi.typefilein"
    menu $mfiti -tearoff 0 -background $bgm
    $mfiti add command -label "a MSF file" -command "OuvrirFichierAlignementDansOrdali MSF"
    $mfiti add command -label "a Macsim/XML file" -command "OuvrirFichierAlignementDansOrdali XML"
    $mfiti add command -label "a TFA file" -command "OuvrirFichierAlignementDansOrdali TFA"
    $mfiti add command -label "a Clustal ALN file" -command "OuvrirFichierAlignementDansOrdali ALN"
    #$mfiti add command -label "a RSF file" -command "OuvrirFichierAlignementDansOrdali RSF"
    $mfiti add command -label "an Ordalie ORD file" -command "OuvrirFichierAlignementDansOrdali ORD"
    $mfi add cascade -label "Open ..." -menu $mfiti -underline 0 -background $bgm
    $mfi add command -label "Save" -command "SauveLAlignement"
    # cascade "save as ..."
    set mfito "$mfi.typefileout"
    menu $mfito -tearoff 0
    $mfito add command -label "TFA file" -command "SauveLAlignement TFA"
    $mfito add command -label "MSF file" -command "SauveLAlignement MSF"
    $mfito add command -label "Macsim/XML file" -command "SauveLAlignement XML"
    $mfito add command -label "ALN (ClustalW) file" -command "SauveLAlignement ALN"
    $mfito add command -label "ORD file" -command "SauveLAlignement ORD"
    $mfi add cascade -label "Save as ..." -menu $mfito -underline 0
    # save window as ..
    set mfitw "$mfi.windowfileout"
    menu $mfitw -tearoff 0 -background $bgm
    $mfitw add command -label "a TFA file" -command "CreeLAlignementDeLaFenetre TFA"
    $mfitw add command -label "a MSF file" -command "CreeLAlignementDeLaFenetre MSF"
    $mfitw add command -label "a ALN Clustal file" -command "CreeLAlignementDeLaFenetre ALN"
    $mfi add cascade -label "Save window as" -menu $mfitw -underline 0
    $mfi add command -label "Close" -command [list FermeFichier save]
    $mfi add separator
    $mfi add command -label "Print" -command "PrintSetup"
    $mfi add separator
    $mfi add command -label "Quit Ordalie" -command "AdieuOrdali"

    # Menu edition
    $med add command -label "Cut"   -accelerator "Ctrl-x" -command "CutLesNoms"
    $med add command -label "Copy"  -accelerator "Ctrl-c" -command "CopyLesNoms"
    $med add command -label "Paste" -accelerator "Ctrl-v" -command "PasteLesNoms"
    $med add separator
    $med add command -label "Preferences" -command "AffichePreferences2"

    # Menu View
    $mvw add command -label "Bigger font" -accelerator "Ctrl-plus" -command "TailleFonte +2"
    $mvw add command -label "Smaller font" -accelerator "Ctrl-minus" -command "TailleFonte -2"
    $mvw add separator
    # view log cascade
    set mvwvl $mvw.viewlog
    menu $mvwvl -tearoff 0 -background $bgm
    $mvwvl add command -label "in Console" -command "ToggleAuLog"
    $mvwvl add command -label "in browser" -command "LogInBrowser"
    $mvw add cascade -label "View Log " -menu $mvwvl

    # output log cascade
    set mvwol $mvw.outlog
    menu $mvwol -tearoff 0 -background $bgm
    $mvwol add command -label "as HTML" -command {AuLog LOutput HTML}
    $mvwol add command -label "as Text" -command {AuLog LOutput Text}
    $mvw add cascade -label "Save Log file " -menu $mvwol
    $mvw add separator
    $mvw add command -label "Toggle Full-screen mode" -command "ToggleFullScreen"
    $mvw add separator

    set Toggle(AllSeqs) [set Defauts(ToggleAllSeqs)]
    set Toggle(ToolBar) [set Defauts(ToggleToolBar)]
    set Toggle(Feature) [set Defauts(ToggleFeature)]
    set Toggle(Scores)  [set Defauts(ToggleScores)]
    set Toggle(AuLog)   [set Defauts(ToggleAuLog)]
    set Toggle(MapRes)  [set Defauts(ToggleMapRes)]

$mvw add checkbutton -label "Show/Hide Icon Bar" -variable Toggle(ToolBar) -command ToggleToolbar
    $mvw add checkbutton -label "Show/Hide Scores" -variable Toggle(Scores) -command {ToggleScores FromMenu}
    $mvw add checkbutton -label "Show/Hide Features" -variable Toggle(Feature) -command ToggleFeature
    $mvw add separator
    $mvw add checkbutton -label "Show/Hide Phylum" -variable Defauts(AffPhy) -command "ColorieNomsSelonPhylum"
    $mvw add checkbutton -label "Show/Hide group colors" -variable Defauts(AffGrp) -command "ColorieNomsSelonGroupes"
    $mvw add checkbutton -label "Show/Hide Sec. Str." -variable Defauts(AffSS) -command [list ToggleSecStr menu]

    #
    # Menu sequence
    #
    set msena "$mse.nomsaff"
    $mse add cascade -label "Names as " -menu $msena -underline 0 -background $bgm
    menu $msena -tearoff 0 -background [set Defauts(BackAppli)]
    $msena add command -label "Sequence Name" -command "AutresNomsAff seqname"
    $msena add command -label "Accession Number" -command "AutresNomsAff access"
    $msena add command -label "Database ID" -command "AutresNomsAff bid"
    $msena add command -label "Full Organism Name" -command "AutresNomsAff organism"
    $msena add command -label "Genus.species abbreviation" -command "AutresNomsAff gen.sp"
    $mse add separator
    $mse add command -label "Identity tool" -command "ChangeMode donnepci" -accelerator "Shift I"
    $mse add command -label "Search motif"  -command "ChangeMode search"
    $mse add separator
    $mse add command -label "Retrieve Sequences information" -command "LaunchCheckInfosSeqs"
    $mse add command -label "Edit Seq. information" -command "SequencesInformation"
    #$mse add command -label "Edit Seq. information" -command "EditInfoSeq"
    $mse add separator
    $mse add command -label "Add feature from file..." -command "ReadRawFeatureFile"
    $mse add command -label "Export Feature to file" -command "WindowWriteFeatureFile"
    $mse add command -label "Features Editor" -command "ChangeMode feateditor"
    $mse add command -label "Features Summary" -command "FeatureSummary"
    $mse add separator
    set mseas "$mse.addseq"
    $mse add cascade -label "Add sequences in instance " -menu $mseas -underline 0 -background $bgm
    menu $mseas -tearoff 0 -background [set Defauts(BackAppli)]
    $mseas add command -label "from file" -command "AjouteSequenceOrPDB seqfile"
    $mseas add command -label "from database" -command "AjouteSequenceOrPDB database"

    set mseap "$mse.addpdb"
    $mse add cascade -label "Add structure in instance " -menu $mseap -underline 0 -background $bgm
    menu $mseap -tearoff 0 -background [set Defauts(BackAppli)]
    $mseap add command -label "from file" -command "AjouteSequenceOrPDB pdbfile"
    $mseap add command -label "from ID" -command "AjouteSequenceOrPDB pdbid"

    #
    # Menu alignement
    #
    #$mal add command -label "Create Macsims ..." -command CreateAndDisplayMacsims
    #$mal add command -label "Names Of Clusters" -command "NamesOfClusters"
    #$mal add separator
    $mal add command -label "Editor" -command "ChangeMode seqlab" -accelerator "Shift E"
    $mal add command -label "Re-align sequences" -command ReAlignSeqs 
    $mal add separator
    $mal add command -label "Clustering" -command "ChangeMode cluster" -accelerator "Shift G"
    $mal add command -label "Add separator" -command "AddSpaceSeq"
    $mal add command -label "Remove separator" -command "RemoveSpaceSeq"
    $mal add command -label "Remove All separators" -command "RemoveAllSeparators"
    $mal add separator
    $mal add command -label "Overview" -command "AfficheOverview"
    $mal add command -label "Conservation" -command "ChangeMode conservation" -accelerator "Shift C"
    $mal add command -label "Tree building" -command "ChangeMode arbres" -accelerator "Shift T"
    $mal add command -label "Annotate instance" -command "ChangeMode annotation"
    $mal add command -label "Barcode" -command BarcodeAlignment
    $mal add separator
    $mal add command -label "Toggle Physicochemical Coloring" -command "ToggleMapResidues"

    #
    # Menu structure
    #
    $mst add command -label "Display Structures" -command "VisualiseStructure"
    $mst add command -label "Superpose Structures" -command [list ChangeMode superpose]
    $mst add separator
    $mst add separator
    $mst add command -label "Color Sec. Str by identity" -command "ColorieSSSelonConservation"
    $mst add separator
    $mst add command -label "Save PDB" -command "SauveLesPDB"

    # Menu help
    $mhe add command -label "About Ordalie" -command "InfosSurOrdali"
    $mhe add separator
    #$mhe add command -label "Help on Ordali" -command "LanceDoc"
    $mhe add command -label "local Ordalie documentation" -command "LanceDoc local"
    $mhe add command -label "On-line Ordalie documentation" -command "LanceDoc internet"
    #$mhe add command -label "Ordalie PDF documentation" -command "LanceDoc"

    [winfo toplevel $NomFenetreOrdali] configure -menu $mb
    update idletasks
    
    return
}


proc MiseAJourMac {{args ""}} {
    global WOrdali Defauts LongueurTotale Toggle LTPCI SDG
    
    if {[TypeAli] eq "pasdali"} {
	return
    }

    set Reset 0
    # remet alignement courant
    if {$args eq "reset"} {
	set Reset 1
	VueEditee 0
	set args ""
    }
    
    # snapshot to display : the one chosen in the combobox,
    # or the current one (reset, startup).
    # Read it BEFORE saving : saving resets the combobox to the
    # current snapshot.
    set Mac [MacCourant name]
    if {$args ne ""} {
	set Mac [lindex $args 1]
    } elseif {! $Reset && [info exists WOrdali(combomac)] && [winfo exists $WOrdali(combomac)]} {
	set sel [$WOrdali(combomac) get]
	if {$sel ne ""} {
	    set Mac $sel
	}
    }

    if {[VueEditee]} {
	set chx [tk_dialog .chx "Warning" "Warning !\nThis alignment has not been saved !" "" 0 "Overwrite it" "Create a new one" "Cancel"]
	if {$chx == 2 || $chx < 0} {
	    # Cancel : stay on the current snapshot
	    MetAJourWMacs
	    return
	}
	SauveLeMac $chx
	if {[VueEditee]} {
	    # not saved (reference alignment, no title ...) :
	    # stay on the current snapshot, changes are kept
	    MetAJourWMacs
	    return
	}
    }

    set iMac [IndexDeMac $Mac]
    if {[llength $iMac] != 1} {
	FaireLire "Error !\nInstance \"$Mac\" not found or not unique !"
	MetAJourWMacs
	return
    }
    # instance displayed until now : back to it if this one
    # can not be loaded
    set AncNm [expr {[info exists Defauts(NmMacCourant)] ? $Defauts(NmMacCourant) : ""}]
    set AncIx [expr {[info exists Defauts(IxMacCourant)] ? $Defauts(IxMacCourant) : ""}]
    $WOrdali(combomac) configure -values [LesMacs]
    LesDefauts NmMacCourant $Mac
    LesDefauts IxMacCourant $iMac
    if {$iMac == 1} {
	FaireLire "Please do not forget this is the reference alignment. As such, you would not be able to modify it !"
    }
    set NoFeat 0
    if {! $Toggle(Feature)} {
	set Toggle(Feature) 1
	ToggleFeature
	set NoFeat 1
    }
    
    if {[catch {CreeVue} Msg]} {
	set Info $::errorInfo
	if {$AncIx eq $iMac || $AncIx eq ""} {
	    # nothing to go back to
	    return -code error -errorinfo $Info $Msg
	}
	# an error in CreeVue left the display half updated
	# (sequences of one instance, features of another) :
	# the previous instance is displayed again
	puts "\nMiseAJourMac : instance \"$Mac\" not loaded\n$Info"
	LesDefauts NmMacCourant $AncNm
	LesDefauts IxMacCourant $AncIx
	CreeVue
	FaireLire "Error !\nInstance \"$Mac\" could not be loaded :\n$Msg\n\nBack to instance \"$AncNm\"."
    }
    
    # the selected names are row numbers of the previous instance,
    # and the selected columns (Identity, Tree, Superposition tools)
    # columns of its alignment
    ClearSelectionNoms
    ClearSelectionSequences
    set ::ZonePCI {}
    set ::ZoneTree {}
    set ::ZoneSuperposition {}

    set LongueurTotale [LongueurMac]
    #InfosDesPDB
    
    set LTPCI [CalculeLesPCIDuMac]
    if {$Defauts(FirstPass)} {
	LogSeqInfoGlobales
	LogLesCompositions
	LogPCI all

	LesDefauts FirstPass 0
    }
    
    AuLog @begin blob
    AuLog @title Alignment : [MacCourant name]
    AuLog @end
    LogInfosClusters
    LogPCI
    
    ChangeNomsAff
    AdjustNamesWidgetWidth
    AfficheNomsEtSeqs
    OrdaliDefaultMapping
    OrdaliDefaultTags
    LesDefauts AffSS 0
    ToggleSecStr
    RepeintNomsEtSeqs

    InitWRegle
    AfficheRegle

    update idletasks

    set bt $WOrdali(BoutZones)
    if {[EtatBouton $bt]} {
	AfficheZonesClustering
    }

    ChangeMode

    if {$NoFeat} {
	set Toggle(Feature) 0
	ToggleFeature
    }

    # combobox shows the current snapshot
    MetAJourWMacs

    # annotations of the new snapshot
    RafraichitAnnotations
    
    return
}


proc MetAJourWMacs {} {
    global WOrdali

    if {[LesMacs] eq ""} {
	return
    }

    set i [lsearch [LesMacs index] [MacCourant]]

    if {[ModeI]} {
	$WOrdali(combomac) configure -values [LesMacs]
	if {$i != -1} {
	    $WOrdali(combomac) current $i
	}
    }

    return
}


proc QuitteInfosMac {w} {
    destroy $w
    return
}


proc FinDemandeTitre {quoi w} {
    global TiDe

    if {$quoi eq "save"} {
	set titre [$TiDe(Wtitre) get 1.0 end]
	if {[string trim $titre] eq ""} {return}
    } else {
	set titre ""
    }
    
    set TiDe(titre)  $titre
    set TiDe(desc)   [$TiDe(Wdesc) get 1.0 end]
    set TiDe(ctitre) [$TiDe(Wctitre) get 1.0 end]
    set TiDe(cdesc)  [$TiDe(Wcdesc) get 1.0 end]

    foreach v [array names TiDe] {
	if {[string index [set TiDe($v)] end] eq "\n"} {set TiDe($v) [string range [set TiDe($v)] 0 end-1]}
    }

    destroy $w
    update idletasks

    return
} 


proc DemandeTitreEtDescDuMac {} {
    global TiDe

    set w .tide
    if {[winfo exists $w]} {
	raise $w
	
	return
    }
    
    toplevel $w
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm resizable $w 0 0
    wm title $w "Instance Title"
    wm attributes $w -topmost
    
    frame $w.f
    grid $w.f -row 0 -column 0 -sticky news -padx 5 -pady 5
    
    label $w.f.lb \
	-text "Instance Information" \
	-font "Helvetica 14 bold" \
	-justify left -anchor w
    label $w.f.tl \
	-font "Helvetica 12" \
	-text "Please supply an instance title (COMPULSORY)\nand an instance description.\nYou can also describe the current clustering" \
	-justify left -anchor w
    
    frame $w.f.ftd
    set wt "$w.f.ftd"
    label $wt.lbt \
	-font "Helvetica 12 bold" \
	-text "Instance Title :" \
	-fg blue \
	-justify left -anchor w
    set TiDe(Wtitre) $wt.titre
    text $wt.titre \
	-font "Helvetica 12" \
	-width 20 -height 1 \
	-background white
    label $wt.desc \
	-font "Helvetica 12 bold" \
	-text "Alignment Description :" \
	-fg blue \
	-justify left -anchor w
    set TiDe(Wdesc) $wt.tdesc
    text $wt.tdesc \
	-font "Helvetica 12" \
	-background white \
	-width 20 -height 3 \
	-yscrollcommand "$wt.scr set" \
	-wrap word
    scrollbar $wt.scr \
	-width 8 \
	-command "$wt.tdesc yview "
    grid $wt.lbt    -row 0 -column 0 -columnspan 2 -sticky ew
    grid $wt.titre  -row 1 -column 0 -columnspan 2 -sticky ew -pady {1 3}
    grid $wt.desc   -row 2 -column 0 -columnspan 2 -sticky ew
    grid $wt.tdesc  -row 3 -column 0 -sticky ew
    grid $wt.scr    -row 3 -column 1 -sticky ns
    grid columnconfig $wt 0 -weight 1
    
    frame $w.f.fcc
    set wc "$w.f.fcc"
    label $wc.lbt \
	-font "Helvetica 12 bold" \
	-text "Clustering Title :" \
	-fg blue \
	-justify left -anchor w
    set TiDe(Wctitre) $wc.titre
    text $wc.titre \
	-width 20 -height 1 \
	-background white
    label $wc.desc \
	-font "Helvetica 12 bold" \
	-text "Clustering Description :" \
	-fg blue \
	-justify left -anchor w
    set TiDe(Wcdesc) $wc.tdesc
    text $wc.tdesc \
	-width 20 -height 3 \
	-font "Helvetica 12" \
	-bg white \
	-yscrollcommand "$wc.scr set" \
	-state normal
    scrollbar $wc.scr \
	-width 8 \
	-command "$wc.tdesc yview "
    grid $wc.lbt    -row 0 -column 0 -columnspan 2 -sticky ew
    grid $wc.titre  -row 1 -column 0 -columnspan 2 -sticky ew -pady {1 3}
    grid $wc.desc   -row 2 -column 0 -columnspan 2 -sticky ew
    grid $wc.tdesc  -row 3 -column 0 -sticky ew
    grid $wc.scr    -row 3 -column 1 -sticky ns
    grid columnconfig $wt 0 -weight 1
    
    frame $w.f.fb
    set wb "$w.f.fb"
    button $wb.bsav \
	-text " OK " \
	-background green1 \
	-command [list FinDemandeTitre save $w]
    button $wb.bdis \
	-text "Cancel" \
	-background red \
	-command [list FinDemandeTitre dis $w]
    grid $wb.bdis -row 0 -column 0 -sticky w -padx 20
    grid $wb.bsav -row 0 -column 1 -sticky e -padx 20
    grid columnconfig $wb all -weight 1
    
    grid $w.f.lb -row 0 -column 0 -columnspan 2 -sticky ew
    grid $w.f.tl -row 1 -column 0 -columnspan 2 -sticky ew -pady {1 12}
    grid $wt     -row 2 -column 0 -sticky ew -padx {1 10}
    grid $wc     -row 2 -column 1 -sticky ew -padx {10 1}
    grid $wb     -row 4 -column 0 -columnspan 2 -sticky ew -pady 10
    grid rowconfig $w.f all -weight 0
    grid columnconfig $w.f all -weight 1
    
    FenetreAuCentre $w
    
    tkwait window $w

    set atitre [set TiDe(titre)]
    set adesc  [set TiDe(desc)]
    set ctitre [set TiDe(ctitre)]
    set cdesc  [set TiDe(cdesc)]
    unset TiDe
    
    return [list $atitre $adesc $ctitre $cdesc]
}


proc InfosDuMac {{what ""}} {
    set w .macinfo
    if {$what eq "destroy"} {
	destroy $w
	return
    }

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    toplevel $w
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm resizable $w 0 0
    wm title $w "Instance Info"
    wm attributes $w -topmost 1

    label $w.title \
	-text "Instance Information" \
	-font TitleFont \
	-relief flat \
    -justify left -anchor w
    grid $w.title -row 0 -column 0 -sticky w -padx 5 -pady 20

    frame $w.f
    grid $w.f -row 1 -column 0 -sticky news -padx 5 -pady 5

    set Linfos {}
    lappend Linfos "Title"
    lappend Linfos $::Defauts(NmMacCourant)
    lappend Linfos "Description" "[DescriptionDuMac]"
    lappend Linfos "Number of Sequences"
    set nbSeqs [llength $::SDG(GroupeToutLeMonde)]
    lappend Linfos $nbSeqs
    lappend Linfos "Length" "[LongueurDeLAlignement]"
    lappend Linfos "Clustering" "[ClusteringDuMac]"
    lappend Linfos "Method" "[ClusteringDuMac method]"
    lappend Linfos "Zone" "[ClusteringDuMac zone]"
    set nbGrps [llength [lsearch -all -regexp $::LNDG {^Group[0-9]+$}]]
    if {$nbGrps == 0} {
	set nbGrps 1
    }
    lappend Linfos "Number of clusters" "$nbGrps"

    set i 0
    foreach {k v} $Linfos {
	label $w.f.l$i \
	    -text "$k" \
	    -relief flat \
	-justify left -anchor w
	label $w.f.s$i \
	    -text ":" \
	    -relief flat 
	label $w.f.v$i \
	    -text "$v" \
	    -relief flat \
	-justify left -anchor w
	grid $w.f.l$i -row $i -column 0 -sticky w
	grid $w.f.s$i -row $i -column 1 -sticky w
	grid $w.f.v$i -row $i -column 2 -sticky w
	incr i
    }

    frame $w.but
    grid $w.but -row 2 -column 0 -sticky ew -padx 5 -pady 20

    button $w.but.close \
	-text "Close" \
	-bg green1 \
	-command [list InfosDuMac destroy]
    grid $w.but.close -row 0 -column 0

    FenetreAuCentre $w

    return
}


proc AfficheBarreMac {} {
    global NomFenetreOrdali FrmVues WOrdali Defauts

    set wv $NomFenetreOrdali.fmac
    set FrmVues $wv
    frame $FrmVues
    grid $FrmVues -row 1 -column 0 -sticky ew -padx 5 -pady {1 3}
    
    frame $wv.fcx
    grid $wv.fcx -row 0 -column 0 -sticky w
    label $wv.fcx.lmac \
	-text "Instance " \
	-fg $Defauts(ForeAppli) \
    -justify left \
	-anchor w
    set WOrdali(combomac) $wv.fcx.cmac
    # the combobox has its own variable : Defauts(NmMacCourant)
    # must stay the CURRENT snapshot until MiseAJourMac switches
    ttk::combobox $wv.fcx.cmac \
	-background white \
	-state readonly \
	-width 40 \
	-textvariable ::MacChoisi
    bind $WOrdali(combomac) <<ComboboxSelected>> [list MiseAJourMac]
    set WOrdali(BoutInfos) $wv.fcx.binf
    button $wv.fcx.binf \
	-text "Info" \
	-bg white \
	-command [list InfosDuMac]

    grid $wv.fcx.lmac -row 0 -column 0 -sticky w -padx {1 2}
    grid $wv.fcx.cmac -row 0 -column 1 -sticky w -padx 2
    grid $wv.fcx.binf -row 0 -column 2 -sticky w -padx {2 5}
    
    frame $wv.fbt
    grid $wv.fbt -row 0 -column 1 -sticky w -padx 20
    set WOrdali(BoutAnno) $wv.fbt.bann
    button $wv.fbt.bann \
	-text "Annotations" \
	-bg cyan \
	-command AfficheSnapshotAnnotations
    set WOrdali(BoutZones) $wv.fbt.bzon
    button $wv.fbt.bzon \
	-text "View Zone" \
	-bg cyan \
	-command [list AfficheZonesClustering]
    button $wv.fbt.bres \
	-text "Reset" \
	-bg cyan \
	-command [list MiseAJourMac reset]
    button $wv.fbt.bsav \
	-text "Overwrite" \
	-bg green1 \
	-command [list SauveLeMac 0]
    button $wv.fbt.bkip \
	-text "New Instance" \
	-bg green1 \
	-command [list SauveLeMac 1]
    button $wv.fbt.bdel \
	-text "Delete" \
	-bg red \
	-command [list DetruitInstance]
    
    grid $wv.fbt.bann -row 0 -column 0 -sticky w -padx {10 1}
    grid $wv.fbt.bzon -row 0 -column 1 -sticky w -padx 1
    grid $wv.fbt.bres -row 0 -column 2 -sticky w -padx 10 
    grid $wv.fbt.bsav -row 0 -column 3 -sticky w -padx 1
    grid $wv.fbt.bkip -row 0 -column 4 -sticky w -padx 1
    grid $wv.fbt.bdel -row 0 -column 5 -sticky w -padx {10 1}

    grid rowconfigure $wv 0   -weight 0
    grid columnconfig $wv all -weight 0

    return
}


proc ChercheNom {} {
    global NomNomSeq NomTextSeq SearchNom SNOld IdPosSearch

    #puts "SearchNom $SearchNom"
    set SearchNom [string trim $SearchNom]
    if {$SearchNom eq ""} {return}

    set Ln [$NomNomSeq output all]
    set Li [lsearch -all -nocase -regexp $Ln $SearchNom]
    if {$Li eq ""} {return}

    if {! [info exists SNOld] || $SNOld ne $SearchNom} {
	set IdPosSearch 0
	set SNOld $SearchNom
    } else {
	incr IdPosSearch
	if {$IdPosSearch >= [llength $Li]} {
	    set IdPosSearch 0
	}	
    }

    set yc [expr {[lindex $Li $IdPosSearch]+1}]
    set pos [$NomNomSeq index @0,0]
    $NomNomSeq  see $pos
    $NomTextSeq see $pos
    lassign [split $pos .] yv xv 
    set D [expr {$yc-$yv}]

    $NomNomSeq  yview scroll $D units
    $NomTextSeq yview scroll $D units

    return
}


proc AdjustNamesWidgetWidth {} {
    global Defauts NomsAffiches NomNomSeq

    if {[info exists NomsAffiches]} {
	set WdtNom [expr {[PlusLongEltDe [lmap n $NomsAffiches {string trim $n}]]+1}]
    } else {
	set WdtNom [set Defauts(LongNom)]
    }
    
    # names pane : widened for long names (organisms ...), up to
    # twice its default width (full information with <B3>)
    set WdtWid [expr {min(max($WdtNom, $Defauts(LongNom)), 2*$Defauts(LongNom))}]
    if {[$NomNomSeq cget -width] != $WdtWid} {
	$NomNomSeq configure -width $WdtWid
    }
    
    # Adjust the search entry width
    [winfo parent $NomNomSeq].srcnom configure -width [expr {$WdtWid - 2}]

    return
}


proc AfficheFrameSequences {} {
    global LNOrdali Defauts TScrollX TScrollY NomFenetreOrdali NomsAffiches
    global NomNomSeq NomTextSeq FrmSequence SearchNom
    global WTexteRegle

    set w $NomFenetreOrdali
    set FrmSequence "$w.lessequences"
    frame $FrmSequence
    grid $FrmSequence -row 2 -column 0 -sticky news -padx 5
    
    #
    # widgets to display names of sequences, sequences and ruler
    #
    set TScrollX   $FrmSequence.scrollxseq
    set TScrollY   $FrmSequence.scrolly
    set NomNomSeq  $FrmSequence.biotextnom
    set NomTextSeq $FrmSequence.biotextsequence
    set WTexteRegle $FrmSequence.regle

    # names
    biotext $FrmSequence.biotextnom \
	-width [set Defauts(LongNom)] \
	-height $Defauts(seqHeight) \
	-foreground $Defauts(Foreground) \
	-background $Defauts(Background) \
	-relief flat \
	-borderwidth 1 \
	-highlightthickness 0 \
	-yscrollcommand [list $TScrollY set] \
	-class Biotext \
	-setgrid 0
    
    # Sequences :
    biotext $FrmSequence.biotextsequence \
	-width $Defauts(seqWidth) \
	-height $Defauts(seqHeight) \
	-foreground $Defauts(Foreground) \
	-background $Defauts(Background) \
	-relief flat \
	-borderwidth 1 \
	-highlightthickness 0 \
	-yscrollcommand [list $TScrollY set] \
	-xscrollcommand [list $TScrollX set] \
	-class Biotext \
	-setgrid 0
    
    # position ruler
    biotext $w.lessequences.regle \
	-width $Defauts(seqWidth) \
	-height 2 \
	-foreground $Defauts(Foreground) \
	-background $Defauts(Background) \
	-borderwidth 1 \
	-highlightthickness 0 \
	-relief flat \
	-xscrollcommand [list .ordali.lessequences.scrollxseq set] \
	-class Biotext \
	-setgrid 0
    
    $NomNomSeq font family $Defauts(SeqFontFaml) size $Defauts(SeqFontSize) weight $Defauts(SeqFontWght)
    $NomTextSeq font family $Defauts(SeqFontFaml) size $Defauts(SeqFontSize) weight $Defauts(SeqFontWght)
    $WTexteRegle font family $Defauts(SeqFontFaml) size $Defauts(SeqFontSize) weight $Defauts(SeqFontWght)

    scrollbar $w.lessequences.scrollxseq \
	-orient horiz \
	-command [list CoupleX] \
	-width 8 \
	-borderwidth 2
    scrollbar $w.lessequences.scrolly \
	-width 8 \
	-command "CoupleY" \
	-borderwidth 2
    
    # Frame to display cursor position in sequence 
    frame $w.lessequences.fpos \
	-width 17 \
	-relief sunken \
	-borderwidth 1
    label $w.lessequences.fpos.tposg \
	-text "gen " \
-fg $Defauts(ForeAppli) \
    -relief flat \
	-width 4 \
	-anchor w -justify left
    label $w.lessequences.fpos.vposg \
	-textvariable XGen \
	-relief flat \
	-width 5 \
	-fg black \
    -anchor w -justify right
    label $w.lessequences.fpos.tposs \
	-text " seq " \
	-fg $Defauts(ForeAppli) \
    -relief flat \
	-width 5 \
	-anchor w -justify left
    label $w.lessequences.fpos.vposs \
	-textvariable XSeq \
	-relief flat \
	-width 5 \
	-fg black \
    -anchor w -justify right
    grid $w.lessequences.fpos.tposg -row 0 -column 0 -sticky w
    grid $w.lessequences.fpos.vposg -row 0 -column 1 -sticky w
    grid $w.lessequences.fpos.tposs -row 0 -column 2 -sticky w
    grid $w.lessequences.fpos.vposs -row 0 -column 3 -sticky w
    
    grid columnconfig $w.lessequences.fpos all -weight 0
    grid rowconfig    $w.lessequences.fpos 0 -weight 0
    
    # entry to search for a sequence name
    set wdtEnt [expr {[set Defauts(LongNom)] - 2}]
    entry $w.lessequences.srcnom \
	-width $wdtEnt \
	-textvariable SearchNom \
	-relief groove \
	-borderwidth 2 \
	-background white
    bind $w.lessequences.srcnom <Return> [list ChercheNom]
    
    # then gridify all that !
    grid $FrmSequence.biotextnom \
	-row 0 -column 0 \
	-sticky ns -padx 5
    grid $FrmSequence.scrolly \
	-row 0 -column 3 \
	-sticky ns -padx {1 5}
    grid $FrmSequence.biotextsequence \
	-row 0 -column 1 \
	-columnspan 2 \
	-sticky news
    grid $FrmSequence.srcnom \
	-row 1 -column 0 \
	-padx 5
    grid $FrmSequence.regle \
	-row 1 -column 1 \
	-columnspan 2 \
	-sticky ew
    # ATTENTION
    # keep row 2 empty to put conservation profil if needed
    grid $FrmSequence.fpos \
	-row 3 -column 1 \
	-sticky w
    grid $FrmSequence.scrollxseq \
	-row 3 -column 2 \
	-sticky ew
    
    grid rowconfig    $FrmSequence 0 -weight 1
    #grid columnconfig $FrmSequence 0 -weight 1
    grid columnconfig $FrmSequence 2 -weight 1
    #grid columnconfig $FrmSequence {0 2 3} -weight 0
    #grid columnconfig $FrmSequence 2 -weight 0
    
    update idletasks

    return
}


proc ReDessineLesScores {} {
    global FrmSequence Toggle

    if {! [set Toggle(Scores)]} {
	return
    }

    switch [QuelMode] {
	"feature" {
	    set l [LesBoutonsEnfonces]
	    set Lf [lsearch -regexp -all -inline $l {^Cons\-|^Score\-}]
	    if {! [llength $Lf]} {
		#set Toggle(Scores) 0
		return
	    }
	}
	"conservation" {
	    set Lf [lindex [set ::Cons(ConsCou)] 0]
	    puts "Lf $Lf"
	    if {$Lf eq "None"} {
		return
	    }
	}
	default return
    }

    #lulu
    foreach f $Lf {
	DessineLesScores $f
    }

    $FrmSequence.csc xview moveto [lindex [$FrmSequence.scrollxseq get] 0]

    update idletasks

    return
}


proc DessineLesScores {{f ""}} {
    global NomFenetreOrdali Toggle LongueurTotale FrmSequence NomTextSeq ScoreMeth

    if {! [set Toggle(Scores)]} {
	return
    }
    
    set bdi [expr {[$NomTextSeq cget -borderwidth] + [$NomTextSeq cget -highlightthickness]}]
    lassign [$NomTextSeq font metrics] tmp ascent tmp descent tmp linespace tmp fixed tmp width
    set HgLtr $linespace
    set LgLtr $width

    set LgPxl [expr {2*$bdi + $LgLtr * $LongueurTotale}]
    set HgPxl 50
    set Width [$NomTextSeq cget -width]
    set WdtPxl [expr {$Width * $LgLtr}]
    set Ccs $FrmSequence.csc
    if {! [winfo exists $Ccs]} {
	canvas $FrmSequence.csc \
	    -height $HgPxl \
	    -width $WdtPxl \
	    -scrollregion [list 0 0 $LgPxl $HgPxl] \
	    -bg white \
	    -borderwidth 2 \
	    -xscrollincrement 1 \
	    -xscrollcommand "$FrmSequence.scrollxseq set"
	grid $FrmSequence.csc -in $FrmSequence -row 2 -column 1 -columnspan 2 -sticky ew
    } else {
	# canvas scores already exists
	$Ccs configure \
	    -height $HgPxl \
	    -width $WdtPxl \
	    -scrollregion [list 0 0 $LgPxl $HgPxl] \
	    
    }
    
    if {$f eq ""} {
	$Ccs delete all
	update idletasks

	return
    }
    
    set Lg [set ScoreMeth($f,ListeGrps)]

    #
    # Min/Max global or not
    if {[info exists ScoreMeth($f,ScaleGlobal)] && $ScoreMeth($f,ScaleGlobal)} {
	set ScaGlob 1
	set min  9999999.
	set max -9999999.
	foreach g $Lg {
	    if {$ScoreMeth($f,${g}-min) < $min} {
		set min $ScoreMeth($f,${g}-min)
	    }
	    if {$ScoreMeth($f,${g}-max) > $max} {
		set max $ScoreMeth($f,${g}-max)
	    }
	}
    } else {
	set ScaGlob 0
    }

    # Draw a line showing consrvation for each group
    foreach g $Lg {
	if {$g eq "grise" || $g eq "bidon"} {
	    continue
	}

	if {$g eq "GroupeToutLeMonde"} {
	    set col black
	} else {
	    set No [string range $g 5 end]
	    set col [CouleurO2Ordali [CouleurDuGroupe $No]]
	}
	
	set Lv {}
	set Lx {}
	set Li [array names ScoreMeth "$f,$g,*"]
	foreach v $Li {
	    lassign [split $v ,] tmp tmp i 
	    lappend Lx $i
	}

	set c -1
	foreach i [lsort -integer $Lx] {
	    while {$c != ($i - 1)} {
		lappend Lv -999.0
		incr c
	    }
	    lappend Lv [set ScoreMeth($f,$g,$i)]
	    incr c
	}

	if {! [llength $Lv]} {
	    continue
	}

	if {! $ScaGlob} {
	    set max [set ScoreMeth($f,${g}-max)]
	    set min [set ScoreMeth($f,${g}-min)]
	}
	
	set i -1
	set Coord {}
	foreach v [lrange $Lv 0 end] {
	    incr i
	    if {$v == -999.} {
		if {$Coord == {}} {
		    continue
		}
		set x [expr {$i*$LgLtr}]
		set y $HgPxl
		lappend Coord $x $y
		$Ccs create line $Coord \
		    -fill $col \
		    -width 1
		set Coord {}
	    } else {
		# v != -999.0
		set v [expr {1.0*($v-$min)/($max-$min)}]
		if {$Coord == {}} {
		    set x [expr {$i*$LgLtr}]
		    set y $HgPxl
		    lappend Coord $x $y
		}
		set x [expr {$i*$LgLtr+$LgLtr/2}]
		set y [expr {round($HgPxl-$v*$HgPxl)}]
		lappend Coord $x $y
	    }
	}
	if {$Coord != {}} {
	    incr i
	    set x [expr {$i*$LgLtr-1}]
	    set y $HgPxl
	    lappend Coord $x $y
	    $Ccs create line $Coord \
		-fill $col \
		-width 1
	}
    }
    
    FenetreAuCentre $NomFenetreOrdali
    $Ccs xview moveto [lindex [$FrmSequence.scrollxseq get] 0]
    update idletasks

    return
}


proc PrendPDBDansPilier {args} {
    set ::Defauts(PDBDansPilier) [set ::Cons(PDB)]

    return
}


proc ToggleScores {{args ""}} {
    global Toggle NomFenetreOrdali FrmSequence Cons ListeTypesDeFeatures

    lassign $args n1 n2 op
    if {$n1 eq "Cons" && $n2 eq "Show"} {
	set Toggle(Scores) [set Cons(Show)]
    }
    
    # Define which score to display
    switch [QuelMode] {
	"feature" {
	    set Lft [lsearch -regexp -all -inline $ListeTypesDeFeatures {^Cons\-|^Score\-}]
	}
	"conservation" {
	    set Lft [lindex [set Cons(ConsCou)] 0]
	    if {$Lft eq "None"} {
		set Lft ""
	    }
	}
	default {
	    set Lft ""
	}
    }

    if {[set Toggle(Scores)]} {
	if {[QuelMode] eq "feature"} {
	    DessineLesScores
	    foreach e $Lft {
		set w [BtnDeLaFeature $e]
		if {[EtatDuBouton $w]} {
		    DessineLesScores $e
		}
	    }
	} elseif {[QuelMode] eq "conservation"} {
	    DessineLesScores $Lft
	}
    } else {
	# Toggle(scores) = 0
	if {[winfo exists $FrmSequence.csc]} {
	    grid forget $FrmSequence.csc
	    destroy $FrmSequence.csc
	}
    }

    update idletasks
    FenetreAuCentre [winfo toplevel $NomFenetreOrdali]

    return
}


proc AfficheFrameScores {} {
    global FrmScores NomFenetreOrdali

    set w $NomFenetreOrdali
    set FrmScores "$w.scores"
    frame $FrmScores
    grid $FrmScores -row 3 -column 0 -sticky ew -padx 5

    return
}


proc ToggleSecStr {{from ""}} {
    # from the menu, the checkbutton has already set Defauts(AffSS) :
    # apply it (toggling it again made the item useless)
    if {$from eq "menu"} {
	if {$::Defauts(AffSS)} {
	    MontreStrSecDansAlignement
	} else {
	    set ::Defauts(AffSS) 1
	    CacheStrSecDansAlignement
	}
	return
    }

    if {$::Defauts(AffSS)} {
	set ::Defauts(AffSS) 0
	CacheStrSecDansAlignement
    } else {
	set ::Defauts(AffSS) 1
	MontreStrSecDansAlignement
    }

    return
}


proc MontreStrSecDansAlignement {} {
    global Defauts NomTextSeq LNOrdali ListePDB
    
    if {! [ModeI]} {
	return
    }
    if {[TypeAli] eq "pasdali"} {
	return
    }
    if {[set Defauts(DownloadPDB)] eq "dont"} {
	return
    }
    if {! [set Defauts(AffSS)]} {
	return
    }
    if {[InSeqlabMode]} {
	set Defauts(AffSS) 0
	return
    }

    $NomTextSeq configure -state normal
    foreach t {Hel She Tur} {
	catch {$NomTextSeq tag remove $t}
    }

    set y 0
    set Lth {} ; set Lts {} ; set Ltt {}
    foreach n $LNOrdali {
	incr y
	if {[string trim $n] ni $ListePDB} {
	    continue
	}

	set chn   [DonneChainDeAccessPDB $n]
	set MolId [DonneIdDeAccessPDB $n]

	foreach ss [$MolId SecStr -chain $chn] {
	    #puts "ss= $ss"
	    DecortiqueSS $ss Elmt NomChnDep DbP FnP Rm
	    if {$Elmt eq "Coil" || $chn ne $NomChnDep} {
		continue
	    }

	    set Deb [DonnePosSG $n $DbP]
	    set Fin [DonnePosSG $n $FnP]
	    # (biotext tags include their last column : no incr Fin)
	    switch $Elmt {
		"Alpha" {lappend Lth $y.$Deb $y.$Fin}
		"Pi"    {lappend Lth $y.$Deb $y.$Fin}
		"3_10"  {lappend Lth $y.$Deb $y.$Fin}
		"Sheet" {lappend Lts $y.$Deb $y.$Fin}
		"Turn"  {lappend Ltt $y.$Deb $y.$Fin}
	    }
	}
    }

    if {$Lth != {}} {
	$NomTextSeq tag add Hel {*}$Lth
    }
    if {$Lts != {}} {
	$NomTextSeq tag add She {*}$Lts
    }
    if {$Ltt != {}} {
	$NomTextSeq tag add Tur {*}$Ltt
    }

    $NomTextSeq configure -state disabled

    set Defauts(AffSS) 1

    return
}


proc CacheStrSecDansAlignement {} {
    global Defauts NomTextSeq NomNomSeq

    if {! [set Defauts(AffSS)]} {return}
    if {[TypeAli] eq "pasdali"} {return}
    if {[QuelMode] eq "seqlab"} {return}

    $NomNomSeq  configure -state normal
    $NomTextSeq configure -state normal

    # biotext : 'tag remove <tag>' without index removes all the ranges
    foreach t {Hel H31 She Tur} {
	catch {$NomTextSeq tag remove $t}
    }

    $NomNomSeq  configure -state disabled
    $NomTextSeq configure -state disabled

    set Defauts(AffSS) 0

    return
}


proc ToggleFeature {} {
    global FrmBouton NomFenetreOrdali Toggle

    if {[QuelMode] ni [list "feature" "ordali"] && [TypeAli] eq "pasdali"} {
	set Toggle(Feature) [expr {! $Toggle(Feature)}]
	
	return
    }

    if {$Toggle(Feature)} {
	grid $FrmBouton -row 4 -column 0 -padx 10 -pady 10 -sticky news
    } else {
	grid forget $FrmBouton
    }

    update idletasks
    FenetreAuCentre [winfo toplevel $NomFenetreOrdali]

    return
}



proc AfficheFrameFeatures {} {
    global FrmBouton NomNomSeq NomFenetreOrdali OrdEtcDir

    set FrmBouton $NomFenetreOrdali.fbout
    frame $FrmBouton
    grid $FrmBouton -row 4 -column 0 -sticky ew -padx 10 -pady 10

    frame $FrmBouton.fimg
    grid $FrmBouton.fimg -row 0 -column 0 -sticky ""
    
    grid columnconfig $FrmBouton 0 -weight 0
    grid columnconfig $FrmBouton 1 -weight 1
    grid rowconfig    $FrmBouton 0 -weight 1
    
    set wmac "$FrmBouton.fimg.limg"
    set Wdt [expr {[winfo reqwidth $NomNomSeq] - 10}]
    set fmacsim [file join $OrdEtcDir "MACSIM_50px_cut_transparent.gif"]
    image create photo macsim
    macsim read $fmacsim -shrink
    label $wmac \
	-image macsim \
	-anchor n \
	-width $Wdt
    grid $wmac -row 0 -column 0 -sticky news
    grid columnconfig $FrmBouton.fimg 0 -weight 0
    grid rowconfig    $FrmBouton.fimg 0 -weight 0
    
    return
}


proc AfficheFrameDebug {} {
    # Debuggage
    # Permet de resourcer un fichier (merci rR)
    # Permet d'executer une commande

    global CAE NomFenetreOrdali FrmDebug

    set FrmDebug "$NomFenetreOrdali.fdev"
    frame $FrmDebug
    grid $FrmDebug -row 5 -column 0 -sticky ew -padx 10 -pady 1

    grid columnconfig $FrmDebug {0 2} -weight 0
    grid columnconfig $FrmDebug 1     -weight 1
    grid rowconfig    $FrmDebug 0     -weight 0

    if {! [Devlpt]} {return}

    label $FrmDebug.lblc -text "Command"
    entry $FrmDebug.entc -background white -textvariable CAE
    button $FrmDebug.okc -text " OK " -bg green1 -command "uplevel #0 \[$FrmDebug.entc get\]"

    grid $FrmDebug.lblc -column 0 -row 0 -sticky e
    grid $FrmDebug.entc -column 1 -row 0 -sticky ew
    grid $FrmDebug.okc  -column 2 -row 0 -sticky w

    update

    return
}


proc ToggleShowSeqFrame {} {
    global Defauts FrmToolBar FrmVues FrmScores FrmBouton FrmDebug GridDeFrame

    # the menu is the menubar of the window : no frame for it
    if {! [set Defauts(ShowFrame)]} {
	set GridDeFrame {}
	foreach f [list $FrmToolBar $FrmVues $FrmScores $FrmBouton $FrmDebug] {
	    if {[winfo exists $f] && [grid info $f] ne ""} {
		lappend GridDeFrame $f [grid info $f]
		grid forget $f
	    }
	}

	set Defauts(ShowFrame) 1
    } else {
	foreach {f info} $GridDeFrame {
	    grid $f {*}$info
	}
	set Defauts(ShowFrame) 0
    }

    return
}


proc ToggleFullScreen {} {
    # Full screen mode of the main window. Some window managers do not
    # support "-fullscreen" (the attribute stays 0) : the window then
    # takes the whole screen. The previous geometry is restored.
    global GeomAvantPleinEcran

    if {[info exists GeomAvantPleinEcran]} {
	# leave the full screen mode
	wm attributes . -fullscreen 0
	update idletasks
	wm geometry . $GeomAvantPleinEcran
	unset GeomAvantPleinEcran
    } else {
	set GeomAvantPleinEcran [wm geometry .]
	wm attributes . -fullscreen 1
	update idletasks
	after 300
	update
	if {! [wm attributes . -fullscreen]} {
	    wm geometry . "[winfo screenwidth .]x[winfo screenheight .]+0+0"
	}
    }
    update idletasks

    return
    global GeomNormal Defauts NomFenetreOrdali

    #puts "TogglefullScreen"
    set top [winfo toplevel $NomFenetreOrdali]

    wm withdraw $top

    set Etat [wm attributes $top -fullscreen]
    puts "toplevel $top Etat $Etat Def [set Defauts(FullScreen)]"

    #set Defauts(FullScreen) [expr {! [set Defauts(FullScreen)]}]
    set Etat [expr {! $Etat}]
    if {$Etat} {
	puts "switch to Full Screen"
	set GeomNormal [wm geometry $top]
	puts "   GeomNormal $GeomNormal"
	set xw [winfo screenwidth $top]
	set xh [winfo screenheight $top]
	puts "   $xw $xh"
	#wm maxsize $top $xw $xh
	#wm minsize $top $xw $xh

	#wm overrideredirect $top 1
	#wm attributes $top -fullscreen 1
	wm attributes $top -fullscreen 1
	puts "  New [wm geometry $top]"
    } else {
	puts "back to Normal"
	set geom [string map [list + " " - " " x " "] $GeomNormal]
	lassign [split $geom " "] w h x y
	#wm overrideredirect $top 0
	#wm attributes $top -fullscreen 0
	if {$x eq ""} {set x 0}
	if {$y eq ""} {set y 0}
	if {$w eq ""} {set w 0}
	if {$h eq ""} {set h 0}
	wm geometry $top +${x}+$y
	wm attributes $top -fullscreen 0
    }

    wm deiconify $top
    update idletasks
    
    set Defauts(FullScreen) $Etat

    return
}


proc InitSeqsOut {{Etat ""}} {
    global Defauts SeqsOut LNOrdali

    if {$Etat eq ""} {set Etat $Defauts(LockSeqs)}
    foreach s $LNOrdali {
	set SeqsOut($s) $Etat
    }

    return
}


proc AfficheFenetreOrdali {} {
    global NomFenetreOrdali

    set w $NomFenetreOrdali

    grid rowconfig    $w {0 1 3 4 5}   -weight 0
    grid rowconfig    $w 2                 -weight 1
    grid columnconfig $w 0             -weight 1
    # Warning ! Menu is NOTT a row !
    AfficheBarreMenus

    # row 0 starts here
    AfficheBarreBoutons
    AfficheBarreMac
    AfficheFrameSequences
    AfficheFrameScores
    AfficheFrameFeatures
    AfficheFrameDebug

    AfficheBoutonsOrdali

    LesDefauts BackAppliOri [$w cget -background]

    return
}


proc LanceOrdali {{behave slave} {aNomFenetreOrdali ""}} {
    global LongueurTotale NomSeqSel BufferSeq ListeTypesDeFeatures VariablesAuDepart Threshold AExecuter APutser NomFenetreOrdali Defauts Toggle TabSF ListeTypesDeFeatures BufNTimes ListeDesFragments
    upvar $aNomFenetreOrdali NomFenetreOrdali

    # init compulsory variables and arrays
    set Threshold [set Defauts(Threshold)]
    set ListeTypesDeFeatures {}
    set FrmBtnFea {}
    set ListeDesFragments {}
    set NomSeqSel {}
    set BufferSeq {}
    set LongueurTotale 0
    array set TabSF {}
    set BufNTimes ""
    set notePrev ""

    InitComparaison
    InitChemicals
    InitHydrophobicityAA
    InitCode3l1l
    DefinitionPreferences
    InitialiseCouleurs
    PrintSetup "defauts"

    DemarrageOrdali

    set fileIn [LoadingAlignement]
    if {$fileIn  == 0} {
	# initialisation problem
	exit
    }
    
    if {[set Defauts(PreCompute)]} {
	PreCalculs
    }

    FinDemarrage
    
    # Launch main window
    if {! [info exists NomFenetreOrdali] || $NomFenetreOrdali eq ""} {
	set NomFenetreOrdali ".ordali"
    }
    set w $NomFenetreOrdali
    
    if {[ModeI]} {
	ChangeTkOptions
	InitialiseFenetreOrdali $behave $NomFenetreOrdali
	raise $NomFenetreOrdali

	BindingsOrdali
	BindMenuItems

	InitAffichage
	OrdaliDefaultMapping
	OrdaliDefaultTags

	if {[TypeAli] in {"XML" "RSF" "ORD"}} {
	    ChangeMode "feature"
	}
	
	# Toggle if necessary
	ToggleScores
	if {! $Toggle(ToolBar)} {
	    ToggleToolbar
	}
	if {! $Toggle(Feature)} {
	    ToggleFeature
	}
	# ORD : trees and overviews of every instance
	RestaureFenetresORD
    }

    set VariablesAuDepart [info globals]
    
    if {[set Defauts(TypeDeGroupesACreer)] != "User" && [TypeAli] != "XML"} {
	#DefinitionGroupes [set Defauts(TypeDeGroupesACreer)]
	CommandLineClustering [set Defauts(TypeDeGroupesACreer)]
    }
    
    if {[set Defauts(Run)]} {
	CreeLesPiliers
	RunOrdali
	ChangeMode feature
    }

    if {[set Defauts(Dump)]} {
	DumpOrdali
    }
    
    if {[set Defauts(RunScript)]} {
	source [set Defauts(Script)]
    }
    
    if {$behave eq "slave"} {
	return $w
    }

    if {[info exists AExecuter] && $AExecuter ne ""} {
	eval "$AExecuter"
    }
    if {[info exists APutser] && $APutser ne ""} {
	puts [eval $APutser]
    }

    if {[set Defauts(Exit)]} {
	AdieuOrdali
    }

    puts "\nAll done !"
    return
}


proc ShowNameContextMenu {pos} {
    lassign [$::NomNomSeq index $pos] y x

    if {[InSeqlabMode]} {
	set nom [lindex $::LNSeqlab $y-1]
    } else {
	set nom [lindex $::LNOrdali $y-1]
    }
	set nom [string trim $nom]
    if {$nom eq ""} {
	return
    }

    set menu $::WOrdali(NameContextMenu)
    if {[winfo exists $menu]} {
	destroy $menu
    }
    CreateNameContextMenu

    set w [winfo parent $::NomNomSeq]
    lassign [winfo pointerxy $w] x y
    set ::WOrdali(NameContextMenuX) $x
    set ::WOrdali(NameContextMenuY) $y

    tk_popup $menu $x $y

    return
}


proc CreateNameContextMenu {} {
    set w .namemenu
    set ::WOrdali(NameContextMenu) $w

    menu $w -tearoff 0
    $w add command -label "Show description" -command "ShowLongInfoSeq"
    $w add command -label "Open Info page" -command "OpenSequenceInfoPage"
    $w add separator
    $w add command -label "Add structure" -command "AddStructureToSeq"

    return
}
    

proc InitialiseFenetreOrdali {{behave slave} w} {
    global Defauts VersionDeOrdali NomFenetreOrdali
    
    set wtitle [TitreFenetreOrdali]
    
    # pour rR
    #lm 2026/11/17 commented for publication
    #set DialogPorts [DialogPort "GetAll"]
    if {0 && $DialogPorts ne ""} {
	append wtitle " Port $DialogPorts" 
    }
    
    if {$behave eq "slave"} {
	catch {destroy $w}
	set top "${w}_[pid]_[clock scan now]"
	toplevel $top
    } else {
	# master, toplevel is '.'
	set top .
    }
    if {! [info exists NomFenetreOrdali] || $NomFenetreOrdali eq ""} {
	set NomFenetreOrdali $w
    }

    wm title    $top $wtitle
    wm iconname $top "Ordalie"
    wm maxsize $top [winfo screenwidth $top] [winfo screenheight $top]
    wm protocol $top WM_DELETE_WINDOW AdieuOrdali

    grid columnconfig $top 0 -weight 1
    grid rowconfig    $top 0 -weight 1

    wm withdraw $top

    frame $w
    grid $w -row 0 -column 0 -sticky news

    AfficheFenetreOrdali    

    MetAJourWMacs
    MesCouleurs $w
    wm deiconify $top
    update idletasks
    
    FenetreAuCentre $top

    BindModeNormal

    if {[Devlpt]} {
	foreach a [array names Defauts] {
	    set lg [string length $a]
	    set aff "$a [string repeat "." [expr {30-$lg}]] :"
	    AuLog "$aff [set Defauts($a)]"
	}
	AuLog "\n"
    }
    
    focus $::NomTextSeq
    update idletasks

    #CreateNameContextMenu
    
    return $NomFenetreOrdali
}


proc SaveClustersNames {w what} {
    global SDG LNDG

    if {$what eq "dismiss"} {
	destroy [winfo toplevel $w]
	return
    }

    set i 0
    foreach g $LNDG {
	# same groups, same order as NamesOfClusters
	if { ! [regexp {^Group[0-9]+$} $g]} {continue}

	set wdg "$w.eg$i"
	set name [string trim [$wdg get]]

	if {$name ne "" && (! [info exists SDG(Equiv,$g)] || $SDG(Equiv,$g) ne $name)} {
	    set SDG(Equiv,$g) $name
	    # to be saved in the instance
	    VueEditee 1
	}
	incr i
    }

    destroy [winfo toplevel $w]

    # barcode shows the names of the groups
    if {[winfo exists .barcode]} {
	BarcodeView
    }

    return
}


proc NamesOfClusters {} {
    global LNDG SDG

    set Ln {}
    foreach g $LNDG {
	if {[regexp {^Group[0-9]+$} $g]} {
	    lappend Ln $g
	}
    }
    if {! [llength $Ln]} {
	FaireLire "There are no groups to be named !"
	return
    }

    set w .noc
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    wm title $w "Names Of Clusters"
    wm iconname $w "Names"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    grid rowconfig $w all -weight 1
    grid columnconfig $w all -weight 1

    label $w.titre \
	-text "Names Of Clusters" \
	-font "helvetica 14 bold" \
	-anchor w -justify left
    label $w.label \
	-text "Give a name to the clusters of the alignment" \
	-anchor w -justify left
    grid $w.titre -row 0 -column 0 -sticky w -padx 5 -pady 5
    grid $w.label -row 1 -column 0 -sticky w -padx 5 -pady {5 10}
    
    set ws $w.fgrps
    frame $ws
    label $ws.ognm \
	-text "Old Name" \
	-anchor w -justify left
    label $ws.ngnm \
	-text "New Name" \
	-anchor w -justify left
    label $ws.odnm \
	-text "Old Name" \
	-anchor w -justify left
    label $ws.ndnm \
	-text "New Name" \
	-anchor w -justify left
    grid $ws.ognm -row 0 -column 0 -sticky w 
    grid $ws.ngnm -row 0 -column 1 -sticky w -padx {1 5}
    grid $ws.odnm -row 0 -column 2 -sticky w -padx {5 1}
    grid $ws.ndnm -row 0 -column 3 -sticky w 
    set i 0
    set r 1
    foreach g $Ln {
	label $ws.lg$i \
	    -text "$g" \
	    -anchor w -justify left
	entry $ws.eg$i \
	    -background white \
	    -width 10
	# current name
	if {[info exists SDG(Equiv,$g)] && $SDG(Equiv,$g) ne $g} {
	    $ws.eg$i insert 0 $SDG(Equiv,$g)
	}
	if {! ($i % 2)} {
	    # to the left
	    grid $ws.lg$i -row $r -column 0 -sticky w
	    grid $ws.eg$i -row $r -column 1 -sticky w -padx {1 5}
	} else {
	    # to the right
	    grid $ws.lg$i -row $r -column 2 -sticky w -padx {5 1}
	    grid $ws.eg$i -row $r -column 3 -sticky w
	    incr r
	}
	incr i
    }
    grid $ws -row 2 -column 0 -sticky ew -padx 5 -pady 5

    set wb $w.fbtn
    frame $wb
    button $wb.dis \
	-text "Cancel" \
	-background red \
	-command {SaveClustersNames .noc.fgrps dismiss}
    button $wb.ok \
	-text " OK " \
	-background green1 \
	-command {SaveClustersNames .noc.fgrps ok}
    grid $wb.dis -row 0 -column 0 -sticky w -padx 10
    grid $wb.ok  -row 0 -column 1 -sticky e -padx 10
    grid columnconfig $wb 0 -weight 1
    grid $wb -row 3 -column 0 -sticky ew -padx 5 -pady {15 5}
    
    MesCouleurs $w
    FenetreAuCentre $w
    grab $w

    tkwait window $w 

    return
}


proc CreateAndDisplayMacsims {} {
    global TabSF LNOrdali LSOrdali Sequences

    if {[QuelMode] eq "seqlab"} {
	FaireLire "Please leave the Editor before creating Macsims."
	
	return
    }

    if {[TypeAli] eq "XML" || [TypeAli] eq "ORD"} {
	
	return
    }
    
    if {$::Defauts(MacsimDone)} {
	FaireLire "Macsim already done !\nCan't do it twice for the moment !"

	return
    }

    FaireAttendre "Please wait ...\nCreating Macsims ..."
    
    ClearSelectionNoms
    set Lmsf [CreeLeMSF OnRetourne]
    set msf [join $Lmsf \n]
    set Txml [MacsimsREST $msf]

    # Carefull !!
    # Txml is not a list but a text string !!
    if {! [regexp {^\<\?xml |^\<!DOCTY} $Txml]} {
	FaireLire "A problem occurs while computing macsims ..."
	FaireLaSuite

	return
    }

    VueEditee 1
    # temp saving
    set LNOrdali_tmp $LNOrdali
    set LSOrdali_tmp $LSOrdali

    unset Sequences
    set LNOrdali {}
    set LSOrdali {}
    DecortiqueUnXml2 $Txml
    set ::AlnScore 0.0
    set ::AlnNote ""
    foreach n $LNOrdali {
	if {[string trim $n] ne ""} {
	    lappend LSOrdali [set Sequences($n)]
	}
    }
    DonneTabFeature TabSF

    UpdateDBSeqInfo
    InitPosSeqGenGenSeq
    # features d'origine seulement : celles du nouveau
    # snapshot sont enregistrees par SauveLeMac
    MetAJourTableFeatures

    LesDefauts TypeAli XML
    ChangeNomsAff $::Defauts(NomsAffiches)
    ChangeMode feature
    SauveLeMac 1 "Macsims alignment" "Macsims from Ordalie"
    LesDefauts MacsimDone 1
    
    FaireLaSuite

    return
}


# Purpose -
# turn all underlined menu entries into bindings
# Assumes all underlines are unique
# Todo 
#   - if widget that is being bound to keyboard events already has that binding figure out what to do.
#   - the UcharList dows not work on recursive calls so it will not catch duplicate characters
#   - if something dynamically changes the menus this invoke system will break down.
#   - fix so that topWin figured out from menuWidget. It seems that it is a toplevel
#   - add somehow some generations of help informatin for application.
# Notes -
#  peculiar behavior when a keyboard focus is in a widget and both widget and topWin with bindings have same keybindings since they will 
#  execute twice. Example is a entry widget and a ctrl-C operation which is also binded in the topwindow.
# Assumptions - you only want these shortcuts to work when a topWin's widget has keyboard focus. plus the widget has the topwin in its bindtags list.
#



proc accelerateMenu { menu {topWin .}  {modBase Control-Key} disableVarName } {
    set i 0
    set UCharsList {}
    
    while {$i <= [$menu index end]} {
	set type [$menu type $i]
	if {$type == "separator"} {
	    incr i
	    continue
	}

	if {$type == "cascade" } {
	    accelerateMenu [$menu entrycget $i -menu] $topWin $modBase $disableVarName
	    incr i
	    continue
	} ; # Recursively follow cascades
	set label [$menu entrycget $i -label]
	set underLineIndex [ $menu entrycget $i -underline]
	if {$underLineIndex < 0} {
	    incr i
	    continue
	}
	set char [string index $label $underLineIndex]
	if {[lsearch $UCharsList $char] >= 0} {
	    puts "skipping $label"
	    incr i
	    continue
	}
	bind $topWin <$modBase-$char> [format "if \{\$%s\} \{%s invoke %d\}"  $disableVarName $menu $i  ]
	$menu entryconfigure $i -accelerator <$modBase-$char>
	lappend UCharsList 
	incr i
    }

    return
}


proc UpdateInfosDesSeqs {} {
    global LNOrdali ListePDB {*}[info globals "TD*"] Sequences
    
    if {[QuelMode] ni {"ordali" "feature"}} {
	return
    }
    
    # create co-list seqname-access
    set Luni {} ; set Lnun {}
    set Lref {} ; set Lnrf {}
    set Lgi  {} ; set Lngi {}
    foreach n $LNOrdali {
	if {[string trim $n] eq "" || [string trim $n] in $ListePDB} {
	    continue
	}
	
	set bid [set TDesBId($n)]
	if {[EstUnUniProt $bid]} {
	    lappend Lnun $n
	    # In Uniprot, Access is not moving
	    lappend Luni [set TDesAccess($n)]
	} elseif {[EstUnRefseq $bid]} {
	    lappend Lnrf $n
	    lappend Lref $bid
	} elseif {[EstUnGI $bid]} {
	    lappend Lngi $n
	    lappend Lgi  $bid
	}
    }
    
    # first : Check UniProt ID haven't change
    set Luni [ConvertUniProt2UniProtAcc $Luni]
    
    array set T {}
    # infos from uniprot
    if {$Luni != {}} {
	set out [InfosFromUniProt $Luni]
	if {$out == 0} {
	    FaireLire "Problem when fetching UniProt information.\nPlease try again later."
	    set out {}
	}
	
	array set T $out
    }
    
    # change GI to refseq ID
    if {$Lgi != {}} {
	set Lchn [ConvertGI2RefSeq $Lgi]
	foreach g $Lgi c $Lchn n $Lngi {
	    # not found
	    if {$g eq $c} {
		continue
	    }
	    
	    # add as refseq ID
	    lappend Lref $c
	    lappend Lnrf $n
	}
    }
    
    # get refseq infos
    if {$Lref != {}} {
	puts "Lref >$Lref<"
	set aT [InfosFromRefSeq $Lref]
	puts "aT= $aT"
	array set T $aT
    }
    
    if {[llength [array names T]] == 0} {
	puts "\nNothing updated ..."
	puts "array names T 0"
	puts "\nLuniprot [join $Luni \n]"
	puts "\nLrefseq  [join $Lref \n]"
	
	return {}
    }
    
    # make summary of changes
    set Lsqn [concat $Lnun $Lnrf]
    set Lid  [concat $Luni $Lref]
    array set Chg {}
    if {[TypeAli] in {"XML" "ORD"}} {
	foreach sqn $Lsqn id $Lid {
	    if {[llength [array names T "$id,*"]] == 0} {
		continue
	    }
	    
	    # check AC
	    if {$TDesAccess($sqn) ne $sqn && $TDesAccess($sqn) ne $T($id,currAC)} {
		set Chg($sqn,AC) [list $TDesAccess($sqn) $T($id,currAC)]
	    }
	    
	    # check ID
	    if {$TDesBId($sqn) ne $sqn && $TDesBId($sqn) ne $id} {
		set Chg($sqn,BId) [list $TDesBId($sqn) $id]
	    }
	    
	    # check all other data
	    foreach t {TDesDescriptifs TDesTaxId TDuLineage TDesOrganismes TDesPhylum TDesAccess} k {Desc TaxId Lineage Organism Phylum currAC} {
		if {[set ${t}($sqn)] ne "" && [set ${t}($sqn)] ne [set T($id,$k)]} {
		    set Chg($sqn,$k) [list [set ${t}($sqn)] [set T($id,$k)]]
		}
	    }
	}
    }
    
    # Now update the different tables
    set Lseq {}
    foreach sqn $Lsqn id $Lid {
	if {! [info exists T($id,Desc)]} {
	    continue
	}

	foreach t {TDesDescriptifs TDesTaxId TDuLineage TDesOrganismes TDesPhylum TDesAccess} k {Desc TaxId Lineage Organism Phylum currAC} {
	    set ${t}($sqn) [set T($id,$k)]
	}
	# check if the sequence itself changed
	set seq [string map {"." "" "~" "" "-" "" "Z" ""} [set Sequences($sqn)]]
	if {$seq ne $T($id,Sequence)} {
	    set Chg($sqn,Sequence) 1
	    lappend Lseq $sqn $T($id,Sequence)
	}
    }
    
    # realign if necessary
    if {$Lseq != {}} {
	RealignSequencesThatChange $Lseq
    }
    
    if {[TypeAli] ni {"XML" "ORD"}} {
	LogInfosSeqsGlobales
    } else {
	LogChangesDuringInfoUpdate [array get Chg]
    }
    #OutputTLog stdout
    #OutputTLog Text
    #OutputTLog HTML

    #package require browser_info
    #OpenInBrowser file://FRAT01.html
    
    
    #AuLog LOutput HTML
    #puts "\nLog Done ...\n"
    
    return 1
}


proc LogChangesDuringInfoUpdate {aT} {
    if {$aT == {}} {
	return
    }
    array set Chg $aT

    global LNOrdali LSOrdali Sequnces ListePDB
    
    # ckeck changes for all sequences
    foreach n $LNOrdali {
	if {[string trim $n] eq "" || [string trim $n] in $ListePDB} {
	    continue
	}

	foreach k [lsort [array names Chg "$n,*"]] {
	    lassign [set Chg($k)] old new
	    puts "$k | $old ==> $new "
	}
	puts ""
    }

    return
}

proc LogChangesInInfosSeqs {aChg} {
    upvar $aChg Chg

    AuLog @title Changes in sequences information :
    AuLog @tele [DonneDateEtHeure]
    AuLog @tele ""

    set Lk [lsort [array names Chg]]
    foreach key $Lk {
	if {$key eq "Sequence"} {
	    continue
	}
	AuLog @title {*}[split "$key :"]
	AuLog @begin tabular
	switch $key {
	    "Accession" {set Lcols {"seq-name" "Id" "old" "new"}}
	    default {set Lcols {"seq-name" "Accession" "old value" "new value"}}
	}

	AuLog @titlecols {*}$Lcols
	AuLog @typecols T T T T
	foreach elt $Chg($key) {
	    lassign $elt sqn id old new
	    AuLog @row $sqn $id $old $new
	}
	AuLog @end
    }

    AuLog @title Sequence :
    if {! [info exists Chg(Sequence)]} {
	AuLog @tele "No sequence changes"
	return
    } else {
	AuLog @tele "The following amino-acid sequences have changed and have been re-aligned :"
    }
    AuLog @begin tabular
    AuLog @titlecols "seq-name" "Accession"
    AuLog @typecols T T
    foreach elt $Chg(Sequence) {
	AuLog @row {*}$elt
    }
    AuLog @end

    return
}


proc ValidateWindowCheckInfosSeqs {w what} {
    if {$what eq "ok"} {
	if {$::seqs2check eq ""} {
	    FaireLire "Please select one option !"
	    return
	}

	if {$::seqs2check eq "selected" && $::NomSeqSel == {}} {
	    FaireLire "No sequences selected !"
	    return
	}
    } else {
	# indicate to the caller to leave
	set ::seqs2check "return"
    }

    destroy $w

    return
}


proc WindowCheckInfosSeqs {} {
    if {! [info exists ::tk_patchLevel]} {
	LoadTkAndPackages
    }
	set w .wcheckinfos
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    wm title $w "Retrieve Seq. Information"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    #grid columnconfig $w 0 -weight 1
    #grid rowconfig    $w 0 -weight 1

    set wf "$w.fchx"
    frame $wf
    grid $wf -row 0 -column 0 -sticky w -padx 5 -pady 5
    
    set txt "Retrieve sequences information from public domain\n databases (UniProt, RefSeq).\n\nWhich sequences should be considered ?" 
    label $wf.lab \
	-font TitleFont \
	-width 25 \
	-text "$txt" \
	-relief flat \
	-fg $::Defauts(ForeAppli) \
    -justify left
    set ::seqs2check ""
    radiobutton $wf.rsel \
	-text "selected sequences" \
	-value "selected" \
	-relief flat \
	-justify left \
    -variable ::seqs2check
    radiobutton $wf.rall \
	-text "ALL sequences" \
	-value "all" \
	-relief flat \
	-justify left \
    -variable ::seqs2check
    grid $wf.lab  -row 0 -column 0 -sticky w
    grid $wf.rsel -row 1 -column 0 -sticky w -padx {15 1}
    grid $wf.rall -row 2 -column 0 -sticky w -padx {15 1}

    set wb "$w.fbut"
    frame $wb
    grid $wb -row 1 -column 0 -pady 15

    button $wb.bcl \
	-text " Cancel " \
	-bg red \
	-command [list ValidateWindowCheckInfosSeqs $w "cancel"]
    button $wb.bok \
	-text " OK " \
	-bg green1 \
	-command [list ValidateWindowCheckInfosSeqs $w "ok"]
    grid $wb.bcl -row 0 -column 0 -sticky w -padx 10
    grid $wb.bok -row 0 -column 1 -sticky e -padx 10

    FenetreAuCentre $w
    update idletasks
    #InfosDeWindow $w
    tkwait window $w

    return
}


proc DetailsSummaryChangesInfosSeqs {} {
    AuLog LOutput HTML
    set fout [file rootname $::Defauts(Fichier[TypeAli])].html

    #package require browser_info
    #puts "fout= file://[file normalize $fout]"
    set file "file://[file normalize $fout]"
    set ok [OpenInBrowser $file]
    puts "ok $ok"
    if {! $ok} {
	# open using a pure tcl HTML viewer
    }
    
    return
}


proc SummaryChangesInfosSeqs {aTSum} {
    global Defauts

    set w .sumchg
    global $w
    if {[winfo exists $w]} {
	raise $w
	return
    }

    array set TSum $aTSum

    toplevel $w
    wm title $w "Summary Changes in sequences information"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    grid columnconfig $w 0 -weight 1
    grid rowconfig $w 0 -weight 1

    CreateTitleFont

    label $w.gen \
	-font TitleFont \
	-text "Summary of changes after sequences information update.\nThe following items have been updated :" \
	-fg $Defauts(ForeAppli) \
	-justify left
    set i 1
    foreach k {Accession Description "Taxa Id" Lineage Organism Phylum} {
	if {! [info exists TSum($k)]} {
	    set TSum($k) {}
	}
	set n$k [llength $TSum($k)]
	label $w.n$k \
	    -text "[set n$k]" \
	    -justify right -anchor w
	label $w.w$k \
	    -text "$k" \
	    -justify left -anchor e
	grid $w.n$k -row $i -column 0 -padx {15 5}
	grid $w.w$k  -row $i -column 1
	incr i
    }

    button $w.show \
	-text "Show details..." \
	-background cyan \
	-command [list DetailsSummaryChangesInfosSeqs]
    button $w.close \
	-background green1 \
	-text "Close" \
	-command "destroy $w"
    grid $w.show -row $i -column 0 -pady 20 -padx 10 -sticky w
    grid $w.close -row $i -column 1 -pady 20 -padx 10 -sticky e

    return
}


proc LaunchCheckInfosSeqs {} {
    global NomSeqSel seqs2check LNOrdali

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[InSeqlabMode]} {
	FaireLire "Not available in Editor mode ! "
	return
    }
    
    WindowCheckInfosSeqs
    if {$seqs2check ni {"selected" "all"}} {
	return
    }

    set Ln {}
    if {$seqs2check eq "selected"} {
	foreach s $NomSeqSel {
	    lassign [split $s .] y tmp
	    set n [string trim [lindex $LNOrdali $y-1]]
	    if {$n ne "" && $n ni $Ln} {
		lappend Ln $n
	    }
	}
	if {$Ln == {}} {
	    FaireLire "No sequence selected !"
	    return
	}
    } else {
	# check ALL sequences
	foreach n $LNOrdali {
	    set n [string trim $n]
	    if {$n ne ""} {
		lappend Ln $n
	    }
	}
    }

    set ret [CheckInfosSeqs $Ln]
    if {$ret == 0} {
	return
    }

    if {$ret == {}} {
	FaireLire "No changes found !"
    } else {
	SummaryChangesInfosSeqs $ret
    }	

    return
}


proc ClefInfosSeq {aRes acc} {
    # Returns the key of <acc> in the result table of FetchInfosSeqs,
    # or "" if <acc> was not found.
    # UniProt keys are upper-cased, RefSeq keys have no version
    # and GI numbers are stored as BId.
    upvar $aRes Res

    set Lc [list $acc [string toupper $acc]]
    if {[regexp {^(.+)\.[0-9]+$} $acc tmp sv]} {
	lappend Lc $sv [string toupper $sv]
    }
    foreach c $Lc {
	if {[info exists Res($c,currAC)]} {
	    return $c
	}
    }
    if {[string is integer -strict $acc]} {
	foreach k [array names Res "*,BId"] {
	    if {$Res($k) eq $acc} {
		return [lindex [split $k ,] 0]
	    }
	}
    }

    return ""
}


proc LineageEnListe {lin} {
    # Returns lineage as a list of taxa, as stored in TDuLineage
    # ("Bacteria;" "Firmicutes;" ... "Bacillus.")
    set Lt {}
    foreach t [regexp -all -inline {[^;]+;?} $lin] {
	set t [string trim $t]
	if {$t ne "" && $t ne ";"} {
	    lappend Lt $t
	}
    }

    return $Lt
}


proc CheckInfosSeqs {{Liste ""} {what "full"}} {
    global LNOrdali LSOrdali Sequences ListePDB {*}[info globals "TD*"]
    
    FaireAttendre "Please wait ...\nRetrieving sequences information ...\nQuerying databases ... "

    set Lsqn {} ; set Lids {} ; set Lacc {}
    foreach n $Liste {
	set n [string trim $n]
	if {$n eq "" || $n in $ListePDB || ! [info exists TDesAccess($n)]} {
	    continue
	}
	set acc $TDesAccess($n)
	set id ""
	if {[info exists TDesBId($n)]} {
	    set id $TDesBId($n)
	}
	lappend Lsqn $n
	# special case for UniProt:
	# check if Access is real access, if no check for ID
	if {[EstUnUniProt $acc] && ! [EstUnAccUniProt $acc] && [EstUnAccUniProt $id]} {
	    lappend Lacc $id
	    lappend Lids $acc
	} else {
	    lappend Lacc $acc
	    lappend Lids $id
	}
    }
    
    set out [FetchInfosSeqs $Lacc]
    if {$out == 0 || $out == {}} {
	# no information fetched !
	FaireLaSuite
	FaireLire "Sorry ...\nNo information found ..."
	
	return 0
    }

    array set Res $out
    array set TSum {}

    # sequences for which information was found, and their key in Res
    set LoldSqn {} ; set LoldAcc {} ; set LoldKey {} ; set LoldId {}
    foreach sqn $Lsqn acc $Lacc id $Lids {
	set key [ClefInfosSeq Res $acc]
	if {$key eq ""} {
	    continue
	}
	lappend LoldSqn $sqn
	lappend LoldAcc $acc
	lappend LoldKey $key
	lappend LoldId $id
    }

    foreach sqn $LoldSqn acc $LoldAcc key $LoldKey id $LoldId {
	# accession changed (not only a case or version difference)
	set new $Res($key,currAC)
	if {[ClefInfosSeq Res $new] ne $key} {
	    lappend TSum(Accession) [list $sqn $id $acc $new]
	    set TDesAccess($sqn) $new
	}

	foreach t {TDesDescriptifs TDesTaxId TDuLineage TDesOrganismes TDesPhylum} k {Desc TaxId Lineage Organism Phylum} {
	    set vnew $Res($key,$k)
	    if {$k eq "Lineage"} {
		set vnew [LineageEnListe $vnew]
	    }
	    if {[string trim $vnew] eq ""} {
		# nothing retrieved, keep what we have
		continue
	    }
	    set vold ""
	    if {[info exists ${t}($sqn)]} {
		set vold [set ${t}($sqn)]
	    }
	    if {$k eq "Lineage"} {
		set cold [join [LineageEnListe [join $vold]]]
		set cnew [join $vnew]
	    } else {
		set cold [string trim $vold]
		set cnew [string trim $vnew]
	    }
	    if {$cold ne $cnew} {
		switch $k {
		    "Desc" {set tsk "Description"}
		    "TaxId" {set tsk "Taxa Id"}
		    default {set tsk $k}
		}
		lappend TSum($tsk) [list $sqn $acc $cold $cnew]
		set ${t}($sqn) $vnew
	    }
	}
    }

    set Lseq {}
    set Lchg {}
    set Lali {}
    foreach sqn $LoldSqn key $LoldKey {
	set Tsqn($sqn) $key
    }
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}

	set seqIn $Sequences($n)
	lappend Lali "\>$n" $seqIn

	if {! [info exists Tsqn($n)]} {
	    continue
	}
	set seqIn [string map {"." "" "-" "" "~" "" " " ""} $seqIn]
	set key $Tsqn($n)
	set seqNew $Res($key,Sequence)
	if {$seqNew ne "" && ! [string equal -nocase $seqIn $seqNew]} {
	    lappend Lseq "\>tUrLu_$n" $seqNew
	    lappend Lchg $n
	    
	    lappend TSum(Sequence) [list $n $Res($key,currAC)]
	}
    }

    if {$Lseq != {} && $what eq "full"} {
	set Ltfa [Mafft_AddSequences_local $Lali $Lseq]
	if {$Ltfa eq ""} {
	    FaireLaSuite
	    FaireLire "Problem when re-aligning the modified sequences with MAFFT !\nAmino-acid sequences have not been updated."
	    unset TSum(Sequence)
	    FaireAttendre "Please wait ..."
	} else {
	    DecortiqueUnTFA $Ltfa LNAligned SAligned
	    set newLgt [string length $SAligned([lindex $LNAligned 0])]

	    # alignment indexed by seqname
	    # Seq with changes are named tUrLu_seqname
	    # LSmap : old sequences in the new alignment, used to
	    # move features. For a modified sequence, MAFFT aligns
	    # its old and new versions on the same columns.
	    set empty [string repeat " " $newLgt]
	    set LSnew {} ; set LSmap {}
	    foreach n $LNOrdali {
		set n [string trim $n]
		if {$n eq ""} {
		    lappend LSnew $empty
		    lappend LSmap $empty
		    continue
		}
		if {$n in $Lchg} {
		    lappend LSnew $SAligned(tUrLu_$n)
		} else {
		    lappend LSnew $SAligned($n)
		}
		lappend LSmap $SAligned($n)
	    }

	    # update features positions
	    UpdateFeaturesPositions $LNOrdali $LSOrdali $LNOrdali $LSmap

	    # update Sequences
	    unset Sequences
	    set LSOrdali $LSnew
	    foreach n $LNOrdali s $LSOrdali {
		set n [string trim $n]
		if {$n ne ""} {
		    set Sequences($n) $s
		}
	    }
	}
    }
    
    FaireLaSuite

    if {[array size TSum] == 0} {
	return {}
    }

    VueEditee 1

    # information of the sequences (table seqinfo) : written now,
    # otherwise lost when the ORD file is saved and opened again
    foreach sqn $LoldSqn {
	set Lchg {}
	foreach k {access desc taxid lineage orga lifed} t {TDesAccess TDesDescriptifs TDesTaxId TDuLineage TDesOrganismes TDesPhylum} {
	    if {[info exists ${t}($sqn)]} {
		lappend Lchg $k [set ${t}($sqn)]
	    }
	}
	EcritInfosSeqDansBase $sqn $Lchg
    }
    FichierModifie 1

    LogChangesInInfosSeqs TSum

    AfficheNomsEtSeqs
    RepeintNomsEtSeqs

    # trees : the phylum may now be known
    MetAJourPhylumArbre
    
    return [array get TSum]
}


proc FetchInfosSeqs {{Liste ""}} {
    global ListePDB
    
    set Lid {}
    set Lref {} ; set Luni {} ; set Lother {}
    foreach n $Liste {
	set n [string trim $n]
	if {$n eq "" || $n in $ListePDB} {
	    continue
	}
	
	# refseq (WP_ is not known by EstUnRefseq), GenBank protein, GI
	if {[EstUnRefseq $n] || [regexp {^WP_[0-9]{6,9}(\.[0-9]+)?$} $n] \
		|| [regexp {^[A-Z]{3}[0-9]{5,7}(\.[0-9]+)?$} $n] \
		|| [string is integer -strict $n]} {
	    lappend Lref $n
	} elseif {[EstUnUniProt $n]} {
	    lappend Luni $n
	} else {
	    lappend Lother $n
	}
	lappend Lid $n
    }
    
    # for refseq
    set out [InfosFromRefSeq $Lref]
    if {$out == 0} {
	FaireLire "Problem when fetching information from RefSeq !\nPlease try again later !"
	set okR 0
    } else {
	array set Res $out
	set okR 1
    }
    
    # from UniProt
    set out [InfosFromUniProt $Luni]
    if {$out == 0} {
	FaireLire "Problem when fetching UniProt information !\nPlease try again later !"
	set okU 0
    } else {
	array set Res $out
	set okU 1
    }

    if {$okU || $okR} {
	return [array get Res]
    } else {
	return 0
    }
}


proc CommandLineClustering {method} {
    global Clus

    switch $method {
	"secator" {set Clus(Method) "hierarchic / secator"}
	"dpc" {set Clus(Method) "kmeans / DPC"}
	"mmaic" {set Clus(Method) "mixture model / AIC"}
	"mmbic" {set Clus(Method) "mixture model / BIC"}
	"fichierclu" {
	    DefinitionGroupes "fichierclu"
	    return
	}
	"integral" {
	    # groups already restored from the ORD file database
	    return
	}
	default {
	    puts "\nmethod >$method< is not defined"
	    return
	}
    }
    set k "LCrit,\% identity"
    set Clus($k) 1
    set Clus(ShowSeqOut) 1
    set Clus(Combo) ""

    NouveauClustering 

    unset Clus

    return
}

proc image% {image percent} {
    set deno      [gcd $percent 100]
    set zoom      [expr {$percent/$deno}]
    set subsample [expr {100/$deno}]
    puts "deno $deno zoom $zoom sub $subsample"
    exit
    set im1 [image create photo]
    $im1 copy $image -zoom $zoom
    set im2 [image create photo]
    $im2 copy $im1 -subsample $subsample
    image delete $im1
    set im2
}
proc gcd {u v} {expr {$u? [gcd [expr $v%$u] $u]: $v}}


proc tsm {} {
    DecortiqueUnTFA topo.tfa Ln Seq
    set s ""
    foreach k [array names Seq] {
	append s $Seq($k)
    }
    set f "\#000000"
    set b "\#ffffff"

    puts "[time {set smap [string map [list . $b " " $b * $b ~ $b "?" $b A $f B $f C $f D $f E $f F $f G $f H $f I $f J $f K $f L $f M $f N $f O $f P $f Q $f R $f S $f T $f U $f V $f W $f X $f Y $f Z $f] $s]} 10]"
    puts [time {
	regsub -all {[a-zA-Z0-9]} $s "$f " smap1
	regsub -all {[^a-zA-Z0-9]} $smap1 "$b " smap1
    } 10]
    puts "[expr {$smap eq $smap1}]"

    return
}


proc BoutonParDefaut {btn} {
    set cmd [$btn cget -command]
    $btn configure -default active
    bind [winfo toplevel $btn] <Return> "$cmd ; break"

    return
}


proc posemsg {x y what} {
    puts "x= $x $y"
    switch $what {
	"leave" {destroy .t.m}
	"enter" {
	    message .t.m \
		-text "##########\n# TAG >1< #\n############" \
		-bg green1 -fg black \
		-borderwidth 5 \
		-font "Courier 64 bold"
	    place .t.m \
		-anchor nw \
		-in .t \
		-x [expr {$x+10}] -y [expr {$y+10}]
	}
	"move" {
	    place configure .t.m -x [expr {$x+10}] -y [expr {$y+10}]
	}
    }
    
    return
}

proc RealignSequencesThatChange {Lns} {
    global LNOrdali LSOrdali Sequences
    
    # Lns : sequences that changed
    # Lns = name seq name seq ...
    # All sequences already belong to the alignment
    # but the sequence itself has changed
    
    array set T $Lns
    puts "TLns [llength [array names T]]"
    set Lali {} ; set Lnew {}
    set iseq 1
    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}
	set nseq "seq$iseq"
	lappend Lali ">$nseq" $s
	
	if {[info exists T($n)]} {
	    set seq "new$iseq"
	    lappend Lnew ">$seq" $T($n)
	    array unset T "$n"
	}
	incr iseq
    }
    puts "Lali : [expr {[llength $Lali]/2}]"
    puts "Lnew : [expr {[llength $Lnew]/2}]"
    puts "\nRESTE"
    puts [join [array names T] \n]
    
    # ATTENTION ! 3 pour eviter DDBJ
    if {[llength $LNOrdali] < 3} {
	puts "MAFFT local"
	set Ltfa [Mafft_AddSequences_local $Lali $Lnew]
    } else {
	puts "MAFFT DDBJ"
	set Ltfa [Mafft_AddSequences_local $Lali $Lnew]
    }
    DecortiqueUnTFA $Ltfa LAligned SAligned
    puts [llength $LAligned]
    
    set LSOrdali {}
    set iseq 1
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {
	    set sadd $s
	} else {
	    set nseq "seq$iseq"
	    set nnew "new$iseq"
	    if {[info exists SAligned($nnew)]} {
		set sadd $SAligned($nnew)
	    } else {
		set sadd $SAligned($nseq)
	    }
	}
	
	lappend LSOrdali $sadd
	if {[string trim $n] ne ""} {
	    set Sequences($n) $sadd
	    incr iseq
	}
    }
    
    return
}

proc DebNomsWdg {{msg ""}} {
    global NomNomSeq NomTextSeq LNOrdali LSOrdali

    puts "$msg"
    puts "W-Nom [llength [split [$NomNomSeq get 1.0 end] \n]]"
    set tmp [split [$NomNomSeq get 1.0 end] \n]
    if {[winfo class $NomTextSeq] eq "Text"} {
	puts "W-Seq [llength [split [$NomTextSeq get 1.0 end] \n]]"
	set pmt [split [$NomTextSeq get 1.0 end] \n]
    } else {
	puts "W-Seq [llength [$NomTextSeq output all]]"
	set pmt [$NomTextSeq output all]
    }
    puts "LNOrdali [llength $LNOrdali]"
    set i 0
    puts "LNOrdali W-Noms | LSOrdali W-Seqs"
    set fmt ">%8s< >%8s< | >%4s< >%4s<"
    foreach a $LNOrdali b $tmp c $LSOrdali d $pmt {
	if {$i > 3} {break}
	puts [format "$fmt" $a $b [string range [string map {".." ""} $c] 0 3] [string range [string map {"." ""} $d] 0 3]]
	incr i
    }
    puts ">>>>>>>>>>>>>>>>>>>>>>>"
    foreach a [lrange $LNOrdali end-2 end] b [lrange $tmp end-2 end] c [lrange $LSOrdali end-2 end] d [lrange $pmt end-2 end] {
	puts [format "$fmt" $a $b [string range [string map {".." ""} $c] 0 3] [string range [string map {"." ""} $d] 0 3]]
    }
    puts ""
    
    return
}


proc cpltst {args} {
    .t yview {*}$args
    .l yview {*}$args
    .b yview {*}$args

    return
}


proc tb2 {} {
    $::NomNomSeq configure -state normal
    #$::NomNomSeq tag state on
    $::NomNomSeq tag add InvNm 5.0 5.7 15.0 15.end

    return
}


proc tasp {} {
    AjouteSequenceOrPDB seqfile

    return
}

proc tf+2 {} {
    TailleFonte +2
    update idletasks
    TailleFonte +2
    return
}


proc tris {} {
    LaunchCheckInfosSeqs
    update idletasks
    DetailsSummaryChangesInfosSeqs
    update idletasks
    catch {destroy .sumchg}
    LaunchCheckInfosSeqs
    DetailsSummaryChangesInfosSeqs

    return
}

#jcrehm@citya.com
