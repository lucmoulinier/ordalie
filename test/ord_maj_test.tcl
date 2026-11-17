# Contrôle d'un ORD de tutoriel : ouverture, chaque instance, structures secondaires affichées,
# viewer 3D, puis sauvegarde et réouverture.
# Usage : tclsh8.6 test/ord_maj_test.tcl fichier.ord [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set Ficord [file normalize [lindex $argv 0]]
set N [expr {$argc > 1 ? [lindex $argv 1] : 6}]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 400]"
    if {! $ok} {incr ::Echecs}
}
proc Start {f} {
    exec $::P/gui_instance.sh start $::N $f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    # lignes couvertes par le tag : {nom nb}
    W::ask {proc ::NbTag {t nom} {
	set l [expr {[lsearch -exact $::LNOrdali $nom]+1}]
	llength [lmap x [$::NomTextSeq tag ranges $t] {if {[lindex [split $x .] 0] == $l} {set x} else continue}]
    }}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 240000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
}
# {instance {nom {Hel n She n Tur n}}...}
proc Releve {} {
    set Res [dict create]
    foreach m [W::ask {LesMacs}] {
	set court [lindex $m 0]
	F "instance $court" [list apply {{m} {set ::MacChoisi $m; MiseAJourMac}} $m] 120000
	V "$court : Please Wait fermée" {! [W::ask {winfo exists .fattendre}]}
	set Lp [W::ask {set ::ListePDB}]
	V "$court : ListePDB incluse dans l'instance" {[W::ask {llength [lmap n $::ListePDB {if {$n in $::LNOrdali} continue; set n}]}] == 0} $Lp
	foreach n $Lp {
	    set c [list Hel [W::ask "NbTag Hel $n"] She [W::ask "NbTag She $n"] Tur [W::ask "NbTag Tur $n"]]
	    dict set Res $court $n $c
	    puts "  $court $n : $c"
	    V "$court $n : nom coloré" {[W::ask "expr {\[lsearch -exact \[\$::NomNomSeq tag ranges PDB\] \[expr {\[lsearch -exact \$::LNOrdali $n\]+1}\].0\] >= 0}"]}
	    V "$court $n : hélices et brins affichés" {[dict get $c Hel] > 0 && [dict get $c She] > 0} $c
	}
    }
    return $Res
}

Start $Ficord
puts "Defauts(FichierORD) = [W::ask {set ::Defauts(FichierORD)}]"
puts "instances : [W::ask LesMacs]"
puts "arbres : [W::ask {expr {[info exists ::Abr(Liste)] ? $::Abr(Liste) : {}}}]"
set R1 [Releve]
F "viewer 3D" VisualiseStructure
V "viewer ouvert" {[W::ask {winfo exists .ordogl}]}
F "fermeture viewer" QuitteViandox
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] ordmaj_[pid]]
file mkdir $Tmp
F "sauvegarde" [list ordfile::CreeLeORD $Tmp/s.ord]
Stop
Start $Tmp/s.ord
set R2 [Releve]
# l'ordre de ListePDB suit celui des structures dans le fichier
proc Trie {R} {dict map {m v} $R {lsort -stride 2 $v}}
V "aller-retour : mêmes structures secondaires" {[Trie $R1] eq [Trie $R2]}
Stop
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
