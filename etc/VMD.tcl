#
# Procedures de communication entre Ordali et VMD
#
# Gere initialisation, emission reception et arret
#

proc CliVMDstart { argv } {
    global chatsock 
    global broadcast 

    set port [lindex $argv 0]
    set chatsock [socket localhost $port]

    fconfigure $chatsock -buffering line
    fileevent  $chatsock readable [list CliVMDrecv $chatsock]
    set broadcast 1 
    
    return
}



proc CliVMDstop {} {
    global chatsock

    puts "closing connection"
    close $chatsock
    update

    return
}



proc CliVMDrecv {sock} {
    global broadcast

    if { [eof $sock] || [catch {gets $sock line}]} {
	# end of file or abnormal connection drop
	puts "closing connection"
	close $sock

	return
    }
    # Turn off broadcast while evaluating, otherwise we would echo every
    # command we receive.
    set broadcast 0 

    eval $line 

    set broadcast 1

    return
}



proc CliVMDsend { cmd } {
    global broadcast
    global chatsock
    global vmd_logfile

    puts "vmd> $cmd"
    if { $broadcast == 0 } { return }
    puts $chatsock $cmd

    return
}



proc CliVMDsend2 { name1 name2 op } {
    global broadcast
    global chatsock
    global vmd_logfile

    if { $broadcast == 0 } { return }
    # Grab the text out of CliVMD_logfile and send it
    puts $chatsock [set $name1]
}


# 
# Commandes VMD appelees par Ordali
#


proc NouvelleCouleur {args} {
    global Lookup_ColVMD

    lassign $args i c r g b
    set Lookup_ColVMD($c) $i
    set Lookup_ColVMD($i) $c
    
    color change rgb $i $r $g $b

    return
}



proc NouvelleFeatures {args} {
    global LFeatures

    set LFeatures {}
    foreach e $args {
	lappend LFeatures $e
    }
    
    update

    return
}



proc NouvelleMolecule {fpdb MolId chn} {
    global ListeMolecules
    global FMol

    lappend ListeMolecules [list $fpdb $MolId $chn]

    set Id [expr {[llength $ListeMolecules] - 1}]
    mol load pdb $fpdb
    mol active $Id
    mol modrep 0 $Id

    AjouteMolInterface $MolId

    return
}



proc MChangeVue {Id args} {
    global Vue$Id

    set vu [set Vue$Id]

    if {$vu} {
	mol on  $Id
    } else {
	mol off $Id
    }
    
    return
}



proc MChangeColor {Id args} {
    global Col$Id

    set co [set Col$Id]

    if {$co == "structure"} {
	mol modcolor 0 $Id structure
    } else {
	set nreps [molinfo $Id get numreps]
	for {set r 0} {$r < $nreps} {incr r} {
	    mol delrep $r $Id
	}

	set nm [molinfo $Id get accession]
	CliVMDsend "VMDDemande $Id $nm Couleurs $co"
    }
    
    return
}



proc MChangeStyle {Id args} {
    global Sty$Id

    set st [set Sty$Id]

    set nreps [molinfo $Id get numreps]
    for {set r 0} {$r < $nreps} {incr r} {
	mol modstyle $r $Id $st
    }

    return
}



proc AjouteMolInterface {MolId} {
    global FMol
    global ListeMolecules
    global LFeatures
    global LStyles

    package require combobox 2.3

    set Id [expr {[llength $ListeMolecules] -1}]

    global Vue$Id
    global Col$Id
    global Sty$Id

    set Vue$Id 1
    set Col$Id [lindex $LFeatures 0]
    set Sty$Id [lindex $LStyles 0]

    set cwf 0
    foreach e $LFeatures {
	if {[string length $e] > $cwf} {set cwf [string length $e]}
    }
    set cws 0
    foreach e $LStyles {
	if {[string length $e] > $cws} {set cws [string length $e]}
    }

    checkbutton $FMol.roo$Id -variable Vue$Id -command "MChangeVue $Id"
    label $FMol.lbl$Id -width 6 -text $MolId
    combobox::combobox $FMol.menc$Id \
	    -background white \
	    -editable false -height 0 \
	    -textvariable Col$Id \
	    -command "MChangeColor $Id" -width $cwf \
	    -listvar LFeatures
    combobox::combobox $FMol.mend$Id \
	    -background white -height 0 \
	    -editable false \
	    -textvariable Sty$Id \
	    -command "MChangeStyle $Id" -width $cws \
	    -listvar LStyles

    grid $FMol.roo$Id  -in $FMol -padx 1 -pady 1 \
	    -row $Id -column 0 \
	    -rowspan 1 -columnspan 1 -sticky news
    grid $FMol.lbl$Id  -in $FMol -padx 1 -pady 1 \
	    -row $Id -column 1 \
	    -rowspan 1 -columnspan 1 -sticky news
    grid $FMol.menc$Id -in $FMol -padx 1 -pady 1 \
	    -row $Id -column 2 \
	    -rowspan 1 -columnspan 1 -sticky news
    grid $FMol.mend$Id -in $FMol -padx 1 -pady 1 \
	    -row $Id -column 3 \
	    -rowspan 1 -columnspan 1 -sticky news

    update

    return
}



proc Initialisation {} {
    global LFeatures
    global LStyles

    set LFeatures [list "structure" "conservation"]
    set LStyles   [list "trace" "newcartoon" "newribbons" "cartoon" "cpk" "ribbons"]

    mol representation trace
    mol color structure

    CliVMDInterface

    return
}


# proc appele par Ordali 
proc CliVMDInit {args} {
    global auto_path

    set ver [vmdinfo version]
    foreach {a b c} [split $ver "."] {}
    if {$a < 1 && $b < 8 && $c < 5} {
	CliVMDsend "FaireLire \"VMD $ver\nPlease update VMD to a higher version !\""
	FinVMD
    }

    lappend auto_path $args

    Initialisation

    return
}



proc FinVMD {} {

    CliVMDsend "FaireStopVMD"
    CliVMDstop
    catch {exit}
}



proc CliVMDInterface {} {
    global FenetreVOrdali
    global FMol

    set FenetreVOrdali ".vordvmd"
    set w $FenetreVOrdali

    toplevel $w
    wm protocol $w WM_DELETE_WINDOW {return}

    frame $w.f
    pack $w.f -expand 1

    label $w.f.lbl -text "VMD - Ordali Interface" -anchor w -font "{times new roman} 14 bold"
    pack $w.f.lbl -fill x -side top

    set FMol "$w.f.fmol"
    frame $FMol
    pack $FMol -expand 1 -side top -padx 10 -pady 20
    grid rowconfig    $FMol 0 -weight 1 -minsize 0
    grid columnconfig $FMol 0 -weight 0 -minsize 0

    frame $w.f.fbtons
    pack $w.f.fbtons -side bottom -pady 10 -fill x
    button $w.f.fbtons.print -text "Print" -bg cyan -command [list FinVMD]
    button $w.f.fbtons.dismiss -text "Dismiss" -bg red -command [list FinVMD]
    pack $w.f.fbtons.dismiss $w.f.fbtons.print -side left -expand 1

    wm geometry $w +0+0    

    return
}

CliVMDstart $argv

