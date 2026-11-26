# -*- coding:utf-8 -*-

#
#
# --- ordali_service.tcl
#

proc GetPrositeFromUniprot {uniprot_id} {
    package require json
    package require http
    package require tls
    
    ::http::register https 443 [list ::tls::socket]

    set url "https://www.ebi.ac.uk/interpro/api/entry/prosite/protein/uniprot/${uniprot_id}/"
    set headers [list Accept "application/json" User-Agent "Tcl-InterPro-Client/1.0"]

    set token [http::geturl $url -headers $headers -timeout 30000]
    set status [http::status $token]
    set ncode  [http::ncode $token]
    if {$status ne "ok" || $ncode != 200} {
        set err "Erreur API InterPro ($status, code $ncode) for $uniprot_id"
        http::cleanup $token
        #error $err
	puts "$err"
	return ""
    }

    set body [http::data $token]
    http::cleanup $token

    set data    [json::json2dict $body]
    set results [dict get $data results]
    
    set prosite_entries {}
    
    foreach entry $results {
        set metadata   [dict get $entry metadata]
        set accession  [dict get $metadata accession]
        set name       [dict get $metadata name]
        set entry_type [dict get $metadata type]

        # Accession is already a PS ID. Retrieve it directly
        # worlks like member_database key
        set pattern [GetPrositePattern $accession]
	
        # If member_databases is présent, collect also other patterns
        # signatures associated with other patterns
        set prosite_ids [list [list $accession $name $pattern]]

        if {[dict exists $metadata member_databases]} {
            set member_dbs [dict get $metadata member_databases]

            foreach db {prosite profile} {
                if {[dict exists $member_dbs $db]} {
                    foreach {ps_id ps_name} [dict get $member_dbs $db] {
                        # Do not retrieve principal access already treated
                        if {$ps_id eq $accession} continue
                        if {$db eq "profile"} {
                            lappend prosite_ids \
                                [list $ps_id $ps_name "(profil - pas de pattern texte)"]
                        } else {
                            set p [get_prosite_pattern $ps_id]
                            lappend prosite_ids [list $ps_id $ps_name $p]
                        }
                    }
                }
            }
        }

        # Positions de match sur la séquence
        set locations {}
        if {[dict exists $entry proteins]} {
            foreach protein [dict get $entry proteins] {
                if {[dict exists $protein entry_protein_locations]} {
                    foreach loc [dict get $protein entry_protein_locations] {
                        foreach frag [dict get $loc fragments] {
                            set start [dict get $frag start]
                            set end   [dict get $frag end]
                            lappend locations [list $start $end]
                        }
                    }
                }
            }
        }

        lappend prosite_entries [dict create \
            interpro_accession $accession \
            interpro_name       $name \
            type                 $entry_type \
            prosite_signatures   $prosite_ids \
            locations            $locations]
    }

    return $prosite_entries
}


proc GetPrositePattern {ps_accession} {
    ::http::register https 443 [list ::tls::socket]

    set url "https://prosite.expasy.org/${ps_accession}.txt"
    set headers [list User-Agent "Tcl-PROSITE-Client/1.0"]
    
    set token [http::geturl $url -headers $headers -timeout 30000]
    set status [http::status $token]
    set ncode  [http::ncode $token]
    if {$status ne "ok" || $ncode != 200} {
	puts "\nError : when fetching InterPro, ncode $ncode"
        http::cleanup $token
        return ""
    }

    set body [http::data $token]
    http::cleanup $token

    # Extraire la ligne PA (pattern) — peut s'étendre sur plusieurs lignes PA
    set pattern ""
    foreach line [split $body "\n"] {
        if {[regexp {^PA\s+(.+)$} $line -> fragment]} {
            append pattern $fragment
        }
    }

    # Retirer le point final PROSITE
    set pattern [string trimright [string trim $pattern] "."]

    return $pattern
}


proc GetUniprotFastaSequencesPOST {liste_ids} {
    # retrieve fastta sequence for a bunch of unirpot ACC/ID.
    # use POST protocol

    package require json ;# Issu de tcllib pour lire le Job ID
    
    # configuration of the SSL/TLS layer for https
    ::http::register https 443 [list ::tls::socket -autoservername 1]
    
    set url_run "https://rest.uniprot.org/idmapping/run"
    
    # Preparation o data for POST form
    # mapping of ACC+ID of entries to ACC.
    set identifiants_joints [join $liste_ids ","]
    set requete_data [::http::formatQuery \
			  from "UniProtKB_AC-ID" \
			  to "UniProtKB" \
			  ids $identifiants_joints \
    ]
    
    #puts "Sending of [llength $liste_ids] identifiants via POST to UniProt..."
    
    # 1. Job submission
    set token [::http::geturl $url_run -query $requete_data -type "application/x-www-form-urlencoded"]
    set code [::http::ncode $token]
    set reponse [::http::data $token]
    puts "reponse $reponse"
    ::http::cleanup $token
    
    if {$code != 200 && $code != 210} {
        puts "Erreur lors de la soumission POST (Code HTTP : $code)"
        return 0
    }

    # Get JobID from response
    set dict [::json::json2dict $reponse]
    if {[dict exists $dict "jobId"]} {
	set job_id [dict get $dict "jobId"]
} else {
    puts "Error : No job ID found in json response !"
    return 0
}
    		
    #    puts "Job soumis avec succ�s. ID du traitement : $job_id"
    #    puts "Attente de la pr�paration du fichier FASTA..."
    
    # 2. Status checking
    set url_status "https://rest.uniprot.org/idmapping/status/${job_id}"

    set pret 0
    while {!$pret} {
        after 3000 ;# Attendre 3 secondes entre chaque v�rification
        
        set token [::http::geturl $url_status]
        set code_status [::http::ncode $token]
        ::http::cleanup $token
        
        if {$code_status == 200} {
            # if status =200 then the file is ready to be downloaded
            set pret 1
        } elseif {$code_status == 303} {
            # Sometimes uniprot uses 303 status code to say file is ready
            set pret 1
        } else {
            #puts "En cours de traitement par UniProt..."
        }
    }
    
    # 3. Download results in fasta formata
    set url_resultats "https://rest.uniprot.org/idmapping/uniprotkb/results/${job_id}?format=fasta"
    #puts "T�l�chargement du fichier FASTA final..."
    
    set token [::http::geturl $url_resultats]
    set code_final [::http::ncode $token]
    set data_fasta [::http::data $token]
    ::http::cleanup $token
    
    if {$code_final == 200} {
        return $data_fasta
    } else {
	puts "Error : while downloading results (Code HTTP : $code_final)"
        return 0
    }
}


proc GetUniprotFastaSequences {Lacc} {
    # url for ONE sequence request
    # set url "https://rest.uniprot.org/uniprotkb/$Lacc.fasta"
    #


    # Configuration of the SSL/TLS layer for https
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    set Lacc [lmap a $Lacc {set x "(accession:$a)"}]
    set nAcc [llength $Lacc]


    # bunch of 200 accession
    set bunchSize 200
    set bunchSizem1 [expr {$bunchSize -1}]
    set data ""
    for {set i 0} {$i < $nAcc} {incr i $bunchSize} {
	set Lreq [lrange $Lacc $i $i+$bunchSizem1]
	set url "https://rest.uniprot.org/uniprotkb/stream?format=fasta&query=[join $Lreq OR]"

    # HTTP GET request
	set token [::http::geturl $url]
	set code [::http::ncode $token]
	append data [::http::data $token]
	::http::cleanup $token
    
	if {$code != 200} {
	    puts "Error : Unable to retrieve Fasta sequences for accession !\nerror code : $code"
	    return 0
	}
    }

    return $data
}



proc GetAlphafoldID {id} {
    package require TclCurl
    package require json
    
    set url "https://alphafold.ebi.ac.uk/api/prediction/$id"
    set rep ""
    set failed [::curl::transfer -url $url -followlocation 1 -bodyvar rep]
    if {$failed} {
	FaireLire "Unable to reach Alphafold database ! Retry later"
	return ""
    }
    set dout [::json::json2dict $rep]
    #puts "$rep"
    #puts "$dout"

    return $rep
}


proc GetAlphafoldFromUniprot {uniprot_id {output_format "pdb"}} {
    package require TclCurl
    package require json

    set uniprot_id [string toupper $uniprot_id]
    set uniprot_id [ConvertUniProt2UniProtAcc $uniprot_id]

    # Validate output format
    if {![string match -nocase "pdb" $output_format] && ![string match -nocase "cif" $output_format]} {
        puts "Unsupported format. Use 'pdb' or 'cif'."
        return {}
    }

    # Build the AlphaFold DB URL
    set file_ext [expr {$output_format eq "pdb" ? "pdb" : "cif"}]
    set url "https://alphafold.ebi.ac.uk/files/AF-${uniprot_id}-F1-model_v6.${file_ext}"
    # Download using curl
    set Text ""
    set failed [::curl::transfer -url $url -followlocation 1 -bodyvar Text]
    if {$failed} {
        puts "Download failed: $url"
	return {}
    }

    if {[string first "<Error>" $Text] >-1} {
	puts "Error ! Bad ID $uniprot_id !\n$Text"
	return {}
    }

    set Lignes [split $Text \n]

    return $Lignes
}


proc GetPDBLocal {pdbid} {
    # First check if file exists here
    if {[file exists $pdbid]} {
	set TextePDB [ContenuDuFichier $pdbid]
    } else {
	regsub -nocase {^PDB[:_]} $pdbid "" pdbid
    regsub -nocase {_[a-z]*} $pdbid "" pdbid
	
	# Check in the current gscope project
	set RepLocalPDB "[RepertoireDuGenome]/localpdb"
	set FichierLocalPDB "$RepLocalPDB/pdb[string tolower $pdbid].ent"
	if {[file exists $FichierLocalPDB]} {
	    set TextePDB [ContenuDuFichier $FichierLocalPDB]
	} else {
	    # Now check in local db
	    set pdbid [string tolower $pdbid]
	    set SousRep [string range $pdbid 1 2]
	    #lm Local PDB directories
	    set FichierPDB "/commun/banbi/pdb/compressed_files/$SousRep/pdb$pdbid.ent.gz"
	    if { [file exists $FichierPDB]} {
		Espionne $FichierPDB
		#lm a more generic method to uncompress file
		set o [open $FichierPDB]
		zlib push gunzip $o
		set TextePDB [read $o]
		close $o
	    }
	}
    }

    return $TextePDB
}


proc GetPDBLBGI {id} {
    # id : PDB id ex: 1il2
    package require TclCurl

    set url "http://lbgi.fr/api/pdb/getpdb/$id"
    set text ""
    catch {::curl::transfer -url $url -bodyvar text}

    if {[string range $text 0 5] ne "HEADER"} {
	set text ""
    }

    return $text
}


# Adapted from Claude
proc GetPDBWeb {pdb_id {format "cif"}} {
    # mainly called by TextePDB to retreive structure
    package require TclCurl

    # ------------------------------------------------------------------
    # Validate and normalize PDB ID
    # Old format : 4 characters  (e.g. 1ABC)
    # New format  : 8 characters (e.g. 1ABC5678)
    # ------------------------------------------------------------------
    set pdb_id [string toupper [string trim $pdb_id]]
    set id_len [string length $pdb_id]
    if {$id_len != 4 && $id_len != 8} {
        puts "Invalid PDB ID '$pdb_id': must be 4 (old) or 8 (new) characters."
	return ""
    }

    if {! [regexp {^[A-Z0-9]+$} $pdb_id]} {
        puts "Invalid PDB ID '$pdb_id': only alphanumeric characters are allowed."
	return ""
    }

    # ------------------------------------------------------------------
    # Validate format
    # ------------------------------------------------------------------
    set format [string tolower $format]
    if {$format ne "pdb" && $format ne "cif"} {
        puts "Invalid format '$format': must be 'pdb' or 'cif'."
	return ""
    }

    # New format PDB IDs are only available as mmCIF
    if {$id_len == 8 && $format eq "pdb"} {
        puts "Warning: new-format PDB IDs (8 chars) are not available in PDB\
              format. Switching to CIF."
        set format "cif"
    }

    # ------------------------------------------------------------------
    # Build download URL
    #
    # RCSB URL schemes:
    #   Old 4-char CIF : https://files.rcsb.org/download/1ABC.cif
    #   Old 4-char PDB : https://files.rcsb.org/download/1ABC.pdb
    #   New 8-char CIF : https://files.rcsb.org/download/1ABC5678.cif
    #
    # The RCSB also redirects from the legacy FTP-style URLs, so using
    # the /download/ endpoint with -followlocation handles both cases.
    # ------------------------------------------------------------------
    set pdb_id_lower [string tolower $pdb_id]

    if {$format eq "cif"} {
        set url "https://files.rcsb.org/download/${pdb_id_lower}.cif"
    } else {
        set url "https://files.rcsb.org/download/${pdb_id_lower}.pdb"
    }

    # ------------------------------------------------------------------
    # Download with TclCurl
    # ------------------------------------------------------------------

    # Create curl handle
    set curlHandle [curl::init]

    set http_code 0
    set curl_error 0
    set curlBody ""
    if {[catch {
        $curlHandle configure \
	    -bodyvar curlBody \
	    -url             $url          \
            -followlocation  1             \
            -maxredirs       10            \
            -failonerror     0             \
            -connecttimeout  30            \
            -timeout         120           \
            -useragent       "TclPDBFetcher/1.0" \
            -httpheader      [list "Accept: */*"]
	
        $curlHandle perform
        set http_code  [$curlHandle getinfo responsecode]
        set curl_error 0
    } err]} {
        # TclCurl threw an exception — network-level error
        set curl_error 1
        set curl_msg   $err
    }

    $curlHandle cleanup

    # ------------------------------------------------------------------
    # Error handling
    # ------------------------------------------------------------------
    # Network-level error (DNS, timeout, SSL, etc.)
    if {$curl_error} {
        puts "Network error while fetching '$pdb_id': $curl_msg"
	return ""
    }

    # HTTP-level error
    if {$http_code != 200} {
	set curlBody ""
	if {$http_code >= 500} {
	    puts "RCSB server error for '$pdb_id' (HTTP $http_code). Try again later."
	} else {
	    switch $http_code {
		404 {
		    puts "PDB ID '$pdb_id' not found on RCSB (HTTP 404).\
               C    	  heck the ID or try the other format."
		}
		403 {
		    puts "Access denied for '$pdb_id' (HTTP 403)."
		}
		default {
		    puts "Unexpected HTTP response $http_code for '$pdb_id'."
		}
	    }
	}

	return $curlBody
    }

    # Quick content check : verify the file looks like a structure file
    set Llines [split $curlBody \n]
    set first_line [lindex $Llines 0]
    if {$format eq "cif"} {
        if {![string match "data_*" $first_line]} {
            puts "Downloaded file for '$pdb_id' does not look like a valid\
                   mmCIF file (unexpected first line: \n'$first_line')."
        }
    } else {
        if {![regexp {^(HEADER|ATOM|REMARK|MODEL)} $first_line]} {
            puts "Downloaded file for '$pdb_id' does not look like a valid\
                   PDB file (unexpected first line: '$first_line')."
        }
    }

    #puts "Successfully downloaded !"

    return $curlBody
}


# from claude:
proc get_alphafold_pdb {uniprot_id} {
    package require http
    package require tls
    
# Enregistrer https://
    http::register https 443 [list ::tls::socket]

    # Step 1 : retreive correct URL from API
    set api_url "https://alphafold.ebi.ac.uk/api/prediction/${uniprot_id}"
    set headers [list User-Agent "Tcl-AlphaFold-Client/1.0"]

    set token [http::geturl $api_url -headers $headers]
    set status [http::status $token]
    set ncode  [http::ncode $token]

    if {$status ne "ok" || $ncode != 200} {
        set err "Error API ($ncode) for $uniprot_id"
        http::cleanup $token
        puts$err
	return ""
    }

    set body [http::data $token]
    http::cleanup $token

    # Extract pdbUrl from JSON (ex: "pdbUrl":"https://...pdb")
    if {! [regexp {"pdbUrl"\s*:\s*"([^\"]+)"} $body -> pdb_url]} {
	puts "pdbUrl not found in API answer"
	return ""
    }

    # Step 2 : download PDB file
    set token2 [http::geturl $pdb_url -headers $headers]
    set status2 [http::status $token2]
    set ncode2  [http::ncode $token2]

    if {$status2 ne "ok" || $ncode2 != 200} {
        set err "Error downloading PDB ($ncode2)"
        http::cleanup $token2
        puts $err
	return ""
    }

    set pdb_data [http::data $token2]
    http::cleanup $token2

        return $pdb_data
}


proc getAlphafoldPDBOnWeb {id} {
    package require TclCurl
    package require json

    set Lres {}

    set alphafold_ID "AF-P14618-F1"
    set database_version "v2"
    set model_url "https://alphafold.ebi.ac.uk/files/${alphafold_ID}-model_${database_version}.pdb"
    set error_url "https://alphafold.ebi.ac.uk/files/${alphafold_ID}-predicted_aligned_error_${database_version}.json"

    set failed [::curl::transfer -url ${model_url} -followlocation 1 -bodyvar json]
    if {$failed} {
	puts "Unable to reach Alphafold API"
	    return
    }
    set dout [::json::json2dict $json]
    foreach {db desc} $dout {
	    lappend Lres $db
	}

    #os.system(f'curl {model_url} -o {alphafold_id}.pdb')
    #os.system(f'curl {error_url} -o {alphafold_id}.json')    

    return $LPDB
}


proc GetOrtholog {{db ""} {species ""} {taxid ""}} {
    # OrthoInspector API
    # Taken from:
    # https://lbgi.fr/orthoinspectorv3/API
    #
    package require TclCurl
    package require json

    set Lres {}
    
    if {$db eq ""} {
	# get list of available databases
	set url "https://www.lbgi.fr/orthoinspector/api/database"
	set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]
	if {$failed} {
	    puts "Unable to reach OrthoInspector API"
	    return
	}
	set dout [::json::json2dict $json]
	foreach {db desc} $dout {
	    lappend Lres $db
	}
    } elseif {$species eq ""} {
	# Get list of species for given db
	# db is defined
	set url "https://www.lbgi.fr/orthoinspector/api/$db/species"
	set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]
	if {$failed} {
	    puts "Unable to reach OrthoInspector API"
	    return
	}
	set dout [::json::json2dict $json]
	foreach {k v} $dout {
	    lassign $v tmp1 name tmp2 taxid tmp3 phylum
	    lappend Lres $taxid
	}
    } elseif {$taxid eq ""} {
	# db id defined
	# specied is not empty
	if {[string is integer $species]} {
	    # species == taxid
	    #
	    # get list of proteins of texis proteome
	    set url "https://www.lbgi.fr/orthoinspector/api/$db/species/$species/proteins"
	    set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]
	    if {$failed} {
		puts "Unable to reach OrthoInspector API"
		return
	    }
	    set dout [::json::json2dict $json]
	    foreach {acc v} $dout {
		lassign $v tmp id tmp desc tmp seq
		lappend Lres $acc
	    }
	} else {
	    # species == access uniprot
	    # get list of orthologs of this species
	    set url "https://www.lbgi.fr/orthoinspector/api/$db/protein/$species/orthologs"
	    set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]
	    if {$failed} {
		puts "Unable to reach OrthoInspector API"
		return
	    }
	    set dout [::json::json2dict $json]
	    foreach d $dout {
		lassign $d tmp type tmp taxid tmp inpara tmp ortho
		lappend Lres $ortho
	    }
	}
    } elseif {$taxid ne ""} {
	# get ortholog in taxid organism
	set url "https://www.lbgi.fr/orthoinspector/api/$db/protein/$species/orthologs/$taxid"
	set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]
	if {$failed} {
	    puts "Unable to reach OrthoInspector API"
	    return
	}
	set dout [::json::json2dict $json]

	foreach d $dout {
	    lassign $d tmp type tmp taxid tmp inpara tmp ortho
	    lappend Lres $ortho
	}
    }
    
    return $Lres
}


proc jtd {Lacc bank BankSource BankTarget source target} {
    set cmd "select $source,$target from $bank where $source in ('[join $Lacc ',']')"
    set Lout [$::dbIdm eval $cmd]

    return $Lout
}


proc jtD {Lacc bank BankSource BankTarget source target} {
    AttachIDMappingBank ACC2ACC

    if {$bank eq $BankTarget} {
	# i.e. from ACC to REFSEQ
	set Lnew [ConvertAcc2DashAcc $Lacc tmp tmp]
	set cmd "select acc,id from $bank where acc in ('[join $Lnew ',']')"
	set Lout [$::dbIdm eval $cmd]
	# convert back to 'normal' acc
	set Lres {}
	foreach {in out} $Lout {
	    if {[set i [string last "-" $in]] > 0} {
		set in [string range $in 0 $i-1]
	    }
	    lappend Lres $in $out
	}
    } else {
	# i.e. from SEQRES to ACC
	set cmd "select id,acc from $bank where id in ('[join $Lacc ',']')"
	set Lout [$::dbIdm eval $cmd]
	set Lad {}
	foreach {id accD} $Lout {
	    lappend Lad $accD
	}
	set Lad [ConvertDashAcc2Acc $Lad]
	set Lres {}
	foreach {in out} $Lout acc $Lad {
	    lappend Lres $in $acc
	}
    }

    return $Lres
}


proc jTd {Lacc bank BankSource BankTarget source target taxid} {
    AttachIDMappingBank NCBI_TAXID

    set cmd "select db1.$source,db1.$target from $bank as db1, NCBI_TAXID as db2 where db1.$source in ('[join $Lacc ',']') and db2.id='$taxid' and db1.acc = db2.acc"
    set Lout [$::dbIdm eval $cmd]

    return $Lout
}


proc jTD {Lacc bank BankSource BankTarget source target taxid} {
    AttachIDMappingBank NCBI_TAXID
    AttachIDMappingBank ACC2ACC

    set Lres {}
    if {$bank eq $BankTarget} {
	# i.e. from ACC to REFSEQ
	set Lnew [ConvertAcc2DashAcc $Lacc]
	$::dbIdm eval {detach database ACC2ACC}
	set Lout [jtD $Lnew $bank $BankSource $BankTarget $source $target]
	set Ltax [$::dbIdm eval "select acc,id from NCBI_TAXID where acc in ('[join $Lacc ',']')"]

	array set tax {}
	foreach {ac id} $Ltax {
	    if {$id == $taxid} {
		set tax($ac) $id
	    }
	}
	foreach {in out} $Lout {
	    if {[set i [string last "-" $in]] > 0} {
		set in [string range $in 0 $i-1]
	    }
	    if {[info exis tax($in)]} {
		lappend Lres $in $out
	    }
	}
    } else {
	# i.e. from RESSEQ to ACC
	#
	# first, grab raw results from bank
	set cmd "select id,acc from $bank where id in ('[join $Lacc ',']')"
	set Lout [$::dbIdm eval $cmd]
	# 2, go from accc-dashed to ass
	set Ldash {}
	foreach {id acc} $Lout {
	    lappend Ldash $acc
	}
	set Lasd [ConvertDashAcc2Acc $Ldash]
	# 3, take only good taxid
	set Ltax [$::dbIdm eval "select acc,id from NCBI_TAXID where acc in ('[join $Lasd ',']')"]
	array set tax {}
	foreach {acc tx} $Ltax {
	    if {$tx == $taxid} {
		set tax($acc) $tx
	    }
	}
	foreach {in out} $Lout acc $Lasd {
	    if {[info exists tax($acc)]} {
		lappend Lres $in $acc
	    }
	}
    }

    return $Lres
}


proc Jtd {Lacc BankSource BankTarget source target} {
    AttachIDMappingBank $BankTarget

    set cmd "select db1.id, db2.id from $BankSource as db1, $BankTarget as db2 where db1.id in ('[join $Lacc ',']') and db1.acc = db2.acc"
    set Lout [$::dbIdm eval $cmd]

    return $Lout
}


proc JtD {Lacc BankSource BankTarget source target} {
    AttachIDMappingBank $BankTarget
    AttachIDMappingBank ACC2ACC

    set Lres {}
    set Lout [$::dbIdm eval "select id,acc from $BankSource where id in ('[join $Lacc ',']')"]
    if {$BankSource in [ListOfDBsWithDashAccess]} {
	# BankSource outputs dashed-acc
	set Lasd {}
	foreach {id accD} $Lout {
	    lappend Lasd $accD
	}
	# create list access sans dash (Lasd)
	set Lasd [ConvertDashAcc2Acc $Lasd]

	# create conversion array
	array set t {}
	foreach {id accDash} $Lout acc $Lasd {
	    lappend t($acc) $id
	}

	# request target db
	set Lout2 [$::dbIdm eval "select acc,id from $BankTarget where acc in ('[join $Lasd ',']')"]
	foreach {acc id} $Lout2 {
	    if {[info exists t($acc)]} {
		foreach v $t($acc) {
		    lappend Lres $v $id
		}
	    }
	}
    } else {
	# BankTarget takes Dashed-acc as input
	# i.e. from GENE_NAME to REFSEQ
	set Lasd {}
	foreach {id acc} $Lout {
	    lappend Lasd $acc
	}
	set Lasd [ConvertAcc2DashAcc $Lasd tmp tmp]
	foreach {id accD} $Lout acc $Lasd {
	    lappend t($acc) $id
	}
	set Lout2 [$::dbIdm eval "select acc,id from $BankTarget where acc in ('[join $Lasd ',']')"]
	foreach {acc id} $Lout2 {
	    if {[info exists t($acc)]} {
		foreach v $t($acc) {
		    lappend Lres $v $id
		}
	    }
	}
    }

    return $Lres
}


proc JTd {Lacc BankSource BankTarget source target taxid} {
    AttachIDMappingBank $BankTarget
    AttachIDMappingBank NCBI_TAXID

    set cmd "select db1.id, db2.id from $BankSource as db1, $BankTarget as db2, NCBI_TAXID as db3 where db1.id in ('[join $Lacc ',']') and db1.acc = db2.acc and db2.acc = db3.acc and db3.id = '$taxid'"

    set Lout [$::dbIdm eval $cmd]

    return $Lout
}


proc JTD {Lacc BankSource BankTarget source taxid} {
    AttachIDMappingBank $BankTarget
    AttachIDMappingBank NCBI_TAXID
    AttachIDMappingBank ACC2ACC

    set Lout [$::dbIdm eval "select id,acc from $BankSource where id in ('[join $Lacc ',']')"]
    set Lres {}
    if {$BankSource in [ListOfDBsWithDashAccess]} {
	# i.e. from REFSEQ to GENE_NAME
	#
	# REFSEQ outputs accDash, convert them
	set Lasd [lmap {id accD} $Lout {set accD}]
	set Lasd [ConvertDashAcc2Acc $Lasd]
	#
	# from these acc, take the ones with good taxid
	set cmd "WITH tmp(acc) AS (VALUES ('[join $Lasd '),(']')) SELECT tax.acc,tax.id FROM tmp AS dbin, NCBI_TAXID AS tax WHERE tax.acc = dbin.acc and tax.id = '$taxid'"
	set Ltax [$::dbIdm eval $cmd]
	set Lacc {}
	foreach {acc tx} $Ltax {
	    if {$tx == $taxid} {
		set tax($acc) $tx
		lappend Lacc $acc
	    }
	}
	# the Lasd and Lout lists have the same length
	foreach {id accD} $Lout acc $Lasd {
	    if {[info exists tax($acc)]} {
		lappend t($acc) $id
	    }
	}

	set cmd "WITH tmp(acc) AS (VALUES ('[join $Lacc '),(']')) SELECT dbt.acc,dbt.id FROM tmp AS dbin, $BankTarget AS dbt WHERE dbt.acc = dbin.acc"
	set Lout2 [$::dbIdm eval $cmd]
	# create results list
	parray t
	foreach {acc id} $Lout2 {
	    puts "acc $acc id $id"
	    if {[info exists t($acc)]} {
		lappend Lres [lindex $t($acc) 0] $id
	    }
	}
	puts "Lres $Lres"
    } else {
	# BankTaget takes DashAcc as input
	# i.e. from GENE_NAME to REFSEQ
	#
	set Lacc1 [lmap {id acc} $Lout {set acc}]

	# select acc with good taxid
	set cmd "WITH tmp(acc) AS (VALUES ('[join $Lacc1 '),(']')) SELECT tax.acc,tax.id FROM tmp AS dbin, NCBI_TAXID AS tax WHERE tax.acc = dbin.acc AND tax.id = '$taxid'"
	set Ltax [$::dbIdm eval $cmd]
	set LaccTax {}
	foreach {acc id} $Ltax {
	    set tax($acc) $id
	    lappend LaccTax $acc
	}
	foreach {id acc} $Lout {
	    if {[info exists tax($acc)]} {
		lappend t($acc) $id
	    }
	}

	# Convert acc to DashAcc
	set LaccD [ConvertAcc2DashAcc $LaccTax Ta2d Td2a]

	# Now query the target database with Dash-acc
	set cmd "WITH tmp(acc) AS (VALUES ('[join $LaccD '),(']')) SELECT dbt.acc,dbt.id FROM tmp AS dbin, $BankTarget AS dbt WHERE dbt.acc = dbin.acc"
	set Lout2 [$::dbIdm eval $cmd]

	# create results list with pairs :
	# id bk1 - id bk2
	foreach {accD id} $Lout2 {
	    if {[info exists Td2a($accD)]} {
		set acc $Td2a($accD)
	    } else {
		set acc $accD
	    }

	    foreach v $t($acc) {
		lappend Lres $v $id
	    }
	}
    }

    return $Lres
}


proc AttachIDMappingBank {bank} {
    set fdb [file join [idmHome] ${bank}.sqlite]
    $::dbIdm eval {attach database $fdb as $bank}

    return
}


proc OldIDMappingRequest {} {
    if {0} {
	set db [DbIDMappingSQL $bank open]
	if {! $jointure} {
	    if {$taxid eq ""} {
		if {! $checkDashAcc} {
		    set cmd "select $source,$target from $bank where $source in ('[join $Lacc ',']')"
		} else {
		    set fdb [file join [idmHome] ACC2ACC.sqlite]
		    $db eval {attach database $fdb as ACC2ACC}
		    set cmd "select db1.$source,db2.acc from $bank as db1, ACC2ACC as db2 where db1.$source in ('[join $Lacc ',']') and db1.acc = db2.id"
		}
	    } else {
		# taxid = 1
		set fdb [file join [idmHome] NCBI_TAXID.sqlite]
		$db eval {attach database $fdb as NCBI_TAXID}
		if {! $checkDashAcc} {
		    set cmd "select db1.$source,db1.$target from $bank as db1, NCBI_TAXID as db2 where db1.$source in ('[join $Lacc ',']') and db2.id='$taxid' and db1.acc = db2.acc"
		} else {
		    # checkDashAcc = 1

		    set fdb [file join [idmHome] ACC2ACC.sqlite]
		    $db eval {attach database $fdb as ACC2ACC}
		    set cmd "select db1.$source,db3.acc from $bank as db1, NCBI_TAXID as db2, ACC2ACC as db3 where db1.$source in ('[join $Lacc ',']') and db2.id='$taxid' and db1.acc = db2.acc and db1.acc = db3.acc"
		} ; # fin checkDashAcc
	    } ; # fin taxid
	} else {
	    # jointure = 1
	    set fdb [file join [idmHome] ${to}.sqlite]
	    $db eval {attach database $fdb as $to}

	    if {$taxid eq ""} {
		if {! $checkDashAcc} {
		    set cmd "select db1.id, db2.id from $from as db1, $to as db2 where db1.id in ('[join $Lacc ',']') and db1.acc = db2.acc"
		} else {
		    set fdb [file join [idmHome] ACC2ACC.sqlite]
		    $db eval {attach database $fdb as ACC2ACC}
		    set cmd "select db1.id,db3.id  from $from as db1, ACC2ACC as db2, $to as db3 where db1.id in ('[join $Lacc ',']') and db1.acc = db2.acc and db2.id = db3.acc"
		} ; # checkDashAcc
	    } else {
		# taxid = 1
		if {! $checkDashAcc} {
		    set fdb [file join [idmHome] NCBI_TAXID.sqlite]
		    $db eval {attach database $fdb as NCBI_TAXID}
		    set cmd "select db1.id, db2.id from $from as db1, $to as db2, NCBI_TAXID as db3 where db1.id in ('[join $Lacc ',']') and db3.id = '$taxid' and db1.acc = db2.acc and db1.acc = db3.acc"
		} else {
		    # checkDashAcc = 1
		} ; # fin checkDasshAcc
	    } ; # fin taxid
	}

	set Lout [$db eval $cmd]
	$db close
    }

    return
}


proc ConvertDashAcc2Acc {Lacc} {
    set rep [$::dbIdm eval "select id,acc from ACC2ACC where id in ('[join $Lacc ',']')"]
    foreach {id acc} $rep {
	lappend t($id) $acc
    }
    set Lres {}
    foreach acc $Lacc {
	if {[info exists t($acc)]} {
	    foreach v $t($acc) {
		lappend Lres $v
	    }
	} else {
	    lappend Lres $acc
	}
    }

    return $Lres
}


proc ConvertAcc2DashAcc {Lacc aTa2d aTd2a} {
    upvar $aTa2d Ta2d $aTd2a Td2a

    set cmd "WITH tmp(acc) AS (VALUES ('[join $Lacc '),(']')) SELECT a2a.acc,a2a.id FROM tmp AS dbin, ACC2ACC AS a2a WHERE a2a.acc = dbin.acc"
    set rep [$::dbIdm eval $cmd]
    foreach {acc id} $rep {
	lappend Ta2d($acc) $id
	lappend Td2a($id) $acc
    }
    # now re-create access list
    set Lnew {}
    foreach acc $Lacc {
	if {[info exists Ta2d($acc)]} {
	    lappend Lnew {*}$Ta2d($acc)
	} else {
	    lappend Lnew $acc
	}
    }

    return $Lnew
}


proc CreateIDMappingSQLRequest {Lacc bank BankSource BankTarget source target {taxid ""}} {
    global dbIdm

    set Join [expr {$BankSource ni {ACC ID ACC+ID} && $BankTarget ni {ACC ID}}]
    set Taxo [expr {$taxid != ""}]
    set Dash [expr {($BankSource in [ListOfDBsWithDashAccess] && $BankTarget ni [ListOfDBsWithDashAccess]) ^ ($BankSource ni [ListOfDBsWithDashAccess] && $BankTarget in [ListOfDBsWithDashAccess])}]

    set dbIdm [DbIDMappingSQL $bank open]

    if { ! $Join && ! $Taxo && ! $Dash } {
	set Lout [jtd $Lacc $bank $bank $BankTarget $source $target]
    }
    if { ! $Join && ! $Taxo &&  $Dash } {
	set Lout [jtD $Lacc $bank $BankSource $BankTarget $source $target]
    }
    if { ! $Join &&  $Taxo && ! $Dash } {
	set Lout [jTd $Lacc $bank $BankSource $BankTarget $source $target $taxid]
    }
    if { ! $Join &&  $Taxo &&  $Dash } {
	set Lout [jTD $Lacc $bank $BankSource $BankTarget $source $target $taxid]
    }
    if {  $Join && ! $Taxo && ! $Dash } {
	set Lout [Jtd $Lacc $BankSource $BankTarget $source $target]
    }
    if {  $Join && ! $Taxo &&  $Dash } {
	set Lout [JtD $Lacc $BankSource $BankTarget $source $target]
    }
    if {  $Join &&  $Taxo && ! $Dash } {
	set Lout [JTd $Lacc $BankSource $BankTarget $source $target $taxid]
    }
    if {  $Join &&  $Taxo &&  $Dash } {
	set Lout [JTD $Lacc $BankSource $BankTarget $source $taxid]
    }

    $dbIdm close
    
    return $Lout
}


proc InitWebServices {} {
    package require WS::Client

    # NCBI service
    # eUtils services
    set ret [::WS::Client::GetAndParseWsdl "http://www.ncbi.nlm.nih.gov/entrez/eutils/soap/v2.0/eutils.wsdl"]
    ::WS::Client::CreateStubs eUtilsService

    # NCBI service
    # eFetch services
    # Only works with refseq or GI accession
    set ret [::WS::Client::GetAndParseWsdl "http://www.ncbi.nlm.nih.gov/entrez/eutils/soap/v2.0/efetch_seq.wsdl"]
    ::WS::Client::CreateStubs eFetchSequenceService

    return
}


proc DASServers {} {

    if {0} {
	http://www@~.ebi.ac.uk/das-srv/registry/das/sources (a mirror of http://www.dasregistry.org/das/sources)
	http://www.ebi.ac.uk/das-srv/registry/das/coordinatesystem (a mirror of http://www.dasregistry.org/das/coordinatesystem)
    }

    return
}


proc UniProtProteome {{pref 0}} {
    # Taxonomy identifier of top node for query, e.g. 2 for Bacteria, 2157 for Archea, etc.
    # (se http://www.uniprot.org/taxonomy)
    set top_node 131567

    # Toggle this to 1 if you want reference instead of complete proteomes.
    set reference $pref
    set proteome [expr {$reference ? "reference:yes" : "complete:yes"}]
    set keyword [expr {$reference ? "keyword:1185" : "keyword:181"}]

    # Get a list of all taxons below the top node with a complete/reference proteome.
    set url "http://www.uniprot.org/taxonomy/?query=ancestor:$top_node+$proteome&format=list"
    set response_list [split [HttpCopy $url] \n]
    set Lout {}
    foreach id $response_list {
	if {[string trim $id] ne ""} {
	    lappend Lout $id
	}
    }

    return $Lout
}


proc FetchUniprotPost {Lid} {
    set url "http://www.uniprot.org/batch/"
    set file tmp
    set type "text/plain"

    set res [form-data::post $url "file" $type $Lid [list file $file format txt]]

    set Lembl [SplitLesEMBL $res]

    return $Lembl
}


proc ServiceEBI {Lbkid} {

    foreach e $Lbkid {
	lassign $e bk Lid
	# do bunch of 200 seqs
	set nId [llength $Lid]
	set nB [expr {$nId/200+1}]
	for {set i 0} {$i < $nB} {incr i} {
	    set fin [expr {($i+1)*200 - 1}]
	    if {$fin > $nId} {set fin end}
	    set Lr [lrange $Lid $i $fin]

	    set url "http://www.uniprot.org/uniprot/[join $Lr ,].txt"
	    #set url "http://www.uniprot.org/uniprot/?query=database:(type:refseq [join $Lr ,])&format=txt"
	    puts "$url"
	    #set url "http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz?-noSession+-ascii+-e+\[refseqp-id:[join $Lid ,]\]"
	    #puts "$url"
	    #exit
	    #set url "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch?db=$bk&id=[join $Lr ,]&style=raw"
	    set rep [::http::data [::http::geturl $url]]
	    set Lfi [SplitLesEMBL $rep]
	}
    }

    return
}


proc SplitLesEMBL {rep} {
    # list or not ?
    if {[string first "\n" $rep] != -1} {
	set rep [split $rep \n]
    }

    set Li [lsearch -all -regexp $rep {^//(\n|$)} ]
    set Lfile {}
    set a 0
    foreach b $Li {
	set Ll [lrange $rep $a $b]
	lappend Lfile $Ll
	set a [expr {$b + 1}]
    }

    return $Lfile
}


proc LineageFromGI {LId} {
    array set T [eSummaryREST protein $LId]
    set Ltxid {}
    foreach id $LId {
	lappend Ltxid [set T($id,TaxId)]
    }

    set Llin {}
    array set Tx [eFetchREST taxonomy $Ltxid]
    foreach t $Ltxid {
	if {[info exists Tx($t,Lineage)]} {
	    lappend Llin $Tx($t,Lineage)
	} else {
	    lappend Llin ""
	}
    }

    return $Llin
}


proc FetchService {} {
    global LNOrdali ListePDB

    if {0} {
	EB-eye : http://www.ebi.ac.uk/ebisearch/service.ebi?wsdl

	biomart  http://webservices.genouest.org/typedservices/BioMart.wsdl
    }

    set Lrefseq {} ; set Luniprot {}
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}

	if {[string trim $n] in $ListePDB} {continue}
	if {[EstUnRefseq $n]} {
	    lappend Lrefseq $n
	} else {
	    lappend Luniprot $n
	}
    }
    if {$Lrefseq != {}} {
    }

    return
}


proc InfosFromRefSeq {Lid} {
    #
    # fetch all infos from NCBI for IDs list
    # Returns:
    # - an 'array get' of a table containing all infos
    # - an empty list if nothing found
    # - 0 if an error occurred

    if {$Lid == {} } {
	return {}
    }

    set Lxml [eFetchREST protein $Lid tiny]
    if {$Lxml eq ""} {
	# nothin found
	return {}
    } elseif {$Lxml == 0} {
	# A problem occurred
	return 0
    }
    array set T {}
    set Ltid {}
    set Lacc {}
    foreach xml $Lxml {
	set RId [dom parse $xml]
	set doc [$RId documentElement]
	foreach ns [$doc selectNodes //TSeq] {
	    set tid [$ns selectNode string(./TSeq_taxid)]
	    set acc [$ns selectNode string(./TSeq_accver)]
	    set acc [EnleveVersionDeAccess $acc]
	    set gi  [$ns selectNode string(./TSeq_gi)]
	    set org [$ns selectNode string(./TSeq_orgname)]
	    set def [$ns selectNode string(./TSeq_defline)]
	    set seq [$ns selectNode string(./TSeq_sequence)]
	    
	    set T($acc,TaxId)    $tid
	    set T($acc,Desc)     $def
	    set T($acc,Organism) $org
	    set T($acc,currAC)   $acc
	    set T($acc,BId)      $gi
	    set T($acc,Sequence) $seq
	    set T($acc,Lineage)  ""
	    set T($acc,Phylum)   ""
	    
	    lappend Ltid $tid
	    lappend Lacc $acc
	}
	$RId delete
	update
    }
    
    if {$Ltid != {} } {
	set o [eFetchREST taxonomy $Ltid]
	array set Tx $o
	foreach t $Ltid acc $Lacc {
	    if {[info exists Tx($t,Lineage)]} {
		set T($acc,Lineage) $Tx($t,Lineage)
		set Llin [split $Tx($t,Lineage) ";"]
		if {[set ph [string trim [lindex $Llin 0]]] ne "cellular organisms"} {
		    set T($acc,Phylum) $ph
		} else {
		    set T($acc,Phylum) [string trim [lindex $Llin 1]]
		}
	    }
	}
    }
    
    return [array get T]
}


proc eFetchPeel {l} {
    global eFiLevel eFLval

    set eFiLevel 0
    set eFLval {}

    DoeFetchPeeling $l
    if {$eFLval != {} } {
	puts " : [join $Lval]"
    }

    unset eFLval eFiLevel

    return
}


proc DoeFetchPeeling {l} {
    global eFiLevel eFLval

    if {$l eq ""} {return}

    set KeysWithChilds [list "GBSet" "GBSeq" "GBSeq_references" "GBReference" "GBReference_authors" "GBSeq_other-seqids" "GBSeq_feature-table" "GBFeature" "GBFeature_intervals" "GBInterval" "GBFeature_quals" "GBQualifier"]
    set KeysWithArrays [list GBSeq GBSeqid GBReference GBAuthor GBXref GBFeature GBInterval GBQualifier]

    set gap [string repeat " " $iLevel]
    set ik 0
    while {$ik < [llength $l]} {
	set k [lindex $l $ik]
	if {$k in $KeysWithChilds} {
	    set bn ""
	    if {$Lval != {} } {
		puts " : [join $Lval]"
		set Lval {}
		set bn "\n"
	    }
	    puts "${gap}k = $k"

	    incr ik
	    incr iLevel 2
	    set Lv [lindex $l $ik]
	    if {$k in $KeysWithArrays} {
		foreach v $Lv {
		    Peel $v
		}
	    } else {
		Peel $Lv
	    }
	    incr ik
	    incr iLevel -2

	    continue
	}

	if {! [regexp {^GB} $k]} {
	    lappend Lval $k
	} else {
	    if {$Lval != {} } {
		puts " : [join $Lval]"
		set Lval {}
	    }
	    puts -nonewline "${gap}k = $k"
	}
	incr ik
    }

    return
}


proc Convert2UniProtAcc {LId} {
    set LId [CheckIdsAsList $LId]
    # takes any ID list and tries to find their
    # UniProt equivalents if any.
    # Output is in the same order as input.
    # For IDs with no UniProt matching, return ID
    set Lrep [ConvertRefSeq2UniProtAcc $LId]
    set Lrep [ConvertGenBankEMBL2UniProtAcc $Lrep]
    set Lrep [ConvertGI2UniProtAcc $Lrep]
    set Lrep [ConvertUniProt2UniProtAcc $Lrep]

    return $Lrep
}


proc ConvertUniProt2UniProtAcc {LId} {
    set LId [CheckIdsAsList $LId]

    # returns the ID list in the same order
    # replacing all possible id by their
    # UniProt Accession when possible.
    # Otherwise, keep id

    set ToAcc [IDMapping "ACC+ID" ACC $LId]
    set ToAcc [split $ToAcc \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertUniProt2UniProtID {LId} {
    set LId [CheckIdsAsList $LId]
    # returns the ID list in the same order
    # replacing all possible id by their
    # UniProt ID when possible.
    # Otherwise, keep id

    set ToID [split [IDMapping "ACC+ID" ID $LId] \n]
    if {$ToID eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId new $ToID {
	if {$new eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $new
	}
    }

    return $Lrep
}


proc ConvertRefSeq2UniProtAcc {LId} {
    set LId [CheckIdsAsList $LId]
    # returns the ID list in the same order
    # replacing all possible IDs by their
    # UniProt Accession when possible.
    # Otherwise, keep the original ID

    set ToAcc [split [IDMapping REFSEQ ACC $LId] \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertGenBankEMBL2UniProtAcc {LId} {
    set LId [CheckIdsAsList $LId]
    # returns the ID list in the same order
    # replacing all possible IDs by their
    # UniProt Accession when possible.
    # Otherwise, keep the original ID

    set ToAcc [split [IDMapping EMBL ACC $LId] \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertGenBank2UniProtAcc {LId} {
    # returns the ID list in the same order
    # replacing all possible IDs by their
    # UniProt Accession when possible.
    # Otherwise, keep the original ID

    set ToAcc [split [IDMapping EMBL ACC $LId] \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertGI2UniProtAcc {LId} {
    set LId [CheckIdsAsList $LId]
    # returns the ID list in the same order
    # replacing all possible IDs by their
    # UniProt Accession when possible.
    # Otherwise, keep the original ID

    set ToAcc [split [IDMapping GI ACC $LId] \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertUniProt2RefSeq {LId} {
    # returns the ID list in the same order
    # replacing all possible IDs by their
    # RefSeq Accession when possible.
    # Otherwise, keep the original ID

    set ToAcc [split [IDMapping "ACC+ID" REFSEQ $LId] \n]
    if {$ToAcc eq ""} {
	return $LId
    }

    set Lrep {}
    foreach id $LId acc $ToAcc {
	if {$acc eq ""} {
	    lappend Lrep $id
	} else {
	    lappend Lrep $acc
	}
    }

    return $Lrep
}


proc ConvertGI2RefSeq {LId} {
    # taken from :
    # https://ncbiinsights.ncbi.nlm.nih.gov/2016/12/06/converting-gi-numbers-to-accession-version/
    #
    # uses a single query to efetch

    package require TclCurl

    set db "protein"
    set Paquets 200
    
    if {[string first "," $Lids] != -1} {
	set Lids [split $Lids ,]
    }

    set Lacc {}
    set nid [llength $Lids]
    set d 0
    set f $Paquet
    while {($f-1) <= $nid} {
	set Ltmp [join [lrange $Lids $d $f-1] ,]
	set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=$db&id=$Ltmp&rettype=acc"
	set ok [::curl::transfer -url $url -followlocation 1 -bodyvar res]
	set Lres [split $res \n]
	lappend Lacc {*}$Lres
	incr d $Paquet
	incr f $Paquet
	if {$f >= $nid} {
	    set f $nid
	}
    }

    return $Lacc
}


    proc ConvertGI2RefSeq_OLD {LId} {
    # NCBI GI <-> NCBI Refseq
    # use eSummary and eLink when unsuccessfull
    #
    # returns a list of the refseq equivalents.
    # if a GI has no refseq equivalent, a empty
    # string is then set

    set Lref {}
    set aT [eSummaryREST protein $LId]
    array set T $aT

    foreach n $LId {
	if {! [info exists T($n,refseq)]} {
	    set acc ""
	} else {
	    set acc [EnleveVersionDeAccess [set T($n,refseq)]]
	}

	if {[info exists T($n,ReplacedBy)] && [set T($n,ReplacedBy)] ne ""} {
	    set acc [EnleveVersionDeAccess $T($n,ReplacedBy)]
	}

	if {$acc eq ""} {
	    lappend Lref $n
	} else {
	    lappend Lref $acc
	}
    }

    return $Lref
}


proc ConvertGI2GenBank {LId} {
    # NCBI GI <-> NCBI Refseq
    # use eSummary and eLink when unsuccessfull
    #
    # returns a list of the refseq equivalents.
    # if a GI has no refseq equivalent, a empty
    # string is then set

    set Lref {}
    set aT [eSummaryREST protein $LId]
    array set T $aT
    foreach n $LId {
	if {! [info exists T($n,genbank)]} {
	    set acc ""
	} else {
	    set acc [set T($n,genbank)]
	}

	if {[info exists T($n,ReplacedBy)] && [set T($n,ReplacedBy)] ne ""} {
	    puts "  ==> $n -> [set T($n,ReplacedBy)]"
	}

	# if does not exists , try using eLink
	if {0 && $acc eq ""} {
	    set Lel [eLinkREST protein protein $n]
	    if {$Lel ne ""} {
		unset -nocomplain Ttmp
		set at [eSummaryREST protein $Lel]
		array set Ttmp $at
		foreach ne $Lel {
		    if {[info exists Ttmp($ne,refseq)]} {
			set acc [set Ttmp($ne,refseq)]
		    }
		    if {$acc ne ""} {
			set n $ne
			break
		    }
		}
	    }
	}

	if {$acc eq ""} {
	    lappend Lref $n
	} else {
	    lappend Lref $acc
	}
    }

    return $Lref
}


proc Convert2RefSeq {Lid} {
    set Lrep [ConvertGI2RefSeq $Lid]
    set Lrep [ConvertUniProt2RefSeq $Lrep]

    # try to match unknowns ... usually strange
    # NCBI numbers from genomes
    set Lunk {}
    foreach n $Lid r $Lrep {
	if {[EstUnRefseq $r] || [EstUnAccessPDB $r]} {
	    continue
	}
	lappend Lunk $n
    }
    # all found ! nice ...
    if {$Lunk == {} } {
	return $Lrep
    }

    # try to find an existing refseq access
    set Lgi [eSearchREST protein $Lunk]
    if {$Lgi == {} } {
	#  nothing found , return
	return $Lrep
    }
    array set T [eSummaryREST protein $Lgi]
    foreach n $Lunk gi $Lgi {
	if {[info exists T($gi,refseq)] && [set T($gi,refseq)] ne ""} {
	    set i [lsearch $Lid $n]
	    lset Lrep $i [set T($gi,refseq)]
	}
    }
    update

    return $Lrep
}


proc MnemonicUniprot {Lid} {
    # %3A <-> :
    #

    set url "http://www.uniprot.org/uniprot/?query=%28mnemonic%3ASYFB_SILPO+or+mnemonic%3AEFTU_ECOLI+or+mnemonic%3ATKNB_HUMAN+or+mnemonic%3ASYDC_HUMAN%29+and+%0D%0Aactive%3Ayes&sort=score&format=list"
    set url "http://www.uniprot.org/uniprot/?query=%28mnemonic%3ASYFB_SILPO+or+mnemonic%3AEFTU_ECOLI+or+mnemonic%3ATKNB_HUMAN+or+mnemonic%3ASYDC_HUMAN%29+and+%0D%0Aactive%3Ayes&format=list"
    set url "http://www.uniprot.org/uniprot/?query=mnemonic%3ASYFB_SILPO+or+mnemonic%3AEFTU_ECOLI+or+mnemonic%3ATKNB_HUMAN+or+mnemonic%3ASYDC_HUMAN&format=tab"

    set Lid [list SYD_ECOLI SYFB_SILPO EFTU_ECOLI TKNB_HUMAN SYDC_HUMAN]
    set Lma [IDMapping "ACC+ID" ACC $Lid]
    set Lmi [IDMapping "ACC+ID" ID $Lid]
    puts "orig $Lid"
    puts "macc $Lma"
    puts "mid  $Lmi"
    puts ""

    set Lor [lsort $Lid]
    set Lor $Lid

    set Lq {}
    foreach e $Lor {
	lappend Lq "mnemonic%3A$e"
    }
    set q [join $Lq "+or+"]
    set url "http://www.uniprot.org/uniprot/?query=${q}&format=tab&columns=id,entry%20name"

    set Lres [split [HttpCopy $url] \n]
    foreach r [lrange $Lres 1 end] e $Lor {
	lassign [split $r \t] ac id tmp
	puts "$e | $ac $id"
    }

    exit
    return
}


proc CheckIdsAsList {LId} {
    if {[regexp {[ ,\n]} $LId]} {
	set LId [join $LId " "]
	regsub -all {[ ,\n]+} $LId " " LId
	regsub -all { +} [string trim $LId] " " LId
			  set LId [split $LId]
    }

    return $LId
}

proc idmHome {} {
    if {[info exists ::env(IDMAPPING_HOME)]} {
	set idmHome $::env(IDMAPPING_HOME)
    } else {
	set idmHome [IDMappingDir]
    }

    return $idmHome
}


proc BICSDir {} {
    FaireLire "BICS est obsolete use Banbi"
    return [BanbiDir]
}


proc IDMappingDir {} {
    return "[BanbiDir]/IDMapping/current"
}


proc ListOfDBsWithDashAccess {} {
    #rR Attention depuis 2021/11/22 on place le fichier au dessus de production
    #rR en fait il faudrait pouvoir sourcer /commun/banbi/src/banbi_idmapping.tcl
    #rR A FAIRE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if { ! [info exists ::ListOfDBsWithDashAccess]} {
	#set ::ListOfDBsWithDashAccess [lsort [LesLignesDuFichier "[IDMappingDir]/../BanksWithDashAccess.dat"]]
	set ::ListOfDBsWithDashAccess [lsort [LesLignesDuFichier "[IDMappingDir]/BanksWithDashAccess.list"]]
    }

    return $::ListOfDBsWithDashAccess
}

proc ListOfAllIDMappingBanks {{dir current}} {
    #rR 20210622 j'ai rajoutÃ© l'argument optionnel dir
    #rR pour m'en servir dans Banbi
    #rR j'ai aussi rajoutÃ© la clÃ© $dir dans la variable globale ListAllIDMappingBanks
    if {[info exists ::ListAllIDMappingBanks($dir)]} {
	return $::ListAllIDMappingBanks($dir)            ; #rR dir
    }
    
    #AK: l'API web utilise cette fonction; completement débile, recursion infinie garantie ! 
    #if {! [file exists [IDMappingDir]]} {
#	package require TclCurl
#	set url "http://www.lbgi.fr/api/idmapping/dblist"
#	if {[catch {::curl::transfer -url $url -followlocation 1 -bodyvar tmp}]} {
#	    # cf ordali_data.tcl
#	    set Ltmp [ListOfAllIDMappingBanks_hard]
#	} else {
#	    package require json
##	    set ddb [::json::json2dict $tmp]
#	    set Ltmp [dict get $ddb data]
#	}
#    } else {
	# IDMapppingDir exitsts
	#rR set Lsql [lsort [glob [file join [IDMappingDir] SQLDBS *.sql]]]
	#set Lsql [lsort [glob [file join [IDMappingDir] .. $dir SQLDBS *.sql]]]  ; #rR a mis .. $dir
	set Lsql [lsort [glob [file join [IDMappingDir] .. $dir *.sqlite]]]  ; #AK
	set Ltmp [lmap x $Lsql {file rootname [file tail $x]}]
#    }

    # Cleaning and add required banks
    foreach db {"UniProtKB_ACC/ID" "UniProtKB_ACC" "UniProtKB_ID"} {
	set Ltmp [linsert $Ltmp 0 $db]
    }
    # remove ACC2ACC bank which is internal one, and UNIRPOTKB_ID which is redundant
    foreach db {"ACC2ACC" "UNIPROTKB_ID"} {
	set i [lsearch $Ltmp "$db"]
	if {$i > -1} {
	    set Ltmp [lreplace $Ltmp $i $i]
	}
    }    

    set ::ListAllIDMappingBanks($dir) $Ltmp       ; #rR dir
    
    return $::ListAllIDMappingBanks($dir)         ; #rR dir
}

proc ListOfAllIDMappingBanks_AvantModificationPar_rR {} {
    if {[info exists ::ListAllIDMappingBanks]} {
	return $::ListAllIDMappingBanks
    }
    
    if {! [file exists [IDMappingDir]]} {
	package require TclCurl
	set url "http://www.lbgi.fr/api/idmapping/dblist"
	if {[catch {::curl::transfer -url $url -followlocation 1 -bodyvar tmp}]} {
	    # cf ordali_data.tcl
	    set Ltmp [ListOfAllIDMappingBanks_hard]
	} else {
	    package require json
	    set ddb [::json::json2dict $tmp]
	    set Ltmp [dict get $ddb data]
	}
    } else {
	set Lsql [lsort [glob [file join [IDMappingDir] SQLDBS *.sql]]]
	set Ltmp [lmap x $Lsql {file rootname [file tail $x]}]
    }
    
    set ::ListAllIDMappingBanks $Ltmp
    
    return $::ListAllIDMappingBanks
}


proc CheckIDMappingInputParam {args} {
    if {$args eq "list"} {
	puts "\nList of available banks:"
	puts [join [ListOfAllIDMappingBanks] \n]
	puts ""

	return ""
	  }

	if {[llength $args] < 3} {
	IDMapping_help
	return 0
    }

    # parse arguments
    lassign $args from to Lids taxid
    # convert UniPortKB_ACC/ID to ACC+ID, UniProtKB_*ACCC to ACC and UniProtKB_ID to ID
    foreach v {from to} {
	set $v [string toupper [set $v]]
	switch [set $v] {
	    "UNIPROTKB_ACC/ID" {set $v "ACC+ID"}
	    "UNIPROTKB_ACC" {set $v "ACC"}
	    "UNIPROTKB_ID" {set $v "ID"}
	}
    }

    # if exists, taxid should be integer
    if {$taxid ne "" && ! [string is integer $taxid]} {
	puts "\nError !\n\ttaxID should be an integer !\n"
	return 0
    }

    set LidmDBs [ListOfAllIDMappingBanks]
    foreach db {"UniProtKB_ACC/ID" "UniProtKB_ACC" "UniProtKB_ID"} rep {"ACC+ID" "ACC" "ID"} {
	set i [lsearch $LidmDBs $db]
	lset LidmDBs $i $rep
    }

    if {$from ni $LidmDBs || $to ni $LidmDBs} {
	puts "\nError :\nBad <FROM_db> and/or <TO_db> names !\nfrom=$from to=$to\n"
	IDMapping_help
	return 0
    }
    if {$to eq "ACC+ID"} {
	puts "$to is a bad value for <TO> Can be ACC, ID or any other available bank !\n"
	IDMapping_help
	return 0
    }

    # check list of IDs
    if {[file exists $Lids]} {
	set Ltmp [LesLignesDuFichier $Lids]
	
	set Lids {}
	foreach l $Ltmp {
	    if {[string trim $l] eq ""} {
		continue
	    }
	    set l [string toupper $l]
	    if {[regexp {\,| |\;|\|} $l]} {
		set l [split $l " ,;|"]
	    }
	    lappend Lids {*}$l
	}
    } else {
	# ids are not in a file
	set Lids [string toupper $Lids]
	set Lids [CheckIdsAsList $Lids]
    }

    return [list $from $to $Lids $taxid]
}


proc DbIDMappingSQL {bank what} {
    set db $bank
    switch $what {
	"open" {
	    set fdb [file join [idmHome] $bank.sqlite]
	    #Espionne $fdb
	    sqlite3 $db $fdb -readonly 1
	    # an old sqlite (3.25 of the starpack) fails to lock the files on
	    # NFS ("disk I/O error"). The banks are only read : open them
	    # without locks
	    if {[catch {$db eval {select 1 from sqlite_master limit 1}}]} {
		catch {$db close}
		sqlite3 $db $fdb -readonly 1 -vfs unix-none
	    }
	    #$db eval "PRAGMA journal_mode = OFF"
	    $db eval "PRAGMA synchronous = OFF"
	}
	"close" {
	    $db close
	}
    }
    
    return $db
}


proc IDMapping {args} {
    #rR J'ai modifié pour pouvoir l'appeler pour tout en mettant args
    #rR ATTENTION on rend join du résulat par \n ... sauf pour le Help et autres exceptions
    
    if {$args=={}} {
	return [IDMapping_help]
    }

    set First [lindex $args 0]
    if {[string equal -nocase $First "Help"]       } {
	return [IDMapping_help]
    }
    if {[string equal -nocase $First "Hits"]} {
	return [IDMapping_hits {*}[lrange $args 1 end]]
    }
    if {[string equal -nocase $First "ListOfBanks"] || [string equal -nocase $First "List"]} {
	return [ListOfAllIDMappingBanks]
    }

    lassign $args from to LId orga OnWeb
    
    if {$OnWeb==""} {
	set OnWeb "no"
    }
    if {[catch {file exists [IDMappingDir]} local]} {
	set local 0
    }
    if {$OnWeb ne "no" || ! $local} {
	set Retour [IDMapping_web $from $to $LId $orga]
	return [join $Retour "\n"]
    }
    # local banks (banbi) unreadable : UniProt web service
    if {[catch {IDMapping_sql $from $to $LId $orga} Retour]} {
	puts "IDMapping : local banks unreadable ($Retour), using the UniProt web service"
	set Retour [IDMapping_web $from $to $LId $orga]
    }
    return [join $Retour "\n"]
}


proc IDMapping_help {{args ""}} {
    set LeHelp {}
    if {$args eq "" || [regexp -nocase "^Help" $args]} {
	lappend LeHelp "\nUsage : \n\tidmapping <from> <to>   <ids list> ?<taxid>?"
	lappend LeHelp "\tidmapping ACC+ID REFSEQ P12345,TRFE_RAT"
	lappend LeHelp ""
	lappend LeHelp "   <from> should be one of ACC, ACC+ID, ID or any of the available databases."
	lappend LeHelp "   <to>   should be one of ACC,         ID or any of the available databases."
	lappend LeHelp ""
	lappend LeHelp "  List of available databases :"
	lappend LeHelp [join [ListOfAllIDMappingBanks] \n]
	lappend LeHelp ""
    } elseif {$args in {"ListOfBanks" "list"}} {
	lappend LeHelp "\nList of available IDMapping Banks :"
	lappend LeHelp [join [ListOfAllIDMappingBanks] " "]
	lappend LeHelp ""
    }

    return [join $LeHelp "\n"]
}

proc IDMapping_sql {from to Lids {taxid ""}} {
    lassign [CheckIDMappingInputParam $from $to $Lids $taxid] from to Lids taxid
    if {$from == 0} {
	# 0 means a problem occured
	return ""
    }
    if {$from eq ""} {
	# empty returned means OK, return normally
	return ""
    }

    if {$from ni {ACC ID ACC+ID} && $to ni {ACC ID}} {
	set jointure 1
	set uniprotbank 0
    } elseif {$from in {ACC ID ACC+ID} && $to in {ACC ID}} {
	set jointure 0
	set uniprotbank 1
    } else {
	set jointure 0
	set uniprotbank 0
    }

    set Lacc {}
    switch $from {
	"ACC" {
	    set source acc
	    set bank $to
	    set target id
	    set Lacc $Lids
	}
	"ID" -
	"ACC+ID" {
	    set source acc
	    set bank $to
	    set target id

	    # get everything as an ACC
	    set dbTmp [DbIDMappingSQL UNIPROTKB_ID open]
	    set Laccid [$dbTmp eval "select acc,id from UNIPROTKB_ID where id in ('[join $Lids ',']') OR acc in ('[join $Lids ',']')"]
	    $dbTmp close
	    foreach {a i} $Laccid {
		set t($a) $a
		set t($i) $a
	    }
	    # IDs not in database
	    set Lout [lor $Laccid $Lids from2]
	    foreach elt $Lout {
		set t($elt) $elt
	    }

	    set Lacc {}
	    foreach a $Lids {
		lappend Lacc $t($a)
	    }
	    unset -nocomplain t
	}
	default {
	    set source id
	    set bank $from
	    set target acc
	    set Lacc $Lids
	}
    }

    if {$to eq "ACC"} {
	set target acc
    }
    if {$uniprotbank} {
	set bank UNIPROTKB_ID
    }

    #
    # on tient compte des access avec '-' que si :
    #    banque Dassh  vess PAS dash
    #  id <-> accDash ::: acc <-> id
    #
    # dans autres cas, accDash pas grave
    if {$from in [ListOfDBsWithDashAccess] && $to ni [ListOfDBsWithDashAccess]} {
	set checkDashAcc 1
    } else {
	set checkDashAcc 0
    }

    # create SQL request
    set Lout [CreateIDMappingSQLRequest $Lacc $bank $from $to $source $target $taxid]
    #puts "$bank $from $to $source $target $taxid"
    foreach {in out} $Lout {
	#puts "in >$in< out >$out<"
	lappend t($in) $out
    }

    set Lres {}
    foreach a $Lacc {
	if {[info exists t($a)]} {
	    lappend Lres [lunique $t($a)]
	} else {
	    lappend Lres ""
	}
    }

    return $Lres
}

proc IDMapping_hits {ListOfIds} {
    regsub -all {[ \t,\n]+} $ListOfIds "," ListOfIds
    set ListOfIds [split [string trim $ListOfIds ","] ","]
    set LesHits {}
    set Format "from %-15s %-15s to %-15s %s"
    foreach Id $ListOfIds {
	foreach Bank [ListOfAllIDMappingBanks] {
	    set Hit [IDMapping ACC+ID $Bank $Id]
	    if {[llength $Hit]!=0 && [lindex $Hit 0]!=""} { lappend LesHits [format $Format ACC+ID $Id $Bank $Hit] }
	}
    }
    foreach Id $ListOfIds {
	foreach Bank [ListOfAllIDMappingBanks] {
	    set Hit [IDMapping $Bank ACC $Id]
	    if {[llength $Hit]!=0 && [lindex $Hit 0]!=""} { lappend LesHits [format $Format $Bank $Id "ACC" $Hit] }
	}
    }
    return [join $LesHits "\n"]
}

proc IDMappingWebBanques {} {
    # names of the databases of the UniProt ID mapping service
    if {[info exists ::IDMappingWebBanques]} {
	return $::IDMappingWebBanques
    }
    lassign [IDMappingWebGet "https://rest.uniprot.org/configure/idmapping/fields"] code data
    if {$code != 200} {
	return {}
    }
    set ::IDMappingWebBanques [regexp -all -inline {"name"\s*:\s*"[^"]+"} $data]
    set ::IDMappingWebBanques [lmap n $::IDMappingWebBanques {
	regexp {"name"\s*:\s*"([^"]+)"} $n -> n
	set n
    }]
    return $::IDMappingWebBanques
}


proc IDMappingWebNom {bank} {
    # name, for the UniProt ID mapping service (rest.uniprot.org), of an
    # IDMapping bank (names of banbi and of the old uploadlists service).
    # Most differ only by case and punctuation, the others are listed here.
    # Returns "" if the service does not know the bank.
    set T {
	ACC UniProtKB_AC-ID ID UniProtKB_AC-ID ACC+ID UniProtKB_AC-ID
	REFSEQ RefSeq_Protein REFSEQ_NT RefSeq_Nucleotide REFSEQ_NT_ID RefSeq_Nucleotide
	P_REFSEQ_AC RefSeq_Protein GI GI_number P_GI GI_number
	EMBL EMBL-GenBank-DDBJ EMBL_ID EMBL-GenBank-DDBJ EMBL_CDS EMBL-GenBank-DDBJ_CDS
	ENSEMBLGENOME Ensembl_Genomes ENSEMBLGENOME_PRO Ensembl_Genomes_Protein
	ENSEMBLGENOME_TRS Ensembl_Genomes_Transcript ENSEMBL_PRO Ensembl_Protein
	ENSEMBL_TRS Ensembl_Transcript ENSEMBL_ID Ensembl ENSEMBL_PRO_ID Ensembl_Protein
	ENSEMBL_TRS_ID Ensembl_Transcript WORMBASE_PRO WormBase_Protein
	WORMBASE_TRS WormBase_Transcript EUPATHDB VEuPathDB PHARMGKB ClinPGx
	PDB_ID PDB NF100 UniRef100 NF90 UniRef90 NF50 UniRef50
	GENEID GeneID P_ENTREZGENEID GeneID
    }
    set B [string toupper $bank]
    if {[dict exists $T $B]} {
	return [dict get $T $B]
    }
    set norm [regsub -all {[^A-Z0-9]} $B ""]
    foreach n [IDMappingWebBanques] {
	if {[regsub -all {[^A-Z0-9]} [string toupper $n] ""] eq $norm} {
	    return $n
	}
    }
    return ""
}


proc IDMappingWebGet {url {query ""}} {
    # GET (or POST if query is given) : returns {http_code data}, code 0
    # if the server could not be reached
    package require http
    package require tls
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    set opts [list -timeout 60000]
    if {$query ne ""} {
	lappend opts -query $query -type "application/x-www-form-urlencoded"
    }
    if {[catch {::http::geturl $url {*}$opts} tok]} {
	return [list 0 $tok]
    }
    if {[::http::status $tok] ne "ok"} {
	set r [list 0 [::http::status $tok]]
    } else {
	set r [list [::http::ncode $tok] [::http::data $tok]]
    }
    ::http::cleanup $tok
    return $r
}


proc IDMappingWebJob {from to Lids {taxid ""}} {
    # one job of the UniProt ID mapping service (from, to : names of the
    # service). Returns the lines of the result (list of fields, the
    # header line removed), or "Error".
    # To UniProtKB the fields are : from, accession, entry name.
    # Otherwise : from, to.
    set base "https://rest.uniprot.org/idmapping"
    set q [list from $from to $to ids [join $Lids ","]]
    if {[string is integer -strict $taxid]} {
	lappend q taxId $taxid
    }
    lassign [IDMappingWebGet "$base/run" [::http::formatQuery {*}$q]] code data
    if {$code != 200 || ! [regexp {"jobId"\s*:\s*"([^"]+)"} $data -> job]} {
	puts "IDMapping web : job not submitted ($code) [string range $data 0 200]"
	return "Error"
    }

    # wait for the job : the status gives "RUNNING" or "NEW" while it
    # runs, then a redirection (303) or the results
    set fin [expr {[clock seconds] + 300}]
    set attente 500
    while {1} {
	lassign [IDMappingWebGet "$base/status/$job"] code data
	if {$code == 303 || ($code == 200 && ! [regexp {"jobStatus"\s*:\s*"(NEW|RUNNING)"} $data])} {
	    break
	}
	if {$code != 200 || [clock seconds] > $fin} {
	    puts "IDMapping web : job $job failed ($code) [string range $data 0 200]"
	    return "Error"
	}
	after $attente
	update idletasks
	set attente [expr {min(2*$attente, 3000)}]
    }
    if {[regexp {"jobStatus"\s*:\s*"(ERROR|FAILURE)"} $data]} {
	puts "IDMapping web : job $job failed [string range $data 0 200]"
	return "Error"
    }

    if {$to eq "UniProtKB"} {
	set url "$base/uniprotkb/results/stream/$job?format=tsv&fields=accession,id"
    } else {
	set url "$base/stream/$job?format=tsv"
    }
    lassign [IDMappingWebGet $url] code data
    if {$code != 200} {
	puts "IDMapping web : results of job $job not read ($code)"
	return "Error"
    }
    set Lrows {}
    foreach l [lrange [split [string trim $data] \n] 1 end] {
	if {[string trim $l] ne ""} {
	    lappend Lrows [split [string trimright $l \r] \t]
	}
    }
    return $Lrows
}


proc IDMapping_web {from to LId {orga ""}} {
    # IDMapping by the UniProt web service (rest.uniprot.org/idmapping).
    # Same names of banks and same answer as IDMapping_sql : one element
    # per ID of LId, in the same order, list of the IDs found (empty if
    # none). from or to must be ACC, ID or ACC+ID (UniProt) ; between two
    # other banks the mapping goes through the UniProt accessions.
    set LId [CheckIdsAsList $LId]
    set Lvide [lrepeat [llength $LId] ""]
    if {$LId == {}} {
	return {}
    }
    set Luniprot {ACC ID ACC+ID}

    if {$from ni $Luniprot && $to ni $Luniprot} {
	# bank -> UniProt accession -> bank
	set Lacc [IDMapping_web $from ACC $LId $orga]
	set Lpremier [lmap a $Lacc {lindex $a 0}]
	set Lautre [IDMapping_web ACC $to [lsort -unique [lsearch -all -inline -not $Lpremier ""]] $orga]
	foreach a [lsort -unique [lsearch -all -inline -not $Lpremier ""]] r $Lautre {
	    set t($a) $r
	}
	set Lret {}
	foreach a $Lpremier {
	    lappend Lret [expr {[info exists t($a)] ? $t($a) : ""}]
	}
	return $Lret
    }

    set fw [IDMappingWebNom $from]
    set tw [expr {$to in $Luniprot ? "UniProtKB" : [IDMappingWebNom $to]}]
    if {$fw eq "" || $tw eq ""} {
	puts "IDMapping web : bank $from or $to unknown to UniProt"
	return $Lvide
    }
    # column of the answer : accession or entry name to UniProtKB
    set col [expr {$to eq "ID" ? 2 : 1}]

    # jobs of 10000 IDs at most (the limit of the service is 100000)
    set paquet 10000
    for {set d 0} {$d < [llength $LId]} {incr d $paquet} {
	set Lrows [IDMappingWebJob $fw $tw [lrange $LId $d [expr {$d+$paquet-1}]] $orga]
	if {$Lrows eq "Error"} {
	    return $Lvide
	}
	foreach r $Lrows {
	    set out [lindex $r $col]
	    if {$out ne ""} {
		lappend To([lindex $r 0]) $out
	    }
	}
	update idletasks
    }

    set Lret {}
    foreach i $LId {
	if {[info exists To($i)]} {
	    lappend Lret [lsort -unique $To($i)]
	} else {
	    lappend Lret ""
	}
    }
    return $Lret
}

proc IDMapping_WSL {from to Lids {taxid ""}} {
    # send IDMapping as local web service
    # see /home/moumou/bics/index.rvt

    FaireLire "Attention BICS est obsolete. Use Banbi"
    
    lassign [CheckIDMappingInputParam $from $to $Lids $taxid] from to Lids taxid
    
    package require TclCurl
    package require http
    
    set url "http://www.lbgi.fr/~moumou/bics/index.rvt"
    set Lparams [list from $from to $to ids [join $Lids ,]]
    if {$taxid ne ""} {
	lappend Lparams taxid $taxid
    }
    set query [::http::formatQuery {*}$Lparams]

    set out [::curl::transfer -url "${url}?$query" -followlocation 1 -bodyvar res]

    return $res
}


proc InfosFromUniProt {Lids {Lsqn ""}} {
    #
    # This routine retrieves infos from UniProt for each ID
    # Returns :
    # - an 'array get' for all infos for all ids
    # - an empty string if nothing found
    # - 0 if a problem occurred
    
    if {$Lids == {} } {
	return {}
    }
    
    # Transform all given AC/ID to their last ACC counterpart
    set Lori [lupper $Lids]
    set Luni [ConvertUniProt2UniProtAcc $Lori]
    foreach u $Luni o $Lori {
	set Lookup($u) $o
    }

    # DbFetchGet returns a TEXT !
    set out [DbFetchGET uniprot $Luni]
    if {$out == 0} {
	# Problem when fetching
	return 0
    }
    
    set Lembl [SplitLesEMBL $out]
    array set T {}
    set iVide 0
    foreach em $Lembl {
	if {[string trim $em] eq ""} {
	    incr iVide
	    continue
	}
	
	unset -nocomplain TInf
	array set TInf [DecortiqueLesLignesEMBL $em ID AC DE GN OS OC OX Seq LaDETotal GNTotal]

	# access: take all of them in case we have an obsolete one
	set AC [string map {"\;" " "} [join $TInf(AC)]]
	regsub -all { +} [string trim $AC] " " AC
	set AC [split $AC]
	# current AC is the first of the list.
	set currAC [lindex $AC 0]
	set currID $ID
	
	# find original access
	set acOri ""
	if {[info exists Lookup($currAC)]} {
	    set acOri [set Lookup($currAC)]
	} else {
	    foreach elt $AC {
		if {[info exists Lookup($elt)]} {
		    set acOri [set Lookup($elt)]
		    break
		}
	    }
	    if {$acOri eq ""} {
		puts "\n==> can't find $AC / $ID"
		parray TInf
		#puts ""
		#puts "[join $em \n]"
		#puts ""
		continue
	    }
	}
	
	set T($acOri,currAC) $currAC
	set T($acOri,BId) $ID
	set T($acOri,Desc) $DE
	set T($acOri,TaxId) $OX
	set T($acOri,Lineage) $OC
	set T($acOri,Organism) $OS
	set T($acOri,Sequence) $Seq
	set Llin [split $OC ";"]
	if {[set phy [string trim [lindex $Llin 0]]] ne "cellular organisms"} {
	    set T($acOri,Phylum) $phy
	} else {
	    set T($acOri,Phylum) [string trim [lindex $Llin 1]]
	}
    }

    return [array get T]
}


proc DbFetchSOAP {db Lid} {
    package require WS::Client

    # service DbFetch EBI
    set url "http://www.ebi.ac.uk/ws/services/WSDbfetch?wsdl"
    set ret [::WS::Client::GetAndParseWsdl $url]

    set Lid [list Q55C99 xp_570076 SYDC_HUMAN P13368]
    # DBs
    set rep [::WS::Client::DoCall WSDBFetchServerService getSupportedDBs [list ]]

    pdict $rep
    exit
    # DBs
    set rep [::WS::Client::DoCall WSDBFetchServerService  fetchBatch [list db $db ids [join $Lid ,] style default format default]]

    pdict $rep
    puts ""
    # Output is the TEXT of the entries
    set Lrep [split $rep \n]
    set Lres {}
    switch $db {
	"uniprotkb" -
	"refseqp" {
	    set Lsep [lsearch -regexp -all $Lrep "^//"]
	    set d 0
	    set Lres {}
	    foreach f $Lsep {
		lappend Lres [lrange $rep $d $f]
		set d [expr {$f+1}]
	    }
	}
    }
    puts "llength [llength $Lres]"
    foreach r $Lres {
	puts [join $r \n]
	puts ""
    }

    exit
    return
}


proc DbFetchGET {db Lid {format ""} {style ""}} {
    # Returns the TEXT content of the database entries
    #
    # Taken from EBI :
    # https://www.ebi.ac.uk/Tools/dbfetch/

    package require http
    package require TclCurl
    
    set url "https://www.ebi.ac.uk/Tools/dbfetch/dbfetch"

    set Lid [CheckIdsAsList $Lid]
    set nIds [llength $Lid]
    set Res ""
    set paquets 200
    #set paquets 15
    set ni [expr {int([llength $Lid]/$paquets)+1}]
    set Lparams0 {}
    lappend Lparams0 db $db style "raw"
    if {$format ne ""} {
	lappend Lparams0 format $format
    }
    
    for {set i 0} {$i < $ni} {incr i} {
	set d [expr {$i*$paquets}]
	set f [expr {($i+1)*$paquets-1}]
	if {$d == $nIds} {
	    continue
	}
	if {$f >= [llength $Lid]} {
	    set f [expr {[llength $Lid]-1}]
	}
	set Lparams $Lparams0
	lappend Lparams "id" "[join [lrange $Lid $d $f] ,]"
	set query [::http::formatQuery {*}$Lparams]
	#append query "&id=[join [lrange $Lid $d $f] ,]"
	set nTimes 0
	while {$nTimes < 3} {
	    set Msg ""
	    if {[catch {set ok [::curl::transfer -url $url -followlocation 1 -bodyvar out -post 1 -postfields $query -timeout 180]} Msg]} {
		if {$ok == 28} {
		    incr nTimes
		    puts "Timeout ! retrying, $nTimes time"
		} else {
		    # for others curl errors see later...
		    set nTimes 100
		}
		after 1000
	    } else {
		#everything went OK
		set nTimes 100
	    }
	}

	if {$out eq "" || [string range $out 0 4] eq "ERROR"} {
	    puts "\n## ERROR in DbFetchGET ###################"
	    puts "ok= $ok"
	    puts "$out"
	    puts "query:\n$query"
	    puts "## ERROR ###################\n"

	    return 0
	}
	# out is the variable associated to 'bodyvar' and contains the text of the HTML body
	append Res "$out"

	after 500
    }

    return $Res
}


proc FetchOneEBI {id} {
    set url "https://www.uniprot.org/uniprot/$id.txt"
    set out [HttpCopy $url]

    return $out
}


proc MacsimsREST {alignt} {
    package require TclCurl

    if {[string first "\n" $alignt] == -1} {
	# input is a file, get content
	set alignt [ContenuDuFichier $alignt]
    }

    set url "http://lbgi.fr/MACSIMS/load_alignment.php"

    set query [::http::formatQuery \
		   Sequence $alignt]
    set Txml ""
    if {[catch {set out [::curl::transfer -followlocation 1 -url $url -bodyvar Txml -post 1 -postfields $query]} Msg]} {
	FaireLire "Error while trying to compute Macsims !"
	puts "\n---------------\n$Msg"
    }
    #puts "\n$Txml\n"
    set Lxml [split $Txml \n]
    set idx [lsearch $Lxml "*\?id=*"]
    if {$idx == -1} {
	return ""
    }

    # get ID for macsims server request
    set Lid [lindex $Lxml $idx]
    set idx [string first "?id=" $Lid]
    set id [string range $Lid $idx+4 end-3]

    # now ask the servier with ID to get results
    set url2 "http://lbgi.fr:/MACSIMS/load_session.php"
    set query [::http::formatQuery \
		   id $id]
    if {[catch {set out [curl::transfer -followlocation 1 -url $url2 -bodyvar Txml -post 1 -postfields $query]} Msg]} {
	puts "\n-----------\n$out\n\n"
    }

    # get URL of output file
    set Lxml [split $Txml \n]
    set idx [lsearch $Lxml "*is available*"]
    #puts "idx avai $idx"
    set Lxml [lindex $Lxml $idx]
    set idx1 [string first "\"" $Lxml]
    set idx2 [string last  "\"" $Lxml]
    set suffix [string range $Lxml $idx1+1 $idx2-1]
    set url "http://lbgi.fr$suffix"
    set Txml ""
    ::curl::transfer -url $url -bodyvar Txml

    #puts $Txml

    return $Txml
}


proc eFetchREST {db Lid {what ""}} {
    package require TclCurl
    package require http
    package require tls
    package require tdom

    # part of eUtils service from NCBI.
    #
    # the type and format of returning data depends on
    # the rettype (gb entry, cds sequence, ...) and
    # retmode value (asn.1, xml, txt ...)
    # rettype and retmode are defined in table
    # http://www.ncbi.nlm.nih.gov/books/NBK25499/table/chapter4.chapter4_table1/?report=objectonly

    if {$what eq ""} {
	set what "gb"
    }

    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

    set db [string tolower $db]
    set retmode ""
    switch $db {
	"protein" {
	    switch $what {
		"docsum" {
		    set rettype "docsum"
		    set retmode "xml"
		}
		"xml" {
		    set rettype "native"
		    set retmode "xml"
		}
		"asn1" {
		    set rettype ""
		    set retmode ""
		}
		"tiny" {
		    set rettype fasta
		    set retmode xml
		}
		"gb" {
		    #set rettype native
		    set rettype gb
		    set retmode "text"
		}
		"xml" {
		    set rettype gb
		    set retmode "xml"
		}
		default {
		    set rettype "null"
		    set retmode "null"
		}
	    }
	}
	"nucleotide" {
	    switch $what {
		"gb" {
		    set rettype "gb"
		    #set retmode "xml"
		    set retmode "text"
		}
		"cds" {
		    set rettype "fasta_cds_na"
		    set retmode "text"
		}
	    }
	}
	"taxonomy" {
	    set rettype "null"
	    set retmode "xml"
	}
	"pubmed" {
	    set rettype "full"
	    set retmode "xml"
	}
	"pmc" {
	    set rettype "full"
	    set retmode "null"
	}
	"genome" {
	    set retmode "raw"
	    #set rettype "gb"
	    set rettype ""
	}
    }

    if {[string first "," $Lid] > -1} {
	set Lid [split $Lid ,]
    }

    set Lres ""
    set Loptions [list db $db]
    if {$rettype ne ""} {
	lappend Loptions rettype $rettype
    }
    if {$retmode ne ""} {
	lappend Loptions retmode $retmode
    }

    set Pack 10000
    set nPacks [expr {int(1.0*[llength $Lid]/$Pack)}]
    for {set i 0} {$i <= $nPacks} {incr i} {
	set d [expr {$i * $Pack}]
	set f [expr {($i + 1) * $Pack - 1}]
	if {$f > [llength $Lid]} {
	    set f end
	}
	set Lopt [list {*}$Loptions id [join [lrange $Lid $d $f] ,]]
	set query [::http::formatQuery {*}$Lopt]
	
	#set ddb [HttpCopy $url "" $query]
	set errorbuf ""
	if {1 && [catch {set out [::curl::transfer -followlocation 1 -url $url -errorbuffer errorbuf -bodyvar ddb -post 1 -postfields $query]} Msg]} {
	    puts "Error while transfering data !"
	    puts "Msg :\n$Msg"
	    set ddb ""
	}
	
	if {$ddb eq ""} {
	    continue
	}

	set LidNow $Lid
	switch $db {
	    "taxonomy" {
		lappend Lres {*}[TaxonomyProcessXML $ddb $LidNow]
	    }
	    "pubmed" {
		#puts "$LidNow\n$ddb\n"
		lappend Lres {*}[PubMedProcessXML $ddb $LidNow]
	    }
	    default {
		lappend Lres $ddb
	    }
	}
    }

    return $Lres
}


proc eFetchSOAP {db Lid01} {
    # the eFetch SOAP service only returns XML data
    set xml [::WS::Client::DoRawCall eFetchSequenceService run_eFetch [list db $db id [join $Lid ,]]]

    return $xml
}


proc PubMedProcessXML {xml Lid} {
    set o [open xml.xml w]
    puts $o $xml
    close $o

    set RId [dom parse "$xml"]
    set doc [$RId documentElement]

    array set T {}
    foreach aP [$doc selectNodes //PubmedArticleSet/PubmedArticle] {
	set mD [$aP selectNodes ./MedlineCitation]
	set id [$mD selectNode string(./PMID)]

	set aT [$mD selectNodes ./Article]
	set jrn [$aT selectNodes ./Journal]
	set jrI [$jrn selectNodes ./JournalIssue]
	set T($id,Volume)   [$jrI selectNode string(./Volume)]
	set T($id,Issue)    [$jrI selectNode string(./Issue)]
	set T($id,PubYear)  [$jrI selectNode string(./PubDate/Year)]
	set T($id,PubMonth) [$jrI selectNode string(./PubDate/Month)]

	set T($id,JrnName)  [$jrn selectNode string(./Title)]
	set T($id,JrnAbbv)  [$jrn selectNode string(./ISOAbbreviation)]
	set T($id,Title) [$aT selectNode string(./ArticleTitle)]
	set T($id,Pages) [$aT selectNode string(./Pagination/MedlinePgn)]
	set T($id,Abstract) [$aT selectNode string(./Abstract/AbstractText)]

	# Authors
	set aL [$aT selectNodes ./AuthorList]
	set LlastName {} ; set LfirstName {}
	set Laffi {}
	foreach aU [$aL selectNodes ./Author] {
	    lappend LlastName  [$aU selectNode string(./LastName)]
	    lappend LfirstName [$aU selectNode string(./ForeName)]
	    set affi {}
	    set aF [$aU selectNodes ./AffiliationInfo]
	    if {$aF ne ""} {
		foreach aFi $aF {
		    lappend affi [$aFi selectNode string(./Affiliation)]
		}
	    }
	    lappend Laffi $affi
	}
	foreach l $LlastName f $LfirstName a $Laffi {
	    lappend T($id,LAuthors) [list $l $f $a]
	}

	# Keywords/MeSH
	set LkeyP {} ; set LkeyS {}
	set mL [$mD selectNodes ./MeshHeadingList]
	if {$mL != {} } {
	    foreach mN [$mL selectNodes ./MeshHeading] {
		set dN [$mN selectNodes ./DescriptorName]
		set mes [$dN selectNode string(.)]
		set maj [$dN getAttribute MajorTopicYN N]
		if {$maj eq "Y"} {
		    lappend LkeyP $mes
		} else {
		    lappend LkeyS $mes
		}
	    }
	}

	lappend T($id,MeSHMajor) {*}$LkeyP
	lappend T($id,MeSHMinor) {*}$LkeyS
    }
    $RId delete
    update

    #parray T

    return [array get T]
    exit
}


proc TaxonomyProcessXML {Lxml Lid} {
    set RId [dom parse $Lxml]
    set doc [$RId documentElement]

    array set T {}
    foreach nT [$doc selectNodes //TaxaSet/Taxon] {
	set Tax [$nT selectNode string(./TaxId)]
	set isReplaced [expr {$Tax ni $Lid}]
	set sn     [$nT selectNode ./ScientificName]
	set ScName [$sn selectNode string(.)]
	set Rank   [$nT selectNode string(./Rank)]
	set Lin    [$nT selectNode string(./Lineage)]
	set Lon    {}
	foreach no [$nT selectNode ./OtherNames/Synonym] {
	    lappend Lon [$no selectNode string(.)]
	}
	set T($Tax,isReplaced) $isReplaced
	set T($Tax,ScientificName) "$ScName"
	set T($Tax,Rank) $Rank
	set T($Tax,Lineage) "$Lin"
	set T($Tax,Synonyms) $Lon
	# check for taxid changes
	set Lrep {}
	foreach no [$nT selectNode ./AkaTaxIds/TaxId] {
	    lappend Lrep [$no selectNode string(.)]
	}
	set T($Tax,Replaces) $Lrep
    }
    $RId delete
    update

    return [array get T]
}


proc eFetchProcessXML-tDOM {Lxml} {
    set Lfd [list taxonomy organism definition]

    set Id  [dom parse $Lxml]
    set doc [$Id documentElement]
    foreach ns [$doc selectNodes //GBSeq] {
	set id [$ns selectNode //GBSeq_locus/string(.)]
	foreach fd $Lfd {
	    set v [$ns selectnode //GBSeq_$fd/string(.)]
	    set T($id,$fd) $v
	    if {$fd eq taxonomy} {
		set lfd [lindex [split $lin ";"] 0]
		set T($id,phylum) $lfd
	    }
	}
    }

    return [array get T]
}


proc eFetchProcessXML-SAX {Lxml} {
    global TParser

    unset -nocomplain TParse
    set p [expat \
	       -elementstartcommand  eFst \
	       -characterdatacommand eFch \
	       -elementendcommand    eFed ]
    if [catch {$p parse $Lxml} res] {
	puts "ERROR while parsing XML !"
	puts "$res"
	$p delete
	update

	return ""
    }
    $p delete
    update

    return [array get TParser]
}


proc eFst {name atts} {
    global TParser
    lappend TParser(S) $name ;# push
}


proc eFch {str} {
    global TParser

    set type [lindex $TParser(S) end]

    switch $type {
	GBSeq_locus {
	    set TParser(Id) $str
	    lappend TParser(LId) $str
	}
	GBSeq_definition {
	    set id [set TParser(Id)]
	    set TParser($id,des) $str
	}
	GBSeq_taxonomy {
	    set id [set TParser(Id)]
	    set TParser($id,lineage) $str
	    set phy [lindex [split $str ";"] 0]
	    set TParser($id,phylum) $phy
	}
	GBSeq_organism {
	    set id [set TParser(Id)]
	    set TParser($id,organism) $str
	}
    }
}


proc eFed {name} {
    set ::TParser(S) [lrange $::TParser(S) 0 end-1] ;# pop
}


proc eLinkREST {dbfrom dbto Lid} {
    # Part of eUtils from NCBI
    # eLink only accepts GI numbers as input
    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi"
    set Paquet 200

    set Lres {}
    set ni [expr {int([llength $Lid]/$Paquet)+1}]
    for {set i 0} {$i < $ni} {incr i} {
	set d [expr {$i*$Paquet}]
	set f [expr {($i+1)*$Paquet-1}]
	set Ln [lrange $Lid $d $f]
	set cmd ""
	if {$dbfrom eq $dbto} {
	    set cmd ncheck
	} else {
	    set cmd acheck
	}
	# cmd $cmd
	set query [::http::formatQuery \
		       dbfrom $dbfrom \
		       db $dbto \
		       id [join $Ln ,]]

	set xml [HttpCopy $url "" $query]

	if {$dbfrom eq $dbto} {
	    set rpro [eLinkProcess $xml ngb]
	} else {
	    set rpro [eLinkProcess $xml cross]
	}
	if {$rpro == "ReDo"} {
	    set Lres [eLinkREST $dbfrom $dbto $Lid]
	    break
	}
	if {$rpro == -1} {
	    puts "\nError in eLink !"
	} else {
	    lappend Lres {*}$rpro
	}
    }

    return $Lres
}


proc eLinkProcess {Lxml what} {
    if {[catch {set RId [dom parse $Lxml]} Msg]} {
	puts "$Msg"
	puts "$Lxml"

	return ReDo
    }
    set doc [$RId documentElement]

    set Lid {}
    set Nerr [$doc selectNodes //eLinkResult/ERROR]
    if {$Nerr != {} } {
	set err [$Nerr selectNode string(.)]
	$RId delete
	if {[regexp {timed out} $err]} {
	    return "ReDo"
	} else {
	    return -1
	}
    }

    set nid [lindex [$doc selectNodes //IdList/Id] 0]
    if {[$nid selectNode string(.)] == -1} {
	$RId delete
	return -1
    }

    switch $what {
	"cross" {
	    set Lnd [$doc selectNodes //LinkSetDb/Link/Id]
	}
	"ngb" {
	    set lsd [lindex [$doc selectNodes //eLinkResult/LinkSet/LinkSetDb] 0]
	    if {$lsd eq ""} {
		$RId delete
		return -1
	    }
	    set Lnd [lrange [$lsd selectNodes ./Link/Id] 0 10]
	}
    }
    set Lid {}
    foreach n $Lnd {
	lappend Lid [$n selectNode string(.)]
    }
    $RId delete
    update

    return $Lid
}


proc tesp {} {
    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?"

    set id {( ("aars2"[Abstract] OR "ears2"[Abstract] OR "fars2"[Abstract] OR "hars2"[Abstract] OR "vars2"[Abstract] OR "yars2"[Abstract] OR "cars2"[Abstract] OR "dars2"[Abstract] OR "iars2"[Abstract] OR "lars2"[Abstract] OR "mars2"[Abstract] OR "nars2"[Abstract] OR "rars2"[Abstract] OR "sars2"[Abstract] OR "tars2"[Abstract] OR "wars2"[Abstract] OR "pars2"[Abstract] OR "gars2"[Abstract] OR "kars2"[Abstract]) AND ("2007"[Date - Publication] : "3000"[Date - Publication])) AND ( "mutation"[Title/Abstract] OR "patient"[Title/Abstract] OR "mutations"[Title/Abstract] OR "patients"[Title/Abstract] OR "lbsl"[Title/Abstract] OR "leukoencephalopathy"[Title/Abstract] OR "subject"[Abstract] OR "subjects"[Abstract] OR "disease"[Abstract] OR "diseases"[Abstract] OR "disorder"[Abstract] OR "disorders"[Abstract]) AND "English"[Language]}
    set id [list "[string map {"\"" "\\\""} $id]"]

    set Lrep [eSearchREST pubmed $id]
    puts "[llength $Lrep]"

    exit

    set query [::http::formatQuery \
		   db pubmed \
		   term $id]
    set ddb [HttpCopy $url "" $query]
    puts "$ddb"

    return
}


proc eSearchREST {db Lid} {
    # Part of eUtils from NCBI
    # eSearch returns a possible UID corresponding to
    # the entered term
    # db = protein nucleotide pubmed taxonomy
    #
    # proceed ONE By ONE !!
    # Returns a list in the same order as input.
    # Item not found remain unchanged in the output list

    # for protein/nucleotide/EST database, fields description
    # can be found here
    # https://www.ncbi.nlm.nih.gov/books/NBK49540/

    package require TclCurl

    if {$db ni {genome protein nucleotide pubmed taxonomy}} {
	puts "Bad Database !"

	return ""
    }

    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    set Lres {}
    foreach id $Lid {
	# version 2.0
	set query [::http::formatQuery \
		       db $db \
		       retmax 9999 \
		       term $id]
	puts "\ncurlQuery :\n$query\n"
	#set ddb [HttpCopy $url "" $query]
	set out [::curl::transfer -followlocation 1 -url $url -bodyvar ddb -post 1 -postfields $query]
	if {$db eq "pubmed"} {
	    set Lres $ddb
	} else {
	    lappend Lres {*}$ddb
	}
    }

    set Lret {}
    if {$db eq "pubmed"} {
	if {$Lres == {}} {
	    return ""
	}
	set Lret $Lres
    } else {
	foreach id $Lid rs $Lres {
	    if {$rs eq ""} {
		lappend Lret $id
	    } else {
		lappend Lret $rs
	    }
	}
    }

    return $Lret
}


proc eSearchProcessXML {Lxml} {
    set rep {}
    set RId [dom parse $Lxml]
    set doc [$RId documentElement]
    set Lnid [$doc selectNodes //Id]
    if {$Lnid eq ""} {
	set rep ""
    } else {
	foreach n $Lnid {
	    lappend rep [$n selectNode string(.)]
	}
    }

    $RId delete
    update

    return $rep
}


proc eSummaryGetInfo {Lid Ltab what} {
    set Lres {}
    array set T $Ltab
    foreach id $Lid {
	set Lix [lsearch -all -nocase $Ltab $id]
	if {$Lix != {} } {
	    lassign [split [lindex $Ltab [lindex $Lix 0]-1] ,] GI tmp
	    if {[info exists T($GI,$what)]} {
		lappend Lres $T($GI,$what)
	    } else {
		lappend Lres ""
	    }
	} else {
	    lappend Lres ""
	}
    }

    return $Lres
}


proc eSummaryREST {db Lid {What ""} {GetXml ""}} {
    # Part of eUtils from NCBI
    #
    # ==> WARNING !!!!
    # ==> eSummary only accepts GI numbers
    #
    # db = protein nucleotide pubmed taxonomy
    #
    # proceed by 200 IDs batches, sent by POST (no limit on the
    # length of the URL). UrlFetch handles timeouts and redirections.
    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
    set Lres {}
    set Paquet 200
    set LesXml {}
    for {set d 0} {$d < [llength $Lid]} {incr d $Paquet} {
	set query [::http::formatQuery \
		       db $db \
		       id [join [lrange $Lid $d [expr {$d+$Paquet-1}]] ","] \
		       retmax 1000]
	set ddb [UrlFetch $url $query]
	if {$ddb eq ""} {
	    # NCBI not reachable : nothing for this batch
	    continue
	}

	if {$GetXml eq "GetXml"} {
	    lappend LesXml $ddb
	    continue
	}

	if {[catch {eSummaryProcessXML $ddb} Lx]} {
	    puts "eSummaryREST : bad answer from NCBI ($Lx)"
	    continue
	}
	lappend Lres {*}$Lx
    }

    if {$GetXml eq "GetXml"} {
	return $LesXml
    }

    # get desired info
    if {$What ne ""} {
	set Lres [eSummaryGetInfo $Lid $Lres $What]
    }

    return $Lres
}


proc eSummarySOAP {db Lid} {
    # eSummary with db=protein only accepts GI numbers
    # proceed by 200 ids batches
    set Lres {}
    set i 0
    set lg [llength $Lid]
    while {$i < $lg} {
	set Ln [lrange $Lid $i $i+199]
	set ddb [::eUtilsService::run_eSummary $db "" [join $Ln ,] "" "" "" "" ""]

	lappend Lres {*}[eSummaryProcess $ddb acc]
	incr i 200
    }

    return $Lres
}


proc eSummaryProcessXML {Lxml} {
    array set T {}
    #Espionne "\neSummary\n$Lxml"
    set RId [dom parse $Lxml]
    set doc [$RId documentElement]
    foreach nd [$doc selectNodes //DocSum] {
	foreach nc [$nd childNodes] {
	    if {[$nc nodeName] eq "Id"} {
		set id [$nc selectNode string(.)]
	    } else {
		set t [$nc getAttribute Name unk]
		set v [$nc selectNode string(.)]
		set T($id,$t) $v
	    }

	    foreach dbn {refseq genbank embl} {
		set T($id,$dbn) ""
	    }
	    if {[info exists T($id,Extra)]} {
		set Lr [split [set T($id,Extra)] "|"]
		foreach pfx {ref gb emb} dbn {refseq genbank embl} {
		    set i [lsearch $Lr $pfx]
		    if {$i != -1} {
			set seqid [lindex $Lr $i+1]
			set T($id,$dbn) $seqid
		    }
		}
	    }
	    if {[set T($id,refseq)] eq "" && [info exists T($id,Caption)]} {
		set T($id,refseq) [set T($id,Caption)]
	    }
	}
    }
    $RId delete
    update

    return [array get T]
}


proc eSummaryProcess {Lsum {what all}} {
    set Ls [dict get $Lsum DocSum]
    foreach p $Ls {
	set id [lindex $p 1]
	set Lit [lindex $p 3]
	lassign [lindex $Lit 0] tmp T($id,acc)
	lassign [lindex $Lit 1] tmp T($id,def)
	lassign [lindex $Lit 2] tmp T($id,crs)
    }

    if {$what eq "all"} {
	return [array get T]
    } else {
	return [array get T *$what]
    }
}


proc PDBeInterface {Lid} {
    set names [string tolower [join $Lid ,]]
    set url "http://www.ebi.ac.uk/pdbe/pisa/cgi-bin/interfaces.pisa?$names"

    return "[HttpCopy $url]"
}



#####################################

proc testservice {} {
    package require http

    set Lid [list Q55C99 SYDC_HUMAN P13368]
    DbFetchSOAP refseqp $Lid


    set Lid file.fof
    set url "http://www.uniprot.org/batch/"
    set query [::http::formatQuery format txt file "file.fof"]
    puts "pwd [pwd]"
    cd /home/moumou/ordali/alitest
    #set query [::http::formatQuery format txt file "P13368 sydc_human q55c99"]
    set rep [HttpCopy $url "" $query]
    puts "$rep"

    exit
    return
}


proc totati {} {

    set file filefof
    set ifid [open $file "r"]
    fconfigure $ifid -translation binary
    set data [read $ifid]
    close $ifid
    puts "data $data"


    exit
}


proc eft {} {
    set Lid [list Q55C99 xp_570076 SYDC_HUMAN P13368 ZP_01623730.1 YP_003326263.1 XP_001267188.1]
    array set T [InfosFromRefSeq $Lid]
    parray T

    exit
}


proc tsumtax {} {
    set Lid [list 578455 242507 759272 5141 431241 660122 645133 559298 330879 441960 336722 246410 663202 554155 656061 306902 284592 322104 237561 379508 294746 644223 284591 284593 559292 436907 284590 284811 931890 559295 559307 284812 402676 486041 246409 999809 237631 1128400 1054147 9606 10090 9305 7955 7739 10228 6239 7217 7165 7176 7159 121224 6669 6945 13686 104421 946362 6183 81824 403677 3055 554065 296587 70448 3694 3702 4577 452637 583355 391774 883 207559 525146 525897 363253 443144 351605 316067 243231 398767 338966 177439 177437 335543 56780 639282 264201 530564 446471 247156 446465 471857 292415 335283 349741 436114 204536 123214 518766 289376 608538 309799 515635 340099 273068 351627 521460 373903 370438 246194 477974 429009 349161 591001 292459 272564 224308 279010 315750 491915 545693 235909 398511 458233 226185 324057 387092 479437 278197 309801 479434 525904 243164 383372 326427 316274 526218 190304 655815 521097]

    array set T [eSummaryREST taxonomy $Lid]
    parray T

    exit
}


proc Convert2GI {db Lid} {
    return [eSearchREST $db $Lid]
}


proc AnnoteNonAnnotes {} {
    global LNOrdali TDesDescriptifs TDesOrganismes TDesTaxId TDuLineage TDesPhylum

    set L2gi {}
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}

	if {[EstUnRefseq $n]} {
	    lappend L2gi $n
	}
	if {[set TDesOrganismes($n)] eq ""} {
	    lappend L2gi $n
	}
    }
    set L2gi [lsort -unique $L2gi]
    puts "\nL2gi $L2gi"
    set Lgi [Convert2GI protein $L2gi]
    puts "Lgi $Lgi"

    # retrieve basic information
    array set T [eSummaryREST protein $Lgi]
    set Ltn {} ; set Lti {}
    foreach gi $Lgi n $L2gi {
	# GI not found
	if {$gi eq $n} {continue}

	if {[info exists T($gi,Title)]} {
	    set TDesDescriptifs($n) [set T($gi,Title)]
	}
	if {[info exists T($gi,TaxId)]} {
	    set tid [set T($gi,TaxId)]
	    set TDesTaxId($n) $tid
	    lappend Ltn $n
	    lappend Lti $tid
	}
    }

    if {$Ltn != {} } {
	array set X [eFetchREST taxonomy $Lti]
	parray X
	foreach n $Ltn id $Lti {
	    if {[info exists X($id,Lineage)]} {
		set lin [split [set X($id,Lineage)] ;]
		set TDuLineage($n) $lin
		set TDesPhylum($n) [lindex $lin 1]
		set TDesOrganismes($n) [set X($id,ScientificName)]
	    }
	}
    }

    VueEditee 1
    SauveLAlignement XML JLeSauveAs

    puts ""
    foreach n $::LNOrdali {
	if {[string trim $n] eq ""} {
	    puts ";;"
	    continue
	}

	set o [set TDesOrganismes($n)]
	set p [set TDuLineage($n)]
	puts "$n;$o;$p"
    }

    exit
}


proc ttid_SERVICE {} {
    set Li [list XP_002997757.1 BAM80333]

    set L [eSearchREST protein $Li]
    array set X [eSummaryREST protein $L]
    parray X
    puts ""
    foreach k [array names X "*,TaxId"] {
	unset -nocomplain T
	array set T [eFetchREST taxonomy [set X($k)]]
	parray T
	puts ""
    }

    exit
}

proc teli {} {
    set res [IDMapping "ACC+ID" ACC SYD_ECOLI]
    puts "$res"

    set url "http://www.uniprot.org/mapping?query=SYD_ECOLI&from=ACC+ID&to=ACC&format=tab"
    set url "http://www.uniprot.org/mapping?query=SYDC_HUMAN&from=ACC+ID&to=ID&format=tab"
    set res [HttpCopy $url]
    puts "$res"

    puts "mnemonic"
    set url "http://www.uniprot.org/uniprot/?query=mnemonic%3aSYFB_SILPO&format=list"
    set res [HttpCopy $url]
    puts "$res"

    exit
}


proc ListOfEBIDatabases {} {
    # databanses list :
    # https://www.uniprot.org/help/api_idmapping
    # http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/database
    #
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/database"
    set Lxml [HttpCopy $url]
    set RId [dom parse $Lxml]
    set doc [$RId documentElement]
    puts "\nDatabase Name <-> keyword"
    foreach nd [$doc selectNodes //values/value] {
	set db [$nd selectNode string(./label)]
	set vl [$nd selectNode string(./value)]
	puts "$db <-> $vl"
    }

    exit
}


proc BlastServiceEBI {args} {
    # see http://www.ebi.ac.uk/Tools/webservices/services/sss/ncbi_blast_rest
    #
    # the routine ListOfEBIDatabases lists all blast databases
    # available at EBI.
    # for facility, the arguments will be the same as for the
    # NCBI Blast service
    #

    set Lopt [list email $::Defauts(Email)]
    foreach {k v} $args {
	switch $k {
	    "-d"      {lappend Lopt database $v}
	    "-query"  {lappend Lopt sequence $v}
	    "-expect" {lappend Lopt exp $v}
	    "-f"      {
		if {[regexp -nocase {no|false|0} $v]} {
		    lappend Lopt filter F
		} else {
		    lappend Lopt filter T
		}
	    }
	    "-nlist"  {
		lappend Lopt scores $v
		lappend Lopt alignments $v
	    }
	    "-p"      {lappend Lopt program $v}
	    "-T"      {lappend Lopt FORMAT_TYPE $v}
	    "-stype"  {
		set Lval {protein rna dna}
		if {[string tolower $v] in $Lval} {
		    lappend Lopt stype $v
		}
	    }
	}
    }

    set query [::http::formatQuery {*}$Lopt]
    set BaseUrl "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/run/"
    set res [HttpCopy $BaseUrl "" $query]

    # do we got a good jobId ?
    set jobId [string trim $res]
    if {[string range $jobId 0 9] ne "ncbiblast-"} {
	return ""
    }

    set done 0
    set urlStatus "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/status/$jobId"
    set Lbad [list ERROR FAILED NOT_FOUND]
    while {! $done} {
	after 10000
	set res [HttpCopy $urlStatus]
	#puts ">$res<"
	if {$res in $Lbad} {
	    return ""
	}
	if {$res eq "FINISHED"} {
	    set done 1
	}
    }

    # get results
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/result/$jobId/out"
    set res [HttpCopy $url]

    return $res
}


proc BlastService {args} {
    # keys === values
    #
    # https://ncbi.github.io/blast-cloud/dev/api.html
    #
    # QUERY gi|seq
    # DATABASE nr
    # HITLIST_SIZE 10
    # FILTER L
    # EXPECT 10
    # FORMAT_TYPE HTML
    # PROGRAM blastn|blastp
    # CLIENT web
    # SERVICE plain
    # NCBI_GI on
    # PAGE Nucleotides
    # FORMAT_TYPE HTML|Text|XML
    # CMD Put|Get|Info
    set BaseUrl "https://www.ncbi.nlm.nih.gov/blast/Blast.cgi?"
    set Lopt [list CMD Put]
    foreach {k v} $args {
	switch $k {
	    "-d"      {lappend Lopt DATABASE $v}
	    "-query"  {lappend Lopt QUERY $v}
	    "-expect" {lappend Lopt EXPECT $v}
	    "-f"      {lappend Lopt FILTER L}
	    "-nlist"  {lappend Lopt HITLIST_SIZE $v}
	    "-p"      {lappend Lopt PROGRAM $v}
	    "-T"      {lappend Lopt FORMAT_TYPE $v}
	    "-orga"   {lappend Lopt ENTREZ_QUERY "txid$v\[orgn\]"}
	    "-qdef"   {lappend Lopt QUERY_BELIEVE_DEFLINE $v}
	}
    }

    set query [::http::formatQuery {*}$Lopt]
    #puts "query $query"
    set res [HttpCopy $BaseUrl "" $query]
    #puts "$res"
    set Lres [split $res "\n"]
    lassign [CheckBlastStatus $Lres] RID RTOE Status
    if {$Status ne ""} {
	puts "Problem with Blast service !"
	puts "Status= $Status"
	puts "Query $query"
	flush stdout
	return $Status
    }

    if {$RTOE eq "" || $RTOE <= 0} {
	puts "Problem with Blast !\nRTOE >$RTOE< RID >$RID<"
	flush stdout

	return ""
    }

    set url "${BaseUrl}&CMD=Get&RID=$RID&FORMAT_TYPE=Text"
    set nCmp 0 ; set maxCmp 100
    set twait [expr {$RTOE*500}]
    while {$Status ne "READY"} {
	after $twait
	set res [HttpCopy $url]
	set Lres [split $res "\n"]
	lassign [CheckBlastStatus $Lres] RID RTOE Status
	incr nCmp
    }

    if {0 && $nCmp == $maxCmp} {
	puts "Problem with Blast service !"
	puts "Status = $Status"
	return ""
    }

    return $Lres
}


proc CheckBlastStatus {Lignes} {
    set id [lsearch -regexp $Lignes "QBlastInfoBegin"]
    set if [lsearch -regexp $Lignes "QBlastInfoEnd"]
    if {$id == -1} {
	puts "Problem ! No Blast service information"
	if {[lsearch -regexp $Lignes "Server Error"] != -1} {
	    # Blast server Error
	    puts "Interrupted service !"
	    flush stdout
	    set Status "ServerError"
	} else {
	    puts "Blast Error :\n[join $Lignes \n]\n"
	    flush stdout
	    set Status "Error"
	}

	return [list 0 0 $Status]
    }

    set RID 0
    set RTOE 0
    set Status ""
    foreach l [lrange $Lignes $id+1 $if-1] {
	set l [string map {"\t" " " "=" " "} [string trim $l]]
	regsub -all { +} $l " " l
	lassign [split $l " "] what value
	switch $what {
	    "RID"    {set RID $value}
	    "RTOE"   {set RTOE $value}
	    "Status" {set Status $value}
	}
    }

    return [list $RID $RTOE $Status]
}


proc ThreadedBlastService {Ljobs} {
    package require Thread

    set program {
	set OrdaliDejaSource 1
	set GscopeDir $env(GSCOPEDIR)
	source [file join $GscopeDir gscope_source.tcl]
	set OrdaliDir $env(ORDALIDIR)
	set OrdaliDejaSource 0
	source [file join $OrdaliDir src ordali_source.tcl]

	package require Thread
	set VariablesAuDepart [info globals]

	InitLesDefauts
	LesDefauts OnlyTLog 1
	LesDefauts Mode batch
    }

    # Create a pool of threads and initialize them with our code
    set poolid [tpool::create -maxworkers 20 -initcmd $program]
    # Create a number of job requests and
    # submit the jobs to the pool.
    # We keep an id for each job so we can
    # track when they complete
    set jids {}
    foreach Largs $Ljobs {
	set id [tpool::post -nowait $poolid [list BlastService {*}$Largs]]
	lappend jids $id

	set iq [lsearch $Largs "-query"]
	set query [lindex $Largs $iq+1]
	# is query a fasta ?
	if {[string first "\n" $query] != -1} {
	    set query [lindex [split $query \n] 0]
	}
	set io [lsearch $Largs "-orga"]
	if {$io == -1} {
	    set orga "none"
	} else {
	    set orga [lindex $Largs $io+1]
	}

	lappend Tj(Lid)    $id
	set Tj($id,Largs)  $Largs
	set Tj($id,Input)  [list $query $orga]
	set Tj($id,query)  $query
	set Tj($id,Res)    ""
	set Tj($id,nTimes) 0
    }

    # Wait for the jobs we submitted to complete.
    # Collect the results and remove completed jobs
    # from the set of job ids so that we can
    # wait on the running jobs each time around the outer loop.
    set limit 0
    set maxlim [expr {5*[llength $jids]}]
    set nDone 0
    set nInit [llength $jids]
    while {[llength $jids] > 0 && $limit < $maxlim} {
	if {! ($nDone % 10)} {
	    puts [format "%d done ..." $nDone]
	    flush stdout
	}
	set done [tpool::wait $poolid $jids]

	# check finished jobs
	foreach id $done {
	    set Tj($id,Res) [tpool::get $poolid $id]
	    if {$Tj($id,Res) eq "ServerError" && $Tj($id,nTimes) < 5} {
		puts "----------------------"
		puts "Server Error !"
		puts "Args : $Tj($id,Largs)"
		puts "----------------------"
		flush stdout
		update idletasks
		incr Tj($id,nTimes)
		set newid [tpool::post -nowait $poolid [list BlastService {*}$Tj($id,Largs)]]
		lappend jids $newid
		foreach k [array names Tj "$id,*"] {
		    lassign [split $k ,] tmp key
		    set Tj($newid,$key) $Tj($k)
		}
		array unset Tj "$id,*"
	    }

	    set ndx [lsearch -exact $jids $id]
	    if {$ndx != -1} {
		set jids [lreplace $jids $ndx $ndx]
		update
	    }
	}
	incr limit
	set nDone [expr {$nInit - [llength $jids]}]
    }
    if {$limit >= $maxlim} { puts "hit limit"}

    # Clean up and report
    tpool::release $poolid

    return [array get Tj]
}


proc TBS {} {
    puts "[DonneDateEtHeure]"

    set Ltax [LesLignesDuFichier show.id]
    set Ljobs {}
    foreach org $Ltax {
	lappend Ljobs [list -p blastp -d nr -orga $org -expect 0.00001 -query p21889 -nlist 10 -f 1]
    }
    array set rep [ThreadedBlastService $Ljobs]
    parray rep

    exit
}


proc TBS2 {} {
    puts "[DonneDateEtHeure]"

    set Ltax [LesLignesDuFichier show.id]
    set Ljobs {}
    foreach org $Ltax {
	set Lres [BlastService -p blastp -d nr -orga $org -expect 0.00001 -query p21889 -nlist 10 -f 1]
    }

    exit
}


proc tstwb {} {
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/"

    # programm
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/program"
    set res [HttpCopy $url]
    puts "PROGRAM"
    puts "$res\n"

    # sequence
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/sequence"
    set res [HttpCopy $url]
    puts "SEQUENCE"
    puts "$res\n"

    # STYPE
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/parameterdetails/stype"
    set res [HttpCopy $url]
    puts "STYPE"
    puts "$res\n"

    #exit

    set seq ">sp|P15179|SYDM_YEAST Aspartate--tRNA ligase, mitochondrial OS=Saccharomyces cerevisiae (strain ATCC 204508 / S288c) GN=MSD1 PE=1 SV=1
MLARSRVCLQTITRRLADFPEANAIKKKFLFRKDTSTIKQLKGLSSGQKIVLNGWIEQKPKRVGKNLIFGLLRDSNGDIIQLVDNKSLLKGFTLEDVVQAVGILSLKRKLSNEDADEYEVQLEDITVLNASNKKPAQMQDFKLSAIYPPEFRYLQLRNPKYQDFLKKRSSISKEIRNSFNNFDFTEVETPMLFKATPEGAREFLVPTRTKRSDGKPSFYALDQSPQQYKQLLMASGVNKY
YQMARCFRDEDLRADRQPEFTQVDMEMAFANSEDVMKIIEKTVSGVWSKFSKKRGLLTLDSKGTLVPAKKENGTVSIFRMTYEQAMTSYGIDKPDLRAPDLKIINLGEFNAFSHLNKKFPVFEVIILRSAFSNMEEYKERWSFLTNNSNYNYRVPIVLPIENDEQANSNWFENFHAIATFENPHLITKFLKLKKGDIVCGCTREPNHSIFENPTPLGRLRQLVLQSEHGKNIYHAVNKDVASWIVDFPLFSPVIIEDKSGKKEKLAYPEYEKDRLCSTHHPFTMVKLKDYEKLEKTPEKCLGRHYDLVVNGVELGGGSTRIHDPRLQDYIFEDILKIDNAYELFGHLLNAFDMGTPPHAGFAIGFDRMCAMICETESIRDVIAFPKSITGADLVVKSPSVIPESILEPYNIKYSNSKK
"
    set Lres [BlastServiceEBI -p blastp -d uniprotkb -expect 1e-5 -query $seq -nlist 10 -f T -stype protein]
    puts "\n-----------------------"
    puts "Blast result\n$Lres\n"
    DecortiqueBlast $Lres "" "" "" LBbid LBacc LBde "" LBPN LAli
    puts "\n----------------------------"
    foreach a $LBacc p $LBPN ali $LAli {
	puts "$a $p"
	set lgt -1 ; set pid -1
	foreach l $ali {
	    set l [string trim $l]
	    if {[string range $l 0 5] eq "Length"} {
		set lgt [string range $l 7 end]
	    }
	    if {[string range $l 0 9] eq "Identities"} {
		set id [string first "(" $l]
		set if [string first ")" $l]
		set pid [string range $l $id+1 $if-1]
	    }
	}
	puts "$lgt $pid"
	puts ""
    }

    exit
}


proc tstat {} {
    set jid "ncbiblast-R20140331-100922-0009-50350078-pg"

    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/status/$jid"
    set res [HttpCopy $url]
    puts "$res"
    puts "\n\n"
    #exit
    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/resulttypes/$jid"
    set res [HttpCopy $url]
    puts "RESTYPES\n[string map {</ \n</} $res]"

    set url "http://www.ebi.ac.uk/Tools/services/rest/ncbiblast/result/$jid/out"
    set res [HttpCopy $url]
    puts "\n\nRESULT\n$res"


    exit
}

proc ttt {} {
    set Lid [list Q8SRE0 Q8IJP3 Q22XF6 Q9GQ39 XP_763084 Q54KR1 Q4QGR8 Q4CQ34 Q4CUZ9 XP_002286825 O76618]
    set res [IDMapping "ACC+ID" ACC $Lid]
    puts "$res"
    puts "\n-----------------------"
    puts "[Convert2UniProtAcc $Lid]"

    exit
}


proc tlesnm {} {
    set Ll [LesLignesDuFichier lesnm]
    set ret [eFetchREST nucleotide $Ll cds]
    puts "[join $ret \n]"

    foreach k [array names ::TDesPhylum] {
	if {[set ::TDesPhylum($k)] ne ""} {
	    puts "$k"
	}
    }

    exit
}


proc CreatePDBQueryReturn {args} {
    global PDBQ
    
    if {[lsearch $args "-return"] == -1} {
	lappend args "-return" "entry"
    }
    
    set valIdent -1
    set valRet  "entry"
    foreach {k v} {*}$args {
	switch $k {
	    "-return" {
		set valRet $v
	    }
	    "-identity" {
		set valIdent $v
	    }
	}
    }
    if {$valIdent == -1} {
	set aggMethod "matching_uniprot_accession"
    } else {
	set aggMethod "sequence_identity"
    }

    set retNode ""
    append retNode "\"request_options\": \{\n"
    append retNode "\"results_verbosity\": \"compact\",\n"
    append retNode "\"return_all_hits\": true"
    
    if {1} {
	append retNode ",\n"
	append retNode "\"group_by\": \{\n"
	append retNode "\"aggregation_method\": \"$aggMethod\""
	if {$valIdent != -1} {
	    append retNode ",\n"
	    append retNode "\"similarity_cutoff\": $valIdent"
	}
	append retNode "\n"
	append retNode "\},\n"
	append retNode "\"group_by_return_type\": \"representatives\"\n"
    } else {
	# no grouping
	append retNode "\n"
    }
    append retNode "\},\n"
    append retNode "\"return_type\": \"$valRet\""
    
    return $retNode
}


proc CreatePDBQueryNodes {args} {
    global PDBQ
    
    LookupPDBQueryAttributes
    
    set Lnodes {}
    foreach {k v} {*}$args {
	if {$k in {"-return" "-identity"}} {
	    continue
	}
	
	if {! [info exists PDBQ($k,att)]} {
	    puts "Option >$k< is not available !"
	    continue
	}
	set att $PDBQ($k,att)
	set ope $PDBQ($k,ope)
	set val $PDBQ($k,val)
	
	# check if given value is OK
	if {$val ne ""} {
	    # special case : x-ray
	    if {$v eq "x-ray"} {
		set v "X-RAY DIFFRACTION"
	    }
	    
	    if {$v ni $val} {
		puts "ERROR ! Value >$v< not available for -k. Should be one of $val"
		continue
	    }
	}
	
	set node "\{\n"
	append node "\"type\" : \"terminal\",\n"
	append node "\"service\" : \"text\",\n"
	append node "\"parameters\": \{\n"
	append node "\"attribute\": \"$att\",\n"
	append node "\"operator\": \"$ope\",\n"
	append node "\"value\": \"$v\"\n"
	append node "\}\n"
	append node "\}\n"
	
	lappend Lnodes $node
    }
    
    return $Lnodes
}


proc SendPDBQuery {query} {
    set url "https://search.rcsb.org/rcsbsearch/v2/query"

    if {0} {
	# autre solution qui marche aussi ...
	package require TclCurl
	set errVar ""
	set ok [::curl::transfer -url $url -errorbuffer errVar -followlocation 1 -bodyvar out -post 1 -postfields "$query" -timeout 180 -httpheader "Content-Type: application/json"]
	
	puts "ok= $ok"
	puts "out= $out"
	puts "err= $errVar"
    }
    
    ::http::config -urlencoding utf-8
    package require tls
    http::register https 443 tls::socket
    
    set tok [::http::geturl $url -query "$query" -type "application/json"]
    set Lpdb [::http::data $tok]
    ::http::cleanup $tok
    
    return $Lpdb
}


proc PDBQuery {args} {
    # based on new PDB Search API
    #
    # examples of queries
    # https://search.rcsb.org/#group-by-return-type
    # list of attributes
    # https://search.rcsb.org/structure-search-attributes.html
    
    set Lnodes [CreatePDBQueryNodes $args]
    if {[llength $Lnodes] > 1} {
	set multi 1

   } else {
	set multi 0
    }
    
    set query "\{\n"
    append query "\"query\": "
    if {$multi} {
	append query "\{\n"
	append query "\"type\": \"group\",\n"
	append query "\"logical_operator\": \"and\",\n"
	append query "\"nodes\": \[\n"
	append query [join $Lnodes ,]
	append query "\]\n"
	append query "\},\n"
    } else {
	# only one clause
	append query {*}$Lnodes
	append query ",\n"
    }
    append query [CreatePDBQueryReturn $args]
    append query "\n\}"
    
    #puts "\n$query\n"
    
    set rep [SendPDBQuery $query]
    #puts "rep= $rep"
    
    package require json
    set d [json::json2dict $rep]
    set Lrep [dict get $d "result_set"]
    
    return $Lrep
}


proc PDBQuery_old {args} {
    if {([llength $args] % 2)} {
	return {}
    }
    package require http
    set pdbXML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<orgPdbCompositeQuery version=\"1.0\">
"
    set level 0
    foreach {k v} $args {
	switch $k {
	    "-experiment" {
		set v [string toupper $v]
		append pdbXML "<queryRefinement>
<queryRefinementLevel>$level</queryRefinementLevel>"
		if {$level > 0} {
		    append pdbXML "  <conjunctionType>and</conjunctionType>
"
		}
		append pdbXML "    <orgPdbQuery>
<version>head</version>
<queryType>org.pdb.query.simple.ExpTypeQuery</queryType>
<mvStructure.expMethod.value>$v</mvStructure.expMethod.value>
</orgPdbQuery>
</queryRefinement>
"	    }
	    "-organism" {
		append pdbXML "<queryRefinement>
<queryRefinementLevel>$level</queryRefinementLevel>"
		if {$level > 0} {
		    append pdbXML "  <conjunctionType>and</conjunctionType>
"
		}
		append pdbXML "    <orgPdbQuery>
<version>head</version>
<queryType>org.pdb.query.simple.TreeEntityQuery</queryType>
<t>1</t>
<n>$v</n>
</orgPdbQuery>
</queryRefinement>"

	    }
	    "-identity" {
		if {$v > 100 || $v <= 0} {
		    continue
		}
		append pdbXML "<queryRefinement>
<queryRefinementLevel>$level</queryRefinementLevel>
"
		if {$level > 0} {
		    append pdbXML "  <conjunctionType>and</conjunctionType>
"
		}
		append pdbXML "<orgPdbQuery>
<version>head</version>
<queryType>org.pdb.query.simple.HomologueEntityReductionQuery</queryType>
<queryId>null</queryId>
<identityCutoff>$v</identityCutoff>
</orgPdbQuery>
</queryRefinement>
"
	    }
	}
	incr level
    }
    append pdbXML "</orgPdbCompositeQuery>"

    set url "http://www.rcsb.org/pdb/rest/search"

    ::http::config -urlencoding utf-8
    set tok [::http::geturl $url -query $pdbXML -type "application/x-www-form-urlencoded"]
    set rep [::http::data $tok]
    ::http::cleanup $tok

    set Lrep [split $rep \n]
    set Lres {}
    foreach r $Lrep {
	lappend Lres [string range $r 0 3]
    }
    set Lres [lsort -unique $Lres]

    return $Lres
}


proc PDBSearch {{query ""}} {
    package require http
    set url "http://www.rcsb.org/pdb/rest/search"

    ::http::config -urlencoding utf-8
    set tok [::http::geturl $url -query $query -type "application/x-www-form-urlencoded"]
    set rep [::http::data $tok]
    puts ">> $rep"
    ::http::cleanup $tok

    #exit
}


proc tupref {} {
    global db

    set Lt [UniProtProteome 1]
    InitTaxDB

    puts "Lt0 [llength $Lt]"

    set tmp {}
    foreach t $Lt {
	if {$t ne ""} {lappend tmp $t}
    }
    set Lt [lsort -unique -integer $tmp]
    puts "Lt2 [llength $Lt]"

    puts "uniprot genomes contre gold complete"
    set Lo [$db eval "select taxid from sotol where isComp=1 and taxid in ([join $Lt ,]) group by taxid"]
    puts "overlap : [llength $Lo]"

    set Ld [$db eval "select Domaine,taxid from gold where taxid in ([join $Lt ,]) group by taxid"]
    set Lo {}
    set Lo [lmap {x y} $Ld {set x}]
    puts "[join [DenombreLaListe $Lo] \n]"

    puts "\nboucle sur taxid"
    set Lo {}
    foreach id $Lt {
	lappend Lo [$db eval {select Domaine from gold where taxid = $id limit 1}]
    }
    puts "\n gold :\n [join [DenombreLaListe $Lo] \n]"


    set Ll [$db eval "select Lineage from taxonomy where taxid in ([join $Lt ,])"]
    foreach l $Ll {
	set Lt [split $l ";"]
	lappend Lv [lindex $Lt 0]
    }
    puts "[join [DenombreLaListe $Lv] \n]"

    $db close

    exit
}

proc tgb {} {
    set res [DbFetchGET uniprot p12345]
    #puts "$res"

    set gb AAGW02052878
    set out [DbFetchGET genbank $gb]
    #puts $out

    set ref XM_002711551.2
    set out [eFetchREST nucleotide $ref]
    puts $out

    exit
}


proc tpq {} {
    #set Lres [PDBQuery -organism 9606 -method x-ray -return polymer_entity -identity 70]
    set Lres [PDBQuery -organism 83333 -method x-ray -return polymer_entity -identity 70]

    puts "[join $Lres \n]"
    puts "Lres [llength $Lres]"

    set Luni [lmap x $Lres {string range $x 0 3}]
    puts "Luni [llength [lsort -unique $Luni]]"
    exit
}


proc InitIDMapping {} {
    global TIDMap

    if {[info exists TIDMap]} {
	return
    }

    set Ll [LesLignesDuFichier [file join $::OrdSrcDir idmapping.txt]]
    set TIDMap(Lcat) {}
    set TIDMap(Ldbs) {}
    set TIDMap(Lids) {}
    foreach l $Ll {
	set l [string trim $l]
	if {[string index $l 0] eq "#" || $l eq ""} {
	    continue
	}
	if {[string range $l 0 8] eq "Category:"} {
	    set cat [string range $l 9 end]
	    lappend TIDMap(Lcat) $cat
	    set TIDMap($cat) {}

	    continue
	}
	set Lv [split $l \t]
	lassign $Lv name id sens
	lappend TIDMap($cat) $name
	lappend TIDMap(Ldbs) $name
	lappend TIDMap(Lids) $id
	set TIDMap($name,ID) $id
	set TIDMap($name,sens) $sens
    }

    return
}


proc HelpIDMapping {{args {}} } {
    global TIDMap

    InitIDMapping

    puts "\nIDMapping :"
    puts "-----------"
    puts "\nIDMapping is a tool that convert a list of IDs from/to a database from/to UniProt database. Below is the list of available databases, with their abbreviation :"

    set lgtName [PlusLongEltDe $TIDMap(Ldbs)]
    foreach key [array names TIDMap "*,ID"] {
	lappend LID $TIDMap($key)
    }
    set lgtID [PlusLongEltDe $LID]
    set fmt "%-${lgtName}s %-${lgtID}s %4s"
    foreach cat $TIDMap(Lcat) {
	puts "\nCategory : $cat"
	foreach db $TIDMap($cat) {
	    puts [format $fmt $db $TIDMap($db,ID) $TIDMap($db,sens)]
	}
    }
    puts ""
    puts "Usage :"
    puts "IDMapping <abbrev. for FROM database> <abbrv. for TO database> <list of IDs>"
    puts "\nNote : As this tool converts FROM/TO UniProt database,
\t- FROM should be one of ACC+ID, ACC, ID
OR
\t- TO   should be one of ACC or ID
"

    exit
}


proc tdbid {} {
    # see :
    # http://www.uniprot.org/help/programmatic_access#id_mapping_examples    set Ldb "

    set Ll [LesLignesDuFichier [file join $::OrdSrcDir dbid]]
    foreach l $Ll {
	set Lv [split $l \t]
	if {[llength $Lv] > 2} {
	    lassign $Lv tmp abb sens
	    switch $sens {
		"both" {
		    lappend Lto $abb
		    lappend Lfrom $abb
		}
		"from" {
		    lappend Lfrom $abb
		}
		"to" {
		    lappend Lto $abb
		}
	    }
	}
    }
    puts "from:\n$Lfrom"
    puts "\nto:\n$Lto"
    puts "\n[lor $Lfrom $Lto]"

    exit

}

proc tprosite {} {
    #http://prosite.expasy.org/cgi-bin/prosite/PSScan.cgi?seq=sydc_human&output=xml
    set url "http://prosite.expasy.org/cgi-bin/prosite/PSScan.cgi"
    set Lseq [list SYAC_HUMAN SYDM_YEAST titin_human]
    set sseq [join $Lseq \n]
    set que [http::formatQuery seq $sseq output json]
    puts "Query\n$que"
    set res [HttpCopy $url "" $que]
    puts "$res"

    package require json
    set dres [::json::json2dict $res]
    dict for {k v} $dres {puts "$k $v"}
    set val [dict get $dres matchset]
    foreach e $val {
	puts "e= $e\n"
	foreach {k v} $e {
	    puts "\t$k $v"
	}
    }

    exit
}


proc tpfm {} {
    if {0} {
	set res [PfamScanWebService]
	set res [join $res " "]
	puts "\n$res\n"

	source ~/json-procs.tcl
	set out [::util::json::parse $res]
	#puts "$out"
	#exit


	package require json
	set dres [::json::json2dict $res]
	#set dres $out
	puts ""
	puts "out [llength $out] dres [llength $dres]"
	puts "out\n[lindex $out 0]"
	puts "dres\n[lindex $dres 0]"
    } else {
	# tcllib
	set dres [ContenuDuFichier dres.json]
	# json-procs.tcl (OpenACS)
	set out [ContenuDuFichier out.json]
    }

    if {0} {
	set o [open "dres.json" w]
	puts $o $dres
	close $o
	set o [open "out.json" w]
	puts $o $out
	close $o
	exit
    }

    foreach t {0 1} {
	if {$t == 0} {
	    set json $out
	} else {
	    set json $dres
	}

	puts ""
	puts "KEYS:\n[dict keys $json]"
	puts ""
	puts "[llength $json]"
	puts [lindex $json 1]
    }

    # dres
    foreach dict $dres {
	dict for {k v} $dict {
	    puts "$k $v"
	}
	puts ""
    }

    exit
    puts "[dict get $dres seq]"
    exit
    set val [dict get $dres matchset]
    foreach e $val {
	puts "e= $e\n"
	foreach {k v} $e {
	    puts "\t$k $v"
	}
    }
    exit
}


proc EBIWebService {baseUrl query} {
    set urlrun "$baseUrl/run/"
    set ok [HttpCopy $urlrun jobid $query]
    if {! $ok} {
	puts "Error sending EBI run request !"
	return ""
    }

    # get job status
    set urlstatus "$baseUrl/status/$jobid"
    set status "RUNNING"
    while {$status eq "RUNNING"} {
	set ok [HttpCopy $urlstatus status]
	if {! $ok} {
	    puts "Error getting EBI job status !"
	    return ""
	} elseif {$status eq "RUNNING"} {
	    after 5000
	}
    }
    if {$status ne "FINISHED"} {
	puts "Error ! EBI job status $status !"
	return ""
    }

    # get results
    set urlresult "$baseUrl/result/$jobid/out"
    set ok [HttpCopy $urlresult result]
    if {! $ok} {
	puts "Error getting EBI job restults !"
	return ""
    }

    return "[join $result " "]"
}


proc PfamScanWebService {args} {
    set Lquery {}
    set YaFormat 0 ; set YaEmail 0
    foreach {k v} $args {
	switch $k {
	    "-sequence" {
		lappend Lquery sequence "$v"
	    }
	    "-format" {
		lappend Lquery format $v
		set YaFormat 1
	    }
	}
    }
    if {! $YaFormat} {
	lappend Lquery format json
    }
    if {! $YaEmail} {
	lappend Lquery email "luc.moulinier@laposte.net"
    }
    set query [::http::formatQuery {*}$Lquery]
    set baseUrl "http://www.ebi.ac.uk/Tools/services/rest/pfamscan/"

    return [EBIWebService $baseUrl $query]
}


proc PfamWebService {id} {
    set url "http://pfam.xfam.org/protein?entry=$id&output=xml"
    set ok [HttpCopy $url result]
    if {$ok} {
	return "[join $res \n]"
    } else {
	return ""
    }
}


proc InterproScanWebService {args} {
    set Lquery {}
    set YaEmail 0
    foreach {k v} $args {
	switch $k {
	    "-sequence" {
		lappend Lquery sequence $v
	    }
	    "-appl" {

	    }
	    "-goterms" {
		if {! [string is boolean $v]} {
		    puts "Bad value for -goterms !\nShould be a boolean."
		    continue
		}
		lappend Lquery goterms $v
	    }
	    "-pathways" {
		if {! [string is boolean $v]} {
		    puts "Bad value for -pathways !\nShould be a boolean !"
		    continue
		}
		lappend Lquery pathways $v
	    }
	    "-title" {
		lappend Lquery title $v
	    }
	    "-email" {
		lappend Lquery email $v
		set YaEmail 1
	    }
	}
    }
    if {! $YaEmail} {
	lappend Lquery email luc.moulinier@laposte.net
    }
    set query [::http::formatQuery {*}$Lquery]

    set baseUrl "http://www.ebi.ac.uk/Tools/services/rest/iprscan5"

    return [EBIWebService $baseUrl $query]
}


proc PrositeWebService {args} {
    # see :
    # http://prosite.expasy.org/scanprosite/scanprosite_doc.html
    # for information
    #

    if {[llength $args] == 0 || [regexp -nocase "help" $args]} {
	PrositeWebServiceHelp

	return
    }

    if {([llength $args] % 2)} {
	puts "Wrong number of arguments !\nShould be key-value pairs or 'help'"

	return
    }

    # re-order args. puts '-seq' or '-sig' first
    foreach key {"-seq" "-sig"} {
	if {[set ix [lsearch $args $key]] > -1} {
	    set val [lindex $args $ix+1]
	    set args [lreplace $args $ix $ix+1]
	    set args [linsert $args 0 $key $val]
	}
    }

    set Lquery {}
    set YaSeq 0 ; set YaDB 0 ; set yaSig 0 ; set YaOutput 0
    foreach {key value} $args {
	switch $key {
	    "-seq" {
		if {[string is list $value]} {
		    set value [join $value "\n"]
		}
		lappend Lquery seq $value
		set YaSeq 1
	    }
	    "-sig" {
		if {[string is list $value]} {
		    set value [join $value ,]
		}
		lappend Lquery sig $value
		set yaSig 1
	    }
	    "-output" {
		set value [string tolower $value]
		if {0 && $value ni {"xml" "json" "txt"}} {
		    puts "Bad output value !\nShould be XML, JSON or TXT"
		    return
		}
		lappend Lquery output $value
		set YaOutput 1
	    }
	    "-db" {
		set value [string tolower $value]
		if {$value ni {"tr" "pdb" "sp"}} {
		    puts "\nBad value for 'db'nShould be one of 'sp', 'tr' or 'pdb'. you can specify more than one database by assigning several 'db' keys"

		    return
		}
		lappend Lquery db $value
		set YaDB 1
		lappend dbs $value
	    }
	    "-varsplit" {
		if {! $YaDB} {
		    continue
		}
		if {'sp' ni $dbs || 'tr' ni $dbs} {
		    continue
		}
		if {! [string is boolean $value]} {
		    puts "\nBad value for -varsplic option.\nMust be a boolean"

		    return
		}
		lappend Lquery varsplic $value
	    }
	    "-lineage" {
		if {! $YaDB} {
		    continue
		}
		if {'sp' ni $dbs || 'tr' ni $dbs} {
		    continue
		}
		if {[string is list $value]} {
		    set value [join $value ;]
		}
		lappend Lquery lineage $value
	    }
	    "-skip" {
		if {$YaSeq && ! $YaSig} {
		    if {! [string is boolean $value]} {
			puts "Bad value for -skip option !\nShould be a boolean"

			return
		    }
		    lappend Lquery skip $value
		}
	    }
	    "-noprofile" {
		if {$YaSeq && ! $YaSig} {
		    if {! [string is boolean $value]} {
			puts "Bad value for -noprofile option !\nShould be a boolean"

			return
		    }
		    lappend Lquery noprofile $value
		}
	    }
	    "-max_x" {
		if {$YaSig} {
		    if {! [string is integer $value] || $value == 0} {
			puts "Bad value ofr -max_x option.\nShould be an integer > 0"

			return
		    }
		}
	    }
	    "-lowscore" {
		if {! [string is boolean $value]} {
		    puts "Bad value for -lowscore option.\nShould be a boolean."
		    return
		}
		lappend Lquery lowscore $value
	    }
	    "-minhits" {
		if {$YaSig && $YaDB} {
		    if {! [string is integer $value] || $value == 0} {
			puts "Bad value for -minhits option\nShould be integer > 0"

			return
		    }
		    lappend Lquery minhits $value
		}
	    }
	}
    }

    # check incompatibilites
    if {$YaSeq && $YaDB} {
	puts "\nYou can't specify both 'seq' and 'db'"
	return
    }
    if {! $YaOutput} {
	lappend Lquery output json
    }

    set query [http::formatQuery {*}$Lquery]
    #puts "Query\n$que"

    set url "http://prosite.expasy.org/cgi-bin/prosite/PSScan.cgi"
    set result [HttpCopy $url "" $query]
    #puts "$result"

    return $result
}


proc PrositeWebServiceHelp {} {
    puts "\nAllowed parameters :"
    puts "--------------------"
    puts "\n -seq :"
    puts "\t Sequence(s) to be scanned: UniProtKB accessions e.g. P98073 or identifiers e.g. ENTK_HUMAN or PDB identifiers e.g. 4DGJ or sequences in FASTA format or UniProtKB/Swiss-Prot format."
    puts "\n -sig :"
    puts "\t Motif(s) to scan against: PROSITE accession e.g. PS50240 or identifier e.g. TRYPSIN_DOM or your own pattern e.g. P-x(2)-G-E-S-G(2)-\[AS\]."
    puts "\t Default : all PROSITE motifs are used."
    puts "\n -db :"
    puts "\t Target protein database for scans of motifs against whole protein databases: 'sp' (UniProtKB/Swiss-Prot) or 'tr' (UniProtKB/TrEMBL) or 'pdb' (PDB)."
    puts "\t Only work if 'seq' is not defined. Parameter can be repeated; 1 target db by 'db' parameter."
    puts "\n -varsplic :"
    puts "\t If true (defined, non empty, non zero): includes UniProtKB/Swiss-Prot splice variants."
    puts "\t Only works on scans against UniProtKB/Swiss-Prot."
    puts "\n -lineage :"
    puts "\t Any taxonomical term e.g. 'Homo sapiens', e.g. 'Fungi; Arthropoda' or corresponding NCBI TaxID e.g. 9606, e.g. '4751; 6656'"
    puts "\t Separate multiple terms with a semicolon."
    puts "\t Only works on scans against UniProtKB/Swiss-Prot and UniProtKB/TrEMBL."
    puts "\n -description :"
    puts "\t Description (DE) filter: e.g. protease."
    puts "\t Only works on scans against UniProtKB/Swiss-Prot and UniProtKB/TrEMBL."
    puts "\n -max_x :"
    puts "\t Number of X characters in a scanned sequence that can be matched by a conserved position in a pattern."
    puts "\t Only works if 'sig' is defined, i.e. on scans of specific sequences/protein database(s) against specific motif(s)."
    puts "\t Only works on scans against patterns."
    puts "\n -output :"
    puts "\t Output format: 'xml' or 'json' (or 'txt')"
    puts "\n -skip :"
    puts "\t If true (defined, non empty, non zero): excludes motifs with a high probability of occurrence."
    puts "\t Default: ON."
    puts "\t Only works if 'seq' is defined and 'sig' is not defined, i.e. on scans of specific sequence(s) against all PROSITE motifs."
    puts "\n -lowscore :"
    puts "\t If true (defined, non empty, non zero): shows matches with low level scores."
    puts "\t Default: OFF."
    puts "\t Only works with PROSITE profiles."
    puts "\n -noprofile :"
    puts "\t If true (defined, non empty, non zero): does not scan against profiles."
    puts "\t Only works if 'seq' is defined and 'sig' is not defined, i.e. on scans of specific sequence(s) against all PROSITE motifs."
    puts "\n -minhits :"
    puts "\t Mimimal number of hits per matched sequences."
    puts "\t Only works if 'sig' and 'db' are defined, i.e. on scans of protein database(s) against specific motif(s)."

    exit
}


proc AskPrositeScan {Lseq} {
    set result [PrositeWebService -seq $Lseq]

    package require json
    set dres [::json::json2dict $result]
    set val [dict get $dres matchset]
    set i 1
    foreach e $val {
	foreach {k v} $e {
	    set Tres($i,$k) $v
	    #puts "\t$k $v"
	}
	incr i
    }

    return [array get Tres]
}


proc tpws {} {
    set Lseq [list SYAC_HUMAN SYDM_YEAST titin_human]
    set Lseq ">tototo
ACDFGILHDLMVPASKDELMSTACCEQLMIV"

    set res [PrositeWebService -seq $Lseq]
    puts $res
    exit
}


proc LaunchPfamScan {n s} {
    global Rpfm

    set seq ">$n
$s
"
    set Rpfm($n) [PfamScanWebService -seq $seq]

    return
}


proc TraitePfamScanResult {a b op} {
    set res $::Rpfm($b)

    if {$res eq ""} {
	set ::Rpfm($b,feat) ""
	return
    }

    package require json
    set Ldict [::json::json2dict $res]

    foreach dict $Ldict {
	set name [dict get $dict name]
	set desc [dict get $dict desc]
	set desc [string map {" " "_"} $desc]
	set acc  [dict get $dict acc]
	if {! [info exists ::Rpfm($acc)]} {
	    incr ::Rpfam(num)
	    set ::Rpfm($acc) $::Rpfm(num)
	}
	set color $::Rpfm($acc)
	set seq  [dict get $dict seq]
	lassign $seq tmp to tmp from
	lappend ::Rpfm($b,feat) [list $from $to $color "${acc}_$desc"]
    }

    exit
    return
}


proc AnnotePfam {} {
    global LNOrdali LSOrdali Rpfm

    foreach n $LNOrdali s $LSOrdali {
	if {[string trim $n] eq ""} {
	    continue
	}

	set s [string map {"." ""} $s]
	trace add variable Rpfm($n) write TraitePfamScanResult
	set Rpfm($n,id) [after idle "LaunchPfamScan $n $s"]
    }

    puts "Rpfm"
    foreach k [array names ::Rpfm] {
	puts "$k $::Rpfm($k)"
    }

    return
}


proc CreatePfamFeature {} {
    set csys  "local"
    set score 0.0
    foreach k [array names ::Rpfm "*,feat"] {
	lassign [split $k ,] sqn tmp
	foreach feat $::Rpfm($k) {
	    lassign $feat from to color note
	    lappend TFtmp(${sqn},"PFAM-A") [list fstart $from fstop $to fcolor $color fscore $score fnote $note fcsys $csys]
	}
    }
}


proc tews {} {
    global LNOrdali Sequences TDesAccess

    set Lseq {}
    set prend 1 ; set i 0
    foreach n $LNOrdali {
	if {[string trim $n] eq ""} {continue}

	set s [set Sequences($n)]
	set s [string map {"." ""} $s]
	set acc [set TDesAccess($n)]
	lappend Lseq ">$acc"
	#lappend Lseq "MQRASMHNST${s}FWSQAERMPMTK"
	lappend Lseq "MTRASTFASPMLINQ$s"
	#lappend Lseq ""

	incr i
	if {$i == $prend} {
	    break
	}
    }
    set seq "[join $Lseq \n]"
    puts ">$seq<"

    set time [time {set res [InterproScanWebService -sequence $seq]}]
    puts "time $time"
    #puts "$res"
    exit
}

proc GOEnrichmentWebService {Lids} {
    package require http
    set url "http://david.abcc.ncifcrf.gov/api.jsp?"

    set Largs {}

    set tool "chartReport"
    lappend Largs "tool=$tool"

    set type "UNIPROT_ID"
    set type "UNIPROT_ID"
    lappend Largs "type=$type"

    set annot "GOTERM_BP_ALL,GOTERM_CC_ALL,GOTERM_MF_ALL"
    lappend Largs "annot=$annot"

    set sid [join $Lids ,]
    lappend Largs "ids=$sid"

    set args [join $Largs "&"]
    append url "$args"
    puts "$url"
    if {[string length $url] > 2048} {
	puts "url length [string length $url]"
	exit
    }

    set res [HttpCopy $url]

    return $res
}


proc tgoe {} {
    set Ll [LesLignesDuFichier mmaic/sel0_70..acc]

    set res [GOEnrichmentWebService [lrange $Ll 0 100]]
    puts "$res"
    exit
}


proc EnrichrWebService {Lids} {
    package require json

    set baseUrl "http://amp.pharm.mssm.edu/"

    # add list
    set url "$baseUrl/Enrichr/addList"
    set sid [join $Lids "\n"]
    set query [::http::formatQuery list $sid]
    set ok [HttpCopy $url result $query]
    if {! $ok} {
	puts "Error submitting list to Enrichr!"
	return ""
    }
    # result is json
    set result [join $result " "]
    set dict [::json::json2dict $result]
    set jobid [dict get $result userListId]

    # check job
    set url "$baseUrl/Enrichr/enrich?userListId=$jobid&background=GO_Biological_Process_2015"
    set ok [HttpCopy $url result]
    if {! ok} {
	puts "Error getting Enrichr results !"
	return ""
    }
}


# MAFFT shipped in bin/mafft-<platform> : "" when there is none for this machine
proc MafftLivre {} {
    global OrdBinDir

    if {! [info exists OrdBinDir]} {
	return ""
    }

    package require platform
    set platform [::platform::generic]
    switch $platform {
	"linux-x86_64" {set prog mafft}
	"macosx-arm" {set prog [file join bin mafft]}
	"win32-x86_64" {set prog mafft.bat}
	default {return ""}
    }

    set exe [file join $OrdBinDir mafft-$platform $prog]
    if {! [file executable $exe] || ! [file isdirectory [MafftBinaires $exe]]} {
	return ""
    }

    return $exe
}


# directory of the MAFFT programs (MAFFT_BINARIES) beside the script exe :
# libexec for the Linux script, ../libexec/mafft for the macOS one (installed
# tree : bin/mafft, libexec/mafft), usr/lib/mafft in the Windows package
proc MafftBinaires {exe} {
    set d [file dirname $exe]
    if {[string match -nocase *.bat $exe]} {
	return [file join $d usr lib mafft]
    }
    if {[file tail $d] eq "bin"} {
	return [file join [file dirname $d] libexec mafft]
    }

    return [file join $d libexec]
}


# runs MAFFT with arguments args, alignment in fout, messages in flog.
# The shipped one is run directly (no bash on Windows : mafft.bat runs its
# own), otherwise the one of the CSTB through bash. Returns 1 on error.
proc MafftLance {fout flog args} {
    set exe [MafftLivre]
    if {$exe eq ""} {
	set cmd "module load msa/mafft ; mafft"
	foreach a $args {
	    append cmd " '$a'"
	}
	return [catch {exec bash -c "$cmd > '$fout' 2> '$flog'"}]
    }

    # the Unix script needs MAFFT_BINARIES ; mafft.bat sets it itself
    # (/usr/lib/mafft, seen by its own bash) and would override ours
    set avant [expr {[info exists ::env(MAFFT_BINARIES)] ? [list $::env(MAFFT_BINARIES)] : ""}]
    if {! [string match -nocase *.bat $exe]} {
	set ::env(MAFFT_BINARIES) [MafftBinaires $exe]
    }
    set pb [catch {exec $exe {*}$args > $fout 2> $flog}]
    if {$avant eq ""} {
	unset -nocomplain ::env(MAFFT_BINARIES)
    } else {
	set ::env(MAFFT_BINARIES) [lindex $avant 0]
    }

    return $pb
}


# temporary file names for one MAFFT run, in TempFolder
proc MafftFichiersTemp {args} {
    set id "[pid]_[clock milliseconds]"
    set Lf {}
    foreach n $args {
	lappend Lf [file join [TempFolder] "mafft_${n}_$id.tfa"]
    }

    return $Lf
}


# writes sequences s (list of lines, or text) in file f, Unix line ends
proc MafftEcrit {f s} {
    if {[string first "\n" $s] == -1 && [llength $s] > 1} {
	set s [join $s \n]
    }
    set o [open $f w]
    fconfigure $o -translation lf
    puts $o $s
    close $o

    return
}


# result of a MAFFT run : list of lines, or "" (messages printed) on error
proc MafftResultat {nout nlog msg} {
    set res ""
    if {[file exists $nout]} {
	set res [ContenuDuFichier $nout]
    }
    if {[string index $res 0] eq ">"} {
	return [split $res \n]
    }

    puts "\n$msg"
    if {[file exists $nlog]} {
	puts "\nMsg:\n[ContenuDuFichier $nlog]"
    }

    return ""
}


proc Mafft_AddSequences_local {fali fseqs} {
    lassign [MafftFichiersTemp ali seqs out log] nali nseqs nout nlog

    if {[file exists $fali]} {
	set nali $fali
    } else {
	MafftEcrit $nali $fali
    }
    if {[file exists $fseqs]} {
	set nseqs $fseqs
    } else {
	MafftEcrit $nseqs $fseqs
    }

    MafftLance $nout $nlog --add $nseqs $nali
    set res [MafftResultat $nout $nlog "Error in MAFFT !"]

    if {$nali ne $fali} {file delete $nali}
    if {$nseqs ne $fseqs} {file delete $nseqs}
    file delete $nout $nlog

    return $res
}


proc Mafft_AlignSequences_local {fseqs} {
    lassign [MafftFichiersTemp seqs out log] nseqs nout nlog

    if {[file exists $fseqs]} {
	set nseqs $fseqs
    } elseif {[llength $fseqs] <= 1 && [string first "\n" $fseqs] == -1} {
	puts "Error in Mafft ! Bad input sequences !"
	return ""
    } else {
	MafftEcrit $nseqs $fseqs
    }

    MafftLance $nout $nlog $nseqs
    set res [MafftResultat $nout $nlog "Error in MAFFT ! Can't align sequences"]

    if {$nseqs ne $fseqs} {file delete $nseqs}
    file delete $nout $nlog

    return $res
}


proc Mafft_AddSequences {fali fseqs} {
    if {[file exists $fali]} {
	set ali [ContenuDuFichier $fali]
    } elseif {[string first "\n" $fali] > -1} {
	set ali $fali
    } elseif {[llength $fali] > 1} {
	set ali [join $fali "\n"]
    }
    
    if {[file exists $fseqs]} {
	set add [ContenuDuFichier $fseqs]
    } elseif {[string first "\n" $fseqs] > -1} {
	set add $fseqs
    } elseif {[llength $fseqs] > 1} {
	set add [join $fseqs "\n"]
    }
    
    set url "http://ddbj.nig.ac.jp/wabi/mafft/"
    package require http
    set query [::http::formatQuery \
		   "format" "text" \
		   "querySequence" "$ali" \
		   "addSequence" "$add" \
		   "parameters" "--globalpair --maxiterate 1000" \
		   "result" "www"]

    array set hd {}
    package require TclCurl
    set ok [::curl::transfer -followlocation 1 -timeout 120 -post 1 -postfields $query -url "$url" -bodyvar res -header 1 -headervar hd]
    # curl::transfer send 0 as exit status if OK
    set ok [expr {! $ok}]
    set res [split $res "\n"]

    #set ok [HttpCopy $url res $query]
    #puts "ok  submit $ok"
    puts "res submit\n$res\n"

    if {! $ok} {
	puts "ERROR in Mafft_AddSequences !\nCannot send request to server\n"

	return ""
    }

    set ix [lsearch -regexp $res "requestId"]
    set id [lindex $res $ix]
    regsub -all { +} [string trim $id] " " id
    set id [lindex [split $id " "] 1]
    puts "id= >$id<"

    # check job status
    set urlStatus "$url${id}"
    while {1} {
	#set ok [HttpCopy $urlStatus res]
	set ok [curl::transfer -url $urlStatus -followlocation 1 -bodyvar res]
	set res [split $res \n]
	# curl::transfer -> 0 means OK
	set ok [expr {! $ok}]

	puts "ok status $ok"
	puts "res= \n$res"
	if {! $ok} {
	    puts "ERROR in Mafft_AddSequences !\nCannot retrieve job status !\n"

	    return ""
	}
	set istatus [lsearch -regexp $res {^status:}]
	set statusLine [lindex $res $istatus]
	regsub -all { +} [string trim $statusLine] " " statusLine
	set status [lindex [split $statusLine " "] end]
	puts "status $status"
	switch $status {
	    "waiting" -
	    "running" {after 2000}
	    "finished" {after 500 ; break}
	    default {
		puts "ERROR in Mafft_AddSequences !\nUnknown status : $status"

		return ""
	    }
	}
    }

    # Now get results
    set urlResult "$url${id}?info=result"
    #puts $urlResult
    set resR ""
    #set ok [HttpCopy $urlResult resR]
    set ok [curl::transfer -followlocation 1 -url $urlResult -bodyvar res]
    # curl::transfer = 0 means OK !
    set ok [expr {! $ok}]
    puts "ok result $ok"
    set res [split $res \n]
    #puts "res=\n>$res<"
    if {! $ok} {
	puts "ERROR in Mafft_AddSequences !\nCannot get results\n"

	return ""
    }

    return $res
}


proc Mafft_AlignSequences {fali} {
    if {[file exists $fali]} {
	set ali [ContenuDuFichier $fali]
    } elseif {[string first "\n" $fali] > -1} {
	set ali $fali
    } elseif {[llength $fali] > 1} {
	set ali [join $fali "\n"]
    }
    
    set url "http://ddbj.nig.ac.jp/wabi/mafft/"
    package require TclCurl
    package require http

    set query [::http::formatQuery \
		   "format" "text" \
		   "querySequence" "$ali" \
		   "parameters" "--globalpair --maxiterate 1000" \
		   "result" "www"]

    array set hd {}
    # curl::transfer send 0 as exit status if OK
    set ok [::curl::transfer -followlocation 1 -post 1 -postfields $query -url "$url" -bodyvar res -header 1 -headervar hd]
    set ok [expr {! $ok}]
    set res [split $res "\n"]
    
    #set ok [HttpCopy $url res $query]
    #puts "ok  submit $ok"
    #puts "res submit\n$res\n"
    
    if {! $ok} {
	puts "ERROR in Mafft_AlignSequences !\nCannot send request to server\n"
	
	return ""
    }
    
    set ix [lsearch -regexp $res "requestId"]
    set id [lindex $res $ix]
    regsub -all { +} [string trim $id] " " id
    set id [lindex [split $id " "] 1]
    #puts "id= >$id<"
    
    # check job status
    set urlStatus "$url${id}"
    while {1} {
	#set ok [HttpCopy $urlStatus res]
	set ok [curl::transfer -url $urlStatus -followlocation 1 -bodyvar res]
	set res [split $res \n]
	# curl::transfer -> 0 means OK
	set ok [expr {! $ok}]
	
	#puts "ok status $ok"
	#puts "res= \n$res"
	if {! $ok} {
	    puts "ERROR in Mafft_AlignSequences !\nCannot retrieve job status !\n"
	    
	    return ""
	}
	set istatus [lsearch -regexp $res {^status:}]
	set statusLine [lindex $res $istatus]
	regsub -all { +} [string trim $statusLine] " " statusLine
	set status [lindex [split $statusLine " "] end]
	#puts "status $status"
	switch $status {
	    "waiting" -
	    "running" {after 2000}
	    "finished" {after 500 ; break}
	    default {
		puts "ERROR in Mafft_AlignSequences !\nUnknown status : $status"
		
		return ""
	    }
	}
    }
    
    # Now get results
    set urlResult "$url${id}?info=result"
    #puts $urlResult
    set resR ""
    #set ok [HttpCopy $urlResult resR]
    set ok [curl::transfer -followlocation 1 -url $urlResult -bodyvar res]
    # curl::transfer = 0 means OK !
    set ok [expr {! $ok}]
    #puts "ok result $ok"
    set res [split $res \n]
    #puts "res=\n>$res<"
    if {! $ok} {
	puts "ERROR in Mafft_AlignSequences !\nCannot get results\n"
	
	return ""
    }
    
    return $res
}


proc tmaft {} {
    set out [Mafft_AddSequences_local mtest.tfa add.tfa]
    puts "\n\n\n$out"
    exit
}


proc AutoconfigurationProviderREST {domain} {

    return $aT
}


proc MailProviderConfigProcessXML {xml} {
    array set T {}

    set RId [dom parse $xml]
    set doc [$RId documentElement]
    foreach nd [$doc selectNodes //incomingServer] {
	set type [$nd getAttribute type "none"]
	set naddr [$nd selectNodes ./hostname]
	set addr [$naddr selectNode string(.)]
	set nport [$nd selectNodes ./port]
	set port [$nport selectNode string(.)]

	# check whether using SSL or not
	set nsock [$nd selectNodes ./socketType]
	if {$nsock ne ""} {
	    set sock [$nsock selectNode string(.)]
	    set T($type,socket) $sock
	}
	lappend T(Ltypes) $type
	set T($type,addr) $addr
	set T($type,port) $port
    }

    foreach nd [$doc selectNodes //outgoingServer] {
	set type [$nd getAttribute type "none"]
	set naddr [$nd selectNodes ./hostname]
	set addr [$naddr selectNode string(.)]
	set nport [$nd selectNodes ./port]
	set port [$nport selectNode string(.)]

	# check whether using SSL or not
	set nsock [$nd selectNodes ./socketType]
	if {$nsock ne ""} {
	    set sock [$nsock selectNode string(.)]
	    set T($type,socket) $sock
	}
	lappend T(Ltypes) $type
	set T($type,addr) $addr
	set T($type,port) $port
    }

    return [array get T]
}


proc tidw {} {
    LesDefauts IDMapping_web 0
    puts [IDMapping_sql ACC+ID GENENAME [list P12345 SYAC_MOUSE Q6PI48]]

    exit
}


proc tray {} {
    set gen [eSearchREST nucleotide "txid578454\[ORGN\] AND complete\[Title\] AND genome\[Title\]"]
    puts "Lid [llength $gen]"
    array set T [eSummaryREST genome $gen]
    parray T
    exit

    set taxid 578454
    set taxid 9606
    set Lid {TaxId 9606}
    set db nuccore

    array set Tx [eSummaryREST taxonomy $taxid]
    parray Tx
    set Name $Tx($taxid,ScientificName)
    puts ""

    set out [eSearchREST genome $Name]
    set Lid [split $out " "]
    puts [llength $Lid]
    array set T [eSummaryREST genome $Lid]
    parray T
    puts ""

    set Lgood {}
    foreach k [array names T *,TaxId] {
	if {$T($k) == $taxid} {
	    lappend Lgood [lindex [split $k ,] 0]
	}
    }
    puts "Lgood [llength $Lgood]"
    exit


    set url "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    set query [::http::formatQuery \
		   db $db \
		   retmax 1000 \
		   term "[join $Lid " AND "]"]
    set res [HttpCopy $url "" $query]
    puts $res
    exit



    set Lid [eSearchREST $db {TaxId 578454}]
    array set T [eSummaryREST $db $Lid]
    parray T

    set Lt {}
    foreach k [array names T *,TaxId] {
	if {$T($k) == $taxid} {
	    lappend Lt [lindex [split $k ,] 0]
	}
    }
    foreach id $Lt {
	foreach k [lsort [array names T $id,*]] {
	    puts "$k $T($k)"
	}
    }
    puts "[llength $Lt]"
    #parray T
    exit
}


proc tray2 {} {
    set Luni {I3KNL5_ORENI H2LGR1_ORYLA H3BWS4_TETNG M3ZXG4_XIPMA G3PU30_GASAC H2RIX7_TAKRU W5KXF3_ASTMX Q7ZZC6 H2ZZ79_LATCH M7C161_CHEMY K7G3L7_PELSI Q1T7B9 U3KB97_FICAL A4IHL0_XENTR H9H6M1_MONDO R4GBD2_ANOCA F7AST6_ORNAN V8NZ78_OPHHA G3WG31_SARHA C3Z7G6_BRAFL W4ZHQ6_STRPU K1QTP9_CRAGI A7RJL6_NEMVE H0VN74_CAVPO Q2TBH1 H2P4L0_PONAB H2QLT2_PANTR Q9NSP4 L5KB28_PTEAL D4AC25_RAT W5QBT9_SHEEP G5BPQ8_HETGA F7ECJ1_MACMU G7PFP3_MACFA G1NY56_MYOLU I3MK25_ICTTR G3TFQ1_LOXAF H0XBV4_OTOGA G1S0I1_NOMLE I3L7A5_PIG F6W0H3_HORSE E2RRU1_CANLF Q9CQA0 G1SUS8_RABIT M3WTJ5_FELCA M3YY48_MUSPF G1LS12_AILME S7MKY7_MYOBR S9XK50_CAMFR H9KVT0_CALJA}

    set out [DbFetchGET uniprot $Luni]
    set out [SplitLesEMBL $out]

    foreach e $out {
	EspionneL $e
    }

    exit
}

proc tweb {} {
    set Lid [list q5vz01 p12345 toto O35943 Q8HXX9 Q16595 Q9W385]
    set Lid {1il2 1e18}
    set Lid {Q621D3 Q5VZ01 Q4P635 Q4I9V2}

    set rep [IDMapping_web ACC+ID ACC $Lid]
    puts "\n>>$Lid<<"
    puts ">>$rep<<"

    exit
}


proc tp {} {
    array set T [eSummaryREST protein P03002]
    #parray T
    puts "\n\n"
    array set ttt [eSummaryREST protein P0AG32]
    #parray ttt
    #set out [eFetchREST protein P0AG32 gb]
    #puts "\n\n$out"
    set out [eFetchREST protein P0AG32 docsum]
    puts "\n\n$out"

    exit
}


proc tjson {} {
    package require TclCurl

    set url "https://rest.ensembl.org/lookup/id/ENSG00000157764?content-type=application/json;expand=1"
    #curl::transfer -url $url -bodyvar json

    set json [ContenuDuFichier exa.json]

    set json [encoding convertfrom utf-8 $json]
    puts "length0 [llength $json]"
    puts "$json"

    package require json 1.3.3
    set tout [::json::json2dict $json]

    source /home/moumou/json-procs.tcl
    set fout [::util::json::parse $json]

    if {$tout == $fout} {
	puts "ok"
	exit
    }

    puts "\ntout\n$tout\n"

    puts "len = [llength $tout]"
    puts "keys : [llength [dict keys $tout]] | [dict keys $tout]"
    puts "\ndict infos :\n[dict info $tout]"

    foreach {k v} $tout {
	puts "k= [llength $k] $k v= [llength $v] $v"
	while {[llength $v] > 1} {
	    set vin $v
	    foreach {k v} $vin {
		puts "\tk= $k | v= $v"
	    }
	}
    }

    return
}

proc tatta {} {

    FaireLire "Attention BICS est obsolete. Use Banbi"
    
    package require sqlite3
    
    set db root

    set rep /commun/bics/IDMapping/production/SQLDBS

    sqlite3 $db "$rep/GENE_NAME.sql" -readonly 1
    set dpdb "$rep/PDB.sql"
    set dbtax "$rep/NCBI_TAXID.sql"

    $db eval {attach database $dpdb as PDB}
    $db eval {attach $dbtax as NCBI_TAXID}

    set Lids {ASPS PHES WXY}

    set out [$db eval "select db1.id, db2.id from GENE_NAME as db1, PDB as db2, NCBI_TAXID as db3 where \
db1.id in ('[join $Lids ',']') and \
    db3.id = '83333' and \
    db1.acc = db2.acc and \
    db3.acc = db1.acc"]

foreach {i a} $out {
    lappend t($i) $a
}
foreach i $Lids {
    if {[info exists t($i)]} {
	puts $t($i)
    } else {
	puts ""
    }
}

exit
}




proc mm {} {
    array set t [eSummaryREST protein NP_001297087]
    parray t
    exit
}


# changer HttpCopy par
#  curl::transfer -nobody 1 -header 1 -headervar head_var -url $url

proc getlc {} {
    #set id NP_001297087
    set id XP_029851736.1
    #set Lt [eSummaryREST protein $id]
    #set Lt [eSummaryREST protein $id Length]
    set o [eFetchREST protein $id]
    DecortiqueGenBank "" "" "" $o "" "" "" ref
    puts $ref ; exit

    puts "$Lt" ; exit

    array set t $Lt
    foreach k [array names t] {
	lassign [split $k ,] tmp key
	lappend Lkey $key
    }
    parray t
    puts ""
    puts [join [lsort $Lkey] \n]
    puts ""

    set Lix [lsearch -all $Lt $id]
    foreach i $Lix {
	puts "[lindex $Lt $i-1] [lindex $Lt $i]"
    }
    #puts [join [lsearch -all -inline -nocase $Lt "geneid"] \n]


    exit
}


proc pl {} {

    FaireLire "Attention BICS est obsolete. Use Banbi"
    
    set Li [LesLignesDuFichier ~/l.txt]
    cd /commun/bics/IDMapping/production
    set Lrs [LesLignesDuFichier REFSEQ.dat]
    puts "file loaded"
    foreach id $Li {
	set id [string toupper [file rootname $id]]
	set o [lsearch -inline -all $Lrs $id]
	puts "$id $o"
    }

    return
}


proc pl2 {} {
    set Lid XP_029851736.1
    set Lid XP_001297087
    set l [eFetchREST protein $Lid]
    #puts $l ; exit

    DecortiqueGenBank "" "" "" $l "" "" "" ref

    puts "\ndb_xref : $ref"
    exit
}


proc tpl {} {
    #rR cd /commun/bics/IDMapping/production
    cd /commun/banbi/IDMapping/production

    set Lres {}
    foreach bk [ListOfAllIDMappingBanks] {
	set l [exec wc -l ${bk}.dat]
	lappend Lres $bk [lindex [split $l] 0]
    }

    set Lres [lsort -stride 2 -index 1 -integer -increasing $Lres]
    lmap {x y} $Lres {puts "$x $y"}

    exit
}

#SELECT * FROM VALUES((1),(2),(3)) t(searchid), table1 WHERE searchid = table1.id



#      gene_name  NCBI_TAXID    ACC2ACC        regseq
# Lids id -> acc   acc -> aTx  aTx -> aDash  aDash -> id
# |                          |
# |--------------------------|


proc nicma {} {
    set out [Mafft_AddSequences aspRS2.tfa Dcoli.tfa]
    puts "\n\n$out"

    exit
}
proc tcurl3 {} {
    package require http
    package require TclCurl

    FaireLire "Attention bics est obselete. Use BANBI"
    
    set url "http://www.lbgi.fr/\~moumou/bics/index.rvt"
    set query [::http::formatQuery from "ACC+ID" to ID ids P12345]

    ::curl::transfer -url "$url\?$query" -bodyvar rep
    puts $rep
    exit
}


proc dismoibg {args} {
    puts "\n=============="
    puts "$::errorInfo"
    puts "==============\n"

    return
}



proc tbg {} {
    LoadTkAndPackages
    update idletasks

    trace variable ::errorInfo w dismoibg

    
    button .b \
	-bg blue \
	-fg yellow \
	-text "Coucou !\nCa gazouille ?" \
	-font "Helvetica 52 bold" \
	-command prout
    pack .b

    raise .b
    FenetreAuCentre .

    tkwait window .b

    return
}

proc tdbf {} {
    package require http
    package require tls
    package require TclCurl

    set url "https://www.ebi.ac.uk/Tools/dbfetch/dbfetch"
    set query [::http::formatQuery db uniprot style "raw" id "P12345,P123456" ]
    
    ::curl::transfer -url $url -bodyvar out -post 1 -postfields $query
    puts $out
    
    exit
}

#-url https://www.ebi.ac.uk/Tools/dbfetch/dbfetch -followlocation 1 -bodyvar out -post 1 -postfields db=uniprot&style=raw&id=Q96B34,Q75MN2,O45815,Q6WG35,O76539,O17503,P60710,O97475,Q95UU0,P53486,Q6RUV6,Q6R5N6,P35432,Q9DDW1,Q9DF38,Q6P3K9,O61285,Q6P378,Q7ZVF9,Q6NVA9 -timeout 180

proc tarno3 {} {
    set id [IDMapping ACC+ID REFSEQ SYDC_YEAST]
    puts "new id : $id"

    array set T [eSummaryREST protein $id]
    parray T

    return
}


if {0} {
Dear RCSB,

There are about 4200 proteins in E. Coli, and the structure of some of them has been determined. I'd like to retrieve from the PDB the set of IDs representing the "structural proteome" of E. Coli, e.g. a unique ID for a given gene.

I'm using the new search API. 


}


proc testena {} {
    package require TclCurl

    set url "https://www.ebi.ac.uk/ena/browser/api/text/"

	set failed [::curl::transfer -url $url -followlocation 1 -bodyvar json]

    exit
}


proc fastmarie {id} {
    package require TclCurl
   exec curl  -o $id.fasta "https://rest.uniprot.org/uniprotkb/search?query=(uniref_cluster_50:$id)&format=fasta"

    exit


    return
}

# arrive le mans 20h59

