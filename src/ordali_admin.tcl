

#
# ordali_admin.tcl
#



proc CreateInstaller {} {
    cd [file join $::OrdaliDir Build Installers]
    catch {file delete -force setup-ordalie-linux.tar.gz}
    catch {file delete -force setup-ordalie-linux}
    file mkdir setup-ordalie-linux

    cd setup-ordalie-linux

    puts ""
    puts "Copying files ..."
    
    file copy -force {*}[glob [file join .. .. linux-x86_64 *]] .
    file copy [file join .. .. Ressources install.tcl] .
    
    puts ""
    puts "Now create archive and compress ...."
    cd ..
    exec tar -cf setup-ordalie-linux.tar setup-ordalie-linux
    exec gzip setup-ordalie-linux.tar
    
    return
}


proc BuildDistrib {{plat ""}} {
    # Available platforms are:
    # - linux-x86_64
    # - win32-x86_64
    # macosx-armaqua : Aqua based tcl/tk and packages. Compilations done on the mac
    # -macosx-arm : X11 based tcl/tk and packages

    # Define platform
    if {$plat eq ""} {
	package require platform
	set plat [::platform::generic]
    }

    cd [file join $::OrdaliDir Build]

    # initialize
    if {! [file exists $plat]} {
	file mkdir $plat
    }
    cd $plat
    puts "working dir : [pwd]"

    # Clean directory
    set Lf [glob -nocomplain *]
    if {$Lf != {}} {
	file delete -force {*}$Lf
    }

    # Create file-system
    file mkdir lib
    file mkdir etc
    file mkdir doc
    file mkdir bin
    
    # 1 -- libraries --
    cd lib
    # 1 --- lib : copying libraries
    # in dir moumou/pkgconf/<platform> there are all 
    # binary libraries. Some are compiled, other are 
    # taken as is on the internet (Img, tcl3d)
    puts ""
    puts "copying libraries ..."
    puts "[pwd]"
    set Lpkgs [lsort [glob -type d "[file join $::OrdaliDir .. pkgconf $plat lib *]"]]
    foreach pkg $Lpkgs {
	puts "    [file tail $pkg]"
	file copy -force $pkg .
    }
    # Now copy pure tcl libraries
    file copy -force {*}[glob [file join .. .. Ressources lib *]] .

    # all done
    cd ..

    # 2 -- etc ressouces --
    cd etc
    file copy -force {*}[glob [file join .. .. Ressources etc *]] .
    cd ..
    
    # 3 -- doc --
    cd doc
    set srcDoc [file join .. .. Ressources doc ordalie_documentation]
    set odoc [file tail $srcDoc]
    if {[file type $srcDoc] eq "link"} {
	set srcDoc [file join [file dirname $srcDoc] [file readlink $srcDoc]]
    }
    if {! [file exists $odoc]} {
	file mkdir $odoc
    }
    file copy -force {*}[glob $srcDoc/*] [file join . $odoc]
    cd ..

    # 4 -- bin
    # MAFFT, static build to avoid web services to DDBJ
    cd bin
    file copy -force [file join .. .. Ressources bin $plat "mafft-$plat"] .
    cd ..

    # add installation script if not windows
    if {[string first "win" $plat] == -1} {
	file copy -force [file join .. Ressources install.tcl] .
	file copy -force [file join .. Ressources uninstall.tcl] .
	file copy -force [file join .. Ressources README.txt] .
    }	
    
    # 4 -- create executable --
    # first harvest tcl code
    CreeOrdalieTclGlobal
    # create executable --
    CreeOrdalieStarpack $plat

    # 6 -- other needed files ---
    # add license, before, after installation
    # text files, and icon files
    file copy -force [file join .. Ressources LICENSE] .
    if {$plat eq "win32-x86_64"} {
	file copy -force {*}[glob [file join .. Ressources *.txt]] .
	file copy -force {*}[glob [file join .. Ressources *.ico]] .
    }

    # Finally, if not windows, put all together
    # and create an installer
    if {[string first "win" $plat] == -1} {
	# go back to Build/
	cd ..
	if {[file exists [file join Installers setup-ordalie-${plat}]]} {
	    file delete -force [file join Installers setup-ordalie-${plat}]
	}
	file copy -force $plat [file join Installers setup-ordalie-${plat}]

	# create the installer
	cd Installers
	puts "\nIn [pwd]"
	puts "Create installer ... setup-ordalie-${plat}.tar.gz"
	catch {file delete setup-ordalie-${plat}.tar.gz}
	exec tar cvfz setup-ordalie-${plat}.tar.gz setup-ordalie-${plat}
	if {! [file exists setup-ordalie-${plat}.tar.gz]} {
	    puts "ERROR ! Something went wrong when creating the tar.GZ file !"
	    exit
	}
	file delete -force setup-ordalie-${plat}
    }	
    
    puts "\ndone !\n\n"
    
    exit
}


proc CreeOrdalieTclGlobal {} {
    # Recupere toutes les procedures ...
    puts "\nHarvesting all procs ..."
    set LesProcsDeGscope [ToutesLesProcsDeGscope]

    # Cree fichier tcl global
    # Ouvre fichier qui contient tout
    set f [open "ordalie.tcl" w]
    # procs de gscope , ordali ...
    puts $f [join $LesProcsDeGscope \n]
    # Ajoute ordali.tcl en fin
    set Lj [LesLignesDuFichier [file join $::OrdaliDir src ordali.tcl]]
    puts $f [join [lrange $Lj 3 end] "\n"]
    close $f

    return
}


proc LoadTclPackages {} {
    package require tclcluspack
    package require tclordalie
    package require tclfastme
    package require http
    package require sqlite3
    package require La
    catch { namespace import La::*}
    package require struct
    package require tdom
    
    return
}

proc EspionneLoad {args} {
    #rR creer par Raymond pour le faire taire au lancement
    if {[info exists ::Defauts(ShowOrdalieHeader)] &&$::Defauts(ShowOrdalieHeader)} {
	return [Espionne {*}$args]
    } else {
	return ""
    }
}


proc LoadTkAndPackages {} {
    global Defauts

    #package require Tk $::tcl_patchLevel
    package require Tk
    #catch {console show}
    EspionneLoad "Tk       : $::tk_patchLevel"
    if {[string range [::platform::generic] 0 5] ne "macosx"} {
	if {[catch {package require tcl3d} Msg]} {
	    if {[string first "instead" $Msg] > -1} {
		set vertcl3d [lindex [split [string trim $Msg]] end-2]
	    } else {
		EspionneLoad "Msg : $Msg"
		set vertcl3d "None"
	    }
	} else {
	    set vertcl3d $Msg
	    package require tcl3d
	}
	EspionneLoad "tcl3d    : $vertcl3d"
    }
    
    if {$Defauts(Devlpt)} {
	EspionneLoad "biotext-dev: [package require biotext-dev]"
    } else {
	EspionneLoad "biotext  : [package require biotext]"
    }
    EspionneLoad "combobox : [package require combobox 2.3]"
    EspionneLoad "LRIPhoto : [package require LRIPhoto]"
    EspionneLoad ""

    namespace import ::LRI::*
    if {[tk windowingsystem] eq "aqua"} {
	catch {set ::origUseCustomMDEF $::tk::mac::useCustomMDEF; set ::tk::mac::useCustomMDEF 1}
    }
    
    return
}


proc ProcsDuScript {script {ns ::}} {
    # fully qualified names of the procs defined by a Tcl script :
    # top level procs, also indented ones, the ones in
    # "namespace eval" (qualified with the namespace) and the ones in
    # the bodies of if/catch/foreach... (a "proc" in a proc body
    # is not seen : it is not top level)
    set Lp {}
    set cmd ""
    foreach line [split $script \n] {
	append cmd $line \n
	# backslash-newline : the command goes on
	if {[regexp {(\\+)$} $line -> bs] && [string length $bs] % 2} {
	    continue
	}
	if {! [info complete $cmd]} {
	    continue
	}
	set c [string trim $cmd]
	set cmd ""
	if {$c eq "" || [string index $c 0] eq "#" || [catch {llength $c}]} {
	    continue
	}
	switch -- [lindex $c 0] {
	    "proc" {
		set n [lindex $c 1]
		if {! [string match "::*" $n]} {
		    set n "[string trimright $ns :]::$n"
		}
		lappend Lp $n
	    }
	    "namespace" {
		if {[lindex $c 1] eq "eval" && [llength $c] == 4} {
		    set sous [lindex $c 2]
		    if {! [string match "::*" $sous]} {
			set sous "[string trimright $ns :]::$sous"
		    }
		    lappend Lp {*}[ProcsDuScript [lindex $c 3] $sous]
		}
	    }
	    "if" - "catch" - "foreach" - "while" - "for" - "eval" - "uplevel" {
		foreach w [lrange $c 1 end] {
		    if {[string first "proc" $w] > -1} {
			lappend Lp {*}[ProcsDuScript $w $ns]
		    }
		}
	    }
	}
    }

    return $Lp
}


proc ProcsDuFichier {file} {
    set o [open $file r]
    set script [read -nonewline $o]
    close $o

    return [ProcsDuScript $script]
}


proc ProcsOrdali {} {
    # fully qualified names of the procs defined by the ordali files
    set Lprocs {}
    foreach file $::ListOfOrdaliFiles {
	if {[string index $file 0] eq "#"} {
	    continue
	}
	set Lp [ProcsDuFichier [file join $::OrdSrcDir $file]]
	puts "[file tail $file]\n    [llength $Lp]"
	lappend Lprocs {*}$Lp
    }
    puts "\ntotal : [llength $Lprocs]"

    return $Lprocs
}


proc ProcsPerso {} {
    # fully qualified names of the procs of gscoperso
    set Lprocs {}
    set fsource [file join $::env(HOME) gscoperso gscope_source.tcl]
    set Llines [LesLignesDuFichier $fsource]
    foreach l $Llines {
	set l [string trim $l]
	if {[string first "source" $l] == 0} {
	    regsub -all { +} $l " " l
	    set f [lrange $l 1 end]
	    # if more than 1 element, the name is
	    # a file join ....
	    if {[llength $f] > 1} {
		eval "set f [join $f]"
	    }
	    set Lp [ProcsDuFichier $f]
	    puts "[file tail $f]\n    [llength $Lp]"
	    lappend Lprocs {*}$Lp
	}
    }
    puts "\ntotal : [llength $Lprocs]"

    return $Lprocs
}


proc ListeNamespaces {{parentns ::}} {
	set result [list]
	foreach ns [namespace children $parentns] {
		eval lappend result [ListeNamespaces $ns]
		lappend result $ns
	}
	return $result
}


proc NamespacesDesPaquets {} {
    # namespaces created by the packages loaded here : they are
    # loaded again in an empty interpreter
    set c [interp create]
    $c eval [list set ::auto_path $::auto_path]
    if {[info commands ::tk] ne ""} {
	catch {$c eval {package require Tk ; wm withdraw .}}
    }
    foreach p [package names] {
	if {$p in {Tcl Tk} || [catch {package present $p} v]} {
	    continue
	}
	catch {$c eval [list package require $p $v]}
    }
    set Lns [$c eval {
	proc LN {{p ::}} {
	    set r {}
	    foreach ns [namespace children $p] {
		lappend r $ns {*}[LN $ns]
	    }
	    return $r
	}
	LN
    }]
    interp delete $c

    return $Lns
}


proc pdg {} {
    ToutesLesProcsDeGscope /home/moumou/ordali2/src/LesProcsDeGscope.tcl
    exit
}


proc ToutesLesProcsDeGscope {{file ""} {AvecOrdali 1} {AvecPerso 1}} {
    # Writes in file (or returns) the Tcl code of the procs of
    # Gscope loaded here. Left out :
    # - the procs that existed before sourcing (ProcsAuDepart)
    # - the procs of the packages (their namespaces)
    # - the commands imported by "namespace import" (the import
    #   is written instead, if the origin is kept)
    # - if AvecOrdali is 0, the procs of the ordali files, and if
    #   AvecPerso is 0, the ones of gscoperso
    global ProcsAuDepart

    # cas particulier AuLog
    if {[info commands ::AuLog] ne ""} {
	rename ::AuLog ::AuLogText
    }

    # all procs, fully qualified
    set ListeProc [lmap p [info procs] {string cat "::" $p}]
    set BlastListNS [list ::tcl ::ttk ::tk ::oo {*}[NamespacesDesPaquets]]
    set BlastListNS [lsort -unique $BlastListNS]
    foreach ns [ListeNamespaces] {
	if {[lsearch -exact $BlastListNS $ns] > -1} {
	    continue
	}
	# sub-namespace of a left out namespace
	set Pere $ns
	while {[set Pere [namespace qualifiers $Pere]] ne ""} {
	    if {[lsearch -exact $BlastListNS $Pere] > -1} {
		break
	    }
	}
	if {$Pere ne ""} {
	    continue
	}
	lappend ListeProc {*}[info procs ${ns}::*]
    }
    set ListeProc [lsort -unique $ListeProc]

    set Exclues {}
    foreach p $ProcsAuDepart {
	dict set Exclues "::[string trimleft $p :]" 1
    }
    if {! $AvecPerso} {
	foreach p [ProcsPerso] {dict set Exclues $p 1}
    }
    if {! $AvecOrdali} {
	foreach p [ProcsOrdali] {dict set Exclues $p 1}
    }
    puts ""

    set LesProcs {}
    set LesNs {}
    set LesImports {}
    foreach e $ListeProc {
	if {[dict exists $Exclues $e]} {
	    continue
	}
	set origine [namespace origin $e]
	if {$origine ne $e} {
	    # imported : written as an import, if the origin is kept
	    if {! [dict exists $Exclues $origine] && $origine in $ListeProc} {
		lappend LesImports [list [namespace qualifiers $e] $origine]
	    }
	    continue
	}
	set ns [namespace qualifiers $e]
	if {$ns ne ""} {
	    lappend LesNs $ns
	}
	# arguments built as a list : defaults with blanks (\n...),
	# quotes or braces are kept as they are
	set Largs {}
	foreach g [info args $e] {
	    if {[info default $e $g Def]} {
		lappend Largs [list $g $Def]
	    } else {
		lappend Largs $g
	    }
	}
	# global procs written without "::", as in the sources
	set nom [expr {$ns eq "" ? [string range $e 2 end] : $e}]
	lappend LesProcs "proc [list $nom] [list $Largs] {"
	lappend LesProcs [info body $e]
	lappend LesProcs "}"
	lappend LesProcs ""
    }

    set PAll {}
    foreach ns [lsort -unique $LesNs] {
	lappend PAll "namespace eval $ns {}"
    }
    lappend PAll {*}$LesProcs
    foreach im $LesImports {
	lassign $im ns origine
	if {$ns eq ""} {
	    set ns "::"
	}
	lappend PAll "namespace eval [namespace qualifiers $origine] [list [list namespace export [namespace tail $origine]]]"
	lappend PAll "namespace eval $ns [list [list namespace import $origine]]"
    }
    puts "[llength $LesProcs] lines, [llength $LesImports] imports"

    if {$file ne ""} {
	set f [open $file w]
	puts $f [join $PAll \n]
	close $f

	return
    } else {
	return $PAll
    }
}


proc PackLibrairies {plat} {
    set odir $::OrdaliDir

    switch $plat {
	"Linux-x86" -
	"linux-ix86" {
	    set rep "Linux-x86"
	    set pre lib
	    set suf ".so"
	}
	"Linux-x86_64" -
	"linux-x86_64" {
	    set rep "Linux-x86_64"
	    set pre lib
	    set suf ".so"
	}
	"Windows" -
	"win32-ix86" {
	    set rep Windows
	    set pre ""
	    set suf ".dll"
	}
	"Mac" -
	"macosx-ix86" {
	    set rep MacOSX-x86
	    set pre "lib"
	    set suf ".dylib"
	}
	"macosx-x86_64" {
	    set rep MacOSX-x86_64
	    set pre "lib"
	    set suf ".dylib"
	}
	"macosx-arm" {
	    set rep MacOSX-arm
	    set pre "lib"
	    set suf ".dylib"
	}
    }

    # first make it clean
    puts "\nPreparing for $pre"
    puts "cleaning ..."
    file delete -force [file join ToPack lib]
    puts "copying pure-tcl packages ..."
    set Lall [list cmdline combobox-2.3 formdata1.0 FRAT01.xml la1.0 LRIPhoto LRIPhoto.kit struct-2.1 tcllib1.18 browser1.0 hv pca1.0]
    set Lcopy [lmap f {set o [file join $OrdLibDir $f]}]
    file copy -force {*}$Lcopy [file join ToPack lib]
    #file copy -force [file join $::OrdaliDir Extensions AllPlatform] [file join ToPack lib]
    
    puts "copying platform specific packages ..."
    foreach pkg {"tclcurl-7.27.0" "tclcluspack0.1" "tclfastme0.1" "tclsurface0.1" "biotext1.0" "tclordalie0.1"} {
	set libin [file join $::OrdaliDir Extensions $pkg $rep "${pre}${pkg}$suf"]
	set pkgin [file join .. Extensions $pkg $rep pkgIndex.tcl]
	set libout [file join ToPack lib $pkg "${pre}${pkg}$suf"]
	set pkgout [file join ToPack lib $pkg pkgIndex.tcl]
	
	# create dir
	file mkdir [file join ToPack lib $pkg]
	file copy -force $libin $libout
	file copy -force $pkgin $pkgout
	if {$pkg eq "biotext1.0"} {
	    file copy -force [file join $odir Extensions $pkg biotext.tcl] [file join ToPack lib $pkg]
	}
    }
    
    # tcl extensions
    # tcl3d
    file copy -force [file join $odir Extensions $rep tcl3d-0.4.1 tcl3d0.4.1] [file join ToPack lib]
    file copy -force [file join $odir Extensions $rep tcl3d-0.4.1 extlibs] [file join ToPack lib]
    # sqlite3
    file copy -force [file join $odir Extensions $rep sqlite3] [file join ToPack lib]
    # tdom
    file copy -force [file join $odir Extensions $rep tdom-0.8.3] [file join ToPack lib]
    
    if {$rep eq "MacOSX-x86"} {
	file copy -force [file join $odir Extensions $rep TclOO] [file join ToPack lib]
    }
        
    puts "\ndone !"
}


proc CreeOrdalieStarpack {{plat ""}} {
    if {$plat eq ""} {
	package require platform
	set plat [::platform::generic]
	cd [file join $::OrdaliDir Build $plat]
    }
    # output runtime tclkit :
    # may be different for CROSS - BUILDING
    set platout $plat
    set plat [::platform::generic]

    file copy -force [file join .. TclKits sdx.kit] sdx.kit

    # copy tclkit for building
    set fkit [glob [file join .. TclKits "tclkit-${plat}*"]]
    set kit [file tail $fkit]
    file copy $fkit $kit
    
    # copy runtime for the target
    set frun [glob [file join .. TclKits "tcltkkit-${platout}*"]]
    set run [file tail $frun]
    file copy $frun $run

    # define executable extention
    set ext ""
    if {[string first "win" $platout] > -1} {
	set ext ".exe"
    }
    set target "ordalie$ext"
    puts "Creating starpack : $target"

    exec ./$kit sdx.kit qwrap  ordalie.tcl
    exec ./$kit sdx.kit unwrap ordalie.kit
    exec ./$kit sdx.kit wrap $target -runtime $run
    if {! [file exists $target]} {
	puts "problem while creating executable !"
	exit
    }
    
    file delete -force ordalie.vfs
    file delete -force ordalie.kit
    file delete -force ordalie.tcl
    file delete -force sdx.kit
    file delete -force {*}[glob *tcl*kit*]
    puts "cleaning done ..."
    
    return
}


proc MakeAll {} {
    
    package require platform

    set p [::platform::generic]
    switch [string tolower $p] {
	"linux-x86" -
	"linux-ix86" {
	    set rep "Linux-x86"
	}
	"linux-x86_64" -
	"linux-x86_64" {
	    set rep "Linux-x86_64"
	}
	"windows" -
	"win32-ix86" {
	    set rep Windows
	}
	"mac" -
	"macosx-ix86" {
	    set rep MacOSX-x86
	}
    }
    
    puts "\nCompilation :\n"
    foreach p {tclcurl-7.27.0" tclordalie0.1 tclcluspack0.1 tclfastme0.1 biotext1.0 tclsurface0.1} {
	cd [file join $::OrdaliDir Extensions $p $rep]
	puts "$p"
	# nettoyage
	set Ldel [glob -nocomplain *.o]
	if {$Ldel != {}} {file delete -force {*}$Ldel}
	set Ldel [glob -nocomplain *.so]
	if {$Ldel != {}} {file delete -force {*}$Ldel}

	# copie des sources
	set Lfc [glob -nocomplain [file join .. src *.c]]
	file copy -force {*}$Lfc "[pwd]"
	set Lfh [glob -nocomplain [file join .. src *.h]]
	file copy -force {*}$Lfh "[pwd]"
	
	# compilation
	catch {exec make} Msg

	if {[regexp -nocase {erreur|error} $Msg]} {
	    puts "#########################"
	    puts $Msg
	    puts "#########################"
	}
    }

    exit
}


proc InstallEnv {{p ""}} {
    global OrdaliDir tcl_platform env

    if {$p eq ""} {
	package require platform
	set p [::platform::generic]
    }
    
    if {$tcl_platform(platform) eq "windows"} {
	set odir [file join o:/ ordali]
    } else {
	set odir $env(ORDALIDIR)
    }
    
    switch $p {
	"Linux-x86" -
	"linux-ix86" {
	    set rep "Linux-x86"
	    set pre lib
	    set suf ".so"
	}
	"Linux-x86_64" -
	"linux-x86_64" {
	    set rep "Linux-x86_64"
	    set pre lib
	    set suf ".so"
	}
	"Windows" -
	"win32-ix86" {
	    set rep Windows
	    set pre ""
	    set suf ".dll"
	}
	"Mac" -
	"macosx-ix86" {
	    set rep MacOSX
	    set pre "lib"
	    set suf ".dylib"
	}
    }
    
    # first make it clean
    puts "cleaning ..."
    set home [pwd]
    cd [file join $OrdaliDir lib]
    foreach d [glob -nocomplain -type d *] {
	file delete -force -- $d
    }
    cd $home
    file delete -force [file join $OrdaliDir lib]
    puts "copying pure-tcl packages ..."
    file copy -force [file join $OrdaliDir Extensions AllPlatform] [file join $OrdaliDir lib]
    
    puts "copying platform specific packages ..."
    foreach pkg {"tclcluspack0.1" "tclfastme0.1" "tclsurface0.1" "biotext1.0" "tclordalie0.1"} {
	set libin [file join $odir Extensions $pkg $rep "${pre}${pkg}$suf"]
	set pkgin [file join $odir Extensions $pkg $rep pkgIndex.tcl]
	set libout [file join $odir lib $pkg "${pre}${pkg}$suf"]
	set pkgout [file join $odir lib $pkg pkgIndex.tcl]
	
	# create dir
	file mkdir [file join $OrdaliDir lib $pkg]
	file copy -force $libin $libout
	file copy -force $pkgin $pkgout
	if {$pkg eq "biotext1.0"} {
	    file copy -force [file join $odir Extensions $pkg biotext.tcl] [file join $odir lib $pkg]
	}
    }
    
    # Tcl/Tk platform specific extensions
    # tcl3d
    file copy -force [file join $odir Extensions $rep tcl3d-0.4.1 tcl3d0.4.1] [file join $odir lib]
    file copy -force [file join $odir Extensions $rep tcl3d-0.4.1 extlibs] [file join $odir lib]
    # sqlite3
    file copy -force [file join $odir Extensions $rep sqlite3] [file join $odir lib]
    # tdom
    file copy -force [file join $odir Extensions $rep tdom-0.8.3] [file join $odir lib]
    
    puts "\ndone !\n"
    
    exit
}


proc BasculeLibs {from to} {
    # mise a jour librairies tcl
    #
    # Quand on installe nouvelle version de Tcl,
    # il faut ramener toutes les librairies qui 
    # existaient dans l'ancienne version vers la 
    # nouvelle, A L'EXCLUSION DES LIBS DE TCL LUI MEME
    #
    # from : top directory of OLD tcl install
    # to   : top directory of NEW Tcl install
    set home [pwd]

    cd /usr/local
    cd [file join $from lib]
    set Lfrom [glob -type d *]
    cd /usr/local
    cd [file join $to lib]
    set Lto   [glob -type d *]
    set Llib [lor $Lfrom $Lto "from1"]

    cd /usr/local
    foreach l $Llib {
	set in  [file join $from lib $l]
	set out [file join $to   lib $l]
	file copy -force $in $out
    }

    cd $home

    exit
}
  

proc PackExtension {{ext "all"}} {
    global OrdaliDir

    set LextOri {tclfastme0.1 tclsurface0.1 biotext1.0 tclcluspack0.1 tclordalie0.1}

    if {$ext eq "all"} {
	set Lext $LextOri
    } elseif {$ext ni $LextOri} {
	puts "possible extensions are :\n$LextOri"
	exit
    } else {
	set Lext $ext
    }

    set Lf [glob -nocomplain [file join $OrdaliDir tmp *]]
    if {$Lf != {}} {
	file delete -force {*}$Lf
    }
    foreach ext $Lext {
	puts "\n$ext"
	cd [file join $OrdaliDir tmp]
	file copy [file join $OrdaliDir Extensions $ext] $ext/
	cd $ext
	set Lsvn [glob -nocomplain */.svn]
	if {$Lsvn != {}} {
	    file delete -force {*}$Lsvn
	}
	
	cd ../
	set cmd "zip ${ext}.zip ${ext}/*"
	puts "==> $cmd"
	catch {exec tcsh -c "zip ${ext}.zip ${ext}/*"} Msg
	puts "zip : $Msg"
	catch {exec tar -cvf "${ext}.tar" $ext} Msg
	puts "tar : $Msg"
	catch {exec gzip "${ext}.tar"} Msg
	puts "gzip $Msg"

	file delete -force $ext
    }
    
    exit
}


proc CompilePackages {{pkg ""}} {
    global env
    
    # Definit plateform, et repertoire associes
    package require platform
    set plat [::platform::generic]
    set platlong [::platform::generic]	
    
    puts "platform : $plat\n"
    
    switch [::platform::generic] {
	"macosx-x86_64" {
	    set pkgconf [file join $::env(HOME) moumou pkgconf]
	}
	"linux-x86" -
	"linux-x86_64" {
	    set pkgconf [file join $::env(HOME) pkgconf]
	}
	"win32-x86_64" {
	    set pkgconf [file join o:/ pkgconf]
	}
    }
    cd $pkgconf

    set instdir [file join $pkgconf $platlong]
    puts "installing in : $instdir"
    
    set Lpkg [list tkhtml3.0 1 LRIPhoto1.0 1 biotext1.0 1 tclordalie0.1 0 tclcluspack0.1 0 tclfastme0.1 0 tclsurface0.1 0 tcltls-1.7.16 0]
    # tests
    #set Lpkg [list tclcluspack0.1 0]
    if {$pkg ne ""} {
	set i [lsearch $Lpkg $pkg]
	if {$i == -1} {
	    puts "\n ==> $pkg NOT FOUND !\n"
	    exit
	}
	set withTk [lindex $Lpkg $i+1]
	set Lpkg [list $pkg $withTk]
    }
    foreach {pkg avecTk} $Lpkg {
	# the sources of the packages are in pkgconf/sources,
	# except a few ones (tkhtml3.0) still in pkgconf
	set pkgdir [file join $pkgconf sources $pkg]
	if {! [file isdirectory $pkgdir]} {
	    set pkgdir [file join $pkgconf $pkg]
	}
	if {[string first "tclcluspack" $pkg] > -1} {
	    if {! [file exists [file join $pkgdir lib Rmath-${platlong}.a]]} {
		CreateRmathLibrary
	    } else {
		cd [file join $pkgdir lib]
		catch {file delete Rmath.a}
		file copy Rmath-${platlong}.a  Rmath.a
		cd $pkgconf
	    }
	}
	
	puts "\npackage : $pkg\npwd     : $pkgdir"
	cd $pkgdir

	exec make clean >& log
	
	switch $platlong {
	    "macosx-x86_64" {
		set Cmd "./configure --exec-prefix=$instdir --with-tcl=/usr/local/tcl8.6.6/lib" 
		if {$avecTk} {
		    append Cmd " --with-tk=/usr/local/tk8.6.6/lib"
		}
	    }
	    "linux-x86_64" {
		set Cmd "./configure --exec-prefix=$instdir --with-tcl=/home/moumou/tcl8.6.7/luc/lib"
		if {$avecTk} {
		    append Cmd "  --with-tk=/home/moumou/tk8.6.7/luc/lib"
		}
	    }
	    "linux-x86" {
	    }
	    "win32-x86_64" {
		set Cmd "sh configure --enable-threads --exec-prefix=$instdir --with-tcl=/c/TclTk64-8.6.7/lib"
		if {$avecTk} {
		    append Cmd " --with-tk=/c/TclTk64-8.6.7/lib"
		}
	    }
	}
	puts "Command : $Cmd"
	eval exec $Cmd >& log
	
	catch {exec make >& log}
	exec make install

	cd $pkgconf
    }
    
    exit
    return
}


proc CreateRmathLibrary {} {
    package require platform
    set platlong [::platform::generic]

    # First create Rmath library
    cd Rmath-master
    exec make clean
    exec make
    catch {file delete Rmath.a}
    cd src
    switch -regexp -- $platlong {
	{^win} {
	    exec ar -rc Rmath-${platlong}.a *.o
	}
	{^macos} {
	    set Lo [glob *.o]
	    #exec ar -rc Rmath-${platlong}.a {*}$Lo
	    exec ar -rc Rmath-${platlong}.a *.o
	}
	{^linux} {
	    set Lo [glob *.o]
	    exec ar -rc Rmath-${platlong}.a {*}$Lo
	    #exec ar -rc Rmath-${platlong}.a *.o
	}
    }
    cd ..
    set libRmath "Rmath-${platlong}.a"
    # tclcluspack0.1 is in pkgconf/sources, Rmath-master in pkgconf
    set libcp [file join .. sources tclcluspack0.1 lib]
    catch {file delete -force [file join $libcp Rmath.a]}
    catch {file delete -force [file join $libcp $libRmath]}
    file copy -force [file join src $libRmath] [file join $libcp .] 
    file copy -force [file join src $libRmath] [file join $libcp Rmath.a]
    puts "Rmath library created ..."
    puts "Copy $libRmath to sources/tclcluspack0.1/lib ..."
    cd ..
    
    return
}


proc MyProc {name argList body} {
    puts "$name"
    _oldproc $name $argList $body
}


proc DoMacPack {} {
    cd /home/moumou

    catch {file delete -force {*}[glob macpack*]}
    file copy ./ordali/src/macpack.tcl .
    exec ./tclkit sdx.kit qwrap  macpack.tcl
    exec ./tclkit sdx.kit unwrap macpack.kit
    cd macpack.vfs
    file copy -force ~/ordali/Build/macosx-x86_64 .
    cd ..
    exec ./tclkit sdx.kit wrap macpack -runtime mackit

    exit
}


proc UpdateTclLib {from} {
    set LibDir "/usr/local/ActiveTcl/lib"
    set LogCopies       "$LibDir/00_CopiesDepuis_[file tail $from].txt"
    set LogSansPkgIndex "$LibDir/00_SansPkgIndex_[file tail $from].txt"
    if {[file exists $LogCopies]} {
	if {[OuiOuNon "Attention UpdateTclLib a déjà été fait... Voir \n\n$LogCopies\n\nJe quitte ?"]} {
	    return ""
	}
    }
    Garde $LogCopies
    Garde $LogSansPkgIndex
	

    NousAllonsAuBoulot $LibDir
    set Llib [lsort -dictionary [glob -type d *]]
    Espionne $Llib
    set Llibnice [lmap d $Llib {
	regsub -all {[^A-Za-z]} $d "" dnice
	set dnice
    }]
    EspionneL $Llibnice
    OnRevientDuBoulot
    
    NousAllonsAuBoulot "$from/lib"
    Espionne [pwd]
    set LesCopies {}
    set LesSansPkgIndex {}
    #rR Attention il y a un petit problème avec des versions différentes... on les copie toutes !!!
    foreach d [lsort -dictionary [glob -type d *]] {
	regsub -all {[^A-Za-z]} $d "" dnice
	if {$dnice ni $Llibnice} {
	    set YaPkgIndex [exec find $d -name pkgIndex.tcl]
	    if {$YaPkgIndex==""} {
		Espionne " ..................................... sans pkgIndex.tcl $d"
		lappend LesSansPkgIndex $d
		continue
	    }
	    lappend LesCopies $d
	    file copy -force $d /usr/local/ActiveTcl/lib
	}
    }
    OnRevientDuBoulot
    SauveLesLignes $LesCopies       dans $LogCopies
    SauveLesLignes $LesSansPkgIndex dans $LogSansPkgIndex
    return "$LogCopies\n$LogSansPkgIndex"
}


# http://kitcreator.rkeene.org/kitcreator

























