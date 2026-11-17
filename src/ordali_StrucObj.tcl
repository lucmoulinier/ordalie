
#
#
#
#
# --- ordali_StrucObj.tcl
#

proc SetupPDBObject {} {
    InitChemicals
    
    oo::class create Structure {
	destructor {
	    # the sqlite db in memory is a global command : it would
	    # outlive the object. No db yet if the object is being built,
	    # already renamed after CopiePDB, hence the catch.
	    my variable db
	    if {[info exists db]} {
		catch {$db close}
	    }
	}
    }

    
    oo::define Structure method nom {} {
	#rR cree par #rR
	#lm pdbId always in upper case
	set nom [string toupper [self]]
	if {[string range $nom 0 1] eq "::"} {
	    return [string range $nom 2 end]
	} else {
	    return $nom
	}
    }
    
    
    oo::define Structure method asym {chaine {AouL ""}} {
	#rR cree par #rR
	#rR On s'emmèle toujours les pédales avec le nom de chaine Label ou Auth

	if {$chaine=="AsymAndEntities"} {
	    if {[my cifFile]==""} { return "" }
	    return [Cif AsymAndEntities . [my cifFile]]
	}

	if {[my cifFile]==""} { return $chaine }

	#rR Dans le Cif on a les 2 !
	if {$AouL==""} { set AouL "L" }
	
	return [CifAsym $chaine $AouL [my cifFile]]
    }

    
	    oo::define Structure method cifFile {{Value ""}} {
	#rR cree par #rR
	my variable CifFile
	if {$Value!=""} { set CifFile $Value }
	if { ! [info exists CifFile]} { return "" }
	return $CifFile
    }
    
	    #rR Modifie par rR
	    #rR J'ai repris la version pour PDB et y ai inséré ce qu'il faut pour traiter un fichier Cif
	    #rR Si on traite un PDB fichierCif est vide ... et ne sert pas. Mais on le voit dans le code (désolé)
    #rR Il exists la méthode cifFile qui renvoie le fichier cif s'il est utilisé mais on ne s'en sert pas trop,
    #rR   c'est plutôt la variable fichierCif qui est utilisée
    oo::define Structure method new {idOrFileOrData {chn ""} {initFromDB 0} {storeInDB 0}} {
	my variable StrucID NomAtm NomRes1l NmrRes ChnIdn AtmXYZ AtmBQ Superseeded Obsolete Rot Trans DbRef
	
	# Inits
		set Rot [list 1,1 1.0 1,2 0.0 1,3 0.0 2,1 0.0 2,2 1.0 2,3 0.0 3,1 0.0 3,2 0.0 3,3 1.0]
	set Trans [list 1 0.0 2 0.0 3 0.0]
		
		# Arguments
		# - idOrFileOrData : file or text or lines or id
		# - initFromDB : 1 -> load from db, 0 load from <idOrFileOrData>
		if {$initFromDB eq ""} {
	    set initFromDB 0
	}
	# - storeInDB : 1 store in db, 0 don't
	if {$storeInDB eq ""} {
	    set storeInDB 1
	}

	if {$initFromDB} {
	    my UpdateFromDB
	    set cok [list StrucID $StrucID]
	    return $cok
	}

	if {[regexp "\n" $idOrFileOrData]} {
	    set Llignes [split $idOrFileOrData \n]
	    set src "text"
	} elseif {[llength $idOrFileOrData] > 1} {
	    set Llignes $idOrFileOrData
	    set src "list"
	} elseif {[file extension $idOrFileOrData] eq ""} {
	    set id $idOrFileOrData
	    set id [string toupper $id]
	    # This can be a PDB or UniProt or Alphafold ID
	    if {[EstUnAccessPDB $id]} {
		set textePDB [TextePDB $id ALL "" "ForceWeb"]
		if {[string first "DOCTYPE" $textePDB] > -1 && [string first "\<html" $textePDB] > -1} {
		    set cok [list Error "retreive PDB ID"]
		    return $cok
		}
		set Llignes [split $textePDB \n]
		if {$Llignes eq "ERREUR" || $Llignes eq ""} {
		    set cok [list Error "empty PDB ID"]
		    return $cok
		}
	    } elseif {[EstUnUniProt $id]} {
		# retreive corresponding AlphaFold
		set Llignes [GetAlphafoldFromUniprot $id cif]
		if {$Llignes == {}} {
		    set cok [list Error "retreiving Alphafold from uniprot"]
		    return $cok
		}
	    }
	    set src "download"
	} elseif {[file extension $idOrFileOrData] in {".cif" ".mmcif"}} {
	    set fichierCif $idOrFileOrData
	    if { ! [file exists $fichierCif]} {
		set cok [list Error "no CIF file"]
		return $cok
	    }
	    my cifFile $fichierCif
	    set Llignes [LesLignesDuFichier $fichierCif]
	    set src "cif"
	} else {
	    set fichierPdb $idOrFileOrData
	    if { ! [file exists $fichierPdb]} {
		set cok [list Error "no PDB file"]
		return $cok
	    }
	    set Llignes [LesLignesDuFichier $fichierPdb]
	    set src "file"
	}

	set cok [my _DecortiqueUneStructureObject $Llignes [my cifFile]]
	lassign $cok what desc
	if {$what eq "Error"} {
	    return $cok
	}

	if {$storeInDB} {
	    my _RemplitLeSQL $src
	}

	if {$Obsolete != 0} {
	    return [list "Obsolete" [list $StrucID $Obsolete]]
	}

	set cok [list StrucID $StrucID]

	return $cok
    }


    #rR modifie par #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR
    #rR la deuxième partie est celle qui traite pdb
	    proc CIFrR_reader_kept {} {
	    if {0}  {
		set ChnIdn {}
		set NFois 99999999
		foreach {LA} [CifAsym ListOf LabelAuth $fichierCif] {
		    lassign $LA Label Auth
		    set Asym $Auth
		    set ChaineVoulue $Asym
		    set polymer [CifAsym $Label Polymer]
		    puts "polymer $polymer"
		    if { ! $polymer} {
			continue
		    }
		    set LignesAtomPdbLike [CifAsym $Label AtomPdbLike $fichierCif]
		    puts "[join $LignesAtomPdbLike \n]\n"
		    my _LectureDeChainePdbObject $LignesAtomPdbLike $polymer
		    
		    if {[incr NFois -1]<=0} {
			break
		    }
		}
	    }
	return
    }

    oo::define Structure method PeelPDB {Llignes {fichierCif ""}} {
	my variable StrucID Header Site TypChn TypRes AtmNA ChnIdn NomRes1l NomRes3l NmrRes AtmXYZ AtmBQ NomAtm Superseeded Obsolete DbRef Lkp SeqAdv

	set Header [ExtraitHeadDuPDB $Llignes]
	# Extract ID from first line
	set Hline [lsearch -regexp -inline $Header  {^HEADER }]
	if {$Hline ne ""} {
	    set StrucID [string trim [string range $Hline 62 65]]
	    if {$StrucID eq ""} {
		# No PDB regular ID, may be alphafold 
		set Line [lsearch -regexp -inline $Header {AF-[A-Za-z0-9]+-F[0-9]+}]
		if {$Line ne ""} {
		    regexp {(AF-[A-Za-z0-9]+-F[0-9]+)} $Line -> StrucID
		}
	    }
	}

	set lignesPDB [ExtraitLignesAtomesDuPDB $Llignes]
	if {$lignesPDB == -1} {
	    puts "\nNo ATOM lines !"
	    return [list Error "No ATOM lines"]
	}
	
	# Is this entry superseeded ?
	set Superseeded [my _superseed $Header]
	# Is this entry obsolete ?
	set Obsolete [my _obsolete $Header]
	
	set ChnIdn {}
	# Treat chains one after another
	set Lter [lsearch -regexp -all $lignesPDB {^TER}]
	set Lter [linsert $Lter 0 "0"]
	set Lter [linsert $Lter end "end"]
	set LterAr [lrange $Lter 1 end]
	set d [lindex $Lter 0]
	set Ieme 0
	foreach f $LterAr {
	    incr Ieme
	    set deb $d
	    set fin $f
	    if {$deb != 0} {
		incr deb
	    }
	    if {$fin ne "end"} {
		incr fin -1
	    }
	    
	    set LLignesChn [lrange $lignesPDB $deb $fin]
	    if {$LLignesChn == {}} {
		set d $f
		continue
	    }
	    if {[lsearch -regexp $LLignesChn {^ATOM  }] != -1} {
		set polymer 1
	    } else {
		set polymer 0
	    }
		
	    my _LectureDeChainePdbObject $LLignesChn $polymer
	    set d $f
	}
	
	# Retreive Active Site
	set Site [ExtraitSiteActifDuPDB $Header]

	# Retreive SEQADV cards (contains mutations...)
	my _LectureSeqAdv
	
	# Retreive DBREF, UniProt or SwissProt for each chain
	foreach c $ChnIdn {
	    set DbRef($c) [ExtraitDbRefDuPdb $Header $c]
	}
	
	# retreive organism (per chain)
	my _LectureSource $fichierCif

	    # define type of chains from SEQRES
	my _LectureSeqRes $Header $fichierCif
	my _ExtraitSecStrucPDB

	return
    }
    

    oo::define Structure method _DecortiqueUneStructureObject {Llignes {fichierCif ""}} {
	my variable StrucID Header Site TypChn TypRes AtmNA ChnIdn NomRes1l NomRes3l NmrRes AtmXYZ AtmBQ NomAtm Superseeded Obsolete DbRef Lkp SeqAdv
	
	set Obsolete 0
	set StrucID ""

	if {$fichierCif!="" || ! [regexp {^HEADER } [lindex $Llignes 0]]} {
	    my PeelCIF $Llignes
	} else {
 	    my PeelPDB $Llignes
	}
	set ChnIdn [lunique $ChnIdn]
    

	if {$Obsolete != 0} {
	    return [list "Obsolete" $Obsolete]
	}

	# Check that each chain has a type
	foreach c $ChnIdn {
	    if {! [info exists TypChn($c)] || [set TypChn($c)] eq ""} {
		set TypChn($c) [DonneChaineType [set TypRes($c)]]
	    }
	}
	
	if {! [EstUnAccessPDB $StrucID] && ! [EstUnUniProt $StrucID]} {
	    foreach c $ChnIdn {
		if {$TypChn($c) eq "Protein" && [info exists DbRef($c)]} {
		    set StrucID $DbRef($c)
		}
	    }
	}

	# Create lookup for residue number
	foreach chn $ChnIdn {
	    set i 1
	    foreach r [my _resnumber -chain $chn -polymer] {
		set Lkp($chn,$r) $i
		incr i
	    }
	}
	
	return [list StrucID $StrucID]
    }

    # ------------------------------------------------------------------
    # Lecture des fichiers mmCIF (anciennement src/ordali_cif.tcl, qui
    # etait charge par 'source' depuis un chemin en dur a chaque lecture
    # d'un CIF). Integre ici dans SetupPDBObject avec les autres methodes.
    # ------------------------------------------------------------------


    oo::define Structure method PeelCIF {Lignes} {
        my variable SecStr StrucID ChnIdn NomRes1l NomRes3l NmrRes TypRes NomAtm AtmXYZ AtmBQ AtmNA Site \
                    Obsolete Superseeded DbRef SeqRes

        # ------------------------------------------------------------------
        # Initialize instance variables
        # ------------------------------------------------------------------
        set StrucID          ""
        set ChnIdn      {}
        set Obsolete    0
        set Superseeded 0
        array set DbRef       {}

        array unset SecStr 
        array unset SeqRes
        array unset NomRes1l
        array unset NomRes3l
        array unset NmrRes
        array unset TypRes
        array unset NomAtm
        array unset AtmXYZ
        array unset AtmBQ
        array unset AtmNA
        array unset Site

        # ------------------------------------------------------------------
        # Internal helper : tokenize one CIF line
        # Handles plain tokens, 'quoted', "quoted" strings
        # ------------------------------------------------------------------
        proc TokenizeCIFLine {line} {
            set tokens {}
            set i      0
            set len    [string length $line]

            while {$i < $len} {
                set c [string index $line $i]

                if {$c eq " " || $c eq "\t"} { incr i; continue }
                if {$c eq "#"} break

                if {$c eq "'"} {
                    set j [string first "'" $line [expr {$i + 1}]]
                    if {$j < 0} { set j $len }
                    lappend tokens [string range $line [expr {$i+1}] [expr {$j-1}]]
                    set i [expr {$j + 1}]
                    continue
                }

                if {$c eq "\""} {
                    set j [string first "\"" $line [expr {$i + 1}]]
                    if {$j < 0} { set j $len }
                    lappend tokens [string range $line [expr {$i+1}] [expr {$j-1}]]
                    set i [expr {$j + 1}]
                    continue
                }

                set j $i
                while {$j < $len} {
                    set nc [string index $line $j]
                    if {$nc eq " " || $nc eq "\t"} break
                    incr j
                }
                lappend tokens [string range $line $i [expr {$j-1}]]
                set i $j
            }

            return $tokens
        }

        # ------------------------------------------------------------------
        # Internal helper : get field value by column name from a data row
        # Returns "" for missing, "." or "?" values
        # ------------------------------------------------------------------
        proc GetCIFField {row col_names field_name} {
            set idx [lsearch -exact $col_names $field_name]
            if {$idx < 0} { return "" }
            set val [lindex $row $idx]
            if {$val eq "." || $val eq "?"} { return "" }
            return $val
        }

        # ------------------------------------------------------------------
        # Internal helper : collect one full data row from a loop
        # Handles multi-line ; text blocks and values split across lines
        # Advances index variable in caller scope
        # ------------------------------------------------------------------
        proc CollectCIFRow {lines_var idx_var ncols} {
            upvar $lines_var lines
            upvar $idx_var   i

            set values {}
            set n      [llength $lines]

            while {[llength $values] < $ncols && $i < $n} {
                set line    [lindex $lines $i]
                set trimmed [string trim $line]

                if {[string index $line 0] eq ";"} {
                    set text [string range $line 1 end]
                    incr i
                    while {$i < $n} {
                        set bline [lindex $lines $i]
                        if {[string trim $bline] eq ";"} { incr i; break }
                        append text "\n" $bline
                        incr i
                    }
                    lappend values $text
                    continue
                }

                if {$trimmed eq "loop_" || $trimmed eq "#"} break
                if {[string index $trimmed 0] eq "_"}       break
                if {$trimmed eq ""}                         { incr i; continue }

                foreach tok [TokenizeCIFLine $trimmed] {
                    if {[llength $values] < $ncols} {
                        lappend values $tok
                    }
                }
                incr i
            }

            return $values
        }

        # ------------------------------------------------------------------
        # Internal helper : flush accumulated atoms of the current residue
        # into the per-chain arrays, then reset accumulators
        # ------------------------------------------------------------------
        proc FlushResidue {chain_var LAtmNm_var LAtmNA_var LAtmXYZ_var LAtmBQ_var
                           NomAtm_var AtmNA_var AtmXYZ_var AtmBQ_var} {
            upvar $chain_var   prevChain
            upvar $LAtmNm_var  LAtmNm
            upvar $LAtmNA_var  LAtmNA
            upvar $LAtmXYZ_var LAtmXYZ
            upvar $LAtmBQ_var  LAtmBQ
            upvar $NomAtm_var NomAtm
            upvar $AtmNA_var   AtmNA
            upvar $AtmXYZ_var  AtmXYZ
            upvar $AtmBQ_var   AtmBQ

            if {$prevChain ne "" && [llength $LAtmNm] > 0} {
                lappend NomAtm($prevChain) $LAtmNm
                lappend AtmNA($prevChain)   $LAtmNA
                lappend AtmXYZ($prevChain)  $LAtmXYZ
                lappend AtmBQ($prevChain)   $LAtmBQ
            }
            set LAtmNm  {}
            set LAtmNA  {}
            set LAtmXYZ {}
            set LAtmBQ  {}

    	return
        }

        set n [llength $Lignes]

    # ==================================================================
        # PASS 1 : extract entry ID, Obsolete (= replacing ID), DbRef
        #
        # Obsolete = "" if structure is current
        # Obsolete = replacing PDB ID if structure is obsolete
        # ==================================================================
        set i 0
        while {$i < $n} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            # Data block ID (first fallback for StrucID)
            if {[regexp {^data_} $trimmed]} {
                set StrucID [string trim \
                    [string range $trimmed [expr {[string first "_" $trimmed]+1}] end]]
            }

            # Entry ID (authoritative)
            if {[regexp {^_entry\.id\s+(\S+)} $trimmed -> val]} {
                set StrucID [string trim $val "'\""]
            }

            # Obsolete : key-value form outside a loop
            # _pdbx_database_status.status gives OBS/REL/etc.
            # _pdbx_database_PDB_obs_spr.replace_pdb_id gives the replacing ID
            if {[regexp {^_pdbx_database_PDB_obs_spr\.pdb_id\s+(\S+)} \
    		 $trimmed -> val]} {
    	    set val [string toupper [string trim $val "'\""]]
    	    if {$val ne $StrucID && $val ne ""} {
    		set Obsolete $val
    	    }
            }

            # UniProt accession — key-value form (AlphaFold or single-chain)
            if {[regexp {^_struct_ref\.pdbx_db_accession\s+(\S+)} $trimmed -> val]} {
                set acc [string trim $val "'\""]
    	    set DbRef(A) $acc
            }

            # Loop_ handling
            if {$trimmed eq "loop_"} {
                set j [expr {$i + 1}]
                while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
                set peek [string trim [lindex $Lignes $j]]

                # ---- _pdbx_database_PDB_obs_spr loop ----
                # Contains the replacing PDB ID when structure is obsolete
                if {[string match "_pdbx_database_PDB_obs_spr.*" $peek]} {
                    set i $j
                    set cols {}
                    while {$i < $n && [string match "_pdbx_database_PDB_obs_spr.*" \
                            [string trim [lindex $Lignes $i]]]} {
                        lappend cols [string trim [lindex $Lignes $i]]
                        incr i
                    }
                    set ncols [llength $cols]
                    while {$i < $n} {
                        set t [string trim [lindex $Lignes $i]]
                        if {$t eq "loop_" || $t eq "#" || \
                                [string index $t 0] eq "_"} break
                        if {$t eq ""} { incr i; continue }
                        set row [CollectCIFRow Lignes i $ncols]
                        set rep [GetCIFField $row $cols \
                            "_pdbx_database_PDB_obs_spr.replace_pdb_id"]
                        if {$rep ne ""} {
                            set Obsolete [string toupper $rep]
                        }
                    }
                    continue
                }

                # ---- _struct_ref loop (UniProt accession, multi-chain) ----
                if {[string match "_struct_ref.*" $peek]} {
                    set i $j
                    set cols {}
                    while {$i < $n && [string match "_struct_ref.*" \
                            [string trim [lindex $Lignes $i]]]} {
                        lappend cols [string trim [lindex $Lignes $i]]
                        incr i
                    }
                    set ncols [llength $cols]
                    while {$i < $n} {
                        set t [string trim [lindex $Lignes $i]]
                        if {$t eq "loop_" || $t eq "#" || \
                                [string index $t 0] eq "_"} break
                        if {$t eq ""} { incr i; continue }
                        set row [CollectCIFRow Lignes i $ncols]
                        set entity [GetCIFField $row $cols "_struct_ref.entity_id"]
                        set db  [GetCIFField $row $cols "_struct_ref.db_name"]
                        set acc [GetCIFField $row $cols \
                            "_struct_ref.pdbx_db_accession"]
                        if {[string toupper $db] eq "UNP" && $acc ne ""} {
                            #if {$acc ni $DbRef} { lappend DbRef $acc }
    			set DbRef($entity) $acc
                        }
                    }
                    continue
                }
            }

            incr i
        }


    # ==================================================================
        # PASS 1b : secondary structure
        #
        # Sources in mmCIF :
        #   _struct_conf       : helices (HELX_P) and turns (TURN_P)
        #   _struct_sheet_range: beta strands
        #
        # SecStr($chain) is a list of dicts, each describing one SS element:
        #   type  : "helix", "sheet" or "turn"
        #   start : first residue number (auth)
        #   end   : last  residue number (auth)
        #   id    : element identifier (helix id or sheet/strand id)
        # ==================================================================
        set iHelix 0
        set iTurn 0
        set iSheet 0
    
        set i 0
        while {$i < $n} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            if {$trimmed ne "loop_"} { incr i; continue }

            set j [expr {$i + 1}]
            while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
            set peek [string trim [lindex $Lignes $j]]

            # ----------------------------------------------------------------
            # _struct_conf : helices and turns
            # ----------------------------------------------------------------
            if {[string match "_struct_conf.*" $peek]} {
                set i $j
                set cols {}
                while {$i < $n && [string match "_struct_conf.*" \
                        [string trim [lindex $Lignes $i]]]} {
                    lappend cols [string trim [lindex $Lignes $i]]
                    incr i
                }
                set ncols [llength $cols]
                while {$i < $n} {
                    set t [string trim [lindex $Lignes $i]]
                    if {$t eq "loop_" || $t eq "#" || \
                            [string index $t 0] eq "_"} break
                    if {$t eq ""} { incr i; continue }

                    set row [CollectCIFRow Lignes i $ncols]

                    set conf_type [GetCIFField $row $cols "_struct_conf.conf_type_id"]
                    set ss_id     [GetCIFField $row $cols "_struct_conf.id"]
                    set chain_beg [GetCIFField $row $cols "_struct_conf.beg_auth_asym_id"]
                    set chain_end [GetCIFField $row $cols "_struct_conf.end_auth_asym_id"]
                    set res_beg   [GetCIFField $row $cols "_struct_conf.beg_auth_seq_id"]
                    set nom_beg   [GetCIFField $row $cols "_struct_conf.beg_auth_comp_id"]
                    set res_end   [GetCIFField $row $cols "_struct_conf.end_auth_seq_id"]
                    set nom_end   [GetCIFField $row $cols "_struct_conf.end_auth_comp_id"]
                    set hel_length [GetCIFField $row $cols "_struct_conf.pdbx_PDB_helix_length"]

                    if {$chain_beg eq "" || $res_beg eq "" || $res_end eq ""} {
    		    continue
    		}
                    # Determine SS type from conf_type_id
                    # HELX_P = helix, TURN_P = turn, STRN = strand (rare here)
    		set conf_type [string toupper $conf_type]
                    switch -glob -- $conf_type {
    		    "HELX_P" {set sstype "Alpha"}
    		    "HELX_RH_AL_P" {set sstype "Alpha"}
    		    "HELX_RH_3T_P" {set sstype "3_10"}
    		    "HELX_LH_PP_P" {set sstype "polyP"}
    		    "HELX_OT_P" {set sstype "AlphaBis"}
    		    "HELX_RH_310_P" {set sstype "3_10"}
    		    "HELX_RH_PI_P" {set sstype "Pi"}
    		    "HELX_LH_P" {set sstype "Left"}
                        "TURN*" {set sstype "Turn"}
                        "STRN*" { set sstype "sheet" }
                        default { set sstype "Alpha" }
                    }

    		if {[string first "HEL" $conf_type] > -1} {
    		    set Element "Helix"
    		    set iElt [incr iHelix]
    		} elseif {[string first "TURN" $conf_type] > -1} {
    		    set Element "Turn"
    		    set iElt [incr iTurn]
    		} elseif {[string first "STRN" $conf_type] > -1} {
    		    # AlphaFold : no _struct_sheet_range, strands are here
    		    set Element "Sheet"
    		    set iElt [incr iStrand]
    		} else {
    		    set Element "PasBon"
    		    continue
    		}

    		if {$Element eq "Sheet"} {
    		    set entry "Sheet $ss_id $iElt $chain_beg $res_beg $nom_beg $res_end $nom_end 1"
    		} else {
    		    set entry "$Element $sstype $iElt $chain_beg $res_beg $nom_beg $res_end $nom_end $hel_length"
    		}

                    # An element may span two chains (rare) — add to both
    	    lappend SecStr($chain_beg) $entry
    	    if {$chain_end ne $chain_beg && $chain_end ne ""} {
                        lappend SecStr($chain_end) $entry
                    }
                }
                continue
            }

            # ----------------------------------------------------------------
            # _struct_sheet_range : beta strands
            # ----------------------------------------------------------------
            if {[string match "_struct_sheet_range.*" $peek]} {
                set i $j
                set cols {}
                while {$i < $n && [string match "_struct_sheet_range.*" \
                        [string trim [lindex $Lignes $i]]]} {
                    lappend cols [string trim [lindex $Lignes $i]]
                    incr i
                }
                set ncols [llength $cols]

                while {$i < $n} {
                    set t [string trim [lindex $Lignes $i]]
                    if {$t eq "loop_" || $t eq "#" || \
                            [string index $t 0] eq "_"} break
                    if {$t eq ""} { incr i; continue }

                    set row [CollectCIFRow Lignes i $ncols]

                    set sheet_id  [GetCIFField $row $cols "_struct_sheet_range.sheet_id"]
                    set strand_id [GetCIFField $row $cols "_struct_sheet_range.id"]
                    set chain_beg [GetCIFField $row $cols "_struct_sheet_range.beg_auth_asym_id"]
                    set chain_end [GetCIFField $row $cols "_struct_sheet_range.end_auth_asym_id"]
                    set res_beg   [GetCIFField $row $cols "_struct_sheet_range.beg_auth_seq_id"]
                    set nom_beg   [GetCIFField $row $cols "_struct_sheet_range.beg_auth_comp_id"]
                    set res_end   [GetCIFField $row $cols "_struct_sheet_range.end_auth_seq_id"]
                    set nom_end   [GetCIFField $row $cols "_struct_sheet_range.end_auth_comp_id"]

                    if {$chain_beg eq "" || $res_beg eq "" || $res_end eq ""} continue

                    set entry "Sheet $sheet_id $strand_id $chain_beg $res_beg $nom_beg $res_end $nom_end 1"

                    lappend SecStr($chain_beg) $entry
                    if {$chain_end ne $chain_beg && $chain_end ne ""} {
                        lappend SecStr($chain_end) $entry
                    }
                }
                continue
            }

            incr i
        }
    

        # ==================================================================
        # PASS 2 : entity type mapping and asym mapping
        # ==================================================================
        array set entity_type {}
        array set asym_entity {}

        set i 0
        while {$i < $n} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            if {$trimmed ne "loop_"} { incr i; continue }

            set j [expr {$i + 1}]
            while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
            set peek [string trim [lindex $Lignes $j]]

            # ---- _entity loop ----
            if {[string match "_entity.*" $peek]} {
                set i $j
                set cols {}
                while {$i < $n && [string match "_entity.*" \
                        [string trim [lindex $Lignes $i]]]} {
                    lappend cols [string trim [lindex $Lignes $i]]
                    incr i
                }
                set ncols [llength $cols]
                while {$i < $n} {
                    set t [string trim [lindex $Lignes $i]]
                    if {$t eq "loop_" || $t eq "#" || [string index $t 0] eq "_"} break
                    if {$t eq ""} { incr i; continue }
                    set row  [CollectCIFRow Lignes i $ncols]
                    set eid  [GetCIFField $row $cols "_entity.id"]
                    set etype [GetCIFField $row $cols "_entity.type"]
                    if {$eid ne "" && $etype ne ""} {
                        set entity_type($eid) $etype
                    }
                }
                continue
            }

            # ---- _struct_asym loop ----
            if {[string match "_struct_asym.*" $peek]} {
                set i $j
                set cols {}
                while {$i < $n && [string match "_struct_asym.*" \
                        [string trim [lindex $Lignes $i]]]} {
                    lappend cols [string trim [lindex $Lignes $i]]
                    incr i
                }
                set ncols [llength $cols]
                while {$i < $n} {
                    set t [string trim [lindex $Lignes $i]]
                    if {$t eq "loop_" || $t eq "#" || [string index $t 0] eq "_"} {
    		    break
    		}
    		if {$t eq ""} { incr i; continue }
                    set row [CollectCIFRow Lignes i $ncols]
                    set aid [GetCIFField $row $cols "_struct_asym.id"]
                    set eid [GetCIFField $row $cols "_struct_asym.entity_id"]
                    if {$aid ne "" && $eid ne ""} {
                        set asym_entity($aid) $eid
                    }
                }
                continue
            }

            incr i
        }

    # ==================================================================
        # PASS 2b : SeqRes — sequence equivalent of PDB SEQRES records
        #
        # Strategy :
        #   _entity_poly_seq  : entity_id -> ordered list of residue names
        #   _pdbx_poly_seq_scheme : entity_id -> auth_asym_id (chain mapping)
        #
        # Result : SeqRes($chain) = list of residue names in sequence order
        # ==================================================================

        # Step 1 : collect residue sequence per entity_id from _entity_poly_seq
        array set entity_seq {}

        set i 0
        while {$i < $n} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            if {$trimmed ne "loop_"} { incr i; continue }

            set j [expr {$i + 1}]
            while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
            set peek [string trim [lindex $Lignes $j]]

            if {![string match "_entity_poly_seq.*" $peek]} { incr i; continue }

            # Collect column headers
            set i $j
            set cols {}
            while {$i < $n && [string match "_entity_poly_seq.*" \
                    [string trim [lindex $Lignes $i]]]} {
                lappend cols [string trim [lindex $Lignes $i]]
                incr i
            }
            set ncols [llength $cols]

            # Parse rows — one row per residue position
            while {$i < $n} {
                set t [string trim [lindex $Lignes $i]]
                if {$t eq "loop_" || $t eq "#" || [string index $t 0] eq "_"} break
                if {$t eq ""} { incr i; continue }

                set row     [CollectCIFRow Lignes i $ncols]
                set eid     [GetCIFField $row $cols "_entity_poly_seq.entity_id"]
                set monomer [GetCIFField $row $cols "_entity_poly_seq.mon_id"]

                if {$eid ne "" && $monomer ne ""} {
                    lappend entity_seq($eid) $monomer
                }
            }
            # Found and parsed the loop — no need to continue scanning
            break
        }

        # Step 2 : map entity_id -> auth_asym_id via _pdbx_poly_seq_scheme
        # We only need the first occurrence of each entity to get the chain mapping
        array set entity_to_chains {}

        set i 0
        while {$i < $n} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            if {$trimmed ne "loop_"} { incr i; continue }

            set j [expr {$i + 1}]
            while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
            set peek [string trim [lindex $Lignes $j]]

            if {![string match "_pdbx_poly_seq_scheme.*" $peek]} { incr i; continue }

            set i $j
            set cols {}
            while {$i < $n && [string match "_pdbx_poly_seq_scheme.*" \
                    [string trim [lindex $Lignes $i]]]} {
                lappend cols [string trim [lindex $Lignes $i]]
                incr i
            }
            set ncols [llength $cols]

            while {$i < $n} {
                set t [string trim [lindex $Lignes $i]]
                if {$t eq "loop_" || $t eq "#" || [string index $t 0] eq "_"} break
                if {$t eq ""} { incr i; continue }

                set row   [CollectCIFRow Lignes i $ncols]
                set eid   [GetCIFField $row $cols "_pdbx_poly_seq_scheme.entity_id"]
                set chain [GetCIFField $row $cols "_pdbx_poly_seq_scheme.pdb_strand_id"]

                # pdb_strand_id is the auth_asym_id equivalent
                if {$eid ne "" && $chain ne ""} {
                    if {![info exists entity_to_chains($eid)] || \
                            $chain ni $entity_to_chains($eid)} {
                        lappend entity_to_chains($eid) $chain
                    }
                }
            }
            break
        }

        # Step 3 : populate SeqRes — one entry per chain
        foreach eid [array names entity_seq] {
            if {![info exists entity_to_chains($eid)]} continue
            foreach chain $entity_to_chains($eid) {
                # Each chain gets its own copy of the sequence list
                set SeqRes($chain) $entity_seq($eid)
            }
        }
    
        # ==================================================================
        # PASS 3 : _atom_site loop — main coordinate data
        # ==================================================================
        set i            0
        set first_model  ""
        set stop_parsing 0

        while {$i < $n && !$stop_parsing} {
            set line    [lindex $Lignes $i]
            set trimmed [string trim $line]

            if {$trimmed ne "loop_"} { incr i; continue }

            set j [expr {$i + 1}]
            while {$j < $n && [string trim [lindex $Lignes $j]] eq ""} { incr j }
            if {![string match "_atom_site.*" [string trim [lindex $Lignes $j]]]} {
                incr i; continue
            }

            set i $j
            set cols {}
            while {$i < $n && [string match "_atom_site.*" \
                    [string trim [lindex $Lignes $i]]]} {
                lappend cols [string trim [lindex $Lignes $i]]
                incr i
            }
            set ncols     [llength $cols]
            set has_model [expr {[lsearch -exact $cols \
                "_atom_site.pdbx_PDB_model_num"] >= 0}]

            # Per-residue accumulator — reset on each new (chain, resnum) pair
            set prevChain  ""
            set prevResnum ""
            set LAtmNm    {}
            set LAtmNA    {}
            set LAtmXYZ   {}
            set LAtmBQ    {}

            while {$i < $n} {
                set t [string trim [lindex $Lignes $i]]

                if {$t eq "loop_" || $t eq "#" || [string index $t 0] eq "_"} break
                if {$t eq ""} { incr i; continue }

                set row [CollectCIFRow Lignes i $ncols]
                if {[llength $row] == 0} continue

                # Keep first model only
                if {$has_model} {
                    set model_num [GetCIFField $row $cols \
                        "_atom_site.pdbx_PDB_model_num"]
                    if {$first_model eq ""} {
                        set first_model $model_num
                    } elseif {$model_num ne $first_model} {
                        set stop_parsing 1
                        break
                    }
                }

                # Skip hydrogen atoms
                set element [GetCIFField $row $cols "_atom_site.type_symbol"]
                if {$element eq "H" || $element eq "D"} continue
                set aname [GetCIFField $row $cols "_atom_site.label_atom_id"]
                if {[string index $aname 0] eq "H"} continue

                # Extract fields
                set group    [GetCIFField $row $cols "_atom_site.group_PDB"]
                set atom_id  [GetCIFField $row $cols "_atom_site.id"]
                set resname  [GetCIFField $row $cols "_atom_site.label_comp_id"]
                set chain    [GetCIFField $row $cols "_atom_site.auth_asym_id"]
                set resnum   [GetCIFField $row $cols "_atom_site.auth_seq_id"]
                set ins_code [GetCIFField $row $cols "_atom_site.pdbx_PDB_ins_code"]
                set lasym    [GetCIFField $row $cols "_atom_site.label_asym_id"]
                set x        [GetCIFField $row $cols "_atom_site.Cartn_x"]
                set y        [GetCIFField $row $cols "_atom_site.Cartn_y"]
                set z        [GetCIFField $row $cols "_atom_site.Cartn_z"]
                set q        [GetCIFField $row $cols "_atom_site.occupancy"]
                set b        [GetCIFField $row $cols "_atom_site.B_iso_or_equiv"]

                if {$group ne "ATOM" && $group ne "HETATM"} continue
                if {$ins_code ne ""} { append resnum $ins_code }

                # Determine residue type for this specific atom/residue
                set rtype "ligand"
                if {$group eq "ATOM"} {
                    set rtype "polymer"
                } elseif {$resname eq "HOH" || $resname eq "WAT"} {
                    set rtype "water"
                } elseif {[info exists asym_entity($lasym)]} {
                    set eid $asym_entity($lasym)
                    if {[info exists entity_type($eid)]} {
                        switch -glob -- $entity_type($eid) {
                            "polymer" { set rtype "polymer" }
                            "water"   { set rtype "water"   }
                            default   { set rtype "ligand"  }
                        }
                    }
                }

                # Register new chain
                if {$chain ni $ChnIdn} {
                    lappend ChnIdn  $chain
                    set Site($chain) {}
                }

                # ----------------------------------------------------------
                # Detect residue boundary : chain or resnum changed
                # Flush previous residue's atoms, register new residue
                # ----------------------------------------------------------
                if {$chain ne $prevChain || $resnum ne $prevResnum} {

                    FlushResidue prevChain \
                        LAtmNm LAtmNA LAtmXYZ LAtmBQ \
                        NomAtm AtmNA AtmXYZ AtmBQ

                    # Register new residue metadata
                    lappend NomRes1l($chain)   [AutreCodeLuc $resname]
                    lappend NomRes3l($chain)   $resname
                    lappend NmrRes($chain) $resnum
                    lappend TypRes($chain)   [DonneResidueType $resname]

                    if {$resnum ni $Site($chain)} {
                        lappend Site($chain) $resnum
                    }

                    set prevChain  $chain
                    set prevResnum $resnum
                }

                # Accumulate atoms for the current residue
                # atom names in PDB format (4 characters,
                # e.g. " CA "), as expected by the whole
                # drawing code
                lappend LAtmNm  [NomAtomeFormatPDB $aname $element]
                # atomic number (as the PDB reader), not the
                # serial number _atom_site.id
                lappend LAtmNA  [NoAtomicDe $element]
                lappend LAtmXYZ [list $x $y $z]
                lappend LAtmBQ  [list $b $q]
            }

            # Flush the very last residue
            FlushResidue prevChain \
                LAtmNm LAtmNA LAtmXYZ LAtmBQ \
                NomAtm AtmNA AtmXYZ AtmBQ
        }

        # ------------------------------------------------------------------
        # Clean up helper procs
        # ------------------------------------------------------------------
        rename TokenizeCIFLine ""
        rename GetCIFField     ""
        rename CollectCIFRow   ""
        rename FlushResidue    ""
    }

    # Turn types defined by '_struct_conf.comp_type_id'
    # TURN_P : Coude / Turn générique (très fréquent).
    # TURN_TY1_P : Coude de Type I (Type I turn).
    # TURN_TY1P_P : Coude de Type I' (Type I prime turn).
    # TURN_TY2_P : Coude de Type II (Type II turn).
    # TURN_TY2P_P : Coude de Type II' (Type II prime turn).
    # TURN_TY3_P : Coude de Type III (Type III turn).

    #rR modifie par #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR #rR 
    oo::define Structure method _LectureDeChainePdbObject {LesLignes Polymer} {
	my variable NomAtm TypRes NomRes1l NomRes3l NmrRes ChnIdn AtmXYZ AtmBQ AtmNA
	
	set ChaineCourant -1
	set ResiduCourant -999
	set AlterLocRes ""
	set CC ""
	set Latmn {}
	set Latmx {}
	set Latmb {}
	set Latmz {}
	foreach ligne $LesLignes {
	    
	    if {[regexp "\t" $ligne]} {
		#rR rajouté par #rR
		#rR on vient d'un CIF
		lassign [split $ligne "\t"] ATOM AtomId AtomName NomRes3L ChainIdent ResidueNumber x y z q b AtomNA
		if {[EstUnNucleotide $AtomName]} {
		    set NomRes1L [string index $NomRes3L end]
		} else {
		    set NomRes1L [AutreCodeLuc $NomRes3L]
		}
		set AtomXYZ  [list $x $y $z]
		set AtomBQ   [list $b $q]
		set AtomNA   [NoAtomicDe $AtomNA]
	    } else {
		set ee " $ligne"
		set AtomName      [string range $ee 13 16]
		#set AlterLocRes   [string index $ee 17]
		set NomRes3L      [string range $ee 18 20]
		#rR j'ai rajouté ça car pour les nucléotides ça marchait pas
		if {[EstUnNucleotide [string trim $AtomName]]} {
		    set NomRes1L [string index $NomRes3L end]
		} else {
		    set NomRes1L [AutreCodeLuc $NomRes3L]
		}
		set ChainIdent    [string index $ee 22]
		scan              [string range $ee 23 27] "%s" ResidueNumber
		scan              [string range $ee 31 54] "%8f%8f%8f" x y z
		set AtomXYZ       [list $x $y $z]
		scan              [string range $ee 55 66] "%6f%6f" q b
		set AtomBQ        [list $b $q]
		set AtomNA        [NoAtomicDe [string trim [string range $ee 77 78]]]
	    }
	    if {$AtomNA == 0 || $AtomNA == {}} {
		#puts "[self] AtomicNumber [string trim [string range $ee 77 78]] atm $AtomName chn >>$ChainIdent<< res $ResidueNumber res3l >$NomRes3L< >$NomRes1L<"
	    }
	    
	    ## ATTENTION !!
	    # Cette version ne lit pas les hydrogenes 
	    if {$AtomNA == 1} {continue}
	    
	    # if {$AlterLocRes ne ""} {continue}
	    if {$ResiduCourant == -999} {
		set ResiduCourant $ResidueNumber
		set CC $ChainIdent
		if {$Polymer} {
		    set tyres [DonneResidueType $NomRes3L]
		} else {
		    set tyres "ligand"
		}
	    }
	    if {$ResidueNumber != $ResiduCourant || $ChainIdent ne $CC} {
		if {$Polymer} {
		    set tyres [DonneResidueType $N3LCou]
		    # check atom ordering. 
		    # important for drawing.
		    if {$tyres eq "Nucleic" && ([lindex $Latmn 0] ne " P  " || [lindex $Latmn 0] ne " O3P")} {
			lassign [ReordonneNucleotide $Latmn $Latmx $Latmb $Latmz] Latmn Latmx Latmb Latmz
		    }
		} else {
		    set tyres "ligand"
		}
		lappend NomRes1l($CC) $N1LCou
		lappend NomRes3l($CC) $N3LCou
		lappend TypRes($CC)   $tyres		
		lappend NmrRes($CC)   $ResiduCourant
		lappend NomAtm($CC)   $Latmn
		lappend AtmXYZ($CC)   $Latmx
		lappend AtmBQ($CC)    $Latmb
		lappend AtmNA($CC)    $Latmz
		
		set Latmn {}
		set Latmx {}
		set Latmb {}
		set Latmz {}
		if {$ChainIdent ne $ChaineCourant} {
		    lappend ChnIdn $ChainIdent
		    set ChaineCourant $ChainIdent
		    set CC $ChainIdent
		}
	    }
	    
	    lappend Latmn $AtomName
	    lappend Latmx $AtomXYZ
	    lappend Latmb $AtomBQ
	    lappend Latmz $AtomNA
	    
	    set ResiduCourant $ResidueNumber
	    set N3LCou $NomRes3L
	    set N1LCou $NomRes1L
	}
	#    lappend ChnIdn $CC
	lappend NomRes1l($CC) $N1LCou
	lappend NomRes3l($CC) $N3LCou
	lappend TypRes($CC)   $tyres
	lappend NmrRes($CC)   $ResiduCourant
	lappend NomAtm($CC)   $Latmn
	lappend AtmXYZ($CC)   $Latmx
	lappend AtmBQ($CC)    $Latmb
	lappend AtmNA($CC)    $Latmz

	return
    }

    #rR a corrigé avec le test de Nucleic
    oo::define Structure method _LectureSeqRes {LesLignes {fichierCif ""}} {
	my variable TypChn SeqRes TypRes ChnIdn
	if {$fichierCif!=""} {
	    foreach c $ChnIdn {
		set L [CifAsym $c Label $fichierCif]
		set SRL [CifAsym $L SeqResL]		
		set SeqRes($c) {}
		foreach res $SRL {
		    set Type [DonneResidueType $res]
		    if {$Type=="Nucleic"} {
			set r1 [string index $res end]
		    } else {
			set r1 [AutreCodeLuc $res]
		    }
		    if {$r1 eq "XXX"} {set r1 X}
		    lappend SeqRes($c) $r1
		}
	    }
	    return "SeqRes fait via Cif"
	}
	

	#la suite est pour pdb
	set Li [lsearch -all -regexp $LesLignes {^SEQRES } ]
	foreach i $Li {
	    set l " [lindex $LesLignes $i]"
	    set c [string index $l 12]
	    for {set x 20} {$x < 70} {incr x 4} {
		set res [string trim [string range $l $x $x+2]]
		if {$res eq ""} {break}
		set Type [DonneResidueType $res]
		lappend TypChn($c) $Type
		if {$Type=="Nucleic"} {
		    set r1 [string index $res end]
		} else {
		    set r1 [AutreCodeLuc $res]
		}
		if {$r1 eq "XXX"} {set r1 X}
		lappend SeqRes($c) $r1
	    }
	}
	foreach c [array names TypChn] {
	    set TypChn($c) [DonneChaineType [set TypChn($c)]]
	}
	
	return
    }
    
    
    oo::define Structure method title {} {
	my variable Header

	set titre ""
	foreach l $Header {
	    if {[regexp {^TITLE } $l]} {
		append titre [string range $l 5 end]
	    }
	}

	return $titre
    }

    oo::define Structure method strucid {} {
	my variable StrucID
	return $StrucID
    }


	oo::define Structure method dbref {chn} {
	my variable DbRef
	if {[info exists DbRef($chn)]} {
	    return [set DbRef($chn)]
	} else {
	    return {"" ""}
	}
    }

    oo::define Structure method PDBInfos {chn {fichierCif ""}} {
	my _SetupForDisplay
	my _cleanSecStr

	return
    }

    oo::define Structure method UpdateFromDB {} {
	my variable db StrucID Header Site TypChn AtmNA ChnIdn NomRes1l NomRes3l NmrRes AtmXYZ AtmBQ NomAtm TypRes

	# ORD files saved before the mmCIF reader fix (2026-10-20)
	# hold the atom serial number instead of the atomic number :
	# take it back from the atom name
	if {[$db onecolumn {select max(na) from atoms}] > 109} {
	    $db function NoAtomicDeNomPDB -deterministic NoAtomicDeNomPDB
	    $db eval {update atoms set na = NoAtomicDeNomPDB(aname)}
	}
	# and the quotes of the atom names doubled (" O5''" for " O5'")
	# by _RemplitLeSQL, before 2026-10-21
	$db eval {update atoms set aname = replace(aname,'''''','''') where instr(aname,'''''') > 0}
	$db eval {update objetinit set label = replace(label,'''''','''') where instr(label,'''''') > 0}

	$db eval {begin transaction}

	set nom  [my nom]
	set StrucID $nom
	set pkp [$db eval {select pk_pdb from pdb where name=$nom}]
	set Header {*}[$db eval {select header from pdb where name=$nom}]
	foreach {pkc chn ctype} [$db eval {select pk_chains, name, type from chains where pk_pdb=$pkp}] {
	    lappend ChnIdn $chn
	    lappend TypChn($chn) $ctype

	    foreach {n1l n3l nmr type} [$db eval {select rname1l, rname3l, rnbr, type from residues where pk_chains=$pkc order by pk_residues}] {
		lappend NomRes1l($chn) $n1l
		lappend NomRes3l($chn) $n3l
		lappend NmrRes($chn) [string trimleft $nmr 0]
		lappend TypRes($chn) $type
	    }

	    set lxyz {}
	    set lbq  {}
	    set lna  {}
	    set latn {}
	    set pkold -1
	    foreach {pkr atn ax ay az ab aq ana} [$db eval {select pk_residues, aname, x, y, z, b, q, na from atoms where pk_chains=$pkc order by pk_atoms}] {
		if {$pkr != $pkold} {
		    if {$pkold != -1} {
			lappend NomAtm($chn) $latn
			lappend AtmXYZ($chn) $lxyz
			lappend AtmBQ($chn) $lbq
			lappend AtmNA($chn) $lna
			
			set lxyz {}
			set lbq  {}
			set lna  {}
			set latn {}
		    }
		    set pkold $pkr
		}
		lappend lxyz [list $ax $ay $az]
		lappend lbq  [list $ab $aq]
		lappend lna  $ana
		lappend latn $atn
	    }
	    lappend NomAtm($chn) $latn
	    lappend AtmXYZ($chn) $lxyz
	    lappend AtmBQ($chn) $lbq
	    lappend AtmNA($chn) $lna
	}
	$db eval {commit}
	update

	my _Dimensions

	# as when reading a PDB/CIF file : data derived
	# from the header (stored in the db). Without it
	# the secondary structure is lost when reading
	# an ORD file.
	my variable DbRef SecStr
	set Site [ExtraitSiteActifDuPDB $Header]
	my _LectureSeqAdv
	foreach c $ChnIdn {
	    set DbRef($c) [ExtraitDbRefDuPdb $Header $c]
	}
	unset -nocomplain SecStr
	if {[$db exists {select 1 from sqlite_master where type='table' and name='secstr'}]} {
	    # saved by serializeDB (ORD file)
	    foreach {chn entry} [$db eval {select chain, entry from secstr order by rowid}] {
		lappend SecStr($chn) $entry
	    }
	} else {
	    my _ExtraitSecStrucPDB
	}

	return
    }
    
    
    oo::define Structure method _RemplitLeSQL {source} {
	my variable StrucID TypRes NmrRes NomRes1l NomRes3l NomAtm AtmXYZ ChnIdn AtmBQ AtmNA TypChn Header db
	global Defauts

	set nom $StrucID
	set nom [my nom]
	if {[string range $nom 0 1] eq "::"} {
	    set nom [string range $nom 2 end]
	}

	# database not open, create it
	if {"db" ni [info object vars [self]]} {
	    set handle "OrdDB_root_pdb${nom}_[clock scan now]"
	    set db [FabriqueDeTables [set ::Defauts(TablesPDB)] $handle memory]
	}

	#set cdef [set Defauts(CoulVariable)]
	set cdef "couldefond"

	$db eval {begin transaction}
	$db eval {insert into pdb values(NULL,$nom,$source,$Header)}
	set pkp [$db last_insert_rowid]
	foreach n $ChnIdn {
	    if {[info exists TypChn($n)]} {
		set Ct [set TypChn($n)]
	    } else {
		set Ct "Water"
	    }
		if {$Ct eq "DNA" || $Ct eq "Water"} {
		continue
	    }

	    $db eval {insert into chains values (NULL,$pkp,$n,$Ct)}
	    set pkc [$db last_insert_rowid]

	    set Lr1 [set NomRes1l($n)]
	    set Lr3 [set NomRes3l($n)]
	    set Lrn [set NmrRes($n)]
	    set Lrt [set TypRes($n)]
	    set LLa [set NomAtm($n)]
	    set LLx [set AtmXYZ($n)]
	    set LLb [set AtmBQ($n)]
	    set LLz [set AtmNA($n)]
	    
	    foreach r1 $Lr1 r3 $Lr3 rn $Lrn rt $Lrt La $LLa Lx $LLx Lb $LLb Lz $LLz {
		set dbrn [format "%08s" $rn]
		$db eval {insert into residues values(NULL,$pkp,$pkc,$r1,$r3,$dbrn,$rt)}
		set pkr [$db last_insert_rowid]

		foreach a $La p $Lx f $Lb na $Lz {
		    lassign $p x y z
		    lassign $f b q
		    # no quote doubling : $a is given to sqlite as a
		    # variable, not inside a literal SQL string

		    set label "[string trim $a] $r3 ${n}${rn}"

		    if {$a eq "" || $x eq ""} {
			#puts "sql $n,$Ct,$dbrn,$r3"
		    }
		    $db eval {insert into atoms values(NULL,$pkp,$pkc,$pkr,$a,$x,$y,$z,$b,$q,$na)}
		    
		    set cola [CouleurDeAtome $a]
		    $db eval {insert into objetinit values (NULL,$pkp,$pkc,$pkr,0,0,0,$cdef,0,$cdef,0,$cola, 0,0,0,$label)}
		}
	    }
	}

	$db eval {commit}

	my _Dimensions
	update

	return
    }


    oo::define Structure method bbox {} {
	my variable Size
	return [list $Size(xmin) $Size(xmax) $Size(ymin) $Size(ymax) $Size(zmin) $Size(zmax)]
    }


    oo::define Structure method _Dimensions {} {
	my variable StrucID Size db

	set pdb $StrucID
	set pdb [my nom]
	set sdb $db

	$sdb eval {begin transaction}
	set pkp [$sdb eval {select pk_pdb from pdb where name=$pdb}]
	lassign [$sdb eval {select min(x),min(y),min(z) from atoms where pk_pdb=$pkp}] Size(xmin) Size(ymin) Size(zmin)
	lassign [$sdb eval {select max(x),max(y),max(z) from atoms where pk_pdb=$pkp}] Size(xmax) Size(ymax) Size(zmax)
	$sdb eval {commit}

	set Size(xc) [expr {($Size(xmin)+$Size(xmax))/2.}]
	set Size(yc) [expr {($Size(ymin)+$Size(ymax))/2.}]
	set Size(zc) [expr {($Size(zmin)+$Size(zmax))/2.}]

	return
    }


    oo::define Structure method setboite {obj chn} {
	set obj [BonObjName $obj]
	my variable AtmXYZ $obj

	dict set $obj FlagBox 1
	
	return
    }


    oo::define Structure method _drawBoite {obj chn} {
	set obj [BonObjName $obj]
	my variable AtmXYZ $obj

	if {! [dict get [set $obj] FlagBox]} {return}

	# calcule la boite
	file delete -force vec.dat
	file delete -force vec.out

	set f [open "vec.dat" w]
	foreach lx [set AtmXYZ($chn)] {
	    foreach e $lx {
		puts $f "[join $e]"
	    }
	}
	close $f

	if {[catch {set log [exec 3DToParallelepiped vec.dat vec.out]} Msg]} {
	    puts "Error computing box !\n$Msg"
	    return
	}
	
	set Lb [LesLignesDuFichier vec.out]
	lassign $Lb a1 b1 c1 d1 a2 b2 c2 d2
	
	glEnable GL_BLEND
	glBlendFunc GL_SRC_ALPHA GL_ONE

	#    glColor3f 1.0 1.0 0.0
	set col [list 0.37 0.5 1.0 0.1]
	FacesDuCube $col $a1 $b1 $c1 $d1 $a2 $b2 $c2 $d2
	
	glColor3f 1.0 0.0 0.0
	AretesDuCube $a1 $b1 $c1 $d1 $a2 $b2 $c2 $d2

	glDisable GL_BLEND

	return
    }

    
    oo::define Structure method _superseed {header} {
	set i [lsearch -regexp $header {^SPRSDE}]
	if {$i != -1} {
	    set l " [lindex $header $i]"
	    set newid [string toupper [lindex [split $l] end]]
	    if {$newid eq [my nom]} {
		return 0
	    } else {
		return $newid
	    }
	} else {
	    return 0
	}
    }
    
    
    oo::define Structure method _obsolete {header} {
	# If Obsolete the current ID has been removed from the PDB and has been replaced
	set i [lsearch -regexp $header {^OBSLTE}]
	if {$i != -1} {
	    set l [lindex $header $i]
	    regsub { +} [string trim $l] " " l
	    set newid [string toupper [lindex [split $l " "] end]]
	    if {$newid eq [my nom]} {
		return 0
	    } else {
		return $newid
	    }
	} else {
	    return 0
	}
    }
    
    oo::define Structure method _lookup {c r} {
	my variable Lkp

	if {[info exists Lkp($c,$r)]} {
	    return $Lkp($c,$r)
	} else {
	    return ""
	}
    }
    
    oo::define Structure method _seqadv {c} {
	my variable SeqAdv
	
	set Lret {}
	foreach adv $SeqAdv {
	    lassign $adv nm1 chn
	    if {$chn eq $c} {
		lappend Lret $adv
	    }
	}

	return $Lret
    }
    
    oo::define Structure method _source {c {type "All"}} {
	my variable Source

	if {$type=="All"} {
	    return [list [my _source $c OrgSc] [my _source $c OrgTx]]
	}
	if {[regexp -nocase {x}     $type]} { set type "OrgTx" }
	if {[regexp -nocase {[scn]} $type]} { set type "OrgSc" }

	if {[info exists Source($c,$type)]} { return $Source($c,$type) }
	return ""
	
	#rR reste obsolete
	set ret ""
	switch $type {
	    "taxid" {set ret [set Source($c,OrgTx)]}
	    "orga"  {set ret [set Source($c,OrgSc)]}
	}
	
	return $ret
    }
    
    oo::define Structure method _LectureSource {{fichierCif ""} {Auth ""}} {
	my variable Source Header ChnIdn

	if {$fichierCif!=""} {
	    set LesId {}
	    foreach Ligne [AboutOrganismsInCifFile $fichierCif] {
		set LesMots [split $Ligne "\t"]
		foreach {K V} $LesMots {
		    if {$K=="entity"} {
			set Id $V
			lappend LesId $Id
			continue
		    }
		    if {$V=="?"} { continue }
		    if {[regexp -nocase TaxId $K]} { lappend LesOrgTx($Id) "$V FoundIn $K"}
		    if {[regexp -nocase Name  $K]} { lappend LesOrgSc($Id) "$V FoundIn $K"}
		}
	    }
	    foreach Id $LesId {
		foreach Asym [CifEntity $Id ListOf AsymAuth] {
		    if { ! [info exists LesOrgTx($Id)]} {
			set Source($Asym,OrgTx) -1
		    } else {
			set Source($Asym,OrgTx) $LesOrgTx($Id)
		    }
		    if { ! [info exists LesOrgSc($Id)]} {
			set Source($Asym,OrgSc) -1
		    } else {
			set Source($Asym,OrgSc) $LesOrgSc($Id)
		    }
		}
	    }
	    return [array get Source]
	}

	#rR la suite est pour PDB	
	# init
	foreach c $ChnIdn {
	    set Source($c,OrgSc) "unknown"
	    set Source($c,OrgTx) -1
	}

	# first, get chains by mol_id
	set Lm [lsearch -all -regexp $Header {^COMPND.+MOL_ID:}]
	set Lc [lsearch -all -regexp $Header {^COMPND.+CHAIN:}]
	foreach m $Lm c $Lc {
	    set molid [lindex $Header $m]
	    set molid [string trim [string range $molid [string first "MOL_ID:" $molid]+7 end]]
	    # remove ;
	    regsub -all ";" $molid "" molid
	    
	    set chain [lindex $Header $c]
	    set chain [string trim [string range $chain [string first "CHAIN:" $chain]+6 end]]
	    # remove ';' and space
	    regsub -all { +|;} $chain "" chain
	    set Lchn [split $chain ,]
	    set mol($molid) $Lchn
	}

	# now retrieve sources
	set Lm [lsearch -all -regexp $Header {SOURCE.+MOL_ID:}]
	foreach m $Lm {
	    set j $m
	    set ligne [lindex $Header $j]
	    set molid [string trim [string range $ligne [string first "MOL_ID:" $ligne]+7 end]]
	    set molid [string range $molid 0 end-1]
	    incr j
	    set ligne [lindex $Header $j]
	    while {[string range $ligne 0 5] eq "SOURCE" || [string first "MOL_ID:" $ligne] != -1} {
		if {[set iosc [string first "ORGANISM_SCIENTIFIC:" $ligne]] != -1} {
		    set osc [string trim [string range $ligne $iosc+20 end]]
		    set osc [string range $osc 0 end-1]
		    foreach c $mol($molid) {
			set Source($c,OrgSc) $osc
		    }
		} elseif {[set iotx [string first "ORGANISM_TAXID:" $ligne]] != -1} {
		    set otx [string trim [string range $ligne $iotx+15 end]]
		    set otx [string range $otx 0 end-1]
		    foreach c $mol($molid) {
			set Source($c,OrgTx) $otx
		    }
		}
		incr j
		set ligne [lindex $Header $j]
	    }
	}
	return
    }

    oo::define Structure method _LectureSeqAdv {} {
	my variable Header SeqAdv
	
	set SeqAdv {}
	foreach l $Header {
	    if {[string range $l 0 5] ne "SEQADV"} {
		continue
	    }
	    # file format description starts at 1
	    set l " $l"

	    set nm1 [string range $l 13 15]
	    set chn [string index $l 17]
	    set rn1 [string range $l 19 22]
	    set rn1 [string trim $rn1]
	    set alt [string index $l 23]
	    set alt [string trim $alt]
	    set db  [string range $l 25 28]
	    set db  [string trim $db]
	    set acc [string range $l 30 38]
	    set acc [string trim $acc]
	    set nm2 [string trim [string range $l 40 42]]
	    set rn2 [string trim [string range $l 44 48]]
	    set rn2 [string trim $rn2]
	    set cft [string trim [string tolower [string range $l 50 70]]]
	    
	    # the conflict (cft) can be :	   
	    # - Cloning artifact
	    # - Expression tag
	    # - Conflict
	    # - Engineered
	    # - Variant  
	    # - Insertion
	    # - Deletion
	    # - Microheterogeneity
	    # - Chromophore
	    # 
	    # 'microheterogeneity' is when a 
	    # residue in PDB differs from the 
	    # corresponding UniPort reference prot

	    set item [list $nm1 $chn "${rn1}$alt" $db $acc $nm2 $rn2 $cft]
	    lappend SeqAdv $item
	}

	return $SeqAdv
    }
    oo::define Structure method _SetupForDisplay {} {
	my variable NmrRes NomRes1l ChnIdn EqResType Header DictDesObjets ResSel ResCol NomRes3l
	global Defauts

	if {[info exists EqResType]} {
	    return
	}

	set EqResType [dict create]
	foreach c $ChnIdn {
	    foreach e [set NmrRes($c)] t [set NomRes3l($c)] {
		set ResSel($c,$e) 0
		set ResCol($c,$e) [set Defauts(CoulVariable)]
		dict lappend EqResType "$t" "$c,$e"
	    }
	}

	dict set DictDesObjets Index 0

	return
    }


    oo::define Structure method SecStr {args} {
	my variable SecStr NomRes1l

	if {! [llength $args]} {
	    return ""
	}
	
	set i [lsearch $args "-chain"]
	if {$i == -1} {
	    puts "Error ! no >>-chain<< card !"
	    return
	}
	set c [lindex $args $i+1]
	if {! [info exists NomRes1l($c)]} {
	    puts "Error ! Chain >>$c<< does not exists"
	    return
	}
	
	if {[info exists SecStr($c)]} {
	    return $SecStr($c)
	}

	return {}
    }
    
    
    oo::define Structure method SSBin {type chn} {
	my variable SSBin

	if { ! [info exists SSBin($chn)]} { return "" }

	switch [string tolower $type] {
	    "helix" { set i 0 }
	    "sheet" { set i 1 }
	    "turn"  { set i 2 }
	}
	return [lindex $SSBin($chn) $i]
    }


    oo::define Structure method _ExtraitSecStrucPDB {} {
	my variable ChnIdn SSBin SecStr Header Lkp
	
	set MolId [DonneIdDeAccessPDB [self]]
	set SStmp {}
	set ToutesLesLignes $Header
	set chn ""
	foreach l $ToutesLesLignes {
	    set t [string range $l 0 4]
	    switch $t {
		"HELIX" {set lss [LitHelixDansPDB $l $chn]}
		"SHEET" {set lss [LitSheetDansPDB $l $chn]}
		"TURN " {set lss [LitTurnDansPDB  $l $chn]}
		default {continue}
	    }
	    if {$lss eq "PasBon"} {
		continue
	    }
	    regsub -all { +} [string trim $lss] " " ss
	    DecortiqueSS $ss Elmt NomChnDep NmrResDep NmrResFin Rmk
	    lappend SecStr($NomChnDep) $ss
	}

	return
    }


    oo::define Structure method _cleanSecStr {} {
	my variable ChnIdn SecStr SSBin Lkp SecStrRaw

	# keep the raw secondary structure (SecStr is
	# replaced below) : saved in ORD files, and
	# restored at each call, so that a new call (e.g.
	# after adding a structure) does not work on an
	# already cleaned SecStr (SSBin was lost)
	if {! [info exists SecStrRaw] && [array exists SecStr]} {
	    array set SecStrRaw [array get SecStr]
	} elseif {[info exists SecStrRaw]} {
	    unset -nocomplain SecStr
	    array set SecStr [array get SecStrRaw]
	}

	set molid [my nom]
	if {! [info exists ::LNOrdali]} {
	    # we're not in Ordali, ....
	    set InOrdali 0
	} else {
	    set InOrdali 1
	}

	foreach chn $ChnIdn {
	    if {! [info exists SecStr($chn)]} {
		continue
	    }

	    if {[EstUnUniProt $molid]} {
		set mol ${molid}_$chn
	    } else {
		set mol [BonNomPDB ${molid}_$chn]
	    }

	    # SSBin est indexe comme Deb/Fin ci-dessous :
	    # colonnes de l'alignement dans Ordali, rang
	    # du residu dans la chaine sinon
	    set Lres [my _resnumber -chain $chn -polymer]
	    if {$InOrdali} {
		set Long [LongueurDeLAlignement]
		# chain not in the alignment (e.g. chain
		# not kept when adding a structure) : no
		# position to compute, don't call DonnePosSG
		# on a missing sequence
		set InAli [info exists ::Sequences($mol)]
	    } else {
		set Long [llength $Lres]
	    }
	    set ssbh [string repeat "0" $Long]
	    set ssbs [string repeat "0" $Long]
	    set ssbt [string repeat "0" $Long]
	    set SStmp {}
	    foreach ss $SecStr($chn) {
		DecortiqueSS $ss Elmt NomChnDep NmrResDep NmrResFin Rmk
	
		if {$InOrdali} {
		    if {! $InAli} {
			continue
		    }
		    set Deb [DonnePosSG $mol $NmrResDep]
		    set Fin [DonnePosSG $mol $NmrResFin]
		} else {
		    # lookup commence a 1, ramene a 0
		    if {! [info exists Lkp($chn,$NmrResDep)]} {
			set Deb ""
		    } else {
			set Deb [expr {[set Lkp($chn,$NmrResDep)]-1}]
		    }
		    
		    if {! [info exists Lkp($chn,$NmrResFin)]} {
			set Fin ""
		    } else {
			set Fin [expr {[set Lkp($chn,$NmrResFin)]-1}]
		    }
		}
	    
		if {$Deb eq "" || $Fin eq ""} {
		    continue
		}
		# element kept (it was never added : SecStr became a
		# single Coil covering the whole chain)
		lappend SStmp $ss

		switch $Elmt {
		    "Alpha" {
			set ssbh [MetDesUnsDansSS $ssbh $Deb $Fin]
		    }
		    "Sheet" {
			set ssbs [MetDesUnsDansSS $ssbs $Deb $Fin]
		    }
		    "Turn" {
			set ssbt [MetDesUnsDansSS $ssbt $Deb $Fin]
		    }
		}
	    }
	
	    set SStmp [lsort -integer -index 4 $SStmp]
	    set SStmp [CombleSSParCoil $SStmp $molid $chn]
	    set SecStr($chn) $SStmp
	    set SSBin($chn) [list $ssbh $ssbs $ssbt]
	}

	return
    }
    
    
    oo::define Structure method _DefinitTypeRes {s p c} {
	my variable TypRes

	set id [string first 0 $p]
	set if [string last  0 $p]
	if {$id == -1} {
	    set type [DefinitTypeSeq $s]
	    set TypRes($c) [lrepeat [string length $s] $type]

	    return
	}

	set nlg [expr {$if - $id + 1}]
	set llg [lrepeat $nlg "ligand"]
	if {$id == 0} {
	    set sub [string range $s [expr {$if+1}] end]
	    set type [DefinitTypeSeq $sub]
	    set TypRes($c) [concat $llg [lrepeat [string length $sub] $type]]
	} else {
	    set sub [string range $s 0 [expr {$id-1}]]
	    set type [DefinitTypeSeq $sub]
	    set TypRes($c) [concat [lrepeat [string length $sub] $type] $llg]
	}

	set p [join [set TypRes($c)] ""]
	set p [string map [list "Protein" "P" "ligand" "l"] $p]
	set l [string length $p]
	set i 0
	while {0 && $i < $l} {
	    set f [expr {$i + 59}]
	    incr i 60
	}

	return
    }


    oo::define Structure method _SetB {d f B c} {
	my variable AtmBQ db

	set pdb [my nom]

	if {$c eq ""} {set c "a"}
	if {$d eq "all"} {
	    set Add ""
	} else {
	    set deb [format "%08s" $d]
	    set fin [format "%08s" $f]
	    set Add "and r.rnbr >= '$deb' and r.rnbr <= '$fin' "
	}

	$db eval {begin transaction}
	set La [$db eval "select a.pk_atoms from atoms as a, residues as r, chains as c, pdb as p where a.pk_residues = r.pk_residues and r.pk_chains=c.pk_chains and c.name='$c' and r.pk_pdb = p.pk_pdb and p.name='$pdb' $Add"]
	
	$db eval "update atoms set b=$B where pk_atoms in ([join $La ,])"
	$db eval {commit}

	return
    }


    oo::define Structure method center {} {
	my variable Size
	return [list $Size(xc) $Size(yc) $Size(zc)]
    }


    oo::define Structure method radius {} {
	my variable Size
	return $Size(Rad)
    }


    oo::define Structure method _chains {{args ""}} {
	my variable ChnIdn TypChn 

	if {$args eq ""} {
	    return $ChnIdn
	}

	if {[llength $args] != 2} {
	    puts "\nError ! arguments should be -type <Protein| Nucleic | ligand>"
	    return
	}
	set type [lindex $args 1]
	if {$type ni {"Protein" "Nucleic" "ligand"}} {
	    puts "\nError ! -type should be one of Protein, Nucleic, or ligand"
	    return
	}
	    set Lchains {}
	foreach c $ChnIdn {
	    if {$TypChn($c) eq $type} {
		lappend Lchains $c
	    }
	}
	
	return $Lchains
    }

	
    oo::define Structure method _seqres {c} {
	my variable SeqRes
	return [join [set SeqRes($c)] ""]
    }


    oo::define Structure method _chainIs {c} {
	my variable TypChn
	return [set TypChn($c)]
    }


    oo::define Structure method _resname {args} {
	my variable NomRes1l NomRes3l TypRes
	
	if {! [llength $args]} {
	    puts "Error ! num args"
	    return
	}
	
	set 3lcode 0
	if {"-code3l" in $args} {
	    set 3lcode 1
	}
	
	set polymer 1
	if {"-allres" in $args} {
	    set polymer 0
	}
	
	set i [lsearch $args "-chain"]
	if {$i == -1} {
	    puts "Error ! no >>-chain<< card !"
	    return
	}
	set c [lindex $args $i+1]
	if {! [info exists NomRes1l($c)]} {
	    puts "Error ! Chain >>$c<< does not exists"
	    return ""
	}
	
	set res {}
	if {$polymer} {
	    if {! $3lcode} {
		set Lres [set NomRes1l($c)]
	    } else {
		set Lres [set NomRes3l($c)]
	    }
	    foreach p [set TypRes($c)] r $Lres {
		if {$p ne "ligand"} {
		    lappend res $r
		}
	    }
	} else {
	    if {! $3lcode} {
		set res [set NomRes1l($c)]
	    } else {
		set res [set NomRes3l($c)]
	    }
	}
	
	return $res
    }


    oo::define Structure method CoordsSeq2PDB {c x} {
	# Conversion pour features PDB dans MACSIM
	# seq macsim est 1,2,3 ... et seq PDB peut
	# etre 67,68,69 ...
	
	set lr [my _resnumber -chain $c -polymer]
	return [lindex $lr $x-1]
    }


    oo::define Structure method CoordsPDB2Seq {c x} {
	# Conversion pour PDB dans MACSIM
	# seq macsim est 1,2,3 ... et seq PDB peut
	# etre 67,68,69 ...
	
	set lr [my _resnumber -chain $c -polymer]

	# ATTENTION ! 
	# return value starts at 0 !
	return [lsearch $lr $x]
    }


    oo::define Structure method AllSphereAround {rad {What "CA"}} {
	my variable AtmXYZ NmrRes ChnIdn TypChn

	set mol [my nom]
	
	set rad2 [expr {$rad * $rad}]
	set Lout {}
	foreach chn0 $ChnIdn {
	    if {$TypChn($chn0) ne "Protein"} {
		continue
	    }
	    set Lnmr0 [$mol _resnumber -chain $chn0 -polymer]
	    set Lxyz0 [$mol _rescoords -chain $chn0 -polymer]
	    foreach nmr0 $Lnmr0 xyz0 $Lxyz0 {
		lappend Lout "ref $nmr0 $chn0"
		if {$What eq "CA"} {
		    set Lc0 [lindex $xyz0 1]
		} elseif {$What eq "CDM"} {
		    set Lc0 [ResidueCDM $xyz0]
		}
		    lassign $Lc0 x0 y0 z0
		
		set Lsph {}
		foreach chn $ChnIdn {
		    set Lnmr [$mol _resnumber -chain $chn -polymer]
		    set Lxyz [$mol _rescoords -chain $chn -polymer]
		    foreach nmr $Lnmr xyz $Lxyz {
			if {$What eq "CA"} {
			    set Lc [lindex $xyz 1]
			} elseif {$What eq "CDM"} {
			    set Lc [ResidueCDM $xyz]
			}
			lassign $Lc x y z
			set r2 [expr {($x0-$x)**2 + ($y-$y0)**2 + ($z-$z0)**2}]
			if {$r2 < $rad2} {
			    lappend Lsph [list $nmr $chn [expr {sqrt($r2)}]]
			}
		    }
		    set i [lsearch $Lsph [list $nmr0 $chn0 0.0]]
		    set Lsph [lreplace $Lsph $i $i]
		    lappend Lout {*}$Lsph
		}
	    }
	}
	
	return $Lout
    }
    oo::define Structure method SphereAround {res0 chn0 rad {What "CA"}} {
	my variable AtmXYZ NmrRes ChnIdn

	set mol [my nom]
	
	set i [lsearch $NmrRes($chn0) $res0]
	if {$i == -1} {
	    # reference residue does not exists
	    return -1
	}
	set Lxyz0 [lindex $AtmXYZ($chn0) $i]

	if {$What eq "CA"} {
	    set Lref0 [lindex $Lxyz0 1]
	}
	lassign $Lref0 x0 y0 z0
	set rad2 [expr {$rad * $rad}]
	set Lout {}
	foreach chn $ChnIdn {
	    set Lnmr [$mol _resnumber -chain $chn -polymer]
	    set Lxyz [$mol _rescoords -chain $chn -polymer]
	    foreach nmr $Lnmr Lc $Lxyz {
		if {$What eq "CA"} {
		    set xyz [lindex $Lc 1]
		}
		lassign $xyz x y z
		set r2 [expr {($x0-$x)**2 + ($y-$y0)**2 + ($z-$z0)**2}]
		if {$r2 < $rad2} {
		    lappend Lout [list $nmr $chn [expr {sqrt($r2)}]]
		}
	    }
	}
	set i [lsearch $Lout [list $res0 $chn0 0.0]]
	set Lout [lreplace $Lout $i $i]

	return $Lout
   } 

    
    oo::define Structure method CoordsDeAtom {chn res atm {WithBQ 0}} {
	my variable NmrRes NomAtm AtmXYZ AtmBQ
	
	set i [lsearch $NmrRes($chn) $res]
	set a [lindex $NomAtm($chn) $i]
	set x [lindex $AtmXYZ($chn) $i]
	set ia [lsearch $a $atm]
	if {$WithBQ} {
	    set b [lindex $AtmBQ($chn) $i]
	    set bq [lindex $b $ia]

	    return [list [lindex $x $ia] $bq]
	} else {
	    return [lindex $x $ia]
	}
    }


    oo::define Structure method _rescoords {args} {
	my variable NmrRes NomRes1l TypRes NomRes3l AtmXYZ
	
	if {! [llength $args]} {
	    puts "Error ! num args"
	    return
	}

	set i [lsearch $args "-chain"]
	if {$i == -1} {
	    puts "Error ! no >>-chain<< card !"
	    return
	}
	set c [lindex $args $i+1]
	if {! [info exists NomRes1l($c)]} {
	    puts "Error ! Chain >>$c<< does not exists"
	    return
	}
	set ip [lsearch $args "-polymer"]
	set il [lsearch $args "-ligand"]
	if {$ip != -1 && $il != -1} {
	    # can't ask for polymer and ligned at te same time
	    return
	}
	if {$ip != -1} {
	    set quoi [list "Protein" "Nucleic"]
	} elseif {$il != -1} {
	    set quoi "ligand"
	} else {
	    #set quoi [list Protein Nucleic ligand]
	}
	set Lres {}
	foreach t [set TypRes($c)] x [set AtmXYZ($c)] {
	    if {$t in $quoi} {
		lappend Lres $x
	    }
	}
	
	return $Lres
    }


    oo::define Structure method _resnumber {args} {
	my variable NmrRes NomRes1l TypRes NomRes3l

	if {! [llength $args]} {
	    puts "Error ! num args"
	    return
	}

	set i [lsearch $args "-chain"]
	if {$i == -1} {
	    puts "Error ! no >>-chain<< card !"
	    return
	}
	set c [lindex $args $i+1]
	if {! [info exists NomRes1l($c)]} {
	    puts "Error ! Chain >>$c<< does not exists"
	    return
	}
	set ip [lsearch $args "-polymer"]
	set il [lsearch $args "-ligand"]
	if {$ip != -1 && $il != -1} {
	    # can't ask for polymer and ligned at te same time
	    return
	}
	if {$ip != -1} {
	    set quoi [list "Protein" "Nucleic"]
	} elseif {$il != -1} {
	    set quoi "ligand"
	} else {
	    set quoi [list Protein Nucleic ligand]
	}
	set Lres {}
	foreach t [set TypRes($c)] a [set NmrRes($c)] {
	    if {$t in $quoi} {
		lappend Lres $a
	    }
	}

	return $Lres
    }


    oo::define Structure method _typeChn {chn} {
	my TypRes
	set L [DenombreLaListe $TypRes($c)]
	
	return [lindex [lindex $L 0] 0]
    }


    oo::define Structure method selcolor {col} {
	my variable ResSel ResCol

	foreach e [array names ResSel] {
	    if {[set ResSel($e)]} {set ResCol($e) $col}
	}

	return
    }


    oo::define Structure method select {args} {
	my variable NomAtm NomRes1l NmrRes ChnIdn AtmXYZ AtmBQ SSBin SecStr Header ResSel
	global Defauts

	if {! [llength $args]} {
	    puts "Error ! num args"
	    return
	}

	if {[llength $args] == 1 && $args eq "all"} {
	    foreach e [array names ResSel] {
		set ResSel($e) 1
	    }

	    return
	}
	if {[llength $args] == 1 && $args eq "none"} {
	    foreach e [array names ResSel] {
		set ResSel($e) 0
		set ResCol($e) [set Defauts(CoulVariable)]
	    }

	    return
	}

	# Si pas de cle chain, -> toutes les chaines
	if {"chain" in $args} {
	    set ChnSel -1
	}

	set LExp $args

	# Si parentheses, traite d'abord interne
	if {[lsearch $args "("] != -1} {
	    set LExp [my _DecoupeParParenthese $args]
	}

	set rep [my _TraiteExp $LExp]

	set i 0
	foreach v $ChnIdn {
	    foreach r [set NmrRes($v)] {
		set ResSel($v,$r) [lindex $rep $i]
		incr i
	    }
	}

	return
    }


    oo::define Structure method _DecoupeParParenthese {l} {
	set LO [lreverse [lsearch -all $l "\("]]
	set LF [lreverse [lsearch -all $l "\)"]]

	if {! [info exists DSel]} {set DSel [dict create]}
	set comp 0
	foreach o $LO f $LF {
	    set exp [lrange $l [expr {$o+1}] [expr {$f-1}]]
	    set res [my _TraiteExp $exp]
	    dict set DSel tmp${comp} $res
	    set l [lreplace $l $o $f "tdict" tmp${comp}]
	    incr comp
	}

	return $l
    }


    oo::define Structure method _Mult {a b op} {
	set res {}
	foreach x $a y $b {
	    if {$op eq "and"} {
		lappend res [expr {$x & $y}]
	    } else {
		lappend res [expr {$x | $y}]
	    }
	}
	return $res
    }


    oo::define Structure method _TraiteExp {exp} {
	set Lelt {}
	foreach e $exp {
	    if {$e eq "and" || $e eq "or"} {
		lappend LHow $e
		lappend Lexp $Lelt
		set Lelt {}
	    } else {
		lappend Lelt $e
	    }
	}
	lappend Lexp $Lelt

	set init 0
	set i 0
	foreach x $Lexp {
	    set RS [my _ExecSel $x]
	    if {! $init} {
		set init 1
		set tmp $RS
	    } else {
		set tmp [my _Mult $RS $tmp [lindex $LHow $i]]
		incr i
	    }
	}
	
	return $tmp
    }


    oo::define Structure method _ExecSel {sel} {
	my variable ResSel NomRes1l NmrRes ChnIdn EqResType
	
	set what [string tolower [lindex $sel 0]]
	switch -regexp -- $what {
	    "chain" {
		set c [lindex $sel 1]
		foreach e [array names ResSel "$c,*"] {
		    set ResSel($e) 1
		}

		set res {}
		foreach v [set ChnIdn] {
		    if {$v eq $c} {set s 1} {set s 0}
		    set n [llength [set NomRes1l($v)]]
		    set res [concat $res [lrepeat $n $s]]
		}

		return $res
	    }
	    "resid" {
		foreach e [array names ResSel] {
		    set ResSel($e) 0
		}

		set v [lindex $sel 1]
		set Lx [split $v ","]
		foreach x $Lx {
		    if {[regexp {:} $x]} {
			lappend Lix [split $x ":"]
		    } else {
			lappend Lix [list $x $x]
		    }
		}

		foreach v [set ChnIdn] {
		    foreach e $Lix {
			lassign $e d f 
			for {set i $d} {$i <= $f} {incr i} {
			    set x "$v,$i"
			    set ResSel($x) 1
			}
		    }
		}
		foreach c [set ChnIdn] {
		    foreach r [set NmrRes($c)] {
			lappend res [set ResSel($c,$r)]
		    }
		}

		return $res
	    }
	    "ala|cys|asp|glu|phe|gly|his|ile|lys|leu|met|asn|pro|gln|arg|ser|thr|val|trp|tyr" {
		#	    variable EqResType

		set AA [string toupper $what]
		set Li [dict get [set EqResType] $AA]
		foreach c [set ChnIdn] {
		    foreach r [set NmrRes($c)] {
			if {"$c,$r" in $Li} {set s 1} {set s 0}
			lappend res $s
		    }
		}

		return $res
	    }
	    "tdict" {
		variable DSel
		set key [lindex $sel 1]
		set res [dict get [set DSel] $key]
		return $res
	    }
	    default {
		puts "keyword not found : $what"
		return
	    }
	}

	return
    }


    proc _CombleSSParCoil {{lss {} } molid chn} {
	variable SecStr
	variable NmrRes

	set LesRes  [set NmrRes($chn)]
	set 1ResPDB [lindex $LesRes 0]
	set DResPDB [lindex $LesRes end]
	set df {}

	foreach s $lss {
	    lassign $s Elt a z e Nm1 r Nm2 t q 
	    lappend df [list $Nm1 $Nm2]
	}

	if {$df == {}} {
	    lappend df "Coil xxx xxx $chn $1ResPDB xxx $DResPDB xxx"
	    return $df
	}

	set 1ResSS [lindex [lindex $df 0] 0]
	if {$1ResPDB - $1ResSS < 0} {
	    lappend lss "Coil xxx xxx $chn $1ResPDB xxx [expr {$1ResSS-1}]"
	}

	set debc [_NextResDuPdb $name [lindex [lindex $df 0] 1] $chn $molid]
	foreach cpl [lrange $df 1 end] {
	    set finc [_PreviousResDuPdb $name [lindex $cpl 0] $chn $molid]
	    if {$finc-$debc >= 0} {
		lappend lss "Coil xxx xxx $chn $debc xxx $finc xxx"
	    }
	    set debc [_NextResDuPdb $name [lindex $cpl 1] $chn $molid]
	}

	if {$debc ne ""} {
	    if {$DResPDB - $debc >= 0} {
		lappend lss "Coil xxx xxx $chn $debc xxx $DResPDB xxx"
	    }
	}

	return [lsort -integer -index 4 $lss]
    }



    proc _NextResDuPdb {name res chn mol} {
	variable NmrRes

	set ires [lsearch [set NmrRes($chn)] $res]
	set deb  [lindex [set NmrRes($chn)] [expr {$ires+1}]]

	return $deb
    }


    proc _PreviousResDuPdb {name res chn mol} {
	variable NmrRes

	set ires [lsearch [set NmrRes($chn)] $res]
	set fin [lindex [set NmrRes($chn)] [expr {$ires-1}]]

	return $fin
    }


    oo::define Structure method newObj {objname {init 0}} {
	my variable DictDesObjets db

	set objname [BonObjName $objname]
	if {[dict exists $DictDesObjets $objname]} {
	    puts "Error ! Object >>$objname<< already exists !"
	    return -1
	}

	set ix [dict get $DictDesObjets Index]
	dict set DictDesObjets $objname $ix
	incr ix
	dict set DictDesObjets Index $ix

	my variable $objname

	dict set $objname OOn 1
	dict set $objname globj 0
	dict set $objname glList -1
	dict set $objname glsel -1
	dict set $objname glbox -1
	dict set $objname FlagSrf 0
	dict set $objname FlagRib 0
	dict set $objname FlagCat 0
	dict set $objname FlagAtm 0
	dict set $objname FlagCPK 0
	dict set $objname FlagPrl 0
	dict set $objname FlagBox 0
	dict set $objname Labels {}

	if {$init} {
	    return
	}
	
	set pdb [my nom]
	if {$pdb ni [info commands]} {
	    if {[regexp {[a-z]} $pdb]} {
		set pdb [string toupper $pdb]
	    } else {
		set pdb [string tolower $pdb]
	    }
	}
	    
	$db eval {begin transaction}
	set pkp [$db eval {select pk_pdb from pdb where name=$pdb}]
	# table kept in an ORD file and not restored by LoadObjFromDB
	$db eval "drop table if exists $objname"
	$db eval "create table $objname as select * from objetinit where pk_pdb = $pkp"
	set idxname "idx_$objname"
	$db eval "create index $idxname on $objname (pk_obj, pk_residues, currsel, surface, ribbon, ribcol, catrace, cacol, atoms, atmcol, cpk, pearl, picked, label)"
	$db eval {commit}

	set Lt [$db eval {select tbl_name from sqlite_master}]
	
	my select none

	return
    }


    oo::define Structure method CPK {obj} {
	set obj [BonObjName $obj]
	my variable ResSel ResCol $obj TypRes ChnIdn NmrRes db
	
	dict set $obj CPKatm [array names ResSel]
	dict set $obj CPKcol [array names ResCol]
	
	set pdb [my nom]
	set sdb $db
	$sdb eval {begin transaction}
	foreach c $ChnIdn {
	    set l1 {}
	    set l0 {}
	    foreach t $TypRes($c) r $NmrRes($c) {
		if {$t eq "ligand"} {
		    continue
		}
		
		set v [set ResSel($c,$r)]
		set Nn [format "%08s" $r]
		if {$v} {
		    lappend l1 '$Nn'
		} else {
		    lappend l0 '$Nn'
		}
	    }
	    set ix1 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l1 ,])"]
	    $sdb eval "update $obj set cpk=1 where pk_residues in ([join $ix1 ,])"
	    set ix0 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l0 ,])"]
	    $sdb eval "update $obj set cpk=0 where pk_residues in ([join $ix0 ,])"
	}
	$sdb eval {commit}

	dict set $obj FlagCPK 1

	return
    }


    oo::define Structure method atomes {obj} {
	set obj [BonObjName $obj]
	my variable ResSel ResCol $obj TypRes ChnIdn NmrRes db
	
	dict set $obj atomes [array names ResSel]
	dict set $obj atmcol [array names ResCol]
	
	set pdb [my nom]
	set sdb $db
	$sdb eval {begin transaction}
	foreach c $ChnIdn {
	    set l1 {}
	    set l0 {}
	    foreach t $TypRes($c) r $NmrRes($c) {
		if {$t eq "ligand"} {
		    continue
		}
		
		set v [set ResSel($c,$r)]
		set Nn [format "%08s" $r]
		if {$v} {
		    lappend l1 '$Nn'
		} else {
		    lappend l0 '$Nn'
		}
	    }
	    set ix1 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l1 ,])"]
	    $sdb eval "update $obj set atoms=1 where pk_residues in ([join $ix1 ,])"
	    set ix0 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l0 ,])"]
	    $sdb eval "update $obj set atoms=0 where pk_residues in ([join $ix0 ,])"
	}
	$sdb eval {commit}

	dict set $obj FlagAtm 1

	return
    }


    oo::define Structure method pearl {obj} {
	set obj [BonObjName $obj]
	my variable ResSel ResCol $obj TypRes ChnIdn NmrRes db

	dict set $obj pearl  [array get ResSel]
	dict set $obj prlcol [array get ResCol]

	set pdb [my nom]
	set sdb $db
	$sdb eval {begin transaction}
	foreach c $ChnIdn {
	    set l1 {}
	    set l0 {}
	    foreach t $TypRes($c) r $NmrRes($c) {
		if {$t eq "ligand"} {
		    continue
		}

		set v [set ResSel($c,$r)]
		set Nn [format "%08s" $r]
		if {$v} {
		    lappend l1 '$Nn'
		} else {
		    lappend l0 '$Nn'
		}
	    }
	    set ix1 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l1 ,])"]
	    $sdb eval "update $obj set pearl=1, ribbon=0 where pk_residues in ([join $ix1 ,])"
	    set ix0 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l0 ,])"]
	    $sdb eval "update $obj set pearl=0, ribbon=0 where pk_residues in ([join $ix0 ,])"
	}
	$sdb eval {commit}
	
	dict set $obj FlagPrl 1
	
	return
    }
    
    
    oo::define Structure method catrace {obj} {
	set obj [BonObjName $obj]
	my variable ResSel ResCol $obj TypRes ChnIdn NmrRes db

	dict set $obj catrace [array get ResSel]
	dict set $obj cacol   [array get ResCol]

	set pdb [my nom]
	set sdb $db
	$sdb eval {begin transaction}
	foreach c $ChnIdn {
	    set l1 {}
	    set l0 {}
	    foreach t $TypRes($c) r $NmrRes($c) {
		if {$t eq "ligand"} {
		    continue
		}

		set v [set ResSel($c,$r)]
		set Nn [format "%08s" $r]
		if {$v} {
		    lappend l1 '$Nn'
		} else {
		    lappend l0 '$Nn'
		}
	    }
	    set ix1 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l1 ,])"]
	    $sdb eval "update $obj set catrace=1, ribbon=0 where pk_residues in ([join $ix1 ,])"
	    set ix0 [$sdb eval "select r.pk_residues from chains as c, residues as r, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l0 ,])"]
	    $sdb eval "update $obj set catrace=0, ribbon=0 where pk_residues in ([join $ix0 ,])"
	}
	$sdb eval {commit}
	
	dict set $obj FlagCat 1
	
	return
    }
    
    
    oo::define Structure method ribbons {obj} {
	set obj [BonObjName $obj]
	my variable ResSel ResCol $obj TypRes ChnIdn NmrRes db
	
	dict set $obj ribbon [array get ResSel]
	dict set $obj ribcol [array get ResCol]
	
	set val [dict get [set $obj] ribbon]
	
	set pdb [my nom]
	set sdb $db
	$sdb eval {begin transaction}

	foreach c $ChnIdn {
	    set l1 {} ; set l0 {}
	    foreach t $TypRes($c) r $NmrRes($c) {
		if {$t eq "ligand"} {continue}
		
		set v [set ResSel($c,$r)]
		set Nn [format "%08s" $r]
		if {$v} {
		    lappend l1 '$Nn'
		} else {
		    lappend l0 '$Nn'
		}
	    }
	    set ix1 [$sdb eval "select r.pk_residues from residues as r, chains as c, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l1 ,])"]
	    $sdb eval "update $obj set ribbon=1, catrace=0 where pk_residues in ([join $ix1 ,])"
	    set ix0 [$sdb eval "select r.pk_residues from residues as r, chains as c, pdb as p where p.name='$pdb' and c.pk_pdb=p.pk_pdb and c.name='$c' and r.pk_chains=c.pk_chains and r.rnbr in ([join $l0 ,])"]
	    $sdb eval "update $obj set ribbon=0, catrace=0 where pk_residues in ([join $ix0 ,])"
	}
	$sdb eval {commit}

	dict set $obj FlagRib 1

	return
    }


    oo::define Structure method surface {obj} {
	set obj [BonObjName $obj]
	my variable $obj ChnIdn ResSel db
	
	dict set $obj surface [array get ResSel]

	$db eval "update $obj set surface = 1 where ribbon=1 or catrace=1 or atoms=1 or cpk=1 or pearl=1"

	dict set $obj FlagSrf 1

	return
    }


    # remove the surface of an object (object editor, "Add surface : No")
    oo::define Structure method nosurface {obj} {
	set obj [BonObjName $obj]
	my variable $obj db

	dict set $obj surface {}
	$db eval "update $obj set surface = 0"
	dict set $obj FlagSrf 0

	return
    }


    oo::define Structure method hasSurface {obj} {
	set obj [BonObjName $obj]
	my variable $obj

	return [dict get [set $obj] FlagSrf]
    }


    # Center + bounding radius of the atoms ACTUALLY displayed for a given
    # object (those with at least one active representation:
    # ribbon/catrace/atoms/cpk/pearl -- same clause as "surface" above).
    # Used by the "Center" menu item added to the object panel (AddFObj /
    # ExecuteActionObjet, on the viandox side). Returns {} if no atom is
    # currently displayed for this object (no representation enabled), in
    # which case the caller cannot recenter on it.
    oo::define Structure method objCenterRad {obj} {
	set obj [BonObjName $obj]
	my variable $obj db

	set Lxyz [$db eval "select a.x, a.y, a.z from atoms as a, $obj as o \
				where a.pk_atoms = o.pk_obj and \
				      (o.ribbon=1 or o.catrace=1 or o.atoms=1 \
				       or o.cpk=1 or o.pearl=1)"]

	if {[llength $Lxyz] == 0} {
	    return {}
	}

	set xmin 999999. ; set xmax -999999.
	set ymin 999999. ; set ymax -999999.
	set zmin 999999. ; set zmax -999999.
	foreach {x y z} $Lxyz {
	    if {$x < $xmin} {set xmin $x}
	    if {$x > $xmax} {set xmax $x}
	    if {$y < $ymin} {set ymin $y}
	    if {$y > $ymax} {set ymax $y}
	    if {$z < $zmin} {set zmin $z}
	    if {$z > $zmax} {set zmax $z}
	}

	set cx [expr {($xmin+$xmax)/2.}]
	set cy [expr {($ymin+$ymax)/2.}]
	set cz [expr {($zmin+$zmax)/2.}]

	# rayon = distance max du centre a un atome reellement affiche (borne
	# correcte, invariante par rotation -- meme principe que le rayon
	# global calcule dans AfficheDansViandox).
	set rad 0.
	foreach {x y z} $Lxyz {
	    set d [expr {sqrt(($x-$cx)**2 + ($y-$cy)**2 + ($z-$cz)**2)}]
	    if {$d > $rad} {set rad $d}
	}

	return [list $cx $cy $cz $rad]
    }


    oo::define Structure method assignSelection {obj Lsel} {
	set obj [BonObjName $obj]
	my variable $obj ResSel ChnIdn db

	set nom [my nom]
	array set TSel $Lsel
	# an edited object can lose a representation
	foreach k {FlagRib FlagCat FlagAtm FlagCPK FlagPrl} {
	    dict set $obj $k 0
	}
	# table name in the SQL below : checked before the
	# transaction, an error inside it would leave it open
	if {! [regexp {^[A-Za-z0-9_]+$} $obj]} {
	    return -code error "invalid object name \"$obj\""
	}
	$db eval {begin transaction}
	$db eval "drop table $obj"
	set pkp [$db eval {select pk_pdb from pdb where name=$nom}]

	$db eval "create table $obj as select * from objetinit where pk_pdb = $pkp"
	foreach chn $ChnIdn {
	    unset -nocomplain Rib Atm Cpk Prl Cap
	    foreach t {Rib Atm Cpk Prl Cap} {
		set ${t}(toto) ""
	    }

	    foreach e [array names TSel "$chn,*"] {
		lassign [set TSel($e)] n type col
		# grab all colors
		lappend Lcols $col
		set Nn [format "%08s" $n]
		switch $type {
		    0 {
			# None
		    }
		    1 {
			# Atoms
			lappend Atm($col) '$Nn'
		    }
		    2 {
			# Ca/P trace
			lappend Cap($col) '$Nn'
		    }
		    3 {
			# Ribbon
			lappend Rib($col) '$Nn'
		    }
		    4 {
			# Ribbon + Atoms
			lappend Rib($col) '$Nn'
			lappend Atm($col) '$Nn'
		    }
		    5 {
			# Ribbon + CPK
			lappend Rib($col) '$Nn'
			lappend Cpk($col) '$Nn'
		    }
		    6 {
			# Pearls
			lappend Prl($col) '$Nn'
		    }
		    7 {
			# CPK
			lappend Cpk($col) '$Nn'
		    }
		}
	    }
	    
	    set Lcols [lsort -unique $Lcols]

	    foreach col $Lcols {
		# update table for ribbon
		if {[info exists Rib($col)]} {
		    dict set $obj FlagRib 1
		    set Lpkr [$db eval "select r.pk_residues from residues as r, chains as c, pdb as p where 
		    p.name = '$nom' and
		    c.pk_pdb = p.pk_pdb and 
		    c.name = '$chn' and 
		    r.pk_chains = c.pk_chains and 
		    r.rnbr in ([join [set Rib($col)] ,])"]
		    
		    $db eval "update $obj set ribcol='$col', ribbon=1 where pk_residues in ([join $Lpkr ,])"
		}
		
		# update table for Ca/P trace
		if {[info exists Cap($col)]} {
		    dict set $obj FlagCat 1

		    set Lpkr [$db eval "select r.pk_residues from residues as r, chains as c, pdb as p where 
		    p.name = '$nom' and 
		    c.pk_pdb = p.pk_pdb and 
		    c.name = '$chn' and 
		    r.pk_chains = c.pk_chains and 
		    r.rnbr in ([join [set Cap($col)] ,])"]
		    $db eval "update $obj set cacol='$col', catrace=1 where pk_residues in ([join $Lpkr ,])"
		}
		
		# update table for Atoms
		if {[info exists Atm($col)]} {
		    dict set $obj FlagAtm 1
		    
		    set Lpkr [$db eval "select r.pk_residues from residues as r, chains as c, pdb as p where 
		    p.name = '$nom' and 
		    c.pk_pdb = p.pk_pdb and 
		    c.name = '$chn' and 
		    r.pk_chains = c.pk_chains and 
		    r.rnbr in ([join [set Atm($col)] ,])"]
		    $db eval "update $obj set atmcol='$col', atoms=1 where pk_residues in ([join $Lpkr ,])"
		}
		
		# update table for CPK
		if {[info exists Cpk] && [info exists Cpk($col)]} {
		    dict set $obj FlagCPK 1

		    set Lpkr [$db eval "select r.pk_residues from residues as r, chains as c, pdb as p where 
		    p.name = '$nom' and 
		    c.pk_pdb = p.pk_pdb and 
		    c.name = '$chn' and 
		    r.pk_chains = c.pk_chains and 
		    r.rnbr in ([join [set Cpk($col)] ,])"]
		    $db eval "update $obj set atmcol='$col', cpk=1 where pk_residues in ([join $Lpkr ,])"
		}
		
		# update table for Pearl
		if {[info exists Prl($col)]} {
		    dict set $obj FlagPrl 1

		    set Lpkr [$db eval "select r.pk_residues from residues as r, chains as c, pdb as p where 
		    p.name = '$nom' and 
		    c.pk_pdb = p.pk_pdb and 
		    c.name = '$chn' and 
		    r.pk_chains = c.pk_chains and 
		    r.rnbr in ([join [set Prl($col)] ,]) order by r.pk_residues"]
		    $db eval "update $obj set cacol='$col', pearl=1 where pk_residues in ([join $Lpkr ,])"
		}
	    }
	}

	$db eval "create index idx_$obj on $obj (pk_obj, pk_residues, currsel, surface, ribbon, ribcol, catrace, cacol, atoms, atmcol, cpk, pearl, picked, label)"
	$db eval {commit}
	#$db eval {vacuum}

	return
    }


    oo::define Structure method editObject {obj} {
	set obj [BonObjName $obj]
	my variable $obj ChnIdn db
	global Defauts
	puts "[my _ListeObjets]"

	set nom [my nom]
	$db eval {begin transaction}
	set Lres {}
	foreach chn $ChnIdn {
	    set Lv [$db eval "select r.rnbr, o.ribbon, o.ribcol, o.catrace, o.cacol, o.atoms, o.atmcol, o.cpk, o.pearl from $obj as o, atoms as a, residues as r, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type != 'ligand' and 
	    a.pk_residues = r.pk_residues and 
	    (a.aname = ' CA ' or a.aname = ' P  ') and 
	    o.pk_obj = a.pk_atoms"]

	    foreach {rn rb rc ca cc at ac cp pr} $Lv {
		if {$rc eq $Defauts(CoulVariable)} {
		    set rc couldefond
		}
		if {$ac eq $Defauts(CoulVariable)} {
		    set ac couldefond
		}
		if {$cc eq $Defauts(CoulVariable)} {
		    set cc couldefond
		}
		set rn [string trimleft $rn 0]
		if {$rb && $at} {
		    set type 4
		    set col $rc
		} elseif {$rb && $cp} {
		    set type 5
		    set col $rc
		} elseif {$at} {
		    set type 1
		    set col $ac
		} elseif {$ca} {
		    set type 2
		    set col $cc
		} elseif {$rb} {
		    set type 3
		    set col $rc
		} elseif {$pr} {
		    set type 6
		    set col $cc
		} elseif {$cp} {
		    set type 7
		    set col $ac
		} else {
		    set type 0
		    set col couldefond
		}

		if {[llength $col] > 1} {
		    set col [CouleurDeci2Hexa $col]
		}
		lappend Lres "${chn},$rn" [list $rn $type $col]
	    }
	} 
	$db eval {commit}

	return $Lres
    }


    oo::define Structure method deleteObjects {{oIn ""}} {
	my variable DictDesObjets db
	
	if {! [info exists DictDesObjets]} {
	    return 0
	}

	if {$oIn eq ""} {
	    set Lo [my _ListeObjets]
	} else {
	    set Lo $oIn
	}

	$db eval {begin transaction}
	foreach o $Lo {
	    $db eval "drop table $o"
	    dict unset DictDesObjets $o
	    my _dellist $o
	}	
	$db eval {commit}

	if {$oIn eq ""} {
	    dict set DictDesObjets Index 0
	}

	return
    }


    oo::define Structure method _dellist {obj} {
	set obj [BonObjName $obj]
	my variable $obj

	# display list for objects
	foreach list [lreverse [dict get [set $obj] glList]] {
	    if {$list != -1 && [glIsList $list]} {
		glDeleteLists $list 1
	    }
	}

	# display list for selection
	set list [dict get [set $obj] glsel]
	if {$list != -1 && [glIsList $list]} {
	    glDeleteLists $list 1
	}

	dict set $obj glList -1
	dict set $obj glsel  -1
	dict set $obj globj   0

	return
    }


    oo::define Structure method GLListDe {type} {
	set obj "${type}[my nom]"
	my variable $obj

	return [dict get [set $obj] ribobj]
    }


    oo::define Structure method _ListeObjets {} {
	my variable DictDesObjets

	set l [dict keys $DictDesObjets]
	set Le {}
	foreach e $l {
	    if {$e eq "Index"} {continue}
	    lappend Le $e
	}

	return $Le
    }


    oo::define Structure method _EtatDeObjet {obj} {
	set obj [BonObjName $obj]
	my variable $obj

	return [dict get [set $obj] OOn]
    }


    oo::define Structure method ObjetOff {obj} {
	set obj [BonObjName $obj]
	my variable $obj

	dict set $obj OOn 0

	return
    }



    oo::define Structure method ObjetOn {obj} {
	set obj [BonObjName $obj]
	my variable $obj
	dict set $obj OOn 1

	return
    }


    oo::define Structure method Ind2Obj i {
	my variable DictDesObjets

	lassign [dict filter $DictDesObjets value $i] obj i
	return $obj
    }


    oo::define Structure method ClearPicked {} {
	set Lo [my _ListeObjets]
	my variable db {*}$Lo
	$db eval {begin transaction}
	foreach obj $Lo {
	    $db eval "update $obj set picked=0"
	    dict set $obj Labels {}
	}
	$db eval {commit}

	return
    }


    oo::define Structure method AddPicked {obj v} {
	my variable db

	set obj [BonObjName $obj]
	$db eval "update $obj set picked=1 where pk_obj=$v"
	my _Labels $obj
	
	return
    }


    oo::define Structure method _drawCPK {obj} {
	my variable $obj ChnIdn

	if {! [dict get [set $obj] FlagCPK]} {return}

	set QObj [gluNewQuadric]
	gluQuadricDrawStyle $QObj GLU_FILL
	gluQuadricNormals   $QObj GLU_SMOOTH
	
	foreach chn $ChnIdn {
	    set La [my _AtomesDuCpk $obj $chn]
	    if {$La == {}} {continue}

	    foreach {x y z na col} $La {
		# no color chosen in New Object (couldefond) : atom colors
		if {$col eq "undefined" || $col eq "couldefond"} {
		    set vcol [CouleurDeAtome $na]
		} else {
		    set vcol [RGBDeLaTkCol $col]
		}
		set rad [RayonDeAtome $na]

		glPushMatrix
		glTranslatef $x $y $z
		glColor4f {*}$vcol 1.0
		gluSphere $QObj $rad 32 32
		glPopMatrix
	    }
	}
	gluDeleteQuadric $QObj

	return
    }


    oo::define Structure method _drawAtoms obj {
	my variable $obj

	if {! [dict get [set $obj] FlagAtm]} {return}

	glLineWidth 2.0
	foreach Lat [dict get [set $obj] atmvec] {
	    lassign $Lat tag type Lx La Ln Lan

	    # on ne trace pas la chaine principale si 
	    # on est en ribbon ou catrace (flag cp)
	    if {$tag eq "Rib"} {
		#use_light
		set cp 0
		set cyl 1
		set QObj [gluNewQuadric]
		gluQuadricDrawStyle $QObj GLU_FILL
		gluQuadricNormals   $QObj GLU_SMOOTH
	    } elseif {$tag eq "Cat"} {
		set cp 0
		set cyl 0
		set QObj ""
	    } else {
		set cp 1
		set cyl 0
		set QObj ""
	    }

	    switch $type {
		"Protein" {
		    DrawAtomsProtein $cp $cyl $QObj $Lx $La $Ln
		}
		"Nucleic" {
		    DrawAtomsNucleic $cp $cyl $QObj $Lx $La $Ln
		}
		"ligand" {
		    DrawAtomsLigand $cp $cyl $QObj $Lx $La $Ln
		}
	    }
	    if {$tag eq "Rib"} {
		gluDeleteQuadric $QObj
	    }
	}

	return
    }


    oo::define Structure method _drawSurface obj {
	my variable $obj db

	if {! [dict get [set $obj] FlagSrf]} {return}
	# no atom displayed : no surface (before any GL state change)
	if {[$db onecolumn "select count(*) from $obj where surface=1"] == 0} {return}
	puts "\nSurface de [self]"
	
	glLightModelfv GL_LIGHT_MODEL_TWO_SIDE 0.0
	glLightModeli GL_LIGHT_MODEL_COLOR_CONTROL $::GL_SEPARATE_SPECULAR_COLOR
	glMaterialfv GL_FRONT_AND_BACK GL_AMBIENT {0.0 0.0 0.0 0.0}
		
	glEnable GL_BLEND
	glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA
	glEnable GL_CULL_FACE
	glCullFace GL_BACK

	glPolygonMode GL_FRONT_AND_BACK GL_FILL
	glHint GL_PERSPECTIVE_CORRECTION_HINT $::GL_NICEST
	glEnable GL_TEXTURE_2D

	#set FileTex "gold.jpg"
	#set FileTex "glass.jpg"
	set FileTex [file join $::OrdEtcDir fond.png]
	#lassign [Bidon_LoadImage $FileTex] imgData imgW imgH type
	#puts "\nFileTex $FileTex"
	catch {image create photo phImg -file $FileTex} Msg
	if {$Msg ne "phImg"} {
	    puts "\n==== Failed :\n$Msg"
	    set FileTex [file join $::OrdEtcDir fond.gif]
	    catch {image create photo phImg -file $FileTex} Msg
	    if {$Msg ne "phImg"} {
		puts "\n==== Failed :\n$Msg"
	    }
	}
	set imgH  [image height phImg]
	set imgW  [image width  phImg]
        set imgData [tcl3dVectorFromPhoto phImg 1]
        image delete phImg
	set latex [tcl3dVector GLuint 1]

	glGenTextures 1 $latex
	glBindTexture GL_TEXTURE_2D [$latex get 0]
	gluBuild2DMipmaps GL_TEXTURE_2D $::GL_ALPHA $imgW $imgH $::GL_ALPHA GL_UNSIGNED_BYTE $imgData
	$imgData delete

	glEnable GL_TEXTURE_GEN_S
	glEnable GL_TEXTURE_GEN_T

	glTexEnvi GL_TEXTURE_ENV GL_TEXTURE_ENV_MODE $::GL_REPLACE
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER $::GL_LINEAR
	glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER $::GL_LINEAR
        glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S $::GL_REPEAT
        glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T $::GL_REPEAT
	
	glTexGeni  GL_S GL_TEXTURE_GEN_MODE $::GL_SPHERE_MAP
	glTexGeni  GL_T GL_TEXTURE_GEN_MODE $::GL_SPHERE_MAP
	
	#glMaterialfv GL_BACK GL_AMBIENT_AND_DIFFUSE {0.0 0.0 0.0 1.0}

	# Recupere atomes contribuant a la surface
	set Lva {}
	$db eval "select a.x, a.y, a.z, a.na from atoms as a, $obj as o where a.pk_atoms = o.pk_obj and o.surface=1" {lappend Lva [list $x $y $z $na 1]}
	set Lva [lsort -unique $Lva]
	#lassign [tclsurface -sample 2 -expand 2 -contract 2 -smooth -connolly -filter 13 $Lva] Lv Ln
	#lassign [tclsurface -sample 2 -expand 2 -contract 2 -smooth -connolly $Lva] Lv Ln
	package require tclsurface
	lassign [tclsurface -expand 2 -contract 2 -smooth -connolly $Lva] Lv Ln
	puts "Surface Computation done ..."
	# 1 glcol per vertex 
	set Lco  {}
	for {set i 0} {$i<[llength $Lv]/3} {incr i} {
	    lappend Lco 0.2 0.2 0.05 0.05
	}
	
	dict set $obj globj 1
	if {1} {
	    set Vec [tcl3dVectorFromList GLfloat $Lv]
	    set Nml [tcl3dVectorFromList GLfloat $Ln]
	    set Col [tcl3dVectorFromList GLfloat $Lco]
	    
	    glEnableClientState GL_VERTEX_ARRAY
	    glEnableClientState GL_COLOR_ARRAY
	    glEnableClientState GL_NORMAL_ARRAY
	
	    glVertexPointer 3 GL_FLOAT 0 $Vec
	    glColorPointer  4 GL_FLOAT 0 $Col
	    glNormalPointer   GL_FLOAT 0 $Nml
	    
	    glDrawArrays GL_TRIANGLES 0 [expr {[llength $Lv]/3}]

	    glDisableClientState GL_VERTEX_ARRAY
	    glDisableClientState GL_COLOR_ARRAY
	    glDisableClientState GL_NORMAL_ARRAY
	} else {
	    set Lvert {}
	    set Lnorm {}
	    foreach {x y z} $Lv {nx ny nz} $Ln {
		lappend Lvert [list $x $y $z]
		lappend Lnorm [list $nx $ny $nz]
	    }
	    set Lcol {}
	    set Lcol [lrepeat [llength $Lvert] [list 0.2 0.2 0.05 0.05]]

	    foreach {v1 v2 v3} $Lvert {n1 n2 n3} $Lnorm col $Lcol {
		glBegin GL_TRIANGLES
		glColor4fv $col
		glNormal3fv $n1
		glVertex3fv $v1
		glNormal3fv $n2
		glVertex3fv $v2
		glNormal3fv $n3
		glVertex3fv $v3
		glEnd
	    }
	}

	glLightModeli GL_LIGHT_MODEL_COLOR_CONTROL $::GL_SINGLE_COLOR
	
	glDisable GL_TEXTURE_GEN_S
	glDisable GL_TEXTURE_GEN_T
	glDisable GL_TEXTURE_2D
	glDisable GL_BLEND
	glDisable GL_CULL_FACE
	glLightModelfv GL_LIGHT_MODEL_TWO_SIDE 1.0

	return
    }


    oo::define Structure method _drawRibbon obj {
	my variable $obj

	if {! [dict get [set $obj] FlagRib]} {return}

	set ListLesVecs [dict get [set $obj] ribvec]
	if {[lindex $ListLesVecs 0] eq "Nucleic" || [lindex $ListLesVecs 0] eq "Protein"} {
	    # Only one ribbon
	    set ListLesVecs [list $LesVecs]
	}
	foreach LesVecs $ListLesVecs {
	    if {$LesVecs == {}} {continue}
	    if {0} {
		DebugRib $LesVecs
		return
	    }

	    # cas nucleic :
	    #glFrontFace GL_CW

	    if {[lindex $LesVecs 0] eq "Nucleic"} {
		DrawRibbonNucleic [lindex $LesVecs 1] [lindex $LesVecs 2]
	    } else {
		DrawRibbonProtein [lindex $LesVecs 1]
	    }
	    #glFrontFace GL_CCW
	}

	if {[dict get [set $obj] FlagBox]} {
	    set chn [string index $obj end]
	    my _drawBoite $obj $chn
	}

	return
    }


    oo::define Structure method _drawCatrace obj {
	my variable $obj ChnIdn

	if {! [dict get [set $obj] FlagCat]} {return}

	foreach chn $ChnIdn {
	    set LLa [my _AtomesDuCaTrace $obj $chn]
	    if {$LLa == 0} {continue}

	    foreach Lcc $LLa {
		set C1 [lrange $Lcc 0 end-1]
		set C2 [lrange $Lcc 1 end]
		
		foreach e1 $C1 e2 $C2 {
		    set v1 [lrange $e1 0 2]
		    set c1 [lindex $e1 3]
		    set v2 [lrange $e2 0 2]
		    set c2 [lindex $e2 3]
		    TraceLiaison "" $v1 $v2 $c1 $c2 0
		}
	    }
	}

	return
    }


    oo::define Structure method _drawPearl {obj} {
	my variable $obj ChnIdn TypChn

	if {! [dict get [set $obj] FlagPrl]} {return}

	set QObj [gluNewQuadric]
	gluQuadricDrawStyle $QObj GLU_FILL
	gluQuadricNormals   $QObj GLU_SMOOTH

	foreach chn $ChnIdn {
	    if {[set TypChn($chn)] eq "Protein"} {
		set Rad 2.
	    } else {
		set Rad 4.
	    }
	    set La [my _AtomesDuPearl $obj $chn]
	    if {$La == {}} {continue}

	    foreach {x y z col} $La {
		set vcol [RGBDeLaTkCol $col]
		glPushMatrix
		glTranslatef $x $y $z
		glColor4f {*}$vcol 1.0
		gluSphere $QObj $Rad 32 32
		glPopMatrix
	    }
	}
	gluDeleteQuadric $QObj

	return
    }


    oo::define Structure method _SetupPicking {obj} {
	set obj [BonObjName $obj]
	my variable $obj ChnIdn DictDesObjets

	set Lres {}
	foreach chn $ChnIdn {
	    set La [my _AtomesToPick $obj $chn]
	    if {$La ne {} } {
		lappend Lres {*}$La
	    }
	}

	return $Lres

    }

    
    oo::define Structure method ResidueCDM {n c} {
	global db

	set nom [my nom]
	set rn [format "%08s" $n]

	$db eval {begin transaction}
	set La [$db eval {select a.x, a.y, a.z from atoms as a, residues as r, chains as c, pdb as p where \
		p.name = $nom and \
		c.pk_pdb=p.pk_pdb and \
		c.name=$c and \
		r.pk_chains=c.pk_chains and \
		r.rnbr=$rn and \
		a.pk_residues=r.pk_residues}]
	set Ln [$db eval {select min(a.x), min(a.y), min(a.z) from atoms as a, residues as r, chains as c, pdb as p where \
		p.name = $nom and \
		c.pk_pdb=p.pk_pdb and \
		c.name=$c and \
		r.pk_chains=c.pk_chains and \
		r.rnbr=$rn and \
		a.pk_residues=r.pk_residues}]
	set Lx [$db eval {select max(a.x), max(a.y), max(a.z) from atoms as a, residues as r, chains as c, pdb as p where \
		p.name = $nom and \
		c.pk_pdb=p.pk_pdb and \
		c.name=$c and \
		r.pk_chains=c.pk_chains and \
		r.rnbr=$rn and \
		a.pk_residues=r.pk_residues}]
	$db eval {commit}
	
	set na 0
	set mx 0. ; set my 0. ; set mz 0.
	foreach {x y z} $La {
	    set mx [expr {$mx + $x}]
	    set my [expr {$my + $y}]
	    set mz [expr {$mz + $z}]
	    incr na
	}
	set mx [expr {$mx/$na}]
	set my [expr {$my/$na}]
	set mz [expr {$mz/$na}]
	
	lassign $Ln xmin ymin zmin
	lassign $Lx xmax ymax zmax
	set r [expr {sqrt(($xmax-$xmin)**2 + ($ymax-$ymin)**2 + ($zmax-$zmin)**2)/2.}]

	return [list $mx $my $mz $r]
    }


    oo::define Structure method AtomXYZ {v} {
	my variable db

	return [$db eval {select x, y, z from atoms where pk_atoms=$v}]
    }


    oo::define Structure method _ClearIDs {} {
	foreach o [my _ListeObjets] {
	    my _ClearObjIDs $o
	}

	return
    }


    oo::define Structure method _ClearObjIDs {obj} {
	my variable db

	set obj [BonObjName $obj]
	$db eval "update $obj set picked=0"

	return
    }


    oo::define Structure method _mapfeat {obj f la2} {
	my variable db
	global TabSF Defauts StrucAVoir

	set obj [BonObjName $obj]
	my variable $obj

	if {$f eq ""} {return}

	set nom [my nom]
	if {$f eq "None" && ! $la2} {
	    set c [set Defauts(CoulVariable)]
	    $db eval {begin transaction}
	    $db eval "update $obj set atmcol='$c', ribcol='$c', cacol='$c'"
	    $db eval {commit}

	    return
	}

	# structures of the 3D viewer (StrucAVoir may have been changed
	# by the tools of another instance)
	set Lstruc [StrucDuViewer]
	set i [lsearch -regexp $Lstruc $nom]
	if {$i < 0} {return}
	set nomf [BonAccess [lindex $Lstruc $i]]

	if {[info exists TabSF($nomf,$f)]} {
	    set Lfeat [set TabSF(${nomf},$f)]
	} else {
	    # conservation features mark alignment columns, but
	    # the sequences of the structures are usually left
	    # out of the computation (Defauts(PDBDansPilier)) :
	    # take the columns given to another sequence
	    set Lk [array names TabSF "*,$f"]
	    if {! [string match "Cons*" $f] || $Lk eq {}} {return}
	    set Lfeat [set TabSF([lindex $Lk 0])]
	}

	$db eval {begin transaction}
	foreach e $Lfeat {
	    DecortiqueUneFeature $e dg fg col score note
	    # skip the gaps of the structure sequence at the
	    # start of the feature : nothing to colour if
	    # there is no residue
	    set seg [string range $::Sequences($nomf) $dg $fg]
	    if {! [regexp -indices {[^.]} $seg m]} {continue}
	    incr dg [lindex $m 0]
	    set dg [DonnePosGS $nomf $dg]
	    set fg [DonnePosGS $nomf $fg]
	    set fdeb [format "%08s" $dg]
	    set ffin [format "%08s" $fg]

	    switch -regexp -- $f {
		{^Cons} {
		    if {$col eq "black"} {
			set c white
		    } else {
			set c [CouleurO2Ordali $col]
		    }
		}
		"SS-Cons" {
		    # colour of the ramp (#RRGGBB)
		    set c $col
		}
		default {
		    set c [CouleurO2Ordali $col]
		}
	    }

	    set Li [$db eval "select o.pk_obj from $obj as o, pdb as p, residues as r where (r.rnbr >= '$fdeb' and r.rnbr <= '$ffin') and o.pk_residues=r.pk_residues and o.pk_pdb=p.pk_pdb and p.name='$nom'"]
	    $db eval "update $obj set atmcol='$c', ribcol='$c', cacol='$c' where pk_obj in ([join $Li ,])"
	}

	$db eval {commit}

	return
    }


    oo::define Structure method AllLabels {} {
	set Res {}
	set Lo [my _ListeObjets]
	my variable {*}$Lo
	foreach o $Lo {
	    if {[my _EtatDeObjet $o]} {
		set l [dict get [set $o] Labels]
		if {$l != {}} {
		    lappend Res {*}$l
		}
	    }
	}

	return $Res
    }


    oo::define Structure method _Labels {obj} {
	my variable $obj db

	dict set $obj Labels [$db eval "select a.x, a.y, a.z, o.label from atoms as a, $obj as o where a.pk_atoms=o.pk_obj and o.picked=1"]
    }


    oo::define Structure method display {} {
	set LObj [my _ListeObjets]
	my variable DictDesObjets {*}$LObj db

	foreach obj $LObj {
	    if {! [my _EtatDeObjet $obj]} {continue}

	    switch [dict get [set $obj] globj] {
		1 {
		    glCallList [dict get [set $obj] glList]
		}
		2 {
		    glDrawArrays GL_TRIANGLES 0 [llength [dict get [set $obj] Ltrig]]
		}
		0 {
		    set list [glGenLists 1]
		    dict set $obj globj 1
		    dict set $obj glList $list
		    glNewList $list GL_COMPILE_AND_EXECUTE
		    
		    $db eval {begin transaction}
		    my _drawRibbon $obj
		    my _drawCatrace $obj
		    my _drawPearl $obj
		    my _drawAtoms $obj
		    my _drawCPK $obj
		    my _drawSurface $obj
		    
		    #my _drawboite $obj $chn

		    glEndList
		    
		    $db eval {commit}
		    #glCallList [dict get [set $obj] glList]
		}
	    }
	}

	return
    }


    oo::define Structure method render {obj} {
	set obj [BonObjName $obj]
	my variable $obj DictDesObjets TypChn ChnIdn db
	global HashPDB

	set nom [my nom]
	set mx [set HashPDB($nom)]
	set ox [dict get $DictDesObjets $obj]
	set tag [format "%02d%02d" $mx $ox]

	$db eval {begin transaction}

	# Trace le RIBBON
	if {[dict get [set $obj] FlagRib]} {
	    set LesVecs {}
	    foreach chn $ChnIdn {
		set ListeLat [my _AtomesDuRibbon $obj $chn]
		if {$ListeLat == 0} {continue}
		
		foreach Lat $ListeLat {
		    lassign $Lat Lca Lcol Lc Lo
		    lappend LesVecs [CheminRibbon $TypChn($chn) $Lca $Lcol $Lc $Lo]
		}
	    }

	    dict set $obj ribvec $LesVecs

	    # Pour Picking
	    # Faut cle atmvec, avec chaine principale
	    set Lv [$db eval "select r.pk_residues, r.rname3l, a.x, a.y, a.z, a.aname, a.pk_atoms from residues as r, atoms as a, $obj as o, pdb as p where o.ribbon=1 and r.pk_residues=a.pk_residues and o.pk_obj=a.pk_atoms and r.type = 'Protein' and r.pk_pdb=p.pk_pdb and p.name='$nom' and a.aname=' CA ' order by a.pk_atoms"]
	    set first 1
	    set LX {} ; set LA {} 
	    set Li {} 
	    set ncou [lindex $Lv 0]
	    set rcou [lindex $Lv 1]
	    set Lxyz {} ; set Lnm {} ; set Lli {}
	    foreach {n r x y z a i} $Lv {
		if {$n != $ncou} {
		    lappend Ln $rcou
		    lappend LX $Lxyz
		    lappend LA $Lnm
		    lappend Li $Lli
		    set Lxyz {}
		    set Lnm {}
		    set Lli {}
		    set rcou $r
		    set ncou $n
		}
		set xyz [list $x $y $z]
		lappend Lxyz $xyz
		lappend Lli [format "%d%02d%02d" $i $mx $ox]
		lappend Lnm  $a
	    }
	    lappend Ln $rcou
	    lappend LX $Lxyz
	    lappend LA $Lnm
	    lappend Li $Lli

	    #dict set $obj atmvec [list $Li $LX $LA $Ln]
	}

	if {[dict get [set $obj] FlagCat]} {
	    foreach chn $ChnIdn {
		set Lat [my _AtomesDuCaTrace $obj $chn]
		if {$Lat == 0} {continue}

		lassign $Lat Li Lca Lcol
		dict lappend $obj catvec [list $Li $Lca]
		dict lappend $obj catcol $Lcol
	    }
	}

	if {[dict get [set $obj] FlagAtm] || [dict get [set $obj] FlagCPK] || [dict get [set $obj] FlagSrf]} {
	    dict set $obj atmvec {}

	    foreach chn $ChnIdn {
		set Lat [my _AtomesDuAtm $obj $chn]
		if {$Lat == {}} {continue}
		if {[lindex $Lat 0] eq "Rib" || [lindex $Lat 0] eq "Cat" || [lindex $Lat 0] eq "Atm"} {
		    dict lappend $obj atmvec $Lat
		} else {
		    dict lappend $obj atmvec {*}$Lat
		}
	    }
	}

	$db eval {commit}

	return
    }


    oo::define Structure method save {chn deb fin {lgd 1} {fileOut ""}} {
	my variable db
	
	if {$fileOut eq ""} {
	    set fileOut [DemandeEtSauveFichier pdb]
	    if {$fileOut eq ""} {
		return
	    }
	}
	
	set Lres {}
	set pdb [string toupper [my nom]]
	if {$chn ne "all"} {
	    set Lchn $chn
	} else {
	    set Lchn [my _chains]
	}
	
	if {$deb ne "all"} {
	    set deb [format "%08s" $deb]
	    set fin [format "%08s" $fin]
	    set Ar "and r.rnbr >= '$deb' and r.rnbr <= '$fin'"
	} else {
	    set Ar ""
	}
	
	$db eval {begin transaction}
	set header [$db eval {select header from pdb where name=$pdb}]
	set Lhead {}
	if {$header != {}} {
	    set Lhead [lindex $header 0]
	}
	# the file is read as a PDB file only if it starts with
	# HEADER (else as mmCIF), and the chain types come from
	# SEQRES : write them when the stored header (structure
	# read from a mmCIF file) has none
	if {! [regexp {^HEADER } [lindex $Lhead 0]]} {
	    set Lhead [lsearch -all -inline -not -regexp $Lhead {^HEADER }]
	    set Lhead [linsert $Lhead 0 [format "HEADER    %-40s%-9s   %4s" "" "" $pdb]]
	}
	lappend Lres {*}$Lhead
	if {[lsearch -regexp $Lhead {^SEQRES }] == -1} {
	    foreach c $Lchn {
		set Lr [$db eval {select r.rname3l from residues as r, chains as c, pdb as p where p.name = $pdb and c.pk_pdb = p.pk_pdb and c.name = $c and r.pk_chains = c.pk_chains and r.type != 'ligand' order by r.pk_residues}]
		set nr [llength $Lr]
		set ser 0
		for {set k 0} {$k < $nr} {incr k 13} {
		    set Lf [lmap r [lrange $Lr $k $k+12] {format "%3s" [string trim $r]}]
		    lappend Lres [format "SEQRES %3d %1s %4d  %s" [incr ser] $c $nr [join $Lf " "]]
		}
	    }
	}
	
	set i 1
	foreach c $Lchn {
	    # Traite polymer
	    set Lv [$db eval "select a.aname, r.rname3l, r.rnbr, a.x, a.y, a.z, a.b, a.q, a.na from atoms as a, residues as r, chains as c, pdb as p where 
	    p.name        = '$pdb' and 
	    c.pk_pdb     = p.pk_pdb and 
	    c.name        = '$c' and 
	    r.pk_chains = c.pk_chains and 
	    r.type      != 'ligand' and 
	    a.pk_residues= r.pk_residues $Ar"]

	    foreach {an rn rr x y z b q na} $Lv {
		lappend Lres [LigneAtomePDB ATOM $i $an $rn $c $rr $x $y $z $q $b $na]
		incr i
	    }
	    if {[llength $Lchn] > 1} {
		lappend Lres "TER    "
	    }

	    # Traite ligand
	    if {$lgd} {
		set Lv [$db eval "select a.aname, r.rname3l, r.rnbr, a.x, a.y, a.z, a.b, a.q, a.na from atoms as a, residues as r, chains as c, pdb as p where 
		p.name         = '$pdb' and 
		c.pk_pdb      = p.pk_pdb and 
		r.pk_chains  = c.pk_chains and 
		c.name         = '$c' and 
		r.type        = 'ligand' and 
		a.pk_residues = r.pk_residues $Ar"]
		if {$Lv != {}} {
		    foreach {an rn rr x y z b q na} $Lv {
			lappend Lres [LigneAtomePDB HETATM $i $an $rn $c $rr $x $y $z $q $b $na]
			incr i
		    }
		    if {[llength $Lchn] > 1} {
			lappend Lres "TER    "
		    }
		}
	    }
	}
	$db eval {commit}

	lappend Lres "END   "

	if {$fileOut eq "ListeEnRetour"} {
	    return $Lres
	} else {
	    if {[info commands ::thread::*] eq ""} {
		set f [open $fileOut w]
		puts $f [join $Lres \n]
		close $f
	    } else {
		exec touch $fileOut
		foreach line $Lres {
		    exec echo "$line" >> $fileOut
		}
	    }
	}
	update
	
	return
    }


    proc Tag2MolObjAtm {i} {    
	set x [expr {[string length $i]-4}]
	scan $i "%${x}d%02d%02d" atm iobj imol

	set mol [lindex $::StrucAVoir $imol]
	set mol "::[DonneIdDeAccessPDB $mol]"
	set obj [lindex [$mol _ListeObjets] $iobj]

	return [list $mol $obj $atm]
    }

    
    oo::define Structure method GiveVar {n} {
	my variable $n

	return [set $n]
    }


    oo::define Structure method SetVar {n v} {
	my variable $n
	set $n $v
	update

	return
    }


    oo::define Structure method AddVar {n v} {
	my variable $n
	
	set $n $v
	return
    }


    oo::define Structure method _AtomesDuAtm {obj chn} {
	my variable TypChn $obj db

	set nom [my nom]
	set rtype $TypChn($chn)
	
	# if FlagRib or FlagCat are set, then some
	# Atoms may be set with ribbons ...
	if {$rtype eq "Protein"} {
	    set prib "and (a.anom in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pnrib "and (a.aname not in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pcat "and (a.aname not in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pca "and a.aname = ' CA '"
	} else {
	    set prib "and (a.aname in (' P  ', ' OP1',' OP2',' OP3',' O5''',' C5''',' C4''',' C3''',' C2''',' O2''',' C1''',' O4''',' O3''')) "
	    set pnrib "and (a.aname not in (' P  ', ' OP1',' OP2',' OP3',' O5''',' C5''',' C4''',' C3''',' C2''',' O2''',' C1''',' O4''',' O3''')) "
	    set pca "and a.aname = ' P  '"
	}

	set Lres {}
	# pass for Ca-Trace/ribbon
	if {[dict get [set $obj] FlagCat] || [dict get [set $obj] FlagRib]} {
	    set tag Cat
	    set Lv [$db eval "select r.pk_residues, r.rname3l, a.x, a.y, a.z, a.na, a.aname, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = '$rtype' and 
	    a.pk_residues = r.pk_residues and 
	    o.pk_obj = a.pk_atoms and 
	    o.atoms = 1 and 
	    (o.catrace = 1 or 
	    o.ribbon = 1) $pnrib 
	    order by a.pk_atoms"]

	    if {$Lv != {}} {
		set Ln {} ; set Lan {}
		set LX {} ; set LA {} 
		set Lna {}
		set first 1
		set Lxyz {} ; set Lnm {}
		set ncou [lindex $Lv 0]
		set rcou [lindex $Lv 1]

		foreach {n r x y z na a i} $Lv {
		    if {$n != $ncou} {
			lappend Ln $rcou
			lappend LX $Lxyz
			lappend LA $Lnm
			lappend Lan $Lna
			set Lxyz {}
			set Lnm {}
			set Lna {}
			
			set rcou $r
			set ncou $n
		    }
		    lappend Lxyz [list $x $y $z]
		    lappend Lnm  $a
		    lappend Lna $na
		}
		lappend Ln $rcou
		lappend LX $Lxyz
		lappend LA $Lnm
		lappend Lan $Lna
		
		lappend Lres [list $tag $rtype $LX $LA $Ln $Lan]
	    }
	}

	# pass for full all-atoms
	set tag Atm
	set Lv [$db eval "select r.pk_residues, r.rname3l, a.x, a.y, a.z, a.na, a.aname, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and 
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	r.type = '$rtype' and 
	a.pk_residues = r.pk_residues and 
	o.pk_obj  = a.pk_atoms and 
	o.atoms  = 1 and 
	o.ribbon  = 0 and 
	o.catrace = 0 
	order by o.pk_obj"]

	if {$Lv != {}} {
	    set Ln {} ; set Lan {}
	    set LX {} ; set LA {} 
	    set Li {} ;  set Lna {}
	    set first 1
	    set Lxyz {} ; set Lnm {}
	    set ncou [lindex $Lv 0]
	    set rcou [lindex $Lv 1]

	    foreach {n r x y z na a i} $Lv {
		if {$n != $ncou} {
		    lappend Ln $rcou
		    lappend LX $Lxyz
		    lappend LA $Lnm
		    lappend Lan $Lna
		    set Lxyz {}
		    set Lnm {}
		    set Lna {}
		    
		    set rcou $r
		    set ncou $n
		}
		lappend Lxyz [list $x $y $z]
		lappend Lnm  $a
		lappend Lna $na
	    }
	    lappend Ln $rcou
	    lappend LX $Lxyz
	    lappend LA $Lnm
	    lappend Lan $Lna
	    
	    lappend Lres [list $tag $rtype $LX $LA $Ln $Lan]
	}

	return $Lres
    }


    oo::define Structure method _AtomesToPick {obj chn} {
	# db : the structure's own database (atoms, residues, objects)
	my variable TypChn $obj db

	set nom [my nom]
	set rtype $TypChn($chn)
	
	# if FlagRib or FlagCat are set, then some
	# Atoms may be set with ribbons ...
	if {$rtype eq "Protein"} {
	    set prib "and (a.aname in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pnrib "and (a.aname not in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pcat "and (a.aname not in (' N  ', ' CA ',' C  ',' O  ')) "
	    set pca "and a.aname = ' CA '"
	} else {
	    set prib "and (a.aname in (' P  ', ' OP1',' OP2',' OP3',' O5''',' C5''',' C4''',' C3''',' C2''',' O2''',' C1''',' O4''',' O3''')) "
	    set pnrib "and (a.aname not in (' P  ', ' OP1',' OP2',' OP3',' O5''',' C5''',' C4''',' C3''',' C2''',' O2''',' C1''',' O4''',' O3''')) "
	    set pca "and a.aname = ' P  '"
	}

	set Lres {}
	# three passes :
	# first for ribbon main-chain
	if {[dict get [set $obj] FlagRib]} {
	    set tag Rib
	    set Lv [$db eval "select a.x, a.y, a.z, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = '$rtype' and 
	    a.pk_residues = r.pk_residues and 
	    o.pk_obj = a.pk_atoms and 
	    o.ribbon = 1 and 
	    o.atoms = 0 $prib 
	    order by o.pk_obj"]

	    if {[llength $Lv] > 3} {
		set Lres $Lv
	    }
	}

	# pass for Ca-Trace
	if {[dict get [set $obj] FlagCat]} {
	    set tag Cat
	    set Lv [$db eval "select a.x, a.y, a.z, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = '$rtype' and 
	    a.pk_residues = r.pk_residues and 
	    o.pk_obj = a.pk_atoms and 
	    o.catrace = 1 and
	    o.atoms = 0 $pca 
	    order by a.pk_atoms"]

	    if {[llength $Lv] > 3} {
		lappend Lres {*}$Lv
	    }
	}

	# pass for Cat/ribbon + atoms
	if {[dict get [set $obj] FlagCat] || [dict get [set $obj] FlagRib]} {
	    set tag Atm
	    set Lv [$db eval "select a.x, a.y, a.z, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = '$rtype' and 
	    a.pk_residues = r.pk_residues and 
	    o.pk_obj  = a.pk_atoms and 
	    o.atoms  = 1 and 
	    (o.ribbon = 1 or  
	    o.catrace = 1) $pnrib 
	    order by o.pk_obj"]
	    
	    if {[llength $Lv] > 3} {
		lappend Lres {*}$Lv
	    }
	}

	# pass for full all-atoms
	set tag Atm
	set Lv [$db eval "select a.x, a.y, a.z, a.pk_atoms from residues as r, atoms as a, $obj as o, chains as c, pdb as p where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and 
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	r.type = '$rtype' and 
	a.pk_residues = r.pk_residues and 
	o.pk_obj  = a.pk_atoms and 
	(o.atoms = 1 or 
	o.cpk     = 1 or 
	o.pearl   = 1) and 
	o.ribbon  = 0 and 
	o.catrace = 0 
	order by o.pk_obj"]

	if {[llength $Lv] > 3} {
	    lappend Lres {*}$Lv
	}

	return $Lres
    }


    oo::define Structure method _AtomesDuCaTrace {obj chn} {
	my variable TypChn db
	
	set nom [my nom]
	set rtype $TypChn($chn)
	if {$TypChn($chn) eq "Protein"} {
	    set caatm " CA "
	} elseif {$TypChn($chn) eq "Nucleic"} {
	    set caatm " P  "
	} else {
	    return 0
	}
	
	set Lv [$db eval "select o.cacol, a.x, a.y, a.z from atoms as a, $obj as o, residues as r, chains as c, pdb as p where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	r.type = '$rtype' and 
	a.pk_residues = r.pk_residues and 
	a.aname = '$caatm' and 
	o.pk_obj = a.pk_atoms and 
	o.catrace = 1  
	order by o.pk_obj"]

	# pas de catrace 
	if {$Lv == {}} {return 0}

	set Lcac {}
	foreach {c x y z} $Lv {
	    lappend Lcac [list $x $y $z [RGBDeLaTkCol $c]]
	}
	set Lcac [TestCoupeMainChain $rtype $Lcac]

	return $Lcac
    }


    oo::define Structure method _AtomesDuPearl {obj chn} {
	my variable TypChn db
	
	set nom [my nom]
	set rtype $TypChn($chn)
	if {$TypChn($chn) eq "Protein"} {
	    set caatm " CA "
	} elseif {$TypChn($chn) eq "Nucleic"} {
	    set caatm " P  "
	}
	
	set Lcac [$db eval "select a.x, a.y, a.z, o.cacol from atoms as a, $obj as o, residues as r, chains as c, pdb as p where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and 
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	r.type = '$rtype' and 
	a.pk_residues = r.pk_residues and 
	a.aname = '$caatm' and 
	o.pk_obj = a.pk_atoms and 
	o.pearl = 1 
	order by o.pk_obj"]

	return $Lcac
    }


    oo::define Structure method _AtomesDuCpk {obj chn} {
	my variable TypChn $obj db

	set nom [my nom]
	# must make two pass :
	# - if ribbon set on the residue no main chain
	# - if ribbon not set , send all atoms
	if {[set TypChn($chn)] eq "Protein"} {
	    set exp " and (a.aname != ' CA ' and a.aname != ' C  ' and a.aname != ' N  ' and a.aname != ' O  ') "
	} else {
	    set exp ""
	}

	set La [$db eval "select a.x, a.y, a.z, a.na, o.atmcol from pdb as p, chains as c, atoms as a, $obj as o where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and 
	c.name = '$chn' and 
	a.pk_chains = c.pk_chains and 
	o.pk_obj = a.pk_atoms and 
	o.cpk = 1 and 
	o.ribbon = 0 order by pk_obj"]

	lappend La {*}[$db eval "select a.x, a.y, a.z, a.na, o.atmcol from pdb as p, chains as c, residues as r, atoms as a, $obj as o where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and 
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	a.pk_residues = r.pk_residues and 
	o.pk_obj = a.pk_atoms and 
	o.cpk = 1 and 
	o.ribbon = 1 $exp 
	order by pk_obj"]
	#puts ">>$La<<"
	return $La
    }


    oo::define Structure method _AtomesDuRibbon {obj chn} {
	my variable TypChn db

	set nom [my nom]
	set rtype $TypChn($chn)
	if {$rtype eq "Protein"} {
	    set caatm " CA "
	} elseif {$rtype eq "Nucleic"} {
	    set caatm " P  "
	} else {
	    return 0
	}
	
	set iLca {} ; set iLc {} ; set iLo {} ; set iLcol {}
	set Lca {} ; set Lc {} ; set Lo {} ; set Lcol {}
	set Lpca {} ; set Lpc {} ; set Lpo {}
	set tmp [$db eval "select distinct r.pk_residues, a.x, a.y, a.z, o.ribcol from atoms as a, $obj as o, residues as r, chains as c, pdb as p where 
	p.name = '$nom' and 
	c.pk_pdb = p.pk_pdb and
	c.name = '$chn' and 
	r.pk_chains = c.pk_chains and 
	r.type = '$rtype' and 
	a.pk_residues = r.pk_residues and 
	a.aname = '$caatm' and 
	o.pk_obj = a.pk_atoms and 
	o.ribbon = 1 
	order by a.pk_atoms"]

	# pas de ribbon !
	if {$tmp == {}} {
	    return 0
	}

	foreach {p x y z c} $tmp {
	    lappend Lpca $p
	    lappend iLcol [RGBDeLaTkCol $c]
	    lappend iLca [list $x $y $z]
	}
	if {$obj eq "obj_tRNA"} {
	    puts "tRNA nb P : [llength $Lca]"
	}

	if {$rtype eq "Protein"} {
	    set tmp [$db eval "select distinct r.pk_residues, a.x,a.y,a.z from atoms as a, $obj as o, residues as r, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = 'Protein' and 
	    a.pk_residues = r.pk_residues and 
	    a.aname = ' C  ' and 
	    o.pk_obj = a.pk_atoms and 
	    o.ribbon = 1 
	    order by a.pk_atoms"]
	    foreach {p x y z} $tmp {
		lappend Lpc $p
		lappend iLc [list $x $y $z]
	    }
	    
	    set tmp [$db eval "select r.pk_residues, a.x,a.y,a.z from atoms as a, $obj as o, residues as r, chains as c, pdb as p where 
	    p.name = '$nom' and 
	    c.pk_pdb = p.pk_pdb and 
	    c.name = '$chn' and 
	    r.pk_chains = c.pk_chains and 
	    r.type = 'Protein' and 
	    a.pk_residues = r.pk_residues and 
	    a.aname = ' O  ' and 
	    o.pk_obj = a.pk_atoms and 
	    o.ribbon = 1 
	    order by a.pk_atoms"]
	    foreach {p x y z} $tmp {
		lappend Lpo $p
		lappend iLo [list $x $y $z]
	    }

	    if {$Lpca != $Lpc} {
		if {[llength $iLca] > [llength $iLc]} {
		    set i 0 ; set Li {}
		    foreach pa $Lpca {
			if {$pa ni $Lpc} {lappend Li $i}
			incr i
		    }
		    set Li [lreverse $Li]
		    foreach i $Li {
			set iLca  [lreplace $iLca $i $i]
			set iLcol [lreplace $iLcol $i $i]
		    }
		} else {
		    set i 0 ; set Li {}
		    foreach p $Lpc {
			if {$p ni $Lpca} {lappend Li $i}
			incr i
		    }
		    set Li [lreverse $Li]
		    foreach i $Li {
			set iLc   [lreplace $iLc $i $i]
			set iLo   [lreplace $iLo $i $i]
		    }
		}
	    }
	}

	set Lca  $iLca
	set Lcol $iLcol
	if {$rtype eq "Protein"} {
	    set Lc   $iLc
	    set Lo   $iLo
	}

	# regarde si le ribbon est coupe en 
	# plusieurs morceaux
	set Lat [TestCoupeMainChain $rtype $Lca $Lcol $Lc $Lo]
	return $Lat
    }

	
    oo::define Structure method updateObjFlags {obj} {
	my variable $obj db
	
	# update flags 
	$db eval {begin transaction}
	foreach k {catrace atoms ribbon pearl cpk surface} n {Cat Atm Rib Prl CPK Srf} {
	    set v [expr {[$db eval "select count(pk_obj) from $obj where $k = 1"] > 0}]
	    dict set $obj Flag$n $v
	}
	$db eval {commit}

	return
    }
    
    
    oo::define Structure method ResetDrawing {} {
	set LObj [my _ListeObjets]
	if {$LObj == {} } {return}

	my variable db {*}$LObj
	
	foreach obj $LObj {
	    dict set $obj globj 0
	    my _dellist $obj
	}

	return
    }

    oo::define Structure method _dbEval {cmd} {
	my variable db
	
	set res [$db eval $cmd] 

	return $res
    }

    oo::define Structure method RotTrans {chn {LRot ""} {LTrans ""}} {
	# applique x' = Rot.x + Trans aux atomes de la chaine chn
	# (Rot/Trans en "array get", par defaut ceux de l'objet),
	# dans la base et dans AtmXYZ (lu par CoordsDeAtom ...)
	my variable Rot Trans db AtmXYZ

	set nom [my nom]

	if {$LRot eq ""} {set LRot $Rot}
	if {$LTrans eq ""} {set LTrans $Trans}
	array set TM $LRot
	array set TT $LTrans
	set M [M_T TM]
	set T [V_T TT]
	lassign $M aM bM cM
	lassign $T t1 t2 t3

	$db eval {begin transaction}
	set Lr [$db eval {select a.x,a.y,a.z,a.pk_atoms from atoms as a, chains as c, pdb as p where \
			      p.name = $nom and \
			      c.pk_pdb = p.pk_pdb and \
			      c.name = $chn and \
			      a.pk_chains = c.pk_chains}]
	
	foreach {x y z ix} $Lr {
	    set nx [VMT $x $y $z $aM $t1]
	    set ny [VMT $x $y $z $bM $t2]
	    set nz [VMT $x $y $z $cM $t3]

	    $db eval {update atoms set x=$nx, y=$ny, z=$nz where pk_atoms=$ix}
	}
	
	$db eval {commit}

	if {[info exists AtmXYZ($chn)]} {
	    set Lnew {}
	    foreach Lres $AtmXYZ($chn) {
		set Lr {}
		foreach xyz $Lres {
		    lassign $xyz x y z
		    lappend Lr [list [VMT $x $y $z $aM $t1] [VMT $x $y $z $bM $t2] [VMT $x $y $z $cM $t3]]
		}
		lappend Lnew $Lr
	    }
	    set AtmXYZ($chn) $Lnew
	}
	
	[self] _Dimensions
	[self] ResetDrawing
    }

    oo::define Structure method CopiePDB {new} {
	my variable db

	set newCmd ::[string trimleft $new ":"]
	oo::copy [self] $newCmd

	set newdb "OrdDB_root_pdb${new}_[clock scan now]"

	# Change the comand attached to the database in the
	# global namespace to the new object
	rename ::$db ::$newdb

	$newCmd SetVar db $newdb
	$newCmd SetVar StrucID $new

	# The database contains the name of the object. Change it to the neww object name
	set pkp [$newdb eval {select pk_pdb from pdb}]
	::$newdb eval {update pdb set name=$new where pk_pdb=$pkp}

	return
    }


    oo::define Structure method serializeDB {} {
	my variable db SecStr SecStrRaw

	# secondary structure is not in the db tables
	# (for CIF it does not come from the header) :
	# store the raw one in table secstr
	if {[info exists SecStrRaw]} {
	    set Lss [array get SecStrRaw]
	} else {
	    set Lss [array get SecStr]
	}
	$db eval {create table if not exists secstr (chain text, entry text)}
	$db eval {delete from secstr}
	foreach {chn Lentry} $Lss {
	    foreach entry $Lentry {
		$db eval {insert into secstr values ($chn, $entry)}
	    }
	}

	return [SqliteSerialize $db]
    }


    oo::define Structure method deserializeDB {data} {
	my variable db

	# [self] is ::XXXX : a "::" in the handle name
	# would make it a namespace-qualified command
	set db "OrdDB_root_pdb[string trimleft [self] :]_[clock seconds]"
	sqlite3 $db ":memory:"
	SqliteDeserialize $db $data

	return
    }

    
    oo::define Structure export AllSphereAround SphereAround _dbEval CPK CopiePDB CoordsSeq2PDB CoordsPDB2Seq _SetB _EtatDeObjet ObjetOn ObjetOff _ListeObjets _mapfeat _dellist Ind2Obj AddPicked AtomXYZ _chains _chainIs _rescoords _resnumber _resname _Dimensions SecStr PDBInfos SSBin CoordsDeAtom AddVar GiveVar ClearPicked SetVar _SetupPicking AllLabels ResetDrawing ResidueCDM dbref strucid _seqres title _seqadv _lookup _source _RemplitLeSQL RotTrans

    return
}


proc RescaleNormale {a1 a3 {cof 2.}} {
    lassign $a1 nx ny nz
    lassign $a3 vx vy vz
    
    set rx [expr {$vx+$cof*$nx}]
    set ry [expr {$vy+$cof*$ny}]
    set rz [expr {$vz+$cof*$nz}]
    
    return [list $rx $ry $rz]
}


proc DebugRib {l} {
    #dont_use_light

    set l [lindex $l 1]
    set i 0
    set col magenta
    set coltmp cyan
    foreach {n1 c1 v1 n2 c2 v2 n3 c3 v3} $l {
	if {1} {
	    puts [format "Pts 1 %8.3f %8.3f %8.3f" {*}$a3]
	    puts [format "Pts 2 %8.3f %8.3f %8.3f" {*}$b3]
	    puts [format "Pts 3 %8.3f %8.3f %8.3f" {*}$c3]
	    puts [format "Nrm 1 %8.3f %8.3f %8.3f" {*}$a1]
	    puts [format "Nrm 2 %8.3f %8.3f %8.3f" {*}$b1]
	    puts [format "Nrm 3 %8.3f %8.3f %8.3f" {*}$c1]
	    puts ""
	}

	if {! ($i%4)} {
	    puts "$i col $col coltmp $coltmp"
	    set col2 $col
	    set col $coltmp
	    set coltmp ${col2}
	    set vcol [RGBDeLaTkCol $col]
	    puts " -> col $col coltmp $coltmp"
	}
	
	# triangle
	glColor3fv $vcol
	glBegin GL_LINES
	glVertex3fv $v1
	glVertex3fv $v2
	glEnd
	
	glColor3fv $vcol
	glBegin GL_LINES
	glVertex3fv $v2
	glVertex3fv $v3
	glEnd
	
	glColor3fv $vcol
	glBegin GL_LINES
	glVertex3fv $v1
	glVertex3fv $v3
	glEnd	
	
	if {0} {
	    # Normals
	    set n1 [RescaleNormale $n1 $v1]
	    set n2 [RescaleNormale $n2 $v2]
	    set n3 [RescaleNormale $n3 $v3]
	    glBegin GL_LINES
	    glVertex3fv $v1
	    glVertex3fv $n1
	    glEnd
	    
	    glBegin GL_LINES
	    glVertex3fv $n2
	    glVertex3fv $v2
	    glEnd
	    
	    glBegin GL_LINES
	    glVertex3fv $n3
	    glVertex3fv $v3
	    glEnd
	}
	incr i
	if {$i > 40} {break}
    }
    
    glEnd
    return
}


proc BonObjName {obj} {
    if {! [regexp {^obj_} $obj]} {
	set obj "obj_${obj}"
    }

    return $obj
}


proc NomAtomeFormatPDB {aname {element ""}} {
    # mmCIF atom names (label_atom_id) are not padded
    # ("CA", "OP1"). Give them the PDB format (columns
    # 13-16, 4 characters) used everywhere else :
    # - 4 characters names are kept as is ("HD11")
    # - one letter element : name starts at the 2nd
    #   character : " CA ", " OP1", " O5'"
    # - two letters element (metals, halogens, Se ...) :
    #   name left aligned : "CA  " (calcium), "MG  ", "SE  "
    # element is _atom_site.type_symbol ; if empty, the
    # element is taken as the first letter of the name.
    set aname [string trim $aname]
    if {[string length $aname] >= 4} {
	return [string range $aname 0 3]
    }
    set element [string toupper [string trim $element]]
    if {[string length $element] == 2 \
	    && [string equal -length 2 $element [string toupper $aname]]} {
	return [format "%-4s" $aname]
    }

    return [format " %-3s" $aname]
}


proc LigneAtomePDB {rec i an rn c rr x y z q b na} {
    # one ATOM/HETATM line in the PDB format :
    # residue number and insertion code (col. 23-27),
    # element symbol (col. 77-78)
    set rr [string trimleft $rr 0]
    if {$rr eq ""} {set rr 0}
    set ic ""
    if {[regexp {^(-?[0-9]+)([A-Za-z])$} $rr -> n ic]} {
	set rr $n
    }
    set an [string map {"''" "'"} $an]

    return [format "%-6s%5d %4s %3s %1s%4s%1s   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s" \
		$rec $i $an $rn $c $rr $ic $x $y $z $q $b [SymboleDeNoAtomic $na]]
}


proc NoAtomicDeNomPDB {aname} {
    # atomic number from an atom name in the PDB format
    # (see NomAtomeFormatPDB) :
    # " CA " -> C, "CA  " -> Ca, "HD11" -> H, "1HB " -> H
    if {[string index $aname 0] eq " "} {
	set e [string index $aname 1]
    } elseif {[string is digit [string index $aname 0]]} {
	set e [string index [string trimleft $aname 0123456789] 0]
    } elseif {[string length [string trim $aname]] < 4} {
	set e [string range $aname 0 1]
    } else {
	set e [string index $aname 0]
    }

    return [NoAtomicDe $e]
}


proc ObjectAlreadyExists {obj} {
    set obj [BonObjName $obj]
    return [expr {$obj in [GetTables]}]
}


proc LoadObjFromDB {} {
    # objects of an ORD file : their tables are in the DB of each
    # structure. Drawn by AfficheDansViandox, with the other objects.
    # (only the displayed ones : the others are not set up for display)
    set nobj 0
    foreach pdb [lsort -unique [lmap e $::StrucAVoir {DonneIdDeAccessPDB $e}]] {
	foreach obj [$pdb _dbEval {select name from sqlite_master where type='table' and name glob 'obj_*' order by rowid}] {
	    if {$obj in [$pdb _ListeObjets]} {continue}

	    $pdb newObj $obj 1
	    $pdb updateObjFlags $obj

	    incr nobj
	}
    }
    
    return $nobj
}


proc CreatePDBFromDB {} {
    global HashPDB ListePDB BadPDB Warn LNOrdali

    set LNoms $LNOrdali
    set Lopdb [info class instances Structure]
    set HashPDB(iHmax) 0
    set BadPDB {}
    set ListePDB {}
    set ix -1
    foreach n $LNoms {
	incr ix
	if {! [EstUnAccessPDB $n]} {
	    continue
	}

	set nom [DonneIdDeAccessPDB $n]
	set chn [DonneChainDeAccessPDB $n]
	set nom "::$nom"
	if {$nom ni $Lopdb} {
	    # Mauvais PDB
	    lappend Warn(BadPdb) $nom
	    set Warn($nom) 1
	    lappend BadPDB $ix
	    continue
	}

	set Warn($nom) 0
	# structures read from an ORD file are already
	# rebuilt by DecortiqueUnORD. ($nom is ::XXXX,
	# [info commands] returns XXXX : test with the
	# qualified name)
	if {[$nom _chains] ne {}} {
	    # PDB deja vu, enregistre juste la chaine
	    lappend ListePDB [BonNomPDB ${nom}_$chn]
	    continue
	}

	# new returns {StrucID id} or {Error msg}
	lassign [$nom new $nom "" 1] what
	if {$what ne "StrucID"} {
	    lappend BadPDB $ix
	} else {
	    lappend ListePDB [BonNomPDB ${nom}_$chn]
	    set iH $HashPDB(iHmax)
	    set HashPDB($nom) $iH
	    set HashPDB($iH) $nom
	    incr iH
	    set HashPDB(iHmax) $iH
	}
    }
    
    return
}


proc InfosDesPDB {} {
    if {$::Defauts(DownloadPDB) eq "dont"} {
	return
    }
        
    set Lcmds [info commands]
    foreach e $::ListePDB {
	set mol [DonneIdDeAccessPDB $e]
	if {$mol ni $Lcmds && "::$mol" ni $Lcmds} {
	    puts "$mol not in commands !"
	    continue
	}
	set chn [DonneChainDeAccessPDB $e]

	$mol PDBInfos $chn
    }

    return
}


#rR rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout rajout 
proc LitHelixDansCIF {fichierCif {chaine ""}} {
    #rR Attention, onlit tout en une seule fois et on rend tout
    #rR Attention on est obligé de travailler avec Label en entrée. On aura Auth en sortie
    set Label [CifAsym $chaine Label $fichierCif]
    set LesLignes [CifEx _struct_conf pdbx_PDB_helix_id,beg_auth_asym_id,beg_auth_seq_id,beg_auth_comp_id,end_auth_seq_id,end_auth_comp_id,pdbx_PDB_helix_class,pdbx_PDB_helix_length WHERE beg_label_asym_id EQ $Label AND File EQ $fichierCif]
    
    set LeRetour {}
    foreach Ligne $LesLignes {
	lassign [split $Ligne "\t"] HelNm NomChnDep NomResDep TypResDep NomResFin TypResFin ClassHel LongHel
	switch $ClassHel {
	    1  {set Type "Alpha"}
	    3  {set Type "Pi"}
	    5  {set Type "3_10"}
	    10 {set Type "polyP"}
	    default {set Type "Alpha"}
	}
	lappend LeRetour "Helix $Type $HelNm $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin $LongHel"
    }
    return $LeRetour
}


proc LitSheetDansCIF {fichierCif {chaine ""}} {
    #rR Attention, onlit tout en une seule fois et on rend tout

    #rR Attention on est obligé de travailler avec Label en entrée et en sortie on aura Auth
    set Label [CifAsym $chaine Label $fichierCif]
    set LesLignes [CifEx _struct_sheet_range sheet_id,id,beg_auth_asym_id,beg_auth_seq_id,beg_auth_comp_id,end_auth_seq_id,end_auth_comp_id WHERE beg_label_asym_id EQ $Label AND File EQ $fichierCif]
    if {$LesLignes==""} { return "PasBon" }
    
    set LeRetour {}
    set Previous ""
    foreach Ligne $LesLignes {
	lassign [split $Ligne "\t"] SheetID StrandID NomChnDep NomResDep TypResDep NomResFin TypResFin
	if {$StrandID==1} {
	    set SensStrd 0
	} else {
	    set Sens [CifEx _struct_sheet_order sense WHERE sheet_id EQ $SheetID AND range_id_2 EQ $StrandID AND File EQ $fichierCif]
	    if {$Sens=="parallel"} {
		set SensStrd 1
	    } else {
		set SensStrd -1
	    }
	}
	lappend LeRetour "Sheet $SheetID $StrandID $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin $SensStrd"
    }
    return $LeRetour
}


proc LitTurnDansCIF {laligne {chaine ""}} {
    # Numerotation format PDB commence a 1 et TCL a 0.
    # Rajoute un blanc en debut de ligne pour avoir coherence
    set laligne " $laligne"
    
    set TurnNm [string range $laligne  8 10]
    
    set TypResDep [string range $laligne 16 18]
    set NomChnDep [string range $laligne 20 20]
    set NomResDep [string range $laligne 21 24]
    
    set TypResFin [string range $laligne 27 29]
    set NomChnFin [string range $laligne 31 31]
    set NomResFin [string range $laligne 32 35]
    
    if {$NomChnDep eq $chaine || $chaine eq ""} {
	return "Turn XXX $TurnNm $NomChnDep $NomResDep $TypResDep $NomResFin $TypResFin"
    } else {
	return "PasBon"
    }
}



proc EstUnNucleotide AtomName {
    global EstUnNucleotide
    if {[info exists EstUnNucleotide($AtomName)]} { return $EstUnNucleotide($AtomName) }
    set AtomName [string toupper $AtomName]
    if {[regexp {^(P[0-9]|O[0-9P]|C[0-9]|N[0-9]|O[0-9])} $AtomName]} {
	set EstUnNucleotide($AtomName) 1
	return 1
    }
    set EstUnNucleotide($AtomName) 0
    return 0	
}

proc tcif {{pdbid ""} {OnTestePdb ""}} {
    #rR pour tester Structure avec un fichier .cif
    if {$pdbid==""} { set pdbid "1asy"}
    set PDBID [string toupper $pdbid]
    #set file "/db/catalog/pdb/compressed_files/[string range $pdbid 1 2]/pdb${pdbid}.ent.gz"
    set FichierPdb "/home/ripp/cif/store/$pdbid.pdb"
    set FichierCif "/home/ripp/cif/store/$PDBID.cif"
    regsub "/home/ripp/cif/store/" $FichierCif "store/" FichierCif
    
    if { $OnTestePdb=="" } { 
	#rR Je commence doucement en faisant en parallèle le Pdb et le Cif
	set AsymAndEntities [Cif AsymAndEntities . $FichierCif]      ; #rR permet d'initialiser 
	set LabelAuth       [CifAsym ListOf LabelAuth $FichierCif]   ; #rR permet d'initialiser
    }
    set FichierATester $FichierCif
    if { $OnTestePdb!="" } {
	set FichierATester $FichierPdb
	if { ! [file exists $FichierATester]} {
	    set FichierATester $PDBID
	}
    }

    if {0} {
	Structure create $pdbid
	set cok [$pdbid new $FichierATester "" 0 0]
	if { ! $cok } { return "Ca merde pour tcif" }
    } else {
	set pdbid [LoadNouveauPDB $FichierATester $pdbid]
	if {$pdbid==0} { return "Ca merde pour tcif LoadNouveauPdb rend $pdbid" }
    }
    foreach c [$pdbid _chains] {
	set s [join [$pdbid _resname -chain $c] ""]
	if {0} {
	    Espionne $c _source\n[$pdbid _source $c]
	    Espionne $c _seqres\n[$pdbid _seqres $c]
	    Espionne $c SecStr \n[$pdbid SecStr -chain $c]
	    Espionne $c Helix  \n[$pdbid SSBin helix $c]
	    Espionne $c Sheet  \n[$pdbid SSBin sheet $c]
	    Espionne $c Turn   \n[$pdbid SSBin turn  $c]
	    EspionneL AsymAndEntities\n[$pdbid asym AsymAndEntities]
	}
	}
    #Espionne tcif a terminé avec FichierATester $FichierATester
    return "fin de tcif"
}

proc tcr2 {} {
    # set the PDB ID you want to download
    set pdb_id "1ake"
    # define the URL for the PDB file in mmCIF format (the current standard)
    set url "https://files.wwpdb.org/pub/pdb/data/structures/divided/pdb/[string range ${pdb_id} 1 2]/${pdb_id}.ent.gz"
    # define the output filename
    set output_file "${pdb_id}.pdb.gz"
    
    # Check if curl is available
    if {[catch {exec curl --version} result]} {
	puts "Error: curl is not installed or not in your system's PATH."
	exit
    }
    
    # Use 'exec' to run curl and download the file
    # -o flag specifies the output file
    # -s flag makes curl silent (no progress bar)
    puts "Downloading PDB entry $pdb_id from wwpdb.org..."
    if {[catch {exec curl -s -o $output_file $url} result]} {
	puts "Error downloading file: $result"
    } else {
	#puts "Successfully downloaded $output_file."
    }    

    exit
}


proc tcr {} {
    set pdbid 1eov
    set middle eo
    #set url "https://files.wwpdb.org/pub/pdb/data/structurres/devided/pdb/eo/pdb1eov.ent.gz"
    set url "https://files.wwpdb.org/pub/pdb/data/structurres/devided/pdb/eo/pdb1eov.ent.gz"
    set url "https://files.wwpdb.org/pub/pdb/data/structures/divided/pdb/eo/pdb1eov.ent.gz"

    package require TclCurl

    if {0} {
	exec curl --compressed $url -o toto.gz > /dev/null 2> /dev/null
	set FichierPDB toto.gz
	#set o [open toto.gz w]
	#puts $o $compData
	#close $o
	set o [open $FichierPDB]
	zlib push gunzip $o
	set TextePDB [read $o]
	close $o
	puts "$TextePDB"
	exit
	
	puts "compData $compData"
	#set binData [zlib decompress $compData]
	set binData [zlib gunzip $compData]
	puts "\nbinData $binData"
	set TextePDB [encoding convertfrom utf-8 $binData]		
    } else {
	::curl::transfer -url $url -followlocation 1 -bodyvar compData
	puts "compData $compData"
	set binData [zlib gunzip $compData]
	puts "\nbinData \n$binData"
	set TextePDB [encoding convertfrom utf-8 $binData]		

    }
    exit
}


proc tspid {} {
    set file 1il2.pdb
    set id qsdfqseddfqsdftralala
    set Lcmds [info commands]
    set out [lsearch -glob -all -inline $Lcmds "*tralala*"]
    puts "out= $out"
    Structure create $id
    set init 0
    set indb 1
    set cok [$id new $file "" $init $indb]
    puts "cok $cok"

    exit
}


proc tstcif {} {
    set file /home/moumou/fold_iars2_mg_zinc_model_0.cif
    set file /home/moumou/alitest/4hhb.pdb
    set file P81889
    set file 1il2
    set file /home/moumou/alitest/qmsldkfjlmkqsddjf.pdb
    
    set cIn [info commands]

    #set cok [LoadNouveauPDB $file "QSDF" 0 1]
    set cok [LoadNewStructure  $file "" 0 1]
    puts "cok $cok"
    set cOut [info commands]
    puts "lor [lor $cIn $cOut]"
    lassign $cok what desc
    puts "what $what"
    puts "desc $desc"
    if {$what eq "Obsolete"} {
	lassign $desc old newid
    }
    if  {$what eq "StrucID"} {
	set id $desc
	puts "strucid [$id strucid]"
	foreach c [$id _chains] {
	    puts "\nchain $c"
	    puts "[join [$id _resname -chain $c] ""]"
	}
    }

    exit
	 }


proc tstcif2 {} {
    set file /home/moumou/fold_iars2_mg_zinc_model_0.cif
    Structure create QSDF
    # LoadNouveauPDBD est dans ordali_sequence.tcl
    set cok [LoadNouveauPDB $file QSDF 0 1]
    puts "cok $cok"
    foreach c [QSDF _chains] {
	puts "\nchain $c"
	puts "[join [QSDF _resname -chain $c] ""]"

    }
	     exit
	 }

    
    
    #rR fin

    
