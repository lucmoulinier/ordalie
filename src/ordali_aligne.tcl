

#
# --- ordali_align.tcl
#



proc AlignSeqsAgainstReference {LNAddSeq LSAddSeq LNomsAli LSeqsAli} {
    # create a TFA from reference
    set aliTfa {}
    foreach n $LNomsAli s $LSeqsAli {
	set n [string trim $n]
	if {$n ne ""} {
	    set s [string map {. -} $s]
	    lappend aliTfa ">$n" $s
	    if {[set i [string first "O" $s]] > -1} {
		puts "$n contains O [string range $s $i-5 $i+5]"
	    }
	}
	}
	set aliTfa [join $aliTfa "\n"]
    
    # create a TFA with seqs to be added
    set addTfa {}
    foreach n $LNAddSeq s $LSAddSeq {
	set s [string map {. "" - ""} $s]
	    lappend addTfa ">$n" $s
	}
    set addTfa [join $addTfa "\n"]
    
    # create MAFFT alignement
    # the local MAFFT is preferred : the DDBJ server may not answer
    if {[MafftLivre] eq "" && [OutsideCSTB] && [auto_execok mafft] eq ""} {
	if {[catch {Mafft_AddSequences $aliTfa $addTfa} LnewAli]} {
	    puts "ERROR in Mafft_AddSequences : $LnewAli"
	    set LnewAli ""
	}
    } else {
	set LnewAli [Mafft_AddSequences_local $aliTfa $addTfa]
    }
    
    if {$LnewAli eq ""} {
	FaireLire "Something went wrong while computing alignment (is MAFFT installed ?) !\nSequences will be added unaligned"
	return ""
    }

    DecortiqueUnTFA $LnewAli LNAligned SAligned
    set LSAligned {}
    foreach n $LNAligned {
	lappend LSAligned $SAligned($n)
    }
    set LTAligned [array get SAligned]
    
    return [list $LNAligned $LSAligned $LTAligned]
}


proc RealignSequencesThatChangeEST_MIEUX_DANS_ordali_affiche {Lns} {
    global LNOrdali LSOrdali
    
    # Lns = name seq name seq ...
    # All sequences already belong to the alignment
    # but the sequence itself has changed

    set Lali {} ; set Lnew {}
    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}
	lappend Lali $n $s
	
	if {[info exists T($n)]} {
	    set n "tUrLu_$n"
	    lappend Lnew $n $T($n)
	}
    }

    if {[MafftLivre] eq "" && [llength $LNOrdali] < 300} {
	set Ltfa [Mafft_AddSequences $Lali $Lseq]
    } else {
	set Ltfa [Mafft_AddSequences_local $Lali $Lseq]
    }
    DecortiqueUnTFA $Ltfa LAligned SAligned
    set LSOrdali {}
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {
	    set sadd $s
	} elseif {! [info exists T($n)]} {
	    set sadd $SAligned($n)
	} else {
	    set nw "tUrLu_$n"
	    set sadd $SAligned($nw)
	}
	lappend LSOrdali $sadd
	set Sequences($n) $sadd
    }
    
    return
}


proc AligntSeulContreTous {nm seq} {
    global OrdTmpDir

    set In1  [file join ${OrdTmpDir} [pid]_tmp1]
    set In2  [file join ${OrdTmpDir} [pid]_tmp2]
    set Out  [file join ${OrdTmpDir} [pid]_tmp2g]
    set Log  [file join ${OrdTmpDir} [pid]_tmp3]

    CreeLeTfa $In1

    set f [open $In2 w]
    puts $f ">$nm"
    set D 0
    while {$D < [string length $seq]} {
	set F [expr {$D + 59}]
	set L [string range $seq $D $F]
	puts $f "$L"
	incr D 60
    }
    close $f

    BatchClustalwProfile $In1 $In2 $Out $Log -outorder=input

    set tmp [DecortiqueUnMSF $Out NomSeq LesSeqAli]
    set LNewSeqAli [array get LesSeqAli]
    catch {file delete -force $In1 $In2 $Log $Out}

    return $LNewSeqAli
}


proc CalculeAligntContreGlobal {seqref seqatester mol} {

    global OrdTmpDir

    regsub -all {\.} $seqref "-" seqref

    set In1  [file join ${OrdTmpDir} [pid]_tmp${mol}1]
    set In2  [file join ${OrdTmpDir} [pid]_tmp${mol}2]
    set Out  [file join ${OrdTmpDir} [pid]_tmp2${mol}g]
    set Log  [file join ${OrdTmpDir} [pid]_tmp3]
    set f [open $In1 w]

    puts $f ">seqref"
    set D 0
    while {$D < [string length $seqref]} {
	set F [expr {$D + 59}]
	set L [string range $seqref $D $F]

	puts $f "$L"
	incr D 60
    }
    close $f

    set f [open $In2 w]

    puts $f ">seqtest"
    set D 0
    while {$D < [string length $seqatester]} {
	set F [expr {$D + 59}]
	set L [string range $seqatester $D $F]

	puts $f "$L"
	incr D 60
    }
    close $f

    BatchClustalwProfile $In1 $In2 $Out $Log -outorder=input
    set tmp [DecortiqueUnMSF $Out NomSeq LesSeqAli]
    catch {file delete -force $In1 $In2 $Out $Log}

    return [set LesSeqAli(seqtest)]
}


proc CalculeAlignt {seqatester seqref chn mol} {

    global Sequences
    global LNOrdali
    global OrdTmpDir

    if {![regexp -nocase {[A-Z]} $seqref]} {
	set nomseq [lindex $LNOrdali $seqref]
	set laseqrefgap  [set Sequences($nomseq)]
    } else {
	set laseqrefgap [set Sequences($seqref)]
    }

    regsub -all {\.} $laseqrefgap "" laseqref
    regsub -all " " $laseqref "" laseqref
    regsub -all {\-} $laseqref "" laseqref
    regsub -all " "  $seqatester "" laseqatester
    regsub -all {\.}  $laseqatester "" laseqatester

    set file [string trim "[pid]_tmp${mol}$chn"]
    set In  [file join ${OrdTmpDir} $file]
    set file [string trim "[pid]_tmp2${mol}$chn"]
    set Out [file join ${OrdTmpDir} $file]
    set file [string trim "[pid]_tmp3${mol}$chn"]
    set Log [file join ${OrdTmpDir} $file]

    set f [open $In w]

    puts $f ">seqref"
    set D 0
    while {$D < [string length $laseqref]} {
	set F [expr {$D + 59}]
	set L [string range $laseqref $D $F]

	puts $f "$L"
	incr D 60
    }

    puts $f ">seqtest"
    set D 0
    while {$D < [string length $laseqatester]} {
	set F [expr {$D + 59}]
	set L [string range $laseqatester $D $F]

	puts $f "$L"
	incr D 60
    }
    close $f

    BatchClustalw $In $Out $Log -nopgap -nohgap -outorder=input

    set LesLignes [LesLignesDuFichier $Log]

    set score 0
    foreach ligne $LesLignes {
	if {[string first "Sequences (1:2)" $ligne] == "0"} {
	    scan [string range $ligne 31 end] "%d" score
	}
    }

    file delete -force $In $Log

    return $score
}



proc BlastallExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./blastall"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "blastall"]
	} else {
	    return "/bips/bin/blastall"
	}
    } else {
	set lexe [file join $OrdBinDir "blastall.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc BallastExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./ballast"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "ballast"]
	} else {
	    return "/biolo/ballast/bin/ballast"
	}
    } else {
	set lexe [file join $OrdBinDir "ballast.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc FastacmdExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./fastacmd"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "fastacmd"]
	} else {
	    return "/biolo/ncbi/bin/fastacmd"
	}
    } else {
	set lexe [file join $OrdBinDir "fastacmd.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc ClustalwExe {} {
    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./clustalw"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "clustalw"]
	} else {
	    return "/biolo/clustal/bin/clustalw"
	}
    } else {
	set lexe [file join $OrdBinDir "clustalw.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc RascalExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./rascal"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    #	    return [file join $OrdBinDir "rascal"]
	    return "/biolo/rascal/rascal"
	} else {
	    return "/biolo/rascal/rascal"
	}
    } else {
	set lexe [file join $OrdBinDir "rascal.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc LeonExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./leon"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "leon"]
	} else {
	    return "/biolo/leon/leon"
	}
    } else {
	set lexe [file join $OrdBinDir "leon.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc NorMDExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./normd"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "normd"]
	} else {
	    return "/biolo/normd/normd"
	}
    } else {
	set lexe [file join $OrdBinDir "normd.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}


proc MacsimsExe {} {

    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./macsim"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "macsim"]
	} else {
	    return "/biolo/macsim/macsim"
	}
    } else {
	set lexe [file join $OrdBinDir "macsim.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}



proc BatchClustalw {args} {

    global tcl_platform
    global OrdTmpDir
    global OrdaliDir

    if {[llength $args] != 0 } {
	set in1 [file tail [lindex $args 0]]
	set out [file tail [lindex $args 1]]
	set log [file tail [lindex $args 2]]

	set Argmt [join [lrange $args 3 end] " "]

	set tmpadel [file join $OrdTmpDir "tmp*"]
	file delete -force $tmpadel
	file delete -force $log
	file delete -force $out.msf

	set DndName [file join $OrdTmpDir "${in1}.dnd"]

	set Commande "[ClustalwExe] $in1 -output=gscope $Argmt >&  $log"
	if {[regexp -nocase "windows" $tcl_platform(platform)]} {
	    regsub -all " -" $Commande " /" Commande
	}

	cd $OrdTmpDir
	eval exec $Commande
	file delete -force $DndName
	file rename -force "${in1}.msf" [SigneFichier "$in1.msf"]
	cd $OrdaliDir
    }

    return
}



proc BatchClustalwProfile {args} {

    global tcl_platform
    global OrdTmpDir
    global OrdaliDir

    if {[llength $args] != 0 } {
	set In1 [file tail [lindex $args 0]]
	set In2 [file tail [lindex $args 1]]
	set Out [file tail [lindex $args 2]]
	set log [file tail [lindex $args 3]]

	set Argmt [join [lrange $args 4 end] " "]

	set tmpadel [file join $OrdTmpDir "tmp*"]
	file delete -force $tmpadel
	file delete -force $log
	file delete -force $Out.msf

	set DndName "${In2}.dnd"

	set Commande  "[ClustalwExe] -profile1=$In1 -profile2=$In2 -outfile=$Out -output=gscope $Argmt >& $log"
	if {[regexp -nocase "windows" $tcl_platform(platform)]} {
	    regsub -all " -" $Commande " /" Commande
	}

	cd $OrdTmpDir
	eval exec $Commande
	file delete -force $DndName
	cd $OrdaliDir
    }

    return
}



