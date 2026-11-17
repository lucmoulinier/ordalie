proc LanceAreaimol {f1 f2} {

    set o [open cmd.csh w]
    puts $o "setccp4"
    puts $o "areaimol xyzin $f1 xyzin2 $f2 xyzout out.pdb <<eof > outfile"
    puts $o "diffmode compare"
    puts $o "pntden 100"
    puts $o "output"
    puts $o "end"
    puts $o "eof"
    puts $o "exit"
    close $o
    
    catch {exec tcsh cmd.csh} Msg
    if {$Msg ne ""} {
	#puts "Msg : $Msg"
    }
    if {! [file exists outfile]} {
	return 0
    } else {
	return [LesLignesDuFichier outfile]
    }
}


proc EnleveHeader {L} {
    set ia [lsearch -regexp $L {^ATOM  }]
    if {$ia != -1} {
	set L [lrange $L $ia end]
    }
    
    return $L
}


proc CreePDBPourSurface {pdbid} {
    global DCpt ListePDB

    # fait le menage
    foreach nom {outfile out.pdb AllAtoms.pdb Cmp.pdb} {
	if {[file exists $nom]} {
	    file delete -force $nom
	}
    }

    # Bilan des chaines
    set Lc [$pdbid _chains]
    set AOT [list]
    foreach c $Lc {
	if {[BonNomPDB ${pdbid}_$c] ni $ListePDB} {
	    continue
	}
	if {[$pdbid _chainIs $c] eq "Protein"} {
	    lappend AOT $c
	}
    }
    if {[llength $AOT] < 2} {
	puts "Une seule chaine ! Pas d'interface !"
	return
    }
    
    # fichier avec tout
    set f1 "AllAtoms.pdb"
    $pdbid save all all all 0 AllAtoms.pdb

    # enleve prot une par une
    set Head ""
    foreach c $Lc {
	set Lgc [$pdbid save $c all all 0 ListeEnRetour]
	set Cl($c) [EnleveHeader $Lgc]
	if {$Head eq ""} {
	    set Head [lor $Lgc [set Cl($c)]]
	}
	set Cl($c) [lrange [set Cl($c)] 0 end-1]
    }
    puts "Chains to be removed : $AOT"

    foreach caot $AOT {
	puts "\nExcluding chain : --> $caot <--"
	unset -nocomplain TB Srf
	set Ltot $Head
	foreach c $Lc {
	    if {$c eq $caot} {continue}
	    lappend Ltot {*}[set Cl($c)]
	    lappend Ltot "TER    "
	}
	lappend Ltot "END   "
	set f2 "Cmp.pdb"
	set o [open $f2 w]
	puts $o [join $Ltot \n]
	close $o

	set res [LanceAreaimol $f1 $f2]
	set Lres [ParseOutputAreaimol $res]
	unset -nocomplain Srf
	array set Srf $Lres

	# Nettoie output
	# Garde si bonne chaine, et si diff > 1 A2
	set NbS 0
	unset -nocomplain TB
	foreach e [lsort [array names Srf]] {
	    lassign [split $e ,] chn rnmr
	    if {$chn ni $AOT} {continue}
	    if {abs([set Srf($e)]) < 29.} {continue}
	    incr NbS
	    set nmr [DonnePosSG [BonNomPDB ${pdbid}_$chn] $rnmr]
	    foreach g [array names DCpt] {
		if {$nmr in [set DCpt($g)]} {
		    lappend TB($g) $nmr
		}
	    }
	}
	puts "Nbr res interface : $NbS"
	foreach g [array names TB] {
	    puts "$g [llength [set TB($g)]] [llength [set DCpt($g)]]"
	}
	puts ""
    }

    return
}


proc ParseOutputAreaimol {Ll} {
    global ASAaa ASAan

    if {[info exists ASAaa]} {
	InitASA
    }

    set Li [lsearch -all -regexp $Ll {^ ANALYSIS OF ACCESSIBLE AREA}]
    set pas -1
    foreach idx $Li {
	incr pas
	
	set i -1
	foreach l [lrange $Ll ${idx}+4 end] {
	    incr i
	    if {[regexp {^ TOTAL AREA} $l]} {
		break
	    }
	    if {! [regexp {^     } $l]} {continue}
	    
	    set l [string trim $l]
	    regsub -all { +} $l " " l
	    foreach {a c n v} $l {
		if {! $pas} {
		    set SrfI($c,$n) $v
		} else {
		    set SrfO($c,$n) $v
		}
	    }
	}
    }
    set Ll [lrange $Ll ${i}+1 end]

    set i [lsearch -regexp $Ll {^ Differences for individual chains}]
    set Ll [lrange $Ll $i+4 end]
    set i -1
    foreach l $Ll {
	incr i
	if {[regexp {^ TOTAL AREA} $l]} {
	    break
	}
	if {! [regexp {^     } $l]} {continue}

	set l [string trim $l]
	regsub -all { +} $l " " l
	foreach {a c n v} $l {
	    set SrfD($c,$n) $v
	}
    }

    puts "SrfI [llength [array names SrfI]]"
    puts "SrfO [llength [array names SrfO]]"
    puts "SrfD [llength [array names SrfD]]"
    foreach e [lsort [array names SrfD]] {
	set v [expr {[set SrfI($e)] - [set SrfD($e)]}]
	set Srf($e) $v
    }
    
    puts ""

    return [array get Srf]
}


proc PatchEtChapelet {} {




    return
}

