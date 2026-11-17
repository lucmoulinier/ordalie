

#
# --- ordali_tree.tcl
#

proc FastMEExe {} {
    global tcl_platform
    global OrdBinDir
    global env

    if {[info exists env(GRILLE)] && $env(GRILLE)} {
	return "./fastme"
    }
    if {[set tcl_platform(platform)] != "windows"} {
	if {[info exists OrdBinDir]} {
	    return [file join $OrdBinDir "fastme"]
	} else {
	    return "/biolo/fastme/bin/fastme"
	}
    } else {
	set lexe [file join $OrdBinDir "fastme.exe"]
	regsub "Program Files" $lexe "PROGRA~1" lexe
	return $lexe
    }
}


proc InitBootstrap {AId} {
    global Abr HashRef

    set t [set Abr(Arbre,$AId)]
    unset -nocomplain HashRef TSum
    CreeBootstrapRef $t root
    $t set root nboot 0

    return
}


proc CreeBootstrapRef {t n} {
    foreach n [$t nodes] {
	set Le [$t get $n Lleaves]
	set Lr [lor $::TLeaves $Le "from1"]
	set Se [join [lsort $Le] ,]
	set Sr [join [lsort $Lr] ,]
	set k1 "$Se@$Sr"
	set k2 "$Sr@$Se"
	
	set ::HashRef($n)  $k1
	set ::HashRef($k1) $n
	set ::HashRef($k2) $n
    }

    return
}


proc AssigneBootstrap {AId} {
    global TSum Abr HashRef

    set t [set Abr(Arbre,$AId)]

    foreach n [$t nodes] {
	if {[$t isleaf $n]} {
	    continue
	}
	if {$n eq "root"} {
	    set v 1000000
	} elseif {! [info exists TSum($n)]} {
	    puts "no TSum for $n"
	    set v 0
	} else {
	    set v [set TSum($n)]
	}
	$t set $n nboot $v
    }

    set Ser [$t serialize]
    set Abr(ArbreSer,$AId) $Ser

    return
}


proc FilterLeaf {t n} {
    $t isleaf $n
}

proc ResteDesFeuilles {t Le} {
    foreach f [$t leaves] {
	if {$f ni $Le} {lappend Lr $f}
    }

    return $Lr
}


proc CompareArbres {} {
    global TBoot TSum HashRef

    foreach e $TBoot {
	if {[info exists HashRef($e)]} {
	    incr TSum([set HashRef($e)])
	}
    }

    return
}


proc CompteBootArbre {t n} {
    set ::TBoot {}
    CreeBootstrapTable $t
    CompareArbres

    return
}


proc CreeBootstrapTable {t} {
    foreach n [$t nodes] {
	set Le [$t get $n Lleaves]
	set Lr [lor $::TLeaves $Le "from1"]
	set k1 "[join [lsort $Le] ,]@[join [lsort $Lr] ,]"
	lappend ::TBoot $k1	
    }
    
    return
}


proc NormaliseTable {aT} {
    global FeuilleRef
    upvar $aT T

    foreach e [array names T "*,$FeuilleRef"] {
	if {! [set T($e)]} {
	    set k [join [lrange [split $e ","] 0 end-1] ","]
	    foreach r [array names T "$k,*"] {
		set T($r) [expr {! [set T($r)]}]
	    }
	}
    }

    return
}


proc CompteBootArbre2 {t n} {
    global TBoot

    if {[$t isleaf $n]} {return}
    foreach fils [$t children $n] {
	CompteBootArbre $t $fils
    }

    set L1 {}
    foreach e [$t children $n] {
	if {[$t isleaf $e]} {
	    set Le $e
	} else {
	    set Le [$t descendants $e filter FilterLeaf]
	}
	set Le [lsort $Le]
	lappend L1 [join $Le ","]
    }
    set k1 [join $L1 "@"]
    set k2 [join [lreverse $L1] "@"]
    incr TBoot($k1)
    incr TBoot($k2)

    return
}


proc T_DoBootstrap {Ln Lpil} {

    set lgs [llength $Lpil]
    set nbs [llength $Ln]
    set NewA {}
    set Lr {}
    for {set col 0} {$col < $lgs} {incr col} {
	# Attention !! int(9.99) = 9 !! donc lgs et pas lgs-1 !
	set H [expr {int(rand()*$lgs)}]

	set pil [lindex $Lpil $H]
	for {set i 0} {$i < $nbs} {incr i} {
	    lappend l$i [lindex $pil $i]
	}
    }
    
    for {set i 0} {$i < $nbs} {incr i} {
	lappend NewA [set l$i]
	lappend Lr [string length [string map {"." ""} [join [set l$i] ""]]]
	set l$i {}
    }
    
    set i 1
    foreach n1 $Ln s1 $NewA l1 $Lr {
	set TPCI($n1,$n1) 0.0
	foreach n2 [lrange $Ln $i end] s2 [lrange $NewA $i end] l2 [lrange $Lr $i end] {
	    set dist [expr {1.0-[NRIdentite $s1 $l1 $s2 $l2]}]
	    set TPCI($n1,$n2) $dist
	    set TPCI($n2,$n1) $dist
	}
	incr i
    }
    
    set Ldst {}
    foreach n1 $Ln {
	foreach n2 $Ln {
	    lappend Ldst [set TPCI($n1,$n2)]
	}
    }
    
    return $Ldst
}

proc T_DoBootstrap2 {Ln Lpil Lrd} {

    set lgs [llength $Lpil]
    set nbs [llength $Ln]
    set NewA {}
    set Lr {}
    for {set col 0} {$col < $lgs} {incr col} {
	# Attention !! int(9.99) = 9 !! donc lgs et pas lgs-1 !
#	set H [expr {int(rand()*$lgs)}]
	set H [lindex $Lrd $col]
	set pil [lindex $Lpil $H]
	for {set i 0} {$i < $nbs} {incr i} {
	    lappend l$i [lindex $pil $i]
	}
    }
    
    for {set i 0} {$i < $nbs} {incr i} {
	lappend NewA [set l$i]
	lappend Lr [string length [string map [list "." ""] [join [set l$i] ""]]]
	set l$i {}
    }
    
    set i 1
    foreach n1 $Ln s1 $NewA l1 $Lr {
	set TPCI($n1,$n1) 0.0
	foreach n2 [lrange $Ln $i end] s2 [lrange $NewA $i end] l2 [lrange $Lr $i end] {
	    set dist [expr {1.0-[NRIdentite $s1 $l1 $s2 $l2]}]
	    set TPCI($n1,$n2) $dist
	    set TPCI($n2,$n1) $dist
	}
	incr i
    }
    
    set Ldst {}
    foreach n1 $Ln {
	foreach n2 $Ln {
	    lappend Ldst [set TPCI($n1,$n2)]
	}
    }
    
    return $Ldst
}


proc TestRand {l} {
    set dl [expr {10*$l}]

    Init_C_Random
    for {set i 0} {$i < 10} {incr i} {
	lappend lc {*}[C_Random $l]
#	after 1000
    }
    for {set i 0} {$i < $dl} {incr i} {
	lappend lt [expr {int(rand()*$l)}]
    }
    set lc [lsort -unique -integer $lc]
    set lt [lsort -unique -integer $lt]
    #puts "lc [llength $lc]"
    #puts "lt [llength $lt]"

    if {$lc != $lt} {
	#puts "diff dans lc et lt"
	#puts "[lor $lc $lt]"
    }
    #flush stdout
    #update idletasks

    exit

    return
}

proc BootstrapArbre {AId Lns} {
    global Abr FAPG Defauts TPil NoDeLArbre

    foreach {n s} $Lns {
	lappend Ln $n
	lappend Ls [split $s ""]
    }
    set nbs [llength $Ln]
    set lgs [llength [lindex $Ls 0]]

    # cree piliers
    for {set i 0} {$i < $lgs} {incr i} {
	set ltmp {}
	set stmp ""
	foreach s $Ls {
	    set c [lindex $s $i]
	    lappend ltmp $c
	    append  stmp $c
	}
	lappend LpilT $ltmp
	lappend LpilC $stmp
    }

    set ::TLeaves [[set Abr(Arbre,$AId)] leaves]
    InitBootstrap $AId

    if {[set Defauts(UseSpeedCode)] ne "tcl"} {
	Init_C_Boot
    }

    # Bootstrap 100 fois par defaut
    FaireAttendre "Please wait ...\nBootstrapping tree ..." 1

    # Bootstrap iterations
    set Nboot [set Defauts(TreeNBoot)]
    for {set bt 0} {$bt < $Nboot} {incr bt} {
	set FAPG [expr {100.*$bt/$Nboot}]
	update idletasks

	set NoDeLArbre 0

	if {[set Defauts(UseSpeedCode)] eq "tcl"} {
	    set Ldst [T_DoBootstrap $Ln $LpilT]
	} else {
	    set Ldst [C_DoBootstrap $Ln $LpilC]
	}
	
	set rep [fastme $Ln $Ldst]
	set ATb 999
	#set ATb [DecortiqueUnArbre $rep]
	DecortiqueUnArbre $rep $ATb
	#puts "ATb $ATb [set Abr(Arbre,$ATb)]"
	set Tb [set Abr(Arbre,$ATb)]
	CompteBootArbre $Tb root

	DetruitArbre $ATb
    }
    #puts "bootstrap done"
    AssigneBootstrap $AId

    FaireLaSuite

    return
}


proc NettoieArbre {a} {
    set Li [regexp -all -indices -inline {'} $a]

    if {$Li != {} } {
	if {[llength $Li] % 2} {
	    FaireLire "There are unmatching ' characters in the tree file !\nAborting ..."
	    return 0
	}
	set Li [lreverse $Li]
	foreach {ff dd} $Li {
	    lassign $dd d tmp
	    lassign $ff f tmp
	    set nm [string map [list "'" "" " " _] [string range $a $d $f]]
	    set a "[string range $a 0 $d-1]$nm[string range $a $f+1 end]"
	}
    }
    set a [string map [list " " ""] $a]

    set o [CheckOpen treenet]
    if {$o eq ""} {
	return
    }
    puts $o $a
    close $o

    return $a
}


proc CalculeUnArbre {} {
    global ZoneTree ZoneSelect ListePDB Defauts Abr TSum tcl_platform OrdTmpDir Rap

    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {! [info exists ZoneSelect]} {
	set ZoneSelect {}
    }
    set ZoneTree $ZoneSelect
    if {$ZoneTree == {}} {
	FaireLire "No residue range selected ..."
	return
    }

    FaireAttendre "Please wait ...\nComputing distance matrix and phylogenetic tree ..."

    AlignementDesSelections $ZoneTree SAli

    set ZoneTree $ZoneSelect
    set NewAli {}
    set LNoms {}
    set LSeqs {}
    foreach {n s} $SAli {
	if {$n in $ListePDB && ! [set Defauts(PDBTree)]} {
	    continue
	}
	lappend LNoms $n
	lappend LSeqs $s
	lappend NewAli $n $s
    }
    set SAli $NewAli

    if {[set Defauts(TypeGapTree)] eq "global"} {
	# only the complete columns (no gap in any sequence) : for the
	# distances and the bootstrap too
	set Long [string length [lindex $LSeqs 0]]
	set Lcol {}
	for {set i 0} {$i < $Long} {incr i} {
	    set complet 1
	    foreach s $LSeqs {
		if {[string index $s $i] in {. " " - ~ ""}} {
		    set complet 0
		    break
		}
	    }
	    if {$complet} {
		lappend Lcol $i
	    }
	}
	set LSeqs [lmap s $LSeqs {join [lmap i $Lcol {string index $s $i}] ""}]
	set SAli {}
	foreach n $LNoms s $LSeqs {
	    lappend SAli $n $s
	}
    }
    set NbrSites [string length [lindex $LSeqs 0]]

    if {$NbrSites < 10} {
	FaireLire "Error ! Less than 10 sites to compute a tree !"
	FaireLaSuite
	return
    }

    unset -nocomplain TPCI
    array set TPCI {}
    CalculeLesPCIGenerique $SAli TPCI
    
    set m 0. ; set m2 0.
    set min 9999999. ; set max -9999999.
    set Nseq [llength $LNoms]
    set Ldst {}
    foreach n1 $LNoms {
	foreach n2 $LNoms {
	    lassign [set TPCI($n1,$n2)] pc l1 l2 lsl
	    lappend Ldst [expr {1.-$pc}]
	    if {$n1 ne $n2} {
		set m  [expr {$m + $pc}]
		set m2 [expr {$m2 + $pc*$pc}]
		if {$pc < $min} {set min $pc}
		if {$pc > $max} {set max $pc}
	    }
	}
    }
    set m  [expr {$m/($Nseq*($Nseq-1))}]
    set m2 [expr {$m2/($Nseq*($Nseq-1))}]
    set var [expr {$m2-$m*$m}]
    if {$var > 0.0001} {
	set sd [expr {sqrt($var)}]
    } else {
	set sd 0.0
    }
    set Rap(nseq)   $Nseq
    set Rap(idmin)  $min
    set Rap(idmax)  $max
    set Rap(idmean) $m
    set Rap(idsd)   $sd

    set LeTree [fastme $LNoms $Ldst]

    FaireLaSuite

    set AId [InitialiseUnArbre $LeTree]
    
    # some spec
    set Abr($AId,Mac) [MacCourant]
    set Abr($AId,Mode) normal
    set Abr($AId,PDBTree) [set Defauts(PDBTree)]
    set Abr($AId,TypeGapTree) $Defauts(TypeGapTree)
    set Abr($AId,NbrSites) $NbrSites
    set Abr($AId,TreeNBoot)   $Defauts(TreeNBoot)
    if {[set Defauts(TreeBoot)]} {
	set Abr($AId,BootDone) 1
	BootstrapArbre $AId $SAli
    } else {
	set Abr($AId,BootDone) 0
    }

    AfficheUnArbre $AId
    #parray Rap

    return $AId
}


proc SaveTree {AId {file ""}} {
    if {$file eq ""} {
	set file [DemandeEtSauveFichier ph 1]
    }
    if {$file eq ""} {
	return
    }

    set fo [CheckOpen $file]
    if {$fo eq ""} {
	return
    }
    puts $fo $::Abr($AId,TextePH)
    close $fo

    set file "${file}.test"
    EcritUnArbre $AId $file

    return
}


proc SurGrille {x} {
    global PasDeLaGrille

    if {! [info exists PasDeLaGrille]} {
	set PasDeLaGrille 1
    }

    set X [expr {round($x/$PasDeLaGrille)*$PasDeLaGrille}]

    return $X
}


proc ColorieDescendants {AId Lf col} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]
    set Lid {}
    foreach n [$t nodes] {
	if {[$t isleaf $n]} {continue}

	set Ld [concat $n {*}[$t descendants $n]]
	set Ln {}
	foreach d $Ld {
	    if {[$t isleaf $d]} {
		lappend Ln $d
	    }
	}
	set lo [lor $Ln $Lf from1]
	if {$lo != {}} {
	    continue
	}
	foreach d $Ld {
	    if {[set Li [$PAD find withtag "line-$d"]] != ""} { 
		lappend Lid {*}$Li
	    }
	}
    }

    set Lid [lsort -integer -unique $Lid]
    foreach i $Lid {
	$PAD itemconfig $i -width 2 -fill $col
    }

    return
}


proc GroupesDeLArbre {AId} {
    # groups {LNDG SDG} of the instance of the tree : the current
    # ones when the tree belongs to the current instance (they are
    # kept in Abr($AId,Groupes)), else the ones kept the last time
    # the tree was drawn in its instance. Empty if unknown.
    global Abr LNDG SDG

    if {! [info exists Abr($AId,Mac)] || $Abr($AId,Mac) == [MacCourant]} {
	if {! [info exists LNDG] || ! [array exists SDG]} {
	    return {}
	}
	set Abr($AId,Groupes) [list $LNDG [array get SDG]]
    }
    if {[info exists Abr($AId,Groupes)]} {
	return $Abr($AId,Groupes)
    }

    return {}
}


proc PeintParClusters {AId} {
    global Abr

    # groups of the instance of the tree, not of the current one
    lassign [GroupesDeLArbre $AId] LNDG LSDG
    array set SDG $LSDG
    if {[llength [array names SDG]] <= 1} {
	return
    }

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]
    if {[set Abr($AId,ShClusters)]} {
	foreach g $LNDG {
	    if {$g in [list GroupeToutLeMonde All all grise bidon]} {
		continue
	    }
	    
	    set col [CouleurO2Ordali [CouleurDuGroupe [string range $g 5 end]]]
	    foreach f [set SDG($g)] {
		set id [$PAD find withtag "feuille-$f"]

		if {$id eq ""} {
		    continue
		}
		$PAD itemconfig $id -fill $col
	    }

	    ColorieDescendants $AId [set SDG($g)] $col
	}
    } else {
	set Lf [$t leaves]
	foreach f $Lf {
	    set id [$PAD find withtag "feuille-$f"]
	    $PAD itemconfig $id -fill black
	}
	set Li [$PAD find withtag all]
	foreach i $Li {
	    if {[lsearch -regexp [$PAD gettags $i] "line-"] != -1} {
		$PAD itemconfig $i -width 1 -fill black
	    }
	}
    }

    return
}


proc PhylumDeLaSequence {n} {
    # life domain of sequence n (from TDesPhylum) : Eukaryota,
    # Archaea, Bacteria, Viruses, or "" if unknown
    global TDesPhylum

    # copies of a sequence are suffixed by __<n>
    if {! [info exists TDesPhylum($n)] && [set ix [string last "__" $n]] > 0} {
	set n [string range $n 0 $ix-1]
    }
    if {! [info exists TDesPhylum($n)]} {
	return ""
    }
    set d [string totitle [string trim $TDesPhylum($n)]]
    if {$d eq "Prokaryota"} {
	set d "Bacteria"
    }
    if {$d ni {Eukaryota Archaea Bacteria Viruses}} {
	return ""
    }

    return $d
}


proc ArbreAPhylum {AId} {
    # 1 if the life domain of at least one leaf is known
    global Abr

    set t $Abr(Arbre,$AId)
    foreach {n v} [$t attr name -nodes [$t leaves]] {
	if {[PhylumDeLaSequence $v] ne ""} {
	    return 1
	}
    }

    return 0
}


proc MetAJourPhylumArbre {{AId ""}} {
    # state of the 'show phylum' check button of the tree windows
    # (all of them if AId is empty)
    global Abr

    if {$AId eq ""} {
	set Lid [expr {[info exists Abr(Liste)] ? $Abr(Liste) : {}}]
    } else {
	set Lid $AId
    }
    foreach AId $Lid {
	if {! [info exists Abr($AId,BPhylum)] || ! [winfo exists $Abr($AId,BPhylum)]} {
	    continue
	}
	if {[ArbreAPhylum $AId]} {
	    $Abr($AId,BPhylum) configure -state normal
	    # already shown : new information is displayed
	    if {[info exists Abr($AId,Phylum)] && $Abr($AId,Phylum)} {
		PeintParPhylum $AId
	    }
	} else {
	    $Abr($AId,BPhylum) configure -state disabled
	}
    }

    return
}


proc PeintParPhylum {AId} {
    # colour the leaves according to their life domain (colors of
    # the Preferences)
    global Abr Defauts

    if {! [ArbreAPhylum $AId]} {
	FaireLire "No Phylum information available !\nUse 'Retrieve Sequences information' in the Sequences menu."
	set Abr($AId,Phylum) 0
	return
    }

    set PAD $Abr($AId,PAD)
    set t   $Abr(Arbre,$AId)
    set Ln  [$t attr name -nodes [$t leaves]]

    foreach {n v} $Ln {
	set d ""
	if {$Abr($AId,Phylum)} {
	    set d [PhylumDeLaSequence $v]
	}
	if {$d ne ""} {
	    set f $Defauts(Fg$d)
	    set b $Defauts(Bg$d)
	} else {
	    set f black
	    set b white
	}
	if {$Abr($AId,TypeTree) eq "dendrogram"} {
	    $PAD itemconfig [$PAD find withtag "feuille-$v"] -fill $f
	}
	$PAD itemconfig [$PAD find withtag "Rfeuille-$v"] -fill $b
    }

    return
}


proc ModeReroot {AId} {
    global Abr

    if {[set Abr($AId,TypeTree)] ne "dendrogram"} {
	set Abr($AId,Reroot) 0

	return
    }

    set PAD [set Abr($AId,PAD)]
    set Li [$PAD find withtag reroot]
    if {[set Abr($AId,Reroot)]} {
	if {[set Abr($AId,BootShow)]} {
	    set Abr($AId,BootShow) 0
	    MontreBootstrap $AId
	}
	if {[set Abr($AId,Swap)]} {
	    set Abr($AId,Swap) 0
	    ModeSwap $AId
	}
	foreach i $Li {
	    $PAD itemconfig $i -fill green1 -outline black
	}
	$PAD raise reroot
	$PAD bind reroot <Button-1> [list RerootNode $AId]
	ChangeCurseur $AId fleche
    } else {
	foreach i $Li {
	    $PAD itemconfig $i -fill white -outline white
	}
	$PAD lower reroot
	$PAD bind reroot <Button-1> ""
	ChangeCurseur $AId normal
    }

    return
}


proc RotateMode {AId val} {

    if {[string is double $val]} {
	if {$val > 0.} {
	    set quoi rplus
	} else  {
	    set quoi rmoins
	}
    }

    set Abr($AId,Mode) "rotate"
    ChangeCurseur $AId $quoi
    
    TourneArbreEntier $AId $val
    OnReDessineArbre $AId

    bind $::Abr($AId,PAD) <Button-1> "TourneArbreEntier $AId $val
                                      OnReDessineArbre $AId
                                      break"

    return
}


proc PointerMode {AId} {
    global Abr
    
    set Abr($AId,Mode) "normal"
    ChangeCurseur $AId normal
    if {[set Abr($AId,Swap)]} {
	set Abr($AId,Swap) 0
	ModeSwap $AId
    }
    if {[set Abr($AId,BootShow)]} {
	set Abr($AId,BootShow) 0
	MontreBootstrap $AId
    }
    if {[set Abr($AId,TypeTree)] eq "dendrogram" && [set Abr($AId,Reroot)]} {
	set Abr($AId,Reroot) 0
	ModeReroot $AId
    }

    set PAD [set Abr($AId,PAD)]
    bind $PAD <ButtonPress-1> {%W scan mark %x %y}
    bind $PAD <B1-Motion> {%W scan dragto %x %y 1}

    return
}


proc AppliqueZoom {AId val x y} {
    global Abr

    if {$val eq "zplus"} {
	set Abr($AId,ScaleR) [expr {[set Abr($AId,incrScaleR)] + [set Abr($AId,ScaleR)]}]
    } else {
	set Abr($AId,ScaleR) [expr {[set Abr($AId,ScaleR)] - [set Abr($AId,incrScaleR)]}]
    }
    if {[set Abr($AId,ScaleR)] < $Abr($AId,incrScaleR)} {
	set Abr($AId,ScaleR) $Abr($AId,incrScaleR)
    }
    
    OnReDessineArbre $AId

    return
}


proc ZoomMode {AId quoi} {
    global Abr

    set Abr($AId,Mode) "zoom"
    ChangeCurseur $AId $quoi

    set PAD [set Abr($AId,PAD)]

    bind $PAD <Button-1> [list AppliqueZoom $AId $quoi %x %y]
    bind $PAD <B1-Motion> {}

    return
}


proc AppliqueWidth {AId val} {

    set inc [expr {[set ::Abr($AId,Increment)] + $val}]
    if {$inc < 5} {return}
    set ::Abr($AId,Increment) $inc
    
    OnReDessineArbre $AId
    
    return
}


proc WidthMode {AId val} {
    global Abr

    if {$val > 0} {set quoi wplus} {set quoi wmoins}
    ChangeCurseur $AId $quoi
    
    set PAD [set Abr($AId,PAD)]
    bind $PAD <ButtonPress-1> [list AppliqueWidth $AId $val]
    bind $PAD <B1-Motion> {}

    return
}


proc HeightMode {AId val} {
    global Abr

    # below 5 the leaves overlap, then the tree is drawn upside down
    if {[set Abr($AId,OffsetY)] + $val >= 5} {
	set Abr($AId,OffsetY) [expr {[set Abr($AId,OffsetY)] + $val}]
    }
    
    if {$val > 0} {set quoi hplus} {set quoi hmoins}
    ChangeCurseur $AId $quoi

    OnReDessineArbre $AId

    set PAD [set Abr($AId,PAD)]
    bind $PAD <ButtonPress-1> [list HeightMode $AId $val]
    bind $PAD <B1-Motion> {}

    return
}


proc FonteMode {AId quoi val} {
    eval font configure "TreeFont$AId" -${quoi} $val

    return
}



proc RerootNode {AId} {
    global Abr

    set t   [set Abr(Arbre,$AId)]
    set PAD [set Abr($AId,PAD)]

    set id [$PAD find withtag current]
    set Ln [$t attr IdRer]
    set i [lsearch $Ln $id]
    set n [lindex $Ln [expr {$i - 1}]]

    set a [NouveauRoot $t $n]
    set Ser [$a serialize]
    $a destroy
    struct::tree $t
    $t deserialize $Ser
    $t set root r 0.0
    $t set root theta 0.0
    $t set root oldtheta 0.0
    $t set root length 0.0
    $t set root width [llength [$t leaves]]

    ReDessineArbre $AId

    ModeReroot $AId
    ModeSwap $AId

    return
}


proc ModeSwap {AId} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set Li [$PAD find withtag rotation]

    puts "swap [set Abr($AId,Swap)]"
    if {[set Abr($AId,Swap)]} {
	if {[set Abr($AId,BootShow)]} {
	    set Abr($AId,BootShow) 0
	    MontreBootstrap $AId
	}
	if {[set Abr($AId,Reroot)]} {
	    set Abr($AId,Reroot) 0
	    ModeReroot $AId
	}
	
	foreach i $Li {
	    $PAD itemconfig $i -fill red -outline black
	}
	$PAD raise rotation
	$PAD bind rotation <Button-1> [list SwapNode $AId]
	ChangeCurseur $AId fleche
    } else {
	foreach i $Li {
	    $PAD itemconfig $i -fill white -outline white
	}
	$PAD lower rotation
	$PAD bind rotation <Button-1> ""
	
	if {[set Abr($AId,Mode)] eq "normal"} {
	    ChangeCurseur $AId normal
	}
    }

    return
}



proc SwapNode {AId} {
    global Abr

    set t   [set Abr(Arbre,$AId)]
    set PAD [set Abr($AId,PAD)]

    set id [$PAD find withtag current]
    set Ln [$t attr IdRot]
    set i [lsearch $Ln $id]
    set n [lindex $Ln $i-1]
    if {$n eq "root"} {
	return
    }

    $t set $n ordre [expr {![$t get $n ordre]}]

    if {[set Abr($AId,TypeTree)] ne "dendrogram"} {
	Tree2Coordonnees $AId
    } else {
	TransformationCartesienne $AId root
    }
    AjusteCoordonneesInit $AId
    #    ReAjusteCoordonnees $AId

    OnReDessineArbre $AId

    ModeReroot $AId
    ModeSwap $AId

    return
}


proc ResetArbre {AId w} {
    global Abr

    $w delete all

    #$Abr(Arbre,$AId) deserialize $Abr(ArbreSer,$AId)
    set TextePH $Abr($AId,TextePH)
    #DetruitArbre $AId
    InitialiseUnArbre $TextePH $AId

    ModeReroot $AId
    ModeSwap   $AId

    return
}


proc DetruitArbre {{AId ""}} {
    global Abr

    if {$AId eq ""} {
	unset Abr(Liste)
	set Le [set Abr(ListeArbres)]
    } else {
	trace remove variable Abr($AId,TypeTree) write {SwitchTypeTree $AId}
	set Le $AId
	set i [lsearch $Abr(Liste) $AId]
	set Abr(Liste) [lreplace $Abr(Liste) $i $i]
	if {$Abr(Liste) == {}} {
	    unset Abr(Liste)
	}
    }

    foreach e $Le {
	set t [set Abr(Arbre,$e)]
	set i [lsearch [set Abr(ListeArbres)] $t]
	set Abr(ListeArbres) [lreplace [set Abr(ListeArbres)] $i $i]
	catch {array unset Abr "Arbre,$AId"}
	catch {array unset Abr "$AId,*"}
	catch {array unset Abr "*,$AId"}
	if {[winfo exists .arbre$e]} {
	    wm protocol ".arbre$e" WM_DELETE_WINDOW ""
	    destroy ".arbre$e"
	}
	# not created for the trees of the other instances
	# when an ORD is loaded (RecoverTrees)
	if {[info commands $t] ne ""} {
	    $t destroy
	}
    }
    if {$AId eq ""} {
	catch {unset Abr}
    }

    return
}


proc ChangeCurseur {AId quoi} {
    global Abr OrdEtcDir tcl_platform

    set PAD [set Abr($AId,PAD)]
    switch -- $quoi {
	"zplus"  {set froot loupeplus}
	"zmoins" {set froot loupemoins}
	"rplus"  {set froot rotateplus}
	"rmoins" {set froot rotatemoins}
	"wplus"  {set froot noeudecarte}
	"wmoins" {set froot noeudserre}
	"hplus"  {set froot heightecarte}
	"hmoins" {set froot heightserre}
	"normal" {set froot hand14}
	"fleche" {
	    $PAD configure -cursor left_ptr
	    return
	}
    }
    $PAD configure -cursor none
    switch -- $tcl_platform(platform) {
	unix {
	    set file [file join $OrdEtcDir ${froot}.xbm]
	    set cursor [list @$file black]
	}
	windows {
	    set file [file join $OrdEtcDir ${froot}.cur]
	    set cursor [list @$file]
	}
    }
    $PAD configure -cursor $cursor

    return
}


proc ShowTreeLegend {AId {quoi draw}} {
    global Abr

    # if hide legend,
    if {$quoi eq "hide"} {
	$Abr($AId,PAD) delete Legend
	return
    }

    if {$quoi eq "draw"} {
	# if text window for caption definition exists
	# then create a new caption
	if {[winfo exists $Abr($AId,LegWText)]} {
	    set txt [$Abr($AId,LegWText) get 1.0 end]
	    set Abr($AId,Text) $txt
	    if {$Abr($AId,LegGap)} {
		if {$Abr($AId,TypeGapTree) eq "global"} {
		    append txt "\nGlobal gap removal"
		} else {
		    append txt "\nPairwise gap removal"
		}
	    }
	    if {$Abr($AId,LegSites)} {
		append txt "\n[set Abr($AId,NbrSites)] sites"
	    }
	    if {$Abr($AId,LegBoot)} {
		if {$Abr($AId,BootDone)} {
		    append txt "\n$Abr($AId,TreeNBoot) bootstraps; Threshold $Abr($AId,ThresBootPC)%"
		}
	    }
	    if {$Abr($AId,LegCoul)} {
		set i 1 ; set cum "\n"
		foreach g [lrange [lindex [GroupesDeLArbre $AId] 0] 1 end] {
		    if {$g eq "bidon" || $g eq "grise"} {
			continue
		    }
		    set n [string range $g 5 end]
		    set col [CouleurDuGroupe $n]
		    append cum "$g $col "
		    if {! ($i % 5)} {
			append txt $cum
			set cum ""
		    }
		}
		if {$cum ne ""} {
		    append txt $cum
		}
	    }
	    set txt "$txt\n"
	    set Abr($AId,Legend) $txt
	} else {
	    set txt $Abr($AId,Legend)
	}
    }

    # pour dismiis et si on vient de DefineLegend
    if {[winfo exists $Abr($AId,LegWText)]} {
	destroy [winfo toplevel $Abr($AId,LegWText)]
	if {$quoi eq "dismiss"} {
	    set Abr($AId,AddLeg) 0
	    $Abr($AId,PAD) delete Legend
	    return
	}
    }
    
    if {$txt eq ""} {
	return
    }
    
    # on trace !
    set PAD [set Abr($AId,PAD)]
    lassign [$PAD bbox all] Axm Aym Axx Ayx
    $PAD create text 0 0 \
	    -text $txt \
	    -anchor nw -justify left \
	    -tags {Legend}
    lassign [$PAD bbox Legend] xm ym xx yx
    $PAD delete Legend
    set wx [expr {$xx-$xm+1}]
    set wy [expr {$yx-$ym+1}]
    # cherche dans zone si y a une place
    set fin 0
    for {set i $Axm} {$i <= $Axx} {incr i 10} {
	set x2 [expr {$i+$wx}]
	for {set j $Aym} {$j <= $Ayx} {incr j 10} {
	    set y2 [expr {$j+$wy}]
	    set Lt [$PAD find overlapping $i $j $x2 $y2]
	    if {$Lt == {} } {
		set fin 1
		break
	    }
	}
	if {$fin} {
	    break
	}
    }
    
    if {! $fin} {
	set lx $Axm ; set ly $Ayx
    } else {
	set lx $i  ; set ly $j
    }
    $PAD create text $lx $ly \
	    -text $txt \
	    -anchor nw -justify left \
	    -tags {Legend}

    return
}


proc DefineLegend {AId {quoi define}} {
    global Abr
    
    if {$quoi eq "clear"} {
	set Abr($AId,LegBoot)  1
	set Abr($AId,LegCoul)  0
	set Abr($AId,LegGap)   1
	set Abr($AId,LegSites) 1
	set Abr($AId,LegText)  ""
	set Abr($AId,Legend) ""
    }
    
    if {! $Abr($AId,AddLeg)} {
	$Abr($AId,PAD) delete Legend
	return
    }

    if {$Abr($AId,Legend) ne ""} {
	ShowTreeLegend $AId
	return
    }

    set w .legend
    toplevel $w
    wm title $w "Tree Caption"
    wm iconname $w "Caption"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix

    set wft $w.ftitre
    frame $wft
    grid $wft -row 0 -column 0 -sticky ew -padx 10 -pady 10
    label $wft.titre \
	    -text "Legend :" \
	    -font "Helvetica 14 bold" \
	    -anchor w -justify left
    label $wft.exp\
	    -text "Select the elements to be displayed as the tree caption" \
	    -anchor w -justify left
    grid $wft.titre -row 0 -column 0 -sticky ew -pady {5 10}
    grid $wft.exp   -row 1 -column 0 -sticky ew

    set wfe $w.felt
    frame $wfe
    label $wfe.ltxt \
	    -text "Caption :" \
	    -anchor w -justify left
    set Abr($AId,LegWText) $wfe.text
    text $wfe.text \
	    -relief flat \
	    -bd 2 -relief sunken \
	    -background white \
	    -width 30 -height 3
    checkbutton $wfe.gap\
	    -relief flat \
	    -anchor w -justify left \
	    -text "gap handling" \
	    -onvalue 1 \
	    -offvalue 0 \
	    -variable Abr($AId,LegGap)
    checkbutton $wfe.nst\
	    -relief flat \
	    -anchor w -justify left \
	    -text "number of sites" \
	    -onvalue 1 \
	    -offvalue 0 \
	    -variable Abr($AId,LegSites)
    checkbutton $wfe.boot \
	    -relief flat \
	    -anchor w -justify left \
	    -text "number of bootstrap and threshold" \
	    -onvalue 1 \
	    -offvalue 0 \
	    -variable Abr($AId,LegBoot)
    checkbutton $wfe.coul \
	    -relief flat \
	    -anchor w -justify left \
	    -text "groups colors" \
	    -onvalue 1 \
	    -offvalue 0 \
	    -variable Abr($AId,LegCoul)
    grid $wfe.ltxt -row 0 -column 0 -sticky w
    grid $wfe.text -row 1 -column 0 -sticky ew
    grid $wfe.gap  -row 2 -column 0 -sticky ew
    grid $wfe.nst  -row 3 -column 0 -sticky ew
    grid $wfe.boot -row 4 -column 0 -sticky ew
    grid $wfe.coul -row 5 -column 0 -sticky ew

    grid $wfe -row 1 -column 0 -sticky ew -padx 10 -pady 5
    grid columnconfig $wft all -weight 1

    set wfb $w.fbout
    frame $wfb
    button $wfb.bok \
	    -background green1 \
	    -text " OK " \
	    -command [list ShowTreeLegend $AId draw]
   button $wfb.bdis \
	    -background red \
	    -text "Dismiss" \
	    -command [list ShowTreeLegend $AId dismiss]
    grid $wfb.bdis -row 0 -column 0 -sticky w
    grid $wfb.bok  -row 0 -column 1 -sticky e
    grid $wfb -row 2 -column 0 -sticky ew -padx 10 -pady 10
    grid columnconfig $wfb all -weight 1

    update idletasks
    FenetreAuCentre $w
    set oldGrab [grab current .]
    grab $w

    tkwait window $w

    if {$oldGrab ne ""} {
	grab $oldGrab
    }

    return
}


proc OnReDessineArbre {AId args} {
    global Abr

    if {$args != ""} {
	set Abr($AId,TAff) [lindex $args 1]
    }
    
    set PAD [set Abr($AId,PAD)]
    $PAD delete all

    if {[set Abr($AId,TypeTree)] eq "dendrogram"} {
	ReDessineArbre $AId
    } else {
	ReDessineArbreCart $AId
	#ModeTagLeaf $AId
    }

    if {[set Abr($AId,Swap)]} {
	set Abr($AId,Swap) 0
	ModeSwap $AId
    }
    if {[set Abr($AId,Reroot)]} {
	set Abr($AId,Reroot) 0
	ModeReroot $AId
    }

    MontreBootstrap $AId
    
    ShowTreeLegend $AId
    
    return
}


proc ChangeLabelTree {AId} {
    global Abr

    # The tree should correspond to the ccorrect mac
    # (no instance : tree outside of an alignment)
    if {[info exists Abr($AId,Mac)] && $Abr($AId,Mac) != [MacCourant]} {
	if {[info exists Abr($AId,TAffPrec)]} {
	    set Abr($AId,TAff) $Abr($AId,TAffPrec)
	}
	FaireLire "Warning !\nThis tree was built for another instance of the alignment ([lindex [NomDeMac $Abr($AId,Mac)] 0]),\nnot for the current one ([MacCourant name]).\nDisplay its instance to change the labels."
	return
    }
    set Abr($AId,TAffPrec) $Abr($AId,TAff)
    
    # leaf labels are given by NomAffiche
   OnReDessineArbre $AId

    return
}


proc AfficheUnArbre {AId {InOrdali 1}} {
    global Abr Defauts WOrdali

    set w ".arbre$AId"
    if {[winfo exists $w]} {
	destroy $w
    }

    if {$InOrdali} {
    toplevel $w

	set top $w
    } else {
	frame $w
	grid rowconfig . 0 -weight 1
	grid columnconfig . 0 -weight 1
	grid $w -row 0 -column 0 -sticky news

	set top .
    }
    
    # instance of the tree (not the current one : trees of every
    # instance are drawn when an ORD file is opened), as its name
    set inst ""
    if {[info exists Abr($AId,Mac)]} {set pkm $Abr($AId,Mac)}
    if {[info exists pkm] && ! [catch {$::db onecolumn {select name from snapshot where pk_snap = :pkm}} nm] && $nm ne ""} {
	set inst " - Instance $nm"
    }
    wm title $top "Tree No $AId$inst"
    # label displayed : the list goes back to it when a change is
    # refused (tree of another instance)
    if {[info exists Abr($AId,TAff)]} {
	set Abr($AId,TAffPrec) $Abr($AId,TAff)
    }
    wm iconname $top "Tree $AId"
    wm protocol $top WM_DELETE_WINDOW KillParLaCroix

    if {[winfo exists .fattendre]} {
	lower $w .fattendre
    }

    frame $w.fc
    frame $w.fb
    # packing des deux frames principales
    grid $w.fc -row 0 -column 0 -sticky news
    grid $w.fb -row 1 -column 0 -sticky news
    grid rowconfig    $w 0 -weight 1
    grid columnconfig $w 0 -weight 1

    # Frame canvas + ascenceurs
    set wc "$w.fc.c"
    set Abr($AId,PAD) $wc
    set Abr($AId,ContextMenu) $w.fc.c.menu
    canvas $w.fc.c \
	-height [set Abr($AId,FHeight)] \
	-width  [set Abr($AId,FWidth)] \
	-scrollregion [list 0 0 [set Abr($AId,PADWdt)] [set Abr($AId,PADHgt)]] \
	-cursor hand2 \
	-background white \
	-relief groove \
	-xscrollcommand "$w.fc.hs set" \
	-yscrollcommand "$w.fc.vs set"
    
    scrollbar $w.fc.vs \
	-command "$wc yview" -width 8
    scrollbar $w.fc.hs \
	-orient horiz \
	-command "$wc xview" -width 8
    
    grid $w.fc.c  -row 0 -column 0 -sticky news
    grid $w.fc.vs -row 0 -column 1 -sticky ns
    grid $w.fc.hs -row 1 -column 0 -sticky ew
    grid rowconfig    $w.fc 0 -weight 1
    grid columnconfig $w.fc 0 -weight 1
    grid columnconfig $w.fc 1 -weight 0
    
    # Frame des fonctions 
    frame $w.fb.fsrp \
	-relief groove \
	-borderwidth 2
    set WOrdali(Tree,DenRad) $w.fb.fsrp.esra
    checkbutton $w.fb.fsrp.esra \
	-text "Dendro/Radial" \
	-anchor w -justify left \
	-onvalue dendrogram \
	-offvalue radial \
	-variable Abr($AId,TypeTree) \
	-command [list OnReDessineArbre $AId]
    checkbutton $w.fb.fsrp.swap \
	-text "swap nodes" \
	-anchor w -justify left \
	-variable Abr($AId,Swap) \
	-relief flat \
	-onvalue 1 \
	-offvalue 0 \
	-command [list ModeSwap $AId]
    set Abr($AId,BReroot) "$w.fb.fsrp.reroot"
    checkbutton $w.fb.fsrp.reroot \
	-text "re-root tree" \
	-anchor w -justify left \
	-disabledforeground dimgrey \
	-variable Abr($AId,Reroot) \
	-relief flat \
	-onvalue 1 \
	-offvalue 0 \
	-command [list ModeReroot $AId]
    set Abr($AId,BCollapse) $w.fb.fsrp.col
    checkbutton $w.fb.fsrp.col \
	-text "collapse tree" \
	-anchor w -justify left \
	-variable Abr($AId,CollapseTree) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list CollapseTree $AId]
    
    grid $w.fb.fsrp.esra   -row 0 -column 0 -sticky we
    grid $w.fb.fsrp.swap   -row 1 -column 0 -sticky we
    grid $w.fb.fsrp.reroot -row 2 -column 0 -sticky we
    grid rowconfig    $w.fb.fsrp all -weight 0
    grid columnconfig $w.fb.fsrp all -weight 1
    
    # Frame de display infos
    frame $w.fb.fa \
	-relief groove \
	-borderwidth 2
    checkbutton $w.fb.fa.phylum \
	-text "show phylum" \
	-anchor w -justify left \
	-variable Abr($AId,Phylum) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list PeintParPhylum $AId]
    # show bootstrap :
    # different cases if dendro or radial
    set Abr($AId,ShowBootDen) $w.fb.fa.boots
    checkbutton $w.fb.fa.boots \
	-text "show bootstrap" \
	-anchor w -justify left \
	-variable Abr($AId,BootShow) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list MontreBootstrap $AId]
    set Abr($AId,ShowBootRad) $w.fb.fa.fboo
    frame $w.fb.fa.fboo
    set Abr($AId,ThresBootPC) [set Defauts(ThresBootPC)]
    set Abr($AId,ThresBoot) [expr {1.0*$Abr($AId,ThresBootPC)*[set Defauts(TreeNBoot)]/100.}]
    checkbutton $w.fb.fa.fboo.b1 \
	-text "show boot" \
	-anchor w -justify left \
	-variable Abr($AId,BootShow) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list MontreBootstrap $AId]
    set Abr($AId,ThrBootEnt) $w.fb.fa.fboo.e1 
    entry $w.fb.fa.fboo.e1 \
	-background white \
	-textvariable Abr($AId,ThresBootPC) \
	-justify right \
	-width 3 \
	-validate none
    grid $w.fb.fa.fboo.b1 -row 0 -column 0
    grid $w.fb.fa.fboo.e1 -row 0 -column 1
    grid rowconfig    $w.fb.fa.fboo 0   -weight 0
    grid columnconfig $w.fb.fa.fboo all -weight 0
    
    checkbutton $w.fb.fa.shclus \
	-text "show clusters" \
	-anchor w -justify left \
	-variable Abr($AId,ShClusters) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list PeintParClusters $AId]
    
    grid $w.fb.fa.phylum -row 0 -column 0 -sticky we
    grid $w.fb.fa.fboo   -row 1 -column 0 -sticky we
    #grid $w.fb.fa.boots  -row 1 -column 0 -sticky we
    grid $w.fb.fa.shclus -row 2 -column 0 -sticky we
    grid rowconfig    $w.fb.fa all -weight 0
    grid columnconfig $w.fb.fa 0 -weight 1 -minsize 0
    # phylum : available if the life domain of at least one leaf
    # is known (Macsim/ORD file, or 'Retrieve Sequences information')
    set Abr($AId,BPhylum) $w.fb.fa.phylum
    MetAJourPhylumArbre $AId
    bind [set Abr($AId,ThrBootEnt)] <Return> [list ChangeThresholdBoot $AId]
    if {! [set Abr($AId,BootDone)]} {
	#$w.fb.fa.boots configure -state disabled
	$w.fb.fa.fboo.b1 configure -state disabled
	bind [set Abr($AId,ThrBootEnt)] <Return> ""
    }

    # Frame de redimentionnement de l'arbre
    # Deux frames :
    #    - cartesienne pour dendrgramme (width/height)
    #    - rotation    pour radial (rot/zoom)
    #
    # Pour dendogramme
    set Abr($AId,FDimXY) "$w.fb.fd"
    frame $w.fb.ft -relief groove -borderwidth 2

    set Abr($AId,FDimRZ) "$w.fb.fr"
    frame $w.fb.ft.f1
    checkbutton $w.fb.ft.f1.tnode \
	-text "Tag node" \
	-variable Abr($AId,DoTagNode) \
	-onvalue 1 \
	-offvalue 0 \
	-command [list ModeTagNode $AId]
    
    frame $w.fb.ft.f2
    set Wdt [PlusLongEltDe [set Abr($AId,LSeq)]]
    set Abr($AId,DoTagleaf) 0
    set Abr($AId,LeafSelOld) [lindex $Abr($AId,LSeq) 0]
    checkbutton $w.fb.ft.f2.ctag \
	-text "Tag" \
	-variable Abr($AId,DoTagLeaf) \
	-onvalue 1 \
	-offvalue 0
    set Abr($AId,CbLTag) $w.fb.ft.f2.stag
    ttk::combobox $w.fb.ft.f2.stag \
	-background white \
	-width 12 \
	-height 15 \
	-textvariable Abr($AId,LeafSel) \
	-state readonly \
	-values $Abr($AId,LSeq)
    $w.fb.ft.f2.stag index 0
    bind $w.fb.ft.f2.stag <<ComboboxSelected>> [list ModeTagLeaf $AId]
    frame $w.fb.ft.f3
    set Abr($AId,AddLeg)   0
    set Abr($AId,LegText)   ""
    set Abr($AId,LegBoot)  1
    set Abr($AId,LegCoul)  0
    set Abr($AId,LegGap)   1
    set Abr($AId,LegSites) 1
    set Abr($AId,Legend)   ""
    set Abr($AId,LegWText)  ""
    checkbutton $w.fb.ft.f3.ckleg \
	-text "Caption" \
	-anchor w -justify left \
	-onvalue 1 \
	-offvalue 0 \
	-variable Abr($AId,AddLeg) \
	-command [list DefineLegend $AId define]
    button $w.fb.ft.f3.clr \
	-text "Clear" \
	-bg white \
	-command [list DefineLegend $AId clear]
    
    grid columnconfig $w.fb.ft.f1 all -weight 1
    grid rowconfig    $w.fb.ft.f1 all -weight 1
    grid $w.fb.ft.f1.tnode -row 0 -column 0 -sticky ew
    
    grid $w.fb.ft.f2.ctag -row 0 -column 0 -sticky ew
    grid $w.fb.ft.f2.stag -row 0 -column 1 -sticky ew
    grid columnconfig $w.fb.ft.f2 all -weight 1
    grid rowconfig    $w.fb.ft.f2 all -weight 1
    
    grid $w.fb.ft.f3.ckleg -row 0 -column 0 -sticky ew
    grid $w.fb.ft.f3.clr   -row 0 -column 1 -sticky ew
    grid columnconfig $w.fb.ft.f3 all -weight 1
    grid rowconfig    $w.fb.ft.f3 all -weight 1
    
    #grid $w.fb.ft.f1 -row 0 -column 0 -sticky ew
    grid $w.fb.ft.f2 -row 1 -column 0 -sticky ew
    grid $w.fb.ft.f3 -row 2 -column 0 -sticky ew
    grid rowconfig    $w.fb.ft all -weight 0
    grid columnconfig $w.fb.ft all -weight 0
    
    #
    # gestion labels : on ecrit quoi
    frame $w.fb.ff -relief groove -borderwidth 2
    label $w.fb.ff.name \
	-text "Label" \
	-anchor w -justify left
    set cbw [PlusLongEltDe [set Abr(TypeAff)]]
    set Abr(toto) $w.fb.ff.chnm
    ttk::combobox $w.fb.ff.chnm \
	-background white \
	-width $cbw \
	-textvariable Abr($AId,TAff) \
	-state readonly \
	-values $Abr(TypeAff)
    bind $w.fb.ff.chnm <<ComboboxSelected>> [list ChangeLabelTree $AId]
    
    # gestion fonte
    label $w.fb.ff.ftsize \
	-text "font size" \
	-anchor w -justify left
    spinbox $w.fb.ff.fsz \
	-readonlybackground white \
	-width 6 \
	-state readonly \
	-values {6 8 10 12 14 16 18 20 22 24} \
	-command [list FonteMode $AId size %s]
    label $w.fb.ff.ftwght \
	-text "font weight" \
	-anchor w -justify left
    spinbox $w.fb.ff.fwh \
	-readonlybackground white \
	-width 6 \
	-state readonly \
	-values [list normal bold] \
	-command [list FonteMode $AId weight %s]
    grid $w.fb.ff.ftsize -row 0 -column 0 -sticky w
    grid $w.fb.ff.fsz    -row 0 -column 1 -sticky ew
    grid $w.fb.ff.ftwght -row 1 -column 0 -sticky w
    grid $w.fb.ff.fwh    -row 1 -column 1 -sticky ew
    if {[TypeAli] eq "XML" || [TypeAli] eq "ORD"} {
	grid $w.fb.ff.name -row 2 -column 0 -sticky w
	grid $w.fb.ff.chnm -row 2 -column 1
    }
    grid rowconfig    $w.fb.ff all -weight 0
    grid columnconfig $w.fb.ff all -weight 0
    
    # Print, save, close, reset
    frame $w.fb.fprc
    button $w.fb.fprc.print \
	-text "Print" \
	-background yellow \
	-command [list PrintCanvas $wc png]
    button $w.fb.fprc.save \
	-text "Save" \
	-background cyan \
	-command [list SaveTree $AId]
    set ::cmdDeb "$w.fb.fprc.reset"
    button $w.fb.fprc.reset \
	-text "Reset" \
	-background white \
	-command [list ResetArbre $AId $wc]
    button $w.fb.fprc.close \
	-text "Close" \
	-background red -foreground white \
	-command "DetruitArbre $AId"
    
    grid $w.fb.fprc.print -row 0 -column 0
    grid $w.fb.fprc.save  -row 1 -column 0
    grid $w.fb.fprc.reset -row 0 -column 1 -pady {1 5}
    grid $w.fb.fprc.close -row 1 -column 1 -pady {1 5}
    grid rowconfig    $w.fb.fprc all -weight 0
    grid columnconfig $w.fb.fprc all -weight 0
    
    #
    # Packing
    #
    grid $w.fb.fsrp -row 0 -column 0 -padx 5 -sticky news
    grid $w.fb.fa   -row 0 -column 1 -padx 5 -sticky news
    grid $w.fb.ft   -row 0 -column 2 -padx 5 -sticky news
    grid $w.fb.ff   -row 0 -column 3 -padx 5 -sticky news
    grid $w.fb.fprc -row 0 -column 4 -padx 5 -sticky ne -pady {1 5}
    grid columnconfig $w.fb 4   -weight 1
    grid rowconfig    $w.fb all -weight 1
    
    
    $w.fb.ff.fsz set [set Abr($AId,FontSize)]
    $w.fb.ff.fwh set [set Abr($AId,FontWght)]
    
    # bindings, trace , etc ...
    InitTreeContextMenu
    CreateTreeContextMenu $AId [set Abr($AId,ContextMenu)]
    bind $wc <Button-3> [list ShowTreeContextMenu $AId [set Abr($AId,ContextMenu)]]
    
    bind $wc <ButtonPress-1> {%W scan mark %x %y}
    bind $wc <B1-Motion> {%W scan dragto %x %y 1}
    
    bind $wc <4> {eval %W yview scroll -1 units}
    bind $wc <5> {eval %W yview scroll  1 units}
    bind $wc <Control-4> {eval %W xview scroll -1 units}
    bind $wc <Control-5> {eval %W xview scroll  1 units}

    trace add variable Abr($AId,TypeTree) write ChangeConfigFenetre
    trace add variable Abr($AId,DoTagNode) write ModeTagNode
    trace add variable Abr($AId,DoTagLeaf) write ModeTagLeaf

    DefineLegend $AId clear
    ChangeCurseur $AId normal
    MesCouleurs $w
    FenetreAuCentre $w

    OnReDessineArbre $AId

    update idletasks
    
    return
}


proc ChangeConfigFenetre {n1 n2 op} {
    global Abr

    lassign [split $n2 ,] AId TT

    if {[set Abr($n2)] eq "radial"} {
	grid forget [set Abr($AId,BReroot)]
	grid [set Abr($AId,BCollapse)] -row 2 -column 0 -sticky we
    } else {
	grid forget [set Abr($AId,BCollapse)]
	grid [set Abr($AId,BReroot)] -row 2 -column 0 -sticky we
    }

    if {0 && [set Abr($AId,BootDone)]} {
	if {[set Abr($AId,TypeTree)] eq "dendrogram"} {
	    #bind [set Abr($AId,ThrBootEnt)] <Return> ""
	    #grid forget [set Abr($AId,ShowBootRad)]
	    #grid [set Abr($AId,ShowBootDen)] -row 1 -column 0
	    grid forget [set Abr($AId,ShowBootDen)]
	    grid [set Abr($AId,ShowBootRad)] -row 1 -column 0
	} else {
	    grid forget [set Abr($AId,ShowBootDen)]
	    grid [set Abr($AId,ShowBootRad)] -row 1 -column 0
	    bind [set Abr($AId,ThrBootEnt)] <Return> [list ChangeThresholdBoot $AId]
	}
    }

    update idletasks

    return
}


proc DessineLigne {AId n xi yi xf yf} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set xi [SurGrille $xi]
    set yi [SurGrille $yi]
    set xf [SurGrille $xf]
    set yf [SurGrille $yf]

    if {$n ne "root"} {
	set id [$PAD create line $xi $yi $xf $yi \
		-fill black \
		-width 2 \
		-tags [list DItem "line-$n"]]
    }
    set id [$PAD create line $xf $yi $xf $yf \
	    -fill black \
	    -width 2 \
	    -tags [list DItem "line-$n"]]

    return
}


proc DessineLigneCirculaire {AId n xi yi xf yf} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set xi [SurGrille $xi]
    set yi [SurGrille $yi]
    set xf [SurGrille $xf]
    set yf [SurGrille $yf]

    if {$n ne "root"} {
	set id [$PAD create line $xi $yi $xf $yf \
		-fill black \
		-width 2]
    }

    return
}



proc MarquePourReroot {AId n xi y xf} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]

    set x1 [expr {[SurGrille [expr {($xi+$xf)/2}]] - 4}]
    set x2 [expr {[SurGrille [expr {($xi+$xf)/2}]] + 4}]
    set y1 [expr {[SurGrille $y] - 4}]
    set y2 [expr {[SurGrille $y] + 4}]

    set Id [$PAD create oval $x1 $y1 $x2 $y2 \
	    -fill white \
	    -outline white \
	    -tags reroot]

    $PAD lower $Id
    $t set $n IdRer $Id

    return
}


proc CollapseTree {AId} {
    global Abr

    if {! [set Abr($AId,BootDone)]} {
	return
    }
    if {[set Abr($AId,CollapseTree)]} {
	CollapseBranche $AId root
    } else {
	set t [set Abr(Arbre,$AId)]
	set Ser [set Abr(ArbreSer,$AId)]
	$t destroy
	struct::tree $t
	$t deserialize $Ser
	$t set root r 0.0
	$t set root theta 0.0
	$t set root oldtheta 0.0
	$t set root length 0.0
	$t set root width [llength [$t leaves]]
    }

    OnReDessineArbre $AId

    return
}


proc CollapseBranche {AId n} {
    set t [set ::Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}
    
    foreach e [$t children $n] {
	CollapseBranche $AId $e
    }
    if {$n eq "root"} {return}
    if {[$t get $n nboot] < [set ::Abr($AId,ThresBoot)]} {
	$t cut $n
	#CollapseDescendants $AId $n
    }

    return
}


proc CollapseDescendants {AId n} {
    set t [set ::Abr(Arbre,$AId)]
    foreach c [$t descendants $n] {
	if {! [$t isleaf $c]} {
	    $t cut $c
	}
    }

    return
}


proc ChangeThresholdBoot {AId} {
    global Abr Defauts

    set val [set Abr($AId,ThresBootPC)]
    if {! [regexp {^[0-9]+$} $val]} {return}
    set Abr($AId,ThresBoot) [expr {1.0*[set Defauts(TreeNBoot)]*$val/100.}]

    if {[set Abr($AId,BootShow)]} {
	MontreBootstrap $AId
    }

    return
}


proc MontreBootstrap {AId} {
    global Abr

    set res ""
    catch {set res [info level -1]}

    # no bootstrap, do nothing
    if {! [set Abr($AId,BootDone)]} {
	return
    }

    set PAD [set Abr($AId,PAD)]
    set t [set Abr(Arbre,$AId)]
    if {[set Abr($AId,BootShow)]} {
	if {[set Abr($AId,Swap)]} {
	    set Abr($AId,Swap) 0
	    ModeSwap $AId
	}
	if {[set Abr($AId,Reroot)]} {
	    set Abr($AId,Reroot) 0
	    ModeReroot $AId
	}
	update idletasks
	
	# little circles at each node
	foreach {n i} [$t attr IdRot] {
	    # For Marie S.
	    # Only show green circles
	    #$PAD raise $i
	    if {[$t get $n nboot] >= [set Abr($AId,ThresBoot)]} {
		$PAD raise $i
		set cf green1
	    } else {
		set cf red
	    }
	    $PAD itemconfig $i -fill $cf -outline black
	    if {[set Abr($AId,TypeTree)] eq "radial"} {
		InitBalloonOnItem $PAD $i "[$t get $n nboot]"
	    }
	}
	
	# for dendrogram, print the bootstrap value
	foreach i [$PAD find withtag "bootmark"] {
	    $PAD itemconfig $i -fill blue
	}
    } else {
	foreach {n i} [$t attr IdRot] {
	    $PAD lower $i
	    $PAD itemconfig $i -fill white -outline white
	    if {[set Abr($AId,TypeTree)] ne "dendrogram"} {
		$PAD bind $i <Enter> ""
		$PAD bind $i <Leave> ""
	    }
	}

	# for dendrogram, clean the bootstrap value
	foreach i [$PAD find withtag "bootmark"] {
	    $PAD itemconfig $i -fill white
	}
    }

    return
}


proc AfficheBootstrap {AId n} {

    set t   [set ::Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}

    foreach e [$t children $n] {
	AfficheBootstrap $AId $e
    }
    if {$n eq "root"} {return}

    set PAD  [set ::Abr($AId,PAD)]
    set ir   [$t get $n IdRot]
    set Lbox [$PAD bbox $ir]

    MarqueBootstrap $AId $n $Lbox $ir

    return
}


proc MarqueBootstrap {AId n Lbox ir} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]

    set anc se
    set jus right
    # x1,y1 coin sup gauche, x2,y2 coin inf droit
    lassign $Lbox x1 y1 x2 y2
    set x [expr {[SurGrille $x1] - 1}]
    set y [expr {[SurGrille $y1]}]

    set Id [$PAD create text $x $y \
	    -font "TreeFontBoot$AId" \
	    -fill white \
	    -text "[$t get $n nboot]" \
	    -anchor $anc -justify $jus \
	    -tags {bootmark "boot-$n"}]

    return
}


proc MarquePourRotation {AId n x y} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]

    set x  [SurGrille $x]
    set x1 [expr {$x - 3}]
    set x2 [expr {$x + 3}]
    set y  [SurGrille $y]
    set y1 [expr {$y - 3}]
    set y2 [expr {$y + 3}]

    set Id [$PAD create oval $x1 $y1 $x2 $y2 \
	    -fill white \
	    -outline white \
	    -tags [list rotation "rota-$n"]]
    if {$n eq "root"} {
	$PAD itemconfi $Id -tags {rotation rotroot}
    }

    $PAD lower $Id

    $t set $n IdRot $Id

    return
}


proc PlusLongNomAff {AId} {
    global Abr

    set t [set Abr(Arbre,$AId)]

    set Lm -1
    set Nom ""
    foreach n [$t leaves] {
	set NAff [NomAffiche $AId $n]
	set Lg [font measure "TreeFont$AId" $NAff]
	if {$Lg > $Lm} {
	    set Lm $Lg
	}
    }

    return $Lm
}


proc CoordsNom {AId n x y} {
    global Abr

    set t [set Abr(Arbre,$AId)]

    set Angle [$t get $n oldtheta]
    while {$Angle >=  [2Pi]} {set Angle [expr {$Angle-[2Pi]}]}
    while {$Angle <= -[2Pi]} {set Angle [expr {$Angle+[2Pi]}]}
    if {$Angle < 0.} {set Angle [expr {$Angle+[2Pi]}]}

    set NAff [NomAffiche $AId $n]
    set Lg [font measure "TreeFont$AId" $NAff]
    set x [expr {$x + $Lg*cos($Angle)}]
    set y [expr {$y + $Lg*sin($Angle)}]

    return [list $x $y]
}


proc NomAffiche {AId n} {
    global Abr TDesOrganismes TDesBId TDesDescriptifs TDesSeqnames TDesAccess

    if {[TypeAli] ni [list "XML" "ORD"]} {return $n}

    # label is one field of Abr(TypeAff), or several joined by " + "
    set Lv {}
    foreach f [split [string map {" + " +} $Abr($AId,TAff)] +] {
	switch $f {
	    "Seq.Name"    {set t TDesSeqnames    ; set def $n}
	    "Accession"   {set t TDesAccess      ; set def $n}
	    "BankId"      {set t TDesBId         ; set def $n}
	    "Organism"    {set t TDesOrganismes  ; set def "Unknown"}
	    "Description" {set t TDesDescriptifs ; set def "None"}
	    default {continue}
	}
	if {[info exists ${t}($n)] && [set ${t}($n)] ne ""} {
	    lappend Lv [set ${t}($n)]
	} else {
	    lappend Lv $def
	}
    }
    if {$Lv == {}} {
	return $n
    }

    return [join $Lv " - "]
}


proc EcritNom {AId n x1 y1 x2 y2} {
    global Abr

    set NAff [NomAffiche $AId $n]

    set PAD [set Abr($AId,PAD)]
    set xi [SurGrille $x1]
    set yi [SurGrille $y1]
    set xf [SurGrille $x2]
    set yf [SurGrille $y2]
    set ym [expr {($yi+$yf)/2 +1}]
    if {$xi != $xf} {
	set id [$PAD create line $xi $yi $xf $yi \
		-fill black \
		-width 2 \
		-tags "line-$n"]
    }
    set id [$PAD create text [expr {$xf+1}] $ym \
	    -font "TreeFont$AId" \
	    -fill black \
	    -text "$NAff" \
	    -anchor w -justify left \
	    -tags "feuille-$n"]
    set Lc [$PAD bbox $id]
    set Id [$PAD create rectangle $Lc \
	    -fill white \
	    -outline white \
	    -tags "Rfeuille-$n"]

    $PAD lower $Id

    return
}


proc ImgDeNomPIX {f sz w h txt angle} {

    set t2 [image create photo]
    set d [pixane create -tkphoto $t2]

    pixane resize $d $w $h
    pixane blank $d
    pixane color $d black
    pixane text $d [expr {$w/2}] [expr {$h/2}] \
	    -text $txt \
	    -font $f \
	    -size $sz \
	    -align center \
	    -valign middle \
	    -angle $angle

    set bon [RogneImage $t2]
    #    OpacifieImage $bon white 0

    pixane delete $d

    return $bon
}


proc ImgDeNomBLT {txt fm sz md angle} {
    package require BLT

    # Pour arbre radial, on se met en bold, un point c'est tout !
    set md "bold"
    if {$angle > 90. && $angle < 270.} {set jus right} {set jus left}
    set fm [string trim $fm]
    regsub -all " " $fm "" fm
    set fmt "*-family-mode-R-Normal-*-size-*"
    regsub "family" $fmt "$fm" fmt
    regsub "mode" $fmt "$md" fmt
    regsub "size" $fmt "$sz" fmt

    set i 0
    while {1} {
	if {! [::blt::bitmap exists "BltImg$i"]} {break}
	incr i
    }

    ::blt::bitmap compose "BltImg$i" "$txt" \
	    -font "$fmt" \
	    -rotate $angle

    return "BltImg$i"
}


proc EcritNomCart85 {AId n x y Angle} {
    global Abr

    set sz [set Abr($AId,FontSize)]

    while {$Angle >=  [2Pi]} {set Angle [expr {$Angle-[2Pi]}]}
    while {$Angle <= -[2Pi]} {set Angle [expr {$Angle+[2Pi]}]}
    if {$Angle < 0.} {set Angle [expr {$Angle+[2Pi]}]}

    set NAff [NomAffiche $AId $n]
    set PAD [set Abr($AId,PAD)]
    set xg $x
    set yg $y

    set f [set Abr($AId,pixfont)]
    lassign [pixfont measure $f $sz $NAff] w h1 h2
    set Off 2
    #    set h $sz
    set h [expr {$sz+$Off}]

    set AngOri $Angle

    if {$Angle <= [PiS2]} {
	set Pxy [list $x [expr {$y-$h/2}] $x [expr {$y+$h/2}] [expr {$x+$w}] [expr {$y+$h/2}] [expr {$x+$w}] [expr {$y-$h/2}]]
    } elseif {$Angle > [PiS2] && $Angle < [Pi]} {
	set Angle [expr {$Angle+[Pi]}]
	set Pxy [list $x [expr {$y-$h/2}] $x [expr {$y+$h/2}] [expr {$x-$w}] [expr {$y+$h/2}] [expr {$x-$w}] [expr {$y-$h/2}]]
    } elseif {$Angle > [Pi] && $Angle < 3.*[PiS2]} {
	set Angle [expr {$Angle+[Pi]}]
	set Pxy [list $x [expr {$y-$h/2}] $x [expr {$y+$h/2}] [expr {$x-$w}] [expr {$y+$h/2}] [expr {$x-$w}] [expr {$y-$h/2}]]
    } else {
	set Pxy [list $x [expr {$y-$h/2}] $x [expr {$y+$h/2}] [expr {$x+$w}] [expr {$y+$h/2}] [expr {$x+$w}] [expr {$y-$h/2}]]
    }

    if {$Angle > [Pi]} {set Angle [expr {$Angle-[2Pi]}]}

    set xmin 99999 ; set xmax -999999
    set ymin 99999 ; set ymax -999999
    foreach {xp yp} $Pxy {
	lassign [TourneBoite $x $y $xp $yp $Angle] nx ny
	set nx [expr {round($nx)}]
	set ny [expr {round($ny)}]
	set xmin [expr {$nx<$xmin?$nx:$xmin}]
	set ymin [expr {$ny<$ymin?$ny:$ymin}]
	set xmax [expr {$nx>$xmax?$nx:$xmax}]
	set ymax [expr {$ny>$ymax?$ny:$ymax}]
	lappend Lc $nx $ny
    }
    set w2 [expr {abs($xmax-$xmin+0*$Off)}]
    set h2 [expr {abs($ymax-$ymin+0*$Off)}]

    set dy 0
    set dx 0
    set sh2 [expr {round(($h2+$Off)/4)}]
    set sw2 [expr {round(($w2+$Off)/4)}]
    #    set sz2 [expr {round($sz/2)}]
    #    set sz2 $sz
    set ian [expr {int(floor($AngOri/[PiS16]))}]
    switch $ian {
	30 {set anc "w" ; set dy -$sh2}
	31 - 32 - 0 {set anc "w"}
	1 {set anc "w" ; set dy $sh2}

	2 {set anc "nw" ; set dy 0}
	3 - 4 {set anc "nw"}
	5 {set anc "nw" ; set dy 0}

	6 {set anc "n" ; set dx $sw2}
	7 -  8 {set anc "n"}
	9 {set anc "n" ; set dx -$sw2}

	10 {set anc "ne" ; set dy 0}
	11 - 12 {set anc "ne"}
	13 {set anc "ne" ; set dy 0}

	14 {set anc "e" ; set dy $sh2}
	15 - 16 {set anc "e"}
	17 {set anc "e" ; set dy -$sh2}

	18 {set anc "se" ; set dy 0}
	19 - 20 {set anc "se"}
	21 {set anc "se" ; set dy 0}

	22 {set anc "s" ; set dx -$sw2}
	23 - 24 {set anc "s"}
	25 {set anc "s" ; set dx $sw2}

	26 {set anc "sw" ; set dy 0}
	27 - 28 {set anc "sw"}
	29 {set anc "sw" ; set dy 0}
    }

    set INAff [ImgDeNomPIX $f $sz $w2 $h2 $NAff $Angle]

    # ORIGINE image en xg yg
    set id [$PAD create image [expr {$x+$dx}] [expr {$y+$dy}] \
	    -anchor $anc \
	    -image $INAff \
	    -tags "feuille-$n"]

    set Id [$PAD create polygon $Lc \
	    -fill white \
	    -outline white \
	    -width 0 \
	    -tags "Rfeuille-$n"]

    $PAD lower $Id

    return
}


proc EcritNomCart {AId n x y Angle} {
    global Abr

    while {$Angle >=  [2Pi]} {set Angle [expr {$Angle-[2Pi]}]}
    while {$Angle <= -[2Pi]} {set Angle [expr {$Angle+[2Pi]}]}
    set Angle [expr {$Angle*-180./[Pi]}]
    if {$Angle < 0.} {set Angle [expr {$Angle+360.}]}

    set NAff [NomAffiche $AId $n]
    set PAD [set Abr($AId,PAD)]

    if {$Angle > 90. && $Angle < 270.} {
	set anc e
	set jus right
	set Angle [expr {$Angle+180.}]
    } else {
	set anc w
	set jus left
    }

    set id1 [$PAD create text $x $y \
	    -text " $NAff " \
	    -font "TreeFont$AId" \
	    -justify $jus \
	    -anchor $anc]
    set bb [$PAD bbox $id1]
    $PAD delete $id1
    lassign $bb x1 y1 x2 y2
    set Lp [list $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1]

    set id [$PAD create text $x $y \
	    -text " $NAff" \
	    -anchor $anc \
	    -font "TreeFont$AId" \
	    -angle $Angle \
	    -tags "feuille-$n"]

    set Angle [expr {-1.*$Angle}]
    foreach {xp yp} $Lp {
	lassign [TourneBoiteD $x $y $xp $yp $Angle] nx ny
	lappend Lc $nx $ny
    }
    set Id [$PAD create polygon $Lc \
	    -fill white \
	    -outline white \
	    -width 0 \
	    -tags "Rfeuille-$n"]

    $PAD lower $Id

    return
}


proc EcritNomCirculaire {AId n x1 y1 x2 y2 Angle} {
    global Abr
    global TextFeuille MemoXY

    if { ! [info exists TextFeuille]} { set TextFeuille -1 }
    incr TextFeuille

    set fm [font configure TreeFont$AId -family]
    regsub -all " " $fm "" fm
    set sz [font configure TreeFont$AId -size]
    set md [font configure TreeFont$AId -weight]

    set NAff [NomAffiche $AId $n]
    #    set NAff $TextFeuille

    set PAD [set Abr($AId,PAD)]
    set xi [SurGrille $x1]
    set yi [SurGrille $y1]
    set xf [SurGrille $x2]
    set yf [SurGrille $y2]

    set yg $yf
    if {$Angle <= acos(0)} {
	set anc "nw"
	set xg $xf
    } elseif {$Angle > acos(0) && $Angle < acos(-1)} {
	set xg $xf
	set anc "ne"
	set Angle [expr {$Angle+acos(-1)}]
    } elseif {$Angle > acos(-1.) && $Angle < asin(-1)+2*acos(-1)} {
	set xg $xf
	set anc "se"
	set Angle [expr {$Angle+acos(-1)}]
    } else {
	set xg [expr {$xf+2}]
	set anc "sw"
    }
    set Angle [expr {-1.*$Angle}]
    set INAff [ImgDeNom $NAff $fm $sz $md $Angle]
    OpacifieImage $INAff white 0

    set yTF $yf
    if {[info exists MemoXY($xf,$yf)]} {set yTF [expr {$yf + 10}] }
    set MemoXY($xf,$yf) 1

    set id [$PAD create line $xi $yi $xf $yf \
	    -fill black \
	    -width 2]


    set id [$PAD create image $xg $yg \
	    -anchor $anc -image $INAff \
	    -tags "feuille-$n"]
    set Lc [$PAD bbox $id]
    set Id [$PAD create rectangle $Lc \
	    -fill white \
	    -outline white \
	    -tags "Rfeuille-$n"]

    $PAD lower $Id

    return
}


proc ReDessineArbre {AId args} {
    global Abr

    set PAD [set Abr($AId,PAD)]
    $PAD delete all

    DessineArbre $AId root 20 20

    lassign [$PAD bbox all] x1 y1 x2 y2
    set dx [expr {$x2-$x1+50}]
    set dy [expr {$y2-$y1+50}]
    $PAD move all [expr {-$x1+20}] [expr {-$y1+20}]
    if {$dx < [set Abr($AId,PADWdt)]} {set dx [set Abr($AId,PADWdt)]}
    if {$dy < [set Abr($AId,PADHgt)]} {set dy [set Abr($AId,PADHgt)]}
    $PAD configure -scrollregion [list 0 0 $dx $dy]

    if {[set Abr($AId,BootDone)]} {
	AfficheBootstrap $AId root
	MontreBootstrap $AId
    }
    
    if {[TypeAli] in {"XML" "ORD"}} {
	PeintParPhylum $AId
    }

    PeintParClusters $AId

    return
}


proc AjusteXY {AId n px py {mult 1.}} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    foreach xa {xO xE} ya {yO yE} {
	set x [$t get $n $xa]
	set y [$t get $n $ya]
	set nx [expr {($x+$px)*$mult}]
	set ny [expr {($y+$py)*$mult}]
	$t set $n $xa $nx
	$t set $n $ya $ny
    }

    foreach e [$t children $n] {
	AjusteXY $AId $e $px $py $mult
    }

    return
}


proc AjusteScrollRegion AId {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set Lal [$PAD bbox all]
    lassign $Lal x1 y1 x2 y2
    set Dx  [expr {$x2-$x1}]
    set Dy  [expr {$y2-$y1}]
    $PAD configure -scrollregion [list $x1 $y1 $Dx $Dy]

    update idletasks

    return
}


proc RecentreArbre {AId} {
    global Abr

    set PAD [set Abr($AId,PAD)]

    set Offset 20
    lassign [$PAD bbox all] x1 y1 x2 y2
    $PAD move all [expr {-1*$x1 + $Offset}] [expr {-1*$y1 + $Offset}]

    lassign [$PAD bbox all] x1 y1 x2 y2
    set xm [expr {($x2-$x1) + 2*$Offset}]
    set ym [expr {($y2-$y1) + 2*$Offset}]
    $PAD configure -scrollregion [list 0 0 $xm $ym] -width $xm -height $ym

    set x [expr {int($xm/2)}]
    set y [expr {int($ym/2)}]
    $PAD xview scroll $x units
    $PAD yview scroll $y units

    return
}


proc ReAjusteCoordonnees AId {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]
    set Of  20

    $PAD xview moveto 0.0
    $PAD yview moveto 0.0
    set LDes [$PAD bbox all]
    lassign $LDes x1 y1 x2 y2
    foreach d [$t nodes] {
	$t set $d xdes [expr {[$t get $d xdes]-$x1+$Of}]
	$t set $d ydes [expr {[$t get $d ydes]-$y1+$Of}]
    }
    set xm [expr {($x2-$x1)+2*$Of}]
    set ym [expr {($y2-$y1)+2*$Of}]

    $PAD configure -scrollregion [list 0 0 $xm $ym]
    $PAD move all [expr {-$x1+$Of}] [expr {-$y1+$Of}]
    set x [expr {int($xm/2)}]
    set y [expr {int($ym/2)}]
    $PAD xview scroll $x units
    $PAD yview scroll $y units

    return
}


proc ReAjusteCoordonnees2 AId {
    global Abr

    set PAD [set Abr($AId,PAD)]
    set t   [set Abr(Arbre,$AId)]
    set PL  [PlusLongNomAff $AId]

    # Recentrage + Offset
    # Offset = longuer du nom le + grd mis a l'horizontale
    set LDes [$PAD bbox all]
    lassign $LDes x1 y1 x2 y2
    foreach d [$t nodes] {
	$t set $d xdes [expr {[$t get $d xdes]-$x1+$PL}]
	$t set $d ydes [expr {[$t get $d ydes]-$y1+$PL}]
    }
    set xm [expr {($x2-$x1)+2*$PL}]
    set ym [expr {($y2-$y1)+2*$PL}]

    $PAD configure -scrollregion [list 0 0 $xm $ym]

    return
}


proc AjusteCoordonneesInit {AId} {
    global Abr

    set t   [set Abr(Arbre,$AId)]
    set PWd [set Abr($AId,PADWdt)]
    set PHg [set Abr($AId,PADHgt)]
    set Wdt [set Abr($AId,FWidth)]
    set Hgt [set Abr($AId,FHeight)]
    set LongNom [PlusLongNomAff $AId]

    if {! [info exists Abr($AId,DMult)]} {
	# set mult [expr {($Wdt-2*$LongNom)/[set Abr($AId,Dmax)]}]
	set mult [expr {($Wdt-2*$LongNom)/[set Abr($AId,rmax)]}]
	set Abr($AId,DMult) $mult
    }

    set Xmin  99999999.
    set Ymin  99999999.
    set Xmax -99999999.
    set Ymax -99999999.
    set m [set Abr($AId,DMult)]
    set m 1.0
    foreach d [$t nodes] {
	set x [expr {$m * [$t get $d xcoord]}]
	set y [expr {$m * [$t get $d ycoord]}]
	$t set $d xdes $x
	$t set $d ydes $y

	set Xmin [expr {$Xmin<$x?$Xmin:$x}]
	set Ymin [expr {$Ymin<$y?$Ymin:$y}]
	set Xmax [expr {$Xmax>$x?$Xmax:$x}]
	set Ymax [expr {$Ymax>$y?$Ymax:$y}]
    }

    set Abr($AId,XminR) $Xmin
    set Abr($AId,YminR) $Ymin
    set Abr($AId,XmaxR) $Xmax
    set Abr($AId,YmaxR) $Ymax

    return
}


proc AjusteCoordonneesInit2 {AId} {
    global Abr

    set t   [set Abr(Arbre,$AId)]
    set PWd [set Abr($AId,PADWdt)]
    set PHg [set Abr($AId,PADHgt)]
    set Wdt [set Abr($AId,FWidth)]
    set Hgt [set Abr($AId,FHeight)]
    set sca [set Abr($AId,ScaleR)]
    set LongNom [PlusLongNomAff $AId]

    #    set HgF   [font metrics "TreeFont$AId" -linespace]
    set HgF  [font configure "TreeFont$AId" -size]
    set rmin [set Abr($AId,rmin)]
    set rmax [set Abr($AId,rmax)]
    set sang [set Abr($AId,subangleMax)]
    set mult [expr {abs($HgF/($rmax*sin($sang)))}]

    if {0} {
	puts "PWd $PWd PHg $PHg Wdt $Wdt Hgt $Hgt"
	puts "HgF $HgF"
	puts "rmin $rmin"
	puts "rmax $rmax"
	puts "sang $sang"
	puts "mult $mult"
	puts "long Nom $LongNom"
	puts ""
    }

    # Taille de arbre sans les noms au bout
    # des feuilles
    set Xmin  99999999.
    set Ymin  99999999.
    set Xmax -99999999.
    set Ymax -99999999.
    foreach d [$t nodes] {
	set x [expr {$mult*[$t get $d xcoord]}]
	set y [expr {$mult*[$t get $d ycoord]}]
	#	set x [expr {$sca*$mult*[$t get $d xcoord]+$LongNom}]
	#	set y [expr {$sca*$mult*[$t get $d ycoord]+$LongNom}]
	$t set $d xcoord $x
	$t set $d ycoord $y

	set Xmin [expr {$Xmin<$x?$Xmin:$x}]
	set Ymin [expr {$Ymin<$y?$Ymin:$y}]
	set Xmax [expr {$Xmax>$x?$Xmax:$x}]
	set Ymax [expr {$Ymax>$y?$Ymax:$y}]
    }

    if {0} {
	puts "Min/Max SANS FEUILLES"
	puts "Xmin $Xmin"
	puts "Ymin $Ymin"
	puts "Xmax $Xmax"
	puts "Ymax $Ymax"
	puts ""
    }

    # Recentre Arbre sans feuille
    foreach d [$t nodes] {
	set x [expr {[$t get $d xcoord]-$Xmin}]
	set y [expr {[$t get $d ycoord]-$Ymin}]
	$t set $d xcoord $x
	$t set $d ycoord $y
    }

    set Xmin 0.
    set Ymin 0.
    set Xmax [expr {$Xmax-$Xmin}]
    set Ymax [expr {$Ymax-$Ymin}]

    set DX [expr {$Xmax-$Xmin}]
    set DY [expr {$Ymax-$Ymin}]
    set PlacePW [expr {$PWd - 2*$LongNom}]
    set PlacePH [expr {$PHg - 2*$LongNom}]
    if {$DX > $PlacePW || $DY > $PlacePH} {
	if {$DX - $PlacePW > $DY - $PlacePH} {
	    set mult [expr {$PlacePW/$DX}]
	} else {
	    set mult [expr {$PlacePH/$DY}]
	}
    }
    set PlaceSW [expr {$Wdt - 2*$LongNom}]
    set PlaceSH [expr {$Hgt - 2*$LongNom}]
    if {$DX < $PlaceSW && $DY < $PlaceSH} {
	if {$PlaceSW-$DX > $PlaceSH-$DY} {
	    set mult [expr {$PlaceSH/$DY}]
	} else {
	    set mult [expr {$PlaceSW/$DX}]
	}
    }
    #    puts "mult apres $mult"

    set NXmin  99999999999.
    set NYmin  99999999999.
    set NXmax -99999999999.
    set NYmax -99999999999.
    foreach d [$t nodes] {
	set OldX [$t get $d xcoord]
	set OldY [$t get $d ycoord]
	set x [expr {$mult*$OldX + $LongNom}]
	set y [expr {$mult*$OldY + $LongNom}]
	$t set $d xcoord $x
	$t set $d ycoord $y
	if {[$t isleaf $d]} {
	    lassign [CoordsNom $AId $d $x $y] x y
	}

	set NXmin [expr {$NXmin<$x?$NXmin:$x}]
	set NYmin [expr {$NYmin<$y?$NYmin:$y}]
	set NXmax [expr {$NXmax>$x?$NXmax:$x}]
	set NYmax [expr {$NYmax>$y?$NYmax:$y}]
    }

    set Abr($AId,XminR) $NXmin
    set Abr($AId,YminR) $NYmin
    set Abr($AId,XmaxR) $NXmax
    set Abr($AId,YmaxR) $NYmax

    if {0} {
	puts "Abr($AId,Xmin) $Xmin"
	puts "Abr($AId,Ymin) $Ymin"
	puts "Abr($AId,Xmax) $Xmax"
	puts "Abr($AId,Ymax) $Ymax"
	puts ""
    }

    return
}


proc AjusteXYCart {AId n mx my {mult 1.}} {
    global Abr
    global Xmin Xmax Ymin Ymax

    set t  [set Abr(Arbre,$AId)]
    set x  [$t get $n xcoord]
    set y  [$t get $n ycoord]
    set nx [expr {(($x+abs($Xmin))*$mx)*$mult}]
    set ny [expr {(($y+abs($Ymin))*$my)*$mult}]
    $t set $n xcoord $nx
    $t set $n ycoord $ny

    set Xmin [expr {$Xmin<$nx?$Xmin:$nx}]
    set Ymin [expr {$Ymin<$ny?$Ymin:$ny}]
    set Xmax [expr {$Xmax>$nx?$Xmax:$nx}]
    set Ymax [expr {$Ymax>$ny?$Ymax:$ny}]

    foreach e [$t children $n] {
	AjusteXYCart $AId $e $mx $my $mult
    }

    return
}


proc ReDessineArbreCart {AId args} {
    global Abr Xmin Xmax Ymin Ymax
    
    set PAD [set Abr($AId,PAD)]
    $PAD delete all

    # from angular coordinates to (x,y) 
    set ::iter 0
    if {$Abr($AId,firstTimeZoom)} {
	set Abr($AId,firstTimeZoom) 0
	TransformationCartesienne $AId root
	set dx [expr {$Xmax - $Xmin}]
	set dy [expr {$Ymax - $Ymin}]
	set scaX [expr {[$PAD cget -width]/$dx}]
	set scaY [expr {[$PAD cget -height]/$dy}]
	if {$scaX > $scaY} {
	    set Abr($AId,ScaleR) $scaY
	    set Abr($AId,incrScaleR) [expr {0.2 * $scaY}]
	} else {
	    set Abr($AId,ScaleR) $scaX
	    set Abr($AId,incrScaleR) [expr {0.2 * $scaX}]
	}
    }
    TransformationCartesienne $AId root
	
    #AjusteCoordonneesInit $AId
    #ScaleArbre $AId $args
    RetraceToutCart $AId root
    #ScaleArbre2 $AId $args
    #ReAjusteCoordonnees $AId
    RecentreArbre $AId

    if {[set Abr($AId,BootDone)]} {
	#AfficheBootstrap $AId root
	MontreBootstrap $AId
    }

    if {[TypeAli] in {"XML" "ORD"}} {
	PeintParPhylum $AId
    }

    PeintParClusters $AId

    return
}


proc ReDessineArbreCirculaire {AId args} {
    global Abr
    global CurrAng

    set PAD [set Abr($AId,PAD)]
    $PAD delete all

    set CurrAng 0.
    CalculeDimensionsArbre $AId

    set SWdt [expr {int([set Abr($AId,Xmax)]-[set Abr($AId,Xmin)]+10)}]
    set SHgt [expr {int([set Abr($AId,Ymax)]-[set Abr($AId,Ymin)]+10)}]
    set MWdt [expr {$SWdt/2}]
    set MHgt [expr {$SHgt/2}]
    if {0} {
	puts "Xmin [set Abr($AId,Xmin)]"
	puts "Xmax [set Abr($AId,Xmax)]"
	puts "Ymin [set Abr($AId,Ymin)]"
	puts "Ymax [set Abr($AId,Ymax)]"
	puts "SWdt $SWdt SHgt $SHgt"
	puts "MWdt $MWdt MHgt $MHgt"
	puts ""
    }
    $PAD configure -scrollregion [list 0 0 $SWdt $SHgt]
    update idletasks

    $PAD create oval [expr {-1*$Abr($AId,Xmin)-6}] [expr {-1*$Abr($AId,Ymin)-6}] [expr {-1*$Abr($AId,Xmin)+6}] [expr {-1*$Abr($AId,Ymin)+6}] -fill magenta
    AjusteXY $AId root [expr {-1*$Abr($AId,Xmin)}] [expr {-1*$Abr($AId,Ymin)}]

    set CurrAng 0.
    DessineArbreCirculaire $AId root [expr {-1*$Abr($AId,Xmin)}] [expr {-1*$Abr($AId,Ymin)}]

    if {[TypeAli] in [list "XML" "ORD"]} {
	PeintParPhylum $AId
    }

    #    AmelioreArbre $AId
    Daylight $AId

    update idletasks

    return
}


proc DessineArbre {AId n xCsg yCsg} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set OffsetX [set Abr($AId,OffsetX)]
    set OffsetY [expr {[set Abr($AId,OffsetY)]/2+1}]
    set Increment [set Abr($AId,Increment)]

    set l [$t get $n length]
    if {$l != -1} {
	set l [expr {int($l*$Increment+$OffsetX)}]
    }

    set xP $xCsg
    set yP [expr {$yCsg+$OffsetY}]

    set xE [expr {$xCsg+$OffsetX+$l}]
    set yE $yCsg

    set LesAmarres {}
    set Feuille 1
    if {[$t numchildren $n] > 1} {
	set Le [$t children $n]
	if {$n ne "root" && [$t get $n ordre]} {
	    set Le [lreverse $Le]
	}

	foreach f $Le {
	    set Feuille 0
	    set OldyE $yE
	    set yE [lindex [DessineArbre $AId $f $xE $yE] 1]

	    lappend LesAmarres [expr {int(($OldyE+$yE)/2)}]
	}
	set yP [expr {int(($yE+$yCsg)/2)}]
    }

    set Rotation 1
    foreach A $LesAmarres {
	if {$Rotation} {
	    MarquePourRotation $AId $n $xE $yP
	}
	set Rotation 0
	DessineLigne $AId $n $xP $yP $xE $A
    }

    if {$Feuille} {
	set name [$t get $n name]
	EcritNom $AId $name $xP $yP $xE $yCsg
	return [list $xE [expr {$yCsg+2*$OffsetY}]]
	#	return [list $xE $yCsg]
    } elseif {! $Feuille && $n ne "root"} {
	MarquePourReroot $AId $n $xP $yP $xE
	return [list $xE $yE]
    }
}


proc CompteFeuilles {{t ""} {n ""} {a ""}} {
    global CompteFeuilles
    if {$t eq ""} { set CompteFeuilles 0 ; return }
    if {$t eq "get"} {return $CompteFeuilles}

    incr CompteFeuilles [$t isleaf $n]
    return $CompteFeuilles
}


proc DessineArbreCirculaire {AId n xCsg yCsg {Dim 0}} {
    global Abr
    global CurrAng

    set t [set Abr(Arbre,$AId)]
    set Increment [set Abr($AId,Increment)]

    set l 0
    if {[$t keyexists $n length]} {
	set l [$t get $n length]
	if {$l != -1} {set l [expr {int(10*$l*$Increment)}]}
    }

    set xP $xCsg
    set yP $yCsg
    set xE [expr {$xCsg+$l}]
    set yE $yCsg

    set CurrAng [expr {$CurrAng+[set Abr($AId,deltaA)]}]

    set OlddeltaA $CurrAng

    set LesAmarres {}
    set Feuille [$t isleaf $n]
    if {! $Feuille} {
	set Le [$t children $n]
	if {$n ne "root" && [$t get $n ordre]} {set Le [lreverse $Le]}

	set LesF {}
	set LesN {}
	foreach f $Le {
	    if {[$t isleaf $f]} {lappend LesF $f} {lappend LesN $f}
	}

	set MondeltaA [expr {([$t size $n]+1)*[set Abr($AId,deltaA)]/2.+$OlddeltaA}]
	set Lcor [TourneBoite $xP $yP $xE $yE $MondeltaA]
	lassign $Lcor xE yE
	lassign $Lcor xF yF
	lappend LesAmarres $Lcor

	foreach f [concat $LesF $LesN] {
	    set Lcor [DessineArbreCirculaire $AId $f $xE $yE $Dim]
	    if {! [$t isleaf $f]} {lappend LesAmarres $Lcor}
	}

	lappend LesAmarres [list $xP $yP]
    } else {
	set Lcor [TourneBoite $xP $yP $xE $yE $CurrAng]
	lassign $Lcor xE yE
	lassign $Lcor xFyF
    }

    if {$Dim} {
	$t set $n xO $xP
	$t set $n yO $yP
	$t set $n xE $xF
	$t set $n yE $yF
	$t set $n theta $CurrAng

	lappend LesAmarres [list $xE $yE]
	foreach e $LesAmarres {
	    lassign $e x y
	    if {0 && $Feuille} {
		set wtxt [font measure TreeFont$AId [NomAffiche $AId $n]]
		set Lc [TourneBoite $x $y [expr {$x+$wtxt}] $y $CurrAng]
		lassign $Lc xtst ytst
		set xtst [expr {int($xtst)}]
		set ytst [expr {int($ytst)}]
	    } else {
		set ytst [expr {int($y)}]
		set xtst [expr {int($x)}]
	    }

	    set Abr($AId,Xmax) [Maxi [set Abr($AId,Xmax)] $xtst]
	    set Abr($AId,Ymax) [Maxi [set Abr($AId,Ymax)] $ytst]
	    set Abr($AId,Xmin) [Mini [set Abr($AId,Xmin)] $xtst]
	    set Abr($AId,Ymin) [Mini [set Abr($AId,Ymin)] $ytst]
	}

	#	set CurrAng [expr {$CurrAng+[set Abr($AId,deltaA)]}]

	return [list $xE $yE]
    }
    #    Entre

    set Rotation 1
    foreach A $LesAmarres {
	# if {$Rotation} {MarquePourRotation $AId $n $xE $yP}
	# set Rotation 0
	global colordunoeud xcol ycol TextNoeud

	if {! [info exists colordunoeud]} {
	    set TextNoeud -1
	    set colordunoeud "red"
	    set xcol $xE
	    set ycol $yE
	    $Abr($AId,PAD) create oval [expr {$xE-2}] [expr {$yE-2}] [expr {$xE+2}] [expr {$yE+2}] -fill $colordunoeud
	} elseif { $xE != $xcol || $yE != $ycol } {
	    set colordunoeud "green"
	}
	incr TextNoeud
	if {0} {
	    $Abr($AId,PAD) create text [expr {$xE-}] [expr {$yE+8}] -text $TextNoeud -font "helvitica 6"
	}
	lassign $A nxE nyE
	DessineLigneCirculaire $AId $n $xE $yE $nxE $nyE
    }

    if {$Feuille} {
	set name [$t get $n name]
	EcritNomCirculaire $AId $name $xP $yP $xE $yE $CurrAng
    } elseif {$n ne "root"} {
	MarquePourReroot $AId $n $xP $yP $xE
    }

    return [list $xE $yE]
}


proc CalculeDimensionsArbre AId {
    global Abr

    set Abr($AId,Xmax) -9999
    set Abr($AId,Ymax) -9999
    set Abr($AId,Xmin) 9999
    set Abr($AId,Ymin) 9999

    if {[set Abr($AId,TypeTree)] eq "dendrogram"} {
	DimensionsArbre $AId root 20 20
    } else {
	DessineArbreCirculaire $AId root 0 0 1
    }

    return
}


proc DimensionsArbre {AId n xCsg yCsg} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set OffsetX [set Abr($AId,OffsetX)]
    set OffsetY [expr {[set Abr($AId,OffsetY)]/2+1}]
    set Increment [set Abr($AId,Increment)]

    set l [$t get $n length]
    if {$l != -1} {
	set l [expr {int($l*$Increment+$OffsetX)}]
    }

    set xP $xCsg
    set yP [expr {$yCsg+$OffsetY}]

    set xE [expr {$xCsg+$OffsetX+$l}]
    set yE $yCsg

    set LesAmarres {}
    set Feuille 1
    if {[$t numchildren $n] > 1} {
	set Le [$t children $n]
	if {$n ne "root" && [$t get $n ordre]} {
	    set Le [lreverse $Le]
	}

	foreach f $Le {
	    set Feuille 0
	    set OldyE $yE
	    set yE [lindex [DimensionsArbre $AId $f $xE $yE] 1]

	    lappend LesAmarres [expr {int(($OldyE+$yE)/2)}]
	}
	set yP [expr {int(($yE+$yCsg)/2)}]
    }

    if {$Feuille} {
	set xtxt [font measure TreeFont$AId [NomAffiche $AId $n]]
	set xtst [expr {$xE+$xtxt}]
	set ytst [expr {$yCsg+2*$OffsetY}]
    } else {
	set xtst $xE
	set ytst $yE
    }
    if {$xtst > [set Abr($AId,Xmax)]} {set Abr($AId,Xmax) $xtst}
    if {$ytst > [set Abr($AId,Ymax)]} {set Abr($AId,Ymax) $ytst}

    if {$Feuille} {
	return [list $xE [expr {$yCsg+2*$OffsetY}]]
	#	return [list $xE $yCsg]
    } elseif {! $Feuille && $n ne "root"} {
	return [list $xE $yE]
    }
}


proc TourneBoite {x1 y1 x2 y2 deltaA} {
    # ramene a l'origine, tourne et revient
    # Angle en RADIANS !!

    set cd [expr {cos($deltaA)}]
    set sd [expr {sin($deltaA)}]

    set xp [expr {$x2-$x1}]
    set yp [expr {$y2-$y1}]
    set x  [expr {$xp*$cd-$yp*$sd}]
    set y  [expr {$xp*$sd+$yp*$cd}]
    set xf [expr {$x+$x1}]
    set yf [expr {$y+$y1}]

    return [list $xf $yf]
}


proc TourneBoiteD {x1 y1 x2 y2 deltaA} {
    # ramene a l'origine, tourne et revient
    # Angle en DEGRES !!
    #          --------

    set cd [expr {cos($deltaA*[Pi]/180.)}]
    set sd [expr {sin($deltaA*[Pi]/180.)}]

    set xp [expr {$x2-$x1}]
    set yp [expr {$y2-$y1}]
    set x  [expr {$xp*$cd-$yp*$sd}]
    set y  [expr {$xp*$sd+$yp*$cd}]
    set xf [expr {$x+$x1}]
    set yf [expr {$y+$y1}]

    return [list $xf $yf]
}


proc DimensionsArbreCirculaire {AId n xCsg yCsg} {
    global Abr
    global deltaA

    set t [set Abr(Arbre,$AId)]
    #    set OffsetX [set Abr($AId,OffsetX)]
    #    set OffsetY [set Abr($AId,OffsetY)]
    set OffsetX 10.
    set OffsetY 10.
    set Increment [set Abr($AId,Increment)]

    set l 0
    if {[$t keyexists $n length]} {
	set l [$t get $n length]
	if {$l != -1} {set l [expr {int($l*$Increment)}]}
    }

    set xP $xCsg
    set yP $yCsg
    set xE [expr {$xCsg+$OffsetX+$l}]
    set yE [expr {$yCsg+$OffsetY}]

    set OlddeltaA $deltaA
    set deltaA [expr {$deltaA+[set Abr($AId,deltaA)]}]

    set LesAmarres {}
    set Feuille 1
    if {[$t numchildren $n] > 1} {
	set Le [$t children $n]
	if {$n ne "root" && [$t get $n ordre]} {set Le [lreverse $Le]}

	#	set nLe [llength $Le]
	set nLe 0
	foreach e $Le {
	    incr nLe [$t size $e]
	}
	set MondeltaA [expr {($nLe-1)*[set Abr($AId,deltaA)]/2.+$deltaA}]
	set Lcor [TourneBoite $xP $yP $xE $yE $MondeltaA]
	lassign $Lcor xE yE
	set Feuille 0
	foreach f $Le {
	    set Lcor [DimensionsArbreCirculaire $AId $f $xE $yE]
	    lassign $Lcor nxE nyE
	    lappend LesAmarres [list $nxE $nyE]
	}
	lappend LesAmarres [list $xE $yE]
    } else {
	set Lcor [TourneBoite $xP $yP $xE $yE $deltaA]
	lassign $Lcor xE yE
	set LesAmarres [list $Lcor]
    }

    foreach e $LesAmarres {
	lassign $e x y
	set ytst $y
	if {$Feuille} {
	    set xtxt [font measure TreeFont$AId [NomAffiche $AId $n]]
	    set xtst [expr {$x+$xtxt}]
	} else {
	    set xtst $x
	}

	set Abr($AId,Xmax) [Maxi [set Abr($AId,Xmax)] $xtst]
	set Abr($AId,Ymax) [Maxi [set Abr($AId,Ymax)] $ytst]
	set Abr($AId,Xmin) [Mini [set Abr($AId,Xmin)] $xtst]
	set Abr($AId,Ymin) [Mini [set Abr($AId,Ymin)] $ytst]
    }

    return [list $xE $yE]
}


proc NouveauRoot {T N} {

    if {[$T depth $N] == 1 || [$T get [$T rootname] name] eq $N} {
	return $T
    }

    set Ld [concat [lrange [lreverse [$T ancestors $N]] 1 end] $N]
    set Fils1 [lindex $Ld 0]
    set Fils2 [lor [$T children root] $Fils1]
    set PetitFils [lindex $Ld 1]

    set NR [struct::tree]
    $NR set root name $NR
    if {$PetitFils ne ""} {
	CopieArbre2 $NR root $T $PetitFils
	$T delete $PetitFils
    }

    if {$Fils2 ne ""} {
	$T move $Fils1 end $Fils2
    }

    CopieArbre2 $NR root $T $Fils1
    $T destroy

    set R [NouveauRoot $NR $N]

    return $R
}


proc Tree2Coordonnees {AId} {
    global Abr subangleMax Xmin Xmax Ymin Ymax

    set subangleMax 999.
    TransformationPolaire $AId root [expr {[Pi]/2.}] [expr {-[Pi]/2.}] [expr {3.*[Pi]/2.}]
    set Abr($AId,subangleMax) $subangleMax

    set Xmin  999999.
    set Ymin  999999.
    set Xmax -999999.
    set Ymax -999999.
    TransformationCartesienne $AId root

    return
}


proc TransformationCartesienne {AId n} {
    global Abr Xmin Xmax Ymin Ymax

    set t [set Abr(Arbre,$AId)]
    set Le [$t children $n]
    if {$n ne "root" && [$t get $n ordre]} {
	set Le [lreverse $Le]
    }
    foreach e $Le {
	TransformationCartesienne $AId $e
    }

    set theta [$t get $n theta]
    set r     [$t get $n r]
    set scale $Abr($AId,ScaleR)

    set x [expr {$scale * $r * cos($theta)}]
    set y [expr {$scale * $r * sin($theta)}]
    if {[info exists ::iter] && $::iter < 5} {
	puts "x= $x y= $y"
	incr ::iter
    }

    $t set $n xcoord $x
    $t set $n ycoord $y
    $t set $n xdes   $x
    $t set $n ydes   $y

    set Xmin [expr {$Xmin<$x?$Xmin:$x}]
    set Ymin [expr {$Ymin<$y?$Ymin:$y}]
    set Xmax [expr {$Xmax>$x?$Xmax:$x}]
    set Ymax [expr {$Ymax>$y?$Ymax:$y}]

    return
}


proc TransformationPolaire {AId n theta lower upper} {
    global Abr subangleMax

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}

    set epsilon 0.0001
    set w       [$t get $n width]
    set pr      [$t get $n r]
    set ptheta  [$t get $n theta]

    set subangle [expr {($upper-$lower)/$w}]
    if {$subangle < $subangleMax} {
	set subangleMax $subangle
    }
    set angle $upper

    set Le [$t children $n]
    if {$n ne "root" && [$t get $n ordre]} {
	set Le [lreverse $Le]
    }
    foreach e $Le {
	set we    [$t get $e width]
	set len   [$t get $e length]
	set angle [expr {$angle - $we / 2.0 * $subangle}]
	set len   [expr {$len<0.?0.:$len}]

	set nr [expr {sqrt($len*$len + $pr*$pr + 2.*$len*$pr*cos($angle - $ptheta))}]
	$t set $e r $nr

	if {abs( $pr*cos($ptheta) + $len*cos($angle)) > $epsilon} {
	    set ntheta [expr {atan( \
		    ($pr*sin($ptheta) + $len*sin($angle))\
		    / ($pr*cos($ptheta) + $len*cos($angle)))}]
	} elseif {$pr*sin($ptheta) + $len*sin($angle) >= 0.0} {
	    set ntheta [expr {[Pi] / 2.}]
	} else {
	    set ntheta [expr {1.5 * [Pi]}]
	}
	if {$pr*cos($ptheta) + $len*cos($angle) < -$epsilon} {
	    set ntheta [expr {$ntheta + [Pi]}]
	}
	$t set $e theta $ntheta

	if {! [$t isleaf $e]} {
	    TransformationPolaire $AId $e $ntheta \
		    [expr {$angle - $we*$subangle/2.}] \
		    [expr {$angle + $we*$subangle/2.}]
	} else {
	    $t set $e oldtheta $angle
	}

	set angle [expr {$angle - $we / 2.0 * $subangle}]
    }

    return
}


proc DumpTree {AId {info "none"}} {
    global Abr

    set A [set Abr(Arbre,$AId)]
    puts ""
    puts "Dump Tree $A"
    puts "==========[string repeat = [string length $A]]"
    puts ""
    if {0} {
	foreach n [$A nodes] {
	    set Lk [lsort [$A keys $n]]
	    puts "Norud $n :"
	    foreach k $Lk {
		if {$k eq "name" || $k eq "AngAbs"} {continue}
		puts [format "\t%s %s" $k [$A get $n $k]]
	    }
	    puts ""
	}
	puts "\n"
    }

    puts "Arbre :"
    puts "======="
    DumpTreeRecur $AId root 0 $info
    puts "\n"

    return
}


proc DumpTreeRecur {AId n niv {info "non"}} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set pre [string repeat "\t" $niv]
    set res "$pre$n"
    if {$info ne "none"} {
	foreach k $info {
	    if {[$t keyexists $n $k]} {
		append res "|[$t get $n $k]"
	    }
	}
    }
    puts "$res"
    if {[$t isleaf $n]} {return}

    incr niv
    foreach e [$t children $n] {
	DumpTreeRecur $AId $e $niv $info
    }

    return
}


proc DataDeLArbre {AId} {
    global Abr Rap

    set A [set Abr(Arbre,$AId)]

    # Analyse distances
    set Lf [$A leaves]
    set NbrF [llength $Lf]
    set max -888.
    foreach l $Lf {
	set sum 0.
	set mdepth 0
	set f $l
	while {$f > 0} {
	    if {[$A keyexists $f length]} {
		set t [$A get $f length]
		if {$t > -1.} {set sum [expr {$sum + $t}]}
	    }
	    set f [$A parent $f]
	}
	if {$sum > $max} {set max $sum}
	if {[$A depth $l] > $mdepth} {set mdepth [$A depth $l]}
    }

    set rmin 999.
    set rmax -999.
    foreach d [$A nodes] {
	if {! [$A isleaf $d]} {continue}
	set r [$A get $d r]
	if {$r < $rmin && $r > 0.} {set rmin $r}
	if {$r > $rmax && $r > 0.} {set rmax $r}
    }

    # length
    set lmin 999. ; set lmax -999. ; set nneg 0
    foreach d [$A nodes] {
	set l [$A get $d length]
	if {$l < $lmin} {set lmin $l}
	if {$l > $lmax} {set lmax $l}
	if {$l < 0.} {incr nneg}
    }
    set Rap(lmin) $lmin
    set Rap(lmax) $lmax
    set Rap(nneg) $nneg

    set Abr($AId,Dmax)    $max
    set Abr($AId,Depth)   $mdepth
    set Abr($AId,NLeaves) $NbrF
    set Abr($AId,rmin)    $rmin
    set Abr($AId,rmax)    $rmax
    set Abr($AId,deltaA)  [expr {(360./([$A size]+1))*acos(-1.)/180.}]

    if {0} {
	puts "Abr($AId,Dmax)    $max"
	puts "Abr($AId,Depth)   $mdepth"
	puts "Abr($AId,NLeaves) $NbrF"
	puts "Abr($AId,rmin)    $rmin"
	puts "Abr($AId,deltaA)  [expr {(360./([$A size]+1))*acos(-1.)/180.}]"
    }

    return
}


proc InitialiseUnArbre {tree {ResetAId ""}} {
    global Abr LNOrdali subangleMax Xmin Xmax Ymin Ymax Defauts

    set AId [DecortiqueUnArbre $tree $ResetAId]

    set Abr($AId,TypeTree) [set Defauts(TypeTree)]
    set Abr($AId,TAff) "Accession"

    set A [set Abr(Arbre,$AId)]

    # Init fonte et parametres par defauts
    if {"TreeFont$AId" ni [font names]} {
	font create "TreeFontBoot$AId" -family Helvetica -size [set Defauts(FontSizeTreeBoot)] -weight [set Defauts(FontWghtTree)]
	font create "TreeFont$AId" -family Helvetica -size [set Defauts(FontSizeTree)] -weight [set Defauts(FontWghtTree)]
    }
    set Abr($AId,PADWdt)   [set Defauts(CanvasWTree)]
    set Abr($AId,PADHgt)   [set Defauts(CanvasHTree)]
    set Abr($AId,FWidth)   [set Defauts(FWidthTree)]
    set Abr($AId,FHeight)  [set Defauts(FHeightTree)]
    set Abr($AId,FontSize) [set Defauts(FontSizeTree)]
    set Abr($AId,FontWght) [set Defauts(FontWghtTree)]
    set Abr($AId,NfoisX)   1.
    set Abr($AId,NfoisY)   1.2
    set Abr($AId,ScaleR)   1.0
    set Abr($AId,incrScaleR) 0.5
    set Abr($AId,firstTimeZoom) 1
    set Abr($AId,Rotate)   0.
    set Abr($AId,OffsetX)  5
    set Abr($AId,OffsetY)  [expr {int([set Abr($AId,NfoisY)]*[lindex [font metrics "TreeFont$AId"] 5])}]

    set Increment 50.
    set Abr($AId,Increment) $Increment

    if {[TypeAli] in [list "XML" "ORD"]} {
	set Abr(TypeAff) [list "Seq.Name" "Accession" "BankId" "Organism" "Description" "Accession + BankId" "Accession + Organism" "Accession + Description" "Organism + Description" "Seq.Name + Description" "Seq.Name + Organism"]
    } else {
	set Abr(TypeAff) "Accession"
    }

    set Abr($AId,Tag) 0
    set Abr($AId,BootShow) 0
    set Abr($AId,LSeq) [$A leaves]
    set Abr($AId,LSeqOri) $Abr($AId,LSeq)
    if {[TypeAli] ne "pasdali"} {
	if {[llength [SequencesSelectionnees]] == 1} {
	    set Abr($AId,LeafSel) [SequencesSelectionnees]
	} else {
	    set Abr($AId,LeafSel) [lindex [set Abr($AId,LSeq)] 0]
	}
    } else {
	set Abr($AId,LeafSel) {}
    }

    # Initialisation Dessin
    Tree2Coordonnees $AId
    DataDeLArbre $AId
    AjusteCoordonneesInit $AId

    return $AId
}


proc EcritUnNoeud {AId n} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    append Abr($AId,OutPH) "("
    
    set ic 1
    set nc [llength [$t children $n]]
    foreach c [$t children $n] {
	if {[$t isleaf $c]} {
	    append Abr($AId,OutPH) "[$t get $c name]:[$t get $c length]"
	} else {
	    EcritUnNoeud $AId $c
	}
	if {$ic < $nc} {
	    append Abr($AId,OutPH) ","
	}
	incr ic
    }
    append Abr($AId,OutPH) ")"
    
    if {$n ne "root"} {
	if {$Abr($AId,BootDone)} {
	    append Abr($AId,OutPH) "[$t get $n nboot]"
	}
	append Abr($AId,OutPH) ":[$t get $n length]"
    }
    
    return
}
    

proc EcritUnArbre {AId {fout ""}} {
    global Abr

    if {$fout eq ""} {
	set fout [DemandeEtSauveFichier ph 1]
	if {$fout eq ""} {return}
    }

    set Abr($AId,OutPH) ""
    EcritUnNoeud $AId root
    append Abr($AId,OutPH) ";"
    
    set o [CheckOpen $fout]
    if {$o eq ""} {
	return
    }
    puts $o $Abr($AId,OutPH)
    close $o

    puts "\n$Abr($AId,OutPH)"

    return
}


proc DecortiqueUnArbre {TextePH {ResetAId ""}} {
    global Abr

    if {$ResetAId eq ""} {
	if {! [info exists Abr(Liste)]} {
	    set AId 1
	} else {
	    set AId [expr {[lindex [set Abr(Liste)] end] + 1}]
	}
	lappend Abr(Liste) $AId
    } else {
	# ResetAId not empty. Re-use AId to create tree
	set AId $ResetAId
    }

    # Newick -> struct::tree serialization, with the attributes
    # width and Lleaves already computed (NewickVersSerialisation).
    # Replaces the eval of the text turned into nested [CreeArbre]
    # calls and the loop over the ancestors of each leaf : same
    # tree, 6 to 9 times faster.
    set ArbreOri [NewickVersSerialisation $TextePH]

    set TArbre "Tree-Root$AId"
    # recherche ciblee : [info commands] liste toutes les
    # commandes (~19000 dans Ordalie, 23 ms par appel, soit
    # l'essentiel du temps de cette procedure au bootstrap)
    if {[info commands ::$TArbre] ne ""} {
	::$TArbre destroy
    }

    struct::tree $TArbre
    foreach {k i p} $ArbreOri {
	lappend Lk $k
    }
    
    $TArbre deserialize $ArbreOri

    set Arbre "ArbreNo$AId"

    set Abr($AId,TextePH) $TextePH
    set Abr(Arbre,$AId) $TArbre
    set Abr(ArbreSer,$AId) $ArbreOri
    lappend Abr(ListeArbres) $TArbre

    # largeur (width) et Lleaves de chaque noeud : deja calcules
    # par NewickVersSerialisation
    
    return $AId
}


proc NewickVersSerialisation {TextePH} {
    # Reads a Newick/phylip tree (as returned by tclfastme) and
    # returns the struct::tree serialization, identical to the one
    # built before by eval-ing the text turned into nested
    # [CreeArbre ...] calls (CreeArbre/CreeId/ReunitBranches/
    # CopieArbre), but without eval and without copying lists :
    # - one regexp splits the text into tokens,
    # - a stack builds a table of nodes,
    # - one preorder walk writes the serialization.
    # Same conventions as the old code :
    # - internal nodes are "Tree-<i>", i = ::NoDeLArbre incremented
    #   when a subtree is completed (post-order, left to right),
    #   attribute name = Noeud-<child1>-<child2>, length 0.0 ;
    # - a node with k > 2 children becomes nested binary nodes :
    #   (A,B,C) -> Tree-2 {C Tree-1 {A B}} ;
    # - a subtree takes the length written after its ')' ;
    # - labels after ')' (bootstrap values, "I12") are ignored ;
    # - the top node is renamed "root".

    set Ltok [regexp -all -inline {[(),:;]|[^(),:;\s]+} $TextePH]
    set ntok [llength $Ltok]
    # no branch length at all (topology only) : every branch is 1,
    # else a missing length is 0. An empty length broke the drawing.
    set SansLg [expr {":" ni $Ltok}]
    set LgDef [expr {$SansLg ? 1.0 : 0.0}]

    # node table : Nom($id) name attribute, Lg($id) length,
    # Fils($id) children (2 for internal nodes)
    # stack : one list of children ids per open parenthesis
    set pile {}
    set courant {}
    set dernier ""
    for {set i 0} {$i < $ntok} {incr i} {
	set tk [lindex $Ltok $i]
	switch -- $tk {
	    "(" {
		lappend pile $courant
		set courant {}
	    }
	    "," {
	    }
	    ":" {
		# branch length of the last child read
		incr i
		set Lg($dernier) [lindex $Ltok $i]
	    }
	    ")" {
		# close the node : nested binary nodes
		lassign $courant g d
		set Id [ReunitBranchesTable $g $d Nom Lg Fils]
		foreach s [lrange $courant 2 end] {
		    set Id [ReunitBranchesTable $s $Id Nom Lg Fils]
		}
		set courant [lindex $pile end]
		set pile [lrange $pile 0 end-1]
		lappend courant $Id
		set dernier $Id
		# a clade of the file (not one of the nested binary nodes)
		if {$SansLg} {
		    set Lg($Id) $LgDef
		}
		# skip a label (bootstrap value) after ')'
		set suiv [lindex $Ltok $i+1]
		if {$suiv ni {: , ) ; ""} && $suiv ne "("} {
		    incr i
		}
	    }
	    ";" {
		break
	    }
	    default {
		# leaf
		set Nom($tk) $tk
		set Lg($tk) $LgDef
		set Fils($tk) {}
		lappend courant $tk
		set dernier $tk
	    }
	}
    }
    set racine [lindex $courant 0]
    if {$SansLg} {
	set Lg($racine) 0.0
    }

    # preorder walk : order of the nodes and parent index
    set Lordre {}
    set aFaire [list [list $racine {}]]
    set pos 0
    while {[llength $aFaire]} {
	lassign [lindex $aFaire end] n ip
	set aFaire [lrange $aFaire 0 end-1]
	lappend Lordre $n $ip
	# children pushed in reverse order : the first one is
	# written first
	foreach f [lreverse $Fils($n)] {
	    lappend aFaire [list $f $pos]
	}
	incr pos 3
    }

    # attributes width (number of leaves below, 1 for a leaf) and
    # Lleaves (leaves below, {} for a leaf), computed bottom-up
    # (reverse preorder : children before their parent). Before,
    # a loop over the ancestors of each leaf did it with
    # struct::tree calls (most of the time of DecortiqueUnArbre).
    foreach {ip n} [lreverse $Lordre] {
	if {$Fils($n) eq {}} {
	    set Larg($n) 1
	    set Lf($n) {}
	    set Sous($n) [list $n]
	} else {
	    set Sous($n) {}
	    foreach f $Fils($n) {
		lappend Sous($n) {*}$Sous($f)
	    }
	    set Larg($n) [llength $Sous($n)]
	    set Lf($n) $Sous($n)
	}
    }

    # serialization {node parentIndex attributes}
    set Ser {}
    foreach {n ip} $Lordre {
	lappend Ser $n $ip [list name $Nom($n) length $Lg($n) AngAbs 0. ordre 0 theta 0. oldtheta 0. r 0. width $Larg($n) Lleaves $Lf($n)]
    }
    lset Ser 0 root

    return $Ser
}


proc ReunitBranchesTable {a b aNom aLg aFils} {
    # as ReunitBranches, on the node table
    upvar $aNom Nom $aLg Lg $aFils Fils

    set Id "Tree-[incr ::NoDeLArbre]"
    set Nom($Id) "Noeud-$a-$b"
    set Lg($Id) 0.0
    set Fils($Id) [list $a $b]

    return $Id
}


proc ConfigureRoot {id name} {
    set TId [struct::tree $id]

    set L [list root {} [list name $name length 0. AngAbs 0. ordre 0 theta 0. oldtheta 0. r 0. width 0]]
    $TId deserialize $L

    return "$TId"
}


proc RetraceTout {AId n {init 0}} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set PAD [set Abr($AId,PAD)]

    set x [$t get $n xO]
    set y [$t get $n yO]
    set x [SurGrille $x]
    set y [SurGrille $y]
    $PAD create oval [expr {$x-5}] [expr {$y-5}] [expr {$x+5}] [expr {$y+5}] \
	    -fill red -outline red

    if {[$t isleaf $n]} {
	set xf [$t get $n xE]
	set yf [$t get $n yE]
	set xf [SurGrille $xf]
	set yf [SurGrille $yf]
	DessineLigneCirculaire $AId $n $x $y $xf $yf

	set id [$PAD create oval [expr {$xf-5}] [expr {$yf-5}] [expr {$xf+5}] [expr {$yf+5}] \
		-fill red -outline red]
	$PAD raise $id
	$PAD create text $xf $yf -anchor w -text $n
    } else {
	set Le [$t children $n]
	foreach e $Le {
	    set xe [$t get $e xO]
	    set ye [$t get $e yO]
	    set xf [$t get $e xE]
	    set yf [$t get $e yE]
	    $PAD create text $xf $yf -anchor w -text $e
	    DessineLigneCirculaire $AId $n $x $y $xe $ye

	    RetraceTout $AId $e $init
	}
    }

    return
}


proc RetraceToutCart {AId n} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set PAD [set Abr($AId,PAD)]

    set x [SurGrille [$t get $n xdes]]
    set y [SurGrille [$t get $n ydes]]

    if {[$t isleaf $n]} {
	EcritNomCart $AId $n $x $y [$t get $n oldtheta]
	return
    }

    MarquePourRotation $AId $n $x $y

    foreach e [$t children $n] {
	set xe [SurGrille [$t get $e xdes]]
	set ye [SurGrille [$t get $e ydes]]
	$PAD create line $x $y $xe $ye \
		-width 1 \
		-tags [list "DItem" "line-$n"]

	RetraceToutCart $AId $e
    }

    return
}


proc ScaleArbre2 {AId args} {
    global Abr

    if {$args != ""} {
	lassign [lindex $args 0] xc yc
    } else {
	set xc ""
    }	    

    set t   [set Abr(Arbre,$AId)]
    set sca [set Abr($AId,ScaleR)]
    puts "ScaleA $sca"
    set PAD [set Abr($AId,PAD)]

    if {$xc eq ""} {
	set xc 0. ; set yc 0.
	set Le [$t nodes]
	foreach e $Le {
	    #set xc [expr {$xc + [$t get $e xcoord]}]
	    #set yc [expr {$yc + [$t get $e ycoord]}]
	    set xc [expr {$xc + [$t get $e xdes]}]
	    set yc [expr {$yc + [$t get $e ydes]}]
	}
	puts [format "%d | xc %10.6f yc %10.6f" [llength $Le] $xc $yc]
	set xc [expr {round($xc / [llength $Le])}]
	set yc [expr {round($yc / [llength $Le])}]
    }

    $PAD scale all $xc $yc $sca $sca

    return
}


proc ScaleArbre {AId args} {
    global Abr

    if {$args != ""} {
	lassign [lindex $args 0] xc yc
    } else {
	set xc ""
    }	    

    set t   [set Abr(Arbre,$AId)]
    set sca [set Abr($AId,ScaleR)]
    puts "ScaleA $sca"
    set PAD [set Abr($AId,PAD)]

    if {$xc eq ""} {
	set Le [$t children -all root]
	set xc 0. ; set yc 0.
	foreach e $Le {
	    #set xc [expr {$xc + [$t get $e xcoord]}]
	    #set yc [expr {$yc + [$t get $e ycoord]}]
	    set xc [expr {$xc + [$t get $e xdes]}]
	    set yc [expr {$yc + [$t get $e ydes]}]
	}
	set xc [expr {$xc / [llength $Le]}]
	set yc [expr {$yc / [llength $Le]}]
    }

    #$PAD scale all $xc $yc $sca $sca
    #return


    foreach e [$t nodes] {
	set x [$t get $e xdes]
	set y [$t get $e ydes]
	set x [expr {$sca * ($x-$xc) + $xc}]
	set y [expr {$sca * ($y-$yc) + $yc}]
	$t set $e xdes $x
	$t set $e ydes $y
    }
    
    return
}


proc TourneArbreEntier {AId rot} {
    global Abr

    set t [set Abr(Arbre,$AId)]

    foreach e [$t nodes] {
	if {[$t keyexists $e theta]} {
	    set th [$t get $e theta]
	    $t set $e theta [expr {$th+$rot}]
	}
	if {[$t keyexists $e oldtheta]} {
	    set th [$t get $e oldtheta]
	    $t set $e oldtheta [expr {$th+$rot}]
	}
    }

    # TransformationCartesienne $AId root
    # AjusteCoordonneesInit $AId
    # ReAjusteCoordonnees $AId

    return
}


proc NewMaxLR {AId n} {
    global Abr ALMax ARmax ALMin ARMin

    set t [set Abr(Arbre,$AId)]

    if {$n eq "root"} {	return 1}

    set epsilon 0.0001
    set xn [$t get $n xcoord]
    set yn [$t get $n ycoord]
    set p [$t parent $n]
    set xp [$t get $p xcoord]
    set yp [$t get $p ycoord]
    if {$xn == $xp && $yn == $yp} {
	lassign [$t children $p] e1 e2
	if {$n eq $e1} {set p $e2} {set p $e1}
	set xp [$t get $p xcoord]
	set yp [$t get $p ycoord]
    }

    if {[$t isleaf $n]} {
	set ang [Coords2Angle [expr {$xn-$xp}] [expr {$yn-$yp}]]
	$t set $n LeftA   $ang
	$t set $n RightA  $ang
	$t set $n NdRight $n
	$t set $n NdLeft  $n
	puts [format "%s | Ang %5.3f" $n $ang]
	return 1
    }

    set fx [expr {$xp - $xn}]
    set fy [expr {$yp - $yn}]
    set Nf [expr {sqrt($fx*$fx+$fy*$fy)}]
    if {$Nf != 0.} {
	set fx [expr {$fx/$Nf}]
	set fy [expr {$fy/$Nf}]
    }

    set lx $fx
    set ly $fy
    set rx $fx
    set ry $fy
    set ALMax -999.
    set ARmax -999.
    set ALMin 999.
    set ARMin 999.

    set Llrxy [PrdtVec $AId $n $xn $yn $fx $fy $lx $ly $rx $ry]
    lassign $Llrxy lxf lyf rxf ryf Nl Nr Nlm Nrm
    if {$lxf == $lx && $lyf == $ly} {return 0}
    if {$rxf == $rx && $ryf == $ry} {return 0}

    if {$Nl eq ""} {set Nl $Nrm}
    if {$Nr eq ""} {set Nr $Nlm}
    set xl [$t get $Nl xcoord]
    set yl [$t get $Nl ycoord]
    set lang [Coords2Angle [expr {$xl-$xn}] [expr {$yl-$yn}]]
    set xr [$t get $Nr xcoord]
    set yr [$t get $Nr ycoord]
    set rang [Coords2Angle [expr {$xr-$xn}] [expr {$yr-$yn}]]

    while {$lang - $rang > [2Pi]} {set lang [expr {$lang - [2Pi]}]}
    while {$rang > $lang} {set lang [expr {$lang + [2Pi]}]}

    $t set $n LeftA   $lang
    $t set $n NdLeft  $Nl
    $t set $n RightA  $rang
    $t set $n NdRight $Nr

    puts "----- + L / + R -----"
    puts "$n"
    puts [format "L %6.3f R %6.3f" $lang $rang]
    puts [format "NL %s NR %s LR %5.3f" $Nl $Nr [expr {$lang-$rang}]]

    return 1
}



proc PrdtVec {AId n xn yn fx fy lx ly rx ry {Nl ""} {Nr ""} {Nlm ""} {Nrm ""}} {
    global Abr ALMax ARmax ARMin ALMin

    set t [set Abr(Arbre,$AId)]

    set x [$t get $n xcoord]
    set y [$t get $n ycoord]

    set dx [expr {$x-$xn}]
    set dy [expr {$y-$yn}]
    set Nd [expr {sqrt($dx*$dx+$dy*$dy)}]
    if {$Nd != 0.} {
	set dx [expr {$dx/$Nd}]
	set dy [expr {$dy/$Nd}]
    }

    set PV [expr {$dy*$fx-$dx*$fy}]
    set PS [expr {$dx*$fx+$dy*$fy}]
    if {$PS != 0.} {set Ang [expr {atan(abs($PV)/$PS)}]} {set Ang 99.}
    if {$Ang < 0.} {set Ang [expr {$Ang+[Pi]}]}

    if {$PV > 0.} {
	if {$Ang < $ARMax} {
	    set ARMax $Ang
	    set Nr $n
	    if {$Nd != 0.} {
		set rx [expr {$dx*$Nd}]
		set ry [expr {$dy*$Nd}]
	    } else {
		set rx $dx
		set ry $dy
	    }
	}
	if {$Ang > $ARmin} {
	    set ARmin $Ang
	    set Nrm $n
	}
    }
    if {$PV < 0.} {
	if {$Ang < $ALMin} {
	    set ALMin $Ang
	    set Nl $n
	    if {$Nd != 0.} {
		set lx [expr {$dx*$Nd}]
		set ly [expr {$dy*$Nd}]
	    } else {
		set lx $dx
		set ly $dy
	    }
	}
	if {$Ang > $ALMax} {
	    set ALMax $Ang
	    set Nlm $n
	}
    }

    if {0} {
	puts [format "Ang : %6.3f PV %6.3f %s" $Ang $PV $n]
	puts [format "  %6.3f %6.3f %6.3f %6.3f" $x $y $xn $yn]
	puts [format "  %6.3f %6.3f %6.3f %6.3f" $dx $dy $fx $fy]
	puts [format "  AL Min %6.3f AR Min %6.3f" $ALMin $ARMax]
	puts "  NdL $Nl NdR $Nr"
    }

    foreach e [$t children $n] {
	set Llrxy [PrdtVec $AId $e $xn $yn $fx $fy $lx $ly $rx $ry $Nl $Nr $Nlm $Nrm]
	lassign $Llrxy lx ly rx ry Nl Nr Nlm Nrm 
    }

    return [list $lx $ly $rx $ry $Nl $Nr $Nlm $Nrm]
}



proc AngleLRAncetres {AId n} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}
    if {$n eq "root"} {return}

    set x [$t get $n xcoord]
    set y [$t get $n ycoord]
    set p [$t parent $n]
    lassign [$t children $p] e1 e2
    set xp [$t get $p xcoord]
    set yp [$t get $p ycoord]
    if {$x == $xp && $y == $yp} {
	if {$n eq $e1} {set p $e2} {set p $e1}
    }

    ::struct::tree tmpT
    tmpT deserialize [$t serialize]
    tmpT delete $n

    # ATTENTION ! Ordre inverse ! On regarde VERS la racine !!
    set Ln [tmpT nodes]
    if {[llength $Ln] > 2} {
	lassign [NoeudLRDe $AId $n $p $Ln 1] Nr Nl
    } else {
	lassign $Ln n1 n2
	if {$n1 eq "root"} {set Ln $n2} {set Ln $n1}
	set Nr $Ln
	set Nl $Ln
    }

    set xaR [$t get $Nr xcoord]
    set yaR [$t get $Nr ycoord]
    set Ang [Coords2Angle [expr {$xaR-$x}] [expr {$yaR-$y}]]
    set AR $Ang

    set xaL [$t get $Nl xcoord]
    set yaL [$t get $Nl ycoord]
    set Ang [Coords2Angle [expr {$xaL-$x}] [expr {$yaL-$y}]]
    set AL $Ang

    puts "----- Ancetre Gauche/Droite ----------------"
    puts [format "AL %6.3f AR %6.3f" $AL $AR]
    puts "NdL $Nl NdR $Nr"

    tmpT destroy

    $t set $n AncesR $AR
    $t set $n AncesL $AL
    $t set $n NdAncesL $Nl
    $t set $n NdAncesR $Nr

    return
}



proc PrdtVec2 {AId n xn yn fx fy} {
    global Abr ARMin ALMin

    set Nl ""
    set Nr ""

    set t [set Abr(Arbre,$AId)]
    set x  [$t get $n xcoord]
    set y  [$t get $n ycoord]
    set dx [expr {$x-$xn}]
    set dy [expr {$y-$yn}]
    set Nd [expr {sqrt($dx*$dx+$dy*$dy)}]
    if {$Nd != 0.} {
	set dx [expr {$dx/$Nd}]
	set dy [expr {$dy/$Nd}]
    }

    set PV [expr {$dy*$fx-$dx*$fy}]
    set PS [expr {$dx*$fx+$dy*$fy}]
    if {$PS != 0.} {set Ang [expr {atan(abs($PV)/$PS)}]} {set Ang 99.}
    if {$Ang < 0.} {set Ang [expr {$Ang+[Pi]}]}

    if {$PV > 0.} {
	if {$Ang < $ARMin} {
	    set ARMin $Ang
	    set Nr $n
	}
    } else {
	if {$Ang < $ALMin} {
	    set ALMin $Ang
	    set Nl $n
	}
    }

    return [list $Nl $Nr]
}



proc PrdtVec3 {AId n xn yn fx fy} {
    global Abr ARMin ALMin

    set Nl ""
    set Nr ""

    set t [set Abr(Arbre,$AId)]
    set x  [$t get $n xcoord]
    set y  [$t get $n ycoord]
    set dx [expr {$x-$xn}]
    set dy [expr {$y-$yn}]
    set Nd [expr {sqrt($dx*$dx+$dy*$dy)}]
    if {$Nd != 0.} {
	set dx [expr {$dx/$Nd}]
	set dy [expr {$dy/$Nd}]
    }

    set PV [expr {$dy*$fx-$dx*$fy}]
    set PS [expr {$dx*$fx+$dy*$fy}]
    if {$PS != 0.} {set Ang [expr {atan(abs($PV)/$PS)}]} {set Ang 99.}
    if {$Ang < 0.} {set Ang [expr {$Ang+[Pi]}]}

    if {$PV > 0.} {
	if {$Ang > $ARMin} {
	    set ARMin $Ang
	    set Nr $n
	}
    } else {
	if {$Ang > $ALMin} {
	    set ALMin $Ang
	    set Nl $n
	}
    }

    return [list $Nl $Nr]
}



proc NoeudLRDe {AId n p Ln {Sens 0}} {
    global Abr ALMin ARMin

    set t [set Abr(Arbre,$AId)]
    set xn [$t get $n xcoord]
    set yn [$t get $n ycoord]
    set xp [$t get $p xcoord]
    set yp [$t get $p ycoord]

    set fx [expr {$xp - $xn}]
    set fy [expr {$yp - $yn}]
    set Nf [expr {sqrt($fx*$fx+$fy*$fy)}]
    if {$Nf != 0.} {
	set fx [expr {$fx/$Nf}]
	set fy [expr {$fy/$Nf}]
    }

    set Nl ""
    set Nr ""
    if {$Sens} {
	set ALMin -999.
	set ARMin -999.
    } else {
	set ALMin 999.
	set ARMin 999.
    }

    foreach d $Ln {
	if {$d eq "root"} {continue}
	if {! [$t isleaf $d]} {continue}
	if {$Sens} {
	    set Llrxy [PrdtVec3 $AId $d $xn $yn $fx $fy]
	} else {
	    set Llrxy [PrdtVec2 $AId $d $xn $yn $fx $fy]
	}
	lassign $Llrxt Nlt Nrt

	if {$Nlt ne "" && $Nlt ne $Nl} {set Nl $Nlt}
	if {$Nrt ne "" && $Nrt ne $Nr} {set Nr $Nrt}
    }

    return [list $Nl $Nr]
}



proc AjusteAnglesRoot {AId n} {
    global Abr sum

    set t [set Abr(Arbre,$AId)]
    set xp [$t get $n xcoord]
    set yp [$t get $n ycoord]
    lassign [$t children $n] e1 e2

    set x [$t get $e1 xcoord]
    set y [$t get $e1 ycoord]
    if {$x == $xp && $y == $yp} {set p $e2} {set p $e1}

    if {! [$t isleaf $e1]} {
	set Ln [concat $e1 [$t descendants $e1]]
	lassign [NoeudLRDe $AId $e1 $p $Ln] NL1 NR1 
    } else {
	set NL1 $e1
	set NR1 $e1
    }

    if {! [$t isleaf $e2]} {
	set Ln [concat $e2 [$t descendants $e2]]
	lassign [NoeudLRDe $AId $e2 $p $Ln] NL2 NR2
    } else {
	set NR2 $e2
	set NL2 $e2
    }
    lassign [OverlapBranch $AId $NL1 $NR1 $NL2 $NR2] o1 o2 
    #    puts "OverlapBranch $o1 $o2"

    set R1 [$t get $e1 RightA]
    set L1 [$t get $e1 LeftA]
    set R2 [$t get $e2 RightA]
    set L2 [$t get $e2 LeftA]
    foreach v {R1 L1 R2 L2} {
	while {[set $v] > [2Pi]} {set $v [expr {[set $v]-[2Pi]}]}
	set $v [expr {[set $v]>[Pi]?[set $v]-[2Pi]:[set $v]}]
    }

    set L1R2 [expr {abs($L1-$R2)}]
    if {$L1R2 > [Pi]} {set L1R2 [expr {[2Pi]-$L1R2}]}

    set L2R1 [expr {abs($L2-$R1)}]
    if {$L2R1 > [Pi]} {set L2R1 [expr {[2Pi]-$L2R1}]}

    set AngVide [expr {$L1R2 + $L2R1}]
    set angeq [expr {$AngVide/2.}]
    set DecTot [expr {abs($angeq-$L1R2) + abs($angeq-$L2R1)}]
    set sum [expr {$sum + $DecTot}]

    if {[$t size $e1] < [$t size $e2]} {
	set AngT $L1R2
	set NdT $e1
    } else {
	set AngT $L2R1
	set NdT $e2
    }
    set tilt1 [expr {$angeq-$AngT}]
    TiltArbre $AId root $NdT $tilt1

    puts "----- ROOT Ajsutement --------"
    puts "$n | E1 $e1 | E2 $e2"
    puts [format "L1R2 %6.3f L1 %6.3f L2 %6.3f" $L1R2 $L1 $R2]
    puts [format "L2R1 %6.3f L2 %6.3f R1 %6.3f" $L2R1 $L2 $R1]
    puts [format "Ang Egaux : %6.3f Decal %6.3f" $angeq $DecTot]
    puts [format "tilt LRRL : %6.3f Nd tilt %s" $tilt1 $NdT]
    puts [format "nAngT %6.3f" [expr {$AngT+$tilt1}]]

    return $sum
}



proc AjusteAngles2 {AId n} {
    global Abr sum PVmL PVmR

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return $sum}
    if {$n eq "root"} {
	AjusteAnglesRoot $AId root
	return $sum
    }

    set xn [$t get $n xcoord]
    set yn [$t get $n ycoord]

    set p [$t parent $n]
    set xp [$t get $p xcoord]
    set yp [$t get $p ycoord]
    if {$xn == $xp && $yn == $yp} {
	lassign [$t children $p] e1 e2
	if {$n eq $e1} {set p $e2} {set p $e1}
	set xp [$t get $p xcoord]
	set yp [$t get $p ycoord]
    }

    set NdMaxRight [$t get $n NdRight]
    set NdMaxLeft  [$t get $n NdLeft]
    set NdAncesL   [$t get $n NdAncesL]
    set NdAncesR   [$t get $n NdAncesR]

    lassign [$t children $n] e1 e2
    if {[lsearch [concat $e1 [$t descendants $e1]] $NdMaxRight] != -1} {
	set NdR $e1
	set NdL $e2
    } else {
	set NdR $e2
	set NdL $e1
    }
    puts "NdR $NdR"
    puts "NdL $NdL"
    set NRR [$t get $NdR NdRight]
    set NRL [$t get $NdR NdLeft]
    set NLR [$t get $NdL NdRight]
    set NLL [$t get $NdL NdLeft]
    puts "NRR $NRR NRL $NRL"
    puts "NLR $NLR NLL $NLL"

    if {0} {
	set Ln [concat $NdR [$t descendants $NdR]]
	if {[llength $Ln] == 1} {
	    set NRL $Ln
	    set NRR $Ln
	} else {
	    lassign [NoeudLRDe $AId $n $p $Ln] NRL NRR
	}
    }

    set x1 [$t get $NRL xcoord]
    set y1 [$t get $NRL ycoord]
    set RL [Coords2Angle [expr {$x1-$xn}] [expr {$y1-$yn}]]

    if {0} {
	set Ln [concat $NdL [$t descendants $NdL]]
	if {[llength $Ln] == 1} {
	    set NLL $Ln
	    set NLR $Ln
	} else {
	    lassign [NoeudLRDe $AId $n $p $Ln] NLL NLR
	}
    }
    set x2 [$t get $NLR xcoord]
    set y2 [$t get $NLR ycoord]
    set LR [Coords2Angle [expr {$x2-$xn}] [expr {$y2-$yn}]]

    set LL [$t get $n LeftA]
    while {$LL > [2Pi]} {set LL [expr {$LL - [2Pi]}]}
    set RR [$t get $n RightA]
    while {$RR > [2Pi]} {set RR [expr {$RR - [2Pi]}]}

    set AL [$t get $n AncesL]
    set AR [$t get $n AncesR]

    foreach v {RR RL LR LL AL AR} {
	set $v [expr {[set $v]>[Pi]?[set $v]-[2Pi]:[set $v]}]
    }

    set RRAL [expr {$RR-$AL}]
    if {$RRAL < 0.} {set RRAL [expr {[2Pi]+$RRAL}]}
    set RRAL [expr {$RRAL>[Pi]?[2Pi]-$RRAL:$RRAL}]

    set LRRL [expr {$LR-$RL}]
    if {$LRRL < 0.} {set LRRL [expr {[2Pi]+$LRRL}]}
    set LRRL [expr {$LRRL>[Pi]?[2Pi]-$LRRL:$LRRL}]

    set ARLL [expr {$AR-$LL}]
    if {$ARLL < 0.} {set ARLL [expr {[2Pi]+$ARLL}]}
    set ARLL [expr {$ARLL>[Pi]?[2Pi]-$ARLL:$ARLL}]

    set AngVide [expr {$LRRL + $ARLL + $RRAL}]
    set angeq [expr {$AngVide/3.}]
    set DecTot [expr {abs($angeq-$RRAL) + abs($angeq-$LRRL) + abs($angeq-$ARLL)}]
    set sum [expr {$sum + $DecTot}]

    set tilt1 [expr {$angeq-$RRAL}]
    TiltArbre $AId $n $NdR $tilt1

    if {$tilt1 < 0.} {
	set LRRL [expr {$LRRL+abs($tilt1)}]
    } else {
	set LRRL [expr {$LRRL-abs($tilt1)}]
    }
    set tilt2 [expr {$angeq-$LRRL}]
    TiltArbre $AId $n $NdL $tilt2

    puts "----- Ajsutement --------"
    puts "$n | R $NdR | L $NdL"
    puts [format "Nd RR %6.3f %s Nd RL %6.3f %s" $RR $NRR $RL $NRL]
    puts [format "Nd LR %6.3f %s Nd LL %6.3f %s" $LR $NLR $LL $NLL]
    puts [format "Nd AL %6.3f %s Nd AR %6.3f %s" $AL $NdAncesL $AR $NdAncesR]
    puts [format "RRAL %6.3f RR %6.3f AL %6.3f" $RRAL $RR $AL]
    puts [format "LRRL %6.3f LR %6.3f RL %6.3f" $LRRL $LR $RL]
    puts [format "ARLL %6.3f AR %6.3f LL %6.3f" $ARLL $AR $LL]
    puts [format "Ang Egaux : %6.3f Decal %6.3f" $angeq $DecTot]
    puts [format "tilt RRAL : %6.3f | LRRL %6.3f" $tilt1 $tilt2]
    puts [format "nRRAL %6.3f nLRRL %6.3f" [expr {$RRAL+$tilt1}] [expr {$LRRL+$tilt2}]]

    return $sum
}



proc TiltArbre {AId ref n ang} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set x [$t get $ref xcoord]
    set y [$t get $ref ycoord]
    set Ld [concat $ref $n [$t descendants $n]]
    foreach d $Ld {
	set xd [$t get $d xcoord]
	set yd [$t get $d ycoord]
	set Lxy [TourneBoite $x $y $xd $yd $ang]
	lassign $Lxy xE yE
	if {0 && $ref eq "root"} {
	    puts [format "xi %6.3f xf %6.3f | yi %6.3f yf %6.3f | %s" $xd $xE $yd $yE $d]
	}
	$t set $d xcoord $xE
	$t set $d ycoord $yE
	foreach a {oldtheta theta LeftL LeftR RightR RightL LeftA RightA} {
	    if {[$t keyexists $d $a]} {
		set Adep [$t get $d $a]
		set Afin [expr {$Adep+$ang}]
		set Afin [expr {$Afin >= [2Pi]?$Afin-[2Pi]:$Afin}]
		set Afin [expr {$Afin <= [2Pi]?$Afin+[2Pi]:$Afin}]
		set Afin [expr {$Afin < 0.?$Afin+[2Pi]:$Afin}]
		$t set $d $a $Afin
	    }
	}
    }

    return
}



proc Improvement {AId n {Step 0}} {
    global Abr sum

    set PAD [set Abr($AId,PAD)]
    set t [set Abr(Arbre,$AId)]

    foreach e [$t children $n] {
	Improvement $AId $e $Step
    }

    puts stderr "$n"
    set Rep [NewMaxLR $AId $n]
    if {1 && $Rep} {
	AngleLRAncetres $AId $n
	set tmp $sum
	set sum [AjusteAngles2 $AId $n]
	puts [format "===> dsum %5.3f sum %5.3f | %s" [expr {$sum-$tmp}] $sum $n]
	puts ""

	if {$Step && ! [$t isleaf $n]} {
	    $PAD delete all
	    RetraceToutCart $AId root
	    #	    Entre
	    JAttends
	}
    }

    return $sum
}



proc Daylight {AId {n "root"}} {
    global sum Abr

    #    OrdonneLesFils $AId root
    #    LikeDrawtree $AId root
    #    exit
    puts ""
    #    DumpTree $AId [list NdLeft NdRight]
    puts ""

    set PAD [set Abr($AId,PAD)]
    set i 0
    set maxchange 1.0
    while {$i < 100 && $maxchange > 0.1} {
	if {$i >= 120} {set Step 1} {set Step 0}
	set sum 0.0
	set maxchange [Improvement $AId root $Step]
	incr i
	puts "\tIter $i $maxchange\n\n"
	if {0} {
	    $PAD delete all
	    RetraceToutCart $AId root
	    #	set xR [$t get root xcoord]
	    #	set yR [$t get root ycoord]
	    #	$PAD create oval [expr {$xR-8}] [expr {$yR-8}] [expr {$xR+8}] [expr {$yR+8}] -fill magenta -outline black
	    #	JAttends
	}
    }

    return
}




#chanmbre simple       64 /personne
#chambre twin (2 pers) 72 (petit dej)
#chambre grand lit


proc OrdonneLesFils {AId n} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}

    set Le [$t children $n]
    foreach e $Le {
	OrdonneLesFils $AId $e
    }
    if {$n eq "root"} {return}

    lassign $Le e1 e2
    set LM1 [AnglesMinMaxDe $AId $n $e1]
    lassign $LM1 A1 tmp AP1
    set LM2 [AnglesMinMaxDe $AId $n $e2]
    lassign $LM1 A2 tmp AP2

    set AAP1 [expr {abs($AP1-$A1)}]
    set AAP1 [expr {$AAP1>[Pi]?[2Pi]-$AAP1:$AAP1}]
    set AAP2 [expr {abs($AP2-$A1)}]
    set AAP2 [expr {$AAP2>[Pi]?[2Pi]-$AAP2:$AAP2}]
    if {$AAP1+$AAP2 > [Pi]} {set obtu 1} {set obtu 0}

    if {abs($A1-$A2)>[Pi]} {
	if {! $obtu} {
	    if {$A1<$A2} {
		$t set $n NdLeft  $e1
		$t set $n NdRight $e2
	    } else {
		$t set $n NdLeft  $e2
		$t set $n NdRight $e1
	    }
	} else {
	    if {$A1<$A2} {
		$t set $n NdLeft  $e2
		$t set $n NdRight $e1
	    } else {
		$t set $n NdLeft  $e1
		$t set $n NdRight $e2
	    }
	}
    } else {
	if { ! $obtu} {
	    if {$A1 > $A2} {
		$t set $n NdLeft  $e1
		$t set $n NdRight $e2
	    } else {
		$t set $n NdLeft  $e2
		$t set $n NdRight $e1
	    }
	} else {
	    if {$A1 > $A2} {
		$t set $n NdLeft  $e2
		$t set $n NdRight $e1
	    } else {
		$t set $n NdLeft  $e1
		$t set $n NdRight $e2
	    }
	}
    }

    return
}



proc AnglesMinMaxDe {AId n Le} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set Am  999.
    set Ax -999.
    set x [$t get $n xcoord]
    set y [$t get $n ycoord]
    set p [$t parent $n]
    set xp [$t get $p xcoord]
    set yp [$t get $p ycoord]
    set AnP [Coords2Angle [expr {$x-$xp}] [expr {$y-$yp}]]

    foreach d $Le {
	set xd [$t get $d xcoord]
	set yd [$t get $d ycoord]
	set Ang [Coords2Angle [expr {$xd-$x}] [expr {$yd-$y}]]

	if {$Ang < $Am} {set Am  $Ang}
	if {$Ang > $Ax} {set Ax  $Ang}
    }

    return [list $Am $Ax $AnP]
}



proc AngleMaxGaucheDroite {AId n} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return}
    #    if {$n eq "root"} {exir}

    puts "--- Min Max Gauche/Droit ---------"
    puts [format "Nd n : %s | x=%7.2f y=%7.2f" $n [$t get $n xcoord] [$t get $n ycoord]]

    set NdL [$t get $n NdLeft]
    set NdR [$t get $n NdRight]
    set LNdL [concat $NdL [$t descendants $NdL]]
    set LNdR [concat $NdR [$t descendants $NdR]]

    set LMM [AnglesMinMaxDe $AId $n $LNdL]
    lassign $LMM Am Ax Sum
    set Am2  [expr {$Am>[Pi]?$Am-[2Pi]:$Am}]
    set Ax2  [expr {$Ax>[Pi]?$Ax-[2Pi]:$Ax}]
    set Sum2 [expr {$Sum>[Pi]?$Sum-[2Pi]:$Sum}]
    puts "Am2 $Am2 Ax2 $Ax2 Sum2 $Sum2"
    set LRLL [expr {abs($Sum2-$Am2)+abs($Ax2-$Sum2)}]
    if {$LRLL > [Pi]} {set obtu 1} {set obtu 0}

    if {abs($Ax-$Am) > [Pi] && ! $obtu} {
	if {$Am < $Ax} {
	    $t set $n LeftL $Am
	    $t set $n LeftR $Ax
	} else {
	    $t set $n LeftL $Ax
	    $t set $n LeftR $Am
	}
    } else {
	if {$Am > $Ax} {
	    $t set $n LeftL $Am
	    $t set $n LeftR $Ax
	} else {
	    $t set $n LeftL $Ax
	    $t set $n LeftR $Am
	}
    }

    set LMM [AnglesMinMaxDe $AId $n $LNdR]
    lassign $LMM Am Ax Sum
    set Am2  [expr {$Am>[Pi]?$Am-[2Pi]:$Am}]
    set Ax2  [expr {$Ax>[Pi]?$Ax-[2Pi]:$Ax}]
    set Sum2 [expr {$Sum>[Pi]?$Sum-[2Pi]:$Sum}]
    set RRRL [expr {abs($Sum2-$Am2)+abs($Ax2-$Sum2)}]
    if {$RRRL > [Pi]} {set obtu 1} {set obtu 0}

    if {abs($Ax-$Am) > [Pi] && ! $obtu} {
	if {$Am < $Ax} {
	    $t set $n RightL $Am
	    $t set $n RightR $Ax
	} else {
	    $t set $n RightL $Ax
	    $t set $n RightR $Am
	}
    } else {
	if {$Am > $Ax} {
	    $t set $n RightL $Am
	    $t set $n RightR $Ax
	} else {
	    $t set $n RightL $Ax
	    $t set $n RightR $Am
	}
    }

    $t set $n LRLL $LRLL
    $t set $n RRRL $RRRL

    puts [format "Nd L %s | LL %5.2f LR %5.2f LRLL %5.2f" [$t get $n NdLeft] [$t get $n LeftL] [$t get $n LeftR] [$t get $n LRLL]]
    puts [format "Nd R %s | RL %5.2f RR %5.2f RRRL %5.2f" [$t get $n NdRight] [$t get $n RightL] [$t get $n RightR] [$t get $n RRRL]]
    puts ""

    return
}


proc AjusteAngles {AId n} {
    global Abr sum

    set t [set Abr(Arbre,$AId)]
    if {[$t isleaf $n]} {return $sum}
    if {$n eq "root"} {
	AjusteAnglesRoot $AId root
	return $sum
    }

    set RR [$t get $n RightR]
    set RR [expr {$RR>[Pi]?$RR-[2Pi]:$RR}]
    set RL [$t get $n RightL]
    set RL [expr {$RL>[Pi]?$RL-[2Pi]:$RL}]
    set LR [$t get $n LeftR]
    set LR [expr {$LR>[Pi]?$LR-[2Pi]:$LR}]
    set LL [$t get $n LeftL]
    set LL [expr {$LL>[Pi]?$LL-[2Pi]:$LL}]
    set AR [$t get $n AncesR]
    set AR [expr {$AR>[Pi]?$AR-[2Pi]:$AR}]
    set AL [$t get $n AncesL]
    set AL [expr {$AL>[Pi]?$AL-[2Pi]:$AL}]
    set NdRight [$t get $n NdRight]
    set NdLeft  [$t get $n NdLeft]
    set LRLL [$t get $n LRLL]
    set RRRL [$t get $n RRRL]

    if {abs($RL-$AL) < $RRRL} {
	set RRAL 0.
    } else {
	set RRAL [expr {abs($RR-$AL)}]
	set RRAL [expr {$RRAL>[Pi]?[2Pi]-$RRAL:$RRAL}]
    }
    if {abs($LL-$RL) < $LRLL} {
	set LRRL 0.
    } else {
	set LRRL [expr {abs($LR-$RL)}]
	set LRRL [expr {$LRRL>[Pi]?[2Pi]-$LRRL:$LRRL}]
    }
    if {$LRLL > abs($LR-$AR)} {
	set ARLL 0.
    } else {
	set ARLL [expr {abs($AR-$LL)}]
	set ARLL [expr {$ARLL>[Pi]?[2Pi]-$ARLL:$ARLL}]
    }

    set AngVide [expr {$LRRL + $ARLL + $RRAL}]
    set angeq [expr {$AngVide/3.}]
    set DecTot [expr {abs($angeq-$RRAL) + abs($angeq-$LRRL) + abs($angeq-$ARLL)}]
    set sum [expr {$sum + $DecTot}]

    set tilt1 [expr {$angeq-$RRAL}]
    TiltArbre $AId $n $NdRight $tilt1

    if {$tilt1 < 0.} {
	set LRRL [expr {$LRRL+abs($tilt1)}]
    } else {
	set LRRL [expr {$LRRL-abs($tilt1)}]
    }
    set tilt2 [expr {$angeq-$LRRL}]
    TiltArbre $AId $n $NdLeft $tilt2

    puts "----- Ajsutement --------"
    puts "$n | R $NdRight | L $NdLeft"
    puts [format "RRAL %5.2f RR %5.2f AL %5.2f" $RRAL $RR $AL]
    puts [format "LRRL %5.2f LR %5.2f RL %5.2f" $LRRL $LR $RL]
    puts [format "ARLL %5.2f AR %5.2f LL %5.2f" $ARLL $AR $LL]
    puts [format "Ang Egaux : %6.2f Decal %6.2f" $angeq $DecTot]
    puts [format "tilt RRAL : %6.2f | LRRL %6.2f" $tilt1 $tilt2]
    puts [format "nRRAL %6.2f nLRRL %6.2f" [expr {$RRAL+$tilt1}] [expr {$LRRL+$tilt2}]]
    puts ""

    return $sum
}


proc OverlapBranch {AId n Ng Nd} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set xr [$t get $Ng xcoord]
    set yr [$t get $Ng ycoord]
    set xl [$t get $Nd xcoord]
    set yl [$t get $Nd ycoord]
    set xn  [$t get $n xcoord]
    set yn  [$t get $n ycoord]

    if {($yl-$yn)*($xr-$xn)-($xl-$xn)*($yr-$yn) > 0.} {
	set ov 1
    } else {
	set ov 0
    }

    return $ov
}


proc TagNode {AId} {
    global Abr

    set t [set Abr(Arbre,$AId)]
    set PAD [set Abr($AId,PAD)]
    set Li [$PAD gettags [$PAD find withtag current]]
    if {[set ix [lsearch -regexp $Li "rota-"]] ==-1} {
	return
    }
    set i [lindex $Li $ix]
    set n [$t attr $i]
    
    set Abr($AId,NodeSel) $n
    set Lbox [$PAD bbox $i]
    set Id [$PAD create oval $Lbox \
	    -fill black \
	    -outline black \
	    -tags IdNodeSel]

    set Li [$PAD find withtag rotation]
    foreach i $Li {
	$PAD itemconfig $i -fill white -outline white
    }
    $PAD lower rotation
    $PAD bind rotation <Button-1> ""
    $PAD bind IdNodeSel <B1> [list $PAD delete IdNodeSel ; set Abr($AId,NodeSel) ""]

    return
}


proc ModeTagNode {{n1 ""} {n2 ""} {op ""}} {
    global Abr

    if {$n1 ne "" && $n2 eq ""} {
	set AId $n1
    } else {
	lassign [split $n2 ,] AId TT
	if {[set Abr($AId,DoTagLeaf)]} {
	    set Abr($AId,DoTagLeaf) 0
	}
    }
    if {[set Abr($AId,Swap)]} {
	set Abr($AId,Swap) 0
	ModeSwap $AId
    }
    if {[set Abr($AId,BootShow)]} {
	set Abr($AId,BootShow) 0
	MontreBootstrap $AId
    }

    set PAD [set Abr($AId,PAD)]
    set t [set Abr(Arbre,$AId)]
    if {[set Abr($AId,DoTagNode)]} {
	set Li [$PAD find withtag rotation]
	foreach i $Li {
 	    $PAD itemconfig $i -fill blue -outline black
	}
	$PAD raise rotation
	$PAD bind rotation <Button-1> [list TagNode $AId]
    } else {
	set i [$PAD find withtag IdNodeSel]
	$PAD delete $i
    }

    return
}


proc ModeTagLeaf {{n1 ""} {n2 ""} {op ""}} {
    global Abr

    if {$n1 ne "" && $n2 eq ""} {
	set AId $n1
    } else {
	lassign [split $n2 ,] AId TT
    }

    if {[set Abr($AId,DoTagNode)]} {
	set Abr($AId,DoTagNode) 0
	ModeTagNode $AId
    }

    set PAD [set Abr($AId,PAD)]
    set t [set Abr(Arbre,$AId)]
    
    if {[set Abr($AId,DoTagLeaf)]} {
	if {[set Abr($AId,LeafSel)] eq [set Abr($AId,LeafSelOld)]} {
	    return
	}
	set n [set Abr($AId,LeafSel)]
	set Abr(LeafSelOld) $n
	set idx [lsearch $Abr($AId,LSeq) $n]
	set n [lindex $Abr($AId,LSeqOri) $idx]

	set Id [$PAD find withtag "Rfeuille-$n"]
	set If [$PAD find withtag "feuille-$n"]
	$PAD itemconfig $Id -outline black -width 3
	$PAD addtag Rtagged withtag $Id
    } else {
	# DoTagLeaf == 0
	set LIt [$PAD find withtag Rtagged]
	foreach i $LIt {
	    set b [$PAD itemcget $i -fill]
	    $PAD itemconfig $i -width 0 -outline $b
	}
    }

    return
}


proc ModeTag {AId} {
    ModeTagNode $AId
    ModeTagLeaf $AId

    return
}


proc CreeArbre {{a ""} {b ""} {s ""} {c ""} {d ""} args} {
    #set affa [lindex $a 0]
    #set affb [lindex $b 0]
    #set affc [lindex $c 0]
    #set affd [lindex $d 0]
    #set affs [lindex $s 0]
    #set args ""
    #puts "Cree $affa $affb $affc $affd $affs"
    #flush stdout ; update idletasks

    set Idg [CreeId $a $b]
    set Idd [CreeId $c $d]
    set Id  [ReunitBranches $Idg $Idd]
    
    while {[llength $args]} {
	#puts "args : >>$args<<"
	# elt 0 est ' , ' ...
	set args [lassign $args tmp a b]
	set Ids [CreeId $a $b]
	set Id [ReunitBranches $Ids $Id]
    }

    return $Id
}


proc CreeId {n l} {
    if {[llength $n] > 1} {
	lset n 2 3 $l
    } else {
	set n [CreeNouveauArbre $n $n $l]
    }

    return $n
}


proc ReunitBranches {a b} {
    set i [incr ::NoDeLArbre]

    set Id "Tree-$i"
    set ab [lindex $a 0]-[lindex $b 0]
    set LI [CreeNouveauArbre $Id Noeud-$ab 0.0]
    set LI [CopieArbre $LI $a]
    set LI [CopieArbre $LI $b]

    return $LI
}


proc CreeNouveauArbre {t n l} {
    return [list $t {} [list name $n length $l AngAbs 0. ordre 0 theta 0. oldtheta 0. r 0. width 0]]
}


proc CopieArbre {s g} {
    set ls [llength $s]
    lset g 1 0
    lappend s {*}[lrange $g 0 2]
    foreach {k i p} [lrange $g 3 end] {
	lappend s $k [incr i $ls] $p
    }

    return $s
}


proc InitTreeContextMenu {} {
    global OrdEtcDir

    image create photo PT \
	-file [file join $OrdEtcDir hand14.gif]
    image create photo ZP \
	-file [file join $OrdEtcDir loupeplus.gif]
    image create photo ZM \
	-file [file join $OrdEtcDir loupemoins.gif]
    image create photo RP \
	-file [file join $OrdEtcDir rotateplus.gif]
    image create photo RM \
	-file [file join $OrdEtcDir rotatemoins.gif]
    image create photo WE \
	-file [file join $OrdEtcDir noeudecarte.gif]
    image create photo WS \
	-file [file join $OrdEtcDir noeudserre.gif]
    image create photo HE \
	-file [file join $OrdEtcDir heightecarte.gif]
    image create photo HS \
	-file [file join $OrdEtcDir heightserre.gif]

    return
}


proc CreateTreeContextMenu {AId menu} {
    # destroy any pre-existing menu with the same name
    set mRad "${menu}Rad"
    set mDen "${menu}Den"
    destroy $mRad
    destroy $mDen
    
    # create new menus
    # for radial representation
    menu $mRad -tearoff 0
    $mRad add command -compound left -image PT -label "Pointer" -command [list PointerMode $AId]
    $mRad add command -compound left -image ZP -label "Zoom +" -command [list ZoomMode $AId zplus]
    $mRad add command -compound left -image ZM -label "Zoom -" -command [list ZoomMode $AId zmoins]
    $mRad add command -compound left -image RP -label "Rotate +" -command [list RotateMode $AId "-[PiS8]"]
    $mRad add command -compound left -image RM -label "Rotate -" -command [list RotateMode $AId [PiS8]]
#    $mRad add command -label "Zoom +" -command [list ZoomMode $AId zplus]
#    $mRad add command -label "Zoom -" -command [list ZoomMode $AId zmoins]
#    $mRad add command -label "Rotate +" -command [list RotateMode $AId "-[PiS16]"]
#    $mRad add command -label "Rotate -" -command [list RotateMode $AId [PiS16]]
#    $mRad add command -label "Tag ..." -command [list set Abr($AId,DoTagNode) 1]

    # for dendrogram representation
    menu $mDen -tearoff 0
    $mDen add command -label "Pointer" -compound left -image PT -command [list PointerMode $AId]
    $mDen add command -label "Width +" -compound left -image WE -command [list WidthMode $AId 20]
    $mDen add command -label "Width -" -compound left -image WS -command [list WidthMode $AId -20]
    $mDen add command -label "Height +" -compound left -image HE -command [list HeightMode $AId 5]
    $mDen add command -label "Height -" -compound left -image HS -command [list HeightMode $AId -5]

    return
}


proc ShowTreeContextMenu {AId menu} {
    if {[set ::Abr($AId,TypeTree)] eq "dendrogram"} {
	set m "${menu}Den"
    } else {
	set m "${menu}Rad"
    }

    set w [winfo parent $m]
    lassign [winfo pointerxy $w] x y
    tk_popup $m $x $y

    return
}


proc cboot {} {
    package require tcc
    tcc::ccode doboot {char** seqs} char** {
	int i

	for (i==0;i<;i++) {
	    pil[i]=
	}
    }
    return
}


proc CreeArbre2 {args} {

    if {[llength $args] > 5} {
	set rest [lrange $args 5 end]
	set args [lrange $args 0 4]
	set Id [CreeArbre {*}$args]
	set args "$Id -1. [join $rest]"
	set Id [CreeArbre {*}$args]

	return $Id
    }

    lassign $args a b s c d

    set Idg [CreeId $a $b]
    set Idd [CreeId $c $d]
    set Id [ReunitBranches $Idg $Idd]

    return $Id
}


proc CopieArbre2 {td nd ta na} {
    # copie le sous-arbre de td au noeud nd dans
    # l'arbre ta au noeud na

    set cible $na
    if {$na eq "root"} {set cible [$ta get $na name]}
    set Ld [$td serialize]
    set La [$ta serialize $na]
    set idx [lsearch $Ld $nd]
    set lgd [llength $Ld]
    lappend Ld $cible $idx [lindex $La 2]
    foreach {n i k} [lrange $La 3 end] {
	incr i $lgd
	lappend Ld $n $i $k
    }
    #	puts "Ld $Ld"
    $td deserialize $Ld

    return
}


proc Tree2PH {t n} {
    if {[$t isleaf $n]} {
	return $n
    }

    set x "("
    set Lnd {}
    foreach fils [$t children $n] {
	set l ":[$t get $fils length]"
	lappend Lnd "[Tree2PH $t $fils]$l"
    }
    append x [join $Lnd ,] ")"
    if {$n eq "root"} {
	append x ";"
    }

    return $x
}


proc tt2p {} {
    global Abr

    set ph [ContenuDuFichier calibre5.ph]
    puts "Tree IN :"
    puts "$ph"
    set AId [DecortiqueUnArbre $ph]
    set t [set Abr(Arbre,$AId)]
    #puts "\nTree ORD"
    #puts "[$t serialize root]"

    set res [Tree2PH $t root]
    puts "\n$res"

    exit
}


# 368 443 pos seq human
# 321 391 1efw


proc thash {} {
    set Lf {10 25 50 100 200 500 1000} 
    set Lt {10 25 50 100 200 500 1000} 

    set Lt {10 300}
    set Lf {10 300}

    foreach t $Lt {
	set Lxt {}
	for {set i 0} {$i < $t} {incr i} {
	    lappend Lxt [expr {int($t*rand())}]
	}
	set T(Lt,$t) $Lxt
    }
    foreach f $Lf {
	set Lxf {}
	for {set i 0} {$i < $f} {incr i} {
	    lappend Lxf [expr {int((2*$f)*rand())}]
	}
	set T(Lf,$f) $Lxf
    }
    
    foreach t $Lt {
	set Lxt [set T(Lt,$t)]
	foreach f $Lf {
	    set Lxf [set T(Lf,$f)]

	    set rep 0
	    set o [time {
		foreach x $Lxt {
		    if {$x in $Lxf} {
			incr rep
		    }
		}
	    } 20]
	    set res(in,$t,$f) [lindex $o 0]
	    
	    set rep 0
	    unset -nocomplain TH
	    set o [time {
		array set TH [HashExiste $Lxf]
		foreach x $Lxt {
		    incr rep [info exists TH($x)]
		}
	    } 20]
	    set res(Hash,$t,$f) [lindex $o 0]
	}
    }
    
    set lg [PlusLongEltDe [array names res]]
    set Li [array get res "in,*"]
    set Lh [array get res "Hash,*"]
    set Li [lsort -real -stride 2 -index 1 $Li]
    set Lh [lsort -real -stride 2 -index 1 $Lh]
    foreach {ki vi} $Li {kh vh} $Lh {
	puts [format "%${lg}s %7.1f %${lg}s %f" $ki $vi $kh $vh]
    }

    exit
}


proc DumpIt {AId} {
    global Abr
    set PAD $Abr($AId,PAD)
    foreach id [$PAD find all] {
	if {[$PAD type $id] eq "text"} {
	    puts "[$PAD itemcget $id -text] [$PAD coords $id] | [$PAD itemcget $id -angle]"
	}
    }

    return
}


proc dotree {} {
    ChangeMode arbres
    update idletasks
    
    SelectionneToutesColonnes
    update idletasks
    $::WOrdali(Tree,Draw) invoke
    update idletasks
    #CalculeUnArbre
    
    return
}


proc RecoverTrees {{Mac ""}} {
    global Abr Defauts

    # Recover the trees of instance Mac (the current one by default,
    # it must be displayed) after loading an ORD file.
    # (no Abr(Liste) when every tree was closed before saving)
    if {! [info exists Abr(Liste)]} {
	return
    }
    if {$Mac eq ""} {
	set Mac [MacCourant]
    }
    
    foreach AId $Abr(Liste) {
	if {$Abr($AId,Mac) != $Mac} {
	    continue
	}
	
	# Init fonte et parametres par defauts
	if {"TreeFont$AId" ni [font names]} {
	    font create "TreeFontBoot$AId" -family Helvetica -size [set Defauts(FontSizeTreeBoot)] -weight [set Defauts(FontWghtTree)]
	    font create "TreeFont$AId" -family Helvetica -size [set Defauts(FontSizeTree)] -weight [set Defauts(FontWghtTree)]
	}

	set TArbre $Abr(Arbre,$AId)
	set ArbreOri $Abr(ArbreSer,$AId)
	if {[info commands $TArbre] ne ""} {
	    $TArbre destroy
	}
	struct::tree $TArbre
	$TArbre deserialize $ArbreOri
	# radial tree : extent of the drawing (Xmin ...) is not saved
	if {$Abr($AId,TypeTree) ne "dendrogram"} {
	    Tree2Coordonnees $AId
	}
	AfficheUnArbre $AId
    }

    return
}


    proc CreeTestTree {} {
    # Taxon | Mnemonic | Scientific name | Common name | Synonym | Other Names | Reviewed | Rank | Lineage | Parent
    
    set ::t1 {}
    # cree racine en 0
    # noeud depart 1
    set ::no 1
    lappend ::t1 "$::no\tn$::no\tn$::no\tn$::no\tn$::no\tn$::no\t\t\t\t0"

    # ensuite cree deux noeud ou vont etre rattaches
    # l'arbre binaire et les feuilles directes
    # de 1 part 2 et 3
    incr ::no 1    
    lappend ::t1 "$::no\tn$::no\tn$::no\tn$::no\tn$::no\tn$::no\t\t\t\t1"
    incr ::no
    lappend ::t1 "$::no\tn$::no\tn$::no\tn$::no\tn$::no\tn$::no\t\t\t\t1"

    #set ::no 3
    set level 2
    DoLevel $::no $level

    if {0} {
	# rattache a feuille 2
	incr ::no
	set nbF [expr {int(pow(2,($level+1)))}]
	for {set i 0} {$i < $nbF} {incr i} {
	    lappend ::t1 "$::no\tn$::no\tn$::no\tn$::no\tn$::no\tn$::no\t\t\t\t2"
	    incr ::no
	}
    }

    set o [open t1.tab w]
    puts $o [join $::t1 \n]
    close $o

    return [join $::t1 \n]
}

 
proc DoLevel {root Level} {
    set Lf {}
    for {set i 0} {$i < 2} {incr i} {
	incr ::no

	puts "$Level= [string repeat "   " [expr {3-$Level}]]  -> $::no pere $root"
	lappend ::t1 "$::no\tn$::no\tn$::no\tn$::no\tn$::no\tn$::no\t\t\t\t$root"
	lappend Lf $::no
    }
    #puts "level $Level no $::no"

    incr Level -1
    update

    if {$Level >= 0} {
	foreach f $Lf {
	    DoLevel $f $Level
	}
    }

    return
}


proc ArrayTree2PH {node} {
    # procedure to process trees used by SoTOL
    # See /home/moumou/Nicolas/sotol
    
    set Lf $::Tx(Child,$node)
    if {$Lf != {}} {
	append ::phTree "("
	foreach f $Lf {
	    ArrayTree2PH $f
	}
	set ::phTree [string trimright $::phTree ,]
	append ::phTree "):1,"
    } else {
	append ::phTree "n$node:1,"
    }

    if {$Lf != {}} {
	#append ::phTree "):1"
    }

    return $::phTree
}


proc ttn2 {} {
    global Tx phTree 
    
    #set Ll [LesLignesDuFichier euk.tab]
    set Ll [LesLignesDuFichier newtree.txt]
    foreach l $Ll {
        regsub -all { +} [string trim $l] " " l
	if {$l eq ""} {
	    continue
	}

        set Lv [split $l]
	#set Lv [split $l \t]
	set node [lindex $Lv 0]
	set par  [lindex $Lv end]
	
	set Tx(Parent,$node) $par
	lappend Tx(Child,$par) $node
	set Tx(Name,$node) "n$node"
	set Tx(Name,$par)  "n$par"
	set Tx(Rank,$node) "node"
	set Tx(Rank,$par)  "node"

	lappend Lf $node
	lappend Lp $par
    }
    set Lfeuilles [lsort -unique -integer [lor $Lf $Lp from1]]
    set LAllIds [lsort -unique [concat $Lf $Lp]]
    foreach f $LAllIds {
	if {! [info exists Tx(Child,$f)]} {
	    # is a leaf
	    set Tx(Rank,$f) Species
	    set Tx(Child,$f) {}
	}
	set Tx(NbChild,$f) [llength $Tx(Child,$f)]
	set Tx($f,nbC) [llength $Tx(Child,$f)]
    }

    set phTree "("
    #ArrayTree2PH 2759
    ArrayTree2PH 0
    append phTree ");"

    set Fin [string last ":" $phTree]
    set phTree "[string range $phTree 1 $Fin-1];"
    set phTree [string map {",)" ")"} $phTree]

    puts ""
    puts "$phTree"
    flush stdout
    set o [open test.ph w]
    puts $o "$phTree\n"
    close $o

    LoadTkAndPackages
    LoadUnArbre test.ph

    return
}


proc tbc {} {
    LoadTkAndPackages
    canvas .c \
	-bg black
    pack .c

    set AId 1
    set Abr($AId,ContextMenu) .c.menu
    InitTreeContextMenu
    CreateTreeContextMenu $AId [set Abr($AId,ContextMenu)]
    bind .c <Button-3> [list ShowTreeContextMenu $AId [set Abr($AId,ContextMenu)]]
    .c create rectangle 20 20 100 100 -fill cyan
    .c create oval 120 120 200 200  -fill magenta
    button .b -text "Clear" -fg white -bg blue -command [list .c delete all]
    pack .b

    return
}


proc ttn3 {} {
    global Abr Tx Lfeuilles LSelectableIds LAllIds TaxRoot

    ttn2

    set Lsamp [LesLignesDuFichier out]
    set PAD [set Abr(1,PAD)]
    foreach l $Lsamp {
	set n "n$l"
	set id [$PAD find withtag "Rfeuille-$n"]
	puts "$n $id"
	$PAD itemconfig $id -fill blue
    }

    PrintCanvas $PAD "" it100000.png
    
    return

	incr Tx(NbChild,$par)

	set Tx(NbChildCum,$node) 0
	set Tx(hasSel,$node)     0
	set Tx(Etat,$node)       0
	set Tx(isComp,$node)     0
	set Tx(NbComp,$node)     0	
	set Tx(isGold,$node)     0
	set Tx(isInt,$node)      0
	set Tx(NbInt,$node)      0
	set Tx(ShowInt,$node)    0
	set Tx(NbKeep,$node)     0

	lappend Tx(Child,$par) $node


    set TaxRoot 0
    CountCompleteGenomesPerNode
    set LSelectableId $LAllIds
    set Tx(hasSel,0) 1
    set Tx(hasSel,$TaxRoot) 1
    foreach id $LSelectableId {
	set Tx(isGold,$id) 1
	set Tx(hasSel,$id) 1
    }

    DefineChildsWithGold

    
    return
}


proc ttn4 {} {
    global TaxRoot Tx

    set TaxRoot 0
    set Tx(-root) 0

    return
}


proc tpt {} {
    puts "chuisla" ; flush stdout ; update idletasks
    ChangeMode arbres
    puts "chuisla" ; flush stdout ; update idletasks
    SelectionneToutesColonnes
    puts "chuisla" ; flush stdout ; update idletasks
    CalculeUnArbre
    puts "chuisla" ; flush stdout ; update idletasks

    update idletasks
    puts "on va sauver !"
    SauveLAlignement ORD toto.ord
    puts "saved !"
    exit
    return
}

