# Test de la fermeture et de la réouverture d'un fichier (bug C9) : Reload, Reset et Close puis Open
# rendent le même état qu'une ouverture neuve, à partir de n'importe quelle instance.
# Usage : tclsh8.6 test/reouverture_ord_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 7}]
set Test [file dirname [file normalize [info script]]]
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
    # état observable du fichier ouvert
    W::ask {proc ::Etat {} {
	global HashPDB
	dict create \
	    mac [MacCourant name] \
	    seqs [llength $::LNOrdali] \
	    noms [lsort $::LNOrdali] \
	    ListePDB [lsort $::ListePDB] \
	    structs [lsort [info class instances Structure]] \
	    hash [expr {[info exists HashPDB] ? [lsort [lmap m [info class instances Structure] {info exists HashPDB([string trimleft $m :])}]] : "absente"}] \
	    iHmax [expr {[info exists HashPDB(iHmax)] ? $HashPDB(iHmax) : "absent"}] \
	    instances [LesMacs] \
	    features [lsort $::ListeTypesDeFeatures] \
	    arbres [expr {[info exists ::Abr(Liste)] ? $::Abr(Liste) : {}}]
    }}
}
proc Stop {} {
    catch {close $W::ch}; set W::ch ""
    exec $::P/gui_instance.sh stop $::N </dev/null >@stdout 2>@stderr
    after 1000
}
proc Err {r} {expr {[dict get $r state] ne "done" || [dict get $r code] != 0 || [dict exists $r bgerrors]}}
proc F {tag cmd {ms 300000}} {
    set r [W::fire $cmd $ms]
    V "$tag : sans erreur" {! [Err $r]} [expr {[Err $r] ? $r : ""}]
}
# compare deux états, clé par clé
proc Same {tag a b} {
    dict for {k v} $a {
	V "$tag : $k identique" {[dict get $b $k] eq $v} [expr {[dict get $b $k] eq $v ? "" : "attendu <$v> obtenu <[dict get $b $k]>"}]
    }
}
proc Super {tag} {
    F "$tag : mode superposition" {ChangeMode superpose}
    F "$tag : retour au mode normal" {ChangeMode ordali}
}

# SEUL=autre : seulement le changement de fichier (bug C10, plus rapide)
foreach f [expr {[info exists env(SEUL)] ? {} : {R_tutorial_maj.ord T_tutorial_maj.ord}}] {
    puts "=== $f"
    Start $Test/$f
    set E0 [W::ask Etat]
    V "$f : des structures sont chargées" {[llength [dict get $E0 ListePDB]] > 0}
    Super "$f ouverture"
    # une ouverture neuve sert de référence
    set Em0 [dict get $E0 mac]
    F "$f : Reload" ReLoadFichier
    Same "$f Reload" $E0 [W::ask Etat]
    Super "$f Reload"
    F "$f : Reset" {MiseAJourMac reset}
    Same "$f Reset" $E0 [W::ask Etat]
    F "$f : Close" {FermeFichier nosave}
    V "$f Close : plus de structure" {[W::ask {llength [info class instances Structure]}] == 0} [W::ask {info class instances Structure}]
    set ff [W::ask {set ::Defauts(FichierORD)}]
    F "$f : Open" [list OuvrirFichierAlignementDansOrdali Unk [expr {$ff ne "" ? $ff : "$Test/$f"}]]
    Same "$f Close Open" $E0 [W::ask Etat]
    Super "$f Close Open"
    # depuis une autre instance
    foreach m [lrange [dict get $E0 instances] 1 end] {
	if {$m eq $Em0} continue
	F "$f : instance $m" [list MiseAJourMac x $m]
	set Ei [W::ask Etat]
	F "$f $m : Reset" {MiseAJourMac reset}
	Same "$f $m Reset" $Ei [W::ask Etat]
	F "$f $m : Reload" ReLoadFichier
	Same "$f depuis $m Reload" $E0 [W::ask Etat]
    }
    Stop
}

# Close puis Open d'un autre fichier : rien du premier ne reste
puts "=== changement de fichier"
Start $Test/R_tutorial_maj.ord
set r [W::ask {lindex [LesMacs] end}]
F "instance $r" [list MiseAJourMac x $r]
F "Close" {FermeFichier nosave}
V "Close : plus de structure" {[W::ask {llength [info class instances Structure]}] == 0} [W::ask {info class instances Structure}]
# chaque structure a sa base sqlite en mémoire, qui doit partir avec elle
V "Close : plus de base de structure" {[W::ask {llength [info commands OrdDB_root_pdb*]}] == 0} [W::ask {info commands OrdDB_root_pdb*}]
F "Open T_tutorial_maj.ord" [list OuvrirFichierAlignementDansOrdali Unk $Test/T_tutorial_maj.ord]
set E1 [W::ask Etat]
# l'ORD sauvé ne contient que les structures du fichier ouvert
set Sortie [file join [W::ask {pwd}] c10_sortie.ord]
F "Sauve l'ORD" [list ordfile::CreeLeORD $Sortie]
set Sauvees [lsearch -all -inline -not -exact [lsort [lmap e [split [string trim [exec tar tzf $Sortie]] "\n"] {file rootname $e}]] main]
file delete $Sortie
V "ORD sauvé : pas de structure de l'autre fichier" {$Sauvees eq [lsort [lmap m [dict get $E1 structs] {string trimleft $m :}]]} "contenu <$Sauvees>"
V "ORD sauvé : pas de 1IQ0 (R_tutorial)" {"1IQ0" ni $Sauvees} "contenu <$Sauvees>"
Stop
Start $Test/T_tutorial_maj.ord
set E2 [W::ask Etat]
Stop
Same "autre fichier" $E2 $E1

puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
