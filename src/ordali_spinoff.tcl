


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


proc MSACutZones {relative LfromX LtoX} {
    # column zones kept by msacut : list of {first last} (0-based, sorted).
    # LfromX/LtoX : -frompos/-topos values (start at 1, "end" for the
    # last one), in the alignment, or in the sequence <relative> (its
    # residues, without gaps) if relative is not "global".
    global LNOrdali Sequences

    set lgt [LongueurDeLAlignement]
    if {$LfromX == {}} {
	return [list [list 0 [expr {$lgt-1}]]]
    }

    set seq ""
    if {$relative ne "global"} {
	set ix [lsearch -exact $LNOrdali $relative]
	if {$ix == -1} {
	    set ix [lsearch -exact -nocase $LNOrdali $relative]
	}
	if {$ix == -1 || [string trim $relative] eq ""} {
	    puts "\nError !\nThe sequence >$relative< given with '-relative' does not exist !\n"
	    exit 1
	}
	set seq [lindex $LNOrdali $ix]
	set max [regexp -all {[A-Za-z]} $Sequences($seq)]
    } else {
	set max $lgt
    }

    set Lz {}
    foreach x1 $LfromX x2 $LtoX {
	if {$x2 eq "end"} {
	    set x2 $max
	}
	if {$x1 < 1 || $x2 > $max || $x1 > $x2} {
	    puts "\nError !\nBad zone -frompos $x1 -topos $x2 : positions should be in \[1,$max\], start <= end !\n"
	    exit 1
	}
	if {$seq ne ""} {
	    # residue -> column (DonnePosSG : residue index from 0)
	    lappend Lz [list [DonnePosSG $seq [expr {$x1-1}]] [DonnePosSG $seq [expr {$x2-1}]]]
	} else {
	    lappend Lz [list [expr {$x1-1}] [expr {$x2-1}]]
	}
    }
    set Lz [lsort -integer -index 0 $Lz]
    set prev -1
    foreach z $Lz {
	if {[lindex $z 0] <= $prev} {
	    puts "\nError !\nThe '-frompos'/'-topos' zones overlap !\n"
	    exit 1
	}
	set prev [lindex $z 1]
    }

    return $Lz
}


proc MSACutSequences {LfromY LtoY} {
    # names of the sequences kept by msacut, in the order of the
    # alignment. LfromY/LtoY : -fromseq/-toseq values, sequence number
    # (from 1, without the empty lines between groups) or name.
    global LNOrdali

    set Lnoms [lsearch -all -inline -not -exact $LNOrdali ""]
    if {$LfromY == {}} {
	return $Lnoms
    }

    set nseq [llength $Lnoms]
    set Lz {}
    foreach y1 $LfromY y2 $LtoY {
	set Li {}
	foreach y [list $y1 $y2] {
	    if {[string is entier -strict $y]} {
		if {$y < 1 || $y > $nseq} {
		    puts "\nError !\nSequence number $y should be in \[1,$nseq\] !\n"
		    exit 1
		}
		lappend Li [expr {$y-1}]
	    } else {
		set i [lsearch -exact $Lnoms $y]
		if {$i == -1} {
		    set i [lsearch -exact -nocase $Lnoms $y]
		}
		if {$i == -1} {
		    puts "\nError !\nSequence >$y< does not exist in the alignment !\n"
		    exit 1
		}
		lappend Li $i
	    }
	}
	lassign $Li i1 i2
	if {$i1 > $i2} {
	    puts "\nError !\n-fromseq $y1 comes after -toseq $y2 in the alignment !\n"
	    exit 1
	}
	lappend Lz [list $i1 $i2]
    }

    set Lkeep {}
    foreach z $Lz {
	lassign $z i1 i2
	for {set i $i1} {$i <= $i2} {incr i} {
	    lappend Lkeep $i
	}
    }
    set Lkeep [lsort -integer -unique $Lkeep]

    return [lmap i $Lkeep {lindex $Lnoms $i}]
}


proc MSACut {relative format outfile} {
    # msacut : keeps the column zones and the sequences given on the
    # command line (MSACutOptions), then saves the alignment.
    # The features (columns, from 0, in TabSF) and the column scores are
    # moved to the new columns ; those of the removed sequences and
    # columns are dropped.
    global LNOrdali LSOrdali Sequences LongueurTotale TabSF TColScore
    global LfromX LtoX LfromY LtoY

    set lgt [LongueurDeLAlignement]
    set Lz [MSACutZones $relative $LfromX $LtoX]
    set Lkeep [MSACutSequences $LfromY $LtoY]

    # column offset of each zone in the new alignment
    set Lzo {}
    set off 0
    foreach z $Lz {
	lassign $z z1 z2
	lappend Lzo [list $z1 $z2 $off]
	incr off [expr {$z2-$z1+1}]
    }
    set newlgt $off

    # sequences
    set LNnew {}
    set LSnew {}
    foreach n $LNOrdali {
	if {$n eq "" || $n ni $Lkeep} {
	    # removed sequence ; the empty lines between groups are
	    # kept only if all sequences are
	    if {$n eq "" && $LfromY == {}} {
		lappend LNnew ""
		lappend LSnew ""
	    }
	    if {$n ne ""} {
		unset -nocomplain Sequences($n)
	    }
	    continue
	}
	set s ""
	foreach z $Lz {
	    append s [string range $Sequences($n) {*}$z]
	}
	set Sequences($n) $s
	lappend LNnew $n
	lappend LSnew $s
    }
    set LNOrdali $LNnew
    set LSOrdali $LSnew
    set LongueurTotale $newlgt
    # a sequence without residues can not be read again (xml, tfa ...)
    set Lvides {}
    foreach n $LNnew s $LSnew {
	if {$n ne "" && ! [regexp {[A-Za-z]} $s]} {
	    lappend Lvides $n
	}
    }
    if {$Lvides != {}} {
	puts "\nWarning !\nThese sequences have no residue in the kept columns :\n[join $Lvides \n]\n"
    }

    # features
    if {[info exists TabSF]} {
	foreach k [array names TabSF] {
	    set n [lindex [split $k ,] 0]
	    if {$n ni $Lkeep} {
		unset TabSF($k)
		continue
	    }
	    set Lnew {}
	    foreach ft $TabSF($k) {
		set d [dict get $ft fstart]
		set f [dict get $ft fstop]
		foreach zo $Lzo {
		    lassign $zo z1 z2 o
		    if {$f < $z1 || $d > $z2} {
			continue
		    }
		    dict set ft fstart [expr {max($d,$z1) - $z1 + $o}]
		    dict set ft fstop  [expr {min($f,$z2) - $z1 + $o}]
		    lappend Lnew $ft
		}
	    }
	    if {$Lnew == {}} {
		unset TabSF($k)
	    } else {
		set TabSF($k) $Lnew
	    }
	}
    }

    # column scores : one value per column
    if {[info exists TColScore(Names)]} {
	foreach name $TColScore(Names) {
	    if {! [info exists TColScore($name,Data)]} {
		continue
	    }
	    set Lnew {}
	    foreach d $TColScore($name,Data) {
		if {[llength $d] == $lgt} {
		    set dn {}
		    foreach z $Lz {
			lappend dn {*}[lrange $d {*}$z]
		    }
		    set d $dn
		}
		lappend Lnew $d
	    }
	    set TColScore($name,Data) $Lnew
	}
    }

    if {$format eq ""} {
	set format [TypeAli]
	if {$format ni {TFA MSF ALN XML}} {
	    set format XML
	}
    }
    if {$outfile eq ""} {
	set outfile "[file rootname [file tail [set ::Defauts(Fichier[TypeAli])]]]_cut.[string tolower $format]"
    }

    SauveLAlignement $format $outfile
    puts "[llength $Lkeep] sequences, $newlgt columns written to $outfile"

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
    puts "\t  + global : reports physico-chemical information for all proteins like length, isoelectric point, molecular weight."
    puts "\t  + seq : reports accession, ID, length, organism and taxonomy ID of each sequence."
    puts "\t  + all : reports all above information."
    puts "\t-instance <n> : with an ORD file (compulsory), number in the list (1 : Original alignment) or label (M5 for \"M5 - ...\") of the instance to be treated. A wrong value lists the instances."
    puts "\nSeveral information types can be specified separated by comas WITHOUT WHITE SPACES."
    puts "\nNOTE: With HTML format, all tables can be exported as a CSV file.\n"
    
    return
}


proc MSACutHelp {{code 0}} {
    puts "\nUsage : msacut <fileIn> options ...\n"
    puts "\t-frompos <integer> : start position of a residue zone (column) to be kept in the alignment, from 1."
    puts "\t-topos <integer | end> : end position of this zone. The special word 'end' refers to the end of the alignment (or of the -relative sequence)."
    puts "NOTE : Several -frompos/-topos pairs can be specified, taken in the order given. If none, all the columns are kept."
    puts "\t-fromseq <integer | seqname> : number (from 1) or name of the first sequence of a group of sequences to be kept in the output alignment"
    puts "\t-toseq <integer | seqname> : number or name of the last sequence of this group."
    puts "NOTE : Several -fromseq/-toseq pairs can be specified. If none, all the sequences are kept."
    puts "\t-format <tfa|msf|xml|aln> : output format. If the -format key is not specified, the output alignment will have the same format as the input alignment (xml for an ord file)."
    puts "\t-outfile <filename> : output file name. If no -outfile is specified, the output file name is the rootname of the input alignment followed by '_cut' and the output format (D_maj.tfa -> D_maj_cut.tfa)."
    puts "\t-instance <n> : with an ORD file (compulsory), number in the list (1 : Original alignment) or label (M5 for \"M5 - ...\") of the instance to be cut. A wrong value lists the instances."
    puts "\t-relative <global|seq-name> : By default the positions are global alignment coordinates (columns). If a seq-name is specified, then the positions are residue numbers of the seq-name sequence."
    puts ""

    exit $code
}


proc MSAInfoOptions {Largs} {
    global AExecuter Logs2Do

    if {[llength $Largs] == 0 || [string tolower [lindex $Largs 0]] in {help -help -h}} {
	MSAInfoHelp
	exit
    }

    set fileIn [lindex $Largs 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile >$fileIn< does not exist !\n"
	exit
    }
    set Largs [lrange $Largs 1 end]
    if {[llength $Largs] % 2} {
	puts "\nError !\nThere should be an even number of arguments after the file name !\n"
	MSAInfoHelp
	exit
    }

    # output formats of OutputTLog (ordali_tlog.tcl) : HTML and Text
    set format "HTML"
    set outfile ""
    set Lval {}
    foreach {k v} $Largs {
	switch $k {
	    "-format" {
		switch [string tolower $v] {
		    "html" {set format "HTML"}
		    "text" {set format "Text"}
		    default {
			puts "\nError !\nBad output format value >$v< !\nShould be html or text.\n"
			exit
		    }
		}
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
	ViewTreeHelp
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

    if {$Lopts == {} || [string tolower [lindex $Lopts 0]] in {help -help -h}} {
	MSACutHelp
    }

    set fileIn [lindex $Lopts 0]
    if {! [file exists $fileIn]} {
	puts "\nError !\nFile >$fileIn< does not exist !\n"
	exit 1
    }
    set Lopts [lrange $Lopts 1 end]

    if {[llength $Lopts] == 0} {
	puts "\nError !\nToo few arguments ! At least a couple of -frompos/-topos and/or -fromseq/-toseq should be specified !"
	MSACutHelp 1
    }
    # There should be an even number of arguments
    if {[llength $Lopts] % 2} {
	puts "\nError !\nThere should be an even number of arguments !\n"
	MSACutHelp 1
    }

    set outfile ""
    set format ""
    set relative "global"
    set LfromX {} ; set LtoX {}
    set LfromY {} ; set LtoY {}
    foreach {k v} $Lopts {
	switch -- $k {
	    "-frompos" {
		if {! [string is entier -strict $v]} {
		    puts "\nError !\nA '-frompos' key does not have an integer value !\n"
		    exit 1
		}
		lappend LfromX $v
	    }
	    "-topos" {
		if {$v ne "end" && ! [string is entier -strict $v]} {
		    puts "\nError !\nA '-topos' key does not have an integer or 'end' value !\n"
		    exit 1
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
		    exit 1
		}
		set format $v
	    }
	    "-output" -
	    "-outfile" {
		set outfile $v
	    }
	    default {
		puts "\nError !\nUnknown key >$k< !\n"
		MSACutHelp 1
	    }
	}
    }
    if {[llength $LfromX] != [llength $LtoX] || [llength $LfromY] != [llength $LtoY]} {
	puts "\nError !\nEach '-frompos' needs a '-topos', each '-fromseq' a '-toseq' !\n"
	exit 1
    }
    if {$LfromX == {} && $LfromY == {}} {
	puts "\nError !\nAt least a couple of -frompos/-topos and/or -fromseq/-toseq should be specified !\n"
	MSACutHelp 1
    }

    LesDefauts DownloadPDB dont
    LesDefauts Mode batch
    LesDefauts Exit 1

    set AExecuter [list MSACut $relative $format $outfile]

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
    puts "\nUsage :\nmsaconvert <input-file> -format <format> ?-output <output-file>? ?-instance <n>?\n"
    puts "msaconvert converts a MSA specified by <input-file> into another format specified by the -format option. Available formats are :"
    puts "\t- tfa, fasta, fa : fasta format"
    puts "\t- macsim, macsims, xml : macsims format"
    puts "\t- msf : msf format"
    puts "\t- aln : Clustal format"
    puts "\t- ord : ordalie format"
    puts ""
    puts "With an ORD input file, the key -instance <n> is compulsory : number in the list (1 : Original alignment) or label (M5 for \"M5 - ...\") of the instance to be converted. A wrong value lists the instances. An ORD output file keeps all the instances."
    puts ""
    puts "If the key -output is not specified, the output file will have the same name as the input file with an extension corresponding to the required format."
    puts ""

    exit
}


# Name under which the program was launched (ordalie, msainfo, msaconvert,
# msacut, viewtree, viewpdb ...), i.e. the name of the symbolic link.
# From the sources, $argv0 is that link. In a starpack, $argv0 is
# <link>/main.tcl (the startup script inside the mounted executable), so
# the name is the directory part ; [info nameofexecutable] is the link
# itself, not resolved.
proc NomDuProgramme {} {
    set prog [file tail $::argv0]
    if {$prog eq "main.tcl"} {
	set prog [file tail [file dirname $::argv0]]
	if {$prog eq ""} {
	    set prog [file tail [info nameofexecutable]]
	}
    }
    # Windows : msainfo.exe -> msainfo
    if {[string tolower [file extension $prog]] eq ".exe"} {
	set prog [file rootname $prog]
    }
    return $prog
}

# -instance <n> of msacut, msaconvert and msainfo : the instance of an ORD
# file to be treated, compulsory with an ORD file (it holds several
# alignments). <n> is the number of the instance in the list of the
# instance bar (1 : Original alignment) or its label (M5 for "M5 - ..."). Removes the key from
# Largs and keeps the value in ::SpinoffInstance, used by
# SpinoffChoisitInstance once the ORD file is read.
proc SpinoffInstance {prog Largs} {
    set ::SpinoffInstance ""
    set fileIn [lindex $Largs 0]
    set Lreste [list $fileIn]
    for {set i 1} {$i < [llength $Largs]} {incr i} {
	if {[lindex $Largs $i] eq "-instance"} {
	    set ::SpinoffInstance [lindex $Largs [incr i]]
	} else {
	    lappend Lreste [lindex $Largs $i]
	}
    }

    set isORD [expr {[string tolower [file extension $fileIn]] eq ".ord"}]
    if {$isORD && [string trim $::SpinoffInstance] eq ""} {
	puts "\nError !\n$fileIn is an ORD file, which holds several instances (alignments) :\nthe key '-instance <n>' is required, <n> being the number of the instance in the list (1 : Original alignment) or its label (M5 for \"M5 - ...\").\nA wrong value lists the instances of the file.\n"
	exit 1
    }
    if {! $isORD && $::SpinoffInstance ne ""} {
	puts "\nWarning !\n'-instance' is only used with ORD files : ignored.\n"
	set ::SpinoffInstance ""
    }

    return $Lreste
}


# Called by UpdateFromOrdaliDB before the instance is loaded (CreeVue) :
# the instance given by -instance becomes the current one.
# puts, even when msaconvert silenced the messages (TaisToi)
proc SpinoffPuts {msg} {
    if {[info commands ::putsCmdOriginale] ne ""} {
	::putsCmdOriginale $msg
    } else {
	puts $msg
    }
}


proc SpinoffChoisitInstance {} {
    if {! [info exists ::SpinoffInstance] || $::SpinoffInstance eq ""} {
	return
    }
    set v $::SpinoffInstance
    set Lpk {}
    set Lnm {}
    foreach {pk nm} [$::db eval {select pk_snap, name from snapshot}] {
	lappend Lpk $pk
	lappend Lnm $nm
    }
    set i -1
    if {[string is entier -strict $v] && $v >= 1 && $v <= [llength $Lpk]} {
	set i [expr {$v - 1}]
    } else {
	# the label of the instance : first word of its name (M5 in
	# "M5 - Kinetoplatids"). The whole name can not be given : the
	# command line is split on spaces.
	set i [lsearch -exact -nocase [lmap nm $Lnm {lindex [split $nm " "] 0}] $v]
    }
    if {$i == -1} {
	SpinoffPuts "\nError !\nInstance >$v< does not exist in this ORD file. Its instances are :"
	set k 0
	foreach nm $Lnm {
	    SpinoffPuts "   [incr k] : $nm"
	}
	SpinoffPuts ""
	exit 1
    }
    LesDefauts IxMacCourant [lindex $Lpk $i]
    LesDefauts NmMacCourant [lindex $Lnm $i]

    return
}

proc InterpreteArgv0 {{Ligne ""}} {
    regsub -all { +} [string trim $Ligne] " " Ligne
    set Largs [split $Ligne " "]

    set prog [NomDuProgramme]
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
	    set Largs [SpinoffInstance $prog $Largs]
	    set Ligne [MSAInfoOptions $Largs]

	    #TaisToi 1
	}
	"msacut" {
	    set ::env(ORDALIEONWEB) 1
	    #TaisToi 1
	    set Largs [SpinoffInstance $prog $Largs]
	    set Ligne [MSACutOptions $Largs]
	}
	"msaconvert" {
	    set Largs [SpinoffInstance $prog $Largs]
	    set Ligne [MSAConvertOptions $Largs]
	    set fileIn [lindex $Ligne 0]
	    set ::env(ORDALIEONWEB) 1
	    TaisToi 1
	    #set ligne "$fileIn -exit 1 -exe SauveLAlignement $format $fileOut"
	}
    }
    
    return $Ligne
}









