# Test des corrections de l'audit GUI (reports/BUGS.md) : B1, B2, B3, B5, B6, B7.
# Lance ses propres instances via le banc ~/.cache/claude-ordalie-tests/probe.
# Usage : tclsh8.6 test/audit_corrections_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set D [expr {[info exists env(GUI_BASE)] ? $env(GUI_BASE) : "$env(HOME)/.cache/claude-ordalie-tests/audit_gui"}]/inst$N
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {res} {expr {[dict get $res state] ne "done" || [dict get $res code] != 0 || [dict exists $res bgerrors] && [dict get $res bgerrors] ne ""}}
proc NbSeq {} {W::ask {llength [lmap x $::LNOrdali {if {[string trim $x] eq ""} continue; set x}]}}

# B7 : sans fichier
Start
foreach {nom cmd} {
    Close {FermeFichier nosave}
    "Log console" {ToggleAuLog; ToggleAuLog}
    Reset {MiseAJourMac reset}
    Info InfosDuMac
    Overwrite {SauveLeMac 0}
    Annotations {AfficheSnapshotAnnotations}
    "New instance" {SauveLeMac 1}
} {
    set r [W::fire $cmd 15000]
    V "B7 sans fichier : $nom" {![Err $r]} [expr {[Err $r] ? $r : ""}]
}
Stop

Start $Test/D_maj.tfa
# B1
W::ask {ChangeMode donnepci; SelectionneToutesColonnes; list}
set n0 [W::ask {llength [$::NomTextSeq tag ranges slct]}]
for {set i 0} {$i < 6} {incr i} {
    W::fire {.ordali.fbout.fpci.falcl.cft set None; event generate .ordali.fbout.fpci.falcl.cft <<ComboboxSelected>>} 30000
}
set n1 [W::ask {llength [$::NomTextSeq tag ranges slct]}]
V "B1 plages slct stables" {$n0 > 0 && $n0 == $n1} "$n0 -> $n1"
W::ask {DeselectToutesLesColonnes; ChangeMode feature; list}

# B3 : ALN écrit puis relu, ancien format (noms alignés à droite) compris
set n0 [NbSeq]
set a $D/work/o.aln
set r [W::ask "EcritLeAln $a \$::LNOrdali \$::LSOrdali; DecortiqueUnALN $a Ln Ts; set dif {}; foreach n \$::LNOrdali s \$::LSOrdali {set n \[string trim \$n\]; if {\$n eq {}} continue; if {!\[info exists Ts(\$n)\] || \[string map {Z - . -} \$Ts(\$n)\] ne \[string map {Z - . -} \$s\]} {lappend dif \$n}}; list \[llength \$Ln\] \$dif"]
V "B3 ALN relu : toutes les séquences" {[lindex $r 0] == $n0} "$r / $n0"
V "B3 ALN relu : contenu identique" {[lindex $r 1] eq ""} [lrange [lindex $r 1] 0 5]
set old [W::ask "set f \[open $a\]; set t \[read \$f\]; close \$f; set f \[open $a.old w\]; foreach l \[split \$t \\n\] {if {\[regexp {^(\\S+)( +\\S+)\$} \$l m x y\]} {puts \$f \"    \$l\"} else {puts \$f \$l}}; puts \$f {          ***:: ..}; close \$f; DecortiqueUnALN $a.old L2 T2"]
V "B3 ancien ALN (noms à droite + consensus)" {$old == $n0} "$old / $n0"

# B5
W::ask {ChangeMode search; list}
set r [W::fire {set ::Chrc(Motif) ""; catch {unset ::Chrc(NextOc)}; ChercheMotifSuivant} 10000]
V "B5 Find Next sans motif" {![Err $r]} [expr {[Err $r] ? $r : ""}]
W::ask {ChangeMode feature; list}
Stop

# B2 + B6 : ORD avec tables obj_*
foreach f {R_tutorial.ord T_tutorial.ord} {
    Start $Test/$f
    set r [W::fire VisualiseStructure 120000]
    V "B2 3D sur $f" {![Err $r]} [expr {[Err $r] ? $r : ""}]
    V "B2 pas de Please Wait $f" {![W::ask {winfo exists .fattendre}]}
    set mols [W::ask {set ::Liste3dMol}]
    V "B2 molécules $f" {[llength $mols] > 0} $mols
    if {$f eq "T_tutorial.ord"} {
	W::ask "probe::answer tk_chooseColor #12ab34; DefineNewObj [lindex $mols 0]; set ::NwOj(ColorSel) {more ...}; set ::NwOj(Chain) \[lindex \[lsort \[array names ::NwOjR\]\] 0\]; regsub {,.*} \$::NwOj(Chain) {} ::NwOj(Chain); list"
	set r [W::fire {ColorChainNwOj all} 15000]
	V "B6 more ... puis All" {![Err $r]} [expr {[Err $r] ? $r : ""}]
	V "B6 couleur posée" {[W::ask {set e [lindex [array names ::NwOjR "$::NwOj(Chain),*"] 0]; lindex $::NwOjR($e) 2}] eq "#12ab34"}
	W::ask {FinNewObj dismiss; list}
    }
    Stop
}
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
