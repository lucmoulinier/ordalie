

#
#
# --- ordali_sequence.tcl
#


proc OuvrirFichierAlignementDansOrdali {{type "Unk"} {Fichier ""}} {
    global Sequences FichierTFA FichierXML FichierMSF FichierRSF FichierORD FichierALN Defauts
    
    if {[info exists Sequences]} {
	FaireLire "Close the current file first !"
	return
    }
    
    if {[string tolower $type] eq "macsim"} {
	set type "XML"
    }
    set tyfi $type
    if {$type eq "Unk"} {
	set tyfi "all"
    }
    
    if {$Fichier eq ""} {
	set Fichier [DemandeEtOuvreFichier $tyfi]
    }

    if {$Fichier eq ""} {
	return
    }

    if {[EstUnFichierRSF $type $Fichier]} {
	FaireLire "The RSF format is not supported anymore !"
	return
    }

    DemarrageOrdali .wroom

    if {"tdom" ni [package names]} {
	LoadTclPackages
    }

    if {$type eq "Unk"} {
	set ext [string tolower [file extension $Fichier]]
	if {$ext ni [list ".xml" ".macsim" ".macsims" ".aln" ".clustal" ".tfa" ".fasta" ".fa" ".msf" ".rsf" ".ord"]} {
	    set type [DetecteTypeFichier $Fichier]
	    if {$type eq ""} {
		set ctype [tk_dialog .typfi "File type" "Please precise your file format :" "" 0 "Macsim/xml" "MSF" "Fasta/TFA" "Clustal" "Ordalie" "Cancel"]
		switch $ctype {
		    0 {set type "XML"}
		    1 {set type "MSF"}
		    2 {set type "TFA"}
		    3 {set type "ALN"}
		    4 {set type "ORD"}
		    5 {return}
		}
	    }
	} else {
	    set type [string toupper [string range $ext 1 end]]
	    # extensions -> the types known below
	    switch -- $type {
		"MACSIMS" - "MACSIM" {set type "XML"}
		"FASTA" - "FA" - "TFASTA" {set type "TFA"}
		"CLUSTAL" {set type "ALN"}
	    }
	}
    }
    if {$type ne "Unk"} {
	LesDefauts TypeAli $type
    }

    set type [string tolower $type]
    InitInfoArrays
    switch $type {
	"msf" {
	    set FichierMSF $Fichier
	    LesDefauts FichierMSF $Fichier
	}
	"xml" {
	    set FichierXML $Fichier
	    LesDefauts FichierXML $Fichier
	}
	"tfa" {
	    set FichierTFA $Fichier
	    LesDefauts FichierTFA $Fichier
	}
	"rsf" {
	    set FichierRSF $Fichier
	    LesDefauts FichierRSF $Fichier
	}
	"aln" {
	    set FichierALN $Fichier
	    LesDefauts FichierALN $Fichier
	}
	"ord" {
	    set FichierORD $Fichier
	    LesDefauts FichierORD $Fichier
	}
    }

    LoadingAlignement
    if {[set Defauts(PreCompute)]} {
	PreCalculs
    }
    InitAffichage
    if {[info exists ::TabSF]} {
	ChangeMode "feature"
    }
    BindingsOrdali
    BindModeNormal
    # ORD : trees and overviews of every instance
    RestaureFenetresORD
    # title : name of the new file
    if {[ModeI]} {
	wm title [winfo toplevel $::NomFenetreOrdali] [TitreFenetreOrdali]
    }

    #FaireLaSuite
    FinDemarrage .wroom

    return
}


proc LitLeTFA {FileOrText aNom aSeq} {
    upvar $aNom Nom $aSeq Seq

    if {[file exists $FileOrText]} {
	set Lignes [LesLignesDuFichier $FileOrText]
    } else {
	set Lignes [split $FileOrText "\n"]
    }
    lappend Lignes ">"

    set n 0
    set laseq ""
    foreach l $Lignes {
	set l [string trim $l]
	if {$l eq ""} {continue}
	if {[string index $l 0] eq ">"} {
	    if {$laseq ne ""} {
		set laseq [string map [list " " "" "-" "." "\n" "" "~" "."] $laseq]
		set laseq [string toupper $laseq]
		lappend Nom $lenom
		set Seq($lenom) $laseq
		set laseq ""
		incr n
	    }

	    set l [string trim [string range $l 1 end]]
	    set ib [string first " " $l]
	    if {$ib == -1} {
		set ib end
	    } else {
		incr ib -1
	    }
	    set lenom [string range $l 0 $ib]
	} else {
	    append laseq $l
	}
    }

    return $n
}


proc CreeLeNEXUS {} {
    
}


proc DecortiqueUnNEXUS {file aNom aSeq} {
    upvar $aNom LNom $aSeq TSeq

    if {[regexp {\n} $file]} {
	set Lignes $file
    } else {
	set Lignes [LesLignesDuFichier $file]
    }

    set LNom {}
    # 1st line NEXUS
    foreach l [lrange $Lignes 1 end] {
	set l [string trim $l]
	if {[regexp -nocase {^begin} $l]} {
	    set hat [lindex [split $l " "] 1]
	}
    }

    return
}


proc DecortiqueUnALN {file aNom aSeq} {
    upvar $aNom LNom $aSeq TSeq

    if {[regexp {\n} $file]} {
	set Lignes $file
    } else {
	set Lignes [LesLignesDuFichier $file]
    }

    set LNom {}
    foreach l [lrange $Lignes 1 end] {
	# consensus line (the names of older Ordalie files start with spaces)
	if {[regexp {^[ *:.]*$} $l]} {
	    continue
	}

	regsub -all { +} [string trim $l] " " l
	lassign [split $l " "] nomori seq tmp
	set nom [BonAccess $nomori]
	if {$nom ni $LNom} {
	    lappend LNom $nom
	    set TSeq($nom) $seq
	} else {
	    append TSeq($nom) $seq
	}
    }

    foreach n [array names TSeq] {
	set TSeq($n) [BonneSequencePourAlignement [set TSeq($n)]]
    }

    return [llength $LNom]
}


proc DecortiqueUnTFA {file aNom aSeq} {
    upvar $aNom Nom $aSeq Seq
    
    if {[file exists $file]} {
	set Lignes [LesLignesDuFichier $file]
    } elseif {[string first "\n" $file] != -1} {
	# texte brut
	set Lignes [split $file "\n"]
    } elseif {[llength $file] > 1} {
	set Lignes $file
    }
    lappend Lignes ">"

    set n 0
    set Nom {}
    set laseq ""
    set lenom ""
    foreach l $Lignes {
	set l [string trim $l]
	if {$l eq ""} {
	    continue
	}
	if {[string index $l 0] eq ">"} {
	    if {$laseq ne ""} {
		set laseq [BonneSequencePourAlignement $laseq]
		set lenom [BonAccess $lenom]
		lappend Nom $lenom
		set Seq($lenom) $laseq
		set laseq ""
		incr n
	    }

	    set l [string trim [string range $l 1 end]]
	    set ib [string first " " $l]
	    if {$ib == -1} {
		set ib end
	    } else {
		incr ib -1
	    }
	    set lenom [string range $l 0 $ib]
	} else {
	    append laseq $l
	}
    }

    return $n
}


proc VerifieFormatAlignement {file format} {
    set rep [EstLeBonFormat $file $format]
    if {[ModeI] && ! $rep} {
	FaireLire "This seems not to be a $format file !"
    }

    if {$rep} {
	return 1
    } else {
	LesDefauts TypeAli "pasdali"
	return 0
    }
}


proc EstUnFichierRSF {type file} {
    # RSF format is disabled : the code reading it is
    # kept, but must not be reached anymore
    if {[string toupper $type] eq "RSF"} {
	return 1
    }
    if {[string tolower [file extension $file]] eq ".rsf"} {
	return 1
    }
    if {[catch {open $file rb} f]} {
	return 0
    }
    set debut [read $f 256]
    close $f

    return [regexp {^\s*!!RICH} $debut]
}


proc FormatDuFichierSequence {file} {
    if {[file exists $file]} {
	set l [ContenuDuFichier $file]
    } else {
	set l $file
    }
    set l [string trimleft $l "\n"]
    set Entete [string range $l 0 5]
    switch -regexp $Entete {
	{^\<\?xml }  {set fmt XML}
	{^\<!DOCTY}  {set fmt XML}
	{^PileUp}    {set fmt MSF}
	{^!!RICH}    {set fmt RSF}
	{^\>}        {set fmt TFA}
	{^SQLite}    {set fmt ORD}
	{^CLUSTA}    {set fmt ALN}
	default      {set fmt "unknown"}
    }

    if {$fmt eq "unknown"} {
	set Lt [split [string range $l 0 2000] "\n"]
	set Ix [lsearch -regexp $Lt {MSF:.+Type:.+Check:.+\.\.}]
	if {$Ix != -1} {set fmt MSF}
    }

    return $fmt
}


proc EstLeBonFormat {file format} {
    set format [string toupper $format]
    if {$format eq "ORD"} {
	return 1
    }
    set fmt [FormatDuFichierSequence $file]
    if {$fmt eq $format} {
	return 1
    } else {
	return 0
    }
}


proc SauveLAlignement {{format ""} {outFile ""}} {
    # Returns 1 if the file has been written, 0 if the save has
    # been cancelled (the alignment is then still "not saved")
    global AliOutputFile AliOutputFormat Defauts

    if {[TypeAli] eq "pasdali"} {
	return 0
    }

    if {[string toupper $format] eq "RSF" || [string tolower [file extension $outFile]] eq ".rsf"} {
	FaireLire "The RSF format is not supported anymore !"
	return 0
    }

    set Edite [VueEditee]
    if {[VueEditee]} {
	if {0 && [ModeI]} {
	    set chx [tk_dialog .chx "Warning" "Warning !\nChanges in this instance have not been saved !" "" 0 "Overwrite it" "Create a new one" "Cancel"]
	    if {$chx < 2} {
		SauveLeMac $chx
		VueEditee 0
	    } else {
		return
	    }
	} else {
		# in batch mode, overwrite it
	    # The 'Original alignment' (snapshot 1) can not
	    # be overwritten (SauveLeMac refuses) : keep the
	    # modifications in a new snapshot, otherwise they
	    # are lost in the ORD file
	    if {[MacCourant] == 1} {
		SauveLeMac 1 "Modified alignment" "Modifications of the original alignment"
	    } else {
		SauveLeMac 0
	    }
	    VueEditee 0
	}
    }

    # At startup, variables AliOutputFile and AliOutputFormat are not initialized
    if {! [info exists AliOutputFormat]} {
	if {$format eq ""} {
	    set AliOutputFormat [TypeAli]
	} else {
	    set AliOutputFormat $format
	}
    } elseif {$format ne ""} {
	set AliOutputFormat $format
    }
    set extion [string tolower $AliOutputFormat]

    # if : AliOutputFile does not exists ,
    #  -> first use, ask for file name, default is input file name
    # else : AliOutputFile exists, behavior depends on outfile
    #   -> JLeSauveAs : use AliOutputFile
    #  -> <somme name> use this name
    #  -> empty : ask for a file name
    if {! [info exists AliOutputFile]} {
	set AskOutputFile 1
	if {$outFile eq ""} {
	    set AliOutputFile [file rootname [set Defauts(Fichier[TypeAli])]].$extion
	} else {
	    set AskOutputFile 0
	    set AliOutputFile [file rootname $outFile].$extion
	}
    } else {
	# variable AliOutputfile exists
	if {$outFile eq ""} {
	    set AskOutputFile 1
	} elseif {$outFile ne "JLeSauveAs"} {
	    # save file with the given name
	    set AskOutputFile 0
	    set AliOutputFile $outFile
	} else {
	    # The file will be saved with the current name
	    set AskOutputFile 0
	}
    }
    
    if {$AskOutputFile} {
	if {[ModeI]} {
	    set askAgain 1
	    while {$askAgain} {
		set outfile [DemandeEtSauveFichier $AliOutputFormat 1 $AliOutputFile]
		if {$outfile eq ""} {
		    VueEditee $Edite
		    return 0
		}
		if {[CheckFileFormatExtension $outfile]} {
		    set askAgain 0
		} else {
		    set response [tk_dialog .resp "Bad extension ?" "Warning !\nThe file extension does not match the $AliOutputFormat known extensions." "" 0 "change it" "Proceed !" "Cancel"]
		    switch $response {
			0 {set askAgain 1}
			1 {set askAgain 0}
			2 {
			    VueEditee $Edite
			    return 0
			}
		    }
		}
	    }
	} else {
	    # batch mode, nothing to do normally ...
	}
	set AliOutputFile $outfile 
    }
    switch $AliOutputFormat {
	"FenetreMSF" {CreeLAlignementDeLaFenetre $AliOutputFile}
	"MSF"        {CreeLeMSF $AliOutputFile}
	"XML"        {CreeLeXml $AliOutputFile}
	"TFA"        {CreeLeTfa $AliOutputFile}
	"ALN"        {CreeLeAln $AliOutputFile}
	"ORD"        {CreeLeORD $AliOutputFile}
    }
    # only ORD keeps all the instances
    if {$AliOutputFormat eq "ORD"} {
	FichierModifie 0
    }

    return 1
}


proc SequencesASauver {} {
    global NomSeqSel LNOrdali LSOrdali LNSeqlab

    set LesNoms {}
    set LesSeqs {}

    if {[info exists NomSeqSel] && $NomSeqSel != {} } {
	set choix [tk_dialog .chx "Beware !!" "There are selected sequences ...\nDo you want to " "" 1 " Save selected" "Save all" "Cancel"]
    } else {
	set choix 1
    }

    switch $choix {
	0 {
	    set LesNoms [LesNomsDesSeqsSel]
	    set LesSeqs [LesSeqsDesSeqsSel]
	}
	1 {
	    if {[InSeqlabMode]} {
		set LNoms $LNSeqlab
		set LSeqs [$::NomTextSeq output all]
	    } else {
		set LNoms $LNOrdali
		set LSeqs $LSOrdali
	    }
	    foreach n $LNoms s $LSeqs {
		if {[string trim $n] eq ""} {
		    continue
		}
		lappend LesNoms $n
		lappend LesSeqs $s
	    }
	}
	2 {
	    return
	}
    }

    return [list $LesNoms $LesSeqs]
}


proc EcritLeMsf {outfile LNoms LSeqs} {
    foreach s $LSeqs {
	set w [SeqGCGCheckSum $s]
	incr SumCheck $w

	lappend Lw $w
	lappend Lt [DefinitTypeSeq $s]
    }
    set SumCheck [expr {$SumCheck % 10000}]
    set len [string length [lindex $LSeqs 0]]
    set Nmax [PlusLongEltDe $LNoms]
    if {$Nmax < 12} {set Nmax 11}
    set uLt [lunique $Lt]
    if {[llength $uLt] > 1} {
	set nmax -1 ; set tmax ""
	foreach e $uLt {
	    set n [llength [lsearch $Lt $e]]
	    if {$n > $nmax} {
		set nmax $n
		set tmax $e
	    }
	}
	set uLt $tmax
    }
    if {$uLt eq "Protein"} {set type "P"} {set type "N"}

    set Llg {}
    lappend Llg "PileUp\n\n\n\n"
    set ligne ""
    append ligne [format "   MSF:%5d  Type: %1s" $len $type]
    append ligne [format "    Check:%6ld   .. \n\n" $SumCheck]
    lappend Llg "$ligne"
    foreach n $LNoms w $Lw {
	lappend Llg [format " Name: %s oo  Len:%5d  Check:%6ld  Weight:  %.1f" $n $len $w 10.0]
    }
    lappend Llg "\n//"

    set chunks [expr {$len/100}]
    if {$len % 100 != 0} {incr chunks}
    
    for {set block 0} {$block < $chunks} {incr block} {
	lappend Llg "\n\n"
	set pos1 [expr {$block * 100}]
	set pos2 [expr {min($len-1, $pos1+99)}]
	foreach nom $LNoms seq $LSeqs {
	    set ligne [format "%${Nmax}s" $nom]
	    set bout [string range $seq $pos1 $pos2]
	    # last group of 10 may be incomplete (it was lost)
	    set nbout [expr {($pos2-$pos1+10)/10}]
	    for {set i 0} {$i < $nbout} {incr i} {
		append ligne " [string range $bout [expr {$i*10}] [expr {($i+1)*10-1}]]"
	    }
	    lappend Llg "$ligne"
	}
    }
    lappend Llg "\n\n"

    if {$outfile ne "OnRetourne"} {
	set f [CheckOpen $outfile]
	if {$f eq ""} {
	    return
	}
	puts $f [join $Llg \n]
	close $f
    }
    
    return $Llg
}


proc CreeLeMSF {{outfile ""} {LNomsTmp {}} {LSeqsTmp {}} {Degap ""}} {
    if {$outfile eq ""} {
	set outfile [DemandeEtSauveFichier "msf" 1]
    }
    if {$outfile eq ""} {return}

    if {$LNomsTmp == {} } {
	lassign [SequencesASauver] LNomsTmp LSeqsTmp
    }

    # No empty seqs for MSF
    set LNoms {}
    set LSeqs {}
    foreach n $LNomsTmp s $LSeqsTmp {
	if {[string trim $n] ne ""} {
	    lappend LNoms $n
	    lappend LSeqs $s
	}
    }
    if {$LNoms == {}} {return}

    if {$Degap != ""} {
	set LSeqs [lmap s $LSeqs {string map {. "" Z "" - "" ~ ""} $s}]
    }

    set Llg [EcritLeMsf $outfile $LNoms $LSeqs]

    return $Llg
}


proc CreeLAlignementDeLaFenetre {format {outfile ""}} {
    global tcl_platform OrdTmpDir NomNomSeq NomTextSeq

    if {! [ModeI]} {return}
    if {[TypeAli] eq "pasdali"} {return}

    if {$outfile eq ""} {
	set outfile [DemandeEtSauveFichier $format 1]
    }
    if {$outfile eq ""} {return}

    # visible area : from the top left to the bottom right corner
    # (-width/-height are the configured sizes, not the displayed ones)
    lassign [split [$NomTextSeq index @0,0] "."] ym xm
    set c [$NomTextSeq index @[expr {[winfo width $NomTextSeq]-1}],[expr {[winfo height $NomTextSeq]-1}]]
    lassign [split $c "."] yx xx

    # names : without the display padding ; no empty lines
    # (separators of groups)
    set Lnom {}
    set Lseq {}
    foreach n [lrange [$NomNomSeq output all] $ym-1 $yx-1] s [lrange [$NomTextSeq output all] $ym-1 $yx-1] {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}
	lappend Lnom $n
	lappend Lseq [string range $s $xm $xx]
    }
    if {$Lnom == {}} {
	return
    }

    switch [string tolower $format] {
	"tfa" {EcritLeTfa $outfile $Lnom $Lseq}
	"aln" {EcritLeAln $outfile $Lnom $Lseq}
	"msf" {EcritLeMsf $outfile $Lnom $Lseq}
    }

    return
}


proc LongueurDeLAlignement {{quoi ""}} {
    # ask for sequence 1 as sequences indices starts at 1 !
    # BEWARE !
    # 'output' cmd returns a list !
    if {$quoi eq "seqlab"} {
	set ::LongueurTotale [string length [lindex [$::NomTextSeq output 1] 0]]
    } else {
	set lgMax -1
	foreach s $::LSOrdali {
	    if {[set lg [string length $s]] > $lgMax} {
		set lgMax $lg
	    }
	}
	set ::LongueurTotale $lgMax
    }

    return $::LongueurTotale
}


proc GiveSameLength {aList} {
    upvar $aList List

    set lmax -1
    foreach s $List {
	if {[set l [string length $s]] > $lmax} {
	    set lmax $l
	}
    }

    set Lnew {}
    foreach s $List {
	if {[set l [string length $s]] != $lmax} {
	    set s "$s[string repeat " " [expr {$lmax - $l}]]"
	}
	lappend Lnew $s
    }
    set List $Lnew
    update
    
    return $lmax
}


proc AdjusteLongueurSequences {LSeqsAli LSAddSeq} {
    # adjust length between the two groups
    set lgAdd [string length [lindex $LSAddSeq 0]]
    set lgAli [string length [lindex $LSeqsAli 0]]

    set d [expr {$lgAdd - $lgAli}]
    set add [string repeat "." [expr {abs($d)}]]
    
    if {$d < 0} {
	# added sequences are shorter
	set Ltmp {}
	foreach s $LSAddSeq {
		append s $add
	    lappend Ltmp $s
	}
	set LSAddSeq $Ltmp
    } elseif {$d > 0} {
	# added sequences are longer
	set Lnew {}
	foreach s $LSeqsAli {
	    if {[string trim $s] ne ""} {
		append s $add
	    } else {
		append s [string map {"." " "} $add]
	    }
	    lappend Lnew $s
	}
	set LSeqsAli $Lnew
    }
    
    return [list $LSeqsAli $LSAddSeq]
}


proc DonneMemeLongueurListe {Liste {typeChar " "}} {
    set max [PlusLongEltDe $Liste]

    set Lnew {}
    foreach n $Liste {
	set l [string length $n]
	if {$typeChar eq "choose"} {
	    if {[string first "." $n] > -1} {
		set char "."
	    } elseif {[string first " " $n] > -1} {
		set char " "
	    } else {
		set char " "
	    }
	} else {
	    # typeChar ne choose
	    set char $typeChar
	}

	set new "$n[string repeat $char [expr {$max - $l}]]"
	lappend Lnew $new
    }

    return $Lnew
}    


proc DonneMemeLongueur {aTseq} {
    upvar $aTseq Tseq

    set lmx -1
    foreach n [array names Tseq] {
	set s [set Tseq($n)]
	set l [string length [string trim $s]]
	if {$l > $lmx} {
	    set lmx $l
	}
	lappend Ln $n
	lappend Ls $s
    }

    foreach s $Ls n $Ln {
	set l [string length [string trim $s]]
	if {$l != 0 && $l != $lmx} {
	    set d [expr {$lmx-$l}]
	    set add [string repeat "." $d]
	    append s $add
	}
	set Tseq($n) $s
    }

    return $lmx
}


proc ZonesDeSequence {s} {
    global ZoneClusterisation

    if {! [info exists ZoneClusterisation]} {return $s}

    set r ""
    foreach z $ZoneClusterisation {
	lassign $z x1 x2
	append r [string range $s $x1 $x2]
    }
    if {$r eq ""} {set r $s}

    return $r
}


proc EcritLeAln {outfile LNoms LSeqs} {
    set o [CheckOpen $outfile]
    if {$o eq ""} {
	return
    }

    puts $o "CLUSTAL W : Created by Ordalie [DonneDateEtHeure]"
    puts $o ""
    set maxn [PlusLongEltDe $LNoms]
    set maxs [PlusLongEltDe $LSeqs]
    set fmt "%-${maxn}s %s"

    set D 0
    while {$D < $maxs} {
	set F [expr {$D + 59}]
	foreach Nm $LNoms s $LSeqs {
	    if {[string trim $Nm] eq ""} {continue}

	    set Linit [string range $s $D $F]
	    set Linit [string map [list Z - . -] $Linit]
	    puts $o [format $fmt $Nm $Linit]
	}
	puts $o ""
	puts $o ""
	incr D 60
    }

    close $o

    return
}


proc CreeLeAln {{FilOut ""} {Degap ""}} {
    lassign [SequencesASauver] LNoms LSeqs
    if {$LNoms == {}} {return}

    if {$FilOut eq ""} {
	set FilOut [DemandeEtSauveFichier "tfa" 1]
    }
    if {$FilOut eq ""} {return}

    if {$Degap != ""} {
	set LSeqs [lmap s $LSeqs {string map {. "" - "" Z "" ~ ""} $s}]
    }

    EcritLeAln $FilOut $LNoms $LSeqs

    return
}


proc CreeLeTfa {{FilOut ""} {Degap ""}} {
    lassign [SequencesASauver] LNoms LSeqs
    if {$LNoms == {}} {return}

    if {$Degap != ""} {
	set LSeqs [lmap s $LSeqs {string map {. "" - "" Z "" ~ ""} $s}]
    }
    
    EcritLeTfa $FilOut $LNoms $LSeqs

    return
}


proc EcritLeTfa {FilOut LesNoms LesSequences} {
    if {$FilOut eq ""} {
	set FilOut [DemandeEtSauveFichier "tfa" 1]
    }
    if {$FilOut eq ""} {return}

    set f [CheckOpen $FilOut]
    if {$f eq ""} {
	return
    }
    
    foreach Nm $LesNoms s $LesSequences {
	if {[string trim $Nm] eq ""} {continue}
	puts $f ">$Nm"
	set D 0
	while {$D < [string length $s]} {
	    set F [expr {$D + 59}]
	    set Linit [string range $s $D $F]
	    set L [string map {Z - . -} $Linit]
	    puts $f "$L"
	    incr D 60
	}
    }

    close $f

    return
}


proc AlignementDesSelections {{Zone {}} aSAli} {
    upvar $aSAli SAli
    global NomSeqSel Sequences LNOrdali
    
    set LesNoms {}
    set LesSequences {}
    set LesNomsDesSeqs $LNOrdali

    if {[info exists NomSeqSel] && [llength $NomSeqSel] > 3} {
	set Li {}
	foreach p $NomSeqSel {
	    lassign [split $p .] y x
	    incr y -1
	    lappend Li $y
	}
    } else {
	for {set i 0} {$i < [llength $LesNomsDesSeqs]} {incr i} {
	    lappend Li $i
	}
    }
    
    if {! [llength $Zone]} {
	set Zone [list [list 0 [expr {[LongueurDeLAlignement]-1}]]]
    }

    set LVide {}
    foreach i $Li {
	set Nm [lindex $LesNomsDesSeqs $i]
	set Nm [string trim $Nm]
	if {$Nm eq ""} {
	    continue
	}
	set sbrut [set Sequences($Nm)]
	
	set s ""
	foreach z $Zone {
	    lassign $z x1 x2
	    append s [string range $sbrut $x1 $x2]
	}
	set tmp [string map {"\." "" Z "" " " "" X ""} $s]
	if {[string trim $tmp] eq ""} {
	    lappend LVide $i
	    continue
	}
	lappend LesNoms $Nm
	lappend LesSequences $s
    }

    set SAli {}
    foreach n $LesNoms s $LesSequences {
	lappend SAli $n $s
    }

    return $LVide
}


proc FaitLignesA60 s {

    set rep ""
    set D 0
    while {$D < [string length $s]} {
	set F [expr {$D + 59}]
	set Linit [string range $s $D $F]
	set L [string map [list Z - . -] $Linit]
	append rep "$L\n"
	incr D 60
    }

    return $rep
}


proc LitLesPoidsDuMSF {FichierMSF {ng ""}} {
    global SDG LNOrdali LesPoidsDesSequences

    if {$ng == ""} {
	set LesNomsDesSeqs $LNOrdali
    } else {
	set LesNomsDesSeqs [set SDG($ng)]
    }

    set LesLignes [LesLignesDuFichier $FichierMSF]

    if {[llength $LesLignes] < 2} { return 0 }

    set iSlashSlash [expr {[lsearch -regexp $LesLignes "//"]+1}]
    set iLeWeight [lsearch -regexp $LesLignes "Weight"]

    # lecture du champ Weight: du MSF

    set i 0
    foreach Ligne [lrange $LesLignes $iLeWeight $iSlashSlash] {
	if {![regexp "Weight" $Ligne]} {continue}
	set iw [expr {[string last "Weight" $Ligne]+7}]
	set pd [string trim [string range $Ligne $iw end]]
	set nom [lindex $LesNomsDesSeqs $i]
	set LesPoidsDesSequences($nom) $pd
	incr i
    }

    return
}



proc AssigneLesPoids {{nmgrp ""}} {
    global LesPoidsDesSequences Defauts Sequences LNOrdali OrdTmpDir

    if {1 || ! [set Defauts(Poids)] && ![set Defauts(Poids2)] && ![set Defauts(Poids3)]} {
	foreach s $LNOrdali {
	    set LesPoidsDesSequences($s) 1.
	}
	return
    }

    set in [file join $OrdTmpDir "[pid]_in"]
    set out [file join $OrdTmpDir "[pid]_out"]

    CreeLeTfa $in $nmgrp

    eval exec "calcule_weight $in $out"

    LitLesPoidsDuMSF $out $nmgrp

    file delete -force $in
    file delete -force $out

    return
}


proc CalculeConservationParSS {LePDB} {
    global ListePCISS Sequences ZoneSelect

    set ZoneSelect {}
    if {$LePDB eq ""} {
	set LePDB ""
	SelectSSDeType sheet
	SelectSSDeType helix
    } else {
	set chn   [DonneChainDeAccessPDB $LePDB]
	set MolId [DonneIdDeAccessPDB $LePDB]
	if {$chn eq ""} {set chn "a"}
	set Limites [$MolId SecStr -chain $chn]
	foreach Lelt $Limites {
	    # Elt Type No Chn dep res fin res lgt
	    # dep and fin are residue numbers of the structure :
	    # the zones are columns of the alignment
	    set d [DonnePosSG $LePDB [lindex $Lelt 4]]
	    set f [DonnePosSG $LePDB [lindex $Lelt 6]]
	    if {$d eq "" || $f eq "" || $d < 0 || $f < 0} {
		continue
	    }
	    lappend ZoneSelect [list $d $f]
	}
    }

    foreach e $ZoneSelect {
	lassign $e d f
	set ListePCISS($d,$f) [CalculeLesPCI $d $f "" "" 1]
    }

    return
}


proc NRIdentite {a lga b lgb} {
    foreach ca $a cb $b {
	incr p [expr {$ca ne "." && $ca eq $cb}]
    }

    return [expr {($lga<$lgb)?(1.0*$p/$lga):(1.0*$p/$lgb)}]
}


proc DetermineLesFragmentsLuc {} {
    global TDesPCI LNOrdali Sequences ListeDesFragments TDesFragments

    set ListeDesFragments {}

    FaireAttendre "Please wait ...\nDetermining sequences corresponding to fragments"

    foreach n [array names Sequences] {
	lappend Ll $n [string length [string trim [set Sequences($n)] "."]]
    }

    set i 2
    foreach {p a} [lrange $Ll 0 end-2] {	
	foreach {q b} [lrange $Ll $i end] {
	    if {$a > $b} {
		set v [expr {double($a)/$b}]
		set ref1 $p
		set ref2 $q
	    } else {
		set v [expr {double($b)/$a}]
		set ref1 $q
		set ref2 $p
	    }
	    if {$v < 0.8} {
		CalculeLesPCI "" "" $ref1 $ref2
	    }
	}
	incr i 2
    }

    foreach c [array names TDesPCI] {
	lassign [split $c ,] n1 n2
	lassign [set TDesPCI($c)] pc l1 l2 lg
	set bpc [expr {$pc > 0.6}]
	set blg [expr {$lg < 0.8}]
	set bn1 [expr {$n1 ni $ListePDB}]
	set bn2 [expr {$n2 ni $ListePDB}]
	if { $blg && $bpc && $bn1 && $bn2} {
	    lappend Frag $n1
	}
    }

    if {[info exists Frag]} {
	set ListeDesFragments [lsort -unique $Frag]
	foreach n $ListeDesFragments {
	    set TDesFragments($n) 1
	}
    }

    FaireLaSuite .frag

    return $ListeDesFragments
}


proc TraitePDBDeLAlignement {} {
    global ListePDB BadPDB HashPDB Sequences LNOrdali PBV PBW PipeCollection Warn LSOrdali SDG Defauts TabSF
    
    set ListePDB {}
    set BadPDB   {}
    set HashPDB(iHmax) 0
    set ix -1
    set PBW "Processing PDB sequences ...."
    set PBV 0.0
    set Nseq [llength $LNOrdali]
    set ToChange {}
    
    set LNtmp $LNOrdali
    foreach seqOri $LNtmp {
	set PBV [expr {$PBV + 100. / $Nseq}]
	incr ix

	# AlphaFold model added by UniProt ID : the
	# sequence is named <UniProtAcc>_<chain>
	# (e.g. Q3KRD0_A). Reload the model so that it
	# is again a structure. If it fails, keep it as
	# a plain sequence (no renaming).
	if {[regexp {^([A-Z0-9]+)_([A-Za-z0-9])$} $seqOri -> acc chn] && [EstUnAccUniProt $acc]} {
	    if {[set Defauts(DownloadPDB)] eq "dont"} {
		continue
	    }
	    if {$acc ni [info commands] && "::$acc" ni [info commands]} {
		lassign [LoadNewStructure $acc $acc] what desc
		if {$what ne "StrucID" || $desc ne $acc} {
		    continue
		}
	    }
	    if {$chn in [$acc _chains]} {
		lappend ListePDB $seqOri
	    }
	    continue
	}

	if {! [EstUnAccessPDB $seqOri]} {
	    continue
	}

	# BonNomPDB returns upper-case pdbid
	set seq [BonNomPDB $seqOri]
	set pdbid [DonneIdDeAccessPDB $seq]
	set chn   [DonneChainDeAccessPDB $seq]

	# ToChange <idx seq> <name> <chn> <justRename (0/1/2>
	# - 0 : normal PDB
	# - 1 : PDB seen as a sequence, not structure
	# - 2 : Bad PDB !
	if {[set Defauts(DownloadPDB)] eq "dont"} {
	    lappend ToChange [list $ix $pdbid $chn 1]
	    continue
	}

	# Download PDB
	# Already done ?
	set Lcmds [info commands]
	if {$pdbid in $Lcmds || "::$pdbid" in $Lcmds} {
	    set cok 1
	} else {
	    # entry not loaded
	    set cok [LoadNewStructure $pdbid $pdbid]
	    lassign $cok what desc
	    if {$what eq "Error"} {
		lappend ToChange [list $ix $pdbid $chn 2]
		lappend BadPDB $ix
		continue
	    }
	    
	    # obsolete or superseeded
	    if {$what eq "Obsolete"} {
		lassign $desc oldid newid
		set pdbid $newid
	    }
	}
	
	if {$chn ni [set Lc [lsort [$pdbid _chains]]]} {
	    set chn [lindex $Lc 0]
	}

	lappend ToChange [list $ix $pdbid $chn 0]
    }

    # Superseeded/obsolete/chain changed
    set Llog {}
    foreach k [lsort -integer -decreasing -index 0 $ToChange] {
	lassign $k i n c NormalOrSeqOrBad
	
	set oldName   [lindex $LNtmp $i]
	    
	if {$NormalOrSeqOrBad == 1} {
	    set newName "seq_${n}_$c"
	} elseif {$NormalOrSeqOrBad == 2} {
	    set newName "bsp_${n}_$c"
	} else {
	    set newName [BonNomPDB [string toupper ${n}]_$c]
	    lappend ListePDB $newName
	}
	    
	lset LNtmp $i $newName

	# name unchanged (e.g. file already saved
	# by Ordalie) : nothing to rename. Renaming
	# a name onto itself used to delete its
	# entries (TabSF ...)
	if {$oldName eq $newName} {
	    continue
	}

	set seqAA [lindex $LSOrdali $i]
	    unset -nocomplain Sequences($oldName)
	set Sequences($newName) $seqAA

	# update names in group arrays
	if {[info exists SDG]} {
	    foreach grp [array names SDG] {
		if {[set isdg [lsearch -exact [set SDG($grp)] $oldName]] != -1} {
		    lset SDG($grp) $isdg $newName
		}
	    }
	}

	if {$NormalOrSeqOrBad == 0 && ! [string equal -nocase $oldName $newName]} {
		# logs ...
	    set log "Warning : PDB entry $oldName changed to $newName"
	    lappend Llog $log
	}

	if {[TypeAli] eq "XML"} {
	    # change oldName in all info tables :
	    # keys oldName and oldName,* are renamed,
	    # values equal to oldName are replaced
	    # (except TDesSeqnamesOri, original name)
	    foreach t [info globals TD*] {
		global $t
		if {! [array exists $t]} {
		    continue
		}
		foreach k [array names $t] {
		    if {$k ne $oldName && [string first "$oldName," $k] != 0} {
			continue
		    }
		    set v [set ${t}($k)]
		    if {$v eq $oldName && $t ne "TDesSeqnamesOri"} {
			set v $newName
		    }
		    set nk $newName[string range $k [string length $oldName] end]
		    unset ${t}($k)
		    set ${t}($nk) $v
		}
	    }
	}

	# Change names in TabSF : keys oldName and
	# oldName,* are renamed, and references to
	# oldName in features (notes ...) are updated
	# (string map, oldName is not a pattern)
	foreach k [array names TabSF] {
	    set v [string map [list $oldName $newName] $TabSF($k)]
	    if {$k eq $oldName || [string first "$oldName," $k] == 0} {
		unset TabSF($k)
		set k $newName[string range $k [string length $oldName] end]
	    }
	    set TabSF($k) $v
	}
    }
    
	# log changes
    if {[llength $Llog] > 0} {
	AuLog @begin warning
	foreach log $Llog {
	    AuLog @text $log
		
	    puts ""
	    Espionne [string repeat "=" [string length $log]]
	    Espionne $log
	    Espionne [string repeat "=" [string length $log]]
	    Espionne ""
	}    
	AuLog @end
    }

    set LNOrdali $LNtmp
    
    # retreive Struc. sec for each chains of PDBs
    foreach pdb $ListePDB {
	set pdbid [DonneIdDeAccessPDB $pdb]
	foreach c [$pdbid _chains] {
	    #$pdbid PDBInfos $c
	}
    }

    return
}


proc BonneSequencePourAlignement {s {outtype ""}} {
    if {$outtype eq ""} {set outtype "ordali"}
    if {$outtype eq "same"} {return $s}

    switch $outtype {
	"ordali" -
	"msf" {
	    set rs "."
	    set s [string toupper $s]
	}
	"tfa" {
	    set rs "-"
	    set s [string toupper $s]
	}
	"xml" -
	"macsim" {
	    set rs "-"
	    set s [string tolower $s]
	}
    }

    set s [string map [list "-" $rs "." $rs " " $rs "\n" "" "~" $rs] $s]

    return $s
}

proc BonAccess {s {AsIs ""}} {
    set s [string trim $s]
    set s [lindex [split $s " "] 0]
    if {[string equal -nocase $AsIs "AsIs"]} { return $s }
    if {! [info exists ::Defauts] || ! [set ::Defauts(RemoveBankPrefix)]} {
	# only 'lcl|' is removed
	return [EnlevePrefixeBank $s]
    }

    set a [EnlevePrefixeBank $s]
    if {[EstUnAccessPDB $a]} {
	set a [BonNomPDB $a]
    } else {
	if {[regexp {\|} $a]} {
	    set a [string range $a 0 [string first "|" $a]-1]
	}
	if {[regexp {\.|\_|\,|\;|\:|\|} [string index $a end]]} {
	    set a [string range $a 0 end-1]
	}
	# voir InitPosSeqGenGenSeq
	# enleve character separateur : @
	set a [string map [list "@" "_"] $a]
    }
    set a [EnleveVersionDeAccess $a]

    return [string trim $a]
}


proc CreeLookupNoms {} {
    global LookupNoms
    global ListeNomAssocieALAccess

    foreach d $ListeNomAssocieALAccess {
	lassign $d n1 n2
	set LookupNoms($n1) $n2
	set LookupNoms($n2) $n1
    }

    return
}



proc RameneInfoSeq {} {

    global LNOrdali
    global NomOrgaCanon
    global ListeNomAssocieALAccess
    global LaClasseAssocieeAuxSequences
    global ListeDesNomsDeGene
    global ListeDesDefinitions

    if {[TypeAli] eq "pasdali"} {return}

    set ListeNomAssocieALAccess {}
    set ListeDesDefinitions {}
    set ListeDesNomsDeGenes {}
    set lorp {}

    FaireAttendre "Please wait ....\nRetrieving canonical names from access numbers ...."

    AuLog "\nCanonical names from access numbers\n===================================\n"
    set k 1
    foreach NmSq $LNOrdali {
	#	    DecortiqueLesLignesEMBL [LaSequenceDesBanques $NmSq $NmSq AccessOK "OnVeutEMBL"] ID AC DE GN OS OC OG

	set ID ""
	set GN ""
	set OS ""
	set OC ""
	set OG ""
	set DE ""
	set leslignes [RecupereUnFichierSurWeb [string toupper $NmSq]]
	if {$leslignes != "ERREUR"} {
	    DecortiqueLesLignesEMBL $leslignes ID AC DE GN OS OC OG
	}
	if {$GN == ""} {set GN "XXXXX"}

	set NomOrgaCanon "Unkn.unknw"
	if {$OS != ""} {
	    set Organisme [OrganismeCanonique $OS Sommaire]
	    if {$Organisme != ""} {
		set NomOrgaCanon [Glossaire "$Organisme" "Demi"]
	    }
	}

	set idx [lsearch -regexp $lorp $NomOrgaCanon]
	if {$idx != -1} {
	    scan [lindex $lorp $idx] "%s %s" n k
	    incr k
	    set NomOrgaCanon "$NomOrgaCanon$k"
	    set nv "$n $k"
	    set lorp [lreplace $lorp $idx $idx $nv]
	} else {
	    lappend lorp "$NomOrgaCanon 1"
	}

	lappend ListeNomAssocieALAccess [list $NmSq $NomOrgaCanon]

	set Phylum "PhylumUnknown"
	if {$OC != ""} {
	    set Classe $OC
	    set Phylum [Phylum $Classe]
	    set LaClasseAssocieeAuxSequences($NmSq) $Classe
	}
	AuLog "$NmSq $NomOrgaCanon $Phylum $DE"

	regsub -all {\-} $DE " " DE
	regsub -all {  +} $DE " " DE
	lappend ListeDesDefinitions $DE
	lappend ListeDesNomsDeGenes $GN
    }

    CreeLookupNoms

    FaireLaSuite .attendre

    return
}



proc InitPosSeqGenGenSeq {} {
    return

    global Sequences ListePDB db TPGS TPSG

    if {[info exists TPGS]} {
	unset TPGS TPSG
    }

    lassign [Ccode_InitPosSGGS [array get Sequences]] TPosGS TPosSG
    foreach {n k v} $TPosGS {
	set TPGS($n@$k) $v
    }
    foreach {n k v} $TPosSG {
	set TPSG($n@$k) $v
    }
	
    foreach nt $ListePDB {
	lassign $nt n tmp
	if {! [info exists Sequences($n)]} {continue}
	set n [BonNomPDB $n]
	array unset TPSG "${n}@*"
	array unset TPGS "${n}@*"
	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set sp [$mol _resnumber -chain $chn -polymer]
	set lgg [llength $sp]
	set sg [set Sequences($n)]

	set i -1 ; set c -1 ; set v [lindex $sp 0]
	foreach a [split $sg ""] {
	    incr i
	    if {$a ne "."} {
		incr c
		# c could not be greater than $lgg
		# it may happen if the sp != sg degape
		if {$c < $lgg} {
		    set v [lindex $sp $c]
		} else {
		    set v [lindex $sp end]
		}
		set TPSG($n@$v) $i
	    }
	    set TPGS($n@$i) $v
	}
	set TPSG($n@-1) $lgg
	set TPGS($n@-1) $lgg
    }

    return
}


proc DonnePosGS {n x {debug 0}} {
    # Attention ! 
    # renvoie coord avec START=1 !
    #                   ----------

    set o [string length [string map {"." ""} [string range $::Sequences($n) 0 $x]]]
    if {[string trim $n] in $::ListePDB} {
	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set lr [$mol _resnumber -chain $chn -polymer]
	if {$o >= [llength $lr]} {
	    set o [lindex $lr end]
	} elseif {$o != 0} {
	    set o [lindex $lr $o-1]
	}
    }
 
   return $o
}


proc DonnePosGS_new {n x seq {debug 0}} {
    # Attention ! 
    # renvoie coord avec START=1 !
    #                   ----------

    set o [string length [string map {"." ""} [string range $seq 0 $x]]]
    if {$n in $::ListePDB} {
	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set lr [$mol _resnumber -chain $chn -polymer]
	if {$o >= [llength $lr]} {
	    set o [lindex $lr end]
	} elseif {$o != 0} {
	    set o [lindex $lr $o-1]
	}
    }
 
   return $o
}


proc DonnePosGS_SL {n w y x {debug 0}} {
    # ==> Pour Mode Seqlab
    #
    # Attention ! 
    # renvoie coord avec START=1 !
    #                   ----------

    set o [string length [string map {"." ""} [string range [$w output [expr {$y-1}]] 0 $x]]]
    if {[string trim $n] in $::ListePDB} {
	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set lr [$mol _resnumber -chain $chn -polymer]
	if {$o >= [llength $lr]} {
	    set o [lindex $lr end]
	} elseif {$o != 0} {
	    set o [lindex $lr $o-1]
	}
    }

    return $o
}


proc DonnePosSG {n x} {
    # Attention !
    # renvoie avec start = 0 !
    #             -----------
    
    if {[string trim $n] in $::ListePDB} {
	set InListePDB 1
	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set x [lsearch [$mol _resnumber -chain $chn -polymer] $x]
    } else {
    set InListePDB 0
    }

    #return [lindex [lindex [regexp -all -inline -indices {[A-Z]} $::Sequences($n)] $x] 0]

    #rR RUSTINE
    if { [info exists ::Sequences($n)]} {
	return [Ccode_DonnePosSG $::Sequences($n) $x]
    }
    global DejaVuCeMessage

    set Message "Sequences($n) does not exist ... and $n in ListePDB=$InListePDB"
    if { ! [info exists DejaVuCeMessage($Message)]} {
	set DejaVuCeMessage($Message) 1
	Espionne $Message
	if {$InListePDB} {
	    puts "mol=$mol"
	    puts "x= $x"
	}
    }

    return {}
    
    #puts "out3 [time {set out3 [TclPosSeq2Gen $::Sequences($n) $x]}]"

    puts "$x | $out1 $out2 $out3\n"

    return $out1

    if {[set v [$::db eval {select gen from corrseqgen where nom=$n and seq=$x}]] ne ""} {
	return $v
    } else {
	puts "Pb SG -> $n $x"
	return -999
    }
}


proc TclPosSeq2Gen {s x} {
    set pos 0 ; set gen 0
    while {$pos < $x} {
	if {[string index $s $gen] ne "."} {
	    incr pos
	}
	incr gen
    }

    return $gen
}



proc InitPosSeqGenGenSeq_OLD {} {
    global Sequences TPosGS TPosSG ListePDB

    if {[info exists TPosSG]} {
	unset TPosSG TPosGS
    }

    lassign [Ccode_InitPosSGGS [array get Sequences]] TPosGS TPosSG

    foreach nt $ListePDB {
	if {! [info exists Sequences($nt)]} {continue}

	lassign $nt n tmp
	set n [BonNomPDB $n]
	set TPosSG [dict remove $TPosSG $n]
	set TPosGS [dict remove $TPosGS $n]

	set mol [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set sp [$mol _resnumber -chain $chn -polymer]
	set sg [set Sequences($n)]
	set lgg [llength $sp]

	dict set TPosSG $n lgt $lgg
	dict set TPosGS $n lgt $lgg

	set i -1
	set c -1
	set v 0
	foreach a [split $sg ""] {
	    incr i
	    if {$a ne "."} {
		incr c
		dict set TPosSG $n [set v [lindex $sp $c]] $i
	    }
	    dict set TPosGS $n $i $v
	}
    }

    return
    
    foreach {n seq} [array get Sequences] {
	#set seq [set Sequences($n)]
	set tmp [string map [list Z "" . ""] $seq]
	set lg [string length $tmp]
	dict set TPosSG $n lgt $lg
	dict set TPosGS $n lgt $lg

	set c -1
	set i -1
	foreach a [split $seq ""] {
	    incr i
	    if {$a ne "."} {
		incr c
		dict set TPosSG $n $c $i
	    }
	    dict set TPosGS $n $i $c
	}
    }

    return $i
}


proc DefinitTypeSeq {seq} {
    set seq [string map {"\." "" "\n" "" "Z" "" " " "" "X" ""} $seq]
    set Lseq [string length $seq]
    set No [regsub -all "O"  $seq "" seq]
    set Lwat [string length $seq]
    
    if {$Lwat == 0} {
	return "Water"
    }
    
    # Nucleic Acid ?
    set seq [string map {"A" "" "C" "" "G" "" "T" "" "U" "" "N" ""} $seq]
    set Lnuc [string length $seq]
    set water [expr {double($Lwat)/$Lseq}]
    set ratio [expr {double($Lnuc)/$Lseq}]
    
    if {$water < 0.15} {
	return "ligand"
    }
    
    if {$ratio < 0.15} {
	return "DNA"
    } else {
	return "Protein"
    }
}


proc DefinitTypeAlignement {} {
    global Sequences LNOrdali TypeSeq ListeDesSimilarites ListeDesAcidesAmines

    if {[info exists TypeSeq]} {return}

    set seq ""
    foreach s $LNOrdali {
	# empty names : group separators (ORD file)
	if {[string trim $s] eq ""} {continue}
	if {[string trim [set Sequences($s)]] ne ""} {
	    append seq [set Sequences($s)]
	}
    }

    set rep [DefinitTypeSeq $seq]
    if {$rep eq "DNA"} {
	set TypeSeq "DNA"
	set ListeDesAcidesAmines {A C G T U N Z}
	set ListeDesSimilarites {1 2 3 4 5 6 Z}
    } elseif {$rep eq "Protein"} {
	set TypeSeq "Protein"
	# liste acides amines de Clustal
	set ListeDesAcidesAmines {A B C D E F G H I K L M N P Q R S T V W X Y Z}
	#set ListeDesAcidesAmines {A C D E F G H I K L M N P Q R S T V W Y Z}
	set ListeDesSimilarites {1 2 3 4 5 6 Z}
    } else {set TypeSeq "Unknown"}

    # Protein
    # 1 =  A,I,L,M,V
    # 2 =  P,A,G,S,T
    # 3 =  D,E,Q,N
    # 4 =  F,Y,W
    # 5 =  K,R,H
    # 6 =  C
    #   Z si sequence manquante

    return
}



proc TypeSeq {} {
    return $::TypeSeq
}


proc InitSequences {} {
    global Defauts LNOrdali LSOrdali Sequences
    global SeqOri LesNomsDesSeqOri
    global NombreDeSequences LongueurTotale
    global OrdEtcDir Warn PBV PBW
    global LesPCI ListeDesFragments
    global ListePDB BadPDB NomEtSeqAssPDB
    
    if {[set Defauts(RemoveQuery)]} {
	set iquery [lsearch -regexp -nocase $LNOrdali "query"]
	if {$iquery != -1} {
	    set Qry [lindex $LNOrdali $iquery]
	    unset Sequences($Qry)
	    set LNOrdali [lreplace $LNOrdali $iquery $iquery]
	}
    }

    # sequences doublonnees ...
    set Luni [lsort -unique $LNOrdali]
    if {[llength $LNOrdali] != [llength $Luni]} {
	set Msg "Warning !\nMultiple copies of some same sequences :\n"
	set Lden [DenombreLaListe $LNOrdali]
	foreach en $Lden {
	    lassign $en e n
	    if {$n > 1} {
		append Msg "  --> $e\n"
	    } else {
		break
	    }
	}
	append Msg "Please remove duplicated sequences and start again !"
	FaireLire $Msg

	return 0
    }
    
    # Cleaning Nom and sequences
    set ListePDB {}
    set PBV 0.
    set PBW "Cleaning Sequences and Names ..."
    set Ns [llength $LNOrdali]
    set LiVide {}
    set i 0
    foreach n $LNOrdali {
	set s [set Sequences($n)]
	set s [BonneSequencePourAlignement $s]
	set Sequences($n) $s

	set nogap [string map {"." "" " " "" "~" "" "-" ""} $s]
	if {! [string length $nogap]} {
	    lappend Warn(Vide) $n
	    set Warn($n) 1
	    lappend LiVide $i
	}
	incr i
	set PBV [expr {$PBV+100./$Ns}]
    }

    # Remove empty sequences
    foreach i [lsort -integer -decreasing $LiVide] {
	set n [lindex $LNOrdali $i]
	set LNOrdali [lreplace $LNOrdali $i $i]
	unset Sequences($n)
    }

    set NombreDeSequences [llength $LNOrdali]
    if {! $NombreDeSequences} {
	return 0
    }
        
    DefinitTypeAlignement
    # residues colors : the ones chosen in the Preferences
    LesDefauts Mapping [MappingDuType]

    DonneMemeLongueur Sequences
    foreach n $LNOrdali {
	lappend LSOrdali [set Sequences($n)]
    }
    lappend LNOrdali {}
    lappend LSOrdali {}

    #
    # Traitement PDB
    #
    set BadPDB {}
    TraitePDBDeLAlignement

    # traite AA bizarres (Seleno Cysteine, B et Z)
    TraiteAABizarres

    # Info generales sur alignement
    set NombreDeSequences [expr {[llength $LNOrdali] - 1}]
    set Premiere [lindex $LNOrdali 0]
    set LongueurTotale [string length [set Sequences($Premiere)]]
    set NPDB [llength $ListePDB]

    array set SeqOri [array get Sequences]
    set LesNomsDesSeqOri $LNOrdali

    # Determine fragments
    if {! $::Defauts(IsGenome)} {
	set ListeDesFragments [DetermineLesFragmentsLuc]
	if {$ListeDesFragments != ""} {
	    MetDesZDansSequencesDeFragments
	}
    }
    
    InfosDesPDB
    
    # not implemented yet ...
    AssigneLesPoids
    
    if {! $Defauts(IsGenome)} {
	CalculeLength
	CalculeComposition
	CalculePI
	CalculeMolecularWeight
    }
    
    WarningsDesSeqs
	
    return 1
}


proc WarningsDesSeqs {} {
    global Warn

    if {! [info exists Warn]} {
	return
    }
    foreach e [array names Warn] {
	switch $e {
	    "B" {
		FaireLire "There are B amino acids (stands for D or N) in the sequence of :\n[join [set Warn(B)] ","]\nSome computations won't be available !"
		AuLog @begin warning
		AuLog @title Warning : B amino acids
		AuLog @text "There are B amino acids (stands for D or N) in the sequence of :\n[join [set Warn(B)] ","]\nSome computations won't be available !"
		AuLog @end
	    }
	    "Z" {
		FaireLire "There are Z amino acids (stands for E or Q) in the sequence of :\n[join [set Warn(Z)] ","]\nSome computations won't be available !"
		AuLog @begin warning
		AuLog @title Warning : Z amino acids
		AuLog @text "There are Z amino acids (stands for E or Q) in the sequence of :\n[join [set Warn(Z)] ","]\nSome computations won't be available !"
		AuLog @end
	    }
	    "J" {
		FaireLire "There are J amino acids (stands for L or I) in the sequence of :\n[join [set Warn(J)] ","]\nSome computations won't be available !"
		AuLog @begin warning
		AuLog @title Warning : J amino acids
		AuLog @text "There are J amino acids (stands for L or I) in the sequence of :\n[join [set Warn(J)] ","]\nSome computations won't be available !"
		AuLog @end
	    }
	    "O" {
		FaireLire "There are unknown amino acids (O) in the sequence of :\n[join [set Warn(O)] ","]\nSome computations won't be available !"
		AuLog @begin warning
		AuLog @title Warning : unknown amino acids
		AuLog @text "There are unknown amino acids (O) in the sequence of :\n[join [set Warn(O)] ","]\nSome computations won't be available !"
		AuLog @end
	    }
	    "U" {
		if {[ModeI]} {
		    set choix [tk_dialog .uwarn "Warning" "There are seleno-cysteins (U) residues in the sequence of :\n[join [set Warn(U)] ","]\nSome computations won't be available if you keep them.\nDo you want to replace them with C (Cys) ?" "" 0 " Yes " " No "]
		} else {
		    set choix 1
		}
		AuLog @begin warning
		AuLog @title Warning : seleno-cystein amino acids
		if {$choix} {
		    ChangeSelenoC2C
		    AuLog @text "There are seleno-cystein amino acids (U) in the sequence of :\n[join [set Warn(U)] ","]\nThey have been replaced by cysteins (C)"
		} else {
		    AuLog @text "There are seleno-cystein amino acids (U) in the sequence of :\n[join [set Warn(U)] ","]\nSome computations won't be available !"
		}
		AuLog @end
	    }
	    "Numbers" {
		FaireLire "There are numbers (0-9) in the sequence of :\n[join [set Warn(Numbers)] ","]\nSome computations won't be available !"
		AuLog @title Warning : numbers in sequence
		AuLog @text "There are numbers [0-9] in the sequence of :\n[join [set Warn(Numbers)] ","]\nSome computations won't be available !"
		AuLog @end
	    }
	    "BadPdb" {
		FaireLire "Can't download the following PDB entries from servers :\n[join [set Warn(BadPdb)] ","]\n"
		AuLog @title Warning : problems downloading PDB
		AuLog @text "Can't download the following PDB entries from servers :\n[join [set Warn(BadPdb)] ","]\n"
		AuLog @end
	    }
	    "ChnPdb" {
		FaireLire "Can't find the requested chain in the following PDB entries:\n[join [set Warn(ChnPdb)] ","]\n"
	    }
	    "Vide" {
		FaireLire "The following sequences names do not contain any amino acid sequences :\n[join [set Warn(Vide)] ","].\nThey will be discarded from the alignment."
		AuLog @title Warning : empty sequences
		AuLog @text "The following sequences names do not contain any amino acid sequences :\n[join [set Warn(Vide)] ","].\nThey will be discarded from the alignment."
		AuLog @end
	    }
	}
    }

    return
}


proc ChangeSelenoC2C {} {
    global LNOrdali LSOrdali Sequences

    set LSOrdali {}
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}
	set s [set Sequences($n)]
	set s [string map [list U C] $s]
	lappend LSOrdali $s
	set Sequences($n) $s
    }

    return
}


proc ExisteAABizarres {nseq} {
    set ya 0
    if {[info exists ::Warn($nseq)] && $::Warn($nseq)} {
	return 1
    } else {
	return 0
    }
}


proc TraiteAABizarres {{force 0}} {
    global Sequences Warn

    foreach n [array names Sequences] {
	set s [set Sequences($n)]
	if {! [info exists Warn($n)] || $force} {
	    set val 0
	    switch -regexp $s {
		{B} {
		    set val 1
		    lappend Warn(B) $n
		}
		{Z} {
		    set val 1
		    lappend Warn(Z) $n
		}
		{U} {
		    set val 1
		    lappend Warn(U) $n
		}
		{X} {
		    set val 1
		    lappend Warn(X) $n
		}
		{J} {
		    set val 1
		    lappend Warn(J) $n
		}
		{O} {
		    set val 1
		    lappend Warn(O) $n
		}
		{[0-9]} {
		    set val 1
		    lappend Warn(Numbers) $n
		}
		{[^a-zA-Z0-9\.-]} {
		    set val 1
		    set Warn(Unknown) $n
		}
	    }
	    set Warn($n) $val
	}
    }

    return
}



proc AssigneLePoidsDesSeqs {} {
    global LePoidsDesSeqs IdXml LesPoidsDesSequences FichierXML FichierMSF LNOrdali
    
    set LePoidsDesSeqs {}
    if {[info exists FichierMSF]} {
	LitLesPoidsDuMSF $FichierMSF
	foreach n $LNOrdali {
	    if {[string trim $n] eq ""} {
		continue
	    }
	    set p [set LesPoidsDesSequences($n)]
	    lappend LePoidsDesSeqs $p
	}
    }
    if {[info exists FichierXML]} {
	ExtraitLesPoidsDuXML $IdXml LePoidsDesSeqs
    }

    return
}


proc CorrespondanceGenSeq {mol x} {
    # ATTENTION ! On considere ici numerotation 
    # commence a 0 !

    set seq [string map [list "." "" "Z" ""] [string range [set ::Sequences($mol)] 0 $x]]

    return [expr {[string length $seq] -1}]
}


proc CorrespondanceSeqGen {mol x} {
    # ATTENTION ! On considere ici numerotation 
    # commence a 0 !

    set seq [set ::Sequences($mol)]
    set seq [string map [list "Z" "."] $seq]
    set tmp [string map [list "." ""]  $seq]
    set lsd [string length $tmp]
    if {$x >= $lsd} {
	return [expr {[string length [string trimright $seq "."]] - 1}]
    }

    set c -1
    set i -1
    foreach a [split $seq ""] {
	incr i
	if {$a eq "."} {continue}
	incr c
	if {$c >= $x} {return $i}
    }

    return $i
}


proc CorrespondancePDBGen {molid x} {
    # Renvoie position generale commencant a 0 !

    set molid [BonAccess $molid]
    set mol [DonneIdDeAccessPDB $molid]
    set chn [DonneChainDeAccessPDB $molid]
    if {$chn eq ""} {set chn "a"}

    set seq [set ::Sequences($molid)]
    set seq [string map [list Z .] $seq]
    set IdxPrem [lsearch [$mol _resnumber -chain $chn -polymer] $x]

    set i -1
    set cpt -1
    set Lc [split $seq ""]
    foreach a $Lc {
	incr i
	if {$a eq "."} {continue}
	incr cpt
	if {$cpt == $IdxPrem} {
	    break
	}
    }

    return $i
}


proc CorrespondanceGenPDB {molid x} {
    # position generale commence a 0

    set molid [BonAccess $molid]
    set mol [DonneIdDeAccessPDB $molid]
    set chn [DonneChainDeAccessPDB $molid]
    if {$chn eq ""} {set chn "a"}

    set seq [set ::Sequences($molid)]
    set s1 [string map [list "Z" "" "." "" " " ""] [string range $seq 0 $x]]
    if {$s1 eq ""} {
	set b1 0
    } else {
	set long1 [expr {[string length $s1] -1}]
	set b1 [lindex [$mol _resnumber -chain $chn -polymer] $long1]
    }

    return $b1
}


proc CorrespondanceAliPDB {molid x1 x2 seqass seqali} {

    set chn [DonneChainDeAccessPDB $molid]
    set mol [DonneIdDeAccessPDB $molid]

    global PDB_[set mol]_Sequence
    global PDB_[set mol]_NmrRes

    regsub -all {\.} [string range $seqali 0 $x1] "" str1
    set long1 [expr {[string length $str1] -1}]
    set b1 [lindex [set PDB_[set mol]_NmrRes($chn)] $long1]

    regsub -all {\.} [string range $seqali 0 $x2] "" str2
    set long2 [expr {[string length $str2] -1}]
    set b2 [lindex [set PDB_[set mol]_NmrRes($chn)] $long2]

    if {$b1 == ""} {set b1 -9999}
    if {$b2 == ""} {set b2 -9999}

    set lgth [expr {$b2 - $b1}]

    return [list $b1 $b2 $lgth]
}



proc CorrespondancePDBAli {MolId Chn Dep Fin SeqAlignee} {

    global PDB_[set MolId]_NmrRes

    set IdxPrem [lsearch [set PDB_[set MolId]_NmrRes($Chn)] $Dep]
    set IdxDern [lsearch [set PDB_[set MolId]_NmrRes($Chn)] $Fin]

    # Cherche correspondance entre no residus PDB et positions de
    # l'alignement global

    incr IdxPrem
    incr IdxDern

    set DebAli -9999
    set FinAli -9999
    set i -1
    set cpt 0
    regsub -all "Z" $SeqAlignee "." seq

    set Lc [split $seq ""]
    foreach a $Lc {
	incr i
	if {$a eq "."} {continue}
	incr cpt
	if {$cpt == $IdxPrem} {set DebAli $i}
	if {$cpt == $IdxDern} {
	    set FinAli $i
	    break
	}
    }

    return [list $DebAli $FinAli]
}



proc EquivPosGenPosSeq pxy {

    global NomNomSeq
    global NomTextSeq
    global NomEtSeqAssPDB
    global Sequences

    lassign [split [$NomTextSeq index $pxy] "."] y x 
    set noms [string trim [$NomNomSeq get $y.0 "$y.0 lineend"]]
    set nomstatus $noms

    if {[regexp "PDB_" $noms]} {
	# recherche seq attachee au pdb. C'est la premiere non-odb
	# en remontant la liste
	set mol [string range $noms 4 7]
	set ny [expr {$y-1}]
	set tst [string range [$NomNomSeq get $ny.0 "$ny.0 lineend"] 0 3]
	while {$tst eq "PDB_"} {
	    incr ny -1
	    set tst [string range [$NomNomSeq get $ny.0 "$ny.0 lineend"] 0 3]
	}
	set idx [lsearch -regexp $NomEtSeqAssPDB $mol]
	set n [lindex $NomEtSeqAssPDB $idx]
	scan $n "%s %s %s" PDBin NmSeqAss MolId
	set chn [string index $MolId 5]
	global PDB_[set mol]_SecStr
	global PDB_[set mol]_Sequence
	set SeqAss [set Sequences($NmSeqAss)]
	set SeqAlignee [lindex [set PDB_[set mol]_Sequence($chn)] 1]
	set nomsqas [lindex $LesNom $ny]
	set SeqAss [lindex $LesSeq $ny]

	set cxseq [CorrespondanceAliPDB $MolId $x $x $SeqAss $SeqAlignee]
	scan $cxseq "%d %s %s" xseq tmp tmp1
    } else {
	set s [string range [lindex $LesSeq [expr {$y-1}]] 0 $x]
	regsub -all {\.} $s "" lsp
	regsub -all " " $lsp "" lnet
	set xseq [string length $lnet]
    }

    return [list $x $xseq]
}


proc AutreCodeLuc {X} {
    if {! [info exists ::AutreCodeLuc]} {
	InitCode3l1l
    }

    set X [string toupper $X]
    if {[info exists ::AutreCodeLuc($X)]} {
	return [set ::AutreCodeLuc($X)]
    } else {
	set n [string length $X]
	switch $n {
	    1 {return "XXX"}
	    3 {return "X"}
	}
    }
}


proc NombreDeZDuPilier Pilana {
    return [regsub -all "Z" $Pilana "" bidon]
}


proc SeqsDuPilier {NmGrp} {
    # sequences of a pillar of group NmGrp, in its order : the PDB
    # sequences are not in the pillars unless PDBDansPilier (see
    # CreeLesPiliers)
    global SDG ListePDB Defauts

    if {[info exists Defauts(PDBDansPilier)] && $Defauts(PDBDansPilier)} {
	return $SDG($NmGrp)
    }
    if {! [info exists ListePDB]} {
	return $SDG($NmGrp)
    }

    return [lmap n $SDG($NmGrp) {expr {$n in $ListePDB ? [continue] : $n}}]
}


proc CalculePoidsDuPilier2 {Pilier Laa NmGrp Seuil} {
    global SDG LNDG Sequences LesPoidsDesSequences

    set Lc [split $Pilier ""]
    set poids 0.
    foreach s [SeqsDuPilier $NmGrp] c $Lc {
	if {$c in $Laa} {
	    set poids [expr {$poids + [set LesPoidsDesSequences($s)]}]
	}
    }

    if {$poids >= $Seuil} {
	return 1
    } else {
	return 0
    }
}


proc CalculePoidsDuPilier {pilier nmgrp} {
    global LesPoidsDesSequences
    global Sequences
    global LNDG
    global SDG

    set poids 0.
    set i 0
    foreach s [set SDG($nmgrp)] {
	if {[regexp {[0-9]} [string index $pilier $i]]} {
	    set poids [expr {$poids + [set LesPoidsDesSequences($s)]}]
	}
	incr i
    }

    return $poids
}


proc CalculeLesSeuils {pilier {nmgrp ""} {thr ""}} {
    global Threshold ListeDesPiliersDuGroupe SDG LNDG Sequences LNOrdali LesPoidsDesSequences

    set PoidsTotal 0.

    if {$thr eq ""} {
	set thr [expr {double($Threshold)/100.}]
    } else {
	set thr [expr {double($thr)/100.}]
    }
    if {$nmgrp eq ""} {set nmgrp "GroupeToutLeMonde"}

    set i 0
    set Lc [split $pilier ""]
    foreach s [SeqsDuPilier $nmgrp] c $Lc {
	if {$c eq "Z"} {continue}
	set PoidsTotal [expr {$PoidsTotal+[set LesPoidsDesSequences($s)]}]
	incr i
    }

    if {$i > 1} {
	set seuil [expr {floor($thr*$PoidsTotal)}]
    } else {
	set seuil -1.
    }

    return $seuil
}


proc DonneCompositionDe {n {s ""}} {
    if {$s eq ""} {
	set i [lsearch $::LNOrdali $n]
	set s [lindex $::LSOrdali $i]
    }
    set s [string map [list "-" "" "Z" "" "X" "" "." ""] $s]

    set ln [string length $s]
    if {! $ln} {return ""}
    foreach a {A C D E F G H I K L M N P Q R S T V W Y} {
	set pa [expr {100.*([string length $s] - [string length [string map [list $a ""] $s]])/$ln}]
	lappend Lf $pa
    }

    return $Lf
}


proc DonnePhysicoChimieDe {n {s ""}} {
    if {$s eq ""} {
	set i [lsearch $::LNOrdali $n]
	set s [lindex $::LSOrdali $i]
    }
    set s [string map [list "-" "" "Z" "" "X" "" "." ""] $s]

    set ln [string length $s]
    if {! $ln} {return ""}
    foreach a {"A|I|L|M|V" "K|R|H" "D|E|Q|N" "F|Y|W" "P|G|S|T"} {
	set pa [expr {100.*[regsub -all "$a" $s "" s]/$ln}]
	lappend Lf $pa
    }

    return $Lf
}


proc CalculeComposition {{force 0}} {
    global TDesCompos LNOrdali LSOrdali

    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}

	if {! [info exists TDesCompos($n,aa)] || $force} {
	    set TDesCompos($n,aa) [DonneCompositionDe $n]
	    set TDesCompos($n,pc) [DonnePhysicoChimieDe $n]
	}
    }

    return
}


proc LogLesCompositions {} {
    global LNOrdali LSOrdali TDesCompos

    if {! [info exists TDesCompos]} {
	return
    }

    AuLog @begin table
    AuLog @title AminoAcid Composition :
    set Ln [PlusLongEltDe $LNOrdali]
    AuLog @begin tabular
    AuLog @titlecols Protein A C D E F G H I K L M N P Q R S T V W Y
    AuLog @typecols T R R R R R R R R R R R R R R R R R R R R
    foreach s $LNOrdali {
	if {[string trim $s] eq ""} {continue}
	
	set ligne "$s"
	foreach v [set TDesCompos($s,aa)] {
	    #append ligne " [format "%5.2f" $v]"
	    lappend ligne [format %5.2f $v]
	}
	AuLog @row {*}$ligne
    }
    AuLog @end

    AuLog @title Physico-chemical Composition :
    AuLog @begin tabular
    AuLog @titlecols Protein AILMV PGST FYW KRH DEQN
    AuLog @typecols T R R R R R
    foreach s $LNOrdali {
	if {[string trim $s] eq ""} {continue}
	set ligne $s
	foreach v [set TDesCompos($s,pc)] {
	    #append ligne " [format "%5.2f" $v]"
	    lappend ligne [format %5.2f $v]
	}
	AuLog @row {*}$ligne
    }
    AuLog @end
    AuLog @end

    return
}


proc PIAuPH {AspN GluN CysN TyrN HisN LysN ArgN pH} {
    # Valeurs de pK prises dans EMBOSS (fichier emboss/data/Epk.dat)
    # les valeurs commentees correspondent aux valeurs donnees par wikipedia.

    #C-terminal charge
    set QN1 [expr {-1./(1+pow(10,(3.6-$pH)))}]

    #D charge
    set QN2 [expr {-$AspN/(1+pow(10,(3.9-$pH)))}]

    #E charge
    # set QN3 [expr {-$GluN/(1+pow(10,(4.07-$pH)))}]
    set QN3 [expr {-$GluN/(1+pow(10,(4.1-$pH)))}]

    #C charge
    # set QN4 [expr {-$CysN/(1+pow(10,(8.18-$pH)))}]
    set QN4 [expr {-$CysN/(1+pow(10,(8.5-$pH)))}]

    #Y charge
    # set QN5 [expr {-$TyrN/(1+pow(10,(10.46-$pH)))}]
    set QN5 [expr {-$TyrN/(1+pow(10,(10.1-$pH)))}]

    #H charge
    # set QP1 [expr {$HisN/(1+pow(10,($pH-6.04)))}]
    set QP1 [expr {$HisN/(1+pow(10,($pH-6.5)))}]

    #N terminal
    # set QP2 [expr {1./(1+pow(10,($pH-8.2)))}]
    set QP2 [expr {1/(1.+pow(10,($pH-8.6)))}]

    #K charge
    # set QP3 [expr {$LysN/(1+pow(10,($pH-10.54)))}]
    set QP3 [expr {$LysN/(1+pow(10,($pH-10.8)))}]

    #R charge
    # set QP4 [expr {$ArgN/(1+pow(10,($pH-12.48)))}]
    set QP4 [expr {$ArgN/(1+pow(10,($pH-12.5)))}]

    set NQ [expr {$QN1+$QN2+$QN3+$QN4+$QN5+$QP1+$QP2+$QP3+$QP4}]

    return $NQ
}


proc DonnePIDe {n {s ""}} {
    if {$s eq ""} {
	set i [lsearch $::LNOrdali $n]
	set s [lindex $::LSOrdali $i]
    }

    set AspN [regsub -all "D" $s "" tmp]
    set GluN [regsub -all "E" $s "" tmp]
    set CysN [regsub -all "C" $s "" tmp]
    set TyrN [regsub -all "Y" $s "" tmp]
    set HisN [regsub -all "H" $s "" tmp]
    set LysN [regsub -all "K" $s "" tmp]
    set ArgN [regsub -all "R" $s "" tmp]

    set pH 6.5
    set pHprev  0.0
    set pHnext 14.0
    set X 0.0
    set E 0.01
    set temp 0.0
    while {1} {
	set NQ [PIAuPH $AspN $GluN $CysN $TyrN $HisN $LysN $ArgN $pH]
	if {$pH > 14.0} {
	    set NQ -999.
	    FaireLire "Something went wrong while computin\npI for $n !"
	    break
	}

	if {$NQ<0} {
	    set temp $pH
	    set pH [expr {$pH-(($pH-$pHprev)/2)}]
	    set pHnext $temp
	} else {
	    set temp $pH
	    set pH [expr {$pH+(($pHnext-$pH)/2)}]
	    set pHprev $temp
	}

	if {$pH-$pHprev<$E && $pHnext-$pH<$E} {
	    break
	}
    }

    return $pH
}


proc CalculeLength {} {
    global Sequences TDesLength
    
    foreach k [array names Sequences] {
	set s [string map {"." "" - "" ~ ""} $Sequences($k)]
	set TDesLength($k) [string length $s]
    }

    return
}


proc CalculePI {{force 0}} {
    global LNOrdali LSOrdali TDespI

    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}
	if {! [info exists TDespI($n)] || $force} {
	    set TDespI($n) [DonnePIDe $n]
	}
    }

    return
}


proc DonneMolWeightDe {s} {
    global TMassesAA

    if {! [info exists TMassesAA]} {InitMasses}

    set s [string map [list "." "" "Z" ""] $s]
    set M 0.0
    foreach a [split $s ""] {
	if {[info exists TMassesAA($a)]} {
	    set M [expr {$M + [set TMassesAA($a)]}]
	}
    }
    set M [expr {$M + [set TMassesAA(H2O)]}]

    return $M
}


proc DonneHydrophobicityDe {s} {
    global THydroAA

    # ungap sequence
    set s [string map {"." "" " " ""} $s]
    set h 0
    foreach a [split $s ""] {
	set h [expr {$h + [set THydroAA($a)]}]
    }
    
    return [expr {$h/[string length $s]}]
}


proc CalculeMolecularWeight {{force 0}} {
    global LNOrdali LSOrdali TMassesAA TDesMolW

    if {! [info exists TMassesAA]} {
	InitMasses
    }

    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}
	
	if {! [info exists TDesMolW($n)] || $force} {
	    if {! [ExisteAABizarres $n]} {
		set M [DonneMolWeightDe $s]
	    } else {
		set M 0.0
	    }
	    set TDesMolW($n) $M
	}
    }

    return
}


proc CalculeHydrophobicity {{force 0}} {
    global LNOrdali LSOrdali THydroAA TDesHydro

    if {! [info exists THydroAA]} {
	InitHydrophobicityAA
    }

    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}

	if {! [info exists TDesHydro($n)] || $force} {
	    if {! [ExisteAABizarres $n]} {
		set M [DonneHydrophobicityDe $s]
	    } else {
		set M 0.0
	    }
	    set TDesHydro($n) $M
	}
    }

    return
}





proc LogSeqInfoGlobales {} {
    global LNOrdali LSOrdali LongueurTotale NombreDeSequences ListePDB ListeDesFragments AlnScore TDesAccess TDespI TDesMolW TDesHydro Defauts

    AuLog @begin blob
    AuLog @title General Information :
    AuLog @begin teletype
    if {! [info exists AlnScore]} {
	set AlnScore 0.0
    }
    AuLog @tele Alignment score .........: [set AlnScore]
    AuLog @tele Alignment length ........: $LongueurTotale
    AuLog @tele Number of sequences .....: $NombreDeSequences
    AuLog @tele Number of PDB sequences .: [llength $ListePDB]
    if {! $::Defauts(IsGenome)} {
	AuLog @tele Number of fragments .....: [llength $ListeDesFragments]
    }
    AuLog @end
    AuLog @end
    
    if {$Defauts(IsGenome)} {
	return
    }

    set pl [PlusLongEltDe $LNOrdali]
    AuLog @begin table
    AuLog @title Global information on proteins
    
    set lmin 9999999. ; set lmax -99999.
    foreach n $LNOrdali s $LSOrdali {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}
	    
	set s [string map {"." "" "Z" ""} $s]
	set l [string length $s]
	if {$l > $lmax} {
	    set lmax $l
	    set nmax $n
	    set amax [set TDesAccess($n)]
	}
	if {$l < $lmin} {
	    set lmin $l
	    set nmin $n
	    set amin [set TDesAccess($n)]
	}
    }
    AuLog @subtitle Length min : $lmin $nmin $amin
    AuLog @subtitle Lenght max : $lmax $nmax $amax

    AuLog @begin tabular
    AuLog @titlecols {Seq. Name} Accession Length MOlW pI Hydrophobicity
    AuLog @typecols T T I R R R
    foreach n $LNOrdali s $LSOrdali {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}

	set ac [set TDesAccess($n)]
	set s [string map [list "." "" "Z" ""] $s]
	set l [string length $s]
	AuLog @row $n $ac $l [format %.3f [set TDesMolW($n)]] [format %6.3f [set TDespI($n)]] [format %6.3f [set TDesHydro($n)]]
    }
    AuLog @end

    if {[llength $ListeDesFragments]} {
	AuLog @begin blob
	AuLog @title List of Fragments :
	AuLog @list $ListeDesFragments
	AuLog @end
    }

    AuLog @end

    return
}


proc DetruitInfoSeqs {} {
    global {*}[info globals "TD*"]

    unset -nocomplain {*}[info globals "TD*"]
    update

    return
}


proc CopyFullSequenceData {old new} {
    global {*}[info globals "TD*"] Sequences SDG TabSF
    
    # infos sequence
    foreach t [info globals "TD*"] {
	set ${t}($new) [set ${t}($old)]
    }

    # features
    foreach k [array names TabSF "$old,*"] {
	lassign [split $k ,] tmp key
	set TabSF($new,$key) [set TabSF($k)]
    }

    # groups
    foreach g [array names SDG] {
	if {$old in [set SDG($g)]} {
	    lappend SDG($g) $new
	}
    }

    # sequences
    set Sequences($new) [set Sequences($old)]

    return
}


proc CopySequenceData {old new} {
    global {*}[info globals "TD*"] TabSF

    foreach t [info globals "TD*"] {
	if {$t eq "TDesPCI"} {continue}

	set ${t}($new) [set ${t}($old)]
    }
    set TDesCompos(${new},aa) [set TDesCompos(${old},aa)]
    set TDesCompos(${new},pc) [set TDesCompos(${old},pc)]

    # Features
    foreach k [array names TabSF "$old,*"] {
	lassign [split $k ,] tmp key
	set TabSF($new,$key) [set TabSF($k)]
    }

    return
}


proc InitInfoArrays {} {
    global TDesHydro TDesSeqnames TDesSeqnamesOri TDespI TDesAccess TDesPhylum TDesGO TDesGS TDuLineage TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesBId TDesDescriptifs TDesMolW TDesStatus TDesSense TDesScore TDesScore TDesLength

    foreach t {TDesHydro TDesSeqnames TDesSeqnamesOri TDespI TDesAccess TDesPhylum TDesGO TDesGS TDuLineage TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesBId TDesDescriptifs TDesMolW TDesStatus TDesSense TDesScore TDesScore TDesLength} {
	unset -nocomplain $t
	array set $t {}
    }

    return
}


proc InitInfoSeqs {{liste {}}} {
    global {*}[info globals "TD*"] LNOrdali LNSeqlab 

    set Ltab [info globals "TD*"]
    if {$liste == {}} {
	if {! [InSeqlabMode]} {
	    set liste $LNOrdali
	} else {
	    set liste $LNSeqlab
	}
    }

    array set Tid {}
    foreach n $liste {
	set n [string trim $n]
	if {$n eq ""} {continue}

	foreach t $Ltab {
	    if {! [info exists ${t}($n)]} {
		if {$t eq "TDesFragment" || $t eq "TDesComplex" || $t eq "TDesTaxId"} {
		    set v 0
		} elseif {$t eq "TDesHydro" || $t eq "TDesMolW" || $t eq "TDespI"} {
		    set v 0.0
		} elseif {$t eq "TDesAccess" || $t eq "TDesSeqnames" || $t eq "TDesBId"} {
		    set v $n
		} elseif {$t eq "TDesOrganismes"} {
		    set v "Unknown"
		} else {
		    set v ""
		}
		set ${t}($n) $v
	    }
	}

	if {[set TDesOrganismes($n)] eq ""} {
	    set id [set TDesTaxId($n)]
	    if {[string is integer -strict $id] && $id > 0} {
		lappend Tid(Lid) $id
		lappend Tid(Ln)  $n
	    }
	}
    }
    
    if {[array names Tid] != {} } {
	array set Tres [eSummaryREST taxonomy $Tid(Lid)]
	foreach id $Tid(Lid) n $Tid(Ln) {
	    if {[info exists Tres($id,ScientificName)]} {
		set TDesOrganismes($n) [set Tres($id,ScientificName)]
	    }
	}
    }

    update

    return
}


proc SeqGCGCheckSum {s} {
    if {$s eq ""} {return -1}
    set i 0
    set check 0
    foreach c [split $s ""] {
	scan $c %c n
	set check [expr {$check+(($i % 57)+1) * $n}]
	incr i
    }
    
    return [expr {$check % 10000}]
}


proc MetAJourListePDB {} {
    # sequences of the current instance with a loaded structure : instances
    # of an ORD file differ, and AlphaFold names (Q9BW92_A) are not PDB accesses
    global ListePDB HashPDB LNOrdali

    # file being opened, first one or after FermeFichier (which empties
    # ListePDB and removes HashPDB) : done by TraitePDBDeLAlignement
    if {! [info exists ListePDB] || ! [info exists HashPDB(iHmax)]} {
	return
    }

    # the code reads Sequences() of each name of ListePDB
    set Lnoms [lmap n $LNOrdali {string trim $n}]
    set ListePDB [lmap e $ListePDB {expr {$e in $Lnoms ? $e : [continue]}}]

    set Lopdb [info class instances Structure]
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n eq "" || $n in $ListePDB} {
	    continue
	}
	set mol [DonneIdDeAccessPDB $n]
	if {"::$mol" ni $Lopdb || [DonneChainDeAccessPDB $n] ni [$mol _chains]} {
	    continue
	}
	lappend ListePDB $n
	# as InfosDesPDB does for the instance displayed at opening
	$mol PDBInfos [DonneChainDeAccessPDB $n]
	if {! [info exists HashPDB($mol)]} {
	    set iH $HashPDB(iHmax)
	    set HashPDB($mol) $iH
	    set HashPDB($iH) $mol
	    set HashPDB(iHmax) [incr iH]
	}
    }

    return
}


proc LoadNewStructure {IdOrFile {strID ""} {initFromDB 0} {storeInDB 1}} {
    global HashPDB ListePDB Warn
    
    # IdOrFile can be :
    # - anID
    # - list of lines, text
    # - a file
    set isFile [file exists $IdOrFile]
    set isID [expr {[EstUnAccessPDB $IdOrFile] || [EstUnUniProt $IdOrFile]}]
    set isListText [expr {([llength $IdOrFile] > 1) || ([string first "\n" $IdOrFile] > -1)}]
    if {! $isFile && ! $isID && ! $isListText} {
	set cok [list Error "Bad argument"]
	return $cok
    }

    # if strID is empty,then the ID should be taken either directly from IdOrFile 
    # or within file designated by IdOrFile.
    if {$strID eq ""} {
	if {$isID} {
	    set strID $IdOrFile
	} else {
	    # is file or list or text
	    set strID TMPSTR
	}
    } else {
	# strID is not null
    }
    if {"$strID" in [info commands]} {
	# already loaded (for an other instance) : it may not be in
	# HashPDB, which only holds the structures of the instance
	# displayed at opening
	if {! [info exists HashPDB(iHmax)]} {
	    set HashPDB(iHmax) 0
	}
	if {! [info exists HashPDB($strID)]} {
	    set iH $HashPDB(iHmax)
	    set HashPDB($strID) $iH
	    set HashPDB($iH) $strID
	    set HashPDB(iHmax) [incr iH]
	}
	return [list StrucID $strID]
    }

    Structure create $strID
    set cok [$strID new $IdOrFile "" $initFromDB $storeInDB]
    lassign $cok what desc
    if {$what eq "Error"} {
	lappend Warn(BadPdb) $strID
	set Warn($strID) 1
	$strID destroy
	update
	
	return $cok
    }
    
    # Obsolete
    if {$what in {"Obsolete" "Superseeded"}} {
	lassign $desc oldid newid
	if {$newid eq ""} {
	    # The entry is definitly removed.
	    lappend Warn(BadPDB) $oldid
	    set Warn($oldid) 1
	    $strID destroy
	    update

	    return  $cok
	}
	
	# Obsolete replaced by newid, check it
	set newcok [LoadNewStructure $newid $newid]
	lassign $newcok newwhat newdesc
	if {$newdesc eq $newid} {
	    #everything's OK, newid will replace old one
	    $strID destroy
	    lappend Warn(Obsolete) [list $oldid $newid]
	    set Warn($oldid) 1
	    set strID $newid
	} else {
	    # Problem with the new ID, keep old one
	    # whatever is strID copy it to oldid
	    $strID CopiePDB $oldid
	    $strID destroy
	    set strID $oldid
	    update
	}
	set cok [list StrucID $strID]
    } else {
	# Everything is OK.
	set cok [list StrucID $strID]
	if {$strID eq "TMPSTR"} {
	    # structure already loaded (added to an other instance) : it
	    # may not be in HashPDB, which only holds the structures of the
	    # instance displayed at opening
	    if {"::$desc" in [info class instances Structure]} {
		$strID destroy
		if {! [info exists HashPDB(iHmax)]} {
		    set HashPDB(iHmax) 0
		}
		if {! [info exists HashPDB($desc)]} {
		    set iH $HashPDB(iHmax)
		    set HashPDB($desc) $iH
		    set HashPDB($iH) $desc
		    set HashPDB(iHmax) [incr iH]
		}
		return [list StrucID $desc]
	    }
	    # see above, 'desc' contains structure ID when all is OK
	    $strID CopiePDB $desc
	    $strID destroy
	    set strID $desc
	    set cok [list StrucID $strID]
	}
    }

    # Record new structure
    if {! [info exists HashPDB]} {
	set HashPDB(iHmax) 0
    }
    set iH $HashPDB(iHmax)
    set HashPDB($strID) $iH
    set HashPDB($iH) $strID
    incr iH
    set HashPDB(iHmax) $iH
    
    return $cok
} 


proc LoadNouveauPDB {IdOrFile {pdbid ""} {init 0} {indb 1}} {
    global HashPDB ListePDB Warn
    #rR depuis 2023/02/13 on rend 0 si ça merde ou le pdbid qui marche ... ou "nouveau superseed the old vieux" 
    #rR  ... et aussi on traite le cif
    #
    # pdbid is ALWAYS in upper-case !
    # only exception is downloading
    set pdbid [string toupper $pdbid]
    if {$pdbid eq ""} {
	set file $IdOrFile
	if {[regexp "\.cif$" $file]} {
	    #rR avec un fichier .cif on prend le pdbid du nom du fichier
	    set FichierCif $file
	    set Queue [file tail $FichierCif]
	    regsub "\.cif$" $Queue "" pdbid
	    set pdbid [string toupper $pdbid] ; #rR A confirmer 
	} elseif {[file exists $file]} {
	    # it is a file, take pdbid from it
	    set tmpName [file tail $file]
	    if {[set idx [string first "\." $tmpName]] > -1} {
		set tmpName [string range $tmpName 0 $idx-1]
	    }
	    set tmpName [BonNomPDB $tmpName]
	    set pdbid [DonneIdDeAccessPDB $tmpName]
	} else {
	    # not a file
	    set pdbid $IdOrFile
	}
    } else {
	# pdbid argument is not null
	set file $IdOrFile
    }

    set pdbid [string toupper $pdbid]
    Structure create $pdbid
    set cok [$pdbid new $file "" $init $indb]

    if {$cok == 0} {
	# Problem : bad pdb ?
	lappend Warn(BadPdb) $pdbid
	set Warn($pdbid) 1
	$pdbid destroy
	update

	return 0
    }

    set Superseed ""
    # Obsolete / superseeded
    if {$cok != 1} {
	lassign $cok what newid
	set newid [string toupper $newid]
	
	if {$what eq "superseeded"} {
	    # superseeded : replaced 
	    set Superseed " superseed the old $pdbid"
	    set cmdId $newid
	    set newid "::$newid"
	    lappend Warn(superseeded) [list $pdbid $cmdId]
	    #rR ATTENTION faut-il detruire le vieux quand même ? 
	    if {$cmdId ni [info commands]} {
		$pdbid CopiePDB $newid
		$pdbid destroy
		set pdbid $newid
	    }
	} else {
	    # obsolete, reload
	    $pdbid destroy
	    lappend Warn(BadPDB) $pdbid
	    set Warn($pdbid) 1
	    return 0
	}
	#rR set cok $pdbid
    }

    # record the new pdbid
    if {[string range $pdbid 0 1] eq "::"} {
	set pdbid [string range $pdbid 2 end]
    }

    if {! [info exists HashPDB]} {
	set HashPDB(iHmax) 0
    }
    set iH $HashPDB(iHmax)
    set HashPDB($pdbid) $iH
    set HashPDB($iH) $pdbid
    incr iH
    set HashPDB(iHmax) $iH
    
    #rR return $cok
    return $pdbid$Superseed     ; #rR 
}


proc AlignRDNA2Prot {p r} {
    # first check length
    set pdg [string map [list "." ""] $p]
    # stop codon
    set Lstop [list tag taa tga TAG TAA TGA]
    if {[string range $r end-2 end] in $Lstop} {
	set r [string range $r 0 end-3]
    }

    # diff of 3 may be due to missing initiaor M
    if {abs( ([string length $pdg]*3) - [string length $r]) == 3} {
	# May be a missing leading M
	if {[string index $p 0] ne "M" && [string range $r 0 2] in [list atg ATG]} {
	    set r [string range $r 3 end]
	}
    }
    if {([string length $pdg]*3) != [string length $r]} {
	puts "PB ! RNA [string length $r] Prot [expr {[string length $pdg]*3}]"
	return ""
    }

    set i 0
    set Lc [split $p ""]
    set al ""
    foreach c $Lc {
	if {$c eq "."} {
	    append al "..."
	} else {
	    append al [string range $r [expr {$i*3}] [expr {$i*3+2}]]
	    incr i
	}
    }

    return $al
}


proc ExtractRNAFromSeqGivenLoc {seq loc} {
    # treat location
    set loc [string trim [string map [list "(" " " ")" " " ">" "" "<" ""] $loc]]
    set cmpt [regexp -nocase "complement" $loc]
    set lloc [split $loc]
    set df [string map [list ".." " "] [lindex $lloc end]]
    lassign [split $df] deb fin
    incr deb -1
    incr fin -1

    # reversed
    set rev 0
    if {$fin < $deb} {
	set tmp $fin
	set fin $deb
	set deb $tmp
	set rev 1
    }
    set rna [string range $seq $deb $fin]

    if {$cmpt} {
	set rna [ComplementDNA $rna]
	set rna [string reverse $rna]
    }

    puts "d=$deb f=$fin l=[expr {$fin-$deb+1}] | [string range $rna 0 11] [string range $rna end-11 end] $cmpt $rev"

    return $rna
}


proc ComplementDNA {seq} {
    set lg [string length $seq]
    set cpt ""
    set seq [string toupper $seq]
    for {set i 0} {$i < $lg} {incr i} {
	switch [string index $seq $i] {
	    "A" {append cpt "T"}
	    "T" {append cpt "A"}
	    "G" {append cpt "C"}
	    "C" {append cpt "G"}
	    "N" {append cpt "N"}
	}
    }

    return $cpt
}


proc DefineGroupForNewSeq {Lseq aT} {
    upvar $aT T
    global GroupeDeLaSequence SDG

    foreach seq $Lseq {
	set Lk {}
	lappend Lk {*}[array names T "$seq,*"]
	lappend Lk {*}[array names T "*,$seq"]
	set Lk [lsort -unique $Lk]
	set pmax -1. ; set kmax ""
	set ix [lsearch -exact $Lk "$seq,$seq"]
	set Lk [lreplace $Lk $ix $ix]
	foreach k $Lk {
	    lassign [split $k ,] n1 n2
	    if {$n1 in $Lseq && $n2 in $Lseq} {
		continue
	    }
	    set pci [lindex [set T($k)] 0]
	    if {$pci > $pmax} {
		set kmax $k
		set pmax $pci
	    }
	}

	# take the name of the closest sequence
	lassign [split $kmax ,] n1 n2
	if {$n1 eq $seq} {set close $n2} {set close $n1}
	set g [set GroupeDeLaSequence($close)]
	lappend SDG($g) $seq
	set GroupeDeLaSequence($seq) $g
    }

    return
}


proc ReAlignSeqs {} {
    global NomSeqSel LNOrdali LSOrdali LNSeqlab LSSeqlab NomNomSeq NomTextSeq Sequences
    
    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[llength $NomSeqSel] < 1} {
	FaireLire "Please select at least one sequence to be re-aligned !"
	
	return
    }
    
    FaireAttendre "Please wait ...\n Re-aligning sequences with MAFFT ..."
    
    if {[InSeqlabMode]} {
	set LNomsAli [lmap n $LNSeqlab {string trim $n}]
    } else {
	set LNomsAli [lmap n $LNOrdali {string trim $n}]
    }
    set LSeqsAli [$NomTextSeq output all]
    set LNomsOri $LNomsAli
    set LSeqsOri $LSeqsAli
    
    set NomSeqSel [lsort -dictionary -decreasing $NomSeqSel]
    foreach ys $NomSeqSel {
	lassign [split $ys .] y tmp
	set n [lindex $LNomsAli $y-1]
	if {[string trim $n] ne ""} {
	    lappend Lnrea $n
	    lappend Lsrea [string map {"." ""} [lindex $LSeqsAli $y-1]]
	    set LNomsAli [lreplace $LNomsAli $y-1 $y-1]
	    set LSeqsAli [lreplace $LSeqsAli $y-1 $y-1]
	}
    }

    if {! [info exists Lnrea]} {
	# only separators selected (or a selection left from an other instance)
	FaireLaSuite
	FaireLire "Please select at least one sequence to be re-aligned !"
	return
    }

    lassign [AlignSeqsAgainstReference $Lnrea $Lsrea $LNomsAli $LSeqsAli] LNAligned LSAligned aSAligned
    if {$LNAligned == {}} {
	# Something went wrong during alignment, return
	FaireLaSuite
	return ""
    }

    # re-order aligned sequences
    array set SAligned $aSAligned
    set Lgt [string length [lindex $aSAligned 1]]
    set LSAligned {}
    foreach n $LNomsOri s $LSeqsOri {
	if {[string trim $n] eq ""} {
	    # separator : at the new length of the alignment
	    if {$s ne ""} {
		set s [string repeat [string index $s 0] $Lgt]
	    }
	    lappend LSAligned $s
	} else {
	    set s $SAligned($n)
	    lappend LSAligned $s
	}
    }
    set LNAligned $LNomsOri
    
    # adjust features positions
    UpdateFeaturesPositions $LNomsOri $LSeqsOri $LNAligned $LSAligned

    # recreate lists according to mode
    if {! [InSeqlabMode]} {
	set LNOrdali $LNomsOri
	set LSOrdali $LSAligned
	unset -nocomplain Sequences
	array set Sequences $aSAligned
	# the instance must be saved with the new alignment
	VueEditee 1
    } else {
	set LNSeqlab $LNomsOri
	set LSSeqlab [lmap s $LSAligned {split $s ""}]
    }	

    if {! [InSeqlabMode]} {
	InitWRegle
	AfficheRegle
    }
	
    ChangeNomsAff $::Defauts(NomsAffiches)
    AfficheNomsEtSeqs
    RepeintNomsEtSeqs
	
    FaireLaSuite
	
    return
}
    

proc CalculeLesPoidsDesSeqs_mean {{normalise 1}} {
    # Argos and Vingron
    # wi = 1/(N-1) sum_i!=j d(si,sj)
    # moyenne des distance de seq j aux autres
    global LPCI TDesPCI LNOrdali

    set Lwgt {}
    set nSeqs 0
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}
	incr nseqs

	set sum 0.0
	foreach n1 $LNOrdali {
	    if {[string trim $n1] eq "" || $n eq $n1} {
		continue
	    }
	    set sum [expr {$sum + (1. - [lindex $TDesPCI($n,$n1) 0])}]
	}
	lappend Lsum $sum
    }
    set Lwgt [lmap x $Lsum {expr {$x / ($nSeqs - 1)}}]

    if {$normalise} {
	set sumTot [::tcl::mathop::+ {*}$Lwgt]
	set Lwgt [lmap x $Lwgt {expr {$x / $sumTot}}]
    }

    return $Lwgt
}


proc CalculeLesPoidsDesSeqs_eigen {} {
    # Valdar et all , scoring residue conservation
    # circular weights
    #
    # wi = sum_i!=j wj x d(si,sj)
    # w = D x w
    # (1 - D)x w = 0
    #
    # D = distance matrix
    # w = vector of weights
    # 
    # solved using eigen decomposition
    # weights are coordinates of eigenvector of the
    # highest eigenvalue
    #

    set Ld [ComputeDistanceMatrix]
    lassign [RunREigen $Ld] Lval Lvec
    
    # search vec with all positive/negative values
    set Lres {}
    foreach vec $Lvec {
	if {[lindex $vec 0] < 0.0} {
	    set vec [lmap v $vec {expr {-1.0*$v}}]
	}

	set okP 1
	foreach v $vec {
	    if {$v < 0.0} {
		set okP 0
		break
	    }
	}
	if {$okP} {
	    set Lres $vec
	    break
	}
    }
    
    puts "original weights :"
    plist $Lres %6.3f

    set sum 0.
    foreach v $Lres {
	set sum [expr {$sum + $v}]
    }
    set Lres [lmap v $Lres {expr {$v/$sum}}]
    puts "Scaled weights :"
    plist $Lres %6.3f
    
    return $Lres
}


proc henikoff_weights {ListePil} {
    set nseq [string length [lindex $ListePil 0]]
    set len [llength $ListePil]
    set weights [lrepeat $nseq 0.0]

    #
    # Iterate over columns
    #
    for {set pos 0} {$pos < $len} {incr pos} {
        array unset counts
        set distinct 0

        #
        # Count residues
        #

	set col [lindex $ListePil $pos]
	for {set i 0} {$i < $nseq} {incr i} {
	    set aa [string index $col $i]

            if {$aa eq "."} {
                continue
            }

            if {![info exists counts($aa)]} {
                set counts($aa) 0
                incr distinct
            }

            incr counts($aa)
        }

        #
        # Contributions
        #
        for {set i 0} {$i < $nseq} {incr i} {
	    set aa [string index $col $i]
            if {$aa eq "."} {
                continue
            }

            set contribution [expr {1.0 / ($distinct * $counts($aa))}]
            set old [lindex $weights $i]

            set weights [lreplace $weights $i $i [expr {$old + $contribution}]]
        }
    }

    return [normalize_weights $weights]
}


proc normalize_weights {weights} {
    set s [expr [join $weights +]]
    set out {}
    foreach w $weights {
        if {$s == 0.0} {
            lappend out 0.0
        } else {
            lappend out [expr {$w / $s}]
        }
    }

    return $out
}


proc CalculeLesPoidsDesSeqs_henikoff {ListePil} {
    # Henikoff and Henikoff
    #
    # wi= 1/L sum 1/(Kx.Nx)
    # L  = alignment length
    # Kx = number of amino acid types at position x
    # Nx = number of amino acid at pos x that
    # are the same as seq i

    # inits
    set NbSeq [string length [lindex $ListePil 0]]
    for {set i 0} {$i < $NbSeq} {incr i} {
	set w($i) 0.0
    }
    
    # loop over all positions
    foreach p $ListePil {
	# number of elements
	set lp [split $p ""]
	set kx [llength [lsort -unique $lp]]
	set i -1
	foreach a $lp {
	    incr i
	    if {$a ne "."} {
		set na [expr {$NbSeq - [string length [string map [list $a ""] $p]]}]
		set w($i) [expr {[set w($i)] + 1./($na*$kx)}]
	    }
	}
    }

    set Lw {}
    set len [expr {double([llength $Lpil])}]
    for {set i 0} {$i < $NbSeq} {incr i} {
	lappend Lw [expr {[set w($i)]/$len}]
    }

    return $Lw
}


proc tst {} {
    LoadTclPackages

    set l [list 5.0 3.0 -2.0 -1.0]
    set m [::tcl::mathop::+ {*}$l]
    set l [lmap x $l {expr {$x/$m + $m}}]
    set m [::tcl::mathop::+ {*}$l]
    set l [lmap x $l {expr {$x/$m}}]
    plist $l %6.3f
    puts [::tcl::mathop::+ {*}$l]
    exit
}


proc Reigen {} {
    global TDesPCI LNOrdali

    set Ln {}
    foreach n $LNOrdali {
	if {[string trim $n] ne ""} {
	    lappend Ln $n
	}
    }
    set m {}
    foreach a $Ln {
	set tmp {}
	foreach b $Ln {
	    lappend tmp [expr {1.0 - [lindex $TDesPCI($a,$b) 0]}]
	}
	lappend m $tmp
    }
    lmap x $m {plist $x %6.4f}
    puts ""
    package require Rtcl
    
    Rpipe "x <- c([join [concat {*}$m] ,])"
    Rpipe "x <- matrix(x, byrow = T, ncol=5, nrow=5)"
    
    #Rpipe "res <- eigen(x, symmetric=TRUE)"
    set vec [lrange $Lvec 0 4]
    set sum [+ {*}$vec]
    set new [lmap x $vec {expr {$x/$sum}}]
    plist $new %6.3f
    
    return $vec
}


proc ChangeSeqnmaeOfSeq {old new} {
    global SDG LNOrdali TEdit

    set i [lsearch $LNOrdali $old]
    lset LNOrdali $i $new
    set g $TDuGroupeDeLaSeq($old)
    set i [lsearch $SDG($g) $old]
    lset SDG($g) $i $new

    foreach t [info global "TD*"] {
	set v ${t}($old)
	array unset ${t}($old)
	set ${t}($new) $v
    }

    return
}


proc EstUnIdUniProt {text} {
    set re_uniprot_id {\m[A-Z0-9]{1,10}_[A-Z0-9]{3,10}\M}
    
    if {[regexp $re_uniprot_id $text match]} {
	return 1
    } else {
	return 0
    }
}


proc EstUnAccUniProt {Access} {
    #lm 2026/09/04: old regexp is wrong, as it recognise alphafold IDs as uniprot ones.
    #lm old: set re_uniprot_acc {\m(?:[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9][A-Z][A-Z0-9]{2}[0-9]|[A-NR-Z][0-9][A-Z0-9]{7}[0-9])\M}
    #lm Here is the new one, accepting version number of access

    if {[regexp {^(?:[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9](?:[A-Z][A-Z0-9]{2}[0-9]){1,2})(?:\.[0-9]+)?$} $Access]} {
	return 1
    } else {
	return 0
    }
}


proc EstUnRefSeq {text} {
    set re_refseq {^(?:AC|AP|NC|NG|NM|NP|NR|NT|NW|NZ|XM|XP|XR|YP|ZP)_[0-9]+(?:\.[0-9]+)?$}
    if {[regexp $re_refseq $text]} {
	return 1
    } else {
	return 0
    }
}


proc lslr {} {
    set L [list totosldkfj slmdkfj qsdlkmfj aupe jqsdklf auior fqjk qsdfjk qsklfj qm fjkd zoie jfkdlsl sdk skdfj q qs sq sdf qsdff klqsdf sdfmjklsdfq sdfq sdf qsfjhzeeiofsjksdf]
    
    set t1 [time {lset L 3 armada} 100000]
    puts "t1 $t1"
    set t2 [time {set L [lreplace $L 3 3 armada]} 100000]
    puts "t2 $t2"

    exit
}

proc tidpdb {} {
    set f 2il2.pdb
    set id [DonneIdDeAccessPDB $f]
    puts "$f $id"
    set f [BonNomPDB $f]
    set id [DonneIdDeAccessPDB $f]
    puts "$f $id"

    exit
}


proc tcreeord {} {
    set out [$::db serialize]
    set o [open ser.out w]
    puts $o $out
    close $o
    
    SauveLAlignement ORD test.ord
    exit
}

proc examine object {
    variable tests
    puts [list {what is copied for} $object]
    set ns [$object eval {namespace current}]
    namespace eval ns1 [
        list namespace import ${ns}::export1]
    set results {0 yes 1 no}
    foreach {label script} $tests {
        set copts {}
        puts [list $label [dict get $results [
            catch $script cres copts]]]
        #puts $copts
    }
    $object forward1

    exit
}
