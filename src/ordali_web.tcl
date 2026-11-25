

#
# --- ordali_web.tcl
#


# ------------------------------------------------------------
# CommandeOuvreURL
#
# Command of the system that opens an URL (or a file) with the
# default browser, {} if there is none
# ------------------------------------------------------------
proc CommandeOuvreURL {} {
    global tcl_platform

    switch -- $tcl_platform(platform) {
        windows {
            # "start" is an internal command of cmd.exe
            return [auto_execok start]
        }
        unix {
            if {$tcl_platform(os) eq "Darwin"} {
                if {[auto_execok open] ne ""} {
                    return [list open]
                }
                return {}
            }
            # freedesktop (every desktop), GNOME/GLib, Debian/Ubuntu
            # alternatives
            foreach cmd {xdg-open {gio open} sensible-browser x-www-browser} {
                if {[auto_execok [lindex $cmd 0]] ne ""} {
                    return $cmd
                }
            }
            return {}
        }
    }

    return {}
}


# ------------------------------------------------------------
# browser_exists
#
# Check if the system is able to open URLs
# ------------------------------------------------------------
proc browser_exists {} {
    return [expr {[CommandeOuvreURL] ne {}}]
}

# ------------------------------------------------------------
# open_browser
#
# Open an URL in a browser set by default
# ------------------------------------------------------------
proc open_browser {url} {
    global tcl_platform

    set cmd [CommandeOuvreURL]
    if {$cmd eq {}} {
        error "No command to open an URL on this system"
    }
    if {$tcl_platform(platform) eq "windows"} {
        # cmd.exe would cut the command at a '&' ; "" : title of
        # the window, otherwise a quoted url would be taken as title
        set url [string map {& ^&} $url]
        exec {*}$cmd "" $url &
    } else {
        exec {*}$cmd $url &
    }

    return
}

# ------------------------------------------------------------
# OpenInBrowser
#
# Opens an URL or a file : with the command of the system, or
# else with a browser found by the browser_info package.
# 1 if launched
# ------------------------------------------------------------
proc OpenInBrowser {UrlOrFile} {
    if {[browser_exists] && ! [catch {open_browser $UrlOrFile}]} {
        return 1
    }
    if {[catch {package require browser_info} Msg]} {
        FaireLire "Cannot open a web browser :\n$Msg"
        return 0
    }

    return [OpenFileInBrowser $UrlOrFile]
}


proc httpCallback {token} {
    upvar #0 $token State
    # Access State as a Tcl array

    if {[info exists State(error)]} {
	return [set State(error)]
    } else {
	return "pasmarche"
    }
}


proc UrlFetch {url {Query ""} {Timeout 30}} {
    # Text of the page at url, "" if it can not be fetched.
    # Query (string returned by ::http::formatQuery) : sent by POST.
    # Follows the redirections, gives up after Timeout seconds.
    # Server errors (5xx) are tried 3 times. No answer (timeout,
    # no network) : not tried again, that would only be longer.
    set texte ""
    for {set essai 1} {$essai <= 3} {incr essai} {
	if {$essai > 1} {
	    after 2000
	    update
	}
	if {! [catch {package require TclCurl}]} {
	    # do not use curl::version : it crashes with recent libcurl
	    set Lopt [list -url $url -followlocation 1 -maxredirs 5 \
			  -connecttimeout 15 -timeout $Timeout \
			  -useragent "Ordalie" -bodyvar texte -infohttpcode ncode]
	    if {$Query ne ""} {
		lappend Lopt -post 1 -postfields $Query
	    }
	    set texte ""
	    set ncode 0
	    if {[catch {::curl::transfer {*}$Lopt} Msg]} {
		# Msg : libcurl error code (28 = timeout)
		catch {set Msg [::curl::easystrerror $Msg]}
		puts "UrlFetch $url : $Msg"
		return ""
	    }
	} else {
	    lassign [UrlFetchHttp $url $Query $Timeout] ncode texte
	    if {$ncode == 0} {
		return ""
	    }
	}
	if {$ncode >= 200 && $ncode < 300} {
	    return $texte
	}
	puts "UrlFetch $url : HTTP code $ncode"
	if {$ncode < 500} {
	    # bad request, not found ... : no use trying again
	    return ""
	}
    }

    return ""
}


proc UrlFetchHttp {url Query Timeout} {
    # used by UrlFetch when TclCurl is not available.
    # Returns {code text}, code 0 if no answer.
    package require http
    package require tls
    # no ::tls::init -tls1 : with OpenSSL 3 it breaks every
    # https connection ("failed to use socket")
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    for {set i 0} {$i < 5} {incr i} {
	set Lopt [list -timeout [expr {$Timeout*1000}]]
	if {$Query ne ""} {
	    lappend Lopt -query $Query
	}
	if {[catch {::http::geturl $url {*}$Lopt} token]} {
	    puts "UrlFetch $url : $token"
	    return [list 0 ""]
	}
	set status [::http::status $token]
	set ncode  [::http::ncode $token]
	set texte  [::http::data $token]
	set Location ""
	foreach {k v} [::http::meta $token] {
	    if {[string equal -nocase $k "location"]} {
		set Location [string trim $v]
	    }
	}
	::http::cleanup $token
	if {$status ne "ok"} {
	    puts "UrlFetch $url : $status"
	    return [list 0 ""]
	}
	if {$ncode < 300 || $ncode >= 400 || $Location eq ""} {
	    return [list $ncode $texte]
	}
	# redirection : relative location is relative to the server
	if {! [regexp {^https?://} $Location] && [regexp {^(https?://[^/]+)} $url -> Debut]} {
	    set Location "$Debut$Location"
	}
	set url $Location
	# 303 : the new location is read by GET
	if {$ncode == 303} {
	    set Query ""
	}
    }

    puts "UrlFetch $url : too many redirections"
    return [list 0 ""]
}


proc HttpCopy {url {aliste ""} {Query ""} {args {}}} {
    #rR si aliste est vide on return la liste sinon
    #rR on return 1 et la liste dans liste
    # Query : string returned by ::http::formatQuery (POST).
    # The page is fetched by UrlFetch (timeouts, redirections).
    # Returns "" (or 0 if aliste is given) if nothing is found.
    if {$aliste ne ""} {
	upvar $aliste liste
	set liste {}
    }

    set texte [UrlFetch $url $Query]
    update

    if {$aliste eq ""} {
	return $texte
    }
    if {$texte eq ""} {
	return 0
    }
    set liste [split $texte "\n"]

    return 1
}


proc HttpCopyVieuxDeMoumou {url {aliste ""}} {
    global Ntimes

    if {$aliste!=""} { upvar $aliste liste }

    if {[catch {::http::geturl $url} token]} {
	#puts "Error $url : bad url or no network"
	return 0
    }

    upvar #0 $token state

    unset token

    set liste [split $state(body) "\n"]

    foreach {name value} $state(meta) {
	if {[regexp -nocase ^location$ $name]} {
	    if {! [info exists Ntimes]} {
		set Ntimes 1
	    } else {
		if {$Ntimes < 5} {
		    incr Ntimes
		} else {
		    return 0
		}
	    }
	    # Handle URL redirects
	    puts "Location: $value"
	    unset state
	    return [HttpCopy [string trim $value] liste]
	}
    }

    unset state
    #    return 1
    #rR prefererait liste au lieu de 1
    return $liste
}


proc HttpProgress {args} {
    puts -nonewline stderr . ; flush stderr

    return
}

proc HttpGetTextFromUrl Url {
    set token [::http::geturl $Url -timeout 1000000]
    upvar #0 $token State
    ::http::cleanup $token
    unset token

    return $State(body)
}

proc RecupereUnFichierSurWeb {molid {url ""} {bnk ""}} {
    global Defauts

    if {! [info exists Defauts]} {LesDefauts}

    if {$url ne ""} {
	set site "UNK"
	set molid ""
	set bnk ""
    } else {
	if {[EstUnAccessPDB $molid]} {
	    set site "Pdb"
	    set bnk "pdb"
	    #set Motor "Hoan"
	    set Motor "World"
	} elseif {$bnk eq ""} {
	    set site "SRS"
	    set bnk "protein"
	    set Motor "Hoan"
	} else {
	    set site "SRS"
	    set bnk $bnk
	    set Motor "Hoan"
	}
	set url [set Defauts(Url${site}${Motor})]
    }

    if {[set ix [string first ":" $molid]] != -1} {
	set molid [string range $molid $ix+1 end]
    }
    set molid [DonneIdDeAccessPDB $molid]

    set Leslignes {}
    regsub -all "XXXX" $url $molid url
    regsub -all "YYYY" $url $bnk   url
    
    HttpCopy $url Leslignes

    if {$site eq "UNK"} {return $Leslignes}

    if {$site eq "SRS"} {
	if {$Motor eq "World"} {
	    set TexteHTML [join $Leslignes "\n"]
	    set Texte [ValeurDeLaBalise "pre" TexteHTML]
	    set Leslignes [split $Texte "\n"]
	}
    }

    set head [string range [lindex $Leslignes 0] 0 1]
    set tail [string range [lindex $Leslignes end] 0 2]
    if { ($site eq "SRS" && $head ne "ID") || ($site eq "Pdb" && $head ne "HE" && $tail ne "END")} {
	set Leslignes {}
	regsub -all "XXXX" [set Defauts(Url${site}World)] $molid url

	if {$site eq "SRS"} {
	    ::http::config -urlencoding iso8859-1
	}

	HttpCopy $url Leslignes

	if {$site eq "SRS"} {
	    set TexteHTML [join $Leslignes "\n"]
	    set Texte [ValeurDeLaBalise "pre" TexteHTML]
	    set Leslignes [split $Texte "\n"]
	}

	set head [string range [lindex $Leslignes 0] 0 1]
	if { $head ne "HE" && $head ne "ID"} {
	    set Leslignes "ERREUR"
	    if {$site eq "Pdb"} {
		if {[file exists "${molid}.pdb"]} {
		    set Leslignes [LesLignesDuFichier "${molid}.pdb"]
		    set head "[string range [lindex $Leslignes 0] 0 1]"
		    if { $head ne "HE"} {set Leslignes "ERREUR"}
		}
	    }
	}
    }

    return $Leslignes
}


proc thc111 {} {
    set Lid [list NM_123]
    set res [eFetchREST nucleotide $Lid cds]
    puts "$res"
    exit
}

if {0} {
Réf 68738516
commande 468955
no client 58560505

03 67 07 70 94
}

proc thc222 {} {
    set query [::http::formatQuery \
		   db uniprot \
		   id Q07930 \
		   style raw]
    puts "[HttpCopy http://www.ebi.ac.uk/Tools/dbfetch/dbfetch? "" $query]"
    exit
    puts [HttpCopy "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch?db\=uniprot\&id\=Q07930\&style=raw"
	  ]
    exit
}


proc tlurl {} {
    set Ll [LesLignesDuFichier lurl]
    foreach l $Ll {
	lassign [split $l " "] tmp url tmp query
	set res [HttpCopy $url "" $query]
    }

    exit
}

