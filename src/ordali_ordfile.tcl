


#
#
# --- ordali_ordfile.tcl ---
#
# procedures to manage ORD file
# ORD file is a tar.gz file that contains all sqlite databases opened in ordali
# Reading an ORD file restores all the databases
#

namespace eval ordfile {
    namespace export CreeLeORD DecortiqueUnORD

    # Decoding ORD file

    
    # ============================================================
    # Read octal field from TAR header
    # ============================================================
    proc tar_octal {s} {
	set s [string trim $s "\0 "]
	if {$s eq ""} {
	    return 0
	}
	scan $s %o val
	
	return $val
    }
    
    # ============================================================
    # Read TAR header
    #
    # Returns:
    #   {} => end of archive
    #
    # or dict:
    #   name size typeflag
    # ============================================================
    proc tar_read_header {chan} {
	set hdr [read $chan 512]
	
	if {[string length $hdr] != 512} {
	    return {}
	}
	
	# End-of-archive block = all zeros
	if {$hdr eq [binary format a512 ""]} {
	    return {}
	}
	
	binary scan $hdr \
	    a100a8a8a8a12a12a8a1 \
	    name mode uid gid size mtime chksum typeflag
	
	set name [string trim $name "\0"]
	set size [tar_octal $size]
	
	return [dict create \
		    name $name \
		    size $size \
		    typeflag $typeflag]
    }
    
    # ============================================================
    # Read one TAR file entry
    #
    # Returns:
    #   dict with:
    #       name
    #       blob
    #
    # or {} at EOF
    # ============================================================
    proc tar_read_file {chan} {
	set info [tar_read_header $chan]
	
	if {$info eq ""} {
	    return {}
	}
	
	set size [dict get $info size]
	
	# Read blob
	set blob [read $chan $size]
	
	# Skip padding
	set pad [expr {(512 - ($size % 512)) % 512}]
	if {$pad > 0} {
	    read $chan $pad
	}
	
	return [dict create \
		    name [dict get $info name] \
		    blob $blob]
    }
    
    # ============================================================
    # Read archive into memory blobs
    #
    # Returns list:
    #
    #   {filename blob}
    #
    # ============================================================
    proc read_memory_sqlite_tar_gz {archive} {
	set results {}
	
	set f [open $archive rb]
	fconfigure $f \
	    -translation binary \
	    -encoding binary
	
	# gunzip STREAMING
	zlib push gunzip $f
	
	while {1} {
	    set entry [tar_read_file $f]
	    if {$entry eq ""} {
		break
	    }
	    
	    lappend results [list [dict get $entry name] [dict get $entry blob]]
	}
	
	close $f
	
	return $results
    }


    proc DecortiqueUnORD {file} {
	set results {}
	
	set f [open $file rb]
	fconfigure $f \
	    -translation binary \
	    -encoding binary
	
	# gunzip STREAMING
	zlib push gunzip $f
	
	while {1} {
	    set entry [tar_read_file $f]
	    if {$entry eq ""} {
		break
	    }
	    
	    set name [dict get $entry name]
	    set data [dict get $entry blob]

	    if {$name eq "main"} {
		# main ordalie database
		global db
		set db "OrdDB_root_main_[pid]_[clock scan now]"
		sqlite3 $db :memory:
		SqliteDeserialize $db $data
		# ORD saved before the cluster names (label column)
		if {"label" ni [$db eval {select name from pragma_table_info('cluster')}]} {
		    $db eval {alter table cluster add column label varchar(64)}
		}
	    } else {
		# PDB db : restore it, then rebuild the
		# object from it (chains, residues, atoms)
		set name [string trimleft $name ":"]
		if {"::$name" in [info commands] || $name in [info commands]} {
		    continue
		}
		# fully qualified : we are in namespace ordfile
		Structure create ::$name
		::$name deserializeDB $data
		::$name new $name "" 1
	    }
	}
	
	close $f

	UpdateFromOrdaliDB
	
	return
    }
	
    # ============================================================
    # DEMO Read
    # ============================================================
    proc demo_read {} {
	set dbs [read_memory_sqlite_tar_gz memory_backup.tar.gz]
	
	foreach item $dbs {
	    lassign $item filename blob
	    
	    puts "Loading $filename"
	    sqlite3 db :memory:
	    
	    # Restore DB directly from blob
	    db deserialize $blob
	    
	    puts "Tables in $filename :"
	    db eval {
		SELECT name FROM sqlite_master WHERE type='table'
	    } {
		puts "  $name"
	    }
	    
	    db close
	}
	
	exit
    }
    
    

    # Encode ORD file

    # ------------------------------------------------------------
    # Write one TAR header
    # ------------------------------------------------------------
    proc tar_write_header {chan name size} {
	set header [binary format a100a8a8a8a12a12a8a1a100a6a2a32a32a8a8a155x12 \
			$name \
			0000644 \
			0000000 \
			0000000 \
			[format %011o $size] \
			[format %011o [clock seconds]] \
			"        " \
			0 \
			"" \
			"ustar" \
			"00" \
			"user" \
			"group" \
			"" \
			"" \
			"" \
		       ]
	
	# checksum
	binary scan $header c* bytes
	
	set checksum 0
	foreach b $bytes {
	    if {$b < 0} {
		set b [expr {$b + 256}]
	    }
	    set checksum [expr {$checksum + $b}]
	}
	
	set chk [format "%06o\0 " $checksum]
	
	# inject checksum
	set header [string replace $header 148 155 $chk]
	
	puts -nonewline $chan $header
	
	return
    }
    
    # ------------------------------------------------------------
    # Write TAR file entry
    # ------------------------------------------------------------
    proc tar_write_file {chan filename data} {
	fconfigure $chan \
	    -translation binary \
	    -encoding binary
	
	set size [string length $data]
	tar_write_header $chan $filename $size
	puts -nonewline $chan $data
	
	# pad to 512 bytes
	set pad [expr {(512 - ($size % 512)) % 512}]
	if {$pad > 0} {
	    puts -nonewline $chan [binary format a$pad ""]
	}
	
	return
    }
    
    # ------------------------------------------------------------
    # Finalize TAR
    # ------------------------------------------------------------
    proc tar_finalize {chan} {
	puts -nonewline $chan [binary format a1024 ""]
	
	return
    }
    
    # ------------------------------------------------------------
    # Create archive from memory SQLite DBs
    #
    # dbs = list of:
    #   {filename sqlite_handle}
    # ------------------------------------------------------------
    proc create_memory_sqlite_tar_gz {dbs outfile} {
	set out [open $outfile wb]
	fconfigure $out \
	    -translation binary \
	    -encoding binary
	
	# streaming gzip
	zlib push gzip $out

	foreach item $dbs {
	    lassign $item name blobOrDb
	    if {$name eq "main"} {
		global db
		set blob [SqliteSerialize $db]
	    } else {
		set blob $blobOrDb
	    }
	    tar_write_file $out $name $blob
	}
	
	tar_finalize $out
	
	close $out
	
	return
    }


    proc CreeLeORD {fileOut} {
	# first update variable
	global db Defauts Abr Ovw AlnInfo OvwORD

	# alignment name/score/note (scalars) : saved
	# through array AlnInfo, restored by
	# UpdateFromOrdaliDB
	unset -nocomplain AlnInfo
	foreach k {Name Score Note} {
	    if {[info exists ::Aln$k]} {
		set AlnInfo($k) [set ::Aln$k]
	    }
	}

	# overviews : what is needed to draw them again when the
	# file is loaded (RestaureFenetresORD), not their images and
	# widgets
	unset -nocomplain OvwORD
	if {[info exists Ovw(Liste)]} {
	    set OvwORD(Liste) $Ovw(Liste)
	    foreach Id $Ovw(Liste) {
		foreach k {Mac Feat FeatAff ShowRegion ShowAnno ScaleTot} {
		    if {[info exists Ovw(O$Id,$k)]} {
			set OvwORD($Id,$k) $Ovw(O$Id,$k)
		    }
		}
	    }
	}

	foreach var {"Defauts" "Abr" "Ovw" "OvwORD" "AlnInfo"} {
	    # the array as it is in memory : keys removed since the
	    # file was loaded (closed trees, deleted instances ...)
	    # must not come back
	    $db eval {DELETE FROM ordalie WHERE var = :var}
	    # Ovw : rows of files saved before (see OvwORD)
	    if {$var eq "Ovw" || ! [info exists $var]} {
		continue
	    }
	    
	    foreach {k v} [array get $var] {
		set existe [$db eval {SELECT val FROM ordalie WHERE var = :var AND key = :k}]
		# Si la liste 'existe' est vide, le couple n'existe pas.
		# Sinon, elle contient la valeur actuelle.
		if {[llength $existe] == 0} {
		    # Cas 1 : Le couple n'existe pas -> INSERT
		    $db eval {INSERT INTO ordalie (var, key, val) VALUES (:var, :k, :v)}
		} else {
		    set ancienne_valeur [lindex $existe 0]
		    if {$ancienne_valeur ne $v} {
			$db eval {UPDATE ordalie SET val = :v WHERE var = :var AND key = :k}
		    }
		    # Cas 3 : Si la valeur est identique, on ne fait rien !
		}
	    }
	}

	# main ordali DB only : the structures DBs
	# (OrdDB_root_pdb*) are saved below with their
	# object. Taking them here wrote their handle
	# name instead of their content.
	set Ldbs [list [list "main" $::db]]
	# for PDB dbs, named by structure (without "::")
	set Lopdb [info class instances Structure]
	foreach opdb $Lopdb {
	    set name [string trimleft $opdb ":"]
	    set blob [$opdb serializeDB]
	    lappend Ldbs [list $name $blob]
	}

	create_memory_sqlite_tar_gz $Ldbs $fileOut
	unset -nocomplain OvwORD

	return
    }


	    # ============================================================
    # DEMO
    # ============================================================
    proc demo_write {} {
	sqlite3 db1 :memory:
	sqlite3 db2 :memory:
	# contact.db is a sqlite db in /home/moumou/alitest
	sqlite3 dx contact.db
	
	db1 eval {
	    CREATE TABLE test(id INTEGER, name TEXT);
	    INSERT INTO test VALUES(1,'alpha');
	}
	
	db2 eval {
	    CREATE TABLE scores(val REAL);
	    INSERT INTO scores VALUES(42.5);
	}
	
	set Ldbs {{project.db db1} {scores.db  db2} {contact dx}}
	create_memory_sqlite_tar_gz $Ldbs memory_backup.tar.gz
	
	puts "Created memory_backup.tar.gz"
	
	exit
    }
}
# end of namespace

namespace import ::ordfile::CreeLeORD
namespace import ::ordfile::DecortiqueUnORD

    
proc tsord {} {
    SauveLAlignement ORD tord.ord
    exit
}


# ============================================================
# Serialize / deserialize a sqlite database handle.
# 'serialize' and 'deserialize' only exist since SQLite 3.23;
# with older versions (ActiveTcl 8.6.11 : 3.20.1) go through a
# temporary file with 'backup' and 'restore'.
# ============================================================
proc SqliteSerialize {h} {
    if {! [catch {$h serialize} blob]} {
	return $blob
    }

    close [file tempfile tmpName .sqlite]
    $h backup $tmpName
    set f [open $tmpName rb]
    set blob [read $f]
    close $f
    file delete $tmpName

    return $blob
}


proc SqliteDeserialize {h data} {
    if {! [catch {$h deserialize $data}]} {
	return
    }

    set f [file tempfile tmpName .sqlite]
    fconfigure $f -translation binary -encoding binary
    puts -nonewline $f $data
    close $f
    $h restore $tmpName
    file delete $tmpName

    return
}
