


#
#
# --- ordali_spinoff.tcl
#
#
# This file contains procedures for the spinoff programs of ordali.
# - msainfo
# - msaconvert
# - msacut
# - viewtree
# - viewpdb
#
#


proc LoadUnArbre {{fichierPH ""} {InOrdali 0}} {
    global Abr
    
    LoadTkAndPackages
    package require struct

    if {$fichierPH eq ""} {
	set f [DemandeEtOuvreFichier ph 1]
	if {$f eq ""} {
	    return
	}
    } else {
	set f $fichierPH
    }
    if {! [file exists $f]} {
	return
    }

    set LeTree [ContenuDuFichier $f]
    set LeTree [NettoieArbre $LeTree]
    # a Newick tree starts with '(' and has balanced parentheses
    # (another file gave an empty, broken tree window)
    if {$LeTree ne 0} {
	set LeTree [string trim $LeTree]
	if {[string index $LeTree 0] ne "(" || [regexp -all {\(} $LeTree] != [regexp -all {\)} $LeTree]} {
	    set LeTree 0
	}
    }
    set Msg ""
    if {$LeTree == 0 || [catch {set AId [InitialiseUnArbre $LeTree]} Msg]} {
	puts "Msg\n$Msg\n$::errorInfo"
	FaireLire "Error while reading the tree file !\nVerify the file is in Newick format"

	return
    }

    # some tree initialisation
    set Abr($AId,Mode)        normal
    set Abr($AId,TypeGapTree) "Unknown"
    set Abr($AId,NbrSites)    "Unknown"
    set Abr($AId,TreeNBoot)   "Unknown"
    set Abr($AId,BootDone)    0
    # instance of the tree, as for a computed tree : without it,
    # changing the leaf labels failed and the tree was not saved
    if {$InOrdali && [TypeAli] ne "pasdali"} {
	set Abr($AId,Mac) [MacCourant]
    }

    AfficheUnArbre $AId $InOrdali

    return
}


proc MSACut_SetFeaturesRanges {relative Ld Lf} {
    global TabSF LNOrdali LSOrdali ListePDB

    if {$relative ne ""} {
	# transforme coords into globals coords
	set Ld [lmap x $Ld {DonnePosSG $relative $x}]
	set Lf [lmap x $Lf {DonnePosSG $relative $x}]
    }	

    # Now correct features limits according to selected zones
    foreach n $LNOrdali {
	set Ltypes [array names TabSF "$n,*"]
	foreach ntype $Ltypes {
	    lassign [split $ntype ,] tmp type
	    foreach ft $TabSF($ntype) {
		DecortiqueUneFeature $ft dg fg fcolor fscore fnote csys
		foreach x1 $LfromX x2 $LtoX {
		    if {$dg > $x2 || $fg < $x1} {
			set ok 0
			continue
		    }
		    if {$fg > $x2} {
			set ok 1
			set fg $x2
		    }
		    if {$dg < $x1} {
			set ok 1
			set dg $x1
		    }
		}
		if {$ok} {
		    # save corrected feature
		    lappend Tnew($n,$type) [list "fstart" $dg "fstop" $fg "fcolor" $fcolor "fscore" $fscore "fnote" $fnote "fcsys" $csys]
		}
	    }
	}
    }
    unset -nocomplain TabSF
    array set TabSF [array get Tnew]

    return
}


proc MSACut {args} {
    global LNOrdali LSOrdali Sequences  LfromX LtoX LfromY LtoY

    lassign $args relative format outfile

    # If positions are relative to a specific sequence, check it
    if {$relative ne ""} {
	set ix [lsearch -nocase $LNOrdali $relative]
	if {$ix == -1} {
	    puts "\nError !\nThe sequence specify in >-relative< does not exists !"
	    exit
	}
    }

    # set features limits according to selected zones
    if {[TypeAli] eq "XML" && $LfromX != {}} {
	MSACut_SetFeaturesRanges $relative $LfromX $LtoX
    }

    # translate sequences names if any into sequence position
    foreach var {LfromY LtoY} {
	set tmp {}
	foreach seq [set $var] {
	    if {! [string is entier $seq]} {
		set ix [lsearch -nocase $LNOrdali $seq]
		if {$ix == -1} {
		    puts "\nError !\n Sequence >$seq< does not exist in the alignment !\n"
		    exit
		}
	        lappend tmp $ix
	    } else {
		lappend tmp $seq
	    }
	}
	set tmp [lsort -integer $tmp]
	set $var $tmp
    }
    set Llimits {}
    foreach y1 $LfromY y2 $LtoY {
	lappend Llimits $y1 $y2
    }
    set Ltmp2 [lsort -integer $Llimits]
    if {$Ltmp2 != $Llimits} {
	puts "\nError !\nMismatch in selected sequences ('-fromseq' and 'toseq' keys) !\n"
	exit
    }

    # Create new sequences lists according to LfromY and LtoY boundaries
    if {$Llimits != {}} {
	set LNnew {} ; set LSnew {}
	foreach {y1 y2} $Llimits {
	    lappend LNnew {*}[lrange $LNOrdali $y1 $y2]
	    lappend LSnew {*}[lrange $LSOrdali $y1 $y2]
	}
	set LNOrdali $LNnew
	set LSOrdali $LSnew
    }
    
    # check position values
    # Put values in [0,lgt-1] range
    set Ltmp {}
    set Lx2new {} ; set Lx1new {}
    set lgt [LongueurDeLAlignement]
    foreach x1 $LfromX x2 $LtoX {
	if {$x2 eq "end"} {
	    set x2 $lgt
	}
	#puts "x1 $x1 x2 $x2 "
	lappend Lx1new [expr {$x1 - 1}]
	lappend Lx2new [expr {$x2 - 1}]
	lappend Ltmp $x1 $x2
    }
    set LfromX $Lx1new
    set LtoX $Lx2new
    set Ltmp2 [lsort -integer $Ltmp]
    if {$Ltmp2 != $Ltmp} {
	puts "\nError !\nMismatch in '-frompos' and '-topos' values !\n"
	exit
    }
    
    # (fromX toX pairs define residue zones to be kept.
    set Lsnew {}
    foreach n $LNOrdali s $LSOrdali {
	set snew ""
	if {[string trim $n] ne ""} {
	foreach x1 $LfromX x2 $LtoX {
	    append snew [string range $s $x1 $x2]
	}
	    set Sequences($n) $snew
	}
	lappend Lsnew $snew
    }
    set LSOrdali $Lsnew
    
    if {$outfile eq ""} {
	set outfile JLeSauveAs
    }
    if {$format eq ""} {
	set format [TypeAli]
    }

    SauveLAlignement $format $outfile

    exit


    
    if ff{[TypeAli] eq "XML"} {
	array set TabSF [CheckFeaturesInRange $frompos $topos]
    }

    
    

    return
}


proc MSAInfoHelp {} {
    puts "\nUsage :"
    puts "msainfo <filename> ?-option value? ..."
    puts "\nOptions are :"
    puts "\t-format <html|text> : output format. Default is HTML."
    puts "\t-outfile <filename> : name for the output file. If this option is not present, the output filename will consist of the input file rootname suffixed by the choosen output format."
    puts "\t-type <info-type> : specifies the type of required information to be output. The following types are available :"
    puts "\t   + identity : report all sequences identity pairs for all groups presents in the alignment, with mean, standart deviation, min, max."
    puts "\t   + identitystats : report only statistics for all groups of sequences."
    puts "\t  + composition : reports the proteins composition, both for each aminoacid, and for physico-chemical groups of aminoacids."
    puts "\t  + clustering : reports information for the current sequences clustering."
    puts "\t  + global : reports physico-chemical information for all proteins like length, isoelectiric point, molecular weight."
    puts "\t  + all : reports all above information."
    puts "\nSeveral information types can be specified separated by comas WITHOUT WHITE SPACES."
    puts "\nNOTE: With HTML format, all tables can be exported as a CSV file.\n"
    
    return
}


proc MSACutHelp {} {
    puts "\nUsage : msacut <fileIn> options ...\n"
    puts "\t-frompos <integer> : start position of the residue zone to be included in the alignment"
    puts "\t-topos <integer | end> : end position for the residue zone to be included in the alignment. The special word 'en' refers to the end of the alignment."
    puts "NOTE : Several -frompos/-topos pairs can be specified. If none, the whole alignment is selected."
    puts "\t-fromseq <integer | seqname> : position or sequence name of thefirst sequence zone to be included in the output alignment"
    puts "\t-toseq <integer | seqname> : position or sequence name of the last sequence zone to be included in the output alignment."
    puts "NOTE : Several -fromseq/-toseq pairs can be specified."
    puts "\t-format <tfa|msf|xml|aln> : output format. If the -format key is not specified, the output alignment will have the same format as the input alignment."
    puts "\t-outfile <filename> : output file name. If no -outfile is specified, the output alignment file name will have the rootname of the inputalignment suffixed by the output type format."
    puts "\t-relative <global|seq-name> : By default the alignment position are supposed to be global alignment coordinates. If a seq-name is specified, then the positions coordinates corresponds to positions inside the seq-name sequence."
    puts ""
    
    exit
}


proc MSAInfoOptions {Largs} {
    global AExecuter Logs2Do

    if {[llength $Largs] == 0} {
	MSAInfoHelp
	exit
    }

    if {[string first "help" [string tolower $Largs]] > -1} {
	MSAInfohelp
	exit
    }
    
    set fileIn [lindex $Largs 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile >$fileIn< does not exist !\n"
	exit
    }
    set Largs [lrange $Largs 1 end]

    set format "HTML"
    set outfile ""
    foreach {k v} $Largs {
	switch $k {
	    "-format" {
		set v [string toupper $v]
		if {$v ni {"HTML" "LATEX" "TEXT"}} {
		    puts "\nError !\nBad output format value >$v< !\nShould be one of HTML, LATEX, TEXT.\n"
		    exit
		}
		set format $v
	    }
	    "-type" {
		set v [string trim [string tolower $v]]
		if {[string first "," $v] > -1} {
		    set Lval [split $v ","]
		} else {
		    set Lval $v
		}
	    }
	    "-outfile" {
		set outfile $v
	    }
	    default {
		puts "\nKey >$k< ignored !\n"
		MSAInfoHelp
		exit
	    }
	}
    }
    puts "outfile= $outfile"
    if {$outfile eq ""} {
	set outfile "[file rootname [file tail $fileIn]].[string tolower $format]"
    }

    set Llogs {global seq identity identitystats composition clustering}
    if {$Lval =={}} {
	puts "\nError !\nNo >-type< key !\n"
	MSAInfoHelp
	exit
    }
    if {$Lval eq "all"} {
	set Lval $Llogs
    }
    set Logs2Do {}
    foreach log $Lval {
	switch $log {
	    "identity" {lappend Logs2Do LogPCI}
	    "identitystats" {lappend Logs2Do LogPCIStats}
	    "composition" {lappend Logs2Do LogLesCompositions}
	    "seq" {lappend Logs2Do LogInfosSeqsGlobales}
	    "global" {lappend Logs2Do LogSeqInfoGlobales}
	    "clustering" {lappend Logs2Do LogInfosClusters}
	    default {
		puts "\nIgnoring info type >$log< !\n"
	    }
	}
    }
    if {$Logs2Do == {}} {
	puts "\nWarning! No info requested !"
	MSAInfoHelp
	exit
    }

    #set ::env(ORDALIEONWEB) 1
    #TaisToi 1
    LesDefauts Mode batch
    LesDefauts Exit 1
    LesDefauts DownloadPDB dont
    
    set AExecuter "MSAInfo $format $outfile"

    return $fileIn
}
    
    
proc MSAInfo {format outfile} {
    global Logs2Do SDG

    # Are there several groups ?
    set nbGrp [llength [array names SDG]]

    # Re-create list of log to execute
    set LnewLogs {}
    foreach log $Logs2Do {
	if {[string first "PCI" $log] > -1 && ! [info exists ::LTPCI]} {
	    CalculeLesPCIDuMac
	}
	if {$log eq "LogPCI"} {
	    if {$nbGrp > 1} {
		    lappend LnewLogs "LogPCI groups"
	    }
	}

	# only statistics
	if {$log eq "LogPCIStats"} {
	    set log "LogPCI global 1"
	    if {$nbGrp > 1} {
		    lappend LnewLogs "LogPCI groups 1"
	    }
	}
lappend LnewLogs $log
    }

    # let's do it ...
    foreach log $LnewLogs {
	    eval $log
    }
    puts "write to outfile $outfile"
    AuLog LOutput $format $outfile
    puts "output done !"
    return
}


proc ViewTreeHelp {} {
	puts "\nUsage :\nviewtree <filename>\n"

    exit
}


proc ViewTreeOptions {Lopts} {
    global AExecuter

    if {$Lopts == {} || [llength $Lopts] > 1} {
	viewTreeHelp
	exit
    }

    set fileIn [lindex $Lopts 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile >$fileIn< does not exist !\n"
	exit
    }

    #set AExecuter "Botanique $fileIn"
    set AExecuter "LoadUnArbre $fileIn"

    return ""
}


proc Botanique {{FichierPH ""}} {
    if {$FichierPH eq ""} { 
	set FichierPH "Botanique.ph" 
    }
    set LeTree [ContenuDuFichier $FichierPH]
    set AId [InitialiseUnArbre $LeTree]
    set ::Abr($AId,BootDone) 0
    
    return [AfficheUnArbre $AId]
}


proc ViewPDBOptions {Lopts} {
    global AExecuter

    if {$Lopts == {}} {
	puts "\nUsage :\nviewpdb <PDB ID| filename> ...\n"
	exit
    }
    
    set AExecuter "ViewPDB $Lopts"

    return ""
}


proc MSACutOptions {Lopts} {
    global AExecuter LfromX LtoX LfromY LtoY

    if {$Lopts == ""} {
	MSACutHelp

	exit
    }

    set fileIn [lindex $Lopts 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile >$fileIn< does not exists !\n"
	exit
    }
    set Lopts [lrange $Lopts 1 end]

    if {[llenth $Lopts] == 0} {
	puts "\nError !\nToo few arguments ! At least a couple of -frompos/-topos and/or -fromseq/-toseq should be specified !"
	MSACutHelp
	exit
    }

    # There should be an event number of arguments
    if {[llength $Lopts] %2} {
	puts "\nError !\nThere should be an even number of arguments !\n"
	MSACutHelp
	exit
    }
    
    # There should be at least a '-frompos', '-topos' and '-outfile' key
    if {"-frompos" ni $Lopts || "-topos" ni $Lopts || "-outfile" ni $Lopts} {
	puts "\nError !\nThere should be at least a '-frompos', '-topos' and '-outfile' key!\n"
	exit
    }
    
    set outfile ""
    set format ""
    set relative "global"
    set LfromX {} ; set LtoX {}
    set LfromY {} ; set LtoY {}
    foreach {k v} $Lopts {
	switch $k {
	    "-frompos" {
		if {! [string is entier $v]} {
		    puts "\nError !\nA '-frompos' key does not have an integer value !\n"
		    exit
		}
		lappend LfromX $v
	    }
	    "-topos" {
		if {$v ne "end" && ! [string is entier $v]} {
		    puts "\nError !\nA '-topos' key does not have an integer or 'end' value !\n"
		    exit
		}
		lappend LtoX $v
	    }
	    "-fromseq" {
		lappend LfromY $v
	    }
	    "-toseq" {
		lappend LtoY $v
	    }
	    "-relative" {
		set relative $v
	    }				
	    "-format" {
		set v [string toupper $v]
		if {$v ni {TFA MSF ALN XML}} {
		    puts "\nError !\nThe '-format' value is not a valid format ! should be one of TFA, MSF, ALN, XML.\n"
		    exit
		}	
		set format $v
	    }	
	    "-outfile" {
		set outfile $v
	    }
	}
    }
    set LfromX [lsort -integer $LfromX]
    set LfromY [lsort -integer $LfromY]
    
    LesDefauts DownloadPDB dont
    LesDefauts Mode Batch
    LesDefauts Exit 1
    if {! [info exists outfile] || $outfile eq ""} {
	set outfile JLeSauvveAs
    }

    set AExecuter "MSACut [list $relative $format $outfile]"
    
    return $fileIn
}


proc MSAConvertOptions {Largs} {
    if {$Largs eq ""} {
	MSAConvertHelp

	exit
    }
    
    set fileIn [lindex $Largs 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile '$fileIn' does not exists !\n"

	exit
    }
    set Largs [lrange $Largs 1 end]
    if {[llength $Largs] == 0} {
	puts "\nError !\nToo few arguments !\n"
	MSAConvertHelp

	exit
    }
    if {[llength $Largs] % 2} {
	puts "\nError !\nWrong number of arguments !\n"
	MSAConvertHelp

	exit
    }
    set Lpar [list $fileIn]
    set format ""
    set fileOut ""
    foreach {k v} $Largs {
	switch $k {
	    "-format" {
		set v [string tolower $v]
		if {$v ni {tfa fasta fa msf macsim macsims xml aln ord}} {
		    puts "\nError !\nBad format ! Should be one of tfa, fasta, fa, macsim, macsims, xml, aln, msf, ord.\n"

		    exit
		}
		set format $v
		lappend Lpar "-convert" $v
	    }
	    "-output" -
	    "-outfile" {
		set fileOut $v
	    }
		default {
		puts "\nkey <$k> ignored"
		continue
	    }
	}
    }
    if {$format eq ""} {
	puts "\nError !\nYou must specify an output file format !\n"
	MSAConvertHelp

	exit
    }

    if {$fileOut eq ""} {
	set fileOut [file rootname [file tail $fileIn]].$format
    }
    lappend Lpar "-outfile" $fileOut
    
	    return $Lpar
}


proc MSAConvertHelp {} {
    puts "\nUsage :\nmsaconvert <input-file> -format <format> ?-output <output-file>? \n"
    puts "msaconvert converts a MSA specified by <input-file> into another format specified by the -format option. Available formats are :"
    puts "\t- tfa, fasta, fa : fasta format"
    puts "\t- macsim, macsims, xml : macsims format"
    puts "\t- msf : msf format"
    puts "\t- aln : Clustal format"
    puts "\t- ord : ordalie format"
    puts ""
    puts "If the key -output is not specified, the output file will have the same name as the input file with an extension corresponding to the required format."
    puts ""

    exit
}


proc InterpreteArgv0 {{Ligne ""}} {
    regsub -all { +} [string trim $Ligne] " " Ligne
    set Largs [split $Ligne " "]
    
    set prog [file tail $::argv0]
    switch $prog {
	"ordali.tcl" -
	"ordali" -
	"ordalie" {
	    if {$Largs == {}} {
		puts "\ntype 'ordalie help' to access on-line optional arguments\n"
		LoadTclPackages
	    }
	    set Ligne $Largs
	}
	"viewtree" {
	    set Ligne [ViewTreeOptions $Largs]
	}
	"viewpdb" {
	    set Ligne [ViewPDBOptions $Largs]
	}
	"msainfo" {
	    set ::env(ORDALIEONWEB) 1
	    set Ligne [MSAInfoOptions $Largs]

	    #TaisToi 1
	}
	"msacut" {
	    set ::env(ORDALIEONWEB) 1
	    #TaisToi 1
	    set Ligne [MSACutOptions $Largs]
	}
	"msaconvert" {
	    set Ligne [MSAConvertOptions $Largs]
	    set fileIn [lindex $Ligne 0]
	    set ::env(ORDALIEONWEB) 1
	    TaisToi 1
	    #set ligne "$fileIn -exit 1 -exe SauveLAlignement $format $fileOut"
	}
    }
    
    return $Ligne
}









