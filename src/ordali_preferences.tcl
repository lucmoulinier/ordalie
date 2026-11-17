


#
#
# --- ordali_preferences.tcl ---
#
# procedures to create and manipulate 'Preferences' widget and contained options
#



proc DefinitPrfItem {w Quoi} {
    global FrmPref OldPrf

    regsub -all { +} $Quoi "" Quoi
    if {$OldPrf eq $Quoi} {
	return
    }

    foreach e [winfo children $FrmPref] {
	destroy $e
    }
    destroy $FrmPref
    
    labelframe $FrmPref \
	-relief groove \
	-foreground blue \
    -font TitleFont

    eval "EnvoiePrf${Quoi}"
    grid $FrmPref -row 0 -column 1 -sticky news -pady {5 1} -padx 5
    MesCouleurs $FrmPref

    set OldPrf $Quoi

    AjusteTaillePrf

    return
}


proc AffichePreferences2 {} {
    global PrfListe LesItems OldPrf FrmPref TmpDef CoulTmp Couleurs Defauts

    if {[winfo exists .prf]} {
	raise .prf
	return
    }

    set oldGrab [grab current]
    if {$oldGrab ne ""} {
	set oldStatus [grab status $oldGrab]
    }
    set oldFocus [focus]

    array set TmpDef  [array get Defauts]
    array set CoulTmp [array get Couleurs]

    # background color really applied to the application
    # (the 'Apply' button changes it before OK / Cancel)
    set ::PrfBackApplied $Defauts(BackAppli)

    toplevel .prf
    wm title .prf "Preferences"
    # closing the window = Cancel
    wm protocol .prf WM_DELETE_WINDOW [list TerminatePreferences .prf cancel]
    raise .prf

    set LesItems {General Sequences Conservation Editor "3D Display" Trees}
    set Larg [PlusLongEltDe $LesItems]

    set w ".prf"
    set PrfListe ".prf.lst"
    listbox $w.lst \
	-width $Larg \
	-height 20 \
	-selectmode single \
	-exportselection 0 \
	-borderwidth 3 \
	-highlightthickness 0 \
	-disabledforeground black \
	-bg white \
	-fg black
    bind $w.lst <1> {}
    # the item is read in the listbox itself : 'selection get'
    # returned the X selection, which may belong to another widget
    bind $w.lst <<ListboxSelect>> {
	if {[%W curselection] ne ""} {
	    DefinitPrfItem %W [%W get [lindex [%W curselection] 0]]
	}
    }

    # Frame pref
    set FrmPref "$w.frm"
    labelframe $w.frm \
	-relief groove \
	-foreground $Defauts(ForeAppli) \
    -font TitleFont
    
    # Frame Boutons OK dismiss default
    ttk::frame $w.btn \
	-style FrmBtnCtrl.TFrame
    button $w.btn.cancel \
	-text "Cancel" \
	-background red \
	-foreground white \
	-command [list TerminatePreferences $w cancel]
    button $w.btn.defaut \
	-text "Defaults" \
	-background yellow \
	-command [list TerminatePreferences $w reset]
    global bok
    set bok $w.btn.cebon
    button $w.btn.cebon \
	-text " OK " \
	-background green1 \
	-command [list TerminatePreferences $w ok]
    
    grid $w.btn.cancel -row 0 -column 0 -pady 5
    grid $w.btn.defaut -row 0 -column 1 -pady 5
    grid $w.btn.cebon  -row 0 -column 2 -pady 5
    grid columnconfig $w.btn {0 1 2} -weight 1

    grid $w.lst -row 0 -column 0 -sticky ns -padx 5 -pady 5
    grid $w.frm -row 0 -column 1 -sticky news -pady {5 1} -padx 5
    grid $w.btn -row 1 -column 0 -columnspan 2 -sticky we -padx 5 -pady {10 5}
    grid columnconfig $w 0 -weight 0
    grid columnconfig $w 1 -weight 1
    grid rowconfig    $w 0 -weight 1

    $w.lst insert 0 {*}$LesItems
    $w.lst selection set 0

    update idletasks

    set OldPrf "General"
    EnvoiePrfGeneral

    MesCouleurs .prf
    FenetreAuCentre .prf

    update idletasks

    return
}


proc AjusteTaillePrf {} {
    # FenetreAuCentre fixed the size of the window for the first
    # page shown : only its position is kept, so that the window
    # takes the size needed by the current page
    set w .prf
    if {! [winfo exists $w]} {
	return
    }
    scan [wm geometry $w] "%dx%d+%d+%d" wc hc x y
    wm geometry $w ""
    wm geometry $w +$x+$y
    update idletasks

    return
}


proc TestEditorFont {n1 n2 op} {
    global TmpDef

    # sample of the General page and main window widgets
    # (they may not exist : other page shown, no alignment ...)
    foreach b [list $TmpDef(biotest) {*}[BiotextsOrdali]] {
	if {[winfo exists $b]} {
	    $b font family $TmpDef(SeqFontFaml) size $TmpDef(SeqFontSize) weight $TmpDef(SeqFontWght)
	}
    }

    font configure SeqFont -family $TmpDef(SeqFontFaml) -size $TmpDef(SeqFontSize) -weight $TmpDef(SeqFontWght)

    return
}


proc EnvoiePrfGeneral {} {
    global TmpDef FrmPref NomTextSeq Defauts

    set pgen $FrmPref
    $pgen configure -text "General"

    label $pgen.lac \
	-text "Application background color : " \
	-anchor w -justify left
    button $pgen.bac \
	-bg [set TmpDef(BackAppli)] \
	-height 1 \
	-width 2 \
    -command "ChangeCouleurAppli $pgen.bac"
    button $pgen.bca \
	-text "Apply" \
	-background green1 \
	-command "AppliqueBackColor"
    
    label $pgen.whl \
	-text "Mouse Wheel controls :" \
	-fg blue \
    -anchor w -justify left
    label $pgen.lwy \
	-text "Vertical scrolling " \
	-anchor w -justify left
    entry $pgen.ewy \
	-width 3 \
	-bg white \
	-textvariable TmpDef(DeltaYScroll) \
	-justify right
    label $pgen.wuy \
	-text " line(s)" \
	-anchor w -justify left

    label $pgen.lwx \
	-text "Horizontal scrolling " \
	-anchor w -justify left
    entry $pgen.ewx \
	-width 3 \
	-bg white \
	-textvariable TmpDef(DeltaXScroll) \
	-justify right
    label $pgen.wux \
	-text " column(s)" \
	-anchor w -justify left

    grid $pgen.lac  -row 0 -column 0 -columnspan 2 -ipady 30 -sticky ew
    grid $pgen.bac  -row 0 -column 2 -sticky ew
    grid $pgen.bca  -row 0 -column 3 -sticky ew
    grid $pgen.whl  -row 1 -column 0 -columnspan 4 -pady {30 5} -sticky news
    grid $pgen.lwy  -row 2 -column 1 -sticky news
    grid $pgen.ewy  -row 2 -column 2 -sticky news
    grid $pgen.wuy  -row 2 -column 3 -sticky news
    grid $pgen.lwx  -row 3 -column 1 -sticky news
    grid $pgen.ewx  -row 3 -column 2 -sticky news
    grid $pgen.wux  -row 3 -column 3 -sticky news

    # Fontes
    frame $pgen.fft
    grid $pgen.fft -row 4 -column 0 -columnspan 4 -sticky ew -pady 10
    label $pgen.fft.lfnt \
	-text "Sequences names and residues font :" \
	-anchor w -justify left \
	-fg blue
    # biotext widget to show font change
    set TmpDef(biotest) $pgen.fft.bio
    biotext $TmpDef(biotest) \
	-width 10 -height 2 \
	-foreground $Defauts(Foreground) \
	-background $Defauts(Background) \
	-relief flat \
	-borderwidth 1 \
	-highlightthickness 0 \
	-class Biotext \
	-setgrid 0
    $TmpDef(biotest) font family $Defauts(SeqFontFaml) size $Defauts(SeqFontSize) weight $Defauts(SeqFontWght)
    set Lseq [list "MSA.DEFQ.W" "MPA..NWD.T"]
    $TmpDef(biotest) configure -state normal
    $TmpDef(biotest) sequences $Lseq

    # search all fixed fonts (asked to the sample widget : the
    # main window may have no alignment yet)
    set Lfont [lsort [$TmpDef(biotest) font list]]
    if {$TmpDef(SeqFontFaml) ni $Lfont} {
	lappend Lfont $TmpDef(SeqFontFaml)
    }
    tk_optionMenu $pgen.fft.ffml TmpDef(SeqFontFaml) {*}$Lfont
    tk_optionMenu $pgen.fft.fsiz TmpDef(SeqFontSize) 4 6 8 10 12 14 16 18 20 22 24
    tk_optionMenu $pgen.fft.fwgh TmpDef(SeqFontWght) normal bold

    # traces are added each time the page is shown : remove
    # them first
    TracesFontePrf add

    grid $pgen.fft.lfnt -row 0 -column 0 -sticky w
    grid $pgen.fft.ffml -row 1 -column 0 -sticky ew
    grid $pgen.fft.fsiz -row 1 -column 1 -sticky ew
    grid $pgen.fft.fwgh -row 1 -column 2 -sticky ew
    grid $pgen.fft.bio -row 2 -column 0 -columnspan 3 -sticky w -pady 20

    return
}


proc BiotextsOrdali {} {
    # names, sequences and ruler widgets of the main window
    set Lw {}
    foreach v {NomNomSeq NomTextSeq WTexteRegle} {
	if {[info exists ::$v] && [winfo exists [set ::$v]]} {
	    lappend Lw [set ::$v]
	}
    }

    return $Lw
}


proc TracesFontePrf {what} {
    # traces on the font variables of the General page
    foreach v {SeqFontFaml SeqFontSize SeqFontWght} {
	trace remove variable ::TmpDef($v) write TestEditorFont
	if {$what eq "add"} {
	    trace add variable ::TmpDef($v) write TestEditorFont
	}
    }

    return
}


proc AppliqueFontesSequences {} {
    # font of the main window from Defauts
    global Defauts

    font configure SeqFont -size $Defauts(SeqFontSize) -family $Defauts(SeqFontFaml) -weight $Defauts(SeqFontWght)
    foreach b [BiotextsOrdali] {
	$b font family $Defauts(SeqFontFaml) size $Defauts(SeqFontSize) weight $Defauts(SeqFontWght)
    }

    return
}


proc AppliqueCouleurFond {old new {w .}} {
    # Replace background color 'old' by 'new' in all the widgets
    # having it, and in the option database for new widgets
    if {$w eq "."} {
	if {[catch {winfo rgb . $old} rgbOld] || [catch {winfo rgb . $new}]} {
	    return
	}
	set ::PrfRgbOld $rgbOld
	if {$::Defauts(bgFrmBtnCtrl) eq $old} {
	    set ::Defauts(bgFrmBtnCtrl) $new
	}
	ChangeTkOptions $new
    }

    if {[winfo class $w] ni {Biotext Text Canvas Entry Listbox TCombobox}} {
	foreach opt {-background -activebackground -highlightbackground} {
	    if {[catch {$w cget $opt} c] || $c eq ""} {
		continue
	    }
	    if {! [catch {winfo rgb . $c} rgb] && $rgb eq $::PrfRgbOld} {
		catch {$w configure $opt $new}
	    }
	}
    }
    foreach e [winfo children $w] {
	AppliqueCouleurFond $old $new $e
    }

    return
}


proc AddNewBankPrefix {we wl} {
    global TmpDef

    set e [string trim [$we get]]
    # a prefix is a single word, without the separator
    set e [string trimright $e "|:"]
    if {$e eq "" || [regexp {[\s|:]} $e]} {
	return
    }

    if {[string toupper $e] in [lmap b $TmpDef(PrefixesBank) {string toupper $b}]} {
	FaireLire "The new prefix already exists !"
	return
    }

    lappend TmpDef(PrefixesBank) $e
    $wl delete 0 end
    $wl insert end {*}[set TmpDef(PrefixesBank)]
    $wl see end

    $we delete 0 end

    return
}


proc RemoveBankPrefix {wl} {
    global TmpDef

    set i [$wl curselection]
    if {$i eq ""} {
	FaireLire "Please select the prefix to remove in the list !"
	return
    }
    set TmpDef(PrefixesBank) [lreplace $TmpDef(PrefixesBank) $i $i]
    $wl delete $i

    return
}


proc ChangeCouleurLifeDomain {b} {
    global TmpDef

    set old [$b cget -bg]
    set c [tk_chooseColor -initialcolor $old -title "Choose a color ..."]
    if {$c eq ""} {
	return
    }

    set LifeD [string trim [$b cget -text]]
    set TmpDef(Bg$LifeD) $c
    $b configure -bg $c

    return
}


proc EnvoiePrfSequences {} {
    global Defauts FrmPref TmpDef

    set root $FrmPref
    $root configure -text "Sequences"

    # Bank Prefix
    set pbp "$root.bp"
    frame $pbp
    label $pbp.prf \
	-text "Remove bank prefix when loading sequences :" \
	-anchor w -justify left \
	-fg blue
    radiobutton $pbp.pry \
	-text "Yes" \
	-variable TmpDef(RemoveBankPrefix) \
	-relief flat \
	-value 1
    radiobutton $pbp.prn \
	-text "No"  \
	-variable TmpDef(RemoveBankPrefix) \
	-relief flat \
	-value 0

    grid $pbp.prf -row 0 -column 0 -columnspan 2 -sticky w
    grid $pbp.pry -row 1 -column 0 -padx {10 5}
    grid $pbp.prn -row 1 -column 1

    # Ajout nouveau Prefix
    set paj "$root.faj"
    set wd [PlusLongEltDe [set TmpDef(PrefixesBank)]]
    frame $paj
    label   $paj.alst \
	-text "Bank prefixes :" \
	-fg blue \
	-anchor w -justify left
    frame   $paj.fls
    listbox $paj.fls.lpr  \
	-width $wd \
	-height 5 \
	    -exportselection 0 \
	    -highlightthickness 0 \
	    -disabledforeground black \
	    -bg white -fg black \
	    -yscrollcommand "$paj.fls.scr set"

    scrollbar $paj.fls.scr \
	-width 8  \
	    -command "$paj.fls.lpr yview"
    $paj.fls.lpr insert end {*}[set TmpDef(PrefixesBank)]

    grid $paj.fls.lpr -row 0 -column 0 -sticky ew
    grid $paj.fls.scr -row 0 -column 1 -sticky ns

    label  $paj.lnew \
	-text "New prefix to be added :"
    entry  $paj.ent \
	-bg white \
	-width 15
    button $paj.badd \
	-text " Add " \
	    -bg cyan \
	    -command [list AddNewBankPrefix $paj.ent $paj.fls.lpr]

    grid $paj.alst -row 0 -column 0 -columnspan 3 -sticky w
    grid $paj.fls  -row 1 -column 0 -rowspan 3 -sticky ew
    grid $paj.lnew -row 2 -column 1 -columnspan 2 -sticky w -padx {10 1}
    grid $paj.ent  -row 3 -column 1 -sticky w -padx {10 1}
    grid $paj.badd -row 3 -column 2 -sticky ew
    button $paj.brem \
	-text " Remove selected prefix " \
	-bg cyan \
	-command [list RemoveBankPrefix $paj.fls.lpr]
    grid $paj.brem -row 1 -column 1 -columnspan 2 -sticky w -padx {10 1}
    bind $paj.ent <Return> [list $paj.badd invoke]

    # Couleurs euka-arke-bacte
    set pcl "$root.fpc"
    frame $pcl
    label $pcl.llif \
	-text "Life Domain Colors :" \
	-fg blue \
	-anchor w -justify left
    button $pcl.beuk \
	-text "Eukaryota" \
	    -fg [set TmpDef(FgEukaryota)] \
	    -bg [set TmpDef(BgEukaryota)] \
	    -command [list ChangeCouleurLifeDomain $pcl.beuk]
    button $pcl.bark \
	-text " Archaea " \
	    -fg [set TmpDef(FgArchaea)] \
	    -bg [set TmpDef(BgArchaea)] \
	    -command [list ChangeCouleurLifeDomain $pcl.bark]
    button $pcl.bbac \
	-text "Bacteria" \
	    -fg [set TmpDef(FgBacteria)] \
	    -bg [set TmpDef(BgBacteria)] \
	    -command [list ChangeCouleurLifeDomain $pcl.bbac]
    button $pcl.bvir \
	-text " Viruses " \
	    -fg [set TmpDef(FgViruses)] \
	    -bg [set TmpDef(BgViruses)] \
	    -command [list ChangeCouleurLifeDomain $pcl.bvir]
    
    grid $pcl.llif -row 0 -column 0 -columnspan 3 -sticky w
    grid $pcl.beuk -row 1 -column 0 -sticky ew
    grid $pcl.bark -row 1 -column 1 -sticky ew
    grid $pcl.bbac -row 1 -column 2 -sticky ew
    grid $pcl.bvir -row 1 -column 3 -sticky ew

    grid $pbp -row 0 -column 0 -sticky ew -padx 5 -pady {20 5}
    grid $paj -row 1 -column 0 -sticky ew -padx 5 -pady 10
    grid $pcl -row 2 -column 0 -sticky ew -padx 5 -pady 5

    return
}


proc EnvoiePrfConservation {} {
    global TypeText CoulTmp TypeCons FrmPref TmpDef

    set pcns $FrmPref
    $pcns configure \
	-text Conservation

    grid columnconfig $pcns {1 2} -weight 1

    # colors
    label $pcns.lbl \
	-text "Conservation Types Colors :" \
	-fg blue \
    -anchor w -justify left
    grid $pcns.lbl -row 0 -column 0 -columnspan 3 -sticky we -pady {10 0}
    # table for conservation colros
    label $pcns.lfore \
	-text "foreground" \
	-anchor w -justify left
    label $pcns.lback \
	-text "background" \
	-anchor w -justify left
    grid $pcns.lfore -row 1 -column 1 -sticky w
    grid $pcns.lback -row 1 -column 2 -sticky w
    set i 2
    foreach Type [lrange $TypeCons 0 2] {
	lassign [set CoulTmp($Type)] fg bg
	label  $pcns.l$Type \
	    -text [set TypeText($Type)] \
	    -anchor w
	button $pcns.f$Type \
	    -bg $fg \
	    -activebackground $fg \
	    -width 4 \
	    -command [list ChangeCouleur $Type fg $pcns.f$Type]
	button $pcns.b$Type \
	    -bg $bg \
	    -activebackground $bg \
	    -width 4 \
	    -command [list ChangeCouleur $Type bg $pcns.b$Type]

	grid $pcns.l$Type -row $i -column 0 -sticky w
	grid $pcns.f$Type -row $i -column 1 -sticky w
	grid $pcns.b$Type -row $i -column 2 -sticky w

	incr i
    }

    # Thresholds
    label $pcns.lblm \
	-text "For the Threshold Method :\nDefine the threshold above which a column is said\nto be conserved" \
	-fg blue \
    -justify left
    label $pcns.sclb \
	-text "Threshold " \
	-anchor w -justify left
    scale $pcns.scal \
	-from 0 -to 100 \
	-orient horiz \
	-showvalue true \
	-variable TmpDef(Threshold) \
	    -width 8 -length 75
    grid $pcns.lblm -row $i -column 0 -columnspan 3 -sticky ew -pady {20 5}
    incr i
    grid $pcns.sclb -row $i -column 0 -columnspan 1 -sticky w
    grid $pcns.scal -row $i -column 1 -columnspan 2 -sticky news
    incr i

    # use similarity
    label $pcns.sim \
	-text "Use similarity" \
	-fg blue \
    -anchor w -justify left
    radiobutton $pcns.simy \
	-text "Yes" \
	-variable TmpDef(SimiGris) \
	-relief flat \
	-value 1 \
	-highlightthickness 0
    radiobutton $pcns.simn \
	-text "No" \
	-variable TmpDef(SimiGris) \
	-relief flat \
	-value 0 \
	-highlightthickness 0

    grid $pcns.sim  -row $i -column 0 -sticky w
    grid $pcns.simy -row $i -column 1
    grid $pcns.simn -row $i -column 2

    return
}

proc DebugMapping {} {
    global FrmPref

    set f $FrmPref.fmp
    puts "winfo [winfo children $f]"
    foreach e [winfo children $f] {
	if {[winfo class $e] eq "Label"} {
	    puts ">[$e cget -text]<"
	}
	if {[winfo class $e] eq "Button"} {
	    puts "[$e cget -bg]"
	}
    }

    return
}


proc EnvoiePrfEditor {} {
    global TmpDef FrmPref TmpMap

    set fe $FrmPref
    $fe configure \
	-text Editor
    
    # lock sequences
    frame $fe.floc 
    grid $fe.floc -row 0 -column 0 -sticky ew -pady 10
    label $fe.floc.loc \
	-text "Lock Sequences at startup :" \
	-anchor w -justify left \
	-fg blue
    radiobutton $fe.floc.lcy \
	-text "Yes" \
	-variable TmpDef(LockSeqs) \
	-relief flat \
	-value 1 \
	-highlightthickness 0
    radiobutton $fe.floc.lcn \
	-text "No" \
	-variable TmpDef(LockSeqs) \
	-relief flat \
	-value 0 \
	-highlightthickness 0
    
    grid $fe.floc.loc -row 0 -column 0 -sticky w
    grid $fe.floc.lcy -row 1 -column 0 -sticky w -padx 10
    grid $fe.floc.lcn -row 1 -column 1 -sticky w
    
    # Mapping
    frame $fe.fmp
    grid $fe.fmp -row 2 -column 0 -sticky ew -pady 10
    label $fe.fmp.lmap \
	-text "Residue Mapping Colors :" \
	-anchor w -justify left \
	-fg blue
    grid $fe.fmp.lmap -row 0 -column 0 -columnspan 9 -sticky w

    unset -nocomplain TmpMap
    set p 0
    foreach l [set TmpDef(Mapping)] {
	lassign $l n f b
	set TmpMap($n,fg) $f
	set TmpMap($n,bg) $b

	label $fe.fmp.lmap$p \
	    -text "$n" \
	    -fg $TmpMap($n,fg) \
	    -bg $TmpMap($n,bg) \
	    -anchor w -justify left
	incr p
	# n may be a space : commands built as lists
	set lbl $fe.fmp.lmap[expr {$p-1}]
	button $fe.fmp.bf$p \
	    -bg $f \
	    -activebackground $f \
	    -width 2 \
	    -command [list ChangeCouleurMapping $n fg $fe.fmp.bf$p $lbl]
	incr p
	button $fe.fmp.bb$p \
	    -bg $b \
	    -activebackground $b \
	    -width 2 \
	    -command [list ChangeCouleurMapping $n bg $fe.fmp.bb$p $lbl]
	incr p
    }

    set r 0
    for {set i 0} {$i < $p} {incr i 3} {
	if {! ($i % 9)} {
	    incr r
	    set c 0
	}
	set wdl "lmap$i" ; set pdl [list 2 1]
	set wdf "bf[expr {$i+1}]" ; set pdf [list 1 1]
	set wdb "bb[expr {$i+2}]" ; set pdb [list 1 2]

grid $fe.fmp.$wdl -row $r -column $c -padx $pdl
	incr c
grid $fe.fmp.$wdf -row $r -column $c -padx $pdf
	incr c
grid $fe.fmp.$wdb -row $r -column $c -padx $pdb
	incr c
    }

    # colorblind proposition
    frame $fe.fbt
    grid $fe.fbt -row 3 -column 0 -sticky ew -pady 10
    button $fe.fbt.blind \
	-text "Colorblind Mapping" \
	-background cyan \
	-command [list ToggleMappingPrf blind]
    button $fe.fbt.def \
	-text "Default Mapping" \
	-background cyan \
	-command [list ToggleMappingPrf default]

    grid $fe.fbt.blind -row 0 -column 0 -sticky w -padx 10
    grid $fe.fbt.def -row 0 -column 1 -sticky e -padx 10

    update idletasks

    return
}


proc ToggleMappingPrf {what} {
    global FrmPref TmpDef

    # toogle the mapping between colorblind and default
    if {$what eq "blind"} {
	set TmpDef(Mapping) [ColorBlindMappingData]
    } else {
	set TmpDef(Mapping) [EditorMappingData]
    }

    foreach e [winfo children $FrmPref] {
	destroy $e
    }
    EnvoiePrfEditor
    AjusteTaillePrf

    return
}


proc EnvoiePrfDatabases {} {
    global TmpDef FrmPref

    set pdbs $FrmPref
    $pdbs configure -text Databases

    label $pdbs.ldbs \
	-justify left -anchor w \
	-text "Ordalie retrieves some information using distant\n databases. You may change the defaults ones to\n yours. IMPORTANT ! The XXXX stands for the Id\n to be retrieved, and it must be specified in your url !"

    label $pdbs.lpdb -text "Protein Data Bank (PDB) location :" -justify left -anchor w
    entry $pdbs.epd1 -bg white -textvariable TmpDef(UrlPdbWorld)
    entry $pdbs.epd2 -bg white -textvariable TmpDef(UrlPdbHome)

    label $pdbs.lbrd -text "Biological Information Retrieval Database (BIRD) location :" -justify left -anchor w
    entry $pdbs.ebr1 -bg white -textvariable TmpDef(UrlPdbHoan)

    grid $pdbs.ldbs -row 0 -column 0 -sticky news -pady {10 5}
    grid $pdbs.lpdb -row 1 -column 0 -sticky news -pady {20 1}
    grid $pdbs.epd1 -row 2 -column 0 -sticky news
    grid $pdbs.epd2 -row 3 -column 0 -sticky news
    grid $pdbs.lbrd -row 7 -column 0 -sticky news -pady {20 1}
    grid $pdbs.ebr1 -row 8 -column 0 -sticky news -pady {0 10}

    return
}


proc EnvoiePrf3DDisplay {} {
    global FrmPref
    global TmpDef

    set td $FrmPref
    $td configure -text "3D Display"

    label $td.lcv \
	-text "Default ribbon Color :" \
	-fg blue \
	-anchor w -justify left
    button $td.bco \
	-background [set TmpDef(CoulVariable)] \
	-command [list ChangeCouleurVariable $td.bco]

    label $td.ps \
	-text "Precompute Surface :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $td.ysf \
	-text "Yes" \
	    -highlightthickness 0 \
	    -relief flat \
	    -variable TmpDef(PrecomputeSrf) \
	    -value 1
    radiobutton $td.nsf \
	-text "No" \
	    -highlightthickness 0 \
	    -relief flat \
	    -variable TmpDef(PrecomputeSrf) \
	    -value 0

    label $td.lramp \
	-text "Ramp of Colors (Color Sec. Str. by identity) :" \
	-fg blue \
	-anchor w -justify left
    frame $td.framp
    for {set i 0} {$i < 10} {incr i} {
	set c $TmpDef(GammeCoul$i)
	set w "$td.framp.bcol$i"
	button $w \
	    -bg $c \
	    -width 2 \
		-command [list ChangeCouleurDeLaGamme $w]
	grid $w -row 0 -column $i -ipadx 0
    }

    grid $td.lcv   -row 0 -column 0 -sticky w -pady 10
    grid $td.bco   -row 0 -column 1 -sticky w
    grid $td.ps    -row 1 -column 0 -sticky w -pady 10
    grid $td.ysf   -row 1 -column 1 -sticky w
    grid $td.nsf   -row 1 -column 2 -sticky w
    grid $td.lramp -row 2 -column 0 -sticky w -pady {10 1}
    grid $td.framp -row 3 -column 0 -columnspan 2 -sticky ew

    return
}


proc EnvoiePrfTrees {} {
    global FrmPref
    global TmpDef

    set ft $FrmPref
    $ft configure -text Trees

    label $ft.lgpr \
	-text "Gap Removal :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $ft.gppw \
	-text "Pairwise" \
	    -highlightthickness 0 \
	    -relief flat \
	    -variable TmpDef(TypeGapTree) \
	    -value "pairwise"
    radiobutton $ft.gpgb \
	-text "Global" \
	    -highlightthickness 0 \
	    -relief flat \
	    -variable TmpDef(TypeGapTree) \
	    -value "global" 

    label $ft.tytr \
	-text "Type of Tree :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $ft.tydn \
	-text "Dendrogram"    \
	-variable TmpDef(TypeTree) \
	-relief flat \
	-value "dendrogram" \
	-highlightthickness 0
    radiobutton $ft.tycl \
	-text "Circular Tree" \
	-variable TmpDef(TypeTree) \
	-relief flat \
	-value "radial" \
	-highlightthickness 0

    label $ft.fntt \
	-text "Tree font :" \
	-fg blue \
	-anchor w -justify left
    tk_optionMenu $ft.fsiz TmpDef(FontSizeTree) 4 6 8 10 12 14 16
    tk_optionMenu $ft.fwgh TmpDef(FontWghtTree) normal bold

    label $ft.boot \
	-text "Bootstrap :" \
	-fg blue \
	-anchor w -justify left
    radiobutton $ft.boty \
	-text "Yes" \
	    -highlightthickness 0 \
	    -relief flat \
	    -value 1 \
	    -variable TmpDef(TreeBoot)
    radiobutton $ft.botn \
	-text "No" \
	    -highlightthickness 0 \
	    -relief flat \
	    -variable TmpDef(TreeBoot) \
	    -value 0

    grid $ft.lgpr -row 0 -column 0 -pady 10 -sticky w
    grid $ft.gppw -row 0 -column 1 -sticky w
    grid $ft.gpgb -row 0 -column 2 -sticky w

    grid $ft.tytr -row 1 -column 0 -pady 10 -sticky w
    grid $ft.tydn -row 1 -column 1 -sticky w
    grid $ft.tycl -row 1 -column 2 -sticky w

    grid $ft.fntt -row 2 -column 0 -pady 10 -sticky w
    grid $ft.fsiz -row 2 -column 1 -sticky w
    grid $ft.fwgh -row 2 -column 2 -sticky w

    grid $ft.boot -row 3 -column 0 -pady 10 -sticky w
    grid $ft.boty -row 3 -column 1 -sticky w
    grid $ft.botn -row 3 -column 2 -sticky w

    return
}


proc AppliqueBackColor {} {
    # 'Apply' button : shows the new background color at once.
    # Cancel restores the old one, OK keeps it.
    global TmpDef

    if {$TmpDef(BackAppli) ne $::PrfBackApplied} {
	AppliqueCouleurFond $::PrfBackApplied $TmpDef(BackAppli)
	set ::PrfBackApplied $TmpDef(BackAppli)
    }

    return
}


proc ChangeCouleurMapping {n what b lbl} {
    # n : residue, what : fg or bg, b : button, lbl : residue label
    global TmpMap

    set newc [tk_chooseColor -initialcolor $TmpMap($n,$what) -title "Choose a color ..."]
    if {$newc eq ""} {
	return
    }
    
    $b configure -bg $newc -activebackground $newc
    $lbl configure -[string index $what 0]g $newc
    set TmpMap($n,$what) $newc

    # the mapping itself is kept up to date : the page may be
    # left and shown again before OK
    set Lmap {}
    foreach l $::TmpDef(Mapping) {
	if {[lindex $l 0] eq $n} {
	    set l [list $n $TmpMap($n,fg) $TmpMap($n,bg)]
	}
	lappend Lmap $l
    }
    set ::TmpDef(Mapping) $Lmap
    
    return
}


proc ChangeCouleurDeLaGamme {b} {
    global TmpDef

    set OldC [$b cget -background]
    set col [tk_chooseColor -initialcolor $OldC -title "Choose a color ..."]
    if {$col eq ""} {return}

    regexp {[0-9]+$} $b i
    $b configure -bg $col
    set col [CouleurDeci2Hexa [RGBDeLaTkCol $col]]
    set TmpDef(GammeCoul$i) $col

    update idletasks

    return
}


proc ChangeCouleurVariable {b} {
    global TmpDef

    set OldC [set TmpDef(CoulVariable)]
    set col [tk_chooseColor -initialcolor $OldC -title "Choose a color ..."]
    if {$col eq ""} {return}

    $b configure -bg $col
    set TmpDef(CoulVariable) $col

    update idletasks

    return
}


proc ChangeCouleurAppli {b} {
    global TmpDef

    set OldC [set TmpDef(BackAppli)]
    set col [tk_chooseColor -initialcolor $OldC -title "Choose a color ..."]
    if {$col eq ""} {
	return
    }

    $b configure -bg $col
    set TmpDef(BackAppli) $col

    return
}



proc ChangeCouleur {TypeGrp what LeBouton} {
    # what : fg or bg. The current color is read in CoulTmp
    # (the one given when the button was created may be old)
    global CoulTmp

    lassign [set CoulTmp($TypeGrp)] fg bg

    set NouvelleCouleur [tk_chooseColor -initialcolor [set $what] -title "Choose a color ..."]
    if {$NouvelleCouleur eq ""} {return}

    set $what $NouvelleCouleur
    $LeBouton configure -background $NouvelleCouleur -activebackground $NouvelleCouleur

    # string "fg bg" : read with 'scan %s %s' elsewhere, a list
    # would brace the colors starting with #
    set CoulTmp($TypeGrp) "$fg $bg"

    return
}



proc ClesPreferences {page} {
    # keys of Defauts set in each page of the Preferences
    switch $page {
	"General" {
	    return {SeqFontFaml SeqFontSize SeqFontWght DeltaXScroll DeltaYScroll BackAppli}
	}
	"Sequences" {
	    set Le {RemoveBankPrefix PrefixesBank}
	    foreach d {Eukaryota Archaea Bacteria Viruses} {
		lappend Le Fg$d Bg$d
	    }
	    return $Le
	}
	"Conservation" {
	    return {SimiGris Threshold}
	}
	"Editor" {
	    return {LockSeqs Mapping}
	}
	"3D Display" - "3DDisplay" {
	    set Le {CoulVariable PrecomputeSrf}
	    for {set i 0} {$i < 10} {incr i} {
		lappend Le GammeCoul$i
	    }
	    return $Le
	}
	"Trees" {
	    return {TypeGapTree TypeTree FontSizeTree FontWghtTree TreeBoot}
	}
	"all" {
	    set Le {}
	    foreach p {General Sequences Conservation Editor "3D Display" Trees} {
		lappend Le {*}[ClesPreferences $p]
	    }
	    return $Le
	}
    }

    return {}
}


proc MappingDuType {} {
    # residues mapping for the current type of sequences : the
    # one chosen in the Preferences, or the default one
    global Defauts

    set k [expr {[info exists ::TypeSeq] && $::TypeSeq eq "DNA" ? "MappingDNA" : "MappingProt"}]
    if {[info exists Defauts($k)]} {
	return $Defauts($k)
    }

    return [EditorMappingData]
}


proc ValeursDefautsPreferences {} {
    # default values of the preferences (Defauts and conservation
    # colors), computed without changing the current ones
    global Defauts Couleurs

    array set SvDef [array get Defauts]
    array set SvCou [array get Couleurs]
    ValsDesDefauts
    ValsDeCouleurs
    set res [list [array get Defauts] [array get Couleurs]]
    unset Defauts Couleurs
    array set Defauts  [array get SvDef]
    array set Couleurs [array get SvCou]

    return $res
}


proc TerminatePreferences {w what} {
    global Couleurs Defauts CoulTmp TmpDef TmpMap LesItems PrfListe FrmPref OldPrf

    switch $what {
	"cancel" {
	    TracesFontePrf remove
	    # background changed by 'Apply' : restore it
	    if {$::PrfBackApplied ne $Defauts(BackAppli)} {
		AppliqueCouleurFond $::PrfBackApplied $Defauts(BackAppli)
	    }
	    unset -nocomplain TmpDef TmpMap CoulTmp
	    destroy [winfo toplevel $w]

	    # fonts may have been changed by the General page
	    AppliqueFontesSequences
	}
	"reset" {
	    # default values for the page currently shown
	    lassign [ValeursDefautsPreferences] lDef lCou
	    array set DDef $lDef
	    array set DCou $lCou
	    foreach e [ClesPreferences $OldPrf] {
		set TmpDef($e) $DDef($e)
	    }
	    if {$OldPrf eq "Conservation"} {
		foreach Type [lrange $::TypeCons 0 2] {
		    set CoulTmp($Type) $DCou($Type)
		}
	    }
	    # redraw the page with the new values
	    foreach e [winfo children $FrmPref] {
		destroy $e
	    }
	    EnvoiePrf$OldPrf
	    MesCouleurs $FrmPref
	    AjusteTaillePrf
	}
	"ok" {
	    TracesFontePrf remove
	    set OldBack $Defauts(BackAppli)
	    set OldCol  [array get Couleurs]

	    # only the preferences keys : the other values of Defauts
	    # (current snapshot, display toggles ...) may have changed
	    # while the window was opened
	    foreach e [ClesPreferences all] {
		set Defauts($e) $TmpDef($e)
	    }
	    foreach Type [lrange $::TypeCons 0 2] {
		set Couleurs($Type) $CoulTmp($Type)
	    }
	    # residues mapping : one for proteins, one for DNA/RNA
	    set k [expr {[info exists ::TypeSeq] && $::TypeSeq eq "DNA" ? "MappingDNA" : "MappingProt"}]
	    if {$Defauts(Mapping) ne [EditorMappingData]} {
		set Defauts($k) $Defauts(Mapping)
	    } else {
		unset -nocomplain Defauts($k)
	    }
	    unset -nocomplain TmpDef CoulTmp TmpMap

	    # background : the one really displayed is PrfBackApplied
	    if {$::PrfBackApplied ne $Defauts(BackAppli)} {
		AppliqueCouleurFond $::PrfBackApplied $Defauts(BackAppli)
	    }
	    set Defauts(BackAppliOri) $OldBack

	    destroy [winfo toplevel $w]

	    AppliquePreferences

	    # saved for the next sessions
	    SauveOrdalieDefauts
	}
    }

    update idletasks

    return
}


proc AppliquePreferences {} {
    # apply the preferences to the current display
    global Defauts

    AppliqueFontesSequences
    set ::Threshold $Defauts(Threshold)

    if {[TypeAli] eq "pasdali" || [BiotextsOrdali] eq ""} {
	return
    }

    # residues mapping (editor and physicochemical colouring)
    $::NomTextSeq mapping $Defauts(Mapping)
    # life domain colors
    OrdaliDefaultTags
    RepeintNomsEtSeqs
    ReDessineLesScores

    return
}


proc ChangePreferences {} {

    global Couleurs
    global TypeCons
    global TypeText
    global SphDef
    global Defauts

    set w .tpref
    toplevel $w
    wm title $w "Preferences"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm iconname $w "Preferences"

    set lffont "Helvetica 10 bold"
    set font "Helvetica 10"
    frame $w.colors
    pack $w.colors -side top -fill x -expand 1 -padx 5 -pady 5

    set co 0
    set wmax 0
    foreach Type $TypeCons {
	if {[regexp {^CoulG} $Type]} {break}
	if {$co == "9"} {
	    set co 0
	    incr li
	}
	if {[lsearch $TypeCons $Type] == "3"} {
	    set li 0
	    set lbf [labelframe $w.colors.group -text "Group conservation" -relief groove -font $lffont]
	    pack $lbf -fill x
	    grid rowconfig    $lbf 0 -weight 1 -minsize 0
	    grid columnconfig $lbf 0 -weight 0 -minsize 0
	}
	if {[lsearch $TypeCons $Type] == "0"} {
	    set li 0
	    set lbf [labelframe $w.colors.global -text "Global conservation" -relief groove -bd 2 -font $lffont]
	    pack $lbf -fill x
	    grid rowconfig    $lbf 0 -weight 1 -minsize 0
	    grid columnconfig $lbf 0 -weight 0 -minsize 0
	}
	if {[lsearch $TypeCons $Type] == "9"} {
	    set li 0
	    set lbf [labelframe $w.colors.inter -text "Inter-Group conservation" -font $lffont -relief groove]
	    pack $lbf -fill x
	    grid rowconfig    $lbf 0 -weight 1 -minsize 0
	    grid columnconfig $lbf 0 -weight 0 -minsize 0
	}

	if {[lsearch $TypeCons $Type] == "15"} {
	    set li 0
	    set lbf [labelframe $w.colors.points -text "Points" -relief groove -font $lffont]
	    pack $lbf -fill x
	    grid rowconfig    $lbf 0 -weight 1 -minsize 0
	    grid columnconfig $lbf 0 -weight 0 -minsize 0
	}

	scan [set Couleurs($Type)] "%s %s" fg bg

	label  $w.colors.l$Type -text [set TypeText($Type)] -font $font -anchor w
	grid $w.colors.l$Type -row $li -column [incr co] -in $lbf
	button $w.colors.f$Type -background $fg -activebackground $fg -command "ChangeCouleur $Type $fg $w.colors.f$Type"
	grid $w.colors.f$Type -row $li -column [incr co] -in $lbf
	button $w.colors.b$Type -background $bg -activebackground $bg -command "ChangeCouleur $Type $bg $w.colors.b$Type"
	grid $w.colors.b$Type -row $li -column [incr co] -in $lbf

	set ltxt [string length [$w.colors.l$Type cget -text]]
	if {$wmax < $ltxt} {set wmax $ltxt}
    }

    foreach e [winfo children $w.colors] {
	if {[winfo class $e] == "Label"} {$e configure -width $wmax}
    }
    update


    labelframe $w.control -relief groove -borderwidth 2 -text "Ordali Control Panel" -font $lffont
    grid rowconfig    $w.control 0 -weight 1 -minsize 0
    grid columnconfig $w.control 0 -weight 0 -minsize 0

    label $w.control.sph -text "Spheres volume" -font $font -anchor w
    radiobutton $w.control.sphmean -text "Mean" -font $font -variable SphDef -relief flat -value "Mean" -highlightthickness 0
    radiobutton $w.control.sphhbnd -text "Mean + Hb" -font $font -variable SphDef -relief flat -value "HBond" -highlightthickness 0


    label $w.control.slg -text "Select length" -font $font -anchor w
    radiobutton $w.control.slgy -text "Yes" -font $font \
	    -variable Defauts(SelectionLong) -value "1"
    radiobutton $w.control.slgn -text "No" -font $font \
	    -variable Defauts(SelectionLong) -value "0"

    label $w.control.sln -text "Select name" -font $font -anchor w
    radiobutton $w.control.slny -text "Yes" -font $font \
	    -variable Defauts(SelectionNom) -relief flat -value "1"
    radiobutton $w.control.slnn -text "No" -font $font \
	    -variable Defauts(SelectionNom) -relief flat -value "0"

    label $w.control.chk -text "Check sequences" -font $font -anchor w
    radiobutton $w.control.chky -text "Yes" -font $font \
	    -variable Defauts(CheckSeq) -relief flat -value "1"
    radiobutton $w.control.chkn -text "No" -font $font \
	    -variable Defauts(CheckSeq) -relief flat -value "0"

    label $w.control.grnc -text "Group Consensus 80%" -font $font -anchor w
    radiobutton $w.control.grncy -text "Yes" -font $font \
	    -variable Defauts(ConsNGrp) -relief flat -value "1"
    radiobutton $w.control.grncn -text "No" -font $font \
	    -variable Defauts(ConsNGrp) -relief flat -value "0"


    label $w.control.pds -text "Weighted sequences " -font $font -anchor w
    radiobutton $w.control.pdsy -text "Yes" -font $font\
	    -variable Defauts(Poids) -relief flat -value "1"
    radiobutton $w.control.pdsn -text "No" -font $font\
	    -variable Defauts(Poids) -relief flat -value "0"

    grid $w.control.sph -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sphmean -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sphhbnd -in $w.control -padx 10 -pady 3 \
	    -row 1 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sim -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.simy -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.simn -in $w.control -padx 10 -pady 3 \
	    -row 1 -column 5 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slg -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slgy -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slgn -in $w.control -padx 10 -pady 3 \
	    -row 2 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sln -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slny -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slnn -in $w.control -padx 10 -pady 3 \
	    -row 2 -column 5 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chk -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chky -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chkn -in $w.control -padx 10 -pady 3 \
	    -row 3 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.grnc -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.grncy -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fntl -in $w.control -padx 10 -pady 3 \
	    -row 4 -column 0 -rowspan 1 -columnspan 3 -sticky w
    grid $w.control.ffml -in $w.control -padx 10 -pady 3 \
	    -row 5 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fsiz -in $w.control -padx 10 -pady 3 \
	    -row 5 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fwgh -in $w.control -padx 10 -pady 3 \
	    -row 5 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pds -in $w.control -padx 1 -pady 3 \
	    -row 6 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pdsy -in $w.control -padx 1 -pady 3 \
	    -row 6 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pdsn -in $w.control -padx 10 -pady 3 \
	    -row 6 -column 2 -rowspan 1 -columnspan 1 -sticky w

    pack $w.control -side top -anchor w -padx 5 -pady 5 -fill x -expand 1

    frame $w.btnstrc
    pack $w.btnstrc -side bottom -pady 10
    button $w.btnstrc.cebon -text " OK " -background green1 -command "TermineChangePreferences $w"
    pack $w.btnstrc.cebon -side left

    FenetreAuCentre $w
    MesCouleurs $w

    return
}



proc AncienChangePreferences {} {

    global Couleurs
    global TypeCons
    global TypeText
    global SphDef
    global Defauts

    set w .pref
    toplevel $w
    wm title $w "Preferences"
    wm protocol $w WM_DELETE_WINDOW KillParLaCroix
    wm iconname $w "Preferences"

    frame  $w.colors
    pack $w.colors -side top -fill x
    grid rowconfig    $w.colors 0 -weight 1 -minsize 0
    grid columnconfig $w.colors 0 -weight 0 -minsize 0

    label $w.colors.global -text "Global conservation" -relief sunken
    #    pack $w.colors.global -side top
    grid $w.colors.global -in $w.colors -padx 1 -pady 20 \
	    -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky w

    set EltCo 0
    set EltLi 0
    foreach Type $TypeCons {
	if {$EltCo == "9"} {
	    set EltCo 0
	    incr EltLi
	}

	if {[lsearch $TypeCons $Type] == "3"} {
	    incr EltLi
	    label  $w.colors.group -text "Group conservation"
	    grid $w.colors.group -in $w.colors -padx 1 -pady 10 \
		    -row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	    incr EltLi
	}

	if {[lsearch $TypeCons $Type] == "9"} {
	    incr EltLi
	    label  $w.colors.inter -text "Inter-Group conservation"
	    grid $w.colors.inter -in $w.colors -padx 1 -pady 10 \
		    -row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	    incr EltLi
	}

	if {[lsearch $TypeCons $Type] == "15"} {
	    incr EltLi
	    label  $w.colors.points -text "Points"
	    grid $w.colors.points -in $w.colors -padx 1 -pady 10 \
		    -row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	    incr EltLi
	}

	scan [set Couleurs($Type)] "%s %s" fg bg

	label  $w.colors.l$Type -text [set TypeText($Type)]
	grid $w.colors.l$Type -in $w.colors -padx 1 -pady 1 \
		-row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	incr EltCo

	button $w.colors.f$Type -background $fg -activebackground $fg -command "ChangeCouleur $Type $fg $w.colors.f$Type"
	grid $w.colors.f$Type -in $w.colors -padx 1 -pady 1 \
		-row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	incr EltCo

	button $w.colors.b$Type -background $bg -activebackground $bg -command "ChangeCouleur $Type $bg $w.colors.b$Type"
	grid $w.colors.b$Type -in $w.colors -padx 1 -pady 1 \
		-row $EltLi -column $EltCo -rowspan 1 -columnspan 1 -sticky w
	incr EltCo
    }

    labelframe $w.control -relief groove -borderwidth 2 -text "Ordali Control Panel"
    grid rowconfig    $w.control 0 -weight 1 -minsize 0
    grid columnconfig $w.control 0 -weight 0 -minsize 0

    label $w.control.sph -text "Ordali Spheres"
    radiobutton $w.control.sphmean -text "Mean Volume" -variable SphDef -relief flat -value "Mean"
    radiobutton $w.control.sphhbnd -text "Mean Volume + HB" -variable SphDef -relief flat -value "HBond"

    label $w.control.sim -text "Use similarity"
    radiobutton $w.control.simy -text "Yes" -variable Defauts(SimiGris) -relief flat -value "1"
    radiobutton $w.control.simn -text "No" -variable Defauts(SimiGris) -relief flat -value "0"

    label $w.control.slg -text "Select length"
    radiobutton $w.control.slgy -text "Yes" \
	    -variable Defauts(SelectionLong) -relief flat -value "1"
    radiobutton $w.control.slgn -text "No" \
	    -variable Defauts(SelectionLong) -relief flat -value "0"

    label $w.control.sln -text "Select name"
    radiobutton $w.control.slny -text "Yes" \
	    -variable Defauts(SelectionNom) -relief flat -value "1"
    radiobutton $w.control.slnn -text "No" \
	    -variable Defauts(SelectionNom) -relief flat -value "0"

    label $w.control.chk -text "Check sequences"
    radiobutton $w.control.chky -text "Yes" \
	    -variable Defauts(CheckSeq) -relief flat -value "1"
    radiobutton $w.control.chkn -text "No" \
	    -variable Defauts(CheckSeq) -relief flat -value "0"

    label $w.control.grnc -text "Group Consensus 80%"
    radiobutton $w.control.grncy -text "Yes" \
	    -variable Defauts(ConsNGrp) -relief flat -value "1"
    radiobutton $w.control.grncn -text "No" \
	    -variable Defauts(ConsNGrp) -relief flat -value "0"

    set fontsize [lindex [split $fontext] 1]
    set fontsizeold $fontsize
    if {[lindex [split $fontext] 2] != ""} {
	set fontclas [lindex [split $fontext] 2]
	set fontclasold $fontclas
    } else {
	set fontclas "normal"
    }

    label $w.control.fntl -text "Alignment font : CourierNew "
    tk_optionMenu $w.control.fnts fontsize 6 8 10 12 14
    tk_optionMenu $w.control.fntc fontclas normal bold

    label $w.control.pds -text "Weighted sequences "
    radiobutton $w.control.pdsy -text "Yes" \
	    -variable Defauts(Poids) -relief flat -value "1"
    radiobutton $w.control.pdsn -text "No" \
	    -variable Defauts(Poids) -relief flat -value "0"

    grid $w.control.sph -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sphmean -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sphhbnd -in $w.control -padx 10 -pady 3 \
	    -row 1 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sim -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.simy -in $w.control -padx 1 -pady 3 \
	    -row 1 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.simn -in $w.control -padx 10 -pady 3 \
	    -row 1 -column 5 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slg -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slgy -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slgn -in $w.control -padx 10 -pady 3 \
	    -row 2 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.sln -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slny -in $w.control -padx 1 -pady 3 \
	    -row 2 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.slnn -in $w.control -padx 10 -pady 3 \
	    -row 2 -column 5 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chk -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chky -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.chkn -in $w.control -padx 10 -pady 3 \
	    -row 3 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.grnc -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 3 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.grncy -in $w.control -padx 1 -pady 3 \
	    -row 3 -column 4 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fntl -in $w.control -padx 10 -pady 3 \
	    -row 4 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fnts -in $w.control -padx 10 -pady 3 \
	    -row 4 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.fntc -in $w.control -padx 10 -pady 3 \
	    -row 4 -column 2 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pds -in $w.control -padx 1 -pady 3 \
	    -row 5 -column 0 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pdsy -in $w.control -padx 1 -pady 3 \
	    -row 5 -column 1 -rowspan 1 -columnspan 1 -sticky w
    grid $w.control.pdsn -in $w.control -padx 10 -pady 3 \
	    -row 5 -column 2 -rowspan 1 -columnspan 1 -sticky w

    pack  $w.control -side top -anchor w -padx 10 -pady 10

    frame $w.btnstrc
    pack $w.btnstrc -side bottom -pady 10
    button $w.btnstrc.cebon -text " OK " -background green1 -command "TermineChangePreferences $w"
    pack $w.btnstrc.cebon -side left

    MesCouleurs $w

    return
}


proc AffichePreferences {} {
    global Defauts
    global TmpDef
    global TypeCons
    global Couleurs
    global TypeText

    if {[winfo exists .prf]} {return}

    set oldGrab [grab current]
    if {$oldGrab ne ""} {set oldStatus [grab status $oldGrab]}
    set oldFocus [focus]

    array set TmpDef [array get Defauts]

    toplevel .prf
    wm title .prf "Preferences"
    wm protocol .prf WM_DELETE_WINDOW KillParLaCroix

    frame .prf.fnb
    pack .prf.fnb -side top -expand 1 -fill both

    set w ".prf.fnb.nb"
    NoteBook $w -side top \
	    -activebackground green \
	    -bd 2 -arcradius 4 \
	    -bg [set Defauts(BackAppli)]


    $w insert 0 gen -text "General"
    $w insert 1 col -text "Colors"
    $w insert 2 cns -text "Conservation"
    $w insert 3 dbs -text "Databases"
    $w insert 4 str -text "Structure"

    # Frame General

    set pgen [$w getframe gen]

    label $pgen.lbl -text "Ordalie appearance parameters" -font "Helvetica 14 bold" -anchor w -justify left

    label $pgen.lac -text "Application background color : " -anchor w -justify left
    button $pgen.bac -bg [set TmpDef(BackAppli)] -command "ChangeCouleurAppli $pgen.bac" -height 1
    button $pgen.bca -text "Apply" -bg green1 -command "AppliqueBackColor" -height 1

    label $pgen.whl -text "Mouse Wheel controls :" -anchor w -justify left
    label $pgen.lwy -text "Vertical scrolling " -anchor w -justify left
    entry $pgen.ewy -width 3 -bg white -textvariable TmpDef(DeltaYScroll) -justify right
    label $pgen.wuy -text " line(s)" -anchor w -justify left

    label $pgen.lwx -text "Horizontal scrolling " -anchor w -justify left
    entry $pgen.ewx -width 3 -bg white -textvariable TmpDef(DeltaXScroll) -justify right
    label $pgen.wux -text " character(s)" -anchor w -justify left


    grid $pgen.lbl  -row 0 -column 0 -columnspan 4 -pady {10 20} -sticky ew
    grid $pgen.fntl -row 1 -column 0 -sticky news
    grid $pgen.ffml -row 1 -column 1 -sticky news
    grid $pgen.fsiz -row 1 -column 2 -sticky news
    grid $pgen.fwgh -row 1 -column 3 -sticky news
    grid $pgen.lac  -row 2 -column 0 -columnspan 2 -ipady 30 -sticky ew
    grid $pgen.bac  -row 2 -column 2 -sticky ew
    grid $pgen.bca  -row 2 -column 3 -sticky ew
    grid $pgen.whl  -row 3 -column 0 -columnspan 4 -pady {30 5} -sticky news
    grid $pgen.lwy  -row 4 -column 1 -sticky news
    grid $pgen.ewy  -row 4 -column 2 -sticky news
    grid $pgen.wuy  -row 4 -column 3 -sticky news
    grid $pgen.lwx  -row 5 -column 1 -sticky news
    grid $pgen.ewx  -row 5 -column 2 -sticky news
    grid $pgen.wux  -row 5 -column 3 -sticky news

    # Frame couleurs d'ordalie

    set pcol [$w getframe col]

    # Frame Conservation

    set pcns [$w getframe cns]
    grid columnconfig $pcns {1 2} -weight 1

    label $pcns.lbl -text "Click on the buttons to change the colors assigned\nto the different conservation types" -anchor w -justify left
    set i 0
    foreach Type [lrange $TypeCons 0 2] {
	incr i
	scan [set Couleurs($Type)] "%s %s" fg bg
	label  $pcns.l$Type -text [set TypeText($Type)] -anchor w
	button $pcns.f$Type -bg $fg -activebackground $fg -width 4 -command "ChangeCouleur $Type $fg $pcns.f$Type"
	button $pcns.b$Type -bg $bg -activebackground $bg -width 4 -command "ChangeCouleur $Type $bg $pcns.b$Type"

	grid $pcns.l$Type -row $i -column 0 -sticky w
	grid $pcns.f$Type -row $i -column 1 -sticky w
	grid $pcns.b$Type -row $i -column 2 -sticky w
    }
    grid $pcns.lbl -row 0 -column 0 -columnspan 3 -sticky we -pady {10 0}

    label $pcns.lblm -text "For the Threshold Method :\nDefine the threshold above which a column is said\nto be conserved" -justify left
    label $pcns.sclb -text "Threshold " -anchor w -justify left
    scale $pcns.scal -from 0 -to 100 \
	    -orient horiz -showvalue true \
	    -variable TmpDef(Threshold) \
	    -width 8 -length 75
    grid $pcns.lblm -row 4 -column 0 -columnspan 3 -sticky ew -pady {20 5}

    grid $pcns.sclb -row 5 -column 0 -columnspan 1 -sticky w
    grid $pcns.scal -row 5 -column 1 -columnspan 2 -sticky news

    label $pcns.sim -text "Use similarity" -anchor w -justify left
    radiobutton $pcns.simy -text "Yes" -variable Defauts(SimiGris) -relief flat -value "1"
    radiobutton $pcns.simn -text "No" -variable Defauts(SimiGris) -relief flat -value "0"

    grid $pcns.sim  -row 6 -column 0 -sticky w
    grid $pcns.simy -row 6 -column 1
    grid $pcns.simn -row 6 -column 2

    # Frame Databases

    set pdbs [$w getframe dbs]
    label $pdbs.ldbs -justify left -anchor w -text "Ordalie retrieves some information using distant\n databases. You may change the defaults ones to\n yours. IMPORTANT ! The XXXX stands for the Id\n to be retrieved, and it must be specified in your url !" -font "Helvetica 14 bold"

    label $pdbs.lpdb -text "Protein Data Bank (PDB) location :" -justify left -anchor w
    entry $pdbs.epd1 -bg white -textvariable TmpDef(UrlPdbWorld)
    entry $pdbs.epd2 -bg white -textvariable TmpDef(UrlPdbHome)

    label $pdbs.lsrs -text "Sequence Retrieval System (SRS) location :" -justify left -anchor w
    entry $pdbs.esr1 -bg white -textvariable TmpDef(UrlSRSWorld)
    entry $pdbs.esr2 -bg white -textvariable TmpDef(UrlSRSHome)

    label $pdbs.lbrd -text "Biological Information Retrieval Database (BIRD) location :" -justify left -anchor w
    entry $pdbs.ebr1 -bg white -textvariable TmpDef(UrlPdbHoan)

    grid $pdbs.ldbs -row 0 -column 0 -sticky news -pady {10 5}
    grid $pdbs.lpdb -row 1 -column 0 -sticky news -pady {20 1}
    grid $pdbs.epd1 -row 2 -column 0 -sticky news
    grid $pdbs.epd2 -row 3 -column 0 -sticky news
    grid $pdbs.lsrs -row 4 -column 0 -sticky news -pady {20 1}
    grid $pdbs.esr1 -row 5 -column 0 -sticky news
    grid $pdbs.esr2 -row 6 -column 0 -sticky news
    grid $pdbs.lbrd -row 7 -column 0 -sticky news -pady {20 1}
    grid $pdbs.ebr1 -row 8 -column 0 -sticky news -pady {0 10}

    # Frame Structure

    set pstr [$w getframe str]

    # Fin notebook

    pack $w -fill both -expand yes
    $w compute_size
    $w raise gen

    # Frame boutons OK, Dismiss, etc ...

    frame .prf.fbt -relief flat
    pack .prf.fbt -side bottom -fill x -expand 1
    set w ".prf.fbt"
    button $w.dis -text "Dismiss" -bg red -command [list DismissDefauts .prf]
    button $w.sav -text "Save" -bg yellow -command [list SauveLesDefauts]
    button $w.ok  -text " OK " -bg green1 -command [list AccepteDefauts .prf]
    pack $w.dis $w.sav $w.ok -side left -expand 1 -padx 10 -pady 10

    #    MesCouleurs .prf
    FenetreAuCentre .prf

    grab -global .prf
    focus .prf

    tkwait window .prf

    focus $oldFocus
    if {$oldGrab ne ""} {
	if {$oldStatus eq "global"} {
	    grab -global $oldGrab
	} else {
	    grab $Grab
	}
    }

    return
}


proc TermineChangePreferences {w} {

    global LNDG
    global NomFenetreOrdali
    global Defauts
    global NomTextSeq
    global NomNomSeq
    global WTexteRegle
    global LesPoidsDesSequences

    if {[winfo exists $NomFenetreOrdali.lessequences.tognoms] && ![set Defauts(CheckSeq)]} {
	destroy $NomFenetreOrdali.lessequences.tognoms
    }

    if {![winfo exists $NomFenetreOrdali.lessequences.tognoms] && [set Defauts(CheckSeq)]} {
	button $NomFenetreOrdali.lessequences.tognoms \
		-text "Access/Name" \
		-command "ChangeTypeNom \[$NomFenetreOrdali.lessequences.scrolly get \]" \
		-background green1
	grid $NomFenetreOrdali.lessequences.tognoms \
		-in $NomFenetreOrdali.lessequences -padx 1 -pady 1 \
		-row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
    }

    font configure SeqFont -size [set Defauts(SeqFontSize)] -family [set Defauts(SeqFontFaml)] -weight [set Defauts(SeqFontWght)]

    if {[set Defauts(Poids)]} {
	global LesPoidsDesSequences
	global LesPoidsLus
	set LesPoidsDesSequences $LesPoidsLus
    }

    destroy $w

    update

    return
}

proc tprfed {} {
    global FrmPref

    puts "AffichePreferences2"
    AffichePreferences2

    puts "envoieprdeditor"
    EnvoiePrfEditor

    puts "\nBLIND"
    $FrmPref.fbt.blind invoke
    update idletasks
    puts "defauts invoke"
    $FrmPref.fbt.def invoke
    
    puts "\npress ok"
    $::bok invoke

    return
}


proc tprf {} {
    LoadTkAndPackages
    AffichePreferences2
    
    global TmpDef PrfListe FrmPref LesItems
    puts "prfliste $PrfListe"
    
    foreach p $LesItems {
	puts "prf $p"
	DefinitPrfItem toto $p
	update idletasks
    }
    
    TerminatePreferences .prf.fnb cancel

    return
    exit
}



    
