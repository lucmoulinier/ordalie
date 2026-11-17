# Explorateur récursif (phase 2) :
#   tclsh explore.tcl N ETAT FICHIER LOT SORTIE ?SELECTION?
# Pour chaque entrée de menu du lot (ou la vue principale pour "base"), entre dans
# le contexte (mode ou fenêtres ouverts), puis déclenche chaque widget actif ;
# ce qu'un widget ouvre devient un sous-contexte exploré à son tour (profondeur MaxDepth).
# Entre deux actions : retour à l'état de base, puis rejeu des étapes du contexte.
lassign $argv N state file lot out sel
set H [file dirname [file normalize [info script]]]
source [file join $H walk.tcl]
source [file join $H lots.tcl]
source [file join $H saisies.tcl]
set Port [expr {4500+$N}]
set GuiBase [expr {[info exists env(GUI_BASE)] ? $env(GUI_BASE) : "/home/moumou/.cache/claude-ordalie-tests/audit_gui"}]
set Work [file join $GuiBase inst$N work]
set MaxDepth [expr {[dict exists $Lots $lot depth] ? [dict get $Lots $lot depth] : 3}]
set Seen [dict create]      ;# contextes déjà explorés (signature)
set Done [dict create]      ;# actions déjà faites (contexte|widget|action)
set fo [open $out a]
fconfigure $fo -buffering line
set NAct 0

proc rec {d} {puts $::fo $d}
# phase 3 : contrôles d'état après chaque action (GUI_INVARIANTS=1), sonde de clordali/test/phase3
set Invariants [expr {[info exists env(GUI_INVARIANTS)] && $env(GUI_INVARIANTS)}]
set Sonde /home/moumou/clordali/test/phase3/sonde.tcl
# une action sans erreur qui laisse un état incohérent devient INVARIANT
proc invariants {cls rv} {
    upvar $rv r
    if {! $::Invariants || $cls ni {OK MSG VALID}} {return $cls}
    if {[catch {W::ask ::P3::Invariants} v]} {set v [list "sonde : $v"]}
    if {$v eq ""} {return $cls}
    dict set r invariants $v
    return INVARIANT
}
proc msg {s} {puts "[clock format [clock seconds] -format %T] $::lot/$::state $s"}

# --- instance -------------------------------------------------------------
proc start_instance {} {
    global H N file
    # sortie vers un fichier : sinon exec attend la fermeture du tube, gardé par wish et Xvfb
    set lf [file join [file dirname $::out] start_$N.log]
    catch {exec $H/gui_instance.sh stop $N >& $lf}
    catch {exec $H/gui_instance.sh start $N {*}[expr {$file eq "" ? "" : [list $file]}] >& $lf}
    set fh [open $lf]; msg [string trim [read $fh]]; close $fh
    W::connect $::Port
    if {$::Saisies} {W::ask [list probe::auto 1 $::Donnees $::Work]}
    if {$::Invariants} {W::ask [list source $::Sonde]}
    setup
    set ::Base [dict create tops [W::ask probe::tops] mode [W::ask probe::mode] sigs [sigs .] empreinte [W::ask probe::empreinte]]
}
proc setup {} {
    global sel
    if {$sel ne ""} {
	foreach s $::Selections($sel) {W::fire $s 20000}
    }
}
proc alive {} {
    if {[catch {W::ask {expr 1}}]} {return 0}
    return 1
}
proc sigs {root} {lmap d [W::widgets $root] {W::sig $d}}

# --- retour à l'état de base ----------------------------------------------
set ExitPat {^\s*(return|cancel|dismiss|close|quit|done|ok|exit|save & return)\s*$}
proc closetop {t} {
    foreach d [W::widgets $t] {
	if {[dict exists $d text] && [dict exists $d command] &&
	    [regexp -nocase $::ExitPat [dict get $d text]]} {
	    catch {W::fire [list [dict get $d path] invoke] 15000}
	    if {! [W::ask [list winfo exists $t]]} {return}
	}
    }
    catch {W::ask [list destroy $t]}
}
proc reset {} {
    global Base
    if {! [alive]} {return 0}
    for {set k 0} {$k < 3} {incr k} {
	foreach t [W::ask probe::tops] {
	    # Please Wait appartient à une action qui tourne encore : la détruire laissait
	    # TFAt(WtLabel) sans fenêtre (faux INVARIANT I5, faux .fattendre.f.label)
	    if {$t ni [dict get $Base tops] && $t ne ".fattendre"} {closetop $t}
	}
	if {[W::ask probe::mode] ne [dict get $Base mode] || [W::ask {InSeqlabMode}]} {
	    set ws [W::widgets .ordali]
	    foreach pat {return cancel dismiss done close} {
		set hit 0
		foreach w $ws {
		    if {[dict exists $w text] && [dict exists $w command] &&
			[string equal -nocase [string trim [dict get $w text]] $pat]} {
			catch {W::fire [list [dict get $w path] invoke] 15000}
			set hit 1; break
		    }
		}
		if {$hit} break
	    }
	    if {[W::ask probe::mode] ne [dict get $Base mode]} {
		catch {W::fire [list ChangeMode [dict get $Base mode]] 15000}
	    }
	}
	# actions encore bloquées : leurs fenêtres sont fermées, on les laisse finir
	set running [W::ask {set r {}; foreach {k v} [array get ::probe::A] {if {[dict get $v state] eq "running"} {lappend r $k}}; set r}]
	if {$running eq "" && [W::ask probe::mode] eq [dict get $Base mode] &&
	    [lsort [W::ask probe::tops]] eq [lsort [dict get $Base tops]] && ! [W::ask {InSeqlabMode}]} {
	    return 1
	}
	after 500
    }
    return 0
}
proc ensure_base {} {
    if {! [reset] || ($::Saisies && [W::ask probe::empreinte] ne [dict get $::Base empreinte])} {
	msg "état de base perdu : redémarrage de l'instance"
	rec [dict create kind restart lot $::lot state $::state]
	start_instance
    }
}

# --- actions possibles sur un widget ----------------------------------------
proc actions_of {d} {
    set w [dict get $d path]
    set c [dict get $d class]
    set st [expr {[dict exists $d state] ? [dict get $d state] : "normal"}]
    if {$st eq "disabled"} {return [list [list disabled ""]]}
    switch -- $c {
	Button - TButton - Radiobutton - TRadiobutton {
	    if {[dict exists $d command]} {return [list [list invoke "$w invoke"]]}
	}
	Checkbutton - TCheckbutton {
	    if {[dict exists $d command] || [dict exists $d variable]} {return [list [list toggle "$w invoke"]]}
	}
	Menubutton - TMenubutton {
	    set m ""; catch {set m [W::ask [list $w cget -menu]]}
	    if {$m ne ""} {return [menu_actions $m]}
	}
	Menu {return [menu_actions $w]}
	TCombobox {
	    set l {}
	    set vals [W::ask [list $w cget -values]]
	    # phase 2 : quelques valeurs suffisent, une par séquence multiplie le contexte
	    if {$::Saisies && [llength $vals] > 5} {set vals [concat [lrange $vals 0 2] [lrange $vals end end]]}
	    foreach v $vals {
		lappend l [list "value «$v»" "$w set [list $v]; event generate $w <<ComboboxSelected>>"]
	    }
	    return $l
	}
	Listbox {
	    if {[W::ask [list $w size]] > 0} {
		return [list [list "select first" "$w selection clear 0 end; $w selection set 0; event generate $w <<ListboxSelect>>"]]
	    }
	}
    }
    return {}
}
proc menu_actions {m {pfx ""}} {
    set l {}
    catch {set pc [W::ask [list $m cget -postcommand]]; if {$pc ne ""} {W::ask $pc}}
    foreach e [W::ask [list probe::menuentries $m]] {
	set t [dict get $e type]
	if {$t in {separator tearoff}} continue
	set lab [expr {[dict exists $e label] ? [dict get $e label] : "#[dict get $e i]"}]
	if {$t eq "cascade"} {
	    if {[dict exists $e menu]} {lappend l {*}[menu_actions [dict get $e menu] "$pfx$lab > "]}
	    continue
	}
	if {[dict exists $e state] && [dict get $e state] eq "disabled"} {lappend l [list "menu «$pfx$lab» disabled" ""]; continue}
	lappend l [list "menu «$pfx$lab»" "$m invoke [dict get $e i]"]
    }
    return $l
}

# --- un contexte : liste d'étapes depuis l'état de base -----------------------
# entre dans le contexte ; renvoie {ok roots tops mode} ou {fail raison}
proc enter {steps} {
    ensure_base
    foreach s $steps {
	set r [fire_smart $s]
	if {[dict get $r state] eq "hang"} {return [list fail "hang on [lindex $s 0]"]}
    }
    return [list ok]
}
# fire qui rend la main quand l'action ouvre une fenêtre et l'attend (dialogue)
proc fire_smart {script {ms 180000}} {
    set tops0 [W::ask probe::tops]
    set id [W::ask [list probe::fire $script]]
    set t0 [clock milliseconds]
    set seen 0
    while 1 {
	if {[catch {W::ask [list probe::status $id]} d]} {return [dict create state dead]}
	if {[dict get $d state] eq "done"} {dict set d id $id; return $d}
	if {[dict get $d state] eq "running"} {
	    set new [lmap t [dict get $d tops1] {expr {$t in $tops0 || $t eq ".fattendre" ? [continue] : $t}}]
	    if {$new ne ""} {
		if {$seen == 0} {set seen [clock milliseconds]}
		if {[clock milliseconds]-$seen > 1500} {dict set d state dialog; dict set d id $id; return $d}
	    }
	}
	if {[clock milliseconds]-$t0 > $ms} {dict set d state hang; dict set d id $id; return $d}
	after 100
    }
}
# widgets du contexte : nouveaux par rapport à la base (et au contexte parent)
proc context_widgets {parentsigs} {
    set p [dict create]
    foreach s $parentsigs {dict set p $s 1}
    set l {}
    foreach d [W::widgets .] {
	if {[dict exists $p [W::sig $d]]} continue
	if {[string match .menuBar* [dict get $d path]]} continue
	if {[dict get $d class] in {Scrollbar TScrollbar Toplevel Frame Canvas Text}} continue
	# menu d'un menubutton : traité avec le menubutton
	if {[dict get $d class] eq "Menu" && [W::ask "winfo class \[winfo parent [dict get $d path]\]"] in {Menubutton TMenubutton}} continue
	lappend l $d
    }
    return $l
}
proc wlabel {d} {
    foreach k {text label} {if {[dict exists $d $k] && [string trim [dict get $d $k]] ne ""} {return [string trim [regsub -all {\s+} [dict get $d $k] " "]]}}
    if {[dict exists $d image]} {return "\[img [dict get $d image]\]"}
    return [lindex [split [dict get $d path] .] end]
}
proc isexit {d} {expr {[dict exists $d text] && [regexp -nocase $::ExitPat [dict get $d text]]}}

# explore un contexte décrit par ses étapes
proc explore {ctxname steps depth parentsigs {force 0} {skipws {}}} {
    global Seen Done MaxDepth
    set e [enter $steps]
    if {[lindex $e 0] ne "ok"} {
	rec [dict create kind ctxfail ctx $ctxname reason [lindex $e 1]]
	return
    }
    set ws [context_widgets $parentsigs]
    set csig [lsort [lmap d $ws {regsub -all {\d+} [W::sig $d] N}]]
    set key "$ctxname|[join [lrange $csig 0 40] ,]"
    set ctxsig [lsort [lmap d $ws {regsub -all {\d+} "[dict get $d class]|[wlabel $d]" N}]]
    set ws [lmap d $ws {expr {[dict get $d path] in $skipws ? [continue] : $d}}]
    set champs [expr {$::Saisies ? [W::ask [list probe::champs [lmap x $parentsigs {lindex [split $x |] 0}]]] : {}}]
    if {! $force && [dict exists $Seen $ctxsig]} {
	rec [dict create kind ctxseen ctx $ctxname same [dict get $Seen $ctxsig]]
	return
    }
    dict set Seen $ctxsig $ctxname
    set mode [W::ask probe::mode]
    set tops [W::ask probe::tops]
    rec [dict create kind ctx ctx $ctxname depth $depth mode $mode tops $tops nwidgets [llength $ws] \
	     widgets [lmap d $ws {list [dict get $d path] [dict get $d class] [wlabel $d] [expr {[dict exists $d command] ? [dict get $d command] : ""}]}]]
    msg "contexte «$ctxname» : [llength $ws] widgets (profondeur $depth)"
    set allsigs [concat $parentsigs [lmap d $ws {W::sig $d}]]
    # sorties en dernier
    set ws [concat [lmap d $ws {expr {[isexit $d] ? [continue] : $d}}] [lmap d $ws {expr {[isexit $d] ? $d : [continue]}}]]
    set first 1
    foreach d $ws {
	if {[catch {actions_of $d} acts]} {
	    rec [dict create kind action ctx $ctxname depth $depth widget [dict get $d path] class [dict get $d class] label [wlabel $d] action list result vanished]
	    continue
	}
	foreach a $acts {
	    lassign $a aname script
	    set akey "[regsub -all {\d+} $ctxname N]|[wlabel $d]|$aname"
	    if {[dict exists $Done $akey]} continue
	    dict set Done $akey 1
	    set r [dict create kind action ctx $ctxname depth $depth widget [dict get $d path] class [dict get $d class] \
		       label [wlabel $d] action $aname command [expr {[dict exists $d command] ? [dict get $d command] : ""}]]
	    if {$script eq ""} {dict set r result disabled; rec $r; continue}
	    if {$::Saisies} {
		lassign [valeurs_valides $champs $d] vals resume
		set script "probe::remplit [list $vals] [list [dict get $::Base tops]]; $script"
		if {$resume ne ""} {dict set r saisies $resume}
	    }
	    if {[catch {do_action $ctxname $steps $depth $parentsigs $allsigs $skipws $d $aname $script $r first} err]} {
		if {[alive]} {error $err $::errorInfo}
		dict set r result DEAD
		dict set r errorInfo "instance morte : $err"
		rec $r
		msg "  DEAD     [wlabel $d] / $aname"
		start_instance
		set first 0
	    }
	}
    }
    if {$::Saisies} {saisies_invalides $ctxname $steps $depth $parentsigs $allsigs $skipws $ws $champs first}
}
# pour chaque champ, les valeurs invalides, avec les autres champs valides, puis validation
proc saisies_invalides {ctxname steps depth parentsigs allsigs skipws ws champs firstvar} {
    upvar $firstvar first
    set d ""
    foreach x $ws {if {[est_validation $x]} {set d $x; break}}
    if {$d eq "" || ! [llength $champs]} return
    foreach c [lrange $champs 0 7] {
	foreach v [valeurs_invalides $c] {
	    set aname "invalide «$v» dans [nom_champ $c]"
	    set akey "[regsub -all {\d+} $ctxname N]|$aname"
	    if {[dict exists $::Done $akey]} continue
	    dict set ::Done $akey 1
	    if {[genre $c] in {accessions idstruct} && ! [prend_reseau [genre $c]]} continue
	    lassign [valeurs_valides $champs $d] vals
	    dict set vals [dict get $c path] $v
	    set script "probe::remplit [list $vals] [list [dict get $::Base tops]]; [dict get $d path] invoke"
	    set r [dict create kind action ctx $ctxname depth $depth widget [dict get $d path] class [dict get $d class] \
		       label [wlabel $d] action $aname command [expr {[dict exists $d command] ? [dict get $d command] : ""}] saisies invalide]
	    if {[catch {do_action $ctxname $steps $depth $parentsigs $allsigs $skipws $d $aname $script $r first} err]} {
		if {[alive]} {error $err $::errorInfo}
		dict set r result DEAD
		dict set r errorInfo "instance morte : $err"
		rec $r
		start_instance
		set first 0
	    }
	}
    }
}
proc do_action {ctxname steps depth parentsigs allsigs skipws d aname script r firstvar} {
    global MaxDepth
    upvar $firstvar first
	    # contexte propre avant chaque action (sauf la première juste après enter)
	    if {! $first} {
		set e [enter $steps]
		if {[lindex $e 0] ne "ok"} {dict set r result ctxlost; rec $r; return}
		if {! [W::ask [list winfo exists [dict get $d path]]]} {dict set r result vanished; rec $r; return}
	    }
	    set first 0
	    set tops0 [W::ask probe::tops]
	    set mode0 [W::ask probe::mode]
	    set sigs0 [sigs .]
	    set caught0 [W::ask {dict size $::probe::Seen}]
	    set res [fire_smart $script]
	    incr ::NAct
	    if {[dict get $res state] eq "dead"} {
		dict set r result DEAD
		rec $r
		msg "instance morte après [dict get $r label] / $aname"
		start_instance
		set first 0
		return
	    }
	    set tops1 [W::ask probe::tops]
	    set mode1 [W::ask probe::mode]
	    set newtops [lmap t $tops1 {expr {$t in $tops0 ? [continue] : $t}}]
	    dict set r state [dict get $res state]
	    foreach k {code ms errorInfo dialogs bgerrors stack} {if {[dict exists $res $k]} {dict set r $k [dict get $res $k]}}
	    dict set r newtops [lmap t $newtops {list $t [W::ask [list wm title $t]]}]
	    dict set r mode $mode0->$mode1
	    dict set r caught [expr {[W::ask {dict size $::probe::Seen}] - $caught0}]
	    # classement
	    set cls OK
	    if {[dict get $res state] eq "hang"} {set cls HANG}
	    if {[dict exists $res code] && [dict get $res code] == 1} {set cls ERROR}
	    if {[dict exists $res bgerrors]} {set cls BGERROR}
	    if {$cls eq "OK" && [dict exists $res dialogs]} {set cls [classe_msg $res]}
	    set cls [invariants $cls r]
	    dict set r result $cls
	    rec $r
	    msg "  [format %-8s $cls] [wlabel $d] / $aname[expr {$newtops ne "" ? " -> $newtops" : ""}][expr {$mode1 ne $mode0 ? " -> mode $mode1" : ""}]"
	    if {$cls eq "HANG"} {start_instance; set first 0; return}
	    # sous-contexte : nouvelle fenêtre ou nouveau mode
	    set sub "$ctxname > [wlabel $d][expr {$aname eq "invoke" || $aname eq "toggle" ? "" : " / $aname"}]"
	    # le panneau a changé (nouveaux widgets, nouvelles valeurs) sans nouvelle fenêtre ni mode
	    set changed 0
	    if {$newtops eq "" && $mode1 eq $mode0} {
		set s0 [dict create]; foreach x $sigs0 {dict set s0 $x 1}
		foreach x [sigs .] {if {! [dict exists $s0 $x] && ! [string match .menuBar* $x]} {set changed 1; break}}
	    }
	    if {[string match "invalide *" $aname]} {
		if {$newtops ne "" || $mode1 ne $mode0} {ensure_base; set first 0}
	    } elseif {$depth < $MaxDepth && ($newtops ne "" || $mode1 ne $mode0) && (! [isexit $d] || ($::Saisies && $newtops ne "" && [est_validation $d]))} {
		explore $sub [concat $steps [list $script]] [expr {$depth+1}] $allsigs
		set first 0
	    } elseif {$depth < $MaxDepth && ! [isexit $d] && $cls in {OK MSG} &&
		      ([dict get $d class] in {TCombobox Listbox} || $changed)} {
		# même contexte, dans l'état laissé par l'action : on reteste les autres widgets
		explore $sub [concat $steps [list $script]] [expr {$depth+1}] $parentsigs 1 [concat $skipws [list [dict get $d path]]]
		set first 0
	    } elseif {[dict get $d class] in {Checkbutton TCheckbutton}} {
		# case à cocher : on la remet dans son état
		catch {fire_smart $script 20000}
	    }
}

# --- lot ---------------------------------------------------------------------
start_instance
set L [dict get $Lots $lot]
set t0 [clock seconds]
rec [dict create kind lot lot $lot state $state file $file sel $sel base [dict get $Base mode]]
if {[dict exists $L items]} {
    set items [W::menuitems]
    foreach it $items {
	set ok 0
	foreach pfx [dict get $L items] {if {[string match "$pfx*" [dict get $it path]]} {set ok 1}}
	if {[dict exists $L skip]} {foreach s [dict get $L skip] {if {[string match "$s*" [dict get $it path]]} {set ok 0}}}
	if {! $ok} continue
	set script "[dict get $it menu] invoke [dict get $it index]"
	# l'entrée de menu elle-même est une action du contexte de base
	ensure_base
	set tops0 [W::ask probe::tops]; set mode0 [W::ask probe::mode]
	set res [fire_smart $script]
	set r [dict create kind action ctx MENU depth 0 widget [dict get $it menu] class MenuEntry label [dict get $it path] \
		   action menu command [dict get $it command] accel [dict get $it accel] state [dict get $res state]]
	foreach k {code ms errorInfo dialogs bgerrors stack} {if {[dict exists $res $k]} {dict set r $k [dict get $res $k]}}
	set cls OK
	if {[dict get $res state] eq "dead"} {set cls DEAD} elseif {[dict get $res state] eq "hang"} {set cls HANG}
	if {[dict exists $res code] && [dict get $res code] == 1} {set cls ERROR}
	if {[dict exists $res bgerrors]} {set cls BGERROR}
	if {$cls eq "OK" && [dict exists $res dialogs]} {set cls [classe_msg $res]}
	if {$cls in {DEAD HANG}} {dict set r result $cls; rec $r; start_instance; continue}
	set tops1 [W::ask probe::tops]; set mode1 [W::ask probe::mode]
	set newtops [lmap t $tops1 {expr {$t in $tops0 ? [continue] : $t}}]
	dict set r newtops [lmap t $newtops {list $t [W::ask [list wm title $t]]}]
	dict set r mode $mode0->$mode1
	set cls [invariants $cls r]
	dict set r result $cls
	rec $r
	msg "[format %-8s $cls] [dict get $it path][expr {$newtops ne "" ? " -> $newtops" : ""}][expr {$mode1 ne $mode0 ? " -> mode $mode1" : ""}]"
	if {$newtops ne "" || $mode1 ne $mode0} {
	    if {[catch {explore [dict get $it path] [list $script] 1 [dict get $Base sigs]} err]} {
		rec [dict create kind ctxfail ctx [dict get $it path] reason $err]
		msg "contexte [dict get $it path] interrompu : $err"
		if {! [alive]} {start_instance}
	    }
	}
    }
}
if {[dict exists $L base]} {
    # widgets de la vue principale (hors menus)
    ensure_base
    explore "Vue principale" {} 1 {}
}
if {[dict exists $L scenarios]} {
    foreach {name sc} [dict get $L scenarios] {
	ensure_base
	set res [fire_smart [string map [list @WORK@ $Work @TEST@ /home/moumou/clordali/test] $sc] 300000]
	set r [dict create kind scenario name $name state [dict get $res state]]
	foreach k {code ms result errorInfo dialogs bgerrors} {if {[dict exists $res $k]} {dict set r $k [dict get $res $k]}}
	set cls OK
	if {[dict get $res state] in {hang dead}} {set cls [string toupper [dict get $res state]]}
	if {[dict exists $res code] && [dict get $res code] == 1} {set cls ERROR}
	if {[dict exists $res bgerrors]} {set cls BGERROR}
	dict set r result $cls
	rec $r
	msg "[format %-8s $cls] scénario $name : [string range [expr {[dict exists $res result] ? [dict get $res result] : ""}] 0 150]"
	if {$cls in {HANG DEAD}} {start_instance}
    }
}
if {[dict exists $L bindings]} {
    # liaisons souris et clavier des zones de noms et de séquences
    foreach var [dict get $L bindings] {
	ensure_base
	set w [W::ask [list set ::$var]]
	set acts {}
	foreach tag [W::ask [list bindtags $w]] {
	    if {$tag in {all . Text}} continue
	    foreach ev [W::ask [list bind $tag]] {
		set g "$w see 1.0; "
		if {[regexp {Motion} $ev]} {
		    regexp {B(\d)} $ev -> b
		    if {[info exists b]} {append g "event generate $w <ButtonPress-$b> -x 30 -y 25; event generate $w $ev -x 90 -y 60; event generate $w <ButtonRelease-$b> -x 90 -y 60"; unset b} else {append g "event generate $w $ev -x 60 -y 40"}
		} elseif {[regexp {Button|^<\d>|-\d>$} $ev]} {
		    append g "event generate $w $ev -x 40 -y 25"
		} elseif {[regexp {Key} $ev]} {
		    append g "focus -force $w; update; event generate $w $ev"
		} else {
		    append g "event generate $w $ev -x 40 -y 25"
		}
		lappend acts [list "$var $tag $ev" $g]
	    }
	}
	foreach a $acts {
	    lassign $a aname script
	    ensure_base
	    set tops0 [W::ask probe::tops]; set mode0 [W::ask probe::mode]
	    set res [fire_smart $script 60000]
	    incr ::NAct
	    set r [dict create kind action ctx "Souris/clavier" depth 1 widget $w class Binding label $aname action event command $script state [dict get $res state]]
	    foreach k {code ms errorInfo dialogs bgerrors stack} {if {[dict exists $res $k]} {dict set r $k [dict get $res $k]}}
	    set cls OK
	    if {[dict get $res state] in {hang dead}} {set cls [string toupper [dict get $res state]]}
	    if {[dict exists $res code] && [dict get $res code] == 1} {set cls ERROR}
	    if {[dict exists $res bgerrors]} {set cls BGERROR}
	    if {$cls eq "OK" && [dict exists $res dialogs]} {set cls MSG}
	    dict set r result $cls
	    if {$cls in {HANG DEAD}} {rec $r; start_instance; continue}
	    set newtops [lmap t [W::ask probe::tops] {expr {$t in $tops0 ? [continue] : $t}}]
	    dict set r newtops $newtops
	    dict set r mode $mode0->[W::ask probe::mode]
	    rec $r
	    msg "  [format %-8s $cls] $aname[expr {$newtops ne "" ? " -> $newtops" : ""}]"
	    # menu contextuel ouvert : chacune de ses entrées
	    foreach t $newtops {
		if {[W::ask [list winfo class $t]] ne "Menu"} continue
		foreach ma [menu_actions $t] {
		    lassign $ma mname mscript
		    if {$mscript eq ""} continue
		    ensure_base
		    fire_smart $script 60000
		    set res [fire_smart "$t unpost; $mscript" 120000]
		    incr ::NAct
		    set r [dict create kind action ctx "Souris/clavier > $aname" depth 2 widget $t class Menu label $mname action menu command $mscript state [dict get $res state]]
		    foreach k {code ms errorInfo dialogs bgerrors stack} {if {[dict exists $res $k]} {dict set r $k [dict get $res $k]}}
		    set cls OK
		    if {[dict get $res state] in {hang dead}} {set cls [string toupper [dict get $res state]]}
		    if {[dict exists $res code] && [dict get $res code] == 1} {set cls ERROR}
		    if {[dict exists $res bgerrors]} {set cls BGERROR}
		    if {$cls eq "OK" && [dict exists $res dialogs]} {set cls MSG}
		    dict set r result $cls
		    rec $r
		    msg "    [format %-8s $cls] $mname"
		    if {$cls in {HANG DEAD}} {start_instance}
		}
	    }
	}
    }
}
rec [dict create kind end lot $lot state $state actions $::NAct secs [expr {[clock seconds]-$t0}]]
msg "fin : $::NAct actions en [expr {[clock seconds]-$t0}] s"
catch {exec $H/gui_instance.sh stop $N >& /dev/null}
close $fo
