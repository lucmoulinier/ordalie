# Test du choix « Leave without saving » du dialogue de changement d'instance (MiseAJourMac),
# demandé par l'utilisateur le 2026-11-20 : quitter une instance modifiée sans rien sauver ; en y
# revenant, elle est telle qu'avant les modifications.
#  - Cancel (bouton 3) : on reste sur l'instance, modifications gardées ;
#  - Leave without saving (bouton 2) : on change d'instance, rien n'est écrit dans la base,
#    au retour l'instance est intacte ;
#  - sur l'« Original alignment » (non écrasable), Leave without saving permet aussi d'en sortir.
# Usage : tclsh8.6 test/quitter_sans_sauver_test.tcl [numéro d'instance]
set N [expr {$argc ? [lindex $argv 0] : 7}]
set argv [list $N]
source [file join [file dirname [file normalize [info script]]] phase3 commun.tcl]
proc Q {s} {W::ask $s}

# contenu de l'instance dans la base : séquences, groupes, features
proc Base {m} {
    Q [string map [list @M@ $m] {
	set pk [lindex [IndexDeMac {@M@}] 0]
	list [zlib crc32 [LesSequencesDuMac $pk]] \
	    [$::db eval {select c.name, lsc.pk_seqali from clustering g, cluster c, ln_seqali_cluster lsc
		where g.pk_snap=$pk and c.pk_clustering=g.pk_clustering and lsc.pk_cluster=c.pk_cluster
		order by c.name, lsc.pk_seqali}] \
	    [$::db eval {select count(*) from ln_seqali_featali where pk_snap=$pk}]
    }]
}
# modifications en mémoire, comme une édition et un clustering : une séquence change,
# un groupe est ajouté
proc Modifie {} {
    Q {
	set n [lindex [lmap x $::LNOrdali {expr {[string trim $x] eq "" ? [continue] : [string trim $x]}}] 0]
	set s $::Sequences($n)
	set ::Sequences($n) [string reverse $s]
	set ::SDG(GroupeTestQuitter) [list $n]
	lappend ::LNDG GroupeTestQuitter
	VueEditee 1
    }
}

set M4 {M4 - mito-extended}
set M5 {M5 - Kinetoplatids}
set M1 {M1 - original alignment}
if {[catch {
    Start $Test/T_tutorial_maj.ord
    V "ouverture sur M4" {[Q {MacCourant name}] eq $M4} [Q {MacCourant name}]
    set E0 [Q ::P3::Empreinte]
    set B4 [Base $M4]
    Modifie
    set E1 [Q ::P3::Empreinte]
    V "M4 modifiée en mémoire" {$E1 ne $E0}

    # Cancel
    set r [F "Cancel" [list apply {{m} {probe::answer tk_dialog 3; MiseAJourMac x $m}} $M5] 120000]
    V "Cancel : dialogue à 4 boutons" {[string match "*Leave without saving*" [Dialogues $r]]} [Dialogues $r]
    V "Cancel : reste sur M4" {[Q {MacCourant name}] eq $M4} [Q {MacCourant name}]
    V "Cancel : modifications gardées" {[Q {VueEditee}] == 1 && [Q ::P3::Empreinte] eq $E1}

    # Leave without saving
    F "Leave without saving" [list apply {{m} {probe::answer tk_dialog 2; MiseAJourMac x $m}} $M5] 120000
    V "Leave : sur M5" {[Q {MacCourant name}] eq $M5} [Q {MacCourant name}]
    V "Leave : plus de modification en cours" {[Q {VueEditee}] == 0}
    V "Leave : base de M4 inchangée" {[Base $M4] eq $B4}
    V "Leave : pas de nouvelle instance" {[llength [Q LesMacs]] == 5} [Q LesMacs]
    Inv "M5"
    set r [F "retour sur M4" [list MiseAJourMac x $M4] 120000]
    V "retour : aucun dialogue" {[Dialogues $r] eq ""} [Dialogues $r]
    Same "retour sur M4 : état d'origine" $E0 [Q ::P3::Empreinte]
    Inv "M4"

    # Original alignment : non écrasable, on peut en sortir sans sauver
    set r [F "instance M1" [list MiseAJourMac x $M1] 120000]
    set E0 [Q ::P3::Empreinte]
    set B1 [Base $M1]
    Modifie
    F "M1 : Leave without saving" [list apply {{m} {probe::answer tk_dialog 2; MiseAJourMac x $m}} $M4] 120000
    V "M1 : sur M4" {[Q {MacCourant name}] eq $M4} [Q {MacCourant name}]
    V "M1 : base inchangée" {[Base $M1] eq $B1}
    F "retour sur M1" {probe::answer tk_dialog 0; MiseAJourMac x {M1 - original alignment}} 120000
    Same "retour sur M1 : état d'origine" $E0 [Q ::P3::Empreinte]
    Stop
} m]} {
    V "script" 0 "$m $::errorInfo"
    catch Stop
}
Fin
