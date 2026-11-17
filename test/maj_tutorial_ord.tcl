# Met à jour les ORD de tutoriel sans passer par l'interface : seules les tables secstr listées
# sont remplacées, et les descriptions d'instances et la note de main nettoyées. Le reste est recopié tel quel.
# Usage : tclsh8.6 test/maj_tutorial_ord.tcl entree.ord sortie.ord [fichier_secstr]
#   fichier_secstr : lignes {structure {chaine {entrees}}}, relues dans les CIF par le code actuel
package require sqlite3
proc SqliteSerialize {h} {$h serialize}
set Src [file dirname [file dirname [file normalize [info script]]]]/src
namespace eval ordfile {}
source $Src/ordali_ordfile.tcl

lassign $argv In Out FSS
if {[file normalize $In] eq [file normalize $Out]} {error "sortie = entrée"}
if {[file exists $Out]} {error "$Out existe déjà"}
set Nouv [dict create]
if {$FSS ne ""} {
    set f [open $FSS]
    while {[gets $f l] >= 0} {dict set Nouv [lindex $l 0] [lindex $l 1]}
    close $f
}
set f [open $In rb]
fconfigure $f -translation binary -encoding binary
zlib push gunzip $f
set o [open $Out wb]
fconfigure $o -translation binary -encoding binary
zlib push gzip $o
while {[set e [ordfile::tar_read_file $f]] ne ""} {
    set name [dict get $e name]
    set blob [dict get $e blob]
    if {$name eq "main"} {
	sqlite3 x :memory:
	x deserialize $blob
	# accolades ajoutées à chaque Overwrite, avant la correction de DescriptionDuMac
	x eval {select pk_snap, description from snapshot} r {
	    set d $r(description)
	    while {[string is list $d] && [llength $d] <= 1 && $d ne [lindex $d 0]} {set d [lindex $d 0]}
	    x eval {update snapshot set description=$d where pk_snap=$r(pk_snap)}
	    puts "instance $r(pk_snap) : <$d>"
	}
	# note répétée, héritée du XML d'origine
	x eval {update ordalie set val='Created by Ordali' where var='AlnInfo' and key='Note'}
	set blob [x serialize]
	x close
    } elseif {[dict exists $Nouv $name]} {
	sqlite3 x :memory:
	x deserialize $blob
	x eval {delete from secstr}
	dict for {chn Le} [dict get $Nouv $name] {
	    foreach entry $Le {x eval {insert into secstr values ($chn, $entry)}}
	}
	puts "$name : [x onecolumn {select count(*) from secstr}] éléments"
	set blob [x serialize]
	x close
    }
    ordfile::tar_write_file $o $name $blob
}
ordfile::tar_finalize $o
close $o
close $f
