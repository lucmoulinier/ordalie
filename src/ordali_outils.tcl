

#
# --- ordali_outils.tcl
#


proc CreateTitleFont {} {
    if {"TitleFont" in [font names]} {
	return
    }

    toplevel .tmp
    #wm withdraw .tmp
    pack [label .tmp.l]
    set ft [.tmp.l cget -font]
    destroy .tmp

    set size [font configure $ft -size]
    if {$size < 0} {
	incr size -2
    } else {
	incr size 2
    }

    set family [font configure $ft -family]

    font create TitleFont -family $family -size $size -weight bold

    return
}


proc CheckOpen {f} {
    if {[catch {set o [open $f w]}]} {
	if {[ModeI]} {
	    FaireLire "Warning !\n The file >$f< can not be written ! Check permissions."
	}
	set o ""
    }
    
    return $o
}


proc RepresentantDeTaxId {t} {
    global TDesTaxId TDesOrganismes LNOrdali
    
    set Lrep {}
    foreach n $LNOrdali {
	if {$n eq ""} {continue}

	if {$TDesTaxId($n) == $t} {
	    lappend Lrep $n
	}
    }

    return $Lrep
}


proc Phylum {Classe} {

    set Phylum "Unknown"
    set Phylum [string trim [string toupper $Classe]]

    if {[regexp "^ARCHAEA" $Phylum]}   {return "ARCHAEA"}
    if {[regexp "^BACTERIA" $Phylum]}  {return "BACTERIA"}
    if {[regexp "^EUKARYOTA" $Phylum]} {return "EUKARYOTA"}

    return "PhylumUnknown $Classe"
}


proc BonNomPDB {acc} {
    set Aori $acc

    if {[string range $acc 0 1] eq "::"} {
	set acc [string range $acc 2 end]
    }
    if {[regexp -nocase {^PDB} $acc]} {
	set acc [string range $acc 3 end]
    }
    # separator left by the prefix (PDB_1ABC). A letter is not one :
    # Q9BW92_A is a UniProt access, not 9BW9
    if {[regexp {^[^0-9a-zA-Z]} $acc]} {
	set acc [string range $acc 1 end]
    }
    if {[EstUnAccessPDB [string range $acc 0 3]]} {
	set Id [string range $acc 0 3]
    } else {
	return $Aori
    }

    if {[string length $acc] > 4} {
	if {! [regexp {[0-9a-zA-Z]} [string index $acc 4]]} {
	    set Ch [string range $acc 5 end]
	} else {
	    set Ch [string range $acc 4 end]
	}
    } else {
	set Ch ""
    }

    set Id [string toupper $Id]
    set nom "PDB_${Id}_$Ch"

    return $nom
}


proc DonneIdDeAccessPDB {access} {
    if {[string range $access 0 3] eq "PDB_"} {
	set access [string range $access 4 end]
    }

    set u [string last "_" $access]
    if {$u == -1} {
	return $access
    } else {
	return [string range $access 0 $u-1]
    }
}


proc DonneChainDeAccessPDB {access} {
    if {[string range [string toupper $access] 0 3] eq "PDB_"} {
	set access [string range $access 4 end]
    }

    set u [string first "_" $access]
    if {$u == -1} {
	if {[string length $access] == 5} {
	    return [string index $access 4]
	} else {
	    return ""
	}
    } else {
	# there is an underscore after XXXX
	set c [string index $access $u+1]
	if {[regexp {_| } $c]} {
	    return ""
	} else {
	    return $c
	}
    }
}


proc EnleveVersionDeAccess {acc} {
    if {[set i [string first "." $acc]] != -1} {
	set suf [string range $acc $i+1 end]
	if {[string is integer -strict $suf]} {
	    set acc [string range $acc 0 $i-1]
	}
    }

    return $acc
}


proc EnlevePrefixeBank {l} {
    # Remove the database prefix of a sequence name or access,
    # e.g. "sw|P12345" -> "P12345" (from EnlevePrefixeBank of
    # gscope_sequence.tcl, which this one overrides).
    # - done only if Defauts(RemoveBankPrefix) is set,
    # - prefixes are listed in Defauts(PrefixesBank) and compared
    #   whatever their case ; separator is '|' or ':' ('_' is not
    #   one : it would cut SwissProt identifiers as ABC_HUMAN),
    # - a leading 'lcl|' is always removed (even if prefixes
    #   are not removed), then the bank prefix if any,
    # - the PDB prefix is kept (PDB sequences are recognized by it),
    # - the prefix is removed only if followed by a letter (as
    #   in gscope), and only once,
    # - a leading '>' (fasta header) is kept.
    set s ""
    if {[string index $l 0] eq ">"} {
	set s ">"
	set l [string range $l 1 end]
    }
    if {[string equal -nocase -length 4 $l "lcl|"]} {
	set l [string range $l 4 end]
    }

    if {! [info exists ::Defauts(RemoveBankPrefix)] || ! $::Defauts(RemoveBankPrefix)} {
	return "$s$l"
    }

    set Lpref {}
    if {[info exists ::Defauts(PrefixesBank)]} {
	set Lpref $::Defauts(PrefixesBank)
    }
    foreach b $Lpref {
	if {[string equal -nocase $b "PDB"]} {
	    continue
	}
	set n [string length $b]
	if {! [string equal -nocase -length $n $l $b] || \
		[string index $l $n] ni {"|" ":"} || \
		! [string is alpha -strict [string index $l $n+1]]} {
	    continue
	}
	set l [string range $l $n+1 end]
	break
    }

    return "$s$l"
}


proc EstUnAccessPDBVOIR_DANS_GSCOPE_SEQUENCES {Access} {

    set Access [EnlevePrefixeBank $Access]

    if {! [regexp -nocase {^[0-9][a-z0-9]{3}_.{0,1}$} $Access]} {return 0}
    if {[regexp -nocase {_[0-9a-z]{3,}} $Access] } { return 0}

    return 1
}


proc PlusLongEltDe {l {quoi "lgt"} {strict 0}} {
    set max -1
    set val ""
    set iv -1
    set i 0
    foreach e $l {
	if {$strict} {
	    set e [string trim $e]
	}
	set v [string length $e]
	if {$v > $max} {
	    set max $v
	    set val $e
	    set ix $i
	}
	incr i
    }

    switch $quoi {
	"lgt" {return $max}
	"val" {return $val}
	"idx" {return $ix}
    }
}


proc EventNullPourNoms {} {
    global NomNomSeq

    $NomNomSeq insert 1.0 "x"
    $NomNomSeq delete 1.0
    $NomNomSeq edit separator

    return
}


proc EventNullPourSeqs {} {
    global NomTextSeq

    $NomTextSeq insert 1.0 "x"
    $NomTextSeq delete 1.0
    $NomTextSeq edit separator

    return
}


proc TamponNFois {quoi {n ""}} {
    global Tampon

    set res 1
    switch $quoi {
	"init" {set Tampon ""}
	"ajoute" {
	    if {! [string is integer $n]} {return}
	    append Tampon $n
	}
	"vide" {
	    if {$Tampon ne ""} {
		set res $Tampon
		set Tampon ""
	    }
	}
    }

    return $res
}


proc CompareNoms {TxtA TxtB} {

    set t1 [string range $TxtA [expr {[string first " " $TxtA]+1}] end]
    set t2 [string range $TxtB [expr {[string first " " $TxtB]+1}] end]

    if {$t1 >  $t2} {return  1}
    if {$t1 == $t2} {return  0}
    if {$t1 <  $t2} {return -1}
}


proc CouleurDeci2Int {c} {
    foreach e $c {
	lappend l [expr {int($e*255)}]
    }

    return $l
}


proc CouleurInt2Deci {c} {
    lassign $c r g b
    if {! [string is integer $r]} {return $c}

    set r [format "%4.2f" [expr {double($r)/255.}]]
    set g [format "%4.2f" [expr {double($g)/255.}]]
    set b [format "%4.2f" [expr {double($b)/255.}]]

    return [list $r $g $b]
}


proc CouleurInt2Hexa {c {base 32}} {
    lassign $c r g b
    if {$base == 64} {
	return [format "\#%04x%04x%04x" $r $g $b]
    } else {
	return [format "\#%02x%02x%02x" $r $g $b]
    }
}


proc CouleurDeci2Hexa {c} {
    set c [CouleurDeci2Int $c]
    return [CouleurInt2Hexa $c]
}


proc CouleurHexa2Int {c} {
    set c [CouleurHexa2Deci $c]
    return [CouleurDeci2Int $c]
}


proc CouleurHexa2Deci {c} {
    if {[string length $c] == 7} {
	set base 32
	set r [string range $c 1 2]
	set g [string range $c 3 4]
	set b [string range $c 5 6]
    } elseif {[string length $c] == 13} {
	set base 64
	set r [string range $c 1 4]	
	set g [string range $c 5 8]
	set b [string range $c 9 12]
    }

    return [list [Hexa2Deci $r $base] [Hexa2Deci $g $base] [Hexa2Deci $b $base]]
}


proc CouleurPlusProcheDeTkCol {col} {
    global TkCol

    if {! [info exists TkCol]} {
	InitTkCol
    }

    if {[regexp -nocase {^#([0-9a-f]{6}|[0-9a-f]{12})$} $col]} {
	lassign [CouleurHexa2Deci $col] rc gc bc
    } elseif {[llength $col] == 3} {
	lassign $col rc gc bc
    } else {
	if {[set i [lsearch -nocase $::ListeTkCol $col]] == -1} {
	    return -1
	} else {
	    return [lindex $::ListeTkCol $i]
	}
    }

    set ncol ""
    set dr 9999. ; set dg 9999. ; set db 9999.
    foreach a [array names TkCol] {
	lassign [set TkCol($a)] r g b
	set rr [expr {abs($r-$rc)}]
	set gg [expr {abs($g-$gc)}]
	set bb [expr {abs($b-$bc)}]
	if {$rr <= $dr && $gg <= $dg && $bb <= $db} {
	    set dr $rr ; set dg $gg ; set db $bb
	    set ncol $a
	}
    }

    return $ncol
}


proc RGBDeLaTkCol {name} {
    if {[string index $name 0] eq "#"} {
	return [CouleurHexa2Deci $name]
    } elseif {$name eq "couldefond"} {
	return [RGBDeLaTkCol [set ::Defauts(CoulVariable)]]
    } else {
	if {! [info exists ::TkCol]} {
	    InitTkCol
	}
	set name [string map [list " " _] $name]
	return [CouleurInt2Deci [set ::TkCol($name)]]
    }
}


proc RGBDeLaCouleur {c} {
    global Lookup_Couleurs

    set r [lindex [set Lookup_Couleurs($c)] 0]
    set r [string trim [format "%x" $r]]
    set r "$r[string repeat "0" [expr {4-[string length $r]}]]"

    set g [lindex [set Lookup_Couleurs($c)] 1]
    set g [string trim [format "%x" $g]]
    set g "$g[string repeat "0" [expr {4-[string length $g]}]]"

    set b [lindex [set Lookup_Couleurs($c)] 2]
    set b [string trim [format "%x" $b]]
    set b "$b[string repeat "0" [expr {4-[string length $b]}]]"

    set hrgb "#$r$g$b"

    return $hrgb
}


proc TestPckFastme {aT} {
    upvar $aT T
    global auto_path

    lappend auto_path [file join home moumou fastme1.1]
    package require fastme

    set Ln [array names T]
    foreach e $Ln {
	set Le [join [split $e ,]]
	lappend Lnom {*}$Le
    }
    set Lnom [lsort -unique $Lnom]

    foreach n1 $Lnom {
	foreach n2 $Lnom {
	    lassign [set T($n1,$n2)] pc l1 l2 lsl
	    lappend Ldst [expr {1.-$pc}]
	}
    }

    set rep [fastme $Lnom $Ldst]
    puts $rep

    return
}


proc WriteDistanceTable {f {aT ""}} {
    if {$aT ne ""} {
	upvar $aT T
    } else {
	array set T [array get ::TDesPCI]
    }

    set foo [CheckOpen $f]
    if {$foo eq ""} {
	FaireLire "Warning !\nUnable to open file >$f< for writing. Please check permissions."
	
	return
    }

    set Ln [array names T]
    foreach e $Ln {
	set Le [split $e ,]
	lappend Lnom {*}$Le
    }
    set Lnom [lsort -unique $Lnom]
    set pl [PlusLongEltDe $Lnom]

    puts $foo [format "%5d" [llength $Lnom]]
    foreach n1 $Lnom {
	set ent [format "%${pl}s" $n1]
	set i 0
	foreach n2 $Lnom {
	    lassign [set T($n1,$n2)] pc l1 l2 lsl
	    set dst [expr {1.-$pc}]
	    append ent [format "%8.4f" $dst]
	    incr i
	    if {$i == 8} {
		puts $foo $ent
		set ent [string repeat " " $pl]
		set i 0
	    }
	}
	puts $foo $ent
    }
    close $foo

    return
}


proc LogPCI {{what "global"} {OnlyStats 0}} {
    global LTPCI TPCI ListePDB LNDG SDG

    if {! [info exists LTPCI]} {
	puts "Error in LogPCI ! pas de LTPCI !"
	return
    }

    if {$what eq "all"} {
	# output for all groups
	set LdesG $LNDG
    } elseif {$what eq "global"} {
	set LdesG "GroupeToutLeMonde"
    } else {
	set LdesG [lrange $LNDG 1 end]
	if {$LdesG == {}} {
	set LdesG "GroupeToutLeMonde"
	}	    
    }

    if {! [info exists TPCI]} {
	array set TPCI $LTPCI
    }

    set Lkeys [array names TPCI]
    set lg [PlusLongEltDe $Lkeys]
    incr lg 3

    array set TRes {}
    set TRes(ListeG) $LdesG
    foreach g $LdesG {
	set txt {}
	set Ln [set SDG($g)]
	set nseq [llength $Ln]
	if {$g eq "GroupeToutLeMonde"} {
	    set g "All"
	}
	set TRes($g,nseq) $nseq
	if {$nseq < 2} {
	    set TRes($g,mean) 0.0
	    set TRes($g,std) 0.0
	    set TRes($g,max) ""
	    set TRes($g,min) ""
	    set TRes($g,vals) {}
	    
	    continue
	}

	# Moyenne generale, std dev.
	# min et max
	set min 999. ; set max -999.
	set pmn "" ; set pmx ""
	set m 0.0 ; set m2 0.0
	set i 1 ; set npairs 0
	foreach n1 [lrange $Ln 0 end-1] {
	    foreach n2 [lrange $Ln $i end] {
		set pc [lindex $TPCI($n1,$n2) 0]
		set pc [expr {100.*$pc}]
		lappend txt [format "%${lg}s %6.1f" "$n1 - $n2" $pc]

		if {[string first "PDB_" $n1] == -1 && [string first "PDB_" $n2] == -1} {
		    set m  [expr {$m + $pc}]
		    set m2 [expr {$m2 + $pc*$pc}]
		    incr npairs

		    if {$pc > $max} {
			set max $pc
			set pmx [format "%${lg}s %6.1f" "$n1 - $n2" $max]
		    }
		    if {$pc < $min} {
			set min $pc
			set pmn [format "%${lg}s %6.1f" "$n1 - $n2" $min]
		    }
		}
	    }
	    incr i
	}

	if {$npairs != 0} {
	    set m [expr {$m/$npairs}]
	    set var [expr {$m2/$npairs - $m*$m}]
	    if {$var > 0.0} {
		set s [expr {sqrt($var)}]
	    } else {
		    set s -1.0
	    }
	} else {
	    # npairs = 0
	    set m 0.0
	    set s 0.0
	}
	set TRes($g,mean) [format %6.1f $m]
	set TRes($g,std) [format %6.1f $s]
	set TRes($g,max) $pmx
	set TRes($g,min) $pmn
	set TRes($g,vals) $txt
    }

    # create results table
    AuLog @begin table
    AuLog @title Summary of sequences identities :
    AuLog @begin tabular
    AuLog @titlecols Group "Nbr sequences" Mean "Std. Dev." Highest Smallest
    AuLog @typecols T I R R T T 
    foreach g $TRes(ListeG) {
	if {$g eq "GroupeToutLeMonde"} {
	    set g "All"
	}
	set ligne [list $g $TRes($g,nseq) $TRes($g,mean) $TRes($g,std) $TRes($g,max) $TRes($g,min)]
	AuLog @row {*}$ligne
    }
    AuLog @end
    AuLog @end
    AuLog @text "Note: PDB sequences are not taken into account for mean and standard deviation calculations."
    AuLog @text ""
    
    # print each pairs if required
    if {! $OnlyStats} {
	foreach g $TRes(ListeG) {
	    if {$g eq "GroupeToutLeMonde"} {
		continue
	    }
	    AuLog @subtitle Details for $g , $TRes($g,nseq) sequences
	    AuLog @pre ""
	    for {set i 0} {$i < [llength $TRes($g,vals)]} {incr i 5} {
		AuLog @pre [join [lrange $TRes($g,vals) $i $i+4]]
	    }
	    AuLog @pre ""
	}
	AuLog @text ""
    }

    return
}


proc CalculeLesPCIDuMac {} {
    global TDesPCI LTPCI LNOrdali LSOrdali

    set SAli {}
    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] ne ""} {
	    lappend SAli $n $s
	}
    }

    set LTPCI [CalculeLesPCIGenerique $SAli]
    
    array set TDesPCI $LTPCI

    return $LTPCI
}


proc CalculeLesPCIGenerique {Lnmsq {aTPCI ""} {symmetric 1}} {
    if {$aTPCI ne ""} {
	upvar $aTPCI TPCI
    } else {
	global TPCI

	unset -nocomplain TPCI
	array set TPCI {}
    }
    
    set LNom {} ; set LSeq {}
    foreach {n s} $Lnmsq {
	lappend LNom $n
	lappend LSeq $s
    }
    
    if {[set ::Defauts(UseSpeedCode)] eq "C"} {
	# compute the half-matrix by default
	set Lpci [Ccode_Pairwise $LSeq]

	set ix 0 ; set j 1
	foreach n1 [lrange $LNom 0 end-1] {
	    foreach n2 [lrange $LNom $j end] {
		set TPCI($n1,$n2) [lindex $Lpci $ix]
		incr ix
	    }
	    incr j
	}
	
	if {$symmetric} {
	    foreach k [array names TPCI] {
		lassign [split $k ,] n1 n2
		set TPCI($n2,$n1) [set TPCI($k)]
	    }
	    foreach n $LNom s $LSeq {
		set l [string length [string map {"\." ""} $s]]
		set TPCI($n,$n) [list 1.0 $l $l 1.0]
	    }
	}
    } else {
	# compute PCI in pure Tcl

	set LLgr {}
	foreach s $LSeq {
	    lappend LLgr [string length [string map {"." ""} $s]]
	}
	
	set i 1
	foreach n1 $LNom s1 $LSeq l1 $LLgr {
	    set TPCI($n1,$n1) [list 1.0 $l1 $l1 1.0]
	    foreach n2 [lrange $LNom $i end] s2 [lrange $LSeq $i end] l2 [lrange $LLgr $i end] {
		set pcid [NRIdentite $s1 $l1 $s2 $l2]
		set LsurL [expr {$l1<$l2?1.0*$l1/$l2:1.0*$l2/$l1}]
		set TPCI($n1,$n2) [list $pcid $l1 $l2 $LsurL]
		set TPCI($n2,$n1) [list $pcid $l2 $l1 $LsurL]
	    }
	    incr i
	}
    }

    set LTPCI {}
    set LTPCI [array get TPCI]
    
    return $LTPCI
}


proc CalculeLesPCI {{d ""} {f ""} {Lseq1 ""} {Lseq2 ""} {Reset 0}} {
    global PLesSeqs PLesLong PLesNoms TDesPCI LNOrdali LSOrdali

    if {$d eq ""} {set d 0}
    if {$f eq ""} {set f "end"}

    FaireAttendre "Please wait ...\nComputing pairwise identities ..."

    # Longueur doivent etre reel pour que
    # Identite (entier) / longueur (reel) soit reel

    if {$Reset || ! [info exists PLesNoms]} {
	unset -nocomplain PLesNoms PLesSeqs PLesLong PNomSeq
	# no sequence with residues in the columns : empty lists
	set PLesNoms {} ; set PLesSeqs {} ; set PLesLong {}
	foreach n $LNOrdali s $LSOrdali {
	    if {[string trim $n] eq ""} {continue}

	    set s [string range $s $d $f]
	    set l [string length [string map {"." "" " " "" "Z" ""} $s]]
	    if {$l == 0} {continue}
	    set ls [split $s ""]
	    lappend PLesLong $l
	    lappend PLesSeqs ${ls}
	    lappend PLesNoms $n
	}
    }

    if {$Lseq1 eq ""} {
	set LNSqDep $PLesNoms
	set LLgsDep $PLesLong
	set LSeqDep $PLesSeqs
    } else {
	foreach s1 $Lseq1 {
	    lappend LNSqDep $s1
	    set iseq1 [lsearch $PLesNoms $s1]
	    lappend LLgsDep [lindex $PLesLong $iseq1]
	    lappend LSeqDep [lindex $PLesSeqs $iseq1]
	}
    }
    
    if {$Lseq2 ne ""} {
	foreach s2 $Lseq2 {
	    lappend LNSqArr $s2
	    set iseq2 [lsearch $PLesNoms $s2]
	    lappend LLgsArr [lindex $PLesLong $iseq2]
	    lappend LSeqArr [lindex $PLesSeqs $iseq2]
	}
    } else {
	set LNSqArr $PLesNoms
	set LLgsArr $PLesLong
	set LSeqArr $PLesSeqs
    }

    set LsurL 0.
    array set T {}
    set ListePCI {}
    foreach n1 $LNSqDep l1 $LLgsDep s1 $LSeqDep {
	foreach n2 $LNSqArr l2 $LLgsArr s2 $LSeqArr {
	    if {[info exists T($n1,$n2)] || [info exists T($n2,$n1)]} {
		continue
	    }
	    if {$n1 eq $n2} {
		lappend ListePCI [list $n1 $n2 1.0 $l1 $l2 1.]
		set TDesPCI($n1,$n2) [list "1.0" $l1 $l2 "1."]
		set T($n1,$n2) [list "1.0" $l1 $l2 "1."]
	    } elseif {! $l1 || ! $l2} {
		lappend ListePCI [list $n1 $n2 0.0 $l1 $l2 -1]
		set TDesPCI($n1,$n2) [list -1.0 $l1 $l2 -1]
		set TDesPCI($n2,$n1) [list -1.0 $l1 $l2 -1]
		set T($n1,$n2) [list -1.0 $l1 $l2 -1]
		set T($n2,$n1) [list -1.0 $l1 $l2 -1]
	    } else {
		set pcid [NRIdentite $s1 $l1 $s2 $l2]
		set LsurL [expr {$l1>$l2?1.0*$l1/$l2:1.0*$l2/$l1}]
		lappend ListePCI [list $n1 $n2 $pcid $l1 $l2 $LsurL]
		lappend ListePCI [list $n2 $n1 $pcid $l2 $l1 $LsurL]
		set TDesPCI($n1,$n2) [list $pcid $l1 $l2 $LsurL]
		set TDesPCI($n2,$n1) [list $pcid $l2 $l1 $LsurL]
		set T($n1,$n2) [list $pcid $l1 $l2 $LsurL]
		set T($n2,$n1) [list $pcid $l2 $l1 $LsurL]
	    }
	}
    }

    FaireLaSuite

    return $ListePCI
}


proc LeNombreDuResidu {r} {

    if {[regexp {^[0-9]} $r]} {
	set ler $r
    } else {
	set ler [string range $r 1 end]
    }

    return $ler
}


proc DefinitNomMolecule {nom} {

    set idxp [lindex [regexp -indices -inline {[0-9]} $nom] 0]
    set idxa [string first "." $nom]
    set molid [string range $nomtmp $idxp $idxa]

    return $molid
}


proc DecortiqueUneFeature {f as ae ac ar an {acs ""} {atar ""}} {
    upvar $as s $ae e $ac c $ar r $an n $acs cs $atar tgt

    # start stop col score note csys terget

    lassign $f fs s fp e fc c fo r fn n fcs cs fta tgt

    return
}


proc NextResDuPdb {res chn mol} {

    set Lres [$mol _resnumber -chain $chn -polymer]
    set ires [lsearch $Lres $res]
    set deb  [lindex $Lres $ires+1]

    return [list $deb [expr {$ires+1}]]
}


proc PreviousResDuPdb {res chn mol} {

    set Lres [$mol _resnumber -chain $chn -polymer]
    set ires [lsearch $Lres $res]
    set fin [lindex $Lres $ires-1]

    return [list $fin [expr {$ires-1}]]
}


proc CombleSSParCoil {Lss molid chn} {
    set molid [string toupper $molid]
    set LesRes [$molid _resnumber -chain $chn -polymer]

    # create lookups pdb <-> index
    set i -1
    foreach res $LesRes {
	incr i
	set Lpi($res) $i
	set Lip($i) $res
    }
    set iLast $i
    
    set Ldf {}
    foreach ss $Lss {
	DecortiqueSS $ss Elt chn nmr1 nmr2 rmk
	lappend Ldf [list $Lpi($nmr1) $Lpi($nmr2)]
    }

    # No sec. struc., all is coil
    if {$Ldf == {}} {
	lappend Lss "Coil xxx xxx $chn [lindex $LesRes 0] xxx [lindex $LesRes end] xxx"
	return $Lss
    }
    set Ldf [lsort -unique -index 0 -integer $Ldf]

    set endPrev -1
    foreach cpl $Ldf {
	lassign $cpl start end
	#puts "start $start end $end"
	if {($start - 1) != $endPrev} {
	    set ideb [expr {$endPrev + 1}]
	    set ifin [expr {$start - 1}]
	    lappend Lss "Coil xxx xxx $chn $Lip($ideb) xxx $Lip($ifin) xxx"
	}
	set endPrev $end
    }
    if {$endPrev != $iLast} {
	set ideb [expr {$endPrev + 1}]
	set ifin $iLast
	lappend Lss "Coil xxx xxx $chn $Lip($ideb) xxx $Lip($ifin) xxx"
    }	
    
    return $Lss
}


proc CombleSSParCoil2 {{lss {} } molid chn} {

    set LesRes [$molid _resnumber -chain $chn -polymer]
    set 1ResPDB [lindex $LesRes 0]
    set i1ResPDB 0
    set DResPDB [lindex $LesRes end]
    set iDResPDB [expr {[llength $LesRes]-1}]
    set df {}

    foreach s $lss {
	lassign $s Elt a z e Nm1 r Nm2 t q 
	lappend df [list $Nm1 $Nm2]
    }

    if {$df == {}} {
	lappend df "Coil xxx xxx $chn $1ResPDB xxx $DResPDB xxx"
	return $df
    }
    
    set i1ResSS [lsearch $LesRes [lindex [lindex $df 0] 0]]
    if {$i1ResSS > 0} {
	lassign [PreviousResDuPdb [lindex [lindex $df 0] 0] $chn $molid] finc fini 
	lappend lss "Coil xxx xxx $chn $1ResPDB xxx $finc"
    }

    lassign [NextResDuPdb [lindex [lindex $df 0] 1] $chn $molid] debc debi 
    foreach cpl [lrange $df 1 end] {
	lassign [PreviousResDuPdb [lindex $cpl 0] $chn $molid] finc fini 
	if {$fini - $debi >= 0} {
	    lappend lss "Coil xxx xxx $chn $debc xxx $finc xxx"
	}
	lassign [NextResDuPdb [lindex $cpl 1] $chn $molid] debc debi 
    }
    
    if {$debc ne ""} {
	if {$iDResPDB - $debc >= 0} {
	    lappend lss "Coil xxx xxx $chn $debc xxx $DResPDB xxx"
	}
    }

    #    return [lsort -integer -index 4 $lss]
    return $lss
}


proc StockNomSeqAssPDB {Win PDBin SeqSel} {
    global LNOrdali NomEtSeqAssPDB Defauts

    if {[ModeI]} {
	if {[llength $SeqSel] != 1} {
	    FaireLire "You must choose only ONE sequence !!"
	    return
	}

	destroy $Win
    }

    if {[info exists NomEtSeqAssPDB]} {
	set SeqSel [lindex $LNOrdali $SeqSel]
	foreach ligne $NomEtSeqAssPDB {
	    scan $ligne "%s %s %s" pdb seq molid
	    if {$seq == $SeqSel} {
		FaireLire "Sequence $SeqSel has already a PDB file \n attached to it"
		return
	    }
	}
    }

    set molid [DefinitNomMolecule $PDBin]
    set NomSeqAss "$PDBin $SeqSel $molid"
    lappend NomEtSeqAssPDB $NomSeqAss

    AssigneStructure

    return
}


proc Equivalence {seq} {
    global LNOrdali

    set test [string toupper $seq]
    set Idx [lsearch $LNOrdali $test]
    if {$Idx != -1} {return $Idx}

    set test [string tolower $seq]
    set Idx [lsearch $LNOrdali $test]
    if {$Idx != -1} {return $Idx}

    FaireLire "Error ! No associated sequence !"

    return
}


proc DetruitVariablesSaufDepart {} {
    global VariablesAuDepart

    set Lv [info globals]
    foreach v $Lv {
	if {$v eq "VariablesAuDepart"} {continue}
	if {$v in $VariablesAuDepart} {continue}
	global $v
	unset -nocomplain $v
    }

    return
}


proc FermeFenetresDuFichier {} {
    # Closes the windows showing data of the current file.
    # 3D viewer and overviews have their own cleanup (the 3D viewer
    # needs the structure objects : call this before destroying them)
    if {[info exists ::pgl(wogl)]} {
	catch {QuitteViandox}
    }
    if {[info exists ::Ovw(Liste)]} {
	catch {DetruitOverview}
    }
    # tree objects (their windows are destroyed below)
    if {[info exists ::Abr(ListeArbres)]} {
	foreach t $::Abr(ListeArbres) {
	    catch {$t destroy}
	}
    }
    if {[info exists ::EFeat(SumWindow)] && [winfo exists $::EFeat(SumWindow)]} {
	catch {RetourFeatSummary}
    }
    # any other toplevel, except the main window, menus and
    # the waiting windows
    foreach w [winfo children .] {
	if {[winfo toplevel $w] ne $w || [winfo class $w] eq "Menu"} {
	    continue
	}
	if {$w eq $::NomFenetreOrdali || $w in {.fattendre .wroom}} {
	    continue
	}
	catch {destroy $w}
    }

    return
}


proc TitreFenetreOrdali {} {
    # main window title : "<file> - Ordalie <version>",
    # "Ordalie <version>" when no file is loaded
    global Defauts VersionDeOrdali

    if {[TypeAli] ne "pasdali"} {
	set file [file tail [set Defauts(Fichier[TypeAli])]]
	set wtitle "$file - Ordalie $VersionDeOrdali"
    } else {
	set wtitle "Ordalie $VersionDeOrdali"
    }

    return $wtitle
}


proc FermeFichier {{DoSave "nosave"}} {
    global NomNomSeq NomTextSeq VariablesAuDepart db Defauts CompteurDeMac AliOutputFormat AliOutputFile

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {[InSeqlabMode]} {
	FaireLire "Please leave Editor Mode first !"

	return
    }

    # DoSave = <save | nosave>
    if {$DoSave eq "save" && ([VueEditee] || [FichierModifie])} {
	set chx [tk_dialog .chx "Warning" "Warning !\nThis alignment has not been saved !\nDo you want to save it before closing it ?" "" 0 "Yes" "No" "Cancel"]
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

    update idletasks
    if {[ModeI]} {
	# windows showing the closed file
	FermeFenetresDuFichier

	bindtags $NomNomSeq {}
	bindtags $NomTextSeq {}
    }

    catch {$db close}
    set CompteurDeMac 0
    # annotations of the closed file
    unset -nocomplain ::AnnoMac ::Anno
    # nothing left to save
    VueEditee 0
    FichierModifie 0
    # all the structures of the file, not only those of the displayed
    # instance (ListePDB) : a structure left here would be saved in the
    # ORD of the next file opened (CreeLeORD saves every instance of the class)
    foreach Obj [info class instances Structure] {
	$Obj destroy
    }
    update
    DetruitInfoSeqs

    if {[ModeI]} {
	$NomNomSeq  configure -state normal
	$NomNomSeq clean

	foreach b [bind $NomNomSeq] {
	    bind $NomNomSeq $b ""
	}
	bindtags $NomNomSeq [list $NomNomSeq Biotext . all]
	$NomNomSeq configure -state disabled

	$NomTextSeq configure -state normal
	$NomTextSeq clean
	bindtags $NomTextSeq $NomTextSeq
	foreach b [bind $NomTextSeq] {
	    bind $NomTextSeq $b ""
	}
	bindtags $NomTextSeq [list $NomTextSeq Biotext . all]
	$NomTextSeq configure -state disabled

	# ruler
	$::WTexteRegle configure -state normal
	catch {$::WTexteRegle clean}
	$::WTexteRegle configure -state disabled
    }

    # remember if we arrive as interactive or batch mode
    # (the value of Defauts(Mode), "Interactive" or other : ModeI
    # returns 0/1, restoring that value made ModeI false for ever)
    set Mode [set Defauts(Mode)]

    #DetruitVariablesSaufDepart
    foreach v {Sequences LNOrdali LSOrdali LNSeqlab LSSeqlab TabSF LNDG SDG ListeTypesDeFeatures TColScore AliOutputFormat AliOutputFile Abr Ovw ScoreMeth ListeScores GroupeDeLaSequence HashPDB LTPCI TPCI LesNomsDesSeqOri LesPoidsDesSequences LesSeqsDuGroupe ListeDesMacs NomsAffiches SeqOri TEdit Warn nseqCurr EFeat StrucAVoir Liste3dMol ZoneSelect ZonePCI ZoneSuperposition EquivalenceZone Anno Clus Chrc LFeatCourantes PLesNoms PLesSeqs PLesLong ListeSeqsGroupees PileModes TDesCompos TypeSeq} {
	global $v
	unset -nocomplain $v
    }
    # log and print data of the closed file
    set ::TexteDuLog ""
    foreach k {LNoms LSeqs LNOri} {
	unset -nocomplain ::PrmPrt($k)
    }

    LesDefauts
    LesDefauts Mode $Mode

    if {[ModeI]} {
	$::WOrdali(combomac) configure -values {}
	set ::MacChoisi ""
	unset -nocomplain ::ActionObj ::SeqsOut
	wm title [winfo toplevel $::NomFenetreOrdali] [TitreFenetreOrdali]
	DetruitBoutonsOrdali
	AfficheBoutonsOrdali
	LesDefauts dispmode "ordali"
    }

    # inits ...
    set ::Threshold [set Defauts(Threshold)]
    set ::ListeTypesDeFeatures {}
    set ::NomSeqSel {}
    set ::BufferSeq {}
    set ::LongueurTotale 0
    set ::ListeTypesDeFeatures {}
    set ::ListePDB {}
    array set ::TabSF {}
    set ::BufNTimes ""

    DefinitionPreferences
    InitialiseCouleurs
    PrintSetup "defauts"

    update

    return
}


proc DonneListeCleValeur {options} {
    # take argument list and return a list with 
    # key-value pairs in all cases

    if {! [llength $options]} {
	return {}
    }

    regsub -all { +} [string trim $options] " " options
    set Le [split $options]
    set tmp {}
    set Lkv [lindex $Le 0]
    foreach e [lrange $Le 1 end] {
	if {[string index $e 0] eq "-"} {
	    lappend Lkv $tmp
	    set tmp {}
	    lappend Lkv $e
	} else {
	    lappend tmp $e
	}
    }
    lappend Lkv $tmp

    return $Lkv
}


proc ReordonneOptions {opts} {
    # Re-order options so that some are first

    set ix [lsearch $opts "-outfile"]
    if {$ix > -1} {
	set v [lindex $opts $ix+1]
	set opts [lreplace $opts $ix $ix+1]
	set opts [concat "-outfile" $v $opts]
    }

    return $opts
}

    
proc InterpreteLaLigneDeCommande {Ligne} {
    global env AExecuter APutser Defauts
    
    set AExecuter ""
    set APutser ""
    
    # Pour Julie, enleve les = au cas ou ...
    set Ligne [string map {= " "} $Ligne]
    regsub -all { +} $Ligne " " Ligne
    set Ligne [string trim $Ligne]
    
    set Ligne [InterpreteArgv0 $Ligne]    

    if {$Defauts(ShowOrdalieHeader)} {
	Espionne "---------------------------------------------------"
	Espionne "[DonneDateEtHeure]"
	Espionne "Program : $::argv0"
	Espionne "options : $::argv"
	Espionne "---------------------------------------------------"
	Espionne ""
    }

    # No arguments
    if {$Ligne eq ""} {
	return
    }

    set Arg1 [lindex [split $Ligne " "] 0]
    set Val1 [lindex [split $Ligne " "] 1]

    #####################
    # ADMIN Ordali :
    # 
    # On ne load ni packages tcl ou tk.
    # On execute et puis exit
    if {$Arg1 eq "admin"} {
	puts [eval {*}[lrange [split $Ligne " "] 1 end]]

	exit
    }

    #LoadTclPackages
    namespace path {::tcl::mathop ::tcl::mathfunc}

    # from GSCOPE : puts et exe
    if {$Arg1 eq "puts"} {
	package require Tk
	ChangeTkOptions
	set reponse [eval {*}[lrange [split $Ligne " "] 1 end]]
	TaisToi 0
	puts $reponse

	exit
    }

    if {$Arg1 eq "exe"} {
	LesDefauts Mode batch
	LoadTclPackages

	eval {*}[lrange [split $Ligne " "] 1 end]

	return "dansexe"
    }

    # manage project, 
    if {$Arg1 eq "project"} {
	if {$Val1 eq ""} {
	    FaireLire "Please supply a project name !"
	    exit
	}

	LoadTkAndPackages
	CheckForProject $Val1

	return "stop"
    }
    
    # traite help
    if {[string tolower $Arg1] eq "help"} {
	set Ligne "-ordalihelp 1"
    }

    # Treat sequence file
    if {[file exists $Arg1]} {
	set ftype [file extension $Arg1]
	switch $ftype {
	    ".macsim" -
	    ".xml"  {set type "xml"}
	    ".tfa" -
	    ".tfasta" -
	    ".fasta" {set type "tfa"}
	    ".msf"  {set type "msf"}
	    ".aln"  {set type "aln"}
	    ".rsf"  {set type "rsf"}
	    ".ord"  {set type "ord"}
	    default {set type [FormatDuFichierSequence $Arg1]}
	}

	if {$type ne ""} {
	    set Ligne "-$type $Ligne"
	}
    }
    
    # bad argument
    # at this point, all arguments should start with 
    # a '-' character
    if {[string index $Ligne 0] ne "-"} {
	FaireLire "\"$Ligne\" is not recognized or does not exists !"

	return
    }

    # Traite les arguments. Sont maintenant tous sous
    # forme de paire cle-valeur
    set Liste [DonneListeCleValeur $Ligne]
    set Liste [ReordonneOptions $Ligne]
    set ix 0 
    foreach {e v} $Liste {
	set e [string tolower $e]

	switch $e {
	    "-puts" {
		#puts [eval $v]
		set APutser $v
	    }
	    "-exe" {	    
		if {[string length $AExecuter]} {
		    append AExecuter " ; "
		}
		append AExecuter $v
		set extra [string trim [join [lrange $Liste $ix+2 end]]]
		if {$extra ne ""} {
		    append AExecuter " $extra"
		}
	    }
	    "-outfile" {
		set outfile $v
	    }
	    "-selnom" {
		LesDefauts SelectionNom $v
	    }
	    "-time" {
		LeTempsDesProcs
	    }
	    "-showss" {
		LesDefauts AffSS $v
	    }
	    "-downloadpdb" {
		switch $v {
		    "0" {set what "dont"}
		    default {set what "internet"}
		}
		LesDefauts DownloadPDB $what
	    }
	    "-echoproc" {
		echoProc $v
	    }
	    "-balibase" {
		LesDefauts Balibase $v
		LesDefauts CheckSeq 0
		LesDefauts AffSS 1
	    }
	    "-precompute" {
		LesDefauts PreCompute $v
	    }
	    "-msf" {
		set FichierMSF $v
		LesDefauts FichierMSF $FichierMSF
		LesDefauts TypeAli MSF
	    }
	    "-rsf" {
		# RSF format disabled
		FaireLire "The RSF format is not supported anymore !"
		return
		#set FichierRSF $v
		#LesDefauts FichierRSF $FichierRSF
		#LesDefauts TypeAli RSF
	    }
	    "-tfa" {
		set FichierTFA $v
		LesDefauts FichierTFA $FichierTFA
		LesDefauts TypeAli TFA
	    }
	    "-xml" {
		set FichierXML $v
		LesDefauts FichierXML $FichierXML
		LesDefauts TypeAli XML
	    }
	    "-ord" {
		set FichierORD $v
		LesDefauts FichierORD $FichierORD
		LesDefauts TypeAli ORD
	    }
	    "-aln" {
		set FichierALN $v
		LesDefauts FichierALN $FichierALN
		LesDefauts TypeAli ALN
	    }
	    "-group" {
		if {[file exists $v] && [file extension $v] eq ".clu"} {
		    set TypeDeGroupesACreer "fichierclu"
		    LesDefauts FichierClu $v
		} else {
		    set TypeDeGroupesACreer $v
		}
		LesDefauts TypeDeGroupesACreer $TypeDeGroupesACreer
	    }
	    "-batch" {
		LesDefauts Mode Batch
		LesDefauts Exit 1
		LesDefauts LogAtStartup 0
	    }
	    "-mode" {
		LesDefauts Mode [string tolower $v]
		LesDefauts LogAtStartup 0
	    }
	    "-convert" {
		set fmt [string toupper $v]
		LesDefauts DownloadPDB dont
		LesDefauts Mode Batch
		LesDefauts Exit 1
		if {! [info exists outfile] || $outfile eq ""} {
		    set outfile JLeSauvveAs
		}
		set AExecuter "SauveLAlignement $fmt $outfile"
	    }
	    "-project" {
		LesDefauts InProject 1
		LesDefauts Project $v
	    }
	    "-genome" {
		LesDefauts IsGenome $v
	    }
	    "-devlpt" {
		LesDefauts Devlpt 1
	    }
	    "-run" {
		LesDefauts Run 1
	    }
	    "-dump" {
		if {$v ne ""} {
		    set FichierDump $v
		} else {
		    set FichierDump 1
		}
		LesDefauts Dump $FichierDump
	    }
	    "-exit" {
		LesDefauts Exit 1
	    }
	    "-checkseq" {
		LesDefauts CheckSeq $v
	    }
	    "-debug" {
		if {$v eq ""} {set v 1}
		LesDefauts Debug $v
	    }
	    "-clusdeb" {
		LesDefauts clusdeb $v
	    }
	    "-weight1" {
		LesDefauts Poids $v
	    }
	    "-record" {
		bind Button <1> {+Record %W %x %y}
		bind Menu <1> {+Record %W %x %y}
		bind Menubutton <1> {+Record %W %x %y}
		bind Radiobutton <1> {+Record %W %x %y}
		bind Checkbutton <1> {+Record %W %x %y}
	    }
	    "-weight2" {
		LesDefauts Poids2 $v
	    }	    
	    "-weight3" {
		LesDefauts Poids3 $v
	    }
	    "-savelog" {
		LesDefauts SaveLog $v
	    }
	    "-threshold" {
		set Threshold $v
		if {$v >= 51 && $v <= 100} {
		    LesDefauts Threshold $v
		}
	    }
	    "-pdb" {
		set Idx [lsearch $Liste "-pdb"]
		set FichierPDB [lindex $Liste [expr {$Idx+1}]]
		LesDefauts FichierPDB $FichierPDB
		set SeqAssocie [lindex $Liste [expr {$Idx+2}]]
		LesDefauts SeqAssocie $SeqAssocie
		LesDefauts PDB 1
	    }
	    "-view" {
		LesDefauts Visualize $v
		set FichierOMAC $v
		LesDefauts FichierOMAC $v
	    }
	    "-script" {
		if {[file exists $v]} {
		    LesDefauts RunScript 1
		    LesDefauts Script $v
		}
	    }
	    "-ordalihelp" {
		OrdalieHelpOnLine
		exit
	    }
	}

	incr ix 2
    }

    return
}


proc OrdalieHelpOnLine {} {
    puts " "
    puts "Usage :"
    puts "ordali <alignment file> ?option value? ?option value? ..."
    puts ""
    puts "Beware ! The input alignment file, if given, should always be the FIRST argument !"
    puts ""
    puts "Ordali on-line options are :"
    puts ""
    puts "  -precompute <0|1> : precompute clustering and conservation for each PFAM domain (default 1)"
    puts "  -threshold x : Set conservation threshold level. x should be set between 51 and 100"
    puts "  -batch <0|1> : run Ordali without windows and exit when finished (default 0)"
    puts " "
    return
}


proc ExtraitListeDeListe {l n} {

    set nl {}
    foreach e $l {
	lappend nl [lindex $e $n]
    }

    return $nl
}


proc ReLoadFichier {} {

    if {[TypeAli] == "pasdali"} {return}
    if {[QuelMode] == "seqlab"} {
	FaireLire "Leave Editor first !"
	return
    }

    set file "Fichier[TypeAli]"
    set ftype [TypeAli]
    global Defauts
    set vfile [set Defauts($file)]

    FermeFichier nosave
    OuvrirFichierAlignementDansOrdali $ftype $vfile

    return
}


proc DetecteTypeFichier {file} {

    set type ""
    set Ll [LesLignesDuFichier $file]
    set i 0
    while {[set l [string trim [lindex $Ll $i]]] eq ""} {
	incr i
    }
    set l [string tolower $l]
    switch -regexp $l {
	{^\<\?xml} {set type "xml"}
	{^!!RICH_} {set type "rsf"}
	{^SQLite}  {set type "ord"}
	{^CLUSTAL} {set type "aln"}
	{^\>}      {set type "tfa"}
	{^msf\: }  {set type "msf"}
    }

    if {$type eq ""} {
	set Lt [lrange $Ll 0 2000]
	set Ix [lsearch -regexp $Lt {MSF:.+Type:.+Check:.+\.\.}]
	if {$Ix != -1} {set type msf}
    }

    return $type
}


proc TypeAli {} {
    return [set ::Defauts(TypeAli)]
}


proc LockMode {l} {
    global ModeLocke

    if {! [info exists ModeLocke]} {set ModeLocke 0}
    set res $ModeLocke
    set ModeLocke $l

    return $res
}


proc InSeqlabMode {{what ""}} {
    if {$what ne ""} {
	set ::UseBiotext $what
    } else {
	if {! [info exists ::UseBiotext]} {
	    set ::UseBiotext 0
	}
	return $::UseBiotext
    }
}


proc QuelMode {{mode ""}} {

    if {$mode eq""} {
	return [set ::Defauts(dispmode)]
    } else {
	LesDefauts dispmode $mode
    }

    return
}


proc ModeI {} {
    global FaireLireNon Defauts

    if {[info exists Defauts(Mode)] && [set Defauts(Mode)] eq "Interactive"} {
	set FaireLireNon 0
	return 1
    } else {
	set FaireLireNon 1
	return 0
    }
}


proc Devlpt {} {

    if {[set ::Defauts(Devlpt)]} {
	return 1
    } else {
	return 0
    }
}


proc Debug {} {
    return [set ::Defauts(Debug)]
}


proc ExtraitYDesPos {liste} {

    foreach {p1 p2} $liste {
	lassign $p1 y x
	lappend ly $y
    }

    return $ly
}


proc TagsDuDump {d} {

    set Ltags {}
    set YaFnd 0
    set TOn 0
    set TOff 0
    set ld [split $d " "]
    foreach {k v i} $ld {
	if {$v eq "InvS"} {continue}
	if {$v eq "Fnd" && !$YaFnd} {
	    lappend Ltags $v 0 "end-1c"
	    set YaFnd 1
	}
	if {$k eq "tagon"} {
	    lassign [split $i "."] y1 x1 
	    set TOn 1
	}
	if {$k eq "tagoff"} {
	    lassign [split $i "."] y2 x2 
	    if {! $TOn} {set x1 -1}
	    lappend Ltags $v $x1 $x2
	    set TOn 0
	}
    }
    if {$TOn} {lappend Ltags $v $x1 "Fin"}

    return $Ltags
}


proc RecupereR {} {
    set rep ""
    if {! [eof $::CnlR]} {
	gets $::CnlR rep
    }
    if {[string first "TURLU" $rep] != -1} {
	set ::ReponseR $::tmp_RepR
	set ::tmp_RepR {}
    } else {
	lappend ::tmp_RepR $rep
    }

    return
}


proc Rclose {} {
    global SckR

    close $SckR(socket)
    unset -nocomplain SckR

    return
}


proc read_Rsock {} {
    global SckR

    # [eof $sock] == 1 || [catch {gets $sock l}] || $l == "\f"
    if {[eof $SckR(socket)] == 1} {
	puts "eof pout $SckR(socket)"
	fileevent $SckR(socket) readable {}
	catch {close $SckR(socket)}
    } else {
	set error 0
        while {[gets $SckR(socket) l] >= 0} {
            append SckR(tmp) "$l\n"	
            flush $SckR(socket)
	    if {! $error && [string first "Erreur :" $l] > -1} {
		set error 1
	    }
	}
        append SckR(tmp) $l
	
	if {$SckR(RDebug)} {
	    puts "get  tmp= $SckR(tmp)"
	}

	if {$error || [regexp "turlututu" $SckR(tmp)]} {
	    set tmp [set SckR(tmp)]
	    set SckR(tmp) ""
	    set SckR(Reponse) $tmp
	}
    }

    return
}


proc RpipeClean {} {
    Rpipe "rm(list = ls(all.names = T))"
    Rpipe "gc()"

    return
}


proc Rpipe {args} {
    if {[info exists ::fR]} {
	if {[lindex $args 0] ne "-verbose"} {
	    puts $::fR "[join $args]"
	} else {
	    puts $::fR "[join [lrange $args 1 end]]"
	}
    }

    # Sur ena/machines labo ;
    # module load R/R-3.6.1
    
    #
    # faire un :
    # package require Rtcl quelque part
    #::rtcl::eval -verbose $cmd

    return [::rtcl::eval {*}$args]
}


proc Rpipe_tmp {Cmd} {
    global SckR

    if {! [info exists SckR(socket)] || [eof $SckR(socket)]} {
	if {$Cmd eq "RClose"} {
	    return
	}

	# create socket connection
	unset -nocomplain SckR
	set rsHost "localhost"
	set rsPort 8888
	set SckR(socket) [socket $rsHost $rsPort]
	
	if {[eof $SckR(socket)] == 1} {
	    puts "probleme SckR !"
	    catch {close $SckR(socket)}	;# connection closed ... abort
	} else {
	    # socket opened
	    puts "R socket open : $SckR(socket)\n"
	    #fconfigure $SckR(socket) -buffering line 
	    fconfigure $SckR(socket) -buffering line -blocking 0
	    #fconfigure $SckR(socket) -buffering full -blocking 0
	    fileevent $SckR(socket) readable read_Rsock
	}
	set SckR(Reponse) ""
	set SckR(tmp) ""
	set SckR(RDebug) 0
    }
    if {$Cmd eq "RClose"} {
	puts $SckR(socket) "closeSocketClients(sockets = \"all\",  serverport = 8888)"
	catch {close $SckR(socket)}
	unset SckR

	return
    }
    if {$Cmd eq "RDebug"} {
	set SckR(RDebug) [expr {! $SckR(RDebug)}]

	return
    }

    append Cmd " ; print('turlututu');"
    if {$SckR(RDebug)} {
	puts "send Cmd= $Cmd"
    }
    puts $SckR(socket) "$Cmd"
    update idletasks
    flush $SckR(socket)
    vwait SckR(Reponse)

    set rep $SckR(Reponse)
    set SckR(Reponse) ""
    set SckR(tmp) ""

    set Lrep [split $rep "\n"]
    set i [lsearch -regexp $Lrep "turlututu"]
    if {$i != -1} {
	set Lrep [lreplace $Lrep $i $i]
    }
    set rep [join $Lrep \n]

    return $rep
}


proc Rpipe_working {Cmd} {
    global CnlR CnlRReady spawn_id

    set rep ""
    set prompt "turlututu> "
    if {! [info exists CnlR]} {
	#exp_internal 1
	exp_log_user 0
	switch $::tcl_platform(platform) {
	    unix {set Rexe R_surf}
	    windows {set Rexe [file join c:/ PROGRA~1 R R-2.15.2 bin i386 Rterm.exe]}
	}
	exp_spawn $Rexe --vanilla
	set CnlR $spawn_id
	exp_stty raw -echo
	set ready 0
	while {! $ready} {
	    expect -timeout 1000 "> " {set ready 1}
	}
	set opt "options(prompt='$prompt');"
	exp_send "$opt\n"
	while {[expect -ex "$opt"] ne ""} {
	    after 1000
	}
	while {[expect "$prompt"] ne ""} {
	    after 1000
	}
    }

    exp_send "$Cmd\n"
    while {[expect "$Cmd"] ne ""} {
	after 200
    }
    set rep "" ; set done 0
    while {! $done} {
	after 200
	expect $prompt {
	    append rep $expect_out(buffer)
	    set done 1
	}
    }

    set rep [string map [list \r ""] $rep]
    set rep [lrange [split $rep \n] 1 end-1]

    return $rep
}

proc Rpipe_old2 {Commande} {
    global CnlR ReponseR

    if {! [info exists CnlR]} {
	set CnlR [open "|R_surf --vanilla " r+]
	fconfigure $CnlR -blocking 0 -buffering none
	fileevent  $CnlR readable RecupereR
	puts $CnlR "# TURLUTUTU"
	flush $CnlR
	vwait ReponseR
	set ReponseR ""
    }

    puts  $CnlR $Commande
    puts  $CnlR "# TURLUTUTU"
    flush $CnlR
    vwait ReponseR

    return $ReponseR
}


proc RecupereR_old {} {
    global CnlR RecuperationEffectuee ReponseR ReponseR_prec

    set ReponseR_prec ""
    if {! [eof $CnlR]} {
	#gets $CnlR ReponseR_prec
	set ReponseR_prec [split [read -nonewline $CnlR] \n]
    }
    set ReponseR $ReponseR_prec
    return
    set iturlu [string first "TURLU" $ReponseR_prec]
    if {$iturlu != -1} {
	set RecuperationEffectuee 1
    } else {
	lappend ReponseR $ReponseR_prec
    }

    #puts "==>$ReponseR"

    return
}


proc Rpipe_old {Commande} {
    global CnlR RecuperationEffectuee ReponseR

    if {! [info exists CnlR]} {
	set CnlR [open "|R --vanilla " r+]
	fconfigure $CnlR -blocking 0 -buffering none
	fileevent $CnlR readable RecupereR
	
	puts $CnlR "# TURLUTUTU"
	flush $CnlR

	vwait RecuperationEffectuee
	unset RecuperationEffectuee
    }

    puts $CnlR "$Commande"
    flush $CnlR
    puts $CnlR "# TURLUTUTU"
    flush $CnlR

    vwait RecuperationEffectuee
    unset RecuperationEffectuee
    set rep $ReponseR
    set ReponseR ""

    return $rep
}


proc rpw {} {
    package require Expect
    if {$::tcl_platform(platform) eq "windows"} {
	set Rexe [file join c:/ PROGRA~1 R R-2.15.2 bin i386 Rterm.exe]
    } else {
	set Rexe "/biolo/R_surf/R-2.15.2/lib64/R/bin/R"
    }

    spawn $Rexe --vanilla

    expect -re "\>" {
	exp_send_user "on a prompt !"
	exp_send "# TURLUTUTU"
	puts "rep = $expect_out(buffer)"
    } eof {
	exp_send_user "eof !"
	break
    }

    return
}



proc tRp {} {
    #package require Tk
    package require Expect

    set txt [list 1.1 2.2 3.4]
    puts "Rpipe [Rpipe "print('[join $txt ,]')"]"
    puts "Rpipe [Rpipe "toto <- c([join $txt ,])"]"
    puts "Rpipe [Rpipe "(min(toto))"]"

    #exit

    set ListeVal [list 1.0 2.0 3.0 4.0 1.1 2.1 3.1 4.1 1.2 2.2 3.2 4.2 1.3 2.3 3.3 4.3]
    set NbRow   3
    set NbGagne 1
    set NbPerdu 1
    set NbNul   1
    set size 2
    set decay 0.0075

    Rpipe "All <- c([join $ListeVal ,])"
    Rpipe "All <- matrix(All,nrow=$NbRow)"
    Rpipe "fac  <- rep( factor( c('gagne', 'perdu','nul')), c($NbGagne,$NbPerdu,$NbNul))"
    Rpipe "library(nnet)"
    ## index des etiquettes
    Rpipe "T <- class.ind(fac)"
    ### size = taille couche cachee, decay= vitesse d'apprentissage, maxit = nbre iteration
    puts [Rpipe "model <- nnet(All,T,size=$size,decay=$decay,softmax=TRUE,maxit=500)"]
    
    exit
}


proc Recupere {Canal} {
    global LiaisonCoupee RecuperationEffectuee

    if {! [eof $Canal]} {gets $Canal Reponse}

    set iturlu [string first "TURLU" $Reponse]
    if {$iturlu != -1} {
	incr iturlu -1
	set Reponse [string range $Reponse 0 $iturlu]
	set RecuperationEffectuee 1
    }

    AuLog "$Reponse"

    if {[PlusDeRasMol]} {
	set RecuperationEffectuee 1
	set LiaisonCoupee 1
	close $Canal
    }

    return
}


proc SauveLesGlobal {} {
    global VariablesAuDepart

    set lesv [info globals]

    global LesGlobal

    foreach Variable $lesv {
	global $Variable
	if {[regexp "Glossaire" $Variable]} { continue }
	if {$Variable=="VariablesAuDepart"} { continue }
	if { ! [info exists $Variable]} { continue }
	if {[lsearch $VariablesAuDepart $Variable] != -1} {continue}
	if {[array exists $Variable]} {
	    lappend LesGlobal [PaqArray $Variable $Variable]
	} else {
	    lappend LesGlobal [PaqListe $Variable [set $Variable]]
	}
    }

    return
}


proc QuiSuisJe {} {
    global MoiJeSuis

    set alter [winfo children .]
    if {$alter != $MoiJeSuis} {
	BasculeVariables MoiJeSuis alter
	set MoiJeSuis $alter
    }

    return
}


proc ExtraitTable {type} {
    global OrdEtcDir

    set file [file join $OrdEtcDir "table_couleurs.dat"]
    set LesLignes [LesLignesDuFichier $file]
    if {$type eq "seqlab"} {set type "Protein"}
    set type ">$type"

    set idx1 [lsearch $LesLignes $type]
    set sear [expr {$idx1+1}]
    set idx2 [lsearch -regexp [lrange $LesLignes $sear end] ">"]
    if {$idx2 == -1} {set idx2 end}

    return [lrange $LesLignes $sear $idx2]
}


proc Stringinsert {astrg i v} {
    upvar $astrg s

    if {$i == "end" || $i > [string length $s]} {
	append s $v
    } elseif {$i < 0} {
	set s "${v}${s}"
    } else {
	set s [string range $s 0 $i]${v}[string range $s [expr {$i+1}] end]
    }

    return $s
}


proc PremierBlanc {s} {

    if {$s eq ""} {return "end"}
    set ib [string first " " $s]
    if {$ib == -1} {
	return "end"
    } else {
	return $ib
    }
}


proc OteLesBlancsEnTrop {r} {

    set r [string trim $r]
    regsub -all { +} $r " " r

    return $r
}


proc ReordonneNucleotide {Ln Lx Lb Lz} {

    set Ltot {}
    foreach n $Ln x $Lx b $Lb z $Lz {
	lappend Ltot [list $n $x $b $z]
    }

    # ordre : 
    # (03P) P O1P O2P O5' C5' C4' O4' C3' O3' 
    # C2' (O2') C1'
    set Lfin {}
    foreach a [list " O3P" " P  " " O1P" " O2P" " O5'" " C5'" " C4'" " O4'" " C3'" " O3'" " C2'" " O2'" " C1'"] {
	if {[set i [lsearch $Ltot $a]] != -1} {
	    lappend Lfin [lindex $Ltot $i]
	    lset Ltot $i ""
	}
    }
    foreach a $Ltot {
	if {$a != ""} {
	    lappend Lfin $a
	}
    }

    set Ln {} ; set Lx {}
    set Lb {} ; set Lz {}
    foreach e $Ltot {
	lassign $e a x b z
	lappend Ln $a
	lappend Lx $x
	lappend Lb $b
	lappend Lz $z
    }

    return [list $Ln $Lx $Lb $Lz]
}


proc ReordonneType {aTypes xtion {exc 0}} {
    upvar $aTypes Types

    if {! [regexp {^\.} $xtion]} {
	set fullxtion ".$xtion"
    } else {
	set fullxtion $xtion
    }
    set IdxYa 0
    foreach Type $Types {
	set Ext [lindex $Type 1]
	if {[regexp $fullxtion $Ext]} {
	    break
	}
	incr IdxYa
    }
    
    if {$IdxYa == [llength $Types]} {
	incr IdxYa -1
    }

    if {$exc} {
	set Types [list [lindex $Types $IdxYa] [lindex $Types end]]
    } else {
	set Types [linsert [lreplace $Types $IdxYa $IdxYa] 0 $Type]
    }

    return $Types
}


proc NettoieLeTmp {} {
    global OrdTmpDir

    foreach f [glob -nocomplain [file join $OrdTmpDir "[pid]_*"]] {
	catch {file delete -force $f}
    }

    return
}



proc SigneFichier {file} {

    if {[regexp "[pid]_" $file]} {
	regsub "[pid]_" $file "" nfile
    } else {
	set f "[pid]_[file tail $file]"
	set nfile [file join [file dirname $file] $f]
    }

    return $nfile
}


proc lupper {l} {
    return [lmap x $l {string toupper $x}]
    
    set o {}
    foreach e $l {
	lappend o [string toupper $e]
    }

    return $o
}


proc llower {l} {
    return [lmap x $l {string tolower $x}]
    
    set o {}
    foreach e $l {
	lappend o [string tolower $e]
    }

    return $o
}


proc lscan {liste elt} {

    set i 0
    foreach s $liste {
	if {[regexp $elt $s]} {lappend lhit $i}
	incr i
    }

    return $lhit
}


proc land {a b} {

    set la {}
    foreach e $a {
	set Vu($e) 1
    }
    foreach e $b {
	if {[info exists Vu($e)]} {
	    lappend la $e
	}
    }

    return $la
}


proc lor {a b {what "all"}} {
    if {$what eq "from1" || $what eq "all"} {
	foreach elt $b {
	    set tb($elt) 1
	}
	set l1 {}
	foreach elt $a {
	    if {! [info exists tb($elt)]} {
		lappend l1 $elt
	    }
	}
    }

    if {$what eq "from2" || $what eq "all"} {
	foreach elt $a {
	    set ta($elt) 1
	}
	set l2 {}
	foreach elt $b {
	    if {! [info exists ta($elt)]} {
		lappend l2 $elt
	    }
	}
    }

    switch $what {
	"from1" {return $l1}
	"from2" {return $l2}
	"all"   {return [concat $l1 $l2]}
    }
}


proc lequal {a b} {
    set rep 1
    foreach e $a f $b {
	if {$e != $f} {
	    set rep 0
	    break
	}
    }

    return $rep
}


proc lunique {l} {
    set res {}
    foreach e $l {
	if {! [info exists t($e)]} {
	    set t($e) 1
	    lappend res $e
	}
    }

    return $res
}


proc lsublist {l n} {
    set nl {}
    foreach e $l {
	lappend nl [lindex $e $n]
    }

    return $nl
}


proc DonneDoublons {l {uniques 1}} {
    set d {}
    foreach e $l {
	if {[info exists T($e)]} {
	    lappend d $e
	} else {
	    set T($e) 0
	}
    }

    if {$uniques} {
	return [lunique $d]
    } else {
	return $l
    }
}


proc DonneDateEtHeure {} {
    return [clock format [clock seconds] -format "%A, %d %B %Y %H\:%M\:%S"]
}


proc FindTclSecure {fic {dir "."}} {
    set LesTrouves {}

    if {[catch {set tmp [glob -nocomplain -- [file join $dir $fic]]}]} {
	return
    }
    set LesF [lsort $tmp]
    lappend LesTrouves {*}$LesF
    
    if {[catch {set tmp [glob -directory $dir -type d -nocomplain -- *]}]} {
	return
    }
    set Ld [lsort $tmp]
    foreach d $Ld {
	if {[file exists $d] && [file type $d] eq "link"} { continue }
	set LesR [FindTclSecure $fic $d]
	lappend LesTrouves {*}$LesR
    }

    return $LesTrouves
}


proc FindTclAll {fic {dir "."}} {
    global ResFind

    set r [glob -directory $dir -nocomplain -- $fic]
    if {$r != ""} {
	lappend ResFind $r
    }

    set Ld [glob -directory $dir -type d -nocomplain -- *]
    foreach dir $Ld {
	set r [FindTcl $fic $dir]
	if {$r != ""} {lappend ResFind {*}$r}
    }

    if {[info exists ResFind]} {
	return $ResFind
    } else {
	return ""
    }
}


proc LongueurAlignement {{quoi ""}} {
    # idem as 'LongueurDeLAlignement'
    #
    # ask seq 1 as sequences indices starts at 1 !
    #  Beware !
    # 'output' returns a list !
    set ::LongueurTotale [string length [lindex [$::NomTextSeq output 1] 0]]

    return $::LongueurTotale
}


proc LoadFontesAscii {} {
    global FontAsc OrdEtcDir

    set f [file join $OrdEtcDir FontesGif.asc]
    array set FontAsc [ContenuDuFichier $f]

    return
}


proc ImgDeNom {t fm sz md ang} {
    global FontAsc

    if {! [info exists FontAsc]} {LoadFontesAscii}
    if {$t eq ""} {return}
    set Lt [split $t ""]

    set x0  0
    set dst [image create photo]
    foreach c $Lt {
	if {![info exists FontAsc($fm,$sz,$md,$c)]} {set c " "}
	set phi [image create photo -data $FontAsc($fm,$sz,$md,$c)]
	set wdi [expr {[image width $phi]-3}]
	set hgi [image height $phi]
	set i $x0
	for {set p 3} {$p < $wdi} {incr p} {
	    for {set j 1} {$j < $hgi} {incr j} {
		if {! [$phi transparency get $p $j]} {
		    $dst put [eval format #%02x%02x%02x [$phi get $p $j]] -to $i $j
		}
	    }
	    incr i
	}
	incr x0 [expr {$wdi-3}]
    }

    OpacifieImage $dst white
    RotateImage $dst $ang
    OpacifieImage $dst white 1

    return $dst
}


proc RotateImage {img angle} {
    # angle en radians !
    set angle [expr {$angle*180./acos(-1)}]

    set angle [expr {fmod($angle, 360.0)}]
    if {$angle < 0} {set angle [expr {$angle + 360.0}]}
    if {$angle} {
	set w [image width  $img]
	set h [image height $img]
	set tmp [image create photo]
	$tmp copy $img
	$img blank
	set buf {}
	if {$angle == 90} {
	    # This would be easier with lrepeat
	    set row {}
	    for {set i 0} {$i<$h} {incr i} {
		lappend row "#000000"
	    }
	    for {set i 0} {$i<$w} {incr i} {
		lappend buf $row
	    }
	    set i 0
	    foreach row [$tmp data] {
		set j 0
		foreach pixel $row {
		    lset buf $j $i $pixel
		    incr j
		}
		incr i
	    }
	    $img config -width $h -height $w
	    $img put $buf
	} elseif {$angle == 180} {
	    $img copy $tmp -subsample -1 -1
	} elseif {$angle == 270} {
	    # This would be easier with lrepeat
	    set row {}
	    for {set i 0} {$i<$h} {incr i} {
		lappend row "#000000"
	    }
	    for {set i 0} {$i<$w} {incr i} {
		lappend buf $row
	    }
	    set i $h
	    foreach row [$tmp data] {
		set j 0
		incr i -1
		foreach pixel $row {
		    lset buf $j $i $pixel
		    incr j
		}
	    }
	    $img config -width $h -height $w
	    $img put $buf
	} else {
	    set a   [expr {atan(1)*8*$angle/360.}]
	    set xm  [expr {$w/2.}]
	    set ym  [expr {$h/2.}]
	    set w2  [expr {round(abs($w*cos($a)) + abs($h*sin($a)))}]
	    set xm2 [expr {$w2/2.}]
	    set h2  [expr {round(abs($h*cos($a)) + abs($w*sin($a)))}]
	    set ym2 [expr {$h2/2.}]
	    $img config -width $w2 -height $h2
	    for {set i 0} {$i<$h2} {incr i} {
		set toX -1
		for {set j 0} {$j<$w2} {incr j} {
		    set rad [expr {hypot($ym2-$i,$xm2-$j)}]
		    set th  [expr {atan2($ym2-$i,$xm2-$j) + $a}]
		    if {
			[set x [expr {$xm-$rad*cos($th)}]] < 0 || $x >= $w ||
			[set y [expr {$ym-$rad*sin($th)}]] < 0 || $y >= $h
		    } then {
			continue
		    }
		    set x0 [expr {int($x)}]
		    set x1 [expr {($x0+1)<$w? $x0+1: $x0}]
		    set dx_ [expr {1.-[set dx [expr {$x1-$x}]]}]
		    set y0 [expr {int($y)}]
		    set y1 [expr {($y0+1)<$h? $y0+1: $y0}]
		    set dy_ [expr {1.-[set dy [expr {$y1-$y}]]}]
		    # This is the fastest way to get the data, because
		    # in 8.4 [$photo get] returns a string and not a
		    # list. This is horrible, but fast...
		    scan "[$tmp get $x0 $y0] [$tmp get $x0 $y1]\
			    [$tmp get $x1 $y0] [$tmp get $x1 $y1]" \
			"%d %d %d %d %d %d %d %d %d %d %d %d" \
			r0 g0 b0  r1 g1 b1  r2 g2 b2  r3 g3 b3
		    set r [expr {round($dx*($r0*$dy+$r1*$dy_)+$dx_*($r2*$dy+$r3*$dy_))}]
		    set g [expr {round($dx*($g0*$dy+$g1*$dy_)+$dx_*($g2*$dy+$g3*$dy_))}]
		    set b [expr {round($dx*($b0*$dy+$b1*$dy_)+$dx_*($b2*$dy+$b3*$dy_))}]
		    lappend buf [format "#%02x%02x%02x" $r $g $b]
		    if {$toX == -1} {
			set toX $j
		    }
		}
		if {$toX>=0} {
		    $img put [list $buf] -to $toX $i
		    set buf {}
		    update
		}
	    }
	}
	image delete $tmp
    }
}


proc RotateTextImg2 {in angle {xc ""} {yc ""}} {
    # xi = + (x - s/2) * cos(-a) + (y - s/2) * sin(-a) + xc
    # yi = - (x - s/2) * sin(-a) + (y - s/2) * cos(-a) + yc

    # ATTENTION ! Angle Transmis est en radians !!!

    set width  [image width $in]
    set height [image height $in]
    set w2 [expr {$width / 2}]
    set h2 [expr {$height / 2}]

    if {$xc == ""} { set xc $w2 }
    if {$yc == ""} { set yc $h2 }

    set ww [expr {abs($width - $xc)}]
    if {$ww < $xc} { set ww $xc }
    set hh [expr {abs($height - $yc)}]
    if {$hh < $yc} { set hh $yc }

    set size [expr {round(sqrt($ww*$ww+$hh*$hh))}]
    set sx2 [expr {$size * 2}]
    set out [image create photo -width $sx2 -height $sx2]
    set pi2 [expr {acos(0)}]
    set alpha $angle
    #    set alpha [expr {$angle * $pi2 / 90.0}]
    set cos [expr {cos(-$alpha)}]
    set sin [expr {sin(-$alpha)}]
    for {set y 0} {$y < $sx2} {incr y} {
	for {set x 0} {$x < $sx2} {incr x} {
	    set x1 [expr {$x-$size}]
	    set y1 [expr {$y-$size}]
	    set x0 [expr {round(+$x1*$cos + $y1*$sin + $xc)}]
	    set y0 [expr {round(-$x1*$sin + $y1*$cos + $yc)}]
	    if {$x0 >= 0 && $x0 < $width && $y0 >= 0 && $y0 < $height} {
		if {![$in transparency get $x0 $y0]} {
		    set col [eval format #%2.2x%2.2x%2.2x [$in get $x0 $y0]]
		    $out put $col -to $x $y
		}
	    }
	}
    }

    return $out
}


proc OpacifieImage {img bg {trans 1}} {

    if {$trans} {
	set tmp [image create photo]
	$tmp put [$img data -background $bg]
	$img blank
	$img copy $tmp
	image delete $tmp
    } else {
	set rgb [winfo rgb . $bg]
	lassign $rgb r g b
	set rgb [list [expr {$r/256}] [expr {$g/256}] [expr {$b/256}]]
	set w [image width $img]
	set h [image height $img]
	set data [$img data]
	set i 0
	set j 0

	foreach Lp $data {
	    foreach p $Lp {
		if {[$img get $j $i] == $rgb} {
		    $img transparency set $j $i 1
		}
		incr j
	    }
	    set j 0
	    incr i
	}
    }

    return
}


proc RogneImage {img {bg "#ffffff"}} {
    set data [$img data -background $bg]
    set w [image width $img]
    set h [llength $data]

    set id 0
    foreach l $data {
	set c [regsub -all $bg $l "" tmp]
	if {$c == $w} {incr id} {break}
    }

    set if 0
    foreach l [lreverse $data] {
	set c [regsub -all $bg $l "" tmp]
	if {$c == $w} {incr if} {break}
    }

    set x 0
    for {set x 0} {$x < $w} {incr x} {
	set col {}
	foreach l $data {
	    lappend col [lindex $l $x]
	}
	lappend Idata $col
    }

    set il 0
    foreach l $Idata {
	set c [regsub -all $bg $l "" tmp]
	if {$c == $h} {incr il} {break}
    }

    set ir 0
    foreach l [lreverse $Idata] {
	set c [regsub -all $bg $l "" tmp]
	if {$c == $h} {incr ir} {break}
    }

    # nettoyage de l'image
    if {$id != 0} {set data [lreplace $data 0 [expr {$id-1}]]}
    if {$if != 0} {set data [lreplace $data "end-[expr {$if-1}]" end]}

    set new {}
    if {$il != 0} {
	set x [expr {8*$il}]
	foreach l $data {
	    lappend new [string range $l $x end]
	}
	set data $new
    }

    set new {}
    if {$ir != 0} {
	set x [expr {8*$ir}]
	foreach l $data {
	    lappend new [string range $l 0 end-$x]
	}
	set data $new
    }

    set w [regsub -all "#" [lindex $data 0] "" tmp]
    set h [llength $data]

    set t3 [image create photo -width $w -height $h]
    $t3 blank
    $t3 put $data
    set t4 [image create photo -width $w -height $h]
    $t4 blank
    $t4 copy $t3 -compositingrule set

    image delete $img $t3

    return $t4
}


proc image.create.xbm args {
    array set a $args

    if {[array names a -exact -file] ne {}} {
	set fid [open $a(-file) r]
	set a(-data) [read $fid]
	close $fid
    }
    if {[array names a -exact -maskfile] ne {}} {
	set fid [open $a(-maskfile) r]
	set a(-maskdata) [read $fid]
	close $fid
    }

    if {[array names a -exact -foreground] eq {}} {set a(-foreground) black}
    if {[array names a -exact -background] eq {}} {set a(-background) {}}

    if {$a(-background) eq {}} {
	set a(-maskdata)   $a(-data)
	set a(-background) white
    }

    set width  [set a(-width)]
    set height [set a(-height)]
    set result [image create photo -width $width -height $height]
    set data   [join [split [set a(-data)] " "]]

    set line   {}
    set ycntr0 0
    set ycntr1 1
    foreach datum $data {
	foreach cntr {0 1 2 3 4 5 6 7} {
	    if {($datum %2) == 0} \
		then {lappend line $a(-background)} \
		else {lappend line $a(-foreground)}
	    set datum [expr {$datum >> 1}]
	}
	if {[llength $line] >= $width} {
	    $result put [list $line] -to 0 $ycntr0 $width $ycntr1
	    incr ycntr0
	    incr ycntr1
	    set line {}
	}
    }

    if {[array names a -exact -maskdata] ne {}} {
	set w [lindex [regexp -inline -- {width\s+(\d+)}  $a(-data)] 1]
	set h [lindex [regexp -inline -- {height\s+(\d+)} $a(-data)] 1]
	if {($w != $width) || ($h != $height)} {
	    error {bitmap and mask have different sizes}
	}
	regexp -indices -- {\{\s*(0x[^\}]*)} $a(-maskdata) r1 range
	foreach {b e} $range break
	set data [join [split [string trim [string range $a(-maskdata) $b $e]] ,]]

	set ycntr 0
	set xcntr 0
	foreach datum $data {
	    foreach cntr {0 1 2 3 4 5 6 7} {
		if {($datum %2) == 0} {
		    $result transparency set $xcntr $ycntr true
		}
		set datum [expr {$datum >> 1}]
		incr xcntr
		if {$xcntr >= $width} {
		    incr ycntr
		    set  xcntr 0
		    break
		}
	    }
	}
    }

    return $result
}


proc image.bitmap.to.photo bmp {
    set options {}
    foreach opt {-background -data -file -foreground -maskdata -maskfile} {
	lappend options $opt [$bmp cget $opt]
    }
    return [eval image.create.xbm $options]
}


proc NormVec2 {v} {
    lassign $v x y z
    return [expr {$x**2+$y**2+$z**2}]
}


proc NormVec {v} {
    lassign $v x y z
    return [expr {sqrt($x**2+$y**2+$z**2)}]
}


proc Dist2 {u v} {
    lassign $u x1 x2 x3
    lassign $v y1 y2 y3
    return [expr {($y1-$x1)**2 + ($y2-$x2)**2 + ($y3-$x3)**2}]
}


proc Dist {u v} {
    return [expr {sqrt([Dist2 $u $v])}]
}


proc Recall {file} {
    set Ll [LesLignesDuFichier $file]
    puts "[llength $Ll] events recorded"
    foreach l $Ll {
	lassign $l w x y
	puts "[winfo class $w] $w"
	set c [winfo class $w]
	switch $c {
	    "Menubutton" {continue}
	    "Menu" {$w invoke @$y}
	    "Button" {$w invoke}
	    "Radiobutton" {$w invoke}
	    "Checkbutton" {$w invoke}
	}
	#	update idletasks
	#	after 200
    }
    #	    default {continue}

    return
}


proc Record {w x y} {
    AppendAuFichier "events.dat" "$w $x $y"

    return
}


proc LgtDescriptif {} {
    global TDesDescriptifs

    set max -1
    foreach e [array names TDesDescriptifs] {
	set l [string length [set TDesDescriptifs($e)]]
	if {$l > $max} {set max $l}
    }

    return $max
}


proc EstUnEC {e} {
    if {[string trim $e] eq ""} {return 1}

    set Le [split $e .]
    if {[llength $Le] != 4} {return 0}
    foreach e $Le {
	if {! [string is integer $e]} {return 0}
	if {$e < 0} {return 0}
    }

    return 1
}


proc LabelText {base {args {}}} {
    #set default values
    set frargs  ""
    set txtargs ""
    set labargs ""
    set txtpack ""
    set labpack ""
    #parse arguments, assign to label/text components
    foreach {arg val} $args {
	switch -- $arg {
	    -relief {append frargs " $arg $val " }
	    -borderwidth {append frargs " $arg $val " }
	    -labelfont {append labargs "-font \{$val\} " }
	    -labelwidth {append labargs " -width $val "}
	    -labelheight {append labargs " -height $val "}
	    -labeltext	{append labargs " -text \{$val\} "}
	    -labeljustify {append labargs " -justify $val "}
	    -labeltextanchor {append labargs " -anchor $val "}
	    -labelbg -
	    -labelbackground {append labargs " -background $val "}
	    -labelfg -
	    -labelforeground {append labargs " -foreground $val "}
	    -labeltextvariable {append labargs " -textvariable $val" }
	    -labelside {
		append labpack " -side $val "
		append txtpack " -side $val "
	    }
	    -labelanchor {
		append labpack " -anchor $val "
		append txtpack " -anchor $val "
	    }
	    -width -
	    -height -
	    -background -
	    -foregroung -
	    -bg -
	    -fg -
	    -font {append txtargs " $arg \{$val\} "}
	    -textvariable {
		#todo: Create variable if one does not exist
		set variable $val
		set a $variable
		puts $a
		trace var ::$a wu _$a
		set ::${a}_ $base.$variable
		###################################################
		#create bespoke trace handler
		###################################################
		proc _$a {name i op} {
		    # args passed to the fucntion
		    # name	variable name
		    # i    array index
		    # op   operation
		    #upvar 1 $name var
		    if {$::DEBUG} {
			puts ">> name: $name i: $i op: $op"
			#puts "[set ::${name}(${i})_]"
		    }

		    #deal with unset variables
		    if { $op == "u" } {
			if { $i != {} } {
			    rename _$name {}
			} else {
			    rename _${name}(${i}) {}
			}
			return
		    }
		    #assuming variable to be an array, ie $i != NULL
		    if {$i != {} } {
			#variable is and array
			[set ::${name}(${i})_] delete 1.0 end
			[set ::${name}(${i})_] insert end [set ::${name}(${i})]
		    } else {
			#simple variable
			[set ::${name}_] delete 1.0 end
			[set ::${name}_] insert end [set ::${name}]
		    }
		}
		#end proc
	    }
	    # end textvariable block
	}
	#end switch
    }
    #end foreach
    # build megawidget
    frame $base {*}$frargs
    label $base.lab {*}$labargs
    pack $base.lab {*}$labpack
    text $base.$variable {*}$txtargs
    pack $base.$variable {*}$txtpack -in $base
    if {$::DEBUG} {
	bind "$base.$variable" <Button-1> {
	    # get variable name
	    set tmp %W
	    puts "%W -- [winfo parent %W]"
	    puts "%W -- [winfo pathname [winfo id %W]]"
	    puts [lindex  [split %W .] end]
	}
    }
    #update variable when focus is lost
    bind "$base.$variable" <FocusOut> {
	set a [%W get 1.0 end]
	set b [lindex  [split %W .] end]
	#if {$::DEBUG} { puts "a = $a b = $b \n[set $b]" }
	#remove any blank lines
	set $b [string trimright [string trimleft $a]]
    }
    #return location
    return $base
}


proc DonneLongueurDe {n} {
    global LNOrdali LSOrdali

    set i [lsearch $LNOrdali $n]
    if {$i == -1} {return -1}
    set s [lindex $LSOrdali $i]
    regsub -all -- {\-| |\.|Z} $s "" tmp
    return [string length $tmp]
}


proc InitBalloonOnItem {w tag text} {
    $w bind $tag <Enter> [list ShowBalloonOnItem $w $text %x %y]
    $w bind $tag <Leave> [list after 1 $w delete cballoon]
}


proc ShowBalloonOnItem {w text x y} {
    if {"BalloonFont" ni [font names]} {
	set BalloonFont TkTooltipFont
    } else {
	set BalloonFont "BalloonFont"
    }
    set x [$w canvasx $x]
    set y [$w canvasy $y]
    set id [$w create text $x $y \
		-font $BalloonFont \
		-text $text \
		-tag {cballoon} \
		-anchor sw -justify left]
    $w create rect [$w bbox $id] \
	-fill lightyellow \
	-tag {cballoon}
    $w raise $id
}


proc SizeOfFont {f} {
    foreach {a v} [font configure $f] {
	if {$a eq "-size"} {return $v}
    }
}


proc ImagePC {image percent} {
    set deno      [gcd $percent 100]
    set zoom      [expr {$percent/$deno}]
    set subsample [expr {100/$deno}]
    set im1 [image create photo]
    $im1 copy $image -zoom $zoom
    set im2 [image create photo]
    $im2 copy $im1 -subsample $subsample
    image delete $im1
    return im2
}


proc gcd {u v} {expr {$u? [gcd [expr $v%$u] $u]: $v}}


proc LesEndroitsDesDiff {la lb} {
    if {[llength $la] > [llength $lb]} {
	set a $la ; set b $lb
    } else {
	set a $lb ; set b $la
    }
    
    set lr {}
    set i 0 ; set j 0 ; set n 0
    set decal 0
    while {$i < [llength $a]} {
	set e [lindex $a $i]
	set f [lindex $b $j]
	if {$e == $f} {
	    incr i ; incr j
	    if {$decal} {
		lappend lr [list $r $n]
	    }
	    set n 0
	    set decal 0
	} else {
	    if {! $decal} {
		if {$i == 0} {
		    set r ""
		} else {
		    set r [lindex $a [expr {$i-1}]]
		}
	    }
	    set decal 1
	    incr i
	    incr n
	}
    }
    if {$decal} {
	lappend lr [list $r $n]
    }
    
    return $lr
}


proc Deci2Hexa {Deci} {
    return [format "%02X" $Deci]
}


proc Hexa2Deci {Hexa {base 32}} {
    # Ramene valeur hexadecimale a la base donnee
    # 32 bits -> val entre 0 et 255
    # 64 bits -> val entre 0 et 65536
    # Surtout utilise pour les couleurs
    set div [expr {$base/4}]
    if {! [regexp {^0x} $Hexa]} {set Hexa "0x$Hexa"}
    return [expr {1.*$Hexa/((2**$div)-1)}]
}


proc CreeTmpDe {tmp} {
    switch $::tcl_platform(platform) {
	"windows" {set user $::env(USERNAME)}
	"unix"    {set user $::env(USER)}
    }
    return "[pid]_${user}_${tmp}"
}


proc RetourneTableau {aI aO} {
    upvar $aI I $aO O

    foreach {k v} [array get I] {
	lappend O($v) $k
    }

    return
}


proc RetourneTableauAccession {aI aO} {
    upvar $aI I $aO O

    foreach {k v} [array get I] {
	if {[info exists O($v)] && ($v eq $k)} {
	    continue
	}
	    set O($v) $k
    }

    return
}


proc ChronnometreOrdali {{quoi ""}} {
    global _TpsInitial
    set rep ""
    if {$quoi eq "init"} {
	set _TpsInitial [clock scan now]
    } else {
	set diff [expr {[clock scan now] - $_TpsInitial}]
	set rep [clock format $diff -gmt 1 -format "%H:%M:%S"]
    }
    
    return $rep
}


proc Barycentre3D {L} {
    set i 0
    set xc 0.0 ; set yc 0.0 ; set zc 0.0
    foreach t $L {
	lassign $t x y z
	set xc [expr {$xc + $x}]
	set yc [expr {$yc + $y}]
	set zc [expr {$zc + $z}]
	incr i
    }
    set xc [expr {1.0*$xc/$i}]
    set yc [expr {1.0*$yc/$i}]
    set zc [expr {1.0*$zc/$i}]

    return [list $xc $yc $zc]
}


proc BBox3D {L} {
    set xm  9999. ; set ym  9999. ; set zm  9999.
    set xx -9999. ; set yx -9999. ; set zx -9999.
    foreach v $L {
	lassign $v x y z
	if {$x < $xm} {set xm $x}
	if {$y < $ym} {set ym $y}
	if {$z < $zm} {set zm $z}

	if {$x > $xx} {set xx $x}
	if {$y > $yx} {set yx $y}
	if {$z > $zx} {set zx $z}
    }

    return [list $xm $xx $ym $yx $zm $zx]
}


proc DenombreLeTableau {aT} {
    upvar $aT T

    set Lres {}
    foreach a [array names T] {
	lappend Lres [list $a [llength [set T($a)]]]
    }
    set Lres [lsort -integer -index 1 -decreasing $Lres]

    return [ExtraitListeDeListe $Lres 0]
}


proc DenombreLaListe {l} {
    set res {}
    foreach e [lsort -unique $l] {
        lappend res [list $e [llength [lsearch -all $l $e]]]
    }

    return [lsort -integer -decreasing -index 1 $res]
}


proc DonneResidueType_OLD {r} {
    if {$r in {ILE LEU MET MSE VAL TYR PTR TRP CYH CYS SEC ARG GLU GLN LYS ASP ASN ALA PHE SER SEP PRO CPR HIS GLY THR TPO} } {
	return "Protein"
    } elseif {$r in {"  A" "  G" "  T" "  U" "  C" "  I" H2U PSU M7G " DA" " DT" " DG" " DC" " DI" } } {
	return "Nucleic"
    } elseif {$r in {HOH WAT H2O} } {
	return "ligand"
    } else {
	return "ligand"
    }
}

proc DonneChaineType {Lr} {
    # returns Nucleic Protein ou ligand
    # Returns the most current type of the residue list unless it is a lignad
    set Lr [DenombreLaListe $Lr]
    lassign [lindex $Lr 0] what n
    if {$what eq "ligand"} {
	if {[llength $Lr] > 1} {
	    lassign [lindex $Lr 1] what n
	}
    }

    return $what
}

# on garde au cas ou ....
# pour une fois que je suis conservateur ...
proc LaTrace {{cmd ""} {ignoredArg {}} } {
    global ListeProc

    if {! [info exists ListeProc]} {
	inittrace
	set ListeProc {}
	return
    }
    
    set cmd [lindex $cmd 0]
    if {[lsearch $ListeProc $cmd] == -1} {
	lappend ListeProc $cmd
    }
    
    return
}

proc inittrace {} {
    set Lp [info procs]
    foreach e $Lp {
	if {$e == "LaTrace"} {continue}
	if {[regexp {^[A-Z]} $e]} {trace add execution $e enter LaTrace}
    }
    
    return
}


proc finLaTrace {} {
    global ListeProc
    
    set ListeProc [lsort -unique $ListeProc]
    set f [open "touteslesprocs.tcl" w]
    foreach e $ListeProc {
	set a [info args $e]
	set b [info body $e]
	set sar ""
	foreach g $a {
	    if {[info default $e $g Def]} {
		if {$Def == ""} {
		    set Def "\"\""
		}		
		append sar "{$g $Def} "
	    } else {
		append sar "$g "
	    }
	}
	set sar [string trim $sar]
	puts $f $b
	puts $f "\}"
	puts $f ""
    }
    
    close $f
    
    return
}
#LaTrace

proc EstUnBonPattern {motif} {
    if {$motif eq ""} {
	return 0
    }
    set motif [string toupper $motif]
    if {[regexp {[^0123456789ACDEFGHIKLMNPQRSTUVWXY,~\(\)\{\}\<\>]} $motif]} {
	FaireLire "Error ! Unallowed character in motif !"
	return 0
    }

    set npo [regsub -all {\(} $motif "" tmp]
    set npf [regsub -all {\)} $motif "" tmp]
    set nco [regsub -all {\{} $motif "" tmp]
    set ncf [regsub -all {\}} $motif "" tmp]
    if {$npo != $npf} {
	FaireLire "Problem with parenthesis in motif !"
	return 0
    }
    if {$nco != $ncf} {
	FaireLire "Problem with curly braces in motif !"
	return 0
    }
    set ndb [regsub -all "<" $motif "" tmp]
    set nfn [regsub -all ">" $motif "" tmp]
    if {$ndb > 1} {
	FaireLire "Only one '<' allowed in motif !"
	return 0
    }
    if {$nfn > 1} {
	FaireLire "Only one '>' allowed in motif !"
	return 0
    }
    # '<' : beginning of the sequence, '>' : its end
    if {$ndb && [string index $motif 0] ne "<"} {
	FaireLire "'<' is only allowed at the beginning of the motif !"
	return 0
    }
    if {$nfn && [string index $motif end] ne ">"} {
	FaireLire "'>' is only allowed at the end of the motif !"
	return 0
    }
    if {[regsub -all {,,+} $motif "" tmp]} {
	FaireLire "Too many commas in motif !"
	return 0
    }

    # traite NOT operateur
    if {[regsub -all {~~+} $motif "" tmp]} {
	FaireLire "Too many tildes in motif !"
	return 0
    }
    if {[set Lt [regexp -all -inline -indices {~} $motif]] != {}} {
	set fpred 0
	set newmotif ""
	foreach pi $Lt {
	    lassign $pi i i
	    append newmotif "[string range $motif $fpred $i-1]\[^"
	    if {[string index $motif $i+1] eq "("} {
		set if [expr {[string first ")" $motif $i]-1}]
		set id [expr {$i+2}]
		set fpred [expr {$if+2}]
	    } else {
		set id [expr {$i+1}]
		set if [expr {$i+1}]
		set fpred [expr {$if+1}]
	    }
	    set cnt [string map {"," ""} [string range $motif $id $if]]
	    append newmotif "${cnt}\]"
	}
	append newmotif [string range $motif $fpred end]
	set motif $newmotif
    }
    #puts "motif til : $motif"

    # Traite parentheses
    # element a repeter ou OR
    set Lp [regexp -all -inline -indices {\(|\)} $motif]
    if {$Lp != {} } {
	set fpred 0
	set newmotif ""
	foreach {po pf} $Lp {
	    lassign $po o o 
	    lassign $pf f f 
	    if {[string index $motif $o] ne "(" || [string index $motif $f] ne ")"} {
		FaireLire "Badly balanced parentheses in motif !"
		return 0
	    }
	    if {($f - $o) == 1} {
		FaireLire "Empty parentheses in motif !"
		return 0
	    }
	    append newmotif [string range $motif $fpred $o-1]
	    
	    # analyse contenu parentheses
	    set cnt [string range $motif $o+1 $f-1]
	    if {[string index $cnt 0] eq "," || [string index $cnt end] eq ","} {
		FaireLire "Missing symbol before or after ',' in parentheses !"
		return 0
	    }
	    if {[regexp {[^ACDEFGHIKLMNPQRSTVWXY,]} $cnt]} {
		FaireLire "Bad symbol in parenthesis !"
		return 0
	    }
	    # X means any residue : '[X]' would become '[.]' (a literal dot)
	    if {"X" in [split $cnt ","]} {
		append newmotif "X"
	    } else {
		append newmotif "\[[string map {"," ""} $cnt]\]"
	    }
	    set fpred [expr {$f+1}]
	}
	append newmotif [string range $motif $fpred end]
	set motif $newmotif
    }

    # Traite curly braces
    # Nombre de fois
    set Lp [regexp -all -inline -indices {\{|\}} $motif]
    if {$Lp != {} } {
	set fpred 0
	set newmotif ""
	foreach {po pf} $Lp {
	    lassign $po o o 
	    lassign $pf f f 
	    if {[string index $motif $o] ne "{" || [string index $motif $f] ne "}"} {
		FaireLire "Badly balanced curly braces !"
		return 0
	    }
	    append newmotif [string range $motif $fpred $o]
	    
	    if {($f - $o) == 1} {
		append newmotif "0-350000"
	    } else {
		# analyse contenu curly braces
		set cnt [string range $motif $o+1 $f-1]
		if {[regexp {[^0123456789,]} $cnt]} {
		    FaireLire "Bad symbol in curly braces !"
		    return 0
		}
		#set cnt [string map [list "," "-"] $cnt]
		append newmotif $cnt
	    }
	    set fpred $f
	}
	append newmotif [string range $motif $f end]
	set motif $newmotif
    }

    # on cree le motif pour regexp
    set motif [string map [list "<" "^" ">" "$" "X" "."] $motif]

    #puts "motif out : $motif"
    return $motif
}


proc CompositionAADuGroupe {{grp ""}} {
    global LNDG SDG Sequences ListeDesAcidesAmines 
    
    set res {}
    foreach a $ListeDesAcidesAmines {
	set n$a 0
    }
    
    if {$grp eq ""} {
	set grp [lindex $LNDG 0]
    }
    set Ln [set SDG($grp)]


    set sall ""
    foreach s $Ln {
	append sall [set Sequences($s)]
    }
    
    set nTot 0
    foreach a $ListeDesAcidesAmines {
	set stmp [string map [list $a ""] $sall]
	set n$a [expr {[string length $sall] - [string length $stmp]}]
	set sall $stmp
	incr nTot [set n$a]
    }
    
    foreach a $ListeDesAcidesAmines {
	lappend res $a [expr {100.0*[set n$a]/$nTot}]
    }
    foreach m {"AILMV" "KRH" "DEQN" "FYW" "PGST"} {
	set La [split $m ""]
	set np 0
	foreach a $La {
	    incr np [set n$a]
	}
	lappend res $m [expr {100.0*$np/$nTot}]
    }
    
    return $res
}


proc pretty_dict {dict {indent 0}} {
    dict for {key value} $dict {
	# tcl 9.0 :
	# use : string is dict instead of isDict
	if {[isDict $value]} {
	    puts "[string repeat " " $indent] ${key}:"
	    pretty_dict $value [expr {$indent + 2}]
	} else {
	    puts "[string repeat " " $indent] ${key}: ${value}"
	}
    }

    return
}


proc myIP {} {
    if { [ catch {
        set ip 127.0.0.1
        set sid [ socket -async [ info hostname ] 22 ]
        set ip  [ lindex [ fconfigure $sid -sockname ] 0 ]
        ::close $sid
    } err ] } {
        catch { ::close $sid }
        puts stderr "myIP error: '$err' on port 22 (sshd). using 127.0.0.1"
    }
    return $ip
}


proc ip:external {} {
    #this uses the TCP DNS port of the DNS root-servers.
    #If these aren't reachable, you probably don't
    #have a working external internet connection anyway.
    set MyIP ""
    foreach a {a b c d e f g h i j k} {
	catch {
	    set external [socket $a.root-servers.net 53]
	    set MyIP [lindex [fconfigure $external -sockname] 0]
	    close $external
	}
	if { ![string equal $MyIP ""] } { break }
    }
    return $MyIP
}


proc ContenuEnGC {s} {
    set l [string length [set s [string map [list "." ""] $s]]]
    if {$l == 0} {
	return [list 0.0 0.0 0.0 0.0]
    }
    set Lres {}
    foreach n [list A C G T] {
	set n$n [expr {$l-[string length [string map [list $n ""] $s]]}]
	lappend Lres [expr {100.*[set n$n]/$l}]
    }

    return $Lres
}


proc IdentityProfileGUI {} {
    global LNDG SDG LNOrdali ListeDesPiliersDuGroupe PrI ScoreMeth ListeTypesDeFeatures TabSF LongueurTotale Sequences PrI

    set ret 0
    set w .prmip
    if {[winfo exists $w]} {
	raise $w
	return
    }

    toplevel $w
    wm title $w "Identity Profile"
    wm iconname $w "Profile"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    grid columnconfig $w all -weight 1
    grid rowconfig    $w all -weight 1

    set wf $w.f
    frame $wf
    grid $wf -row 0 -column 0

    label $wf.lb \
	-text "Identity Profile :" \
	-font "Helvetica 14 bold"
    
    set ws $wf.fs
    frame $ws
    label $ws.lbw \
	-text "Sliding window : "
    set Lgw [list 10 20 50 100]
    ttk::combobox $ws.cbw \
	-state readonly \
	-background white \
	-width 6 \
	-values $Lgw \
	-textvariable PrI(win)
    $ws.cbw current 0
    label $ws.lbs \
	-text "Jump step size : "
    set Lgs [list 1 5 10 20 50]
    ttk::combobox $ws.cbs \
	-state readonly \
	-background white \
	-width 6 \
	-values $Lgs \
	-textvariable PrI(jump)
    $ws.cbs current 0
    label $ws.lbg \
	-text "Groups : "
    set Lgr [list "All" "Global" {*}[lrange LNDG 1 end]]
    ttk::combobox $ws.cbg \
	-state readonly \
	-background white \
	-width 10 \
	-values $Lgr \
	-textvariable PrI(grp)
    $ws.cbg current 0
    set PrI(CSV) 0
    checkbutton $ws.cks \
	-text "Save profile data as CSV" \
	-variable PrI(CSV) \
	-relief flat \
	-highlightthickness 0 \
	-onvalue  1 \
	-offvalue 0

    grid $ws.lbw -row 0 -column 0 -sticky e -pady {10 2}
    grid $ws.cbw -row 0 -column 1 -sticky w -pady {10 2}
    grid $ws.lbs -row 1 -column 0 -sticky e -pady 2
    grid $ws.cbs -row 1 -column 1 -sticky w -pady 2
    grid $ws.lbg -row 2 -column 0 -sticky e -pady 2
    grid $ws.cbg -row 2 -column 1 -sticky w -pady 2
    grid $ws.cks -row 3 -column 0 -columnspan 2 -sticky w -pady {5 10}
    grid columnconfig $ws all -weight 1

    set wb $wf.fb
    frame $wb
    button $wb.bok \
	-text " OK " \
	-background green1 \
	-command {set PrI(ret) 1 ; destroy .prmip}
    button $wb.bdis \
	-text "Dismiss" \
	-background red \
	-command {set PrI(ret) 0 ; destroy .prmip}
    grid $wb.bdis -row 0 -column 0 -sticky w
    grid $wb.bok  -row 0 -column 1 -sticky e
    grid columnconfig $wb all -weight 1

    grid $wf.lb -row 0 -column 0 -padx 10 -pady 10
    grid $ws    -row 1 -column 0 -padx 10 -pady {5 10}
    grid $wb    -row 2 -column 0 -padx 10 -pady 10 -sticky ew

    FenetreAuCentre $w

    tkwait window $w
    update idletasks

    if {! $PrI(ret)} {return}

    LanceIdentityProfile

    if {[QuelMode] eq "feature"} {
	DetruitBoutonsOrdali
	update
	foreach f [grid slaves $::FrmBouton] {
	    puts "f= $f"
	    foreach s [grid slaves $f] {
		puts "  s= $s"
		foreach q [grid slaves $s] {
		    puts "    q= $q"
		}
	    }
	}
	AfficheBoutonsFeatures
    }
    
    return
}


proc LanceIdentityProfile {} {
    global LNDG SDG LNOrdali ListeDesPiliersDuGroupe ScoreMeth ListeTypesDeFeatures TabSF LongueurTotale Sequences PrI

    FaireAttendre "Please wait ...\nComputing Identity Profiles ..."

    if {! [info exists ListeDesPiliersDuGroupe]} {
	CreeLesPiliers
    }

    # groups to compute
    switch $PrI(grp) {
	"All" {set Lgrp $LNDG}
	"Global" {set Lgrp [lindex $LNDG 0]}
	default {set Lgrp $PrI(grp)}
    }

    set NPiliers [llength [set ListeDesPiliersDuGroupe([lindex $Lgrp 0])]]
    set wlg $PrI(win)
    set jmp $PrI(jump)
    set f "Score-Iden"
    lappend ListeTypesDeFeatures $f
    set ScoreMeth($f,ListeGrps) $Lgrp
    
    foreach g $Lgrp {
	set mmax -99999999.0
	set mmin  99999999.0
	set LPil [set ListeDesPiliersDuGroupe($g)]

	set id 0
	set if [expr {$wlg-1}]
	set Nsq 0
	foreach p [lrange $LPil $id $if] {
	    set p [string map {"." ""} $p]
	    if {[string length $p] >= 2} {
		incr Nsq
	    }
	}
	while {$if <= ($NPiliers-$wlg)} {
	    if {$id != 0} {
		set pOte [lindex $LPil $id]
		set pAdd [lindex $LPil $if]
		set pOte [string map {"." ""} $pOte]
		set pAdd [string map {"." ""} $pAdd]
		if {[string length $pOte] >= 2} {
		    incr Nsq -1
		}
		if {[string length $pAdd] >= 2} {
		    incr Nsq
		}
	    }

	    if {$Nsq == 0} {
		set istk [expr {$id+($wlg/2)-1}]
		set ScoreMeth($f,$g,$istk) -999.
		incr id $jmp
		incr if $jmp

		continue
	    }

	    # Create "window" alignment for PCI
	    set SAli {}
	    foreach n [set SDG($g)] {
		lappend SAli $n [string range [set Sequences($n)] $id $if]
	    }
	    CalculeLesPCIGenerique $SAli TPCI
	    set in 1 ; set nm 0
	    set m 0.0
	    foreach n1 [lrange $SDG($g) 0 end-1] {
		foreach n2 [lrange $SDG($g) $in end] {
		    set m [expr {$m + [lindex $TPCI($n1,$n2) 0]}]
		    incr nm
		}
		incr in
	    }
	    set m [expr {100.*$m/double($nm)}]
	    if {$m > $mmax} {set mmax $m}
	    if {$m < $mmin} {set mmin $m}
	    set istk [expr {$id+($wlg/2)-1}]
	    set ScoreMeth($f,$g,$istk) $m

	    incr id $jmp ; incr if $jmp
	    unset -nocomplain TPCI
	}
	set Sc($g,min) $mmin
	set Sc($g,max) $mmax
	set ScoreMeth($f,${g}-min) $mmin
	set ScoreMeth($f,${g}-max) $mmax
    }
    set ScoreMeth($f,Edit) 0
    set ScoreMeth(ScaleGlobal) 1

    FaireLaSuite

    if {$PrI(CSV)} {
	set file [DemandeEtSauveFichier csv]
	if {$file ne ""} {
	    set o [open $file w]
	    set g [lindex $Lgrp 0]
	    set Li {}
	    foreach e [array names ScoreMeth "$f,$g,*"] {
		lappend Li [lindex [split $e ,] 2]
	    }
	    set Li [lsort -unique -integer $Li]
	    foreach i $Li {
		set Ls {}
		foreach g $Lgrp {
		    set x [set ScoreMeth($f,$g,$i)]
		    if {$x == -999. || $x < 0.1} {
			set x 0.0
		    }
		    lappend Ls $x
		}
		puts $o [join $Ls ";"]
	    }
	    close $o
	}
    }
    
    if {1} {
	set file [open "vals.txt" w]
	foreach g $Lgrp {
	    puts $file "$g"
	    puts $file "[string repeat - [string length $g]]"
	    foreach n [lsort -dictionary [array names ScoreMeth "$f,${g},*"]] {
		lassign [split $n ,] nf ng ni
		puts $file "$ni [set ScoreMeth($n)]"
	    }
	    puts $file ""
	}
	close $file
    }

    unset -nocomplain PrI TPCI
    
    return
}


proc CentreData {l {exc ""} {a 2.} {b 1.}} {
    # min / max
    set tmp [lsort -unique -real $l]
    # only one value
    if {[llength $tmp] == 1} {
	if {$exc ne "" && [lindex $tmp 0] == $exc} {
	    return $l
	}
    }
    set min [lindex $tmp 0]
    set max [lindex $tmp end]

    if {$exc ne ""} {
	if {$min == $exc} {
	    set min [lindex $tmp 1]
	}
	if {$max == $exc} {
	    set max [lindex $tmp end-1]
	}
    }
    if {$min == $max} {
	set denom 1.
    } else {
	set denom [expr {1.0*($max-$min)}]
    }

    # centre
    set nv {}
    foreach v $l {
	if {$v != $exc} {
	    set v [expr {$a*($v-$min)/$denom-$b}]
	}
	lappend nv $v
    }

    return $nv
}


proc LanceInterproScan {FileIn FileOut} {
    
    set Commande "/titan/data/iprscan/V4.8/iprscan/bin/iprscan -cli -i tmpfa -o tmpo -appl patternscan -format raw"
    #set Commande "/titan/data/iprscan/V4.8/iprscan/bin/iprscan -cli -i $FileIn -o $FileOut -appl patternscan -format raw -goterms -iprlookup"

    catch {eval exec $Commande >& iprlog}

    return
}


proc LancePSScan {f} {
    exec perl /home/moumou/tmp/ps_scan/ps_scan.pl -r -s -d /home/moumou/tmp/ps_scan/prosite.dat $f > ${f}.out
    if {! [file exists ${f}.out]} {
	puts "==> Erreur dans psscan !!"
	return {}
    }
    set Ll [LesLignesDuFichier ${f}.out]
    file delete -force ${f}.out

    return $Ll
}


proc LesPrositesDuTFA {f} {
    set Ll [LancePSScan $f]
    array set R {}
    set Lpos {}
    foreach l $Ll {
	if {[string index $l 0] eq ">"} {
	    if {$Lpos != {}} {
		lappend R($n) $ps $Lpos
		set Lpos {}
	    }
	    lassign [split [string range $l 1 end] " "] n tmp ps tmp
	} else {
	    regsub -all { +} [string trim $l] " " l
	    lassign [split $l " "] p1 tmp p2 tmp
	    lappend Lpos $p1 $p2
	}
    }
    if {$Lpos != {}} {
	lappend R($n) $ps $Lpos
    }

    return [array get R]
}


proc tlps {} {
    set Lo [LancePSScan tata]
    puts "[join [lrange $Lo 0 10] \n]"
    set LF [LesPrositesDuTFA toto]
    array set F $LF
    parray F
    exit
}


proc MaxDeListe {l} {
    set max [lindex $l 0] ; set imax 0
    set i 0
    foreach v $l {
	if {$v > $max} {
	    set max $v
	    set imax $i
	}
	incr i
    }

    return $imax
}


proc MinDeListe {l} {
    set min [lindex $l 0] ; set imin 0
    set i 0
    foreach v $l {
	if {$v < $min} {
	    set min $v
	    set imin $i
	}
	incr i
    }

    return $imin
}


# 10 billes
# Lv    5   3   7  14 = 29  
# real 1.6 1.0 2.3 4.
# Lres 2   1   2   5   

proc RepartiValEntreN {n Lv} {
    set tot [::tcl::mathop::+ {*}$Lv]

    set sr 0
    set Lres {}
    set Ld {}
    foreach v $Lv {
	set d [expr {double($v)*$n/$tot}]
	set r [expr {int($d)}]
	incr sr $r

	lappend Ld [expr {$d-$r}]
	lappend Lres $r
    }
    
    if {$sr == $n} {
	return $Lres
    }

    while {($n - $sr) > 0} {
	set icol [MaxDeListe $Ld]
	set nbcol [lindex $Lres $icol]
	incr nbcol
	lset Lres $icol $nbcol
	lset Ld   $icol 0.0
	incr sr
	update
    }
    
    return $Lres
}

proc ale {} {
    for {set i 0} {$i < 1000000} {incr i} {
	set nv [expr {int(rand()*18)+2}]
	set Lv {}
	for {set j 0} {$j < $nv} {incr j} {
	    lappend Lv [expr {int(rand()*100)}]
	}
	set tot [::tcl::mathop::+ {*}$Lv]
	if {$tot == 0} {continue}

	set nb [expr {int(rand()*100)+1}]

	puts ""
	puts "nb = $nb"
	set s ""
	foreach v $Lv {
	    append s [format %6d $v]
	}
	puts "$s"
	tvn $nb $Lv
    }
    exit
}

proc tvn {nb Lv} {
    #set nb 11
    #set Lv {5 3 8 14}

    set Lr [RepartiValEntreN $nb $Lv]
    puts ""
    # %ages
    set tot [::tcl::mathop::+ {*}$Lv]
    set sv "" ; set sr "" ; set spt "" ; set spr ""
    foreach v $Lv r $Lr {
	set pt [expr {1.*$v/$tot*100}]
	set pb [expr {1.*$r/$nb*100}]
	append sv  [format %6d $v]
	append spt [format %6.2f $pt]
	append sr  [format %6d $r]
	append spb [format %6.2f $pb]
    }
    puts "$sv\n$spt\n$sr\n$spb"

    return
    exit
}


proc CanvasSee {hWnd items} {
    # taken from the wiki.tcl.tk, search "canvassee"

    set box [eval $hWnd bbox $items]
    if {$box == ""} { return }
    
    if {[string match {} [$hWnd cget -scrollregion]] } {
        # People really should set -scrollregion you know...
	lassign $box x y x1 y1

        set x [expr {round(2.5 * ($x1+$x)/[winfo width $hWnd])}]
	set y [expr {round(2.5 * ($y1+$y)/[winfo height $hWnd])}]
	
        $hWnd xview moveto 0
        $hWnd yview moveto 0
        $hWnd xview scroll $x units
        $hWnd yview scroll $y units
    } else {
        # If -scrollregion is set properly, use this
	lassign $box x y x1 y1
	lassign [$hWnd yview] top btm
	lassign [$hWnd xview] left right
	lassign [$hWnd cget -scrollregion] p q xmax ymax

        set xpos [expr {(($x1+$x)/2.0)/$xmax-($right-$left) / 2.0}]
        set ypos [expr {(($y1+$y) / 2.0) / $ymax - ($btm-$top)    / 2.0}]

        $hWnd xview moveto $xpos
        $hWnd yview moveto $ypos
    }

    return
}


proc HashExiste {l {aT ""}} {
    foreach v $l {
	set HExst($v) 1
    }

    return [array get HExst]
}


proc trari {} {
    package require sqlite3
    sqlite3 d taxo.sql

    lassign [d eval {select Name,Rank,Parent from taxonomy where Name='Danio rerio'}] name rank f
    puts "$name $rank $f"
    while {$f >= 0} {
	lassign [d eval {select Name,Rank,Parent from taxonomy where taxid=$f}] name rank p
	puts "$name $rank $p"
	set f $p
    }

    exit
}


proc PutsDuTaisToi {args} {
    switch -regexp -- [lindex $args 0] {
	{\-nonewline} {
	    return
	}
	{file[0-9]+} -
	{sock[0-9]+} {
	    rename ::puts ::PutsDuTaisToi
	    rename ::putsCmdOriginale ::puts
	    puts {*}$args
	    rename ::puts ::putsCmdOriginale
	    rename ::PutsDuTaisToi ::puts
	}
	default {
	    return
	}
    }
    
    return
}


proc TaisToi {{Silence ""}} {
    if {$Silence eq ""} {set Silence 1}

    if {$Silence} {
	if {"putsCmdOriginale" ni [info commands]} {
	    rename ::puts ::putsCmdOriginale
	    rename ::PutsDuTaisToi ::puts
	}
    } else {
	if {"putsCmdOriginale" in [info commands]} {
	    rename ::puts PutsDuTaisToi
	    rename ::putsCmdOriginale ::puts
	}
    }

    return
}


proc number_processors {} {
    global tcl_platform
    
    package require fileutil
    set max_jobs 0

    if { [string equal -nocase "windows" "$tcl_platform(platform)"] } {
        set max_jobs $::env(NUMBER_OF_PROCESSORS)
    } elseif { [file readable /proc/cpuinfo] } {
        set np [llength [::fileutil::grep processor /proc/cpuinfo]]
        set max_jobs $np
    } else {
	# Unknown OS
    }
    
    return $max_jobs
}


proc ParseLigneCSV {l {sep ","} {cot ""}} {
    if {$cot eq ""} {set cot "\""}

    set Lv {}
    set buf "" ; set cp ""
    set prems 1 ; set op 0
    foreach c [split "$l" ""] {
	if {$c eq "\""} {
	    if {$prems} {
		set op 1
		set cp ""
		set prems 0
	    } else {
		if {! $op} {
		    set op 1
		} elseif {$cp eq $c} {
		    # double double cot
		    append buf "\""
		    set cp ""
		} else {
		    set cp $c
		}
	    }
	} elseif {$c eq $sep} {
	    if {$prems} {
		lappend Lv "$buf"
	    } elseif {$op} {
		if {$cp eq "\""} {
		    # fin, ecrit
		    lappend Lv $buf
		    set buf "" ; set cp ""
		    set prems 1 ; set op 0
		} else {
		    append buf $c
		}
	    } else {
		lappend Lv "$buf"
		set buf "" ; set cp ""
		set prems 1 ; set op 0
	    }
	} else {
	    append buf $c
	    set prems 0
	}
    }

    return $Lv
}

proc InspecteListe {l {indent 0}} {
    if {$indent == 5 || ! [string is list -strict $l] || ! [regexp " " $l]} {
	puts "[string repeat $indent $indent] $l"
	return
    }

    incr indent
    foreach elt $l {
	InspecteListe $elt $indent
    }
}


proc LucIMAPToTcl {items} {
    set quote 0
    set str ""
    foreach c [split $items ""] {
	if {$c eq "\""} {
	    if {$quote} {
		set quote 0
	    } else {
		set quote 1
	    }
	    append str $c
	    continue
	}
	if {$quote} {
	    append str $c
	} else {
	    set x $c
	    switch -- $c {
		"\{" {set x "\\\{"}
		"\}" {set x "\\\}"}
		{(} {set x "\{"}
		    {)} {set x "\}"}
	    }
	    append str $x
	}
    }
    set str [string map {"\[" "\\\[" "\]" "\\\]"} $str]

    return $str
}


proc AnalyseTabulatedFile {f} {
    set cont [ContenuDuFichier $f]
    set cont [string map {"\t\|\n" "LuCkYlUc67"} $cont]
    set cont [string map {"\n" " "} $cont]
    set cont [string map {"LuCkYlUc67" "\n"} $cont]
    set Ll [split $cont \n]

    foreach l $Ll {
	set Lix [regexp -all -inline -indices {\t\|\t} $l]
	set i 0
	set dp 0
	foreach li $Lix {
	    lassign $li dc fc
	    lappend C($i) [string range $l $dp $dc-1]
	    set dp [expr {$fc+1}]
	    incr i
	}
	lappend C($i) [string range $l $dp end]
    }
    foreach col [lsort -integer [array names C]] {
	#puts "[lrange $C($col) 0 4]"
	set lg [PlusLongEltDe $C($col)]
	set v  [PlusLongEltDe $C($col) val]
	puts "$col $lg $v"
    }
    unset -nocomplain C

    return
    exit
}


proc NW {sa sb} {
    # Needleman-Wunsch algorithm
    # taken from :
    # http://biit.cs.ut.ee/~vilo/edu/2002-03/Tekstialgoritmid_I/Loengud/Loeng3_Edit_Distance/bcorum_copy/seq_align3.htm
    #

    set lga [string length $sa]
    set lgb [string length $sb]
    set La [split $sa ""]
    set Lb [split $sb ""]
    set LM {}
    # b vertical
    foreach b $Lb {
	set L {}
	# a horizontal
	foreach a $La {
	    lappend L [expr {$a eq $b}]
	}
	lappend LM $L
    }

    # list of columns max , filled with last line
    set LC [lindex $LM end]
    for {set b [expr {$lgb-2}]} {$b >= 0} {incr b -1} {
	set bp [expr {$b + 1}]

	# init row maximu
	set rmax [lindex [lindex $LM $bp] end]

	for {set a [expr {$lga-2}]} {$a >= 0} {incr a -1} {
	    set ap [expr {$a+1}]
	    set mab [lindex [lindex $LM $b] $a]
	    # diag
	    set md [lindex [lindex $LM $bp] $ap]

	    # row
	    if {$md > $rmax} {
		set rmax $md
	    }
	    
	    # col
	    set cmax [lindex $LC $ap]
	    if {$md > $cmax} {
		set cmax $md
		lset LC $ap $cmax
	    }

	    lset LM $b $a [expr {$mab + ($rmax>$cmax?$rmax:$cmax)}]
	}
    }
    #pNW $sa $sb $LM 2
    #exit

    if {0} {
	# max on row 0
	set mxr0 [lindex [lsort -integer [lindex $LM 0]] end]
	set ax [lindex [lsearch -all [lindex $LM 0] $mxr0] end]
	
	# max on col 0
	set c0 [ExtraitListeDeListe $LM 0]
	set mxc0 [lindex [lsort -integer $c0] end]
	set bx [lindex [lsearch -all $c0 $mxc0] end]
	
	if {$mxr0 > $mxc0} {
	    set bx 0
	} else {
	    set ax 0
	}
	
	set oa "" ; set ob ""
	for {set s 0} {$s < $ax} {incr s} {
	    append ob "-"
	    append oa [lindex $La $s]
    }
	for {set t 0} {$t < $bx} {incr t} {
	    append ob [lindex $Lb $t]
	    append oa "-"
	}
	
	append ob [lindex $Lb $t]
	append oa [lindex $La $s]
	
	set t $bx ; set s $ax
	#puts "lga $lga lgb $lgb"
	while {$s < ($lga-1) || $t < ($lgb-1)} {
	    set sp [expr {$s + 1}]
	    set tp [expr {$t + 1}]
	    
	    set drt [lindex [lindex $LM $tp] $s]
	    set bas [lindex [lindex $LM $t] $sp]
	    set dia [lindex [lindex $LM $tp] $sp]
	    # diagonal
	    if {$dia >= $bas && $dia >= $drt} {
		set res 3
	    } else {
		if {$bas >= $drt} {
		    set res 2
		} else {
		    set res 1
		}
	    }
	    
	    switch $res {
		1 {
		    #puts "drt"
		    set t $tp
		    append oa "-"
		    append ob [lindex $Lb $t]
		}
		2 {
		    #puts "bas"
		    set s $sp
		    append ob "-"
		    append oa [lindex $La $s]
		}
		3 {
		    #puts "diag"
		    set s $sp
		    set t $tp
		    append oa [lindex $La $s]
		    append ob [lindex $Lb $t]
		}
	    }
	    #puts "drt $drt dia $dia bas $bas | $s $t"
	    #puts "[string range $oa end-20 end]"
	    #puts "[string range $ob end-20 end]"
	    #puts ""
	}
    } else {
	set oa "" ; set ob ""
	set s  -1 ; set t  -1
	set sp  0 ; set tp  0
	while {$sp < $lga && $tp < $lgb} {
	    set maxVal -1

	    set row [lindex $LM $tp]
	    for {set i $sp} {$i < $lga} {incr i} {
		set val [lindex $row $i]
		if {$val > $maxVal} {
		    set maxVal $val
		    set drt $i
		    set bas $tp
		}
	    }
	    
	    for {set i $tp} {$i < $lgb} {incr i} {
		set val [lindex [lindex $LM $i] $sp]
		if {$val > $maxVal} {
		    set maxVal $val
		    set bas $i
		    set drt $sp
		}
	    }
	    
	    if {$drt == $sp && $bas == $tp} {
		append oa [lindex $La $drt]
		append ob [lindex $Lb $bas]
	    } else {
		if {$bas > $tp} {
		    for {set i $tp} {$i < $bas} {incr i} {
			append oa "-"
			append ob [lindex $Lb $i]
			#puts "  i=$i"
			#puts "  $oa"
			#puts "  $ob"
		    }
		}
		
		if {$drt > $sp} {
		    for {set i $sp} {$i < $drt} {incr i} {
			append oa [lindex $La $i]
			append ob "-"
			#puts "  i=$i"
			#puts "  $oa"
			#puts "  $ob"
		    }
		}
		append oa [lindex $La $drt]
		append ob [lindex $Lb $bas]
		#puts ">$oa"
		#puts ">$ob"
	    }
	    set s  $drt
	    set t  $bas
	    set sp [expr {$s + 1}]
	    set tp [expr {$t + 1}]
	    
	    #puts "s=$s"
	    #puts "t=$t\n"
	    
	    #puts "drt $drt dia $dia bas $bas | $s $t"
	    #puts "[string range $oa end-20 end]"
	    #puts "[string range $ob end-20 end]"
	    #puts ""
	}
	#puts ""
	#puts "s= $s $lga"
	#puts "t= $t $lgb"
	if {$sp < $lga} {
	    for {set i $sp} {$i < $lga} {incr i} {
		append oa [lindex $La $i]
		append ob "-"
	    }
	} elseif {$tp < $lgb} {
	    for {set i $tp} {$i < $lgb} {incr i} {
		append oa "-"
		append ob [lindex $Lb $i]
	    }
	}
    }
    

    
    #puts "$oa"
    #puts "$ob"

    return [list $oa $ob]
}



proc NW_old {a b} {
    # Needleman-Wunsch algorithm
    # taken from :
    # http://biit.cs.ut.ee/~vilo/edu/2002-03/Tekstialgoritmid_I/Loengud/Loeng3_Edit_Distance/bcorum_copy/seq_align3.htm
    #

    set la [split $a ""]
    set lb [split $b ""]

    set i 0
    foreach s $la {
	set j 0
	foreach t $lb {
	    set M($i,$j) [expr {$s eq $t}]
	    incr j
	}
	incr i
    }
    #pNW $a $b M
    
    #puts "i= $i j= $j"
    for {set s [expr {$i-2}]} {$s >= 0} {incr s -1} {
	for {set t [expr {$j-2}]} {$t >= 0} {incr t -1} {
	    # at each s,t check the right-bottom 
	    # rectangle s+1,t+1 -> end,end
	    set max -99999
	    set sp [expr {$s+1}]
	    set tp [expr {$t+1}]
	    for {set sm $sp} {$sm < $i} {incr sm} {
		for {set tm $tp} {$tm < $j} {incr tm} {
		    if {[set v $M($sm,$tm)] >= $max} {
			set max $v
		    }
		}
	    }
	    incr M($s,$t) $max
	}
    }
    #pNW $a $b M 2
    
    # cherche max 1er ligne/col
    set mxr -999
    for {set s 0} {$s < $i} {incr s} {
	if {$M($s,0) > $mxr} {
	    set mxr $M($s,0)
	    set rx $s
	}
    }
    set mxc -999
    for {set t 0} {$t < $j} {incr t} {
	if {$M(0,$t) > $mxc} {
	    set mxc $M(0,$t)
	    set cx $t
	}
    }
    if {$mxr > $mxc} {
	set cx 0
    } else {
	set rx 0
    }

    set oa "" ; set ob ""
    ##puts "cx $cx rx $rx"
    for {set s 0} {$s < $cx} {incr s} {
	append ob [string index $b $s]
	append oa "-"
    }
    for {set t 0} {$t < $rx} {incr t} {
	append ob "-"
	append oa [string index $a $t]
    }
    #puts "oa $oa"
    #puts "ob $ob"
    set s $rx ; set t $cx
    #puts "s= $s t= $t"
    append ob [string index $b $t]
    append oa [string index $a $s]
    #set t $rx ; set s $cx
    
    while {$s < ($i-1) && $t < ($j-1)} {
	set sp [expr {$s+1}]
	set tp [expr {$t+1}]

	#puts "\n s= $s t= $t M $M($s,$t)"
	set drt $M($s,$tp)
	set bas $M($sp,$t)
	set dia $M($sp,$tp)
	set L [list 1 $drt 2 $bas 3 $dia]
	set res [lindex [lsort -integer -index 1 -stride 2 $L] end-1]
	switch $res {
	    1 {
		#puts "drt"
		set t $tp
		append oa "-"
		append ob [string index $b $t]
	    }
	    2 {
		#puts "bas"
		set s $sp
		append ob "-"
		append oa [string index $a $s]
	    }
	    3 {
		#puts "diag"
		set s $sp
		set t $tp
		append oa [string index $a $s]
		append ob [string index $b $t]
	    }
	}
    }
    
    puts "$oa"
    puts "$ob"


    return [list $oa $ob]
}


proc pNW {a b LM {n 1} {With0 0}} {
    puts ""
    puts "A hori : $a"
    puts "B vert : $b"

    set la [split $a ""]
    set lga [llength $la]
    set sa [join $la [string repeat " " $n]]
    set lb [split $b ""]
    
    set ns [string repeat " " $n]
    puts "  $sa"
    set i 0
    foreach e $lb row $LM {
	puts -nonewline "$e"
	foreach x $row {
	    if {$n < 2 && $x == 0} {
		puts -nonewline "$ns "
	    } else {
		puts -nonewline [format " %${n}d" $x]
	    }
	}
	puts ""
    }

    return
}

    
proc pNW_old {a b aM {n 1}} {
    upvar $aM M

    puts ""
    puts "A vert : $a"
    puts "B hori : $b"

    set la [split $a ""]
    set lb [split $b ""]
    set lgb [llength $lb]
    set sb [join $lb [string repeat " " $n]]

    set ns [string repeat " " $n]
    puts "  $sb"
    set i 0
    foreach e $la {
	puts -nonewline "$e "
	for {set j 0} {$j < $lgb} {incr j} {
	    set x $M($i,$j)
	    if {$n < 2 && $x == 0} {
		puts -nonewline "$ns "
	    } else {
		puts -nonewline [format "%${n}d " $x]
	    }
	}
	incr i
	puts ""
    }

    return
}


proc tNW {} {
    #set S "ACTAGCTGATCGATCGAT"
    set S "ACGCTAGCTGATCGATCGAT"
    #set T "CTAGCTATATAGAT"
    set T "CGCTAGCTATATAGATGCGC"
    lassign [NW $S $T] al bl
    puts "$al"
    puts "$bl"
    exit
    
    #set S "ESIRMVLIGPPGAGKGTQAPNLQERFHAAHLATGDMLRSQIAKGTQLGLEAKKIMDQGGLVSDDIM"
    #set T "SSESIRMVLIGPPGAGKGTQAPNLQERFHAAHLATGDMLRSQIAKGTQLGLEAKKIMDQGGLVSDDIM"
        
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time
    lassign $al s1 s2
    puts "$s1"
    puts "$s2"

    #exit
    
    set S [string repeat $S 2]
    set T [string repeat $T 2]
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time

    set S [string repeat $S 2]
    set T [string repeat $T 2]
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time

    set S [string repeat $S 2]
    set T [string repeat $T 2]
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time


    set S [string repeat $S 2]
    set T [string repeat $T 2]
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time

    set S [string repeat $S 2]
    set T [string repeat $T 2]
    puts "\nS= [string length $S] T= [string length $T]"
    set time [time {set al [NW $S $T]}]
    puts $time

    exit
}


proc CentreDataPourClustering {Ld} {
    set nv [llength [lindex $Ld 0]]
    set L0 [ExtraitListeDeListe $Ld 0]
    for {set i 1} {$i < $nv} {incr i} {
	set L$i [CentreData [ExtraitListeDeListe $Ld $i]]
    }
    
    set New {}
    for {set n 0} {$n < [llength $Ld]} {incr n} {
	set Ltmp {}
	for {set i 0} {$i < $nv} {incr i} {
	    lappend Ltmp [lindex [set L$i] $n]
	}
	lappend New $Ltmp
    }

    return $New
}


proc spi {} {
    set a [string repeat "A" 5000]
    set la [split $a ""]
    puts "[time {string index $a 3021} 10000]"
    puts "[time {lindex $la 3021} 10000]"
    exit
}

proc tnw2 {} {
    set l1 [lindex [LesLignesDuFichier str1.fa] 1]
    set l2 [lindex [LesLignesDuFichier str2.fa] 1]

    set time [time {set out [NW $l2 $l1]}]
    lassign $out n1 n2
    ShowProtDiff n1 n2
    puts "time $time"
    exit
    lassign [NW $l2 $l1] na nb
    #lassign [NW [string range $l2 0 19] [string range $l1 0 19]] na nb
    puts "$nb"
    puts "$na"

    exit
}

proc tnw3 {} {
    set str1 "MACDEFGILMFYWHRK"
    set str2 "MGILMFYW"

    set str1 "CGCTAGCTATATAGAT"
    set str2 "ACGCTAGCTGATCGATCGATGCG"
    
    #set str1 [lindex [LesLignesDuFichier str1.fa] 1]
    #set str2 [lindex [LesLignesDuFichier str2.fa] 1]

    foreach var {str1 str2} {
	set o [open "$var.fa" w]
	puts $o ">$var"
	puts $o "[set $var]"
	close $o
    }

    catch {exec ./nw.com} Msg
    puts "$Msg"
    puts ""

    lassign [NW $str2 $str1] na nb
    puts ""
    ShowProtDiff na nb
    #puts "\n$na\n$nb"

    exit
}

proc atnw {} {
    set Ll [LesLignesDuFichier out]
    set idtnw [lsearch -regexp $Ll {^DTNW}]
    set iftnw [lsearch -regexp $Ll {^FTNW}]

    set idtor [lsearch -regexp $Ll {^DTOR}]
    set iftor [lsearch -regexp $Ll {^FTOR}]
    

    set verif [list [list A 5 5 5 5 5 6 5 5 5 5 6 4 4 4 5 3 3 2 2 0] [list T 4 4 4 4 5 4 4 4 5 4 4 5 4 4 3 4 3 2 1 1] [list A 4 3 3 3 3 4 3 3 3 3 4 3 3 3 4 3 3 2 2 0] [list G 2 2 3 2 2 2 3 2 2 3 2 2 2 3 2 2 2 3 1 0] [list A 2 1 1 1 1 2 1 1 1 1 2 1 1 1 2 1 1 1 2 0] [list T 0 0 0 0 1 0 0 0 1 0 0 1 0 0 0 1 0 0 0 1]]


    set i 0
    foreach l1 [lrange $Ll $idtnw+1 $iftnw-1] l2 [lrange $Ll $idtor+1 $iftor-1] {
	regsub -all { +} [string trim $l1] " " l1
	regsub -all { +} [string trim $l2] " " l2
	if {$l1 ne $l2} {
	    puts "- $i ------------"
	    puts "$l1"
	    puts "$l2\n"
	}
	incr i
    }

    exit
}


proc ttmp {} {
    set ligne [ContenuDuFichier tmp]
    set ligne [string map {"\n" ""} $ligne]
    set dtd [string first "<td " $ligne]
    set ftd [string first "</td>" $ligne]
    while {$dtd != -1} {
	set td [string range $ligne $dtd $ftd+4]
	puts "$td"
	set ligne [string replace $ligne $dtd $ftd+4]
	
	set Lcom [regexp -all -indices -inline {\<\!.\>} $td]
	set Lcom [lreverse $Lcom]
	puts "Lcom $Lcom"
	foreach {lb la} $Lcom {
	    lassign $la d tmp
	    lassign $lb tmp f
	    set td [string replace $td $d $f]
	}

	set res [regexp -all -inline "\>.+\<" $td]
	puts $res
	puts ""
	set dtd [string first "<td " $ligne]
	set ftd [string first "</td" $ligne]
    }

    exit
}


proc DumpSVG {can} {
    puts "entre sumpSVG"
    source [file join $::OrdLibDir uriencode.tcl]
    source [file join $::OrdLibDir tinyfileutils.tcl]
    source [file join $::OrdLibDir can2svg.tcl]

    puts "Fait le dump"
    can2svg::canvas2file $csn can.svg
    puts "Fin SVG"
    return
}


proc OriginesDuPackage {package} {
    if {! [catch {package require $package} currver] } {
	foreach ver [package versions $package] {
	    puts "$ver: [package ifneeded $package $ver]"
	}
    }
    
    return
}


proc tfa {} {
    set Lv [list toto 10.3156 turlututu]
    puts [time {
	foreach {a b c} $Lv {}
    } 10000]
    puts [time {lassign $Lv a b c} 10000]
    exit
}


proc InitCharsetHtml {} {
    set Ll [LesLignesDuFichier [file join $::OrdEtcDir charset.txt]]

    foreach l $Ll {
	if {[string first "#" $l] == 0 || [set l [string trim $l]] eq ""} {
	    continue
	}

	regsub -all { +} $l " " l
	if {[string index $l 0] eq "\\"} {
	    set l "NULL $l"
	}
	lassign $l keyboard octal hex unicode html char
	lappend LCharSet [list $keyboard $octal $hex $unicode $html $char]
    }

    return $LCharSet
}


proc MapCharSet {from to val} {
    if {! [info exists ::LCharSet]} {
	set LCharSet [InitCharsetHtml]
    }

    foreach k {from to} i {iFrom iTo} {
	switch [set $k] {
	    "keyboard" {set $i 0}
	    "octal"    {set $i 1}
	    "hex"      {set $i 2}
	    "unicode"  {set $i 3}
	    "html"     {set $i 4}
	    "char"     {set $i 5}
	}
    }
	
    set ligne [lsearch -inline -index $iFrom $LCharSet $val]
    set out [lindex $ligne $iTo]

    return $out
}


proc Html2Char {l} {
    puts $l
    set Li [regexp -all -inline -indices {\\[0-9]{3}} $l]
    if {$Li == {} } {
	return $l
    }

    foreach xy [lreverse $Li] {
	lassign $xy x y
	set l [string replace $l $x $y [MapCharSet octal char [string range $l $x $y]]]
    }

    return $l
}


proc tchar {} {
    set out [MapCharSet octal char "\311"]
    puts $out

    set s "\311tude d'ét\311"
    puts [Html2Char $s]
    exit


    set o [open cat.html r]
    fconfigure $o -encoding ascii
    set l [read -nonewline $o]
    set Ll [split $l "\n"]
    close $o

    set Lres {}
    foreach l $Ll {
	lappend Lres [Html2Char $l]
    }
    
    exit
}


proc echoProc {{type enter}} {
    set Lprocs [info procs]
    set i [lsearch $Lprocs LogProc]
    set Lprocs [lreplace $Lprocs $i $i]
    foreach name [info procs] {
        trace add execution "::$name" $type LogProc
    }

    return
}


proc LogProc {name args} {
    puts "$name"
    update idletasks
}


proc plist {liste format {Terminal 1}} {
    set out {}
    foreach v $liste {
	lappend out [format $format $v]
    }
    if {$Terminal} {
	puts [join $out]
    }

    return $out
}


proc ComputeSumOfPairs {} {
    global LNOrdali LSOrdali

    set Ls {}
    foreach n $LNOrdali s $LSOrdali {
	if {$n ne ""} {
	    lappend Ls $s
	}
    }

    set Lw [lrepeat [llength $Ls] 1.0]
    set sop [Ccode_SumOfPairs blosum62 $Ls $Lw]
puts "sop= $sop"
    return $sop
}

	    
proc SaveLogHTML {} {
    AuLog LOutput HTML
    return
}


proc CheckFileFormatExtension {file} {
    set ext [file extension $file]
    if {$ext eq ""} {
	return 1
    }
    foreach {Type Extensions} [FileFormatExtensionsTable] {
	if {[lsearch $Extensions $ext]>=0} {
	    return 1
	}
    }

    return 0
}


proc CouleurRGB2name {rgb} {
    global TkCol

    if {[string length $rgb] == 7} {
	set r [string range $rgb 1 2]
	set g [string range $rgb 3 4]
	set b [string range $rgb 5 6]
    }
    set r [
	



    return $name
}


    proc InfosDeWindow {w} {
	update idletasks
	
	puts "\n== window $w ======"
	puts "title >[wm title $w]<"
	puts "geometry : [wm geometry $w]"
	puts "[wm attributes $w]"
	puts "========="

	return
    }


proc PutYearOnOrdaliImage {} {
    # Splash image with the copyright of the current year, written
    # once in etc/OrdaliNuage_<year>.png (see DemarrageOrdali).
    # Drawn in its own toplevel : "." may already be the main window.
    global OrdEtcDir

    LoadTkAndPackages
    package require Img
    
    set fimg [file join $OrdEtcDir OrdaliNuageNumero.png]
    set ph [image create photo]
    $ph read $fimg -format png

    set Ld [$ph data]
    set hgt [llength $Ld]
    set wdt [llength [lindex $Ld 0]]

    # from the bottom, first line with white pixels (characters) ...
    set ytop    [expr {$hgt - 1}]
    set ybottom [expr {$hgt - 1}]
    set i 1
    set color "#ffffff"
    set ToFind 10
    while {$i < $hgt} {
	set d [lindex $Ld $hgt-$i]
	set Lw [lsearch -all $d $color]
	if  {[llength $Lw] > $ToFind} {
	    set ytop [expr {$hgt - $i}]
	    break
	}
	incr i
    }

    # ... then the previous black line, just above the old copyright
    # of the gif, which is hidden by the black rectangle
    # (threshold : 407 black pixels out of 600, works for this image)
    set color "#000000"
    set ToFind [expr {[llength $Ld] - 20}]
    while {$i < $hgt} {
	set d [lindex $Ld $hgt-$i]
	set Lw [lsearch -all $d $color]
	if  {[llength $Lw] > $ToFind} {
	    set ybottom [expr {$hgt - $i}]
	    break
	}
	incr i
    }
    incr ybottom -1

    set Year [clock format [clock seconds] -format %Y]
    set text "\u00A9 Luc Moulinier & CSTB 1999 - $Year"

    set top .putyear
    catch {destroy $top}
    toplevel $top
    wm overrideredirect $top 1
    set c $top.c
    canvas $c \
	-background black \
	-borderwidth 0 \
	-highlightthickness 0 \
	-height $hgt \
	-width $wdt
    $c create image 0 0 \
	-image $ph \
	-anchor nw
    set x [expr {$wdt - 10}]
    set wtext [font measure "Helvetica 8" $text]
    set x1 [expr {$x - $wtext - 100}]
    set x2 [expr {$x+5}]
    incr ybottom -2
    set ytop [expr {$ybottom + 12}]
    set y1 [expr {$ybottom -10}]
    $c create rectangle $x1 $y1 $x2 $ytop \
	-fill black
    $c create text $x $ybottom \
	-text $text \
	-fill white \
	-font "Helvetica 8" \
	-justify left \
	-anchor se
    grid $c -row 0 -column 0 -sticky news

    wm attributes $top -topmost 1
    FenetreAuCentre $top
    raise $top
    update

    # grab the canvas : the window may not be displayed at once
    set out ""
    for {set essai 0} {$essai < 10} {incr essai} {
	if {! [catch {image create photo -format window -data $c} out]} {
	    break
	}
	set out ""
	update
	after 200
    }
    destroy $top
    if {$out eq ""} {
	# no copyright then, but Ordalie must start
	return $ph
    }
    image delete $ph

    # etc may be read-only (installed Ordalie, starpack)
    set fimg [file join $OrdEtcDir OrdaliNuage_$Year.png]
    catch {$out write $fimg -format png}
    
    return $out
}


proc isDict d {
    expr {[string is list $d]
        && !([llength $d] % 2)
        && ((2 * [llength [dict keys $d]]) == [llength $d])
    }
}


proc RandomSequence {len} {
    set aa "ACDEFGHIKLMNPQRSTVWY"
    set s ""
    for {set i 0} {$i < $len} {incr i} {
	set x [expr {int(rand()*20)}]
	append s [string index $aa $x]
    }

    return $s
}


    proc isDictKeysValsUnique d {
    expr {[isDict $d]
        && [llength [lsort -unique $d]] == [llength $d]
    }
}

    
	
# SLURM_ARRAY_TASK_ID
# est execute la ou il est lance
# cree un log pour chaque job
# sbatch -a 0-50 script

