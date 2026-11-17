# Test des structures CIF ajoutées dans T_tutorial.ord : le nom de la séquence insérée
# (Q9BW92_A) est coloré comme structure, à l'ajout, au changement d'instance et après réouverture.
# Usage : tclsh8.6 test/cif_noms_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
set Test [file dirname [file normalize [info script]]]
set P $env(HOME)/.cache/claude-ordalie-tests/probe
set Echecs 0
proc V {tag ok {info ""}} {
    set ok [uplevel 1 [list expr $ok]]
    puts "[expr {$ok ? {OK  } : {FAIL}}] $tag [string range $info 0 300]"
    if {! $ok} {incr ::Echecs}
}
proc Start {{f ""}} {
    exec $::P/gui_instance.sh start $::N {*}$f </dev/null >@stdout 2>@stderr
    W::connect [expr {4500+$::N}]
    # nom coloré : le tag PDB couvre la ligne de ce nom
    W::ask {proc ::Colore {nom} {
	set l [expr {[lsearch -exact $::LNOrdali $nom]+1}]
	expr {$l > 0 && [lsearch -exact [$::NomNomSeq tag ranges PDB] $l.0] >= 0}
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
    return $r
}
proc Instance {nom} {F "instance $nom" [list apply {{nom} {
    set ::MacChoisi [lsearch -inline [LesMacs] "$nom -*"]
    MiseAJourMac
}} $nom] 60000}
proc AjouteCif {f} {
    W::fire {AjouteSequenceOrPDB pdbfile} 5000
    W::ask [list set ::TAddS(StrucFileIn) $::Test/$f]
    set r [F "ajout $f" {.was.fbut.ok invoke}]
    V "ajout $f : Please Wait fermée" {! [W::ask {winfo exists .fattendre}]}
    return $r
}
proc Dans {nom} {W::ask "expr {{$nom} in \$::LNOrdali}"}

set Q9 AF-Q9BW92-F1-model_v6.cif
set E9 AF-E9AEW4-F1-model_v6.cif
set Tmp [file join [expr {[info exists env(TMPDIR)] ? $env(TMPDIR) : "/tmp"}] cifnoms_[pid]]
file mkdir $Tmp
set ord $Tmp/t.ord

Start $Test/T_tutorial.ord
# Q9BW92_A est déjà dans M4 de ce fichier
Instance M4
V "M4 : Q9BW92_A présente" {[Dans Q9BW92_A]}
V "M4 : Q9BW92_A colorée après changement d'instance" {[W::ask {Colore Q9BW92_A}]}
# structure déjà chargée, séquence déjà là : rien à ajouter, sans erreur
AjouteCif $Q9
V "M4 : un seul Q9BW92_A" {[W::ask {llength [lsearch -all -exact $::LNOrdali Q9BW92_A]}] == 1}

Instance M5
V "M5 : pas de Q9BW92_A" {! [Dans Q9BW92_A]}
AjouteCif $E9
V "M5 : E9AEW4_A ajoutée" {[Dans E9AEW4_A]}
V "M5 : E9AEW4_A colorée" {[W::ask {Colore E9AEW4_A}]}
# même structure dans une deuxième instance : ajoutée sous son nom
AjouteCif $Q9
V "M5 : Q9BW92_A ajoutée (structure déjà chargée)" {[Dans Q9BW92_A]}
V "M5 : Q9BW92_A colorée" {[W::ask {Colore Q9BW92_A}]}
V "M5 : pas de nom __2" {[W::ask {lsearch -all -inline $::LNOrdali Q9BW92_A__*}] eq {}}
# un vrai doublon dans l'instance reste refusé
set r [AjouteCif $Q9]
V "M5 : doublon refusé" {[W::ask {llength [lsearch -all -exact $::LNOrdali Q9BW92_A]}] == 1 && [string match "*no sequences*" [dict get $r dialogs]]}
# séquence simple de M4, sans structure, ajoutée par access UniProt
W::fire {AjouteSequenceOrPDB database} 5000
W::ask {set ::TAddS(SeqIdIn) F7CP98}
F "ajout UniProt F7CP98" {.was.fbut.ok invoke}
V "M5 : F7CP98 ajoutée sous son nom" {[Dans F7CP98] && [W::ask {lsearch -all -inline $::LNOrdali F7CP98__*}] eq {}}
V "M5 : les autres structures restent colorées" {[W::ask {Colore PDB_1QF6_A}]}
V "une seule structure Q9BW92" {[W::ask {llength [lsearch -all [info class instances Structure] ::Q9BW92]}] == 1}
V "pas de TMPSTR restant" {[W::ask {info commands TMPSTR}] eq ""}
F "overwrite M5" {SauveLeMac 0}
# aller-retour d'instances
Instance M4
V "M4 : retour, Q9BW92_A colorée" {[W::ask {Colore Q9BW92_A}]}
Instance M5
V "M5 : retour, E9AEW4_A colorée" {[W::ask {Colore E9AEW4_A}]}
F "sauvegarde ORD" [list SauveLAlignement ORD $ord]
Stop

Start $ord
V "réouverture : E9AEW4_A colorée" {[W::ask {Colore E9AEW4_A}]}
V "réouverture : PDB_1QF6_A colorée" {[W::ask {Colore PDB_1QF6_A}]}
V "réouverture : Q9BW92_A colorée" {[W::ask {Colore Q9BW92_A}]}
V "réouverture : F7CP98 dans M5" {[Dans F7CP98]}
set SeqM5 [W::ask {string map {. {}} $::Sequences(F7CP98)}]
Instance M4
V "réouverture M4 : Q9BW92_A colorée" {[W::ask {Colore Q9BW92_A}]}
V "réouverture M4 : pas de E9AEW4_A" {! [Dans E9AEW4_A]}
V "réouverture M4 : F7CP98 toujours là, même séquence" {[Dans F7CP98] && [W::ask {string map {. {}} $::Sequences(F7CP98)}] eq $SeqM5}
V "réouverture M4 : un seul F7CP98" {[W::ask {llength [lsearch -all -exact $::LNOrdali F7CP98]}] == 1}
# la 3D doit connaître ces structures
F "viewer 3D" VisualiseStructure
V "viewer ouvert" {[W::ask {winfo exists .ordogl}]}
V "viewer : Q9BW92 présente" {[W::ask {winfo exists $::pgl(frObjc).fQ9BW92}]}
Stop
file delete -force $Tmp
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
