


#
# ordali_db.tcl
#

proc DBProfile {s t} {
    global TPS

    regsub -all "," $s " " s
    regsub -all {\(|\)} $s " " s
    regsub -all { +} $s " " s
    set l [split $s " "]
    switch [lindex $l 0] {
	"begin" {
	    incr TPS($s,fois)
	    incr TPS($s,time) $t
	    lappend TPS($s,sql) $s
	}
	"select" {
	    set ifrom [lsearch $l "from"]
	    set iwhere [lsearch $l "where"]
	    set lt [lrange $l [expr {$ifrom+1}] [expr {$iwhere-1}]]
	    set ias [lsearch -all $lt "as"]
	    foreach i $ias {
		lappend tb [lindex $lt [expr {$i-1}]]
	    }
	    incr TPS(select,[join $tb "-"],fois)
	    incr TPS(select,[join $tb "-"],time) $t
	    lappend TPS(select,[join $tb "-"],sql) $s
	}
	"insert" {
	    set tb [lindex $l 2]
	    incr TPS(insert,$tb,fois)
	    incr TPS(insert,$tb,time) $t
	    lappend TPS(insert,$tb,sql) "$s"
	}
    }

    return
}


proc FinDBProfile {} {
    global TPS

    if {! [info exists TPS]} {
	return
    }

    foreach v [array names TPS "*,fois"] {
	set i [join [lrange [split $v ,] 0 end-1] ,]
	set res [expr {1.0*[set TPS($i,time)]/[set TPS($v)]}]
	set sql [lsort -unique [set TPS($i,sql)]]
	lappend LR [list $i [set TPS($v)] $res $sql]
    }

    set LR [lsort -real -index 2 $LR]
    puts "\n== PROFILING DB ==="
    puts "==================="
    foreach e $LR {
	lassign $e s i t q
	puts ""
	puts [format "%s %d %10.1f %s" $s $i $t $q]
    }

    return
}


proc DbProfile {sql time} {
    global TTimeSql TSqlTime
    set TTimeSql($time) $sql
    set TSqlTime($sql) $time
}


proc RemplitOrdaliDB {} {
    global LNOrdali LSOrdali
    global {*}[info globals "TD*"]
    global TabSF CompteurDeMac db Defauts LNDG SDG TColScore ListeTypesDeFeatures

    $db eval "PRAGMA synchronous = OFF"
    #$db eval "PRAGMA cache_size = 100000"
    #$db eval "PRAGMA journal_mode = MEMORY"
    $db eval "PRAGMA journal_mode = OFF"
    $db eval "PRAGMA temp_store = memory"
    $db eval "PRAGMA mmap_size = 30000000000"
    #$db profile DbProfile
    $db transaction {
    #$db profile DBProfile

    # Met A Jour table des parametres Ordalie
    set var "Defauts"
    foreach {k v} [array get Defauts] {
	$db eval {insert into ordalie values ($var, $k, $v)}
    }

    # Met A Jour :
    # - table des INFOS de sequences
    # - table des sequences elles-memes origine
    set i 1
    foreach n $LNOrdali s $LSOrdali {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}

	set ins "$i"
	foreach t {TDesSeqnames TDesAccess TDesBId TDesDescriptifs TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesPhylum TDesGO TDuLineage TDesHydro TDespI TDesMolW} {
	    set v [set ${t}($n)]
	    if {! [string is integer -strict $v] && ! [string is double -strict $v]} {
		if {$v eq ""} {
		    lappend ins "NULL"
		} else {
		    set v [string map {"'" "''"} $v]
		    lappend ins "'$v'"
		}
	    } else {
		lappend ins $v
	    }
	}
	set sdegap [string map {"." "" " " ""} $s]
	lappend ins "'$sdegap'"
	
	$db eval "insert into seqinfo values ([join $ins ,])"
	set sqn [set TDesSeqnames($n)]
	$db eval {insert into seqali values ($i, $i, $sqn, $s)}
	incr i
    }
    }

    # Met A Jour table des features
    # on a TabSF, copie conforme des features
    # du XML. On copie tel quel dans seqfeat
    array set TAnno {}
    if {[info exists TabSF]} {
	if {"SnapAnnotation" in $ListeTypesDeFeatures} {
	    array set TAnno [array get TabSF "*,SnapAnnotation"]
	    RemoveAnnotationFeatures
	}
	# features du 1er snapshot (original alignment)
	MetAJourTableFeatures 1
    } else {
	set TabSF {}
    }

    # Met A Jour table mac.
    ##########a###########
    #
    # 1er MAC : initial mac, never be touched
    #
    #####################
    set pkm 1
    set titre "M[NumeroNewMac] - original alignment"
    LesDefauts IxMacCourant $pkm
    LesDefauts NmMacCourant $titre

    $db transaction {

    set Lx [$db eval {select pk_seqali from seqali order by pk_seqali}]

    $db eval {insert into snapshot values ($pkm, $titre,'original alignment')}

    set pos 0
    set i 1
    set Linsert {}
    foreach s $Lx {
	# seqali premier mac deja remplit
	lappend Linsert "($pkm,$s,$pos)"
	#$db eval {insert into ln_snapshot_seqali values ($pkm,$s,$pos)}
	incr pos
    }
    $db eval "insert into ln_snapshot_seqali values [join $Linsert ,]"

    # Clustering associe au 1 mac ne contient pas
    # de cluster, ( 1 seul groupe : toutlemonde )
    # pk_clustering
    set pk_Clg 1
    # pk_cluster
    set pk_Cst 1
    $db eval {insert into clustering values($pk_Clg, $pkm, 'None', NULL, NULL)}
    $db eval {insert into cluster values($pk_Cst, $pk_Clg, 'all', NULL)}
    set pos 0
    set Linsert {}
    foreach i $Lx {
	#$db eval {insert into ln_seqali_cluster values ($i,$pk_Cst,$pos)}
	lappend Linsert "($i,$pk_Cst,$pos)"
	incr pos
    }
    $db eval "insert into ln_seqali_cluster values [join $Linsert ,]"

    # Add annotations
    Features2Annotations [array get TAnno]

    ################
    #
    # 2eme mac
    #
    # XML   : correspond au clustering du macsim
    # Autre : working alignment
    ################
    incr pkm
    if {[TypeAli] eq "XML"} {
	set titre "M$pkm - macsims alignment"
	set name "macsim alignment"
    } else {
	set titre "M$pkm - working alignment"
	set name "working alignment"
    }
    LesDefauts IxMacCourant $pkm
    LesDefauts NmMacCourant $titre

    $db eval {insert into snapshot values ($pkm, $titre,$name)}
    set pos 0
    foreach s $Lx {
	$db eval {insert into ln_snapshot_seqali values ($pkm, $s, $pos)}
	incr pos
    }
    # memes features que le 1er snapshot
    $db eval {insert into ln_seqali_featali select pk_seqali, pk_featali, $pkm from ln_seqali_featali where pk_snap=1}

    incr pk_Clg ; # clustering
    incr pk_Cst ; # cluster

    if {[TypeAli] eq "XML"} {
	$db eval {insert into clustering values($pk_Clg,$pkm, 'macsim clustering', 'macsims', 'all')}
    } else {
	$db eval {insert into clustering values($pkm,$pk_Clg, 'whole alignment', 'whole', 'all')}
    }
    foreach g $LNDG {
	if {$g eq "bidon"} {
	    continue
	}
	if {$g eq "grise"} {
	    continue
	}
	
	set Lix [LesIndexsDesSeqnames [set SDG($g)]]
	# name given by "Clusters Names"
	set label [expr {[info exists SDG(Equiv,$g)] && $SDG(Equiv,$g) ne $g ? $SDG(Equiv,$g) : ""}]
	if {$g eq "GroupeToutLeMonde"} {
	    set g "all"
	}
	$db eval {insert into cluster values($pk_Cst, $pk_Clg, $g, nullif($label,''))}
	set pos 0
	foreach i $Lix {
	    $db eval {insert into ln_seqali_cluster values ($i,$pk_Cst,$pos)}
	    incr pos
	}
	incr pk_Cst
    }

    set pk_snap [$db eval {select max(pk_snap) from snapshot}]
    set CompteurDeMac $pk_snap

    # Add annotations if any
    Features2Annotations [array get TAnno]

    # Met A Jour conservation/colscores
    if {[info exists TColScore]} {
	foreach name $TColScore(Names) {
	    if {$name eq "(null)"} {
		continue
	    }

	    $db eval {insert into colmeasure values (NULL,$pk_snap,$name,NULL)}
	    set pk_meas [$db last_insert_rowid]
	    foreach owner $TColScore($name,Owner) type $TColScore($name,Type) data $TColScore($name,Data) group $TColScore($name,Group) {
		regsub -all { +} [string trim $data] " " data
		set data [string map {" " ","} $data]
		if {$data eq ""} {
		    continue
		}
		$db eval {insert into colscore values (NULL, $pk_meas, $name, $owner, $type, $group, $data)}
		set pkc [$db last_insert_rowid]
		if {$owner ne "all" && $owner ne "All"} {
		    if {! [string is integer $owner]} {
			set suf [string last "_" $owner]
			if {$suf > -1} {
			    set g "Group[string range $owner $suf+1 end]"
			} else {
			    set g [string totitle $owner]
			}
		    } else {
			set g "Group$owner"
		    }
		} else {
		    set g $owner
		}

		set pkg [$db eval {select pk_cluster from cluster where name=$g and pk_clustering=$pk_Clg}]
		$db eval {insert into ln_cluster_colscore values ($pkg, $pkc)}
	    }
	}
    }

    # Creation des Index
    $db eval {create index idx_seqinfo on seqinfo (pk_seqinfo, seqname, access)}
    $db eval {create index idx_seqali on seqali (pk_seqali, pk_seqinfo, seqname, seq)}
    $db eval {create index idx_ln_seqali_featali on ln_seqali_featali (pk_snap, pk_seqali, pk_featali)}
    $db eval {create index idx_featali on featali (pk_featali, ftype, fstart, fstop, fscore, fnote, fcsys)}
    $db eval {create index idx_ln_snapshot_seqali on ln_snapshot_seqali (pk_snap, pk_seqali)}
    $db eval {create index idx_cluster on cluster (pk_cluster, pk_clustering, name)}
    $db eval {create index idx_ln_seqali_cluster on ln_seqali_cluster (pk_seqali, pk_cluster, pos)}
    #$db eval {create index idx_pdb on pdb (pk_pdb, name, header)}
    #$db eval {create index idx_chaines on chains (pk_chains, pk_pdb, name, type)}
    #$db eval {create index idx_residues on residues (pk_residues, pk_pdb, pk_chains, rname1l, rname3l, rnbr, type)}
    #$db eval {create index idx_atomes on atoms (pk_atoms, pk_pdb, pk_chains, pk_residues, aname, x, y, z, na)}

    # Remplissage Termine !
    }

    CreeVue

    return
}


proc CreeLeOrd_old {{f ""}} {
    if {$f eq ""} {
	if {$::Defauts(FichierOBK) eq ""} {
	    file tempfile Defauts(FichierOBK)
	}
	set f $::Default(FichierOBK)
    }
    $::db eval {vacuum}
    $::db backup $f

    return
}


######################################
###
###  QUELQUES REGLES POUR BASE ORDALIE
###
### - nom    : c'est le nom de scene , le nom AFFICHE
### - access : c'est le veritable access, au sens db
###
######################################

proc UpdateFromOrdaliDB {} {
    global {*}[info globals "TD*"]
    global ListeDesFragments
    global db CompteurDeMac Defauts

    $db transaction {

    # Parametres Ordalie
    set Lkv [$db eval {select * from ordalie}]
    set Lt [$db eval {select distinct(var) from ordalie}]
    global {*}$Lt
    # options of the command line (-script) and the state of this
    # session (batch mode of msaconvert, msacut, msainfo..., path of
    # the file opened) are not replaced by the values saved in the file
    set Lcmd {}
    foreach k {RunScript Script Mode Exit LogAtStartup FichierORD} {
	if {[info exists Defauts($k)]} {
	    lappend Lcmd $k $Defauts($k)
	}
    }
    foreach {t k v} $Lkv {
	# overviews of files saved before : their windows are not
	# restored
	if {$t eq "Ovw"} {
	    continue
	}
	set ${t}($k) $v
    }
    array set Defauts $Lcmd
    # never restored : PDB excluded unless "include PDB" is checked
    set Defauts(PDBDansPilier) 0
    # the state of the tools (trees, cluster, conservation,
    # annotation...) is not saved : an ORD saved while one of
    # them was open is displayed in the main view
    if {$Defauts(dispmode) ni {"ordali" "feature"}} {
	set Defauts(dispmode) "feature"
    }
    # alignment name/score/note saved by CreeLeORD
    foreach k {Name Score Note} {
	if {[info exists ::AlnInfo($k)]} {
	    set ::Aln$k $::AlnInfo($k)
	}
    }
    LesDefauts TypeAli ORD
    InitInfoArrays
    global {*}[info globals "TD*"]
    
    set Li [$db eval {select * from seqinfo}]
    set Ln [$db eval {select seqname from seqinfo}]
    set i 0 ; set k 0
    while {$i < [llength $Li]} {
	set Lval [lrange $Li $i $i+17]
	set n [lindex $Ln $k]
	foreach t {tmp TDesSeqnames TDesAccess TDesBId TDesDescriptifs TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesPhylum TDesGO TDuLineage TDesHydro TDespI TDesMolW tmp} v $Lval {
	    if {$t eq "tmp"} {
		continue
	    }
	    set ${t}($n) $v
	}
	incr i 18
	incr k
    }

    set ListeDesFragments {}
    foreach k [array names TDesFragment] {
	if {[set TDesFragment($k)]} {
	    lappend ListeDesFragments $k
	}
    }

    }

    set pkm $Defauts(IxMacCourant)
    set nom $Defauts(NmMacCourant)
    # next instance number : after the highest one (not the
    # current one : its name would already exist)
    set CompteurDeMac [$db eval {select max(pk_snap) from snapshot}]
    foreach m [LesMacs] {
	if {[regexp {^M([0-9]+) } $m tmp n] && $n > $CompteurDeMac} {
	    set CompteurDeMac $n
	}
    }

    CreeVue

    # infos not stored in seqinfo : rebuild them as
    # when reading a MACSIM file
    global TDesSeqnames TDesSeqnamesOri TDesOrganismes TDesGS
    CalculeLength
    foreach n [array names TDesSeqnames] {
	if {! [info exists TDesSeqnamesOri($n)] || $TDesSeqnamesOri($n) eq ""} {
	    set TDesSeqnamesOri($n) $n
	}
	if {[info exists TDesOrganismes($n)]} {
	    set GenreEspece [string map {"." " "} $TDesOrganismes($n)]
	    regsub -all { +} $GenreEspece " " GenreEspece
	    lassign [split $GenreEspece " "] Genre Espece
	    set TDesGS($n) "[string range $Genre 0 3].[string range $Espece 0 3]"
	}
    }
    # type of sequences (protein/DNA), as InitSequences does.
    # The residues mapping is restored with the Defauts.
    unset -nocomplain ::TypeSeq
    DefinitTypeAlignement

    CreatePDBFromDB
    TraitePDBDeLAlignement
    # index of the structures for the 3D viewer (method render),
    # set when a structure is read : not done for the ones
    # rebuilt from the ORD
    global HashPDB
    foreach e $::ListePDB {
	set mol [DonneIdDeAccessPDB $e]
	if {! [info exists HashPDB($mol)]} {
	    set iH $HashPDB(iHmax)
	    set HashPDB($mol) $iH
	    set HashPDB($iH) $mol
	    set HashPDB(iHmax) [incr iH]
	}
    }
    InfosDesPDB

    TraiteAABizarres

    if {! $::Defauts(IsGenome)} {
	# compositions are not stored in the ORD (Sequences
	# Information window, log, copy of a sequence)
	CalculeComposition 1
	#CalculeMolecularWeight

	LogSeqInfoGlobales
	LogLesCompositions
    }

    # trees and overviews : RestaureFenetresORD, once the main
    # window is displayed

    return
}


proc CreeVue {} {
    global db LNDG SDG Sequences TabSF ListeDesMacs ConsMeth ScoreMeth ListeScore ListeTypesDeFeatures LFeatCourantes Defauts TDesPhylum LNOrdali LSOrdali NombreDeSequences TbScores Anno

    # reads only : no transaction. The writing procs use
    # "$db transaction {...}" : committed at the end, rolled back
    # on error, never left open.
    set pkm [MacCourant]
    set LTot {}

    # Mise a jour groupes
    set LNDG  [LesClustersDuMac name]
    # WARNING !
    # Groups serve to define LNOrdali variable
    unset -nocomplain SDG
    foreach ng $LNDG {
	set ix [IndexDuCluster $ng]
	#set Ls [LesAccessDuCluster $ix]
	set Ls [LesSeqnamesDuCluster $ix]

	if {$ng eq "all"} {
	    set ng GroupeToutLeMonde
	}
	set SDG($ng) $Ls
	# name given by "Clusters Names"
	set label [$db onecolumn {select label from cluster where pk_cluster=$ix}]
	if {$label ne ""} {
	    set SDG(Equiv,$ng) $label
	}
    }
    set ig [lsearch -nocase $LNDG "all"]
    lset LNDG $ig "GroupeToutLeMonde"
    # group of each sequence of this instance : the tables still held
    # those of the instance displayed before, so a sequence only present
    # in this one had no group (ReadRawFeatureFile with PROPAGATE group)
    unset -nocomplain ::GroupeDeLaSequence
    AssignSeqToGroup
    # columns used by the clustering of this instance (written again
    # by EnregistreLeMac : it was the zone of the last clustering made,
    # whatever its instance)
    set ::ZoneClusterisation [lindex [ClusteringDuMac zone] 0]
    
    # Mise a jour tableau Sequences
    unset -nocomplain Sequences
    set Ls [LesSequencesDuMac]
    set Ln [LesSeqnamesDuMac]
    set NombreDeSequences [llength $Ln]
    foreach n $Ln s $Ls {
	set Sequences($n) $s
    }

    MetAJourNomsEtSeqs
    MetAJourListePDB
    AssigneLesPoids
    # physico-chemistry of the sequences only present in this instance
    # (computed at opening for the instance displayed then, and when
    # sequences are added) : needed by Sequence Information
    TraiteAABizarres
    CalculeLength
    CalculeComposition
    CalculePI
    CalculeMolecularWeight

    # Met a jour features AFFICHEES !!
    # features of the previous snapshot must not stay
    set LFeatCourantes {}
    set ListeTypesDeFeatures {}
    unset -nocomplain TabSF
    # nor their conservation methods (CreeFeaturesMethod would
    # put the feature type back in ListeTypesDeFeatures)
    array unset ScoreMeth "Cons-*"
    if {[set nbf [$db eval {select count(lsf.pk_featali) from ln_seqali_featali as lsf, ln_snapshot_seqali as lms where lms.pk_snap=$pkm and lsf.pk_snap=$pkm and lms.pk_seqali=lsf.pk_seqali}]]} {

	set Lv [$db eval {select si.seqname, fi.* from seqinfo as si, seqali as sa, featali as fi, ln_seqali_featali as lsf, ln_snapshot_seqali as lms
	    where fi.pk_featali = lsf.pk_featali
	    and   lsf.pk_seqali = lms.pk_seqali
	    and   lsf.pk_snap = $pkm
	    and   lms.pk_snap = $pkm
	    and   lms.pk_seqali = sa.pk_seqali
	    and   si.pk_seqinfo = sa.pk_seqinfo}]

	# the types are collected in a local list : ListeTypesDeFeatures
	# is traced (overviews, 3D viewer), and a lappend per feature
	# item ran the traces ~20000 times (40 s to change of instance)
	set Ltypes {}
	foreach {nom x ftype fstart fstop fcolor fscore fnote csys} $Lv {
	    lappend TabSF($nom,$ftype) [list "fstart" $fstart "fstop" $fstop "fcolor" $fcolor "fscore" $fscore "fnote" $fnote "fcsys" $csys]
	    lappend Ltypes $ftype
	}
	set ListeTypesDeFeatures [lsort -unique $Ltypes]
	if {[set Lft [lsearch -inline -regexp -all $ListeTypesDeFeatures {^Cons\-}]] != {}} {
	    foreach ft $Lft {
		# ORD saved before the fix of the doubled conservation
		# features : same element twice. Order kept.
		foreach k [array names TabSF "*,$ft"] {
		    set Lu {}
		    foreach e $TabSF($k) {
			if {! [info exists Vu($e)]} {
			    set Vu($e) 1
			    lappend Lu $e
			}
		    }
		    unset -nocomplain Vu
		    set TabSF($k) $Lu
		}
		set ScoreMeth($ft,Edit) 0
		if {[regexp {^Cons\-T[0-9]+} $ft]} {
		    set ScoreMeth($ft,ListeGrps) $LNDG
		    foreach g $LNDG {
			set LesPointsDuGroupe($g) ""
		    }
		}
	    }
	}
    }

    # Alignment Annotations of the snapshot : in memory (AnnoMac),
    # written in the db with the snapshot (ordali_annotation.tcl).
    # The instance is changed only in the ordali/feature modes :
    # no working state of the annotation mode.
    ChargeAnnotationsDuMac
    unset -nocomplain Anno

    # Conservation
    # Pas calcule si precompute = 0
    set pk_Clg [$db eval {select max(pk_clustering) from clustering where pk_snap=$pkm}]
    if {[llength [set Lpkmeas [$db eval {select pk_colmeasure from colmeasure where pk_snap=$pkm}]]]} {
	set i 1
	foreach pk_meas $Lpkmeas {
	    set nom [$db eval {select name from colmeasure where pk_colmeasure=$pk_meas}]

	    if {[string range $nom 0 3] ne "Cons"} {
		set ft "Cons-$nom"
		# => ATTENTION ! A changer ! TODO
		# si on a des features de conservation (donc des fitem cons-***) , elle apparaissent dans ListeTypesDeFeatures
		# Quand on charge les colscores,
		# le nom de ce colscore peut etre dnas ListeTypesDeFeatures, et le nom du colscore sera nom_1, ce qui est faux !
		while {0 && $ft in $ListeTypesDeFeatures} {
		    set ft "Cons-${nom}_$i"
		    incr i
		}
	    } else {
		set ft $nom
	    }
	    #puts "feat $ft $nom $::ListeTypesDeFeatures"

	    set ident "$nom"
	    set TbScores(Lcols) $nom
	    unset -nocomplain ConsMeth
	    set ConsMeth(IdenGlob) {}
	    set ConsMeth(ConsGlob) {}
	    foreach ix [LesClustersDuMac] g [LesClustersDuMac name] {
		array unset TbScores "Score,*"
		if {$g eq "GroupeToutLeMonde"} {
		    set g "all"
		}

		#puts "colmeasure:"
		#puts [$db eval {select * from colmeasure}]
		#puts "colscore:"
		set Lv [$db eval {select * from colscore}]
		foreach {pkc pkm name owner type grp dt} $Lv {
		    #puts "$pkc $pkm $name $owner $type $grp [llength $dt]"
		}

		set l [$db eval {select cs.data from colscore as cs, ln_cluster_colscore as lcc, cluster as c where \
				     cs.pk_colmeasure=$pk_meas and \
				     cs.pk_colscore=lcc.pk_colscore and \
				     lcc.pk_cluster=c.pk_cluster and \
				     c.pk_cluster=$ix}]
		if {[llength $l] > 1} {
		    puts ">>> l > 1 !"
		    set l [lindex $l 0]
		}

		set l [split $l ","]

		# one score per column : ORD saved with the scores of
		# a longer instance (StockScores kept them) could
		# not be loaded
		set Lgt [LongueurDeLAlignement]
		if {[llength $l] && [llength $l] != $Lgt} {
		    puts "$nom $g : [llength $l] scores for $Lgt columns"
		    set l [lrange $l 0 $Lgt-1]
		    while {[llength $l] < $Lgt} {
			lappend l -999
		    }
		}

		# Si groupe trop petit pas de cons
		if {! [llength $l]} {
		    continue
		}
		if {[llength [lsort -unique $l]] == 1} {
		    continue
		}

		if {$g eq "all" || $g eq "All"} {
		    set g ""
		}
		# Met tout en flottant.
		# Enleve -999. pour calc min/max
		set Nl {} ; set lmx {}
		foreach e $l {
		    set e [expr {double($e)}]
		    lappend Nl $e
		    if {$e != -999.} {
			lappend lmx $e
		    }
		}
		set l $Nl
		set lmx [lsort -unique -real $lmx]
		set min [lindex $lmx 0]
		set max [lindex $lmx end]
		set Lres {}
		# scale values between 0 and 100.
		foreach e $l {
		    if {$e != -999.} {
			set e [expr {100.*($e-$min)/($max-$min)}]
		    }
		    lappend Lres $e
		}
		set TbScores(Score,$nom) $Lres

		set Lsc [CreeListeScore $g]
		set Lluc {}
		foreach elt $Lsc {
		    lappend Lluc [lindex $elt 1]
		}
		StockScores $ft $g
		set Lsc {}
		foreach elt $::ListeScore {
		    lappend Lsc [lindex $elt 1]
		}

		set Lgr [Tclcluspack $::ListeScore -dt coordinates -cm kmeans -nbc dpc -wc]
		if {$g eq "" && [llength $Lgr] == 1} {
		    set Lgr [SecatorDesScores $::ListeScore]
		    #puts "Clus : 2e [llength $Lgr]"
		}

		set Lret [TraiteResultatClusteringTcl $Lgr $ident $g "mixturemodels"]
		foreach {a b} $Lret {
		}
	    }
	    foreach k [array names ConsMeth] {
		#puts "$ft -> $k [llength $ConsMeth($k)]"
	    }

	    if {[info exists ScoreMeth($ft,ListeGrps)]} {
		if {[array names TabSF "*,$ft"] eq ""} {
		    CreeFeaturesMethod $ft
		} else {
		    # the feature items of the snapshot were read above :
		    # they are kept. Creating the feature again from the
		    # scores appended its elements to them, at each
		    # Overwrite then opening (the clustering of the scores
		    # by kmeans is random, so the elements differ)
		    set ScoreMeth($ft,Edit) 0
		}
	    }
	    puts ""
	}
    }

    # Termine !
    set ListeDesMacs [LesMacs]


    VueEditee 0

    return
}


proc SecatorDesScores {Lpts} {
    # hierarchic/secator clustering of column scores {col value}.
    # When many columns have the same value (Cons-SDP : 0, 75 or
    # 100), secator on ~2000 tied points takes about a minute : the
    # distinct values are clustered (same groups, a few
    # microseconds) and each column goes in the group of its value.
    set Lv [lsort -unique -real [lmap e $Lpts {lindex $e 1}]]
    if {[llength $Lv] == [llength $Lpts] || [llength $Lv] < 2} {
	return [Tclcluspack $Lpts -dt coordinates -cm hierar -nbc secator -wc]
    }
    set Lu {}
    set i 0
    foreach v $Lv {
	lappend Lu [list $i $v]
	incr i
    }
    set k 0
    foreach g [Tclcluspack $Lu -dt coordinates -cm hierar -nbc secator -wc] {
	foreach e $g {
	    set Grp([expr {double([lindex $Lv [lindex $e 0]])}]) $k
	}
	set Tgr($k) {}
	incr k
    }
    foreach e $Lpts {
	lappend Tgr($Grp([expr {double([lindex $e 1])}])) $e
    }
    set Lgr {}
    for {set i 0} {$i < $k} {incr i} {
	lappend Lgr $Tgr($i)
    }

    return $Lgr
}


proc LesIndexsDesSeqnames {Ls} {
    # pk_seqali des sequences du mac courant, dans l'ordre de Ls.
    # Un meme seqname peut avoir plusieurs versions dans seqali
    # (sequence modifiee) : on ne garde que celle du mac courant.
    set pkm [MacCourant]
    foreach {n pk} [$::db eval {select sa.seqname, sa.pk_seqali from seqali as sa, ln_snapshot_seqali as lms where lms.pk_snap=$pkm and lms.pk_seqali=sa.pk_seqali}] {
	set Tpk($n) $pk
    }

    set Lpk {}
    foreach s $Ls {
	set sqn [set ::TDesSeqnames($s)]
	if {[info exists Tpk($sqn)]} {
	    lappend Lpk [set Tpk($sqn)]
	}
    }

    return $Lpk
}


proc LesIndexsDesAccess {Ls} {
    # Rajoute les simples quotes ...
    # boucle pour avoir les pk dans l'ordre
    set pkm [MacCourant]
    foreach acc $Ls {
	set acc [string map [list "'" "''"] $acc]
	lappend tmp "'$acc'"
    }
    set Na {}
    set Na [$::db eval "select sa.pk_seqali from seqali as sa, seqinfo as si, ln_snapshot_seqali as lms where
lms.pk_snap=$pkm and
lms.pk_seqali=sa.pk_seqali and
sa.pk_seqinfo=si.pk_seqinfo and
si.access in ([join $tmp ,]) order by sa.pk_seqali"]

return $Na
}


proc VueEditee {{edt ""}} {
    if {$edt eq ""} {return $::VueEditee}
    set ::VueEditee $edt

    return
}


proc FichierModifie {{mod ""}} {
    # 1 : the database (instances) has changed since the file was
    # loaded or saved as ORD. Unlike VueEditee, saving an instance
    # does not reset it : the file still has to be saved.
    if {$mod eq ""} {
	return [expr {[info exists ::FichierModifie] && $::FichierModifie}]
    }
    set ::FichierModifie $mod

    return
}


proc ModeInterditInstance {action} {
    # the instances (snapshots) are changed, overwritten, created or
    # deleted only in the "ordali" and "feature" modes : the work of
    # the other modes is validated (or dropped) when they are left.
    # 1 (and a message) if the current mode forbids it.
    if {[QuelMode] in {"ordali" "feature"}} {
	return 0
    }
    FaireLire "Please leave the current mode before $action."

    return 1
}


proc ActionInstance {quoi} {
    # list and buttons of the instance bar
    switch -- $quoi {
	"choose" {
	    if {[ModeInterditInstance "changing instance"]} {
		# the list shows the current instance again
		MetAJourWMacs
		return
	    }
	    MiseAJourMac
	}
	"reset" {
	    if {[ModeInterditInstance "resetting the instance"]} {
		return
	    }
	    MiseAJourMac reset
	}
	"overwrite" {
	    if {[ModeInterditInstance "overwriting the instance"]} {
		return
	    }
	    SauveLeMac 0
	}
	"new" {
	    if {[ModeInterditInstance "creating a new instance"]} {
		return
	    }
	    SauveLeMac 1
	}
	"delete" {
	    DetruitInstance
	}
    }

    return
}


proc DescriptionDuMac {{mac ""}} {
    if {$mac eq ""} {set mac [MacCourant]}
    return [$::db onecolumn {select description from snapshot where pk_snap=$mac}]
}


proc ClusteringDuMac {{quoi "name"}} {
    set p [MacCourant]
    switch $quoi {
	"index" {
	    set r [$::db eval {select pk_clustering from clustering where pk_snap=$p}]
	}
	"name" {
	    set r [$::db eval {select name from clustering where pk_snap=$p}]
	}
	"method" {
	    set r [$::db eval {select method from clustering where pk_snap=$p}]
	}
	"zone" {
	    set r [$::db eval {select zone from clustering where pk_snap=$p}]
	}
    }

    return $r
}


proc NumeroNewMac {} {
    return [incr ::CompteurDeMac]
}


proc LesMacs {{quoi "name"}} {
    if {! [info exists ::db]} {
	return ""
    } elseif {$quoi eq "name"} {
	return [$::db eval {select name from snapshot}]
    } else {
	return [$::db eval {select pk_snap from snapshot}]
    }
}


proc SauveLeMac {{new 1} {atitre ""} {adesc ""}} {
    if {[TypeAli] eq "pasdali"} {
	return
    }

    if {$new} {
	if {$atitre eq "" && $adesc eq ""} {
	    lassign [DemandeTitreEtDescDuMac] atitre adesc ctitre cdesc
	}
	if {$atitre eq ""} {return}
    } else {
	if {[MacCourant] == 1} {
	    FaireLire "Beware !\nYou can not overwrite the 'Original alignment'.\nThis alignment constitute a reference alignment. You can only \ncreate a new alignemts from it or discard the modifications."
	    return
	}
	set atitre ""
	set adesc ""
    }

    MetAJourGroupes
    EnregistreLeMac $atitre $adesc
    # the snapshot is saved
    VueEditee 0
    MetAJourWMacs

    return
}


#
# After an ORD file is loaded (main window displayed) : the trees and
# overviews of EVERY instance are drawn again. Each one is computed on
# the alignment of its instance : the instances that have some are
# displayed in turn, then the current one again.
#
proc RestaureFenetresORD {} {
    global Abr OvwORD

    if {[TypeAli] ne "ORD" || ! [ModeI]} {
	unset -nocomplain OvwORD
	return
    }
    set Lpk [LesMacs index]
    set Lmac {}

    # trees (and overviews) of instances that do not exist any more
    if {[info exists Abr(Liste)]} {
	foreach AId $Abr(Liste) {
	    if {! [info exists Abr($AId,Mac)] || $Abr($AId,Mac) ni $Lpk} {
		DetruitArbre $AId
	    } else {
		lappend Lmac $Abr($AId,Mac)
	    }
	}
    }
    set Lovw {}
    if {[info exists OvwORD(Liste)]} {
	foreach Id $OvwORD(Liste) {
	    if {! [info exists OvwORD($Id,Mac)] || $OvwORD($Id,Mac) ni $Lpk} {
		continue
	    }
	    set d [dict create]
	    foreach k {Feat FeatAff ShowRegion ShowAnno ScaleTot} {
		if {[info exists OvwORD($Id,$k)]} {
		    dict set d $k $OvwORD($Id,$k)
		}
	    }
	    lappend Lovw $OvwORD($Id,Mac) $d
	    lappend Lmac $OvwORD($Id,Mac)
	}
    }
    unset -nocomplain OvwORD

    # the current instance last : no need to come back to it
    set cur [MacCourant]
    set Lmac [lsort -unique -integer $Lmac]
    if {$cur in $Lmac} {
	set Lmac [concat [lsearch -all -inline -not -exact $Lmac $cur] $cur]
    }
    foreach mac $Lmac {
	if {$mac != [MacCourant]} {
	    MiseAJourMac x [lindex [NomDeMac $mac] 0]
	}
	# a tree which can not be drawn must not prevent opening the file
	if {[catch {RecoverTrees $mac} Msg]} {
	    puts "\nRestaureFenetresORD : trees of instance $mac\n$::errorInfo"
	    FaireLire "Error !\nA tree of instance [NomDeMac $mac] could not be restored :\n$Msg"
	}
	foreach {m d} $Lovw {
	    if {$m == $mac} {
		AfficheOverview $d
	    }
	}
    }
    if {[MacCourant] != $cur} {
	MiseAJourMac x [lindex [NomDeMac $cur] 0]
    }

    return
}


#
# "Delete" button of the instance bar : deletes the current instance
# (snapshot) and everything that depends on it : database rows
# (DetruitLeMac), trees and overviews made on it. The instances are
# not renumbered. The previous instance of the list is displayed.
#
proc DetruitInstance {} {
    global Abr Ovw

    if {[TypeAli] eq "pasdali" || [LesMacs] eq ""} {
	return
    }
    set pkm [MacCourant]
    set nom [MacCourant name]
    if {$pkm == 1} {
	FaireLire "Beware !\nYou can not delete the 'Original alignment'.\nThis alignment constitutes the reference alignment."
	return
    }
    if {[ModeInterditInstance "deleting an instance"]} {
	return
    }

    # trees and overviews of this instance
    set Larb {}
    if {[info exists Abr(Liste)]} {
	foreach AId $Abr(Liste) {
	    if {[info exists Abr($AId,Mac)] && $Abr($AId,Mac) == $pkm} {
		lappend Larb $AId
	    }
	}
    }
    set Lovw {}
    if {[info exists Ovw(Liste)]} {
	foreach Id $Ovw(Liste) {
	    if {[info exists Ovw(O$Id,Mac)] && $Ovw(O$Id,Mac) == $pkm} {
		lappend Lovw $Id
	    }
	}
    }

    set msg "Delete instance \"$nom\" ?"
    if {[llength $Larb] || [llength $Lovw]} {
	append msg "\nIts [llength $Larb] tree(s) and [llength $Lovw] overview(s) will be deleted too."
    }
    if {[VueEditee]} {
	append msg "\nThe unsaved modifications will be lost."
    }
    append msg "\nThis can not be undone !"
    if {[tk_dialog .delmac "Delete instance" $msg warning 1 "Delete" "Cancel"] != 0} {
	return
    }

    # instance displayed afterwards : the previous one
    set Lpk [LesMacs index]
    set i [lsearch $Lpk $pkm]
    set pknew [lindex $Lpk [expr {$i > 0 ? $i-1 : 1}]]
    set nomnew [lindex [NomDeMac $pknew] 0]

    foreach AId $Larb {
	DetruitArbre $AId
    }
    foreach Id $Lovw {
	DetruitOverview $Id
    }

    $::db transaction {
	DetruitLeMac $pkm
    }

    # the deleted instance can not be displayed again (MiseAJourMac
    # goes back to the previous instance if the new one fails)
    VueEditee 0
    LesDefauts IxMacCourant $pknew
    LesDefauts NmMacCourant $nomnew
    MiseAJourMac x $nomnew

    if {[info commands AuLog] ne ""} {
	AuLog "Instance \"$nom\" deleted ([llength $Larb] tree(s), [llength $Lovw] overview(s))"
    }

    return
}


proc SetMacCourant {quoi} {
    if {$quoi eq "last"} {
	set imac [$::db eval {select max(pk_snap) from snapshot}]
    } elseif {$quoi eq "first"} {
	set imac [$::db eval {select min(pk_snap) from snapshot}]
    }
    set nmac [NomDeMac $imac]

    LesDefauts IxMacCourant $imac
    LesDefauts NmMacCourant $nmac

    return
}


proc NomDeMac {imac} {
    return [$::db eval {select name from snapshot where pk_snap=$imac}]
}


proc IndexDeMac {mac} {
    return [$::db eval {select pk_snap from snapshot where name=$mac}]
}


proc IndexDeClustering {c} {
    return [$::db eval {select pk_clus from clustering where name=$c}]
}


proc ZonesClustering {} {
    set pkm [MacCourant]
    return [$::db eval {select zone from clustering where pk_snap=$pkm}]
}


proc ClusteringCourant {{quoi "name"}} {
    if {$quoi eq "index"} {
	return [set ::Defauts(IxClustCourant)]
    } else {
	return [set ::Defauts(NmClustCourant)]
    }
}


proc MacEdite {{v ""}} {
    set pkm [MacCourant]
    if {$v eq ""} {
	return [$::db eval {select edition from snapshot where pk_snap=$pkm}]
    } else {
	$::db eval {update mac set edition=$v where pk_snap=$pkm}
    }
}


proc MacCourant {{quoi "index"}} {
    if {$quoi eq "index"} {
	return [set ::Defauts(IxMacCourant)]
    } else {
	return [set ::Defauts(NmMacCourant)]
    }
}


proc InsereNouvelleSequence {n s} {
    global {*}[info globals "TD*"] db

	       set ins "NULL"
	       foreach t {TDesSeqnames TDesAccess TDesBId TDesDescriptifs TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesPhylum TDesGO TDuLineage TDesHydro TDespI TDesMolW} {
		   set v [set ${t}($n)]

		   if {! [string is integer -strict $v] && ! [string is double -strict $v]} {
		       if {$v eq ""} {
			   lappend ins "NULL"
		       } else {
			   set v [string map {"'" "''"} $v]
			   lappend ins "'$v'"
		       }
		   } else {
		       lappend ins $v
		   }
	       }
	       set sdegap [string map {" " "" "." ""} $s]
	       lappend ins "'$sdegap'"

	       $db eval "insert into seqinfo values ([join $ins ,])"
	       set pki [$db last_insert_rowid]
	       set sqn [set TDesSeqnames($n)]
	       $db eval {insert into seqali values (NULL, $pki, $sqn, $s)}

	       return
	   }


proc VerifSeqs {} {
    global db LNOrdali LSOrdali TDesSeqnames
    
    # Met a jour si besoin est table seqali , ou
    # insere nouvelle sequence

    foreach n $LNOrdali s $LSOrdali {
	set n [string trim $n]
	if {$n eq ""} {continue}
	
	set sqn [set TDesSeqnames($n)]
	if {[$db eval {select count(pk_seqali) from seqali where seqname=$sqn and seq=$s}]} {
	    # seqname et sequence existent
	    continue
	} elseif {[$db eval {select count(pk_seqali) from seqali where seq=$s}]} {
	    # seq identique , nom different ?
	    set seqref $s
		if {[regexp "__" $sqn]} {
		    set nom [string range $sqn 0 [string first "__" $sqn]-1]
		    if {[$db eval {select count(pk_seqali) from seqali where seqname=$nom and seq=$s}]} {
			# seq est copie d'une autre
			set nomref $nom
		    } else {
			# nom n'existe pas
			set nomref ""
		    }
		} else {
		    # on a nouveau nom
		    set nomref ""
		}
	    } elseif {[$db eval {select count(pk_seqali) from seqali where seqname=$sqn}]} {
		# meme nom, mais nouvelle seq
		set seqref ""
		set nomref $sqn
	    } else {
		set seqref ""
		set nomref ""
	    }

	    # Si nom ref existe, prend infos de ref
	    if {$nomref ne ""} {
		set refinf [lindex [$db eval {select pk_seqinfo from seqali where seqname=$nomref}] 0]
		$db eval {insert into seqali values (NULL, $refinf, $sqn, $s)}
	    } else {
		InsereNouvelleSequence $n $s
	    }
	}

	return
    }


proc DetruitLeMac {pkm} {
	global db

	FichierModifie 1
	# Table mac
	$db eval {delete from snapshot where pk_snap=$pkm}
	# table ln_snapshot_seqali
	# les seqali sont partagees entre snapshots : ne detruire
	# que les features de ce snapshot, et les featali qui ne
	# sont plus liees a aucun snapshot
	$db eval {delete from ln_seqali_featali where pk_snap=$pkm}
	$db eval {delete from featali where pk_featali not in (select pk_featali from ln_seqali_featali)}
	$db eval {delete from ln_snapshot_seqali where pk_snap=$pkm}

	# clusternig/cluster
	# on detruit cluster apres cluster
	set Lpkg [$db eval {select pk_clustering from clustering where pk_snap=$pkm}]
	foreach pkg $Lpkg {
	    set Lpkc [$db eval {select pk_cluster from cluster where pk_clustering=$pkg}]
	    foreach pkc $Lpkc {
		$db eval {delete from ln_seqali_cluster where pk_cluster=$pkc}
		$db eval {delete from cluster where pk_cluster=$pkc}
	    }
	}
	$db eval {delete from clustering where pk_snap=$pkm}

	# colscore
	set Lc [$db eval {select pk_colmeasure from colmeasure where pk_snap=$pkm}]
	$db eval "delete from colmeasure where pk_colmeasure in ([join $Lc ,])"
	set Ll [$db eval "select pk_colscore from colscore where pk_colmeasure in ([join $Lc ,])"]
	$db eval "delete from colscore where pk_colmeasure in ([join $Lc ,])"
	$db eval "delete from ln_cluster_colscore where pk_colscore in ([join $Ll ,])"

	# annotation
	$db eval {delete from annotation where pk_snap=$pkm}

	#    $db eval {commit}

	return
    }


proc EnregistreLeMac {{titre ""} {desc ""}} {
    global db LNOrdali LSOrdali LNDG SDG ScoreMeth TDesSeqnames TabSF Anno

    FichierModifie 1

	# Speed up the bordel
	$db transaction {

	if {$titre eq ""} {
	    set atitre [MacCourant name]
	    set adesc  [DescriptionDuMac]
	    set ctitre [lindex [ClusteringDuMac name] 0]
	    set new 0
	} else {
	    set atitre "M[NumeroNewMac] - $titre"
	    set adesc  $desc
	    set ctitre [lindex [ClusteringDuMac name] 0]
	    set new 1
	}
	# methode du clustering (colonne method de la table clustering) :
	# celle calculee en mode cluster, sinon celle du mac courant
	if {[info exists ::Clus(MethodeCalculee)]} {
	    set cmeth $::Clus(MethodeCalculee)
	} else {
	    set cmeth [lindex [ClusteringDuMac method] 0]
	}

	# annotations of the current snapshot, in memory (AnnoMac) :
	# written in the saved snapshot, with their pk when the
	# current one is overwritten
	if {! [info exists ::AnnoMac]} {
	    ChargeAnnotationsDuMac
	}
	set Lanno [concat {*}$::AnnoMac]

	# Detruit mac a remplacer si besoin est.
	# Overwrite : le snapshot garde son pk_snap (et donc sa
	# place dans la liste des instances)
	set pkrep ""
	if {! $new} {
	    set pkrep [MacCourant]
	    DetruitLeMac $pkrep
	}

	# C'est parti !
	# Creation du Mac
	# Devient le mac courant
	$db eval {insert into snapshot values (nullif($pkrep,''), $atitre, $adesc)}
	set pk_snap [$db last_insert_rowid]
	LesDefauts IxMacCourant $pk_snap
	LesDefauts NmMacCourant $atitre

	VerifSeqs

	# Remplit seqs du mac
	# Remplit features du mac
	set pos 0
	foreach n $LNOrdali s $LSOrdali {
	    set n [string trim $n]
	    if {$n eq ""} {
		continue
	    }

	    set sqn [set TDesSeqnames($n)]
	    set pksi [$db eval {select pk_seqali from seqali where seqname=$sqn and seq=$s}]
	    $db eval {insert into ln_snapshot_seqali values ($pk_snap, $pksi, $pos)}

	    # remplit features a partir de TabSF
	    if {! [info exists TabSF] || [set Lf [array names TabSF "${n},*"]] == {} } {
		incr pos
		continue
	    }

	    foreach e $Lf {
		lassign [split $e ,] tmp ftype
		foreach f [set TabSF($e)] {
		    DecortiqueUneFeature $f fstart fstop fcolor fscore fnote fcsys
		    $db eval {insert into featali values(NULL, $ftype, $fstart, $fstop, $fcolor, $fscore, $fnote, $fcsys)}
		    set pkfi [$db last_insert_rowid]
		    $db eval {insert into ln_seqali_featali values($pksi,$pkfi,$pk_snap)}
		}
	    }
	    incr pos
	}

	# Remplit clusters
	$db eval {insert into clustering values(NULL, $pk_snap, $ctitre, $cmeth, $::ZoneClusterisation)}
	set pkg [$db last_insert_rowid]
	foreach g $LNDG {
	    if {$g eq "bidon"} {continue}
	    if {$g eq "grise"} {continue}

	    set Lix [LesIndexsDesSeqnames [set SDG($g)]]
	    # name given by "Clusters Names"
	    set label [expr {[info exists SDG(Equiv,$g)] && $SDG(Equiv,$g) ne $g ? $SDG(Equiv,$g) : ""}]
	    if {$g eq "GroupeToutLeMonde"} {
		set g "all"
	    }
	    $db eval {insert into cluster values(NULL, $pkg, $g, nullif($label,''))}
	    set pkc [$db last_insert_rowid]
	    set pos 0
	    foreach i $Lix {
		$db eval {insert into ln_seqali_cluster values ($i,$pkc,$pos)}
		incr pos
	    }
	}

	# Remplit Annotations
	foreach {pka txt col zone} $Lanno {
	    if {$new} {
		set pka ""
	    }
	    $db eval {insert into annotation values (nullif($pka,''),$pk_snap,$txt,$col,$zone)}
	}
	# pk may have changed (new snapshot) : AnnoMac read again
	ChargeAnnotationsDuMac

	# Remplit colscore
	set Ls [array names ScoreMeth "Cons-*,Edit"]
    #puts "ListeTypes $::ListeTypesDeFeatures"
	foreach e $Ls {
	    if {[set ScoreMeth($e)]} {
		continue
	    }

	    lassign [split $e ,] ft edt
	    set name $ft
	    if {[regexp "Cons-T" $ft]} {
		set type int
		set absent -999
	    } else {
		set type float
		set absent -999.0
	    }
	    set root [string range $ft 5 end]
	    if {[string first "_" $root] != -1} {
		set root [string range $root 0 [string first _ $ft]-1]
	    }
	    $db eval {insert into colmeasure values (NULL,$pk_snap,$ft,$root)}
	    set pk_meas [$db last_insert_rowid]
	    if {! [info exists ScoreMeth($ft,ListeGrps)]} {
		set ScoreMeth($ft,ListeGrps) {}
	    }
	    foreach g [set ScoreMeth($ft,ListeGrps)] {
		if {$g eq "GroupeToutLeMonde" || $g eq "all"} {
		    set owner "all"
		} else {
		    set owner "group_[string range $g 5 end]"
		}

		# recupere index colonnes ayant 1 score
		set Li [array names ScoreMeth ${ft},$g,*]
		if {$Li == {} } {continue}
		set Lx {}
		foreach v $Li {
		    lassign [split $v ,] t m i
		    lappend Lx $i
		}
		# insere -999. aux colonnes manquantes
		set data {}
		set c 0
		foreach i [lsort -integer $Lx] {
		    while {$c != $i} {
			lappend data $absent
			incr c
		    }
		    set v $ScoreMeth(${ft},$g,$i)
		    lappend data $v
		    incr c
		}
		set data [join $data ,]
		$db eval {insert into colscore values(NULL, $pk_meas, $name, $owner, $type, $owner, $data)}
		set pkcols [$db last_insert_rowid]
		if {$g eq "GroupeToutLeMonde"} {set g all}
		set pkclus [$db eval {select pk_cluster from cluster where name=$g and pk_clustering=$pkg}]
		$db eval {insert into ln_cluster_colscore values ($pkclus,$pkcols)}
	    }
	}

	# termine !
	}
	$db eval {vacuum}

	return
    }


proc EnregistreInfosSeqs {} {
    global db LNOrdali {*}[info globals "TD*"]

    $db transaction {
			       set pkm [MacCourant]
    foreach n $LNOrdali {
	set n [string trim $n]
	if {$n eq ""} {
	    continue
	}
	
	set pksi [$db eval {select pk_seqinfo from seqinfo where seqname=$n}]
	
	foreach t {TDesSeqnames TDesAccess TDesBId TDesDescriptifs TDesOrganismes TDesTaxId TDesFragment TDuGroupeDesSeqs TDesEC TDesComplex TDesPhylum TDesGO TDuLineage TDesHydro TDespI} c {seqname access bid description organism taxid fragment cgroup ec complex phylum go lineage hydrophobicity isoelectric} {
	    set v [set ${t}($n)]

	    if {! [string is integer -strict $v] && ! [string is double -strict $v]} {
		if {$v eq ""} {
		    $db eval "update seqinfo set $c=NULL where pk_seqinfo = $pksi"
		} else {
		    set v [string map {"'" "''"} $v]
		    $db eval "update seqinfo set ${c} = '${v}' where pk_seqinfo = $pksi "
		}
	    } else {
		$db eval "update seqinfo set $c = $v where pk_seqinfo = $pksi"
	    }
	}
    }
    }

    return
}


proc LongueurMac {{m 0}} {
    if {! $m} {set m [MacCourant]}
    return [$::db eval {select max(length(sa.seq)) from seqali as sa, ln_snapshot_seqali as lms where lms.pk_snap=$m and lms.pk_seqali=sa.pk_seqali}]
}


proc LesAccessDuMac_VOIR_PLUS_LOIN_1 {{m 0}} {
    #rR attention il y en a un autre plus bas
    # ATTENTION
    # Ici on retourne les access de tous les clusters
    if {! $m} {set m [MacCourant]}
    return [$::db eval {select si.access from seqinfo as si, seqali as sa, ln_seqali_cluster as lsc, cluster as c where
	c.pk_clustering=$m and
	lsc.pk_cluster=c.pk_cluster and
	sa.pk_seqali=lsc.pk_seqali and
	si.pk_seqinfo=sa.pk_seqinfo}]
}


proc LesAccessDuMac {{m 0}} {
    if {! $m} {set m [MacCourant]}
    return [$::db eval {select si.access from seqinfo as si, seqali as sa, ln_snapshot_seqali as lms where \
			    lms.pk_snap=$m and \
			    lms.pk_seqali=sa.pk_seqali and \
			    sa.pk_seqinfo=si.pk_seqinfo}]
	}


	proc LesSeqnamesDuMac {{m 0}} {
	    if {! $m} {set m [MacCourant]}
	    return [$::db eval {select sa.seqname from seqali as sa, ln_snapshot_seqali as lms where lms.pk_snap=$m and lms.pk_seqali=sa.pk_seqali order by lms.pos}]
	}


	proc LesSeqnamesDuCluster {c} {
	    return [$::db eval {select sa.seqname from seqali as sa, ln_seqali_cluster as lsc where lsc.pk_cluster=$c and lsc.pk_seqali=sa.pk_seqali order by lsc.pos}]
	}


	proc LesAccessDuCluster {c} {
	    return [$::db eval {select si.access from seqinfo as si, seqali as sa, ln_seqali_cluster as lsc where lsc.pk_cluster=$c and lsc.pk_seqali=sa.pk_seqali and si.pk_seqinfo=sa.pk_seqinfo order by lsc.pos}]
	}


	proc LesSequencesDuMac_VOIR_PLUS_LOIN_2 {{m 0}} {
	    if {! $m} {set m [MacCourant]}
	    return [$::db eval {select sa.seq from seqali as sa, ln_snapshot_seqali as lms where lms.pk_snap=$m AND lms.pk_seqali=sa.pk_seqali order by lms.pos}]
	}


	proc LesSequencesDuMac_VOIR_PLUS_LOIN_1 {{m 0}} {
	    if {! $m} {set m [MacCourant]}
	    return [$::db eval {select sa.seq from seqali as sa, cluster as c, ln_seqali_cluster as lsc, clustering as g where
		g.pk_snap=$m and
		g.pk_clustering=c.pk_clustering and
		c.pk_cluster=lsc.pk_cluster and
		lsc.pk_seqali=sa.pk_seqali}]
	}


	proc LesSequencesDuMac {{m 0}} {
	    # meme ordre que LesSeqnamesDuMac (order by lms.pos),
	    # sinon noms et sequences sont decales dans CreeVue
	    if {! $m} {set m [MacCourant]}
	    return [$::db eval {select sa.seq from seqali as sa, ln_snapshot_seqali as lms where lms.pk_snap=$m and lms.pk_seqali=sa.pk_seqali order by lms.pos}]
	}

	proc IndexDuCluster {c} {
	    set m [MacCourant]
	    return [$::db eval {select c.pk_cluster from cluster as c, clustering as g where c.name=$c and c.pk_clustering=g.pk_clustering and g.pk_snap=$m}]
	}


	proc InitClustersDuMac {} {
	    global SDG LNDG

	    set LNDG [LesClustersDuMac name]
	    unset -nocomplain SDG
	    foreach ng $LNDG {
		set ix [IndexDuCluster $ng]
		set Ls [LesSeqnamesDuCluster $ix]
		if {$ng eq "all"} {
		    set ng GroupeToutLeMonde
		}
		set SDG($ng) $Ls
		# name given by "Clusters Names"
		set label [$::db onecolumn {select label from cluster where pk_cluster=$ix}]
		if {$label ne ""} {
		    set SDG(Equiv,$ng) $label
		}
	    }
	    set ig [lsearch -nocase $LNDG "all"]
	    if {$ig != -1} {
		lset LNDG $ig "GroupeToutLeMonde"
	    }

	    return
	}


proc LesClustersDuMac {{quoi "index"} {m 0}} {
    if {! $m} {
	set m [MacCourant]
    }
    if {$quoi eq "name"} {
	set r [$::db eval {select c.name from cluster as c, clustering as g where c.pk_clustering=g.pk_clustering and g.pk_snap=$m order by c.pk_cluster}]
    } else {
	set r [$::db eval {select c.pk_cluster from cluster as c, clustering as g where c.pk_clustering=g.pk_clustering and g.pk_snap=$m order by c.pk_cluster}]
    }
    
    return $r
}


proc LesAccessDesSeqali {l} {
    return [$::db eval "select si.access from seqinfo as si, seqali as sa
wher	   e si.pk_seqinfo=sa.pk_seqinfo
and sa.pk_s  eqali in ([join $l ,])"]
}   
    
    
proc	 NomsEtSeqsDesSeqali {l} {
    return [$::db eval "select sa.seqname, sa.seq from seqali where pk_seqali in ([join $l ,])"]
}


proc tototo {} {
    global db
    
    set VC [VisCourante]
    $db transaction {

    set Lg [$db eval {select pk_cluster from cluster where pk_clustering=$c}]
    foreach g $Lg {
	set Sql "select si.access, sa.seq from seqali as sa , ln_seqali_cluster as lsc, seqinfo as si, ln_vis_seqali as lvs
where          $g = lsc.pk_cluster
and lsc.pk_seqali = lvs.pk_seqali
and    lvs.pk_vis = $VC
and lvs.pk_seqali = sa.pk_seqali
and sa.pk_seqinfo = si.pk_seqinfo"

	set res [$db eval $Sql]
	lappend Las $res
    }
    }

    return $Las
}


proc ChangeClustering {c n m z} {
    $::db eval {update clustering set name=$t, method=$m, zone=$z where pk_clustering=$c}

    return
}


proc EnregistreClustering {titre LNSG} {
    global Clus

    $db transaction {
    $db eval "insert into clustering values(NULL,[MacCourant index],'$titre','[set Clus(Method)]','$ZoneClusterisation')"
    set lastClu [$db eval {select max(pk_clus) from clustering}]
    foreach {g ls} $LNSG {
	EnregistreCluster $LastClu
    }

    }

    return
}


proc MetAJourCluster {LNSG} {
    global Clus ZoneClusterisation

    set iVue [MacCourant index]
    set iClu [ClusteringCourant index]

    ChangeClustering $iVue $Clus(Titre) $Clus(Method) $ZoneClusterisation
    DetruitCluster $iClu

    if {$Clus(Method) eq "nogroups"} {set gall 1} {set all 0}
    set Lactive {}
    foreach {g Ls} $LNSG {
	if {$g eq "GroupeToutLeMonde" && ! $gall} {continue}
	if {$g eq "GrSeqOut"} {
	    set Lout $Ls
	    continue
	}
	set Li [LesIndexDesSeqs $Ls]
	EnregistreCluster $iClu $Li $g
	set Lactive [concat $Lactive $Li]
    }

    ChangeActive $Lactive

    return
}



proc DetruitLesClustersDuClustering {c} {
    $::db eval {delete from cluster where pk_clustering=$c}

    return
}


proc DetruitUnCluster {c} {
    $::db eval {delete from cluster where pk_cluster=c}
    return
}


proc EnregistreCluster {pk_clustering Ls name} {
    global db

    $db eval {insert into cluster values (NULL, $pk_clustering, $name, NULL)}

    set lastCst [$db last_insert_rowid]
    set pos 0
    foreach i $Li {
	$db eval {insert into ln_seqali_cluster values ($i,$LastCst,$pos)}
	incr pos
    }

    return
}


proc MetAJourVis {Li quoi {Vue ""} {Clus}} {
    switch $quoi {
	"cut" {
	    foreach i $Li {
		$::db eval {delete from ln_vis_seqali where pk_vis=$vs and pk_seqali=i}
	    }
	}
    }

    return
}


proc LesSequencesInactives {} {
    set Lv [$::db eval {select pk_seqali from ln_vis_seqali where pk_vis=$pk_vis}]
    set La [$::db eval {select las.pk_seqali from ln_active_seqali as las, active as ac
	where ac.pk_vis=$pk_vis
	and ac.pk_active=las.pk_active
	order by las.pos}]

    set Li [lor $Lv $La]
    return [LesAccessDesSeqali $Li]
}


proc EditeSeq {quoi} {
    global db NomSeqSel LNOrdali

    $db transaction {

    set pk_vue [MacCourant index]
    set pkvo   [VisCourante]
    set pkvm [$db eval {select pk_vis_mere from vis where pk_vis=$pkvo}]
    if {! $pkvm} {
	# Peut pas revenir plus en amont !! Return !
	return
    }

    set Lnow [$db eval {select pk_seqali from ln_vis_seqali where pk_vis=$pkvo order by pos}]
    set Lold [$db eval {select pk_seqali from ln_vis_seqali where pk_vis=$pkvm order by pos}]

    LesDefauts IxVisCourante $pkvm
    DetruitVis $pkvo

    }

    RafraichitAffichage

    set NomSeqSel {}
    if {[llength $Lnow] < [llength $Lold]} {
	set Loff [lor $Lnow $Lold]
	set Laof [LesAccessDesSeqali $Loff]
	foreach n $Laof {
	    lappend NomSeqSel "[expr {[lsearch $LNOrdali $n]+1}].0"
	}
	TagNomsSelectionnes
    }

    return
}


proc EnregistreVis {Ln quoi {Lo {}}} {
    global db

    $db transaction {

    set pk_vue [MacCourant index]
    set pkvo   [VisCourante]
    $db eval {insert into vis values (NULL,$pk_vue, 'tmp', $pkvo)}
    set pk_vis [$db eval {select max(pk_vis) from vis}]
    set Ls [LesIndexsDesSeqs $Ln]
    set Li [$db eval {select pk_seqali from ln_vis_seqali where pk_vis=$pkvo order by pos}]
    switch $quoi {
	"cut" {
	    set Lvis [lor $Li $Ls]
	    set pos 0
	    foreach i $Lvis {
		$db eval {insert into ln_vis_seqali values ($pk_vis,$i,$pos)}
		incr pos
	    }
	    set Lg [LesClusterDeVueClus [MacCourant index] [ClusteringCourant index] index]
	    foreach g $Lg {
		$db eval "delete from ln_seqali_cluster where pk_cluster=$g and pk_seqali in ([join $Ls ,])"
		if {[$db eval {select count(pk_seqali) from ln_seqali_cluster where pk_cluster=$g}] == 0} {
		    $db eval {delete from cluster where pk_cluster=$g}
		}
	    }
	}
	"copy" {}
	"paste" {
	    set Lp [TraiteSequencesAInserer $pkvo $Lo $pk_vue]
	    set pos 0
	    foreach i $Li {
		$db eval {insert into ln_vis_seqali values ($pk_vis,$i,$pos)}
		if {$i eq $Ls} {
		    foreach x $Lp {
			incr pos
			$db eval {insert into ln_vis_seqali values ($pk_vis,$x,$pos)}
		    }
		}
		incr pos
	    }
	    set c [ClusteringCourant index]
	    set g [$db eval {select c.pk_cluster from cluster as c, ln_seqali_cluster as lsc
		where lsc.pk_seqali = $Ls
		and  lsc.pk_cluster = c.pk_cluster
		and c.pk_clustering = $c}]
	    set Li [$db eval {select pk_seqali from ln_seqali_cluster where pk_cluster=$g order by pos}]
	    $db eval {delete from ln_seqali_cluster where pk_cluster=$g}
	    set pos 0
	    foreach i $Li {
		$db eval {insert into ln_seqali_cluster values ($i,$g,$pos)}
		if {$i eq $Ls} {
		    foreach x $Lp {
			incr pos
			$db eval {insert into ln_seqali_cluster values ($x,$g,$pos)}
		    }
		}
		incr pos
	    }
	}
    }
    }

    LesDefauts IxVisCourante $pk_vis

    return
}


proc DetruitVis {v} {
    DetruitSeqVis $v
    $::db eval {delete from vis where pk_vis=$v}

    return
}


proc DetruitSeqVis {v} {
    $::db eval {delete from ln_vis_seqali where pk_vis=$v}
    return
}


proc ChangeVis {v li} {
    DetruitSeqVis $v
    set pos 0
    foreach i $li {
	$db eval {insert into ln_vis_seqali values ($v, $i, $pos)}
	incr pos
    }

    return
}


proc DetruitSeqActive {v} {
    $::db eval {delete from ln_active_seqali where pk_active=$v}
    return
}


proc ChangeActive {v li} {
    DetruitSeqActive $v
    set pos 0
    foreach i $li {
	$db eval {insert into ln_active_seqali values ($v, $i, $pos)}
	incr pos
    }

    return
}


proc TraiteSequencesAInserer {pkvo l pkvue} {
    global db

    foreach e $l {
	lassign $e new nf old
	if {! $nf} {
	    lappend Li [$db eval {select lvs.pk_seqali from ln_vue_seqali as lvs, seqinfo as si, seqali as sa
		where si.access=$new
		and sa.pk_seqinfo=si.pk_seqinfo
		and lvs.pk_vue=$pkvue
		and lvs.pk_seqali=sa.pk_seqali}]
	} else {
	    set L [$db eval {select * from seqinfo where access=$old}]
	    set ins '$new'
	    set pkref [lindex $L 0]
	    foreach e [lrange $L 2 end] {
		if {[string trim $e] eq ""} {
		    lappend ins "NULL"
		} elseif {[string is integer $e] || [string is double $e]} {
		    lappend ins $e
		} else {
		    lappend ins '$e'
		}
	    }
	    $db eval "insert into seqinfo values (NULL,[join $ins ,])"
	    set seq [$db eval {select s.seq from seqali as s, ln_vis_seqali as l
		where s.pk_seqinfo=$pkref
		and       l.pk_vis=$pkvo
		and l.pk_seqali=s.pk_seqali}]

	    set Npki [$db eval {select max(pk_seqinfo) from seqinfo}]
	    $db eval {insert into seqali values (NULL,$Npki,$seq)}
	    set Npks [$db eval {select max(pk_seqali) from seqali}]
	    lappend Li $Npks
	}
    }

    return $Li
}


proc CheckGoodDBType {l} {
    set Lgood [list I R T V P F U 0 1 2 3 4 5 6 7 8 9]
    # un seul caractere, ne peut etre que P I R T
    set Lun [list P I R T]
    # plus que un, prems est :
    set Lprems [list I R T V]
    # et deuxieme est
    set Ldeux  [list F P U 0 1 2 3 4 5 6 7 8 9]

    set lg [llength $l]
    set ix 0
    foreach e $l {
	if {$lg == 1} {
	    if {$e ni $Lun} {
		#puts "bad column type >$e< !!"
	    }
	} else {
	    if {$ix > 0} {
		if {$e ni $Ldeux} {
		    #puts "bad column type >$e< in second place !!"
		}
	    }
	}
    }

    return
}


proc OpenSqliteDB {file {db ""}} {
    package require sqlite3

    if {$db eq ""} {
	after [expr {round(rand()*10)}]
	set db "rootDB_[pid]_[clock microseconds]"
    }
    sqlite3 $db $file

    $db eval "PRAGMA synchronous = OFF"
    $db eval "PRAGMA cache_size = 100000"
    #$db eval "PRAGMA journal_mode = MEMORY"
    $db eval "PRAGMA journal_mode = OFF"

    return $db
}


proc FabriqueDeTables {stab {db ""} {fdb ""} {add 0} {drop 0}} {
    if {$fdb eq "" || $fdb eq "memory"} {
	set fdb ":memory:"
    }
    if {! $add && ! $drop} {
	if {$fdb ne ""} {
	    if {[file exists $fdb]} {
		file delete -force $fdb
	    }
	}
    } else {
	if {! [file exists $fdb]} {
	    FaireLire "File $fdb does not exists !"
	    return
	}
    }
    if {$db eq ""} {
	#set db "rootDB_[pid]_[clock scan now]"
	after 10
	set db "rootDB_[pid]_[clock seconds]"
    }

    sqlite3 $db $fdb
    $db eval {PRAGMA encoding="UTF-8"}
    
    set Lignes [split $stab "\n"]

    foreach elt $Lignes {
	set e [string trim $elt]
	set pC [string index $e 0]
	# comment line
	if {$e eq "" || $pC eq "#"} {
	    continue
	} elseif {$pC eq "-"} {
	    set Luniq {}

	    set nom [StringApres "-" dans $e]
	} elseif {$pC eq "\}"} {
	    if {$drop} {
		$db eval "drop table if exists $nom"
	    }
	    set cmd "create table $nom ("
	    set virgule 0
	    foreach {c tp} $Lcle {
		set openp 0
		set Ltype [split $tp ""]
		CheckGoodDBType $Ltype
		set Lgt [llength $Ltype]
		foreach telt $Ltype {
		    switch -regexp -- $telt {
			"P" {
			    if {$Lgt == 1} {
				set type "INTEGER PRIMARY KEY"
			    } else {
				append type " PRIMARY KEY"
			    }
			}
			"I" {set type "INTEGER"}
			"T" {set type "TEXT"}
			"R" {set type "REAL"}
			"V" {
			    set type "VARCHAR("
			    set openp 1
			}
			{[0-9]} {
			    append type $telt
			}
			"F" {append type " FOREIGN KEY"}
			"U" {lappend Luniq $c}
		    }
		}
		if {$openp} {
		    append type ")"
		    set openp 0
		}
		if {! $virgule} {
		    append cmd "$c $type"
		    set virgule 1
		} else {
		    append cmd ", $c $type"
		}
	    }
	    if {$Luniq != {} } {
		append cmd ", unique ([join $Luniq ,])"
	    }
	    append cmd ")"

	    update idletasks
	    #puts "cmd= $cmd"
	    $db eval "$cmd"
	    set cmd ""
	    set Lcle {}
	} elseif {$pC eq "."} {
	    set cle [StringApres "." dans $e]
	    set type [StringApres "$cle" dans $e]
	    lappend Lcle $cle $type
	}
    }

    return $db
}


proc DumpSqliteDB {{fdb ""}} {
    global db

    catch {puts "\n########################\n[info level -1]\n"}

    if {$fdb ne ""} {
	if {! [file exists $fdb]} {
	    puts "\nfile $fdb does not exists"
	    return
	}
	set db "root_[clock scan now]"
	package require sqlite3
	sqlite3 $db $fdb -readonly 1
    }
    $db transaction {
    set Lt [$db eval {select tbl_name from sqlite_master}]
    foreach table $Lt {
	set result {}
	$db eval "PRAGMA TABLE_INFO($table)" row { lappend result $row(name) $row(type) $row(pk) }
	foreach {n t pk} $result {
	    set v [$db eval "select count($n) from $table "]
	    if {$pk} {
		set pk "PK"
	    } else {
		set pk "  "
	    }
	    puts "\t$n $pk $t $v"
	}
    }
    }
    puts "\n########################\n"

    return
}


proc VersionOrdalieDB {} {
    global db

    # version 1.0 -
    # la table 'ordalie' ne contient pas la colonne
    # 'var'
    set Lcol {}
    $db eval {PRAGMA TABLE_INFO(ordalie)} col { lappend Lcol $col(name) }
    if {[llength $Lcol] == 2} {
	return 1.0
    }

    # Version > 1.0 -
    # la version de la db est dans table ordalie
    set VersionDB [$db eval {select val from ordalie where var='Defauts' and key='VersionDB'}]

    return $VersionDB
}


proc GetTables {{NameStart ""}} {
    return [$::db eval "select distinct(tbl_name) from sqlite_master where (type = \"table\") and (tbl_name like \"${NameStart}%\")"]
}


proc UpgradeOrdaliDB {fold fnew} {
    sqlite old $fold
    sqlite new $fnew

    FabriqueDeTables [set Defauts(TablesDB1.1)] new $fnew

    return
}


proc UpdateDBSeqInfo {} {
    global db TDesAccess TDesBId
    global LNOrdali

    foreach n $LNOrdali {
	set pk [$db eval {select pk_seqinfo from seqinfo where seqname=$n}]
	$db eval "update seqinfo set seqname='$n', access='[set TDesAccess($n)]', bid='[set TDesBId($n)]' where pk_seqinfo=$pk"
    }

    return
}


proc CopyFeaturesToDB {} {
    global TabSF LNOrdali db

    $db transaction {
    set Lfeatvues {}
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}

	set inom [$db eval {select pk_seqinfo from seqinfo where seqname=$n}]

	foreach key [array names TabSF "${n},*"] {
	    lassign [split $key ,] tmp feat
	    set Linsert {}
	    set Linsert_featali {}
	    set Linsert_lnsf {}
	    set Lseen {}
	    foreach f [set TabSF($key)] {
		DecortiqueUneFeature $f dg fg color score note csys
		if {$note eq ""} {
		    set note "NULL"
		    }

		#set pk [$db eval {select pk_seqfeat from seqfeat where fstart=$dg and fstop=$fg and fcolor=$color and fscore=$score and fnote=$note and fcsys=$csys}]
		set fcurr [list $dg $fg $color $score $note $csys]
		set pk [lsearch $Lseen $fcurr]
		# already seen
			if {$pk == -1} {
			    lappend Lseen $fcurr
			    # dans seqfeat, met feature orig.
			    #$db eval {insert into seqfeat values (NULL,$inom, $feat, $dg, $fg, $color, $score, $note, $csys)}
			    lappend Linsert_seqfeat "(NULL,$inom,$feat,$dg,$fg,$color,$score,$note,$csys)"
			}
		$db eval "insert into featali values [join $Linsert ,]"
		incr i
	    }
	    }
    }
    }

    return
}


proc MetAJourTableFeatures {{pkm ""}} {
    global TabSF LNOrdali db ListePDB

    # pkm : snapshot auquel les features (featali) sont liees.
    # Les seqali sont partagees entre snapshots, le lien
    # seqali/featali porte donc le snapshot.
    # Sans pkm, seules les features d'origine (seqfeat) sont
    # enregistrees (le snapshot les enregistrera depuis TabSF).

    #$db eval "PRAGMA cache_size = 100000"
    #$db eval "PRAGMA journal_mode = MEMORY"
    #$db eval "PRAGMA journal_mode = OFF"
    $db transaction {

    # tables possiblement deja remplies
    set pk_seqfeat [$db eval {select coalesce(max(pk_seqfeat),0) from seqfeat}]
    set pk_featali [$db eval {select coalesce(max(pk_featali),0) from featali}]
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}

	set inom [$db eval {select pk_seqinfo from seqinfo where seqname=$n}]
	set IsPDB [expr {[string trim $n] in $ListePDB}]
	if {$IsPDB} {
	    set mol [DonneIdDeAccessPDB $n]
	    set chn [DonneChainDeAccessPDB $n]
	}

	foreach key [array names TabSF "${n},*"] {
	    lassign [split $key ,] tmp feat

	    set Linsert_seqfeat {}
	    set Linsert_featali {}
	    set Linsert_lnsf {}
	    # features deja vues pour cette seq et ce type :
	    # SeenOri en coords d'origine, SeenAli en coords
	    # alignement. Les features ne doivent pas etre
	    # doublonnees.
	    set SeenOri [dict create]
	    set SeenAli [dict create]
	    foreach f [set TabSF($key)] {
		DecortiqueUneFeature $f dg fg color score note csys
		if {$score eq "" || ! [string is double $score]} {
		    set score 0.0
		}
		if {$note eq ""} {
		    set note "NULL"
		}

		# skip exact duplicate
		set fori [list $dg $fg $color $score $note $csys]
		if {[dict exists $SeenOri $fori]} {
		    continue
		}
		dict set SeenOri $fori 1

		# dans seqfeat, met feature orig.
		incr pk_seqfeat
		#$db eval {insert into seqfeat values ($pk_seqfeat,$inom, $feat, $dg, $fg, $color, $score, $note, $csys)}
		lappend Linsert_seqfeat "($pk_seqfeat,$inom,'$feat',$dg,$fg,'$color',$score,'$note','$csys')"
		
		# Features sont exprimees en
		# coords. de la seq ou global
		# selon fcsys et commencant a 1.
		# Pour PDB, on N'EST PAS en
		# coords. PDB, mais coords.
		# "normales"
		# (seq commence a 1)
		if {$csys eq "local"} {
		    if {$IsPDB} {
			set dg [$mol CoordsSeq2PDB $chn $dg]
			set fg [$mol CoordsSeq2PDB $chn $fg]
		    } else {
			# ramene start a 0
			incr dg -1
			incr fg -1
		    }

		    set dg [DonnePosSG $n $dg]
		    set fg [DonnePosSG $n $fg]
		} else {
		    # deja en coords globales.
		    # xml commence a 1
		    incr dg -1
		    incr fg -1
		}

		# Skip feature if problem with
		# start and stop.
		if {$pkm ne "" && $dg ne "" && $fg ne ""} {
		    # check if already present
		    #set pk [$db eval {select pk_featali from featali where fstart=$dg and fstop=$fg and fcolor=$color and fscore=$score and fnote=$note and fcsys=$csys}]
		    # (lsearch donnait l'index dans la liste,
		    # pas le pk_featali : un doublon etait lie
		    # a la feature d'une autre sequence)
		    set fcurr [list $dg $fg $color $score $note $csys]
		    if {[dict exists $SeenAli $fcurr]} {
			continue
		    }
		    incr pk_featali
		    dict set SeenAli $fcurr $pk_featali
		    lappend Linsert_featali "($pk_featali,'$feat',$dg,$fg,'$color',$score,'$note','$csys')"
		    #$db eval {insert into featali values ($pk_featali, $feat, $dg, $fg, $color, $score, $note, $csys)}
		    lappend Linsert_lnsf "($inom,$pk_featali,$pkm)"
		    #$db eval {insert into ln_seqali_featali values ($inom,$pk)}
		}
	    }
	    if {$Linsert_seqfeat != {}} {
		$db eval "insert into seqfeat values [join $Linsert_seqfeat ,]"
	    }
	    if {$Linsert_featali != {}} {
		$db eval "insert into featali values [join $Linsert_featali ,]"
	    }
	    if {$Linsert_lnsf != {}} {
		$db eval "insert into ln_seqali_featali values [join $Linsert_lnsf ,]"
	    }
	}
    }
    }

    return
}


proc RemapFeatures {s} {
    global TabSF

    # 1  4   8  11
    # ---XXXXX--XXX--
    # XXXXXXXX--
    # 1      8

    set o -1
    for {set n 0} {$n < [string length $s]} {incr n} {
	if {[string index $s $n] ne "."} {
	    incr o
	}
	set H($o) $n
    }

    array set newT {}
    foreach key [array names TabSF] {
	set newF {}
	set Lft [set TabSF($key)]
	foreach f $Lft {
	    DecortiqueUneFeature $f fstart fstop fcolor fscore fnote fcsys
	    set nstart [set H($fstart)]
	    set nstop  [set H($fstop)]
	    lset f 1 $nstart
	    lset f 3 $nstop
	    lappend newF $f
	}
	set newT($key) $newF
    }
    unset -nocomplain TabSF
    array set TabSF [array get newT]

    update

    return
}


proc toord {} {
    CreeLeOrd ordalie.ord
    exit
}



