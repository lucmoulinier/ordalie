# Alignment > Clustering : critères et méthodes. Les groupes sont une partition des séquences ; avec le seul
# critère « length », chaque groupe couvre un intervalle de longueurs distinct ; « Life Domain » : un groupe
# par domaine (nom du domaine) ; plage de colonnes : gardée par instance (Overwrite, changement d'instance) ;
# sans critère / sans méthode / « Life Domain » avec un autre critère : message ; Return.
# Usage : tclsh8.6 test/saisies/clustering_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
set Ici [file dirname [file normalize [info script]]]
source [file join [file dirname $Ici] phase3 commun.tcl]
proc Q {s} {W::ask $s}
proc Clus {criteres methode} {
    Q {foreach k [array names ::Clus LCrit,*] {set ::Clus($k) 0}}
    foreach c $criteres {Q [list set ::Clus(LCrit,$c) 1]}
    Q [list set ::Clus(Method) $methode]
    set r [W::fire NouveauClustering 300000]
    V "$criteres / $methode : sans erreur" {! [Err $r]} [expr {[Err $r] ? [string range [dict get $r errorInfo] 0 300] : ""}]
    return [Dialogues $r]
}
proc Groupes {} {Q {set r {}; foreach g [lrange $::LNDG 1 end] {if {$g ni {bidon grise}} {lappend r $g $::SDG($g)}}; set r}}
proc Toutes {} {Q {lmap n $::LNOrdali {expr {[string trim $n] eq "" ? [continue] : [string trim $n]}}}}

if {[catch {
    Start $Test/T_tutorial_maj.ord
    set Ln [lsort [Toutes]]
    F "mode Clustering" {ChangeMode cluster} 60000
    Q {set ::Clus(ShowSeqOut) 1}
    foreach m {"hierarchic / secator" "kmeans / DPC"} {
	Clus length $m
	set G [Groupes]
	set tous [lsort [concat {*}[dict values $G]]]
	V "length, $m : partition des séquences ([llength [dict keys $G]] groupes)" {$tous eq $Ln && [llength [dict keys $G]] >= 2} "[llength $tous] / [llength $Ln]"
	# intervalles de longueurs disjoints
	set I {}
	dict for {g L} $G {
	    set lg [lmap n $L {Q "string length \[string map {. {} { } {}} \$::Sequences($n)\]"}]
	    lappend I [list [::tcl::mathfunc::min {*}$lg] [::tcl::mathfunc::max {*}$lg]]
	}
	set I [lsort -integer -index 0 $I]
	set chev 0
	for {set i 1} {$i < [llength $I]} {incr i} {if {[lindex $I $i 0] <= [lindex $I $i-1 1]} {incr chev}}
	V "length, $m : intervalles de longueurs disjoints" {$chev == 0} $I
    }
    Clus {"% identity" length} "hierarchic / secator"
    set G [Groupes]
    V "% identity + length : partition" {[lsort [concat {*}[dict values $G]]] eq $Ln}
    # Life Domain
    Clus {"Life Domain"} ""
    set G [Groupes]
    set ok 1
    dict for {g L} $G {
	set d [lsort -unique [lmap n $L {string totitle [Q "expr {\[info exists ::TDesPhylum($n)\] && \$::TDesPhylum($n) ne {} ? \$::TDesPhylum($n) : {Undefined}}"]}]]
	if {[llength $d] != 1 || [Q "set ::SDG(Equiv,$g)"] ne $d} {set ok 0}
    }
    V "Life Domain : un groupe par domaine, nommé" {$ok && [llength [dict keys $G]] >= 2} [lmap g [dict keys $G] {Q "set ::SDG(Equiv,$g)"}]
    # messages
    V "sans critère : message" {[string match "*No criterion*" [Clus {} "hierarchic / secator"]]}
    V "sans méthode : message" {[string match "*No clustering method*" [Clus length ""]]}
    V "Life Domain + autre : message" {[string match "*alone*" [Clus {"Life Domain" length} "hierarchic / secator"]]}
    # plage de colonnes gardée par instance
    Q {set ::ZoneSelect {{100 299}}}
    Clus length "hierarchic / secator"
    V "plage du clustering : 100-299" {[Q {set ::ZoneClusterisation}] eq {{100 299}}} [Q {set ::ZoneClusterisation}]
    F "Return" {QuitteModeClusters $::FrmBouton.clusel} 60000
    F "Overwrite" {SauveLeMac 0} 60000
    set z2 [Q {$::db eval {select zone from clustering where pk_snap = 2}}]
    F "instance M2" {MiseAJourMac x {M2 - macsims alignment}} 120000
    V "M2 : sa propre plage" {[Q {set ::ZoneClusterisation}] eq [lindex $z2 0]} "[Q {set ::ZoneClusterisation}] / $z2"
    F "Overwrite M2" {SauveLeMac 0} 60000
    V "M2 : plage de M2 gardée" {[Q {$::db eval {select zone from clustering where pk_snap = 2}}] eq $z2}
    F "instance M4" {MiseAJourMac x {M4 - mito-extended}} 120000
    V "M4 : plage 100-299" {[Q {set ::ZoneClusterisation}] eq {{100 299}}} [Q {set ::ZoneClusterisation}]
    Inv "après Clustering"
    Stop
} m]} {
    V "script" 0 $m
    catch Stop
}
Fin
