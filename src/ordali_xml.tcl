

#
#
# ordali_xml.tcl
#


proc CreeLeMacsim {{out "dehors"} {LNoms ""} {LSeqs ""}} {
    global LNOrdali LSOrdali TabSF TpI TMolW
    global GroupeDeLaSequence SDG
    global NomAlignement
    global AlnName AlnScore AlnNote
    global TColScore
    global {*}[info globals "TD*"]

    # First, check if file is writable
    if {0 && ! [file is writable $out]} {
	FaireLire "Warning !\nThe file named :\n>$out<\ncan not be written ! Check location or rights permission."
	
	return
    }

    dom createDocument "macsim" doc

    # XML nodes creation commands
    dom createNodeCmd "elementNode" MS::alignment
    dom createNodeCmd "elementNode" MS::aln-name
    dom createNodeCmd "elementNode" MS::aln-score
    dom createNodeCmd "elementNode" MS::aln-note
    dom createNodeCmd "elementNode" MS::sequence
    dom createNodeCmd "elementNode" MS::seq-name
    dom createNodeCmd "elementNode" MS::seq-info
    dom createNodeCmd "elementNode" MS::accession
    dom createNodeCmd "elementNode" MS::nid
    dom createNodeCmd "elementNode" MS::definition
    dom createNodeCmd "elementNode" MS::organism
    dom createNodeCmd "elementNode" MS::taxid
    dom createNodeCmd "elementNode" MS::group
    dom createNodeCmd "elementNode" MS::grouplabel
    dom createNodeCmd "elementNode" MS::lifedomain
    dom createNodeCmd "elementNode" MS::hydrophobicity
    dom createNodeCmd "elementNode" MS::ec
    dom createNodeCmd "elementNode" MS::length
    dom createNodeCmd "elementNode" MS::lineage
    dom createNodeCmd "elementNode" MS::taxon
    dom createNodeCmd "elementNode" MS::molecularweight
    dom createNodeCmd "elementNode" MS::isoelectricpoint
    dom createNodeCmd "elementNode" MS::seq-data
    dom createNodeCmd "elementNode" MS::ftable
    dom createNodeCmd "elementNode" MS::fitem
    dom createNodeCmd "elementNode" MS::ftype
    dom createNodeCmd "elementNode" MS::fstart
    dom createNodeCmd "elementNode" MS::fstop
    dom createNodeCmd "elementNode" MS::fcolor
    dom createNodeCmd "elementNode" MS::fscore
    dom createNodeCmd "elementNode" MS::fnote

    dom createNodeCmd "elementNode" MS::goxreflist
    dom createNodeCmd "elementNode" MS::goxref
    dom createNodeCmd "elementNode" MS::goid
    dom createNodeCmd "elementNode" MS::goclass
    dom createNodeCmd "elementNode" MS::godesc
    dom createNodeCmd "elementNode" MS::goevidence

    dom createNodeCmd "elementNode" MS::column-score
    dom createNodeCmd "elementNode" MS::colsco-name
    dom createNodeCmd "elementNode" MS::colsco-owner
    dom createNodeCmd "elementNode" MS::colsco-type
    dom createNodeCmd "elementNode" MS::colsco-group
    dom createNodeCmd "elementNode" MS::colsco-data
    dom createNodeCmd "textNode"    MS::text

    $doc documentElement root
    $root appendFromScript {
	MS::alignment
    }
    set aln [$root lastChild]

    if {! [info exists AlnNote] || [string first "Created by Ordali" $AlnNote] == -1} {
	append AlnNote " Created by Ordali"
    }
    # set when a MACSIM file or the interface is loaded, not when another
    # format is converted in batch (msaconvert file.tfa -format xml)
    if {! [info exists AlnScore]} {
	set AlnScore 0.0
    }
    if {! [info exists AlnName]} {
	set AlnName ""
    }
    foreach n [list "aln-name" "aln-score" "aln-note"] k [list "$AlnName" "$AlnScore" "$AlnNote"] {
	$aln appendFromScript {
	    MS::$n {MS::text $k}
	}
    }
    
    # Boucle sur les noms, remplit champ <sequence>
    if {$LNoms eq ""} {
	set LNoms $LNOrdali
	set LSeqs $LSOrdali
    }

    foreach n $LNoms s $LSeqs {
	if {[string trim $n] eq ""} {
	    continue
	}

	set IsPDB [EstUnAccessPDB $n]
	if {$IsPDB} {
	    set mol [DonneIdDeAccessPDB $n]
	    set chn [DonneChainDeAccessPDB $n]
	    if {$chn eq ""} {set chn "a"}
	}
	set s [string map [list "." - "Z" -] $s]
	set s [string tolower $s]
	set lgs [string length [string map {- ""} $s]]

	$aln appendFromScript {
	    MS::sequence -seq-type Protein
	}
	set ns [$aln lastChild]
	$ns appendFromScript {
	    MS::seq-name {MS::text [set TDesSeqnames($n)]}
	}
	$ns appendFromScript {
	    MS::seq-info
	}
	# sequence infos
	set si [$ns lastChild]
	$si appendFromScript {
	    set ac [set TDesAccess($n)]
	    MS::accession {MS::text $ac}
	}
	if {[info exists TDesBId($n)]} {
	    $si appendFromScript {
		set bid [set TDesBId($n)]
		MS::nid {MS::text $bid}
	    }
	}
	set grp [set GroupeDeLaSequence($n)]
	$si appendFromScript {
	    set g [string range $grp 5 end]
	    MS::group {MS::text $g}
	}
	# label of the group, only if it was edited (Clusters Names)
	if {[info exists SDG(Equiv,$grp)] && $SDG(Equiv,$grp) ne $grp} {
	    $si appendFromScript {
		MS::grouplabel {MS::text $SDG(Equiv,$grp)}
	    }
	}
	if {[info exists TDesDescriptifs($n)]} {
	    $si appendFromScript {
		set des [set TDesDescriptifs($n)]
		MS::definition {MS::text $des}
	    }
	}
	if {[info exists TDesOrganismes($n)]} {
	    $si appendFromScript {
		set orga [set TDesOrganismes($n)]
		MS::organism {MS::text $orga}
	    }
	}
	if {[info exists TDesTaxId($n)]} {
	    $si appendFromScript {
		set tax [set TDesTaxId($n)]
		MS::taxid {MS::text $tax}
	    }
	}
	$si appendFromScript {
	    MS::length {MS::text $lgs}
	}
	if {[info exists TDesPhylum($n)]} {
	    # same normalisation as DecortiqueNoeudXml :
	    # unknown or empty life domain -> undefined
	    set LifeD [string totitle [set TDesPhylum($n)]]
	    if {$LifeD ni $::Defauts(LifeDomains)} {
		set LifeD "undefined"
	    }
	    $si appendFromScript {
		MS::lifedomain {MS::text $LifeD}
	    }
	}
	if {[info exists TDuLineage($n)]} {
	    $si appendFromScript {
		MS::lineage
		set tx [$si lastChild]
		foreach t [set TDuLineage($n)] {
		    $tx appendFromScript {
			MS::taxon {MS::text $t}
		    }
		}
	    }
	}
	if {[info exists TDesGO($n)]} {
	    $si appendFromScript {
		MS::goxreflist
		set ng [$si lastChild]
		foreach e [set TDesGO($n)] {
		    $ng appendFromScript {
			MS::goxref
			set nv [$ng lastChild]
			$nv appendFromScript {
			    foreach {k v} $e {
				MS::$k {MS::text $v}
			    }
			}
		    }
		}
	    }
	}

	if {[info exists TDesHydro($n)]} {
	    $si appendFromScript {
		MS::hydrophobicity {MS::text [set TDesHydro($n)]}
	    }
	}
	if {[info exists TDesEC($n)]} {
	    $si appendFromScript {
		MS::ec {MS::text [set TDesEC($n)]}
	    }
	}

	# Features
	# Cons-* are not saved (generated from the
	# column-scores). ftable is written only if
	# there is at least one feature to write
	# (DTD : ftable (fitem+))
	set Lnf {}
	foreach nf [lsort [array names TabSF "$n,*"]] {
	    lassign [split $nf ,] tmp type
	    if {[string first "Cons-" $type] > -1 || [set TabSF($nf)] eq {}} {
		continue
	    }
	    lappend Lnf $nf
	}
	if {$Lnf != {} } {
	    $si appendFromScript {
		MS::ftable
	    }
	    set ft [$si lastChild]
	    foreach nf $Lnf {
		lassign [split $nf ,] tmp type
		foreach f [set TabSF($nf)] {
		    DecortiqueUneFeature $f iStart iStop color score note csys target

		    if {$csys eq "local" || $csys eq ""} {
			# DonnePosGS gives pos seq. 
			# starting at 1
			set start [DonnePosGS $n $iStart]
			set stop  [DonnePosGS $n $iStop]
			if {$IsPDB} {
			    # CoordsPDB2Seq gives 
			    # values starting at 0 !
			    set start [expr {[$mol CoordsPDB2Seq $chn $start] + 1}]
			    set stop  [expr {[$mol CoordsPDB2Seq $chn $stop] + 1}]
			}
		    } else {
			set start [expr {$iStart + 1}]
			set stop  [expr {$iStop  + 1}]
		    }
		    if {$target ne "" && $target ne "seq"} {
			$ft appendFromScript {
			    MS::fitem -coords $csys -target $target
			}
		    } else {
			$ft appendFromScript {
			    MS::fitem -coords $csys
			}
		    }

		    set fi [$ft lastChild]
		    $fi appendFromScript {
			MS::ftype {MS::text $type}
		    }
		    $fi appendFromScript {
			MS::fstart {MS::text $start}
		    }
		    $fi appendFromScript {
			MS::fstop {MS::text $stop}
		    }
		    $fi appendFromScript {
			MS::fcolor {MS::text $color}
		    }
		    $fi appendFromScript {
			MS::fscore {MS::text $score}
		    }
		    $fi appendFromScript {
			MS::fnote {MS::text $note}
		    }
		}
	    }
	}
	# data section -> the aa sequence
	$ns appendFromScript {
	    MS::seq-data {MS::text $s}
	}
	$si appendFromScript {
	    MS::molecularweight {MS::text [set TDesMolW($n)]}
	}
	$si appendFromScript {
	    MS::isoelectricpoint {MS::text [set TDespI($n)]}
	}
    }

    if {0} {                    ;#rRRR
    # Column Score
    foreach n $TColScore(Names) {
	#rRRR puts "$n"
	foreach d $TColScore($n,Data) {
	    #rRRR puts "  [llength $d]"
	}
    }
}

    if {[info exists TColScore]} {
	# insert each colmeasurement
	foreach name $TColScore(Names) {
	    set ixc 0
	    foreach owner [set TColScore($name,Owner)] {
		# column-score without data is not saved
		if {[string trim [lindex [set TColScore($name,Data)] $ixc]] eq ""} {
		    incr ixc
		    continue
		}
		$aln appendFromScript {
		    MS::column-score
		}
		set cs [$aln lastChild]
		
		if {[regexp {Group[0-9]+$} $owner]} {
		    set io [string range $owner 5 end]
		} else {
		    set io [string range $owner [string last "_" $owner]+1 end]
		}

		# suffix only if it is a valid one ('all' or
		# group number), as DecortiqueColumnScore strips
		# it back. Otherwise (empty owner) a '_' was
		# added at each save.
		if {$io eq "all" || [string is integer -strict $io]} {
		    set csname "${name}_$io"
		} else {
		    set csname $name
		}
		$cs appendFromScript {
		    MS::colsco-name {MS::text $csname}
		}

		foreach cle {colsco-owner colsco-type colsco-data colsco-group} k {Owner Type Data Group} {
		    $cs appendFromScript {
			MS::$cle {MS::text [lindex [set TColScore($name,$k)] $ixc]}
		    }
		}
		incr ixc
	    }
	}
    }
        
    set fout [open $out w]
    puts $fout "<?xml version=\"1.0\"?>"
    puts $fout "<!DOCTYPE macsim SYSTEM \"http://www.lbgi.fr/macsim.dtd\">"
    $doc asXML -channel $fout
    close $fout
    
    $doc delete

    return
}


proc DecortiqueUnXml {f anom aSeq} {
    
    upvar $aSeq Sequences $anom LNOrdali
    
    FaireAttendre .pxml "Please wait ...\nParsing macsim file ..."
    
    if {$f eq ""} {
	return 0
    }
    set LXml {}
    if {[regexp "\n" $f]} {
	set LXml [join $f "\n"]
    } else {
	if {[file exists $f]} {
	    set LXml [ContenuDuFichier $f]
	}
    }
    if {$LXml eq {} } {
	return 0
    }

    set Id  [dom parse $LXml]
    set RId [$Id documentElement]
    set LNoeudsNoms [$RId selectNodes //seq-name]
    set Lseq [$RId selectNodes //seq-data]

    set LNOrdali {}
    foreach tn $LNoeudsNoms ts $Lseq {
	set n [$tn selectNodes string(.)]
	set n [string trim $n]
	
	set s [$ts selectNodes string(.)]
	set s [string map [list "-" "." "~" "." "\n" "" " " ""] $s]
	set s [string toupper $s]
	
	set Sequences($n) $s
	lappend LNOrdali $n
    }

    FaireLaSuite .pxml

    return $Id
}



proc ExtraitListeTypesFeatures {id aLFeat} {

    upvar $aLFeat ListeTypesFeatures

    set RId [$id documentElement]
    set LNoeudFeatures [$RId selectNodes //ftype]

    foreach n $LNoeudFeatures {
	set f [$n selectNodes string(.)]
	lappend ListeTypesFeatures $f
    }
    set ListeTypesFeatures [lsort -unique $ListeTypesFeatures]

    return $ListeTypesFeatures
}



proc ExtraitListeItemFeatures {id aLItFeat} {

    upvar $aLItFeat ListeItemFeatures

    set RId [$id documentElement]

    set LNoeudFeatures [$RId selectNodes //fitem/*]
    foreach n $LNoeudFeatures {
	set f [$n selectNodes name(.)]
	lappend ListeItemFeatures $f
    }
    set ListeItemFeatures [lsort -unique $ListeItemFeatures]

    return $ListeItemFeatures
}



proc ExtraitLesDescriptifs {id aLDes} {

    global LNOrdali
    global TDesDescriptifs

    set TDesDescriptifs {}
    set RId [$id documentElement]

    set TDesDescriptifs {}
    foreach n $LNOrdali {
	set qds "//*\[string(seq-name)='$n'\]/descendant::*\[name()='definition'\]"
	set nds [$RId selectNodes "$qds"]
	if {$nds != ""} {
	    set d [$nds selectNodes string(.)]
	    set TDesDescriptifs($n) $d
	}
    }

    return
}



proc ExtraitLesTaxId {id aLTax} {

    global LNOrdali
    upvar $aLTax LesTaxId

    set LesTaxId {}
    set RId [$id documentElement]

    set LClass [list eukaryota archaea bacteria viruses]
    foreach n $LNOrdali {
	if {[regexp {^[0-9]} $n]} {continue}
	set tid ""
	set qds "//*\[string(seq-name)='$n'\]/descendant::*\[name()='lifedomain'\]"
	set nds [$RId selectNodes "$qds"]
	if {$nds != ""} {
	    set tid [string tolower [$nds selectNodes string(.)]]
	    if {[lsearch $LClass $tid] == -1 || $tid == ""} {set tid "undefined"}
	    lappend LesTaxId ${tid}
	} else {
	    lappend LesTaxId "undefined"
	}
    }

    return $LesTaxId
}



proc ExtraitLesPoidsDuXML {id aLWgt} {
    global LNOrdali
    upvar $aLWgt LnonesPoidsDesSeqs

    set RId [$id documentElement]

    set LesPoidsDesSeqs {}
    foreach n $LNOrdali {
	if {$n eq ""} {
	    continue
	}
	set qds "//*\[string(seq-name)='$n'\]/descendant::*\[name()='weight'\]"
	set nds [$RId selectNodes "$qds"]
	if {$nds != ""} {
	    set d [$nds selectNodes string(.)]
	    lappend LesPoidsDesSeqs $d
	}
    }

    return $LesPoidsDesSeqs
}



proc ExtraitLeGroupeDesSeqs {id aLGS} {

    global LNOrdali
    upvar $aLGS LeGroupe

    set LeGroupe {}
    set RId [$id documentElement]

    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n eq ""} {continue}
	if {[EstUnAccessPDB $n]} {set n [EnlevePrefixeBank $n]}
	set qds "//*\[string(seq-name)='$n'\]/descendant::*\[name()='group'\]"
	set nds [$RId selectNodes "$qds"]
	if {$nds ne ""} {
	    set d [[lindex $nds 0] selectNodes string(.)]
	    lappend LeGroupe $d
	}
    }

    return $LeGroupe
}



proc TabFeaturesDesSeqs {id aTab} {

    upvar $aTab tb
    global LNOrdali

    set RId [$id documentElement]
    ExtraitListeItemFeatures $id LItemFeat
    set tb(Items) $LItemFeat

    foreach n $LNOrdali {
	set query "//*\[string(seq-name)='$n'\]/descendant::*\[name()='fitem'\]"
	set lneitem [$RId selectNodes "$query"]
	set tb($n) {}
	foreach f $lneitem {
	    set ValI {}
	    foreach i $LItemFeat {
		set nfi [$f selectNodes "./$i"]
		set val [$nfi selectNodes string(.)]
		set val [string map {" " "_"} $val]
		lappend ValI $val
	    }

	    lappend tb($n) $ValI
	}
    }

    return
}



proc DonneTabFeatureDuRsf {aTab} {
    upvar $aTab tb
    global LNOrdali Couleurs Defauts

    FaireAttendre "Please wait ...\nRetrieving feature from RSF file ..."

    set LFS [array names tb "*,Type,*"]

    set csys "global" ; set score 0.0 ; set note ""
    foreach f $LFS {
	set ln [split $f ","]
	set ln [lreplace $ln 1 1]
	set nom [join $ln ","]
	foreach l [set tb($f)] {
	    scan $l "%d %d %d %d %s %s %s" dg fg ds fs col form style
	    set nl [list fstart $dg fstop $fg fcolor $col fscore $score fnote $note fcsys $csys]
	    lappend Ttmp($nom) $nl
	}
    }

    unset -nocomplain tb
    array set tb [array get Ttmp]

    FaireLaSuite .tabf

    return
}


proc DonneTabFeature {aTab} {
    global ListeTypesDeFeatures Defauts LNOrdali LSOrdali TDuGroupeDesSeqs LesSeqsDuGroupe
    upvar $aTab tbf

    #################
    # 
    # !! ATTENTION !!
    # 
    # On prend maintenant les positions 
    # fstart et fstop TELLES QUELLES (position dans
    # la sequence ou pas, et commencent a 1). On transforme 
    # en position absolues quend on cree une vue
    # 
    #################

    # record features to be propageted, according
    # to the target attribute
    set Lall {} ; set Lgrp {}
    set ListeTypesDeFeatures {}
    foreach nom $LNOrdali seq $LSOrdali {
	if {! [info exists tbf($nom)]} {
	    #puts ">>> NO information for $nom"
	    continue
	}

	set lgt [string length [string map {"." ""} $seq]]
	foreach i [set tbf($nom)] {
	    foreach {f v} $i {
		switch $f {
		    "target" {set g $v}
		    "coords" {set y $v}
		    "ftype"  {set t $v}
		    "fstart" {set s $v}
		    "fstop"  {set e $v}
		    "fcolor" {
			if {[string is integer  $v]} {
			    set c [CouleurDuStock $v]
			}  else {
			    set c $v
			}
		    }
		    "fscore" {set r $v}
		    "fnote"  {set n $v}
		    default {lappend nl $f $v}
		}
	    }
	    if {$t eq "STRUCT"} {
		if {[string first "HELIX" $n] >= 0} {
		    set c "red"
		} elseif {[string first "STRAND" $n] >= 0} {
		    set c "green"
		}
	    }
	    if {$t eq "Discri"} {incr nbdiscri}

	    # ERRORS in Macsim
	    # 1 - start/stop should not be empty !!
	    if {$e eq "" || $s eq ""} {
		puts "Error while reading XML ! start ou stop vide !"
		continue
	    }
	    # 2 - stop > start !
	    if {$e < $s} {
		puts "Error while reading XML ! $nom $t | start > stop : $s $e"
		continue
	    }
	    # 3 - start and stop < length
	    if {$y eq "local"} {
		if {$e > $lgt || $s > $lgt} {
		    puts "Error while reading XML ! $nom $t | start or stop > length : $s $e - $lgt"
		    continue
		}
	    }

	    set nl [list fstart $s fstop $e fcolor $c fscore $r fnote $n fcsys $y target $g]
	    switch $g {
		"all"   {lappend Lall $nom $t $nl}
		"group" {lappend Lgrp $nom $t $nl}
	    }

	    lappend tbf(${nom},$t) $nl
	    lappend ListeTypesDeFeatures $t
	}
    }

    set ListeTypesDeFeatures [lsort -unique $ListeTypesDeFeatures]

    # propagete some feature to all seqs
    if {$Lall != {}} {
	foreach {n type ft} $Lall {
	    foreach nseq $LNOrdali {
		if {$nseq eq ""} {continue}
		if {$n eq $nseq} {continue}
		
		lappend tbf($nseq,$type) $nl
	    }
	}
    }

    # propagate some features to the group of seqs
    if {$Lgrp != {} } {
	foreach {n type ft} $Lgrp {
	    set grp [set TDuGroupeDesSeqs($n)]
	    foreach ns $LesSeqsDuGroupe($grp) {
		if {$n eq $ns} {
		    continue
		}
		
		lappend tbf($ns,$type) $ft
	    }
	}
    }

    return
}


proc DecortiqueUnXml2 {FichierOuTexteXML} {
    global LNDG SDG
    global LesSeqsDuGroupe
    global LNOrdali Sequences TDesSeqnames
    global TDuGroupeDesSeqs
    global TabSF
    global NoeudMacsim DocMacsim
    global AlnName AlnScore AlnNote TColScore

    if {[file exists $FichierOuTexteXML]} {
	set MacsimXml [ContenuDuFichier $FichierOuTexteXML]
	set FromOrdalie 1
    } else {
	set MacsimXml $FichierOuTexteXML
	set FromOrdalie 0
    }
    
    # Caution !!
    # MacsimXml is not a list, but a text string !!
    set DocMacsim   [dom parse $MacsimXml]
    set NoeudMacsim [$DocMacsim documentElement]
    
    # Initialise arrays for features
    InitInfoArrays

    unset -nocomplain LesSeqsDuGroupe ::LabelDuGroupeDeLaSeq
    
    # alignment header
    set NoeudAli [$NoeudMacsim selectNodes "alignment"]
    set AlnName  [$NoeudAli selectNodes "string(aln-name)"]
    set AlnScore [$NoeudAli selectNodes "string(aln-score)"]
    set AlnNote  [$NoeudAli selectNodes "string(aln-note)"]
    set TColScore(Names) {}
    foreach NoeudLigne [$NoeudAli childNodes] {
	set NodeName [$NoeudLigne nodeName]
	if {[string first "aln\-" $NodeName] >= 0} {
	    continue
	}
	if {[string first "column\-" $NodeName] >= 0} {
	    DecortiqueColumnScore $NoeudLigne
	} else {
	    DecortiqueNoeudXml $NoeudLigne TabSF
	}
    }
    
    # check duplicated sequences
    set Ltmp $LNOrdali
    set LNOrdali {}
    foreach n $Ltmp {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}
	lappend LNOrdali $n
    }

    if {[llength $LNOrdali] != [llength [lsort -unique $LNOrdali]]} {
	set ld [DonneDoublons $LNOrdali]
	FaireLire "Beware !\nSeveral sequences have the same name :[join $ld]"
    }

    # premier grp = GroupeToutLeMonde
    InitPremierGroupe
    
    # Add groups taken from XML
    set Lg [ReordonneGroupes [array names LesSeqsDuGroupe]]
    if {[llength $Lg] > 1} {
	set LNDG [concat $LNDG $Lg]
	foreach g $Lg {
	    set LesSeqsDuGroupe($g) [lunique [set LesSeqsDuGroupe($g)]]
	    set SDG($g) [set LesSeqsDuGroupe($g)]
	}
	# labels of the groups (grouplabel)
	foreach {n label} [array get ::LabelDuGroupeDeLaSeq] {
	    set g [set TDuGroupeDesSeqs($n)]
	    if {$g ne "Group0" && [info exists SDG($g)]} {
		set SDG(Equiv,$g) $label
	    }
	}
    }
    unset -nocomplain ::LabelDuGroupeDeLaSeq

    $NoeudMacsim delete
    $DocMacsim delete
    unset -nocomplain DocMacsim NoeudMacsim

    return 1
}


proc DecortiqueNoeudXml {Noeud aTab} {
    upvar $aTab tb
    global {*}[info globals "TD*"] Defauts LesSeqsDuGroupe SDG ListeItemFeatures Sequences LNOrdali 

    set ListLifeD $Defauts(LifeDomains)
    set LClass [list eukaryota archaea bacteria viruses]
    
    set NoeudSeqAli $Noeud
    
    set SeqNameOri [$NoeudSeqAli selectNodes "string(seq-name)"]
    set SeqName [BonAccess $SeqNameOri "AsIs"]
    set SeqData [$NoeudSeqAli selectNodes "string(seq-data)"]
    set SeqData [BonneSequencePourAlignement $SeqData]
    if {$SeqData eq ""} {
	puts "\n>$SeqName< is an empty sequence !"
	return
    }
    
    set TDesSeqnamesOri($SeqName) $SeqNameOri
    set TDesSeqnames($SeqName) $SeqName
    lappend LNOrdali $SeqName
    set Sequences($SeqName) $SeqData

    set NoeudInfos [$NoeudSeqAli selectNodes "seq-info"]
    set LifeD "undefined"
    foreach NoeudInfo [$NoeudInfos childNodes] {
	set NodeName [$NoeudInfo nodeName]
	set v [$NoeudInfo selectNodes "string()"]
	switch $NodeName {
	    "accession" {
		# NCBI:
		# access = NM_xx, XP_XXX
		# UniProt
		# access = P123456
		set bonac [BonAccess $v]
		set ACisGI [EstUnGI $bonac]
		set ACisIDUni [EstUnIdUniprot $bonac]
		set TDesAccess($SeqName) $bonac
	    }
	    "nid" {
		# NCBI:
		# id = 548745
		# UniProt:
		# id = SYHM_AQUAE
		set bonid [BonAccess $v]
		set IDisACRefseq [EstUnRefseq $bonid]
		set IDisAcUni [EstUnAccUniProt $bonid]
		set TDesBId($SeqName) $bonid
	    }
	    "lifedomain" {
		set LifeD [string totitle $v]
		if {$LifeD ni $ListLifeD} {set LifeD "undefined"}
		set TDesPhylum($SeqName) $LifeD
	    }
	    "organism" {
		set GenreEspece [string map {"." " "} $v]
		set TDesOrganismes($SeqName) $GenreEspece
		regsub -all { +} $GenreEspece " " GenreEspece
		lassign [split $GenreEspece " "] Genre Espece
		#set Genre [lindex $Lgs 0]
		#set Espece [lindex $Lgs 1]
		set TDesGS($SeqName) "[string range $Genre 0 3].[string range $Espece 0 3]"
	    }
	    "taxid" {
		set TDesTaxId($SeqName) $v
	    }
	    "definition" {
		set TDesDescriptifs($SeqName) $v
	    }
	    "length" {
		set TDesLength($SeqName) $v
	    }
	    "group" {
		set g "Group$v"
		lappend LesSeqsDuGroupe($g) $SeqName
		set TDuGroupeDesSeqs($SeqName) $g
	    }
	    "grouplabel" {
		# group of the sequence may come later : see DecortiqueUnXml2
		set ::LabelDuGroupeDeLaSeq($SeqName) [string trim $v]
	    }
	    "keywordlist" {
		foreach NoeudKeywordList [$NoeudInfo selectNodes "string(keywordlist)"] {
		    foreach NoeudKeyword [$NoeudKeywordList childNodes] {
			set Keyword [$NoeudKeyword selectNodes "string()"]
		    }
		}
	    }
	    "lineage" {
		set NoeudLin $NoeudInfo
		set Lt {}
		foreach n [$NoeudLin selectNodes "taxon"] {
		    lappend Lt [$n selectNodes string()]
		}
		if {$Lt != {} } {
		    set TDuLineage($SeqName) $Lt
		}
	    }
	    "goxreflist" {
		set NoeudGO $NoeudInfo
		set Lv {}
		foreach NG [$NoeudGO selectNodes "goxref"] {
		    set LNoeudG [$NG childNodes]
		    foreach n $LNoeudG {
			set f [$n selectNodes name(.)]
			set v [$n selectNodes string()]
			lappend Lv [list $f $v]
		    }
		}
		if {$Lv != {}} {
		    set TDesGO($SeqName) $Lv}
	    }
	    "ftable" {
		set NoeudFtable $NoeudInfo
		set tb($SeqName) {}
		foreach NF [$NoeudFtable selectNodes "fitem"] {
		    set LNoeudFeatures [$NF childNodes]
		    set coords [$NF getAttribute coords local]
		    set target [$NF getAttribute target seq]
		    set Lv {}
		    lappend Lv "coords" $coords "target" $target
		    foreach n $LNoeudFeatures {
			set f [$n selectNodes name(.)]
			set v [$n selectNodes string()]
			set v [string map {" " "_"} $v]
			lappend Lv $f $v
			if {$v eq "Discri"} {incr ::nbDiscri}
		    }
		    lappend tb($SeqName) $Lv
		}
	    }
	    "ec" {
		set TDesEC($SeqName) $v
	    }
	    "status" {
		set TDesStatus($SeqName) $v
	    }
	    "complex" {
		set TDesComplex($SeqName) $v
	    }
	    "weight" -
	    "molecularweight" {
		set TDesMolW($SeqName) $v
	    }
	    "sense" {
		set TDesSense($SeqName) $v
	    }
	    "fragment" {
		set TDesFragment($SeqName) $v
	    }
	    "score" {
		set TDesScore($SeqName) $v
	    }
	    "hydrophobicity" {
		set TDesHydro($SeqName) $v
	    }
	    "isoelectricpoint" {
		set TDespI($SeqName) $v
	    }
	    default {
		set Info $v
	    }
	}
    }

    # Change Acc/Id if necessary
    if {$ACisGI || $IDisACRefseq || $IDisAcUni || $ACisIDUni} {
	# invert the two for compatibility with UniProt
	set tmp $TDesAccess($SeqName)
	set TDesAccess($SeqName) $TDesBId($SeqName)
	set TDesBId($SeqName) $tmp
    }
    
    if {! [info exists TDuGroupeDesSeqs($SeqName)]} {
	set g "Group0"
	lappend LesSeqsDuGroupe($g) $SeqName
	set TDuGroupeDesSeqs($SeqName) $g
    }

    return
}


proc DecortiqueColumnScore {NoeudCol} {
    global TColScore
    
    # Store column-score name in TColScore(Names)
    # For a given name (i.e. normd) create list of lists:
    # TColScore(normd,Group) list of groups
    # TColScore(normd,Owner) list of owners of the data
    # TColScore(normd,Data) List of data attached to each group
    # TColScore(normd,Type) list of data types
    # 
    # the group 'all' stands for all sequences
    #

    set name [$NoeudCol selectNodes "string(colsco-name)"]
    # special case :
    # macsim names should be trucated after '_'
    # An empty suffix (trailing '_') comes from files
    # saved with an empty owner : strip it too.
    set suf [string range $name [string last "_" $name]+1 end]
    if {$suf eq "all" || $suf eq "" || [string is integer -strict $suf]} {
	set name [string range $name 0 [string last "_" $name]-1]
    }
    if {$name ni $TColScore(Names)} {
	lappend TColScore(Names) $name
    }

    lappend TColScore($name,Owner) [$NoeudCol selectNodes "string(colsco-owner)"]
    lappend TColScore($name,Type) [$NoeudCol selectNodes "string(colsco-type)"]
    set cgrp ""
    catch {set cgrp [$NoeudCol selectNodes "string(colsco-group)"]}
    lappend TColScore($name,Group) $cgrp
    lappend TColScore($name,Data)  [$NoeudCol selectNodes "string(colsco-data)"]

    return
}


proc IndexationParAccess {} {
    global {*}[info globals "TD*"] LesSeqsDuGroupe SDG ListeItemFeatures Sequences LNOrdali TabSF

    # Verifie qu'on a un access/bid pour tout le monde
    foreach n [lunique $LNOrdali] {
	if {! [info exists TDesAccess($n)]} {
	    set TDesAccess($n) $n
	}
	if {! [info exists TDesBId($n)]} {
	    set TDesBId($n) $n
	}
    }

    # et que les access ne sont pas en double
    set Lacc {}
    foreach n [lunique $LNOrdali] {
	lappend Lacc [set TDesAccess($n)]
    }
    set l1 [lsort $Lacc]
    set l2 [lsort -unique $Lacc]
    if {[llength $l1] != [llength $l2]} {
	FaireLire "Beware !\nThere are duplicated access, Ordalie may not work properly :\n[join [lor $l1 $l2] " "]"
    }

    # idem pour groupes <-> sequences
    foreach a [array names LesSeqsDuGroupe] {
	set Ls [set LesSeqsDuGroupe($a)]
	unset LesSeqsDuGroupe($a)
	foreach s $Ls {
	    if {$s eq "" || [EstUnAccessPDB $s]} {
		lappend LesSeqsDuGroupe($a) $s
	    } else {
		lappend LesSeqsDuGroupe($a) [set TDesAccess($s)]
	    }
	}
    }

    # Tableau des sequences aa
    foreach a [array names Sequences] {
	set s [set Sequences($a)]
	unset Sequences($a)
	set Sequences([set TDesAccess($a)]) $s
    }

    # et pour les pre-features
    foreach a [array names TabSF] {
	set v [set TabSF($a)]
	unset TabSF($a)
	set TabSF([set TDesAccess($a)]) $v
    }

    # Et pour tous les tableaux
    set Ltmp [lunique $LNOrdali]
    set LNOrdali {}
    foreach sqn $Ltmp {
	set acc [set TDesAccess($sqn)]
	lappend LNOrdali $acc

	foreach t [info globals "TD*"] {
	    if {! [info exists ${t}($sqn)]} {continue}
	    set r [set ${t}($sqn)]
	    unset ${t}($sqn)
	    set ${t}($acc) $r
	}
    }

    return
}


proc CreeLeXml {{filout ""} {Degap ""}} {
    global OrdEtcDir tcl_platform DocMacsim NoeudMacsim IdXml

    if {$filout eq ""} {
	set filout [DemandeEtSauveFichier xml 1]
    }
    if {$filout eq ""} {
	return
    }

    lassign [SequencesASauver] LNoms LSeqs
    if {$LNoms == {} || $LSeqs == {}} {
	return
    }

    Annotations2Features
    CreeLeMacsim $filout $LNoms $LSeqs
    RemoveAnnotationFeatures

    return
}



proc MetAJourArbreXml {} {
    global Sequences
    global LNOrdali
    global TabSF
    global NoeudMacsim
    global LNDG
    global SDG

    set RId $NoeudMacsim

    # Met a jour sequences

    set Lseq [$RId selectNodes //seq-name]
    set Ldat [$RId selectNodes //seq-data]
    foreach n $Lseq d $Ldat {
	set s [$n selectNodes string(.)]
	set ix [lsearch $LNOrdali $s]
	if {$ix == -1} {
	    set p [$n parentNode]
	    $p delete
	} else {
	    if {[regexp {^PDB_[0-9]} $s]} {
		set s [string range $s 4 7]
	    }
	    set seq [set Sequences($s)]
	    set seq [string map {"\." "-"} [string tolower $seq]]
	    set nodes [$d selectNodes text()]
	    set d [lindex $nodes 0]
	    $d nodeValue $seq
	}
    }

    # Met a jour groupes

    foreach g $LNDG {
	if {$g eq "grise"} {continue}
	if {$g eq "GroupeToutLeMonde"} {continue}
	set i [string range $g 5 end]
	foreach s [set SDG($g)] {
	    set qds "//*\[string(seq-name)='$s'\]/descendant::*\[name()='group'\]"
	    set nds [$RId selectNodes "$qds"]
	    foreach n $nds {
		set nodes [$n selectNodes text()]
		set n [lindex $nodes 0]
		$n nodeValue $i
	    }
	}
    }

    return

    # Met a jour features
    array set TF [array get TabSF]

    foreach nm $LNOrdali {
	set qds "//*\[string(seq-name)='$nm'\]/descendant::*\[name()='fitem'\]"
	set Lnds [$RId selectNodes "$qds"]
	foreach n $Lnds {
	    set qri "./*\[name()='ftype'\]"
	    set nft [$n selectNodes $qri]
	    set ft [$nft selectNodes string(.)]
	    set Lfta [set TF($nm,$ft)]
	    set f [lindex $Lfta 0]
	    DecortiqueUneFeature $f dg fg col score note
	    set nx1 [$n selectNodes "./fstart/text()"]
	    $nx1 nodeValue $dg
	    set nx2 [$n selectNodes "./fstop/text()"]
	    $nx1 nodeValue $fg
	    set TF($nm,$ft) [lreplace [set TF($nm,$ft)] 0 0]
	}
    }

    return
}


proc XML4Macsim {f} {
    set Ll [LesLignesDuFichier $f]
    set o [open $f w]
    foreach l $Ll {
	if {! [regexp {goxref|goid|goclass|molecularweight|isoelectric} $l]} {
	    puts $o $l
	}
    }
    close $o

    return
}



