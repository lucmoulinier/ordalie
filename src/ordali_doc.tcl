

#
# --- ordali_doc.tcl
#
#
#


#
# hview is an adaptation from hv.tcl (complementing tkhtml)
#
# Changes :
# - ISO8859-1 chars converted to HTML entities
# - Global variables prefixed by hv_ (except ::HtmlTraceMask)
# - Procs prefixed by Hv_
# - menubar is optional
# - added an optional close button
#
# - launched by Hv_Run which admits optional arguments
#   Hv_Run -title $mytitle -iconname $myicon -readfile $myfile
#          -menubar 1 -closebutton "Close"
#
#
# This script implements the "hv" application.  Type "hv FILE" to
# view FILE as HTML.
#
# This application is used for testing the HTML widget.  It can
# also server as an example of how to use the HTML widget.
#
# @(#) $Id: hv.tcl,v 1.25 2000/02/19 18:37:52 drh Exp $
#

# This procedure is called when the user selects the File/Open
# menu option.
proc Hv_UserLoad {} {
    set filetypes {
	{{Html Files} {.html .htm}}
	{{All Files} *}
    }
    set f [tk_getOpenFile -initialdir $::hv_lastDir -filetypes $filetypes]
    if {$f!=""} {
	Hv_LoadFile $f
	set ::hv_lastDir [file dirname $f]
    }
}

#   Clear the screen.
proc Hv_ClearScreen {} {
    set w .hv.h.h
    $w clear
    catch {unset ::hv_hotkey}
    Hv_ClearBigImages
    Hv_ClearOldImages
    foreach fn [array names ::hv_Images] {
	set ::hv_OldImages($fn) $::hv_Images($fn)
    }
    catch {unset ::hv_Images}
}
proc Hv_ClearOldImages {} {
    foreach fn [array names ::hv_OldImages] {
	image delete $::hv_OldImages($fn)
    }
    catch {unset ::hv_OldImages}
}
proc Hv_ClearBigImages {} {
    foreach b [array names ::hv_BigImages] {
	image delete $::hv_BigImages($b)
    }
    catch {unset ::hv_BigImages}
}

#   Read a file
proc Hv_ReadFile {name} {
    if {[catch {open $name r} fp]} {
	tk_messageBox -icon error -message $fp -type ok
	return {}
    } else {
	fconfigure $fp -translation binary
	set r [read $fp [file size $name]]
	close $fp
	return $r
    }
}

# Load a file into the HTML widget
proc Hv_LoadFile {name} {
    set html [Hv_ReadFile $name]
    if {$html==""} return

    # translate ISO chars to HTML entities
    set html [Hv_ToEntities $html]

    Hv_ClearScreen
    set ::hv_LastFile $name
    .hv.h.h config -base $name
    .hv.h.h parse $html
    Hv_ClearOldImages
}

# Refresh the current file.
proc Hv_RefreshFile {args} {
    if {![info exists ::hv_LastFile]} return
    Hv_LoadFile $::hv_LastFile
}

# A font chooser routine.
#
# .hv.h.h config -fontcommand Hv_PickFont
proc Hv_PickFont {size attrs} {
    #  puts "FontCmd: $size $attrs"
    set a [expr {-1<[lsearch $attrs fixed]?{courier}:{charter}}]
    set b [expr {-1<[lsearch $attrs italic]?{italic}:{roman}}]
    set c [expr {-1<[lsearch $attrs bold]?{bold}:{normal}}]
    set d [expr {int(12*pow(1.2,$size-4))}]
    list $a $d $b $c
}

# This routine is called for each form element
proc FormCmd {n cmd args} {
    # puts "FormCmd: $n $cmd $args"
    switch $cmd {
	select -
	textarea -
	input {
	    set w [lindex $args 0]
	    label $w -image ::hv_nogifsm
	}
    }
}

# This routine is called for every <IMG> markup
#
proc ImageCmd {args} {
    if {!$::hv_showImages} {
	return ::hv_smgray
    }
    set fn [lindex $args 0]
    if {[info exists ::hv_OldImages($fn)]} {
	set ::hv_Images($fn) $::hv_OldImages($fn)
	unset ::hv_OldImages($fn)
	return $::hv_Images($fn)
    }
    if {[catch {image create photo -file $fn} img]} {
	return ::hv_smgray
    }
    if {[image width $img]*[image height $img]>20000} {
	set b [image create photo -width [image width $img] \
		   -height [image height $img]]
	set ::hv_BigImages($b) $img
	set img $b
	after idle "Hv_MoveBigImage $b"
    }
    set ::hv_Images($fn) $img
    return $img
}
proc Hv_MoveBigImage b {
    if {![info exists ::hv_BigImages($b)]} return
    $b copy $::hv_BigImages($b)
    image delete $::hv_BigImages($b)
    unset ::hv_BigImages($b)
    update
}

#   associated by trace variable with ::hv_showTableStruct var
proc Hv_ShowTableStruct args {
    if {$::hv_showTableStruct} {
	set ::HtmlTraceMask [expr {$::HtmlTraceMask|0x8}]
	.hv.h.h config -tablerelief flat
    } else {
	set ::HtmlTraceMask [expr {$::HtmlTraceMask&~0x8}]
	.hv.h.h config -tablerelief raised
    }
    Hv_RefreshFile
}

#   associated by trace variable with ::hv_underlineHyper
proc Hv_ChangeUnderline args {
    .hv.h.h config -underlinehyperlinks $::hv_underlineHyper
    Hv_RefreshFile
}

# This routine is called for every <SCRIPT> markup
#
proc ScriptCmd {args} {
    # puts "ScriptCmd: $args"
}

# This routine is called for every <APPLET> markup
#
proc AppletCmd {w arglist} {
    # puts "AppletCmd: w=$w arglist=$arglist"
    label $w -text "The Applet $w" -bd 2 -relief raised
}

# This procedure is called when the user clicks on a hyperlink.
# See the "bind .hv.h.h.x" below for the binding that invokes this
# procedure
#
proc Hv_HrefBinding {x y} {
    # koba & dg marking text
    .hv.h.h selection clear
    #    set ::tkhtml::Priv(mark) $x,$y
    set list [.hv.h.h href $x $y]
    if {![llength $list]} {return}
    foreach {new target} $list break
    if {$new!=""} {
	set pattern $hv_LastFile#
	set len [string length $pattern]
	incr len -1
	if {[string range $new 0 $len] eq $pattern} {
	    incr len
	    .hv.h.h yview [string range $new $len end]
	} else {
	    Hv_LoadFile $new
	}
    }
}
proc OldHv_HrefBinding {x y} {
    set new [.hv.h.h href $x $y]
    # puts "link to [list $new]"; return
    if {$new!=""} {
	set pattern $::hv_LastFile#
	set len [string length $pattern]
	incr len -1
	if {[string range $new 0 $len]==$pattern} {
	    incr len
	    .hv.h.h yview [string range $new $len end]
	} else {
	    Hv_LoadFile $new
	}
    }
}

#   Load argv string
#   The ::HtmlTraceMask only works if the widget was compiled with
#   the -DDEBUG=1 command-line option.  "file" is the name of the
#   first HTML file to be loaded.
#
proc Hv_LoadArgv {} {
    set ::hv_file {}
    foreach a $::argv {
	if {[regexp {^debug=} $a]} {
	    scan $a "debug=0x%x" ::HtmlTraceMask
	} else {
	    set ::hv_file $a
	}
    }
}

# These Images are used in place of GIFs or of form elements
#
proc Hv_FillerImages {} {
    image create photo ::hv_biggray -data {
	R0lGODdhPAA+APAAALi4uAAAACwAAAAAPAA+AAACQISPqcvtD6OctNqLs968+w+G4kiW5omm
	6sq27gvH8kzX9o3n+s73/g8MCofEovGITCqXzKbzCY1Kp9Sq9YrNFgsAO///
    }
    image create photo ::hv_smgray -data {
	R0lGODdhOAAYAPAAALi4uAAAACwAAAAAOAAYAAACI4SPqcvtD6OctNqLs968+w+G4kiW5omm
	6sq27gvH8kzX9m0VADv/
    }
    image create photo ::hv_nogifbif -data {
	R0lGODdhJAAkAPEAAACQkADQ0PgAAAAAACwAAAAAJAAkAAACmISPqcsQD6OcdJqKM71PeK15
	AsSJH0iZY1CqqKSurfsGsex08XuTuU7L9HywHWZILAaVJssvgoREk5PolFo1XrHZ29IZ8oo0
	HKEYVDYbyc/jFhz2otvdcyZdF68qeKh2DZd3AtS0QWcDSDgWKJXY+MXS9qY4+JA2+Vho+YPp
	FzSjiTIEWslDQ1rDhPOY2sXVOgeb2kBbu1AAADv/
    }
    image create photo ::hv_nogifsm -data {
	R0lGODdhEAAQAPEAAACQkADQ0PgAAAAAACwAAAAAEAAQAAACNISPacHtD4IQz80QJ60as25d
	3idKZdR0IIOm2ta0Lhw/Lz2S1JqvK8ozbTKlEIVYceWSjwIAO///
    }
}

# Construct the main window
#
proc Hv_MainWindow { {withmenu ""} {closebutton ""} {horizbar ""}
		     { linkcolor "#0000FF" } { bgcolor "#FFFFFF" } } {

    global Defauts

    frame .hv.mbar -bd 2 -relief raised

    if { $withmenu == 1 } {
	pack .hv.mbar -side top -fill x
    }

    menubutton .hv.mbar.file -text File -underline 0 -menu .hv.mbar.file.m
    pack .hv.mbar.file -side left -padx 5
    set m [menu .hv.mbar.file.m]
    $m add command -label Open -underline 0 -command Hv_UserLoad
    $m add command -label Refresh -underline 0 -command Hv_RefreshFile
    $m add separator
    $m add command -label Exit -underline 1 -command exit
    menubutton .hv.mbar.view -text View -underline 0 -menu .hv.mbar.view.m
    pack .hv.mbar.view -side left -padx 5
    set m [menu .hv.mbar.view.m]

    set ::hv_underlineHyper 1
    $m add checkbutton -label {Underline Hyperlinks} -variable ::hv_underlineHyper
    trace add variable ::hv_underlineHyper write Hv_ChangeUnderline

    set ::hv_showTableStruct 0
    $m add checkbutton -label {Show Table Structure} -variable ::hv_showTableStruct
    trace add variable ::hv_showTableStruct write Hv_ShowTableStruct
    set ::hv_showImages 1
    $m add checkbutton -label {Show Images} -variable ::hv_showImages
    trace add variable ::hv_showImages write Hv_RefreshFile

    # Construct the main HTML viewer
    #
    frame .hv.h
    pack .hv.h -side top -fill both -expand 1
    html .hv.h.h \
	-yscrollcommand {.hv.h.vsb set} \
	-xscrollcommand {.hv.f2.hsb set} \
	-formcommand FormCmd \
	-imagecommand ImageCmd \
	-scriptcommand ScriptCmd \
	-appletcommand AppletCmd \
	-underlinehyperlinks 1 \
	-bg $bgcolor -tablerelief flat \
	-visitedcolor $linkcolor \
	-unvisitedcolor $linkcolor \
	-fontcommand Hv_PickFont

    # If the tracemask is not 0, then draw the outline of all
    # tables as a blank line, not a 3D relief.
    #
    if {$::HtmlTraceMask} {
	.hv.h.h config -tablerelief flat
    }

    bind .hv.h.h.x <1> {Hv_HrefBinding %x %y}

    # Pack the HTML widget into the main screen.
    #
    pack .hv.h.h -side left -fill both -expand 1
    scrollbar .hv.h.vsb -width 8 \
	-orient vertical \
	-command {.hv.h.h yview}
    pack .hv.h.vsb -side left -fill y

    bind HtmlClip <4> {%W yview scroll -[set Defauts(DeltaYScroll)] units}
    bind HtmlClip <5> {%W yview scroll  [set Defauts(DeltaYScroll)] units}

    frame .hv.f2

    frame .hv.f2.sp -width [winfo reqwidth .hv.h.vsb] -bd 2 -relief raised
    scrollbar .hv.f2.hsb -orient horizontal -command {.hv.h.h xview}

    if { $horizbar == 1 } {
	pack .hv.f2.sp -side right -fill y
	pack .hv.f2.hsb -side top -fill x
	pack .hv.f2 -side top -fill x
    }

    # add close button
    if { $closebutton != "" } {
	frame .hv.bot
	pack .hv.bot -side bottom -fill x
	button .hv.bot.close -text $closebutton -command {destroy .hv} -width -12 -background green1
	pack .hv.bot.close -side right -padx [winfo reqwidth .hv.h.vsb] -pady 7
    }

    #   # configure link color
    #   .hv.h.h configure -visitedcolor $linkcolor -unvisitedcolor $linkcolor

    #   # configure background color
    #   .hv.h.h configure -background $bgcolor

    # If an argument was specified, read it into the HTML widget.
    #
    update
    if {$::hv_file!=""} {
	Hv_LoadFile $::hv_file
    }

    # This binding changes the cursor when the mouse move over
    # top of a hyperlink.
    #
    bind HtmlClip <Motion> {
	set parent [winfo parent %W]
	set url [$parent href %x %y]
	if {[string length $url] > 0} {
	    $parent configure -cursor hand2
	} else {
	    $parent configure -cursor {}
	}
    }

    MesCouleurs .hv
    FenetreAuCentre .hv
}

#   get a particular parameter value from an "args" string
proc Hv_GetArg { argname args } {
    foreach { keyword value } $args {
	if {[string index $keyword 0] == "-" } {
	    set argum [string range $keyword 1 end]
	    if { $argname == $argum } {
		return $value
	    }
	}
    }
    return ""
}

#   ISO To and From HTML entities / Converter
#   changing from and to html-entities http://wiki.tcl.tk/2821 - websearch
proc Hv_InitIsoHtml {} {
    array unset ::hv_froment
    array unset ::hv_toent

    array set escapes {
	iexcl \xa1 cent \xa2 pound \xa3 curren \xa4
	yen \xa5 brvbar \xa6 sect \xa7 uml \xa8 copy \xa9
	ordf \xaa laquo \xab not \xac shy \xad reg \xae
	hibar \xaf deg \xb0 plusmn \xb1 sup2 \xb2 sup3 \xb3
	acute \xb4 micro \xb5 para \xb6 middot \xb7 cedil \xb8
	sup1 \xb9 ordm \xba raquo \xbb frac14 \xbc frac12 \xbd
	frac34 \xbe iquest \xbf Agrave \xc0 Aacute \xc1 Acirc \xc2
	Atilde \xc3 Auml \xc4 Aring \xc5 AElig \xc6 Ccedil \xc7
	Egrave \xc8 Eacute \xc9 Ecirc \xca Euml \xcb Igrave \xcc
	Iacute \xcd Icirc \xce Iuml \xcf ETH \xd0 Ntilde \xd1
	Ograve \xd2 Oacute \xd3 Ocirc \xd4 Otilde \xd5 Ouml \xd6
	times \xd7 Oslash \xd8 Ugrave \xd9 Uacute \xda Ucirc \xdb
	Uuml \xdc Yacute \xdd THORN \xde szlig \xdf agrave \xe0
	aacute \xe1 acirc \xe2 atilde \xe3 auml \xe4 aring \xe5
	aelig \xe6 ccedil \xe7 egrave \xe8 eacute \xe9 ecirc \xea
	euml \xeb igrave \xec iacute \xed icirc \xee iuml \xef
	eth \xf0 ntilde \xf1 ograve \xf2 oacute \xf3 ocirc \xf4
	otilde \xf5 ouml \xf6 divide \xf7 oslash \xf8 ugrave \xf9
	uacute \xfa ucirc \xfb uuml \xfc yacute \xfd thorn \xfe
	yuml \xff
    }

    # Convert into a form that we can use with [string map]
    foreach key [array names escapes] {
	set ::hv_froment(&$key\;) $escapes($key)
    }

    foreach { key value } [array get escapes] {
	set ::hv_toent($value) &$key\;
    }
}

#   convert text to HTML entities
proc Hv_ToEntities { txt } {
    return [string map [array get ::hv_toent] $txt]
}

#   convert text from HTML entities
proc Hv_FromEntities { txt } {
    return [string map [array get ::hv_froment] $txt]
}

#   EXTERNAL PROCS

#   Load binary
proc Hv_LoadBin { {binpath ""} } {
    if { $binpath != "" } {
	load $binpath Tkhtml
    } else {
	foreach f {
	    ./tkhtml.so
	    /usr/lib/tkhtml.so
	    /usr/local/lib/tkhtml.so
	    ./tkhtml.dll
	} {
	    if {[file exists $f]} {
		if {[catch {load $f Tkhtml}]==0} break
	    }
	}
    }
}

#   Run
proc Hv_Run { args } {
    set title "HTML File Viewer"
    set iconname "HV"
    set menubar ""
    set closebutton ""
    set loadargv ""
    set readfile ""
    set horizbar ""
    set linkcolor ""

    set title       [eval Hv_GetArg title $args]
    set iconname    [eval Hv_GetArg iconname $args]
    set menubar     [eval Hv_GetArg menubar $args]
    set closebutton [eval Hv_GetArg closebutton $args]
    set loadargv    [eval Hv_GetArg loadargv $args]
    set readfile    [eval Hv_GetArg readfile $args]
    set horizbar    [eval Hv_GetArg horizbar $args]
    set linkcolor   [eval Hv_GetArg linkcolor $args]
    set bgcolor     [eval Hv_GetArg bgcolor $args]

    set ::hv_lastDir [pwd]
    set ::HtmlTraceMask 0

    if { $loadargv == 1 } {
	Hv_LoadArgv
    }

    if { $readfile != "" } {
	set ::hv_file $readfile
    }

    Hv_FillerImages
    Hv_InitIsoHtml

    trace remove variable ::hv_underlineHyper write Hv_ChangeUnderline
    trace remove variable ::hv_showImages write Hv_RefreshFile
    trace remove variable ::hv_showTableStruct write Hv_ShowTableStruct

    destroy .hv
    toplevel .hv
    wm title .hv $title
    wm iconname .hv $iconname
    set Cmd ""
    foreach a {menubar closebutton horizbar linkcolor bgcolor} {
	if {[set $a] != ""} {
	    append Cmd [set $a]
	}
    }
    Hv_MainWindow 0 "Close"
    #    eval Hv_MainWindow $Cmd

}

proc LanceDoc {{meth "internet"}} {
    # two ways :
    #    - internet : launch browser to access doc in ordalie web-site
    #    - local    : launch Tcl/Tk hv3 browser

    if {$meth eq "internet"} {
	package require browser_info

	OpenInBrowser "http://bigest-icube.fr/ordalie/doc/ordalie_documentation/index.html"
    } else {
	if {[info procs sourcefile] eq ""} {
	    source [file join $::OrdLibDir hv hv3_main.tcl]
	}
	set ::hv3::maindir $::OrdaliDir
	# HTML doc built by latex2html (doc/dohtml)
	set uri "file://[file join $::OrdaliDir doc ordalie_documentation index.html]"
	if {[info exists ::BrowserToplevel] && [winfo exists $::BrowserToplevel]} {
	    # browser already open : show the doc in a new tab
	    wm deiconify $::BrowserToplevel
	    raise $::BrowserToplevel
	    $::BrowserToplevel.notebook add $uri
	    return
	}
	#eval [concat hv3_main $argv]
	hv3_main $uri
	#hv3_main "file://~/merci.html"
    }

    return
}


proc LanceDoc_old {} {
    global OrdHlpDir

    #package require html3viewer

    set file [file join $OrdHlpDir index.html]

    #set html3 [html3widget::html3widget .t]
    #pack $html3
    #$html3 parseurl "http://wiki.tcl.tk/48458"
    #$html3 parsefile $file

    #return

    package require Tkhtml
    source /home/moumou/ordali/doc/hv.tcl
    Hv_Run -readfile $file

    return
}


proc LanceFile {file} {
    if {[info procs sourcefile] eq ""} {
	source [file join $::OrdLibDir hv hv3_main.tcl]
    }
    set ::hv3::maindir $::OrdaliDir
    hv3_main $file
    #hv3_main "file://[file join $::OrdaliDir doc ordalie_documentation.html]"
    #hv3_main "file://~/merci.html"
    
    return
}
























