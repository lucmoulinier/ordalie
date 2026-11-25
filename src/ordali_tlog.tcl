
#
# --- ordali_tlog.tcl
#

# format tlog :
# ------------
#
# - Toute commande tlog commence par une @
# - Toute ligne commancant par # est un commentaire
# - Toute ligne de blanc ou vide est skippee
#
# liste commandes :
# -----------------
#
# @begin <what> : debut de what
#     - table
#     - tabular
#     - list
#     - warning
# - teletype : 
#     - blob (various data)
# @end : end du dernier what defini
# @title : ligne de titre
# @Subtitle : ligne de sous-titre
# @text : simple text
# @tele : simple text without vertical spacing
# ATTENTION : AuLog transforme tous les \n en AlALiGNe
# --> il faut les re-transformer en \n ici
# @TagID : une string de la derniere commande
# @html : a inserer tel quel si on sort de l'html.
# @css : css definition
# @titlerows : liste des entetes de lignes
# @titlecols : liste des titres de columns
# @typecols : types of each column
# - I int, R real, T text, G imaGe, ou
# - attribut de balise (cle=valeur)
# @row : liste des valeurs d'une ligne 
# @col : liste des valeurs d'une columne
# @list : Tcl list
# @listBR : Tcl list to be included joined by <br>
# @pre texte type courier
# @separator : cree une ligne

proc ParseTLog {Log} {
    global TbLog

    unset -nocomplain TbLog
    set TbLog(DoTOC) 1
    set TbLog(LElt) {}

    ParseTLogLines $Log
    array unset TbLog "*Pile"

    return
}


proc ParseTLogLines {Log {id ""}} {
    global TbLog

    foreach l $Log {
	#set l [string trim $l]
	if {$l eq ""} {
	    continue
	}

	#set l [string map {AlALiGNe "\n" " {" " \{" "} " "\} "} $l]
	#set sreste [string trim [string range $l [string first " " $l]+1 end]]
	#set sreste [join [lrange $l 1 end]]
	set sreste [lrange $l 1 end]
	switch -regexp -- $l {
	    {^\#} {
		continue
	    }
	    {^\@begin} {
		set what [lindex $l 1]
		set n [incr TbLog(i[string totitle $what])]
		set it "${what}_$n"
		if {$what eq "tabular"} {
		    set TbLog($it,TitleCols) ""
		    set TbLog($it,TypeCols) ""
		}
		
		lappend TbLog(${id}LElt) $it
		if {$id ne ""} {
		    set id "${id}$it,"
		} else {
		    set id "$it,"
		}
		set TbLog(${id}Id) $it
	    }
	    {^\@end} {
		set id [join [lrange [split $id ,] 0 end-2] ,]
		if {$id ne ""} {
		    set id "$id,"
		}
		#puts "--> end $id"
	    }
	    {^\@title } {
		set it "title_[incr TbLog(iTitle)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) "$it"
		set TbLog(${id}$it,Title) $sreste
	    }
	    {^\@subtitle} {
		set it "subtitle_[incr TbLog(iSubtitle)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) "$it"
		set TbLog(${id}$it,Subtitle) $sreste
	    }
	    {^\@text} {
		set it "text_[incr TbLog(iText)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) ""
		set TbLog(${id}$it,Text) [join $sreste]
	    }
	    {^\@tele} {
		set it "tele_[incr TbLog(iTele)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) ""
		set TbLog(${id}$it,Text) [join $sreste]
	    }
	    {^\@pre} {
		set it "pre_[incr TbLog(iPre)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) ""
		set TbLog(${id}$it,Text) [join $sreste]
	    }
	    {^\@separator} {
		set it "separator_[incr TbLog(iSeparator)]"
		lappend TbLog(${id}LElt) $it
	    }
	    {^\@titlecols} {
		if {! [regexp {^tabular} [lindex [split $id ,] end-1]]} {
		    continue
		}
		set TbLog(${id}TitleCols) $sreste
	    }
	    {^\@typecols} {
		if {! [regexp {^tabular} [lindex [split $id ,] end-1]]} {
		    continue
		}
		set TbLog(${id}TypeCols) $sreste
	    }
	    {^\@row} {
		if {! [regexp {^tabular} [lindex [split $id ,] end-1]]} {
		    continue
		}
		lappend TbLog(${id}Rows) $sreste
	    }
	    {^\@list} {
		lappend TbLog(${id},Text) [join [lrange [split $l " "] 1 end]]
	    }
	    {^\@listBR} {
		lappend TbLog(${id},Text) [join [lindex [split $l " "] 1] "<br/>"]
	    }
	    {^\@link} {
		set it "link_[incr TbLog(iLink)]"
		lappend TbLog(${id}LElt) $it
		set TbLog(${id}$it,Id) ""
		set TbLog(${id}$it,textLink) [lindex $l 1]	
		set TbLog(${id}$it,targetLink) [lindex $l 2]
	    }
	}
    }

    return
}


proc NettoieTbl {at} {
    upvar $at t

    set nt {}
    foreach {k v} [array get t] {
	set k [join [lrange [split $k ,] 1 end] ,]
	lappend nt $k $v
    }
    unset -nocomplain t
    array set t $nt

    return
}


proc OutputTLog {{what HTML} {Log ""} {filout ""} {add ""}} {
    global TbLog TexteDuLog
    
    # what : (type of output)
    # - HTML
    # - Text
    # - stdout ==> Text + ecran

    set screen 0
    if {$what eq "stdout"} {
	set what Text
	set screen 1
    }

    if {$Log eq ""} {
	set Log $TexteDuLog
    }

    #set Log [split $Log "\n"]
    ParseTLog $Log
    InitTLog2$what
    TLogTo $what TbLog
    set res [EndTLog2$what]

    if {$filout eq ""} {
	if {[TypeAli] ne "pasdali"} {
	    set ftype "Fichier[TypeAli]"
	    set filout "[file rootname [set ::Defauts($ftype)]].[string tolower $what]"
	} else {
	    set filout "Output.$what"
	}
    }
    if {$add eq ""} {
	file delete -force $filout
    }

    if {$screen} {
	#puts "$res"
	#flush stdout
	update idletasks
    } else {
	if {$add eq ""} {
	    Sauve $res Dans $filout
	} else {
	    AppendAuFichier $filout $res
	}
    }

    return $res
}


proc TLogTo {what aT} {
    upvar $aT T
    
    foreach elt $T(LElt) {
	unset -nocomplain Tbl
	array set Tbl [array get T "$elt,*"]
	NettoieTbl Tbl

	#puts "$elt $what"
	switch -regexp -- $elt {
	    {^table} {
		Table2$what Tbl
		#TLogTo $what [array get Tbl]
	    }
	    {^warning} {
		if {$what eq "HTML"} {
		    BeginWarning2$what Tbl
		}
		#TLogTo $what [array get Tbl]
		TLogTo $what Tbl
		if {$what eq "HTML"} {
		    EndWarning2$what
		}
		#TLogTo $what [array get Tbl]
	    }
	    {^teletype} {
		#Blob2$what Tbl
		if {$what eq "HTML"} {
		    Html_BaliseOpen pre
		}
		#TLogTo $what [array get Tbl]
		TLogTo $what Tbl
		if {$what eq "HTML"} {
		    Html_BaliseClose pre
		}
	    }		
	    {^link} {
		if {$what eq "HTML"} {
		    Link2$what Tbl
		}
	    }
	    {^blob} {
		#Blob2$what Tbl
		#TLogTo $what [array get Tbl]
		TLogTo $what Tbl
	    }
	    {^tabular} {
		#puts "what $what"
		#parray Tbl
		Tabular2$what Tbl
	    }
	    {^title\_} {
		Title2$what Tbl
	    }
	    {^subtitle} {
		Subtitle2$what Tbl
	    }
	    {^separator} {
		Separator2$what
	    }
	    {^text} {
		Text2$what Tbl
	    }
	    {^tele} {
		Tele2$what Tbl
	    }
	    {^pre} {
		Pre2$what Tbl
	    }
	}
    }

    return 
}

########################
##################"#####
#
# Routines pour HTML
#
########################
##################"#####

proc TOCEnHTML {} {
    global TbLog

    Html_Append "<div>"
    Html_Append "<h2>Table Of Contents</h2>"
    Html_Append "<ul>"
    foreach elt $TbLog(LElt) {
	if {[set Lix [lsearch -all -regexp [set TbLog($elt,LElt)] "title_"]] == -1} {
	    continue
	}
	set InSub 0
	foreach ix $Lix {
	    set ittl [lindex [set TbLog($elt,LElt)] $ix]
	    if {[regexp {^subt} $ittl]} {
		if {! $InSub} {
		    set InSub 1
		    Html_Append "<ul>"
		}
		Html_Append "<li>"
		set subtitle [set TbLog($elt,$ittl,Subtitle)]
		Html_Href $subtitle "#$ittl" "style='fontsize:big;'"
		Html_Append "</li>"
	    } else {
		if {$InSub} {
		    set InSub 0
		    Html_Append "</ul>"
		}
		Html_Append "<li>"
		set title [set TbLog($elt,$ittl,Title)]
		Html_Href $title "#$ittl" "style='fontsize:big;'"
		Html_Append "</li>"
	    }
	}
	if {$InSub} {
	    Html_Append "</ul>"
	}
    }
    Html_Append "</ul>"
    Html_Append "</div>"
    Html_Append "<hr width='95%'/>"
    
    Html_BR

    return
}


proc JSDeOrdali {} {
    global OrdEtcDir

    # Le script est mis dans la page : le HTML sauve n'a pas de
    # htmltable2csv.js a cote de lui, et doit marcher seul.
    set JSDeOrdali [list "<script type='text/javascript'>"]
    lappend JSDeOrdali [ContenuDuFichier [file join $OrdEtcDir htmltable2csv.js]]
    lappend JSDeOrdali "</script>"

    return [join $JSDeOrdali \n]
}


proc CssBaseOrdalie {} {
    global CssBaseOrdalie

    set CssBaseOrdalie {} 
    lappend CssBaseOrdalie "<style type=\"text/css\">"
    lappend CssBaseOrdalie "  body {"
    lappend CssBaseOrdalie "    background-color:lightBlue;"
    #lappend CssBaseOrdalie "    background-image:url(/logos/WscopeBackground.png);"
    #lappend CssBaseOrdalie "    background-repeat:repeat;"
    #lappend CssBaseOrdalie "    background-position:top center;"
    lappend CssBaseOrdalie "    margin-left:20px;"
    lappend CssBaseOrdalie "  }"
    #lappend CssBaseOrdalie "  .darkgreen {color:DarkGreen;}" 
    lappend CssBaseOrdalie "  .leftalign {text-align:left}"
    lappend CssBaseOrdalie "  .rightalign {text-align:right}"
    lappend CssBaseOrdalie "  .centeralign {text-align:center}"
    lappend CssBaseOrdalie "  td {padding:0px 5px 0px 5px}"
    lappend CssBaseOrdalie "  table {border-collapse:collapse}"
    lappend CssBaseOrdalie "  .mb10 {margin-bottom:0px;}"
    lappend CssBaseOrdalie "  .courier {font-family:monospace, monospace;}"

#    lappend CssBaseOrdalie "  h1 {text-align:center; color: DarkGreen;}"
#    lappend CssBaseOrdalie "  h2 {text-align:center; color: DarkGreen;}"
#    lappend CssBaseOrdalie "  h3 {text-align:center; color: DarkGreen;}"
    lappend CssBaseOrdalie "  </style>"
    set CssBaseOrdalie [join $CssBaseOrdalie "\n"]

    return $CssBaseOrdalie
}


proc InitTLog2HTML {} {
    global DebutBodyHTML

    set head "[JSDeOrdali]\n[CssBaseOrdalie]"
    Html_ZeroToBody "Ordalie Log" "$head"

    # add needed javascript
    #Html_Append [JSDeOrdali]

    # css de base ....
    #Html_Append [CssBaseOrdalie]

    set DebutBodyHTML [Html_GetPosition]

    #Html_Append "<h1>[file rootname [set ::Defauts(Fichier[TypeAli])]]</h1>"
    Html_Append "<h2>Ordalie Version $::VersionDeOrdali</h2>"
    Html_Teletype "[DonneDateEtHeure]"
    Html_Append "<hr width='95%'/>"
    
    return
}


proc EndTLog2HTML {} {
    global DebutBodyHTML

    Html_BodyToEnd

    # incsere la CSS 
    set CSS ""
    if {$CSS ne ""} {
	Html_Insert $DebutBodyHTML $CSS
    }

    return [Html_Get]
}


proc Separator2HTML {} {
    Html_Append "<hr width='85%'/><br/>"
    return
}


proc Title2HTML {aT} {
    upvar $aT tbl

    Html_Append "<div id=$tbl(Id)>"
    Html_Append "<h2>$tbl(Title)</h2>"
    Html_Append "</div>"
    
    return
}


proc Subtitle2HTML {aT} {
    upvar $aT tbl

    set txt "$tbl(Subtitle)"
    Html_Append "<div id=$tbl(Id)>"
    Html_Append "<h3>$txt</h3>"
    Html_Append "</div>"
    
    return
}


proc Link2HTML {aT} {
    upvar $aT tbl

    Html_Href $tbl(textLink) $tbl(targetLink)

    return
}


proc Text2HTML {aT} {
    upvar $aT tbl

    set txt "$tbl(Text)"
    set txt [string map {"\n" "<br/>"} [string trim $txt]]
    if {$txt ne "" || $txt ne "{}"} {
	Html_Append $txt
    }
    Html_BR
    
    return
}


proc Tele2HTML {aT} {
    upvar $aT tbl

    if {$tbl(Text) eq ""} {
	Html_BR
    } else {
	set txt "$tbl(Text)"
	Html_Append "$txt"
    }

    return
}


proc Pre2HTML {aT} {
    upvar $aT tbl

    if {$tbl(Text) eq ""} {
	Html_BR
    } else {
	set txt [join $tbl(Text)]
	set tele "<pre>$txt</pre><br/>"
	Html_Append $tele
    }

    return
}


proc BeginWarning2HTML {aT} {
    upvar $aT tbl

    set style "font-style:bold;color:red;"
    if {$tbl(Id) ne ""} {
	Html_Append "<div style='$style' id=$tbl(Id)>"
    } else {
	Html_Append "<div style='$style'>"
    }
    Html_Append "<hr/>"

    return
}


proc EndWarning2HTML {} {
    Html_Append "<hr/>"
    Html_Append "</div>"
    Html_BR
    
    return
}


proc Blob2HTML {aT} {
    upvar $aT tbl

    if {$tbl(Id) ne ""} {
	Html_Append "<div id=$tbl(Id)>"
    } else {
	Html_Append "<div>"
    }
    foreach elt [set tbl(LElt)] {
	switch -regexp -- $elt {
	    {^title\_} {
		Html_Append "<h3>$tbl($elt,Title)</h3>"
	    }
	    {^Subtitle\_} {
		Html_Append "<h4>$tbl($elt,Subtitle)</h4>"
	    }
	}
    }
    Html_Append "</div>"
    Html_BR
    
    return
}


proc ButtonExportTableAsCSV {text} {
    Html_BR
    Html_BR

    set file [string map {" " _ "\;" "" "\." "" "\:" ""} $text]
    set file "[string trim $file "_"].csv"
    Html_Append "<button type='button' onClick=\"tableToCSV(this, '$file')\">Download CSV : $file </button>"
    Html_BR

    return
}


proc Tabular2HTML {aT {id ""} {text ""}} {
    upvar $aT tbl
    #parray tbl
    if {[set id $tbl(Id)] ne ""} {
	Html_Append "<div id=$tbl(Id)>"
    } else {
	Html_Append "<div>"
    }
    
    Html_Append "<table border='1px'>"
    if {$tbl(TitleCols) != {}} {
	Html_Append "<thead>"
	Html_Append "<tr>"
	foreach c $tbl(TitleCols) {
	    if {$c eq "NULL"} {set c ""}
	    Html_Append "<th>$c</th>"
	}
	Html_Append "</tr>"
	Html_Append "</thead>"
    }
    
    if {! [info exists tbl(Rows)]} {
	set tbl(Rows) {}
    }
    Html_Append "<tbody>"
    for {set i 0} {$i < [llength [lindex $tbl(Rows) 0]]} {incr i} {
	set classe($i) ""
	if {[info exists tbl(TypeCols)]} {
	    set type [lindex $tbl(TypeCols) $i]
	    if {$type eq "R" || $type eq "I"} {
		set classe($i) "class='rightalign'"
	    }
	}
    }
    
    foreach lrow $tbl(Rows) {	
	Html_Append "<tr>"
	set i 0
	foreach c $lrow {
	    if {$c eq "NULL"} {set c ""}
	    Html_Append "<td [set classe($i)]>$c</td>"
	    incr i
	}
	Html_Append "</tr>"
    }

    Html_Append "</tbody>"
    Html_Append "</table>"

    ButtonExportTableAsCSV $text
    

    Html_Append "</div>"

    return 
}


proc Table2HTML {aT} {
    upvar $aT tbl

    set id ""
    if {[set id $tbl(Id)] ne ""} {
	Html_Append "<div id=$tbl(Id)>"
    } else {
	Html_Append "<div>"
    }

    set title "" ; set subtitle ""
    foreach elt $tbl(LElt) {
	switch -regexp -- $elt {
	    {^title\_} {
		set title $tbl($elt,Title)
		Html_Append "<h3>$tbl($elt,Title)</h3>"
	    }
	    {^Subtitle\_} {
		set subtitle $tbl($elt,Subtitle)
		Html_Append "<h4>$tbl($elt,Subtitle)</h4>"
	    }
	    {^text} {
		Html_Teletype "[join $tbl($elt,Text) \n]"
	    }
	    {^tabular} {
		set lt [array get tbl "$elt,*"]
		set new {}
		foreach {k v} $lt {
		    lassign [split $k ,] tmp nk
		    lappend new $nk $v
		}
		array set tt $new
		set text ""
		if {$title ne ""} {
		    if {$subtitle ne ""} {
			set text $subtitle
		    } else {
			set text $title
		    }
		} else {
		    if {$subtitle ne ""} {
			set text $subtitle
		    }
		}
		
		Tabular2HTML tt $id $text
	    }
	}
    }

    Html_Append "</div>"
    Html_BR

    return 
}
###########


########################
##################"#####
#
# Routines pour Text
#
########################
##################"#####

proc TOCEnText {} {
    global TbLog TextOut

    lappend TextOut ""
    lappend TextOut "Table Of Contents"
    lappend TextOut "-----------------"
    foreach elt $TbLog(LElt) {
	if {[set Lix [lsearch -all -regexp [set TbLog($elt,LElt)] "title_"]] == -1} {
	    continue
	}
	set InSub 0
	foreach ix $Lix {
	    set ittl [lindex [set TbLog($elt,LElt)] $ix]
	    if {[regexp {^subt} $ittl]} {
		if {! $InSub} {
		    set InSub 1
		    set pre "    "
		}
		set subtitle [set TbLog($elt,$ittl,Subtitle)]
		lappend TextOut "$pre$subtitle"
	    } else {
		if {$InSub} {
		    set InSub 0
		    set pre ""
		}
		set title [set TbLog($elt,$ittl,Title)]
		lappend TextOut $title
	    }
	}
    }
    lappend TextOut ""

    return
}


proc InitTLog2Text {} {
    global TextOut

    if {[TypeAli] ne "pasdali"} {
	set tf "[file rootname [set ::Defauts(Fichier[TypeAli])]]"
    } else {
	set tf "Output"
    }
    lappend TextOut $tf
    lappend TextOut [string repeat "=" [string length $tf]]
    lappend TextOut ""
    lappend TextOut "Ordalie Version $::VersionDeOrdali"
    lappend TextOut "[DonneDateEtHeure]"
    lappend TextOut ""

    return
}


proc EndTLog2Text {} {
    global TextOut

    lappend TextOut ""

    return [join $TextOut \n]
}


proc Separator2Text {} {
    lappend ::TextOut ""
    return
}


proc Title2Text {aT} {
    upvar $aT tbl
    global TextOut

    lappend TextOut "$tbl(Title)"
    lappend TextOut [string repeat = [string length $tbl(Title)]]
    
    return
}


proc Subtitle2Text {aT} {
    upvar $aT tbl
    global TextOut

    lappend TextOut "$tbl(Subtitle)"
    lappend TextOut [string repeat = [string length $tbl(Subtitle)]]

    return
}


proc Pre2Text {aT} {
    upvar $aT tbl
    
    if {$tbl(Text) eq ""} {
	lappend ::TextOut ""
    } else {
	set txt [join $tbl(Text)]
	lappend ::TextOut $txt
    }

    return
}


proc Text2Text {aT} {
    upvar $aT tbl

    lappend ::TextOut "$tbl(Text)"
    
    return
}


proc Tele2Text {aT} {
    upvar $aT tbl

    lappend ::TextOut "$tbl(Text)"
    
    return
}


proc Warning2Text {aT} {
    upvar $aT tbl
    global TextOut

    lappend TextOut "[string repeat = 60]"
    if {$tbl(Title) ne ""} {
	lappend TextOut "[string toupper $tbl(Title)]"
    }
    if {$tbl(Text) ne ""} {
	lappend TextOut $tbl(Text)
    }
    lappend TextOut "[string repeat = 60]"
    lappend TextOut ""
    
    return
}


proc Blob2Text {aT} {
    upvar $aT tbl
    global TextOut

    foreach elt [set tbl(LElt)] {
	switch -regexp -- $elt {
	    {^title\_} {
		lappend TextOut "$tbl($elt,Title)"
	    }
	    {^Subtitle\_} {
		lappend TextOut "$tbl($elt,Subtitle)"
	    }
	    {^text} {
		lappend TextOut "[join $tbl($elt,Text) \n]"
	    }
	}
    }
    lappend TextOut ""
    
    return
}


proc Tabular2Text {aT} {
    upvar $aT tbl
    global TextOut

    if {! [info exists tbl(Rows)]} {
	set tbl(Rows) {}
    }

    # determine columns widths
    set TotLg 0
    array set TFmt {}
    for {set i 0} {$i < [llength [lindex [set tbl(Rows)] 0]]} {incr i} {
	set lgt [PlusLongEltDe [ExtraitListeDeListe $tbl(Rows) $i]]
	
	if {[info exists tbl(TitleCols)] && $tbl(TitleCols) != {}} {
	    set c [lindex $tbl(TitleCols) $i]
	    if {$c eq "NULL"} {set c ""}
	    set l [string length $c]
	    if {$l > $lgt} {set lgt $l}
	}

	set TFmt($i) [list " %${lgt}s |" $lgt]
	incr TotLg $lgt
	incr TotLg 3 ; # white space + |
    }
    incr TotLg ; # leading |

    # fill the table
    set sep [string repeat - $TotLg]
    lappend TextOut ""
    lappend TextOut $sep
    if {[info exists tbl(TitleCols)] && $tbl(TitleCols) != {}} {
	set i 0
	set textcol "|"
	foreach c $tbl(TitleCols) {
	    if {$c eq "NULL"} {set c ""}
	    lassign [set TFmt($i)] fmt tmp
	    append textcol [format $fmt $c]
	    incr i
	}
	lappend TextOut $textcol
	lappend TextOut $sep
    }

    foreach lrow $tbl(Rows) {	
	set tcol "|"
	set i 0
	foreach c $lrow {
	    if {$c eq "NULL"} {set c ""}
	    lassign [set TFmt($i)] fmt tmp
	    append tcol [format $fmt $c]
	    incr i
	}
	lappend TextOut $tcol
    }
    lappend TextOut $sep
    lappend TextOut ""

    return 
}


proc Table2Text {aT} {
    upvar $aT tbl
    global TextOut

    foreach elt $tbl(LElt) {
	switch -regexp -- $elt {
	    {^title\_} {
		lappend TextOut $tbl($elt,Title)
		lappend TextOut [string repeat - [string length $tbl($elt,Title)]]
	    }
	    {^Subtitle\_} {
		lappend TextOut $tbl($elt,Subtitle)
	    }
	    {^text} {
		lappend TextOut [join $tbl($elt,Text) \n]
	    }
	    {^tabular} {
		set lt [array get tbl "$elt,*"]
		set new {}
		foreach {k v} $lt {
		    lassign [split $k ,] tmp nk
		    lappend new $nk $v
		}
		array set tt $new
		Tabular2Text tt
	    }
	}
    }
    lappend TextOut ""

    return 
}

###########


proc testlog {} {
    set ::VersionDeOrdali 10.10
    set ::Defauts(TypeAli) XML
    set ::Defauts(FichierXML) testlog.xml

    AuLog @begin blob
    AuLog @title titre du blob
    AuLog @text ceci est un blob
    AuLog @end
    AuLog @begin table
    AuLog @title ===> TABLE TITTLE <===
    AuLog @begin tabular
    AuLog @titlecols ind2 col1 col2 col3 col4 col5 col6
    AuLog @typecols I R R R R R R
    AuLog @row 1 123.0 NULL 214. 123.0 NULL 214.
    AuLog @row 2 147.0 0.0 12. 147.0 0.0 12.
    AuLog @row 3 123.0 NULL 214. 123.0 NULL 214.
    AuLog @row 4 147.0 0.0 12. 147.0 0.0 12.
    AuLog @row 5 123.0 NULL 214. 123.0 NULL 214.
    AuLog @row 6 147.0 0.0 12. 147.0 0.0 12.
    AuLog @end
    AuLog @separator
    AuLog @text ligne de texte
    AuLog @separator
    AuLog @title 2eme tableau
    AuLog @begin tabular
    AuLog @titlecols indices col1 col2 col3
    AuLog @typecols I I R R
    AuLog @row 1 123 NULL 214.
    AuLog @row 2 147 0.0 12.
    AuLog @end
    AuLog @end
    AuLog @begin warning
    AuLog @title WARNING :
    AuLog @text this is a warning text
    AuLog @end

    AuLog LOutput HTML testlog.html

    #set res [OutputTLog HTML $Log]
    #Sauve $res Dans t.html

    exit
}


proc LogInfosSeqsGlobales {} {
    global {*}[info globals "TD*"] LNOrdali

    AuLog @begin blob
    AuLog @begin table
    AuLog @title General Sequences information
    AuLog @begin tabular
    AuLog @typecols T T T T T
    AuLog @titlecols "Seq. Name" "Accession" "ID" "Organism" "Taxa ID"
    foreach n $LNOrdali {
	set n [string trim $n]
	if {[string trim $n] eq ""} {
	    continue
	}
	set tmp {}
	lappend tmp $n
	foreach t {TDesAccess TDesBId TDesLength TDesOrganismes TDesTaxId} {
	    lappend tmp [set ${t}($n)]
	}
	AuLog @row {*}$tmp
    }
    AuLog @end
    AuLog @end
    AuLog @separator

    AuLog @begin table
    AuLog @title Phusico-chemical Sequences Information
    AuLog @begin tabular
    AuLog @typecols T R R R
    AuLog @titlecols "Seq. Name" "Mol. Weight" "Isoelectric Point" "Hydrophobicity"
    foreach n $LNOrdali {
	set n [string trim $n]
	if {[string trim $n] eq ""} {
	    continue
	}
	set tmp {}
	foreach t {TDesMolW TDespI TDesHydro} {
	    lappend tmp [set ${t}($n)]
	}
	AuLog @row $n {*}$tmp
    }
    AuLog @end
    AuLog @end
    AuLog @end
    
    return
}


proc LogInBrowser {} {
    AuLog LOutlog HTML
    if {[TypeAli] ne "pasdali"} {
	set ftype "Fichier[TypeAli]"
	set filout "[file rootname [set ::Defauts($ftype)]].html"
    } else {
	set filout "Output.$what"
    }

    set file "file://[file join [pwd] $filout]"
    #puts "open $file"
    OpenInBrowser $file

    return
}




