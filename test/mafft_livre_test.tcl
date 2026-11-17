# Test du MAFFT livré dans bin/mafft-linux-x86_64, hors CSTB et sans mafft dans le PATH, et des descriptions
# d'instances après Overwrite.
# Usage : tclsh8.6 test/mafft_livre_test.tcl [numéro d'instance]
source $env(HOME)/.cache/claude-ordalie-tests/probe/walk.tcl
fconfigure stdout -buffering line
set N [expr {$argc ? [lindex $argv 0] : 6}]
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
    # ni CSTB, ni module, ni mafft dans le PATH
    W::ask {
	proc ::InsideCSTB {} {return 0}
	set ::env(PATH) /usr/bin:/bin
	foreach k [array names ::env BASH_FUNC*] {unset ::env($k)}
	unset -nocomplain ::env(MODULESHOME) ::env(BASH_ENV) ::env(MAFFT_BINARIES)
    }
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
proc Instance {nom} {F "instance $nom" [list apply {{nom} {
    set ::MacChoisi [lsearch -inline [LesMacs] "$nom -*"]
    MiseAJourMac
}} $nom] 120000}
proc Desc {pk} {W::ask [list $::db_nom onecolumn "select description from snapshot where pk_snap=$pk"]}

Start $Test/T_tutorial_maj.ord
set ::db_nom [W::ask {set ::db}]
set exe [W::ask MafftLivre]
V "MafftLivre trouve le binaire" {[string match */bin/mafft-linux-x86_64/mafft $exe]} $exe
V "pas de mafft dans le PATH" {[W::ask {array unset ::auto_execs; auto_execok mafft}] eq ""}
set r [W::ask {Mafft_AddSequences_local [list >a MKVLAAGIVGLCAKQ-WERTYHGF >b MKVLAAGIVGLCAKQHWERTYHGF] [list >c MKVLGIVGLCAKQWERTYHG]}]
V "appel direct : séquence c alignée" {[lsearch -exact $r >c] >= 0 && [string length [join [lrange $r [expr {[lsearch -exact $r >c]+1}] end] ""]] == 24} $r

# ajout d'une structure, chemin complet de l'interface
Instance M5
W::fire {AjouteSequenceOrPDB pdbfile} 5000
W::ask [list set ::TAddS(StrucFileIn) $Test/AF-Q3KRD0-F1-model_v6.cif]
F "ajout du CIF" {.was.fbut.ok invoke}
V "Q3KRD0_A ajoutée" {[W::ask {expr {"Q3KRD0_A" in $::LNOrdali}}]}
set e [W::ask {llength [lsort -unique [lmap n $::LNOrdali s $::LSOrdali {if {[string trim $n] eq ""} continue; string length $s}]]}]
V "alignement : une seule longueur" {$e == 1} $e
set s [W::ask {lindex $::LSOrdali [lsearch -exact $::LNOrdali Q3KRD0_A]}]
puts "Q3KRD0_A : [string range $s 0 150]..."
set res [string length [string map {. "" - ""} $s]]
V "Q3KRD0_A : résidus conservés et trous insérés" {$res > 0 && $res < [string length $s]} "$res / [string length $s]"
# pas de journal quand aucun message n'a été affiché
set Dlg $env(HOME)/.cache/claude-ordalie-tests/audit_gui/inst$N/dialogs.log
set Msg ""
if {[file exists $Dlg]} {set f [open $Dlg]; set Msg [read $f]; close $f}
V "aucun message d'échec MAFFT" {! [string match -nocase *unaligned* $Msg]} $Msg

# descriptions : Overwrite ne les change pas
# le banc annule le message "not saved" : sauver avant de changer d'instance
F "Overwrite M5" {SauveLeMac 0}
Instance M4
V "on est bien sur M4" {[string match "M4 -*" [W::ask {MacCourant name}]]} [W::ask {MacCourant name}]
W::ask [list $::db_nom eval {update snapshot set description='ma description' where pk_snap=4}]
foreach i {1 2 3} {F "Overwrite $i" {SauveLeMac 0}}
V "M4 : description inchangée après 3 Overwrite" {[Desc 4] eq "ma description"} [Desc 4]
Instance M3
V "on est bien sur M3" {[string match "M3 -*" [W::ask {MacCourant name}]]}
foreach i {1 2} {F "Overwrite M3 $i" {SauveLeMac 0}}
V "M3 : description lue dans l'ORD réparé" {[Desc 3] eq "macsim alignment"} [Desc 3]
V "fenêtre Instance : pas d'accolades" {[W::ask {DescriptionDuMac 3}] eq "macsim alignment"}
Stop

# repli : sans binaire livré
Start $Test/T_tutorial_maj.ord
W::ask {set ::OrdBinDir /nulle/part}
V "sans binaire : MafftLivre vide" {[W::ask MafftLivre] eq ""}
V "sans binaire ni module : résultat vide, sans erreur" {[W::ask {Mafft_AddSequences_local [list >a MKV >b MKV] [list >c MK]}] eq ""}
Stop
puts "BILAN : $Echecs échec(s)"
exit [expr {$Echecs ? 1 : 0}]
