#!/bin/sh
# The two lines below are read by sh, bash or zsh and restart this script with
# the first tclsh found. Tcl reads them as a single comment. \
for t in tclsh tclsh9.0 tclsh8.6 tclsh8.5; do if command -v $t >/dev/null 2>&1; then exec $t "$0" "$@"; fi; done; \
echo "Error ! tclsh was not found. Please install Tcl/Tk 8.6, then run this script again." >&2; exit 1

#
# This script installs ORDALIE software on Unix-like machines (Linux and
# macOS) and additional files in the desired directories.
#
# (c) Luc Moulinier 2025
#
# Usage : ./install.tcl  or  sh install.tcl  or  tclsh install.tcl
# (from bash, zsh or any other shell)
# The files/directories lib, doc, etc, LICENSE and ordalie must be located
# in the same directory as this script. The script can be started from any
# working directory.

package require Tcl 8.5
package require platform

# ----------------------------------------------------------------------------
# Procedures
# ----------------------------------------------------------------------------

# Prompt the user and return the trimmed answer.
# Abort cleanly on end of file (Ctrl-D, closed stdin) instead of looping forever.
proc Ask {prompt} {
    puts -nonewline $prompt
    flush stdout
    if {[gets stdin line] < 0} {
        puts "\n\nInstallation aborted."
        exit 1
    }
    return [string trim $line]
}

# Return the startup file read by the user's interactive shell, which will
# receive the ORDALIE aliases (macOS) or is named in the PATH hint (Linux).
# Return "" if the shell is not bash or zsh, or if the file is not writable.
# If $create is true, a missing file is created.
#  - zsh  : $ZDOTDIR/.zshrc, or ~/.zshrc (zsh does not read ~/.profile)
#  - bash : ~/.bashrc on Linux. On macOS, Terminal starts login shells, which
#           read only the first existing file among ~/.bash_profile,
#           ~/.bash_login and ~/.profile (never ~/.bashrc).
proc ShellFileToUse {shell macos create} {
    if {! [info exists ::env(HOME)]} {
        return ""
    }
    set home $::env(HOME)

    switch -- $shell {
        "zsh" {
            set dir $home
            if {[info exists ::env(ZDOTDIR)] && [file isdirectory $::env(ZDOTDIR)]} {
                set dir $::env(ZDOTDIR)
            }
            set f [file join $dir .zshrc]
        }
        "bash" {
            if {$macos} {
                set f [file join $home .bash_profile]
                foreach c {.bash_profile .bash_login .profile} {
                    if {[file exists [file join $home $c]]} {
                        set f [file join $home $c]
                        break
                    }
                }
            } else {
                set f [file join $home .bashrc]
            }
        }
        default {
            # other shells (tcsh, fish...) use another syntax : not handled
            return ""
        }
    }

    if {[file exists $f]} {
        if {[file writable $f]} {
            return $f
        }
        return ""
    }
    # Missing file. Without 'create', only report its name (used for a hint,
    # nothing is written on the disk).
    if {! $create} {
        return $f
    }
    if {[catch {close [open $f a]}]} {
        return ""
    }
    return $f
}

# Quote a string for sh, bash and zsh : 'abc' (a ' inside becomes '\'')
proc ShQuote {s} {
    return "'[string map [list ' {'\''}] $s]'"
}

# Find or create the $dir/bin directory. Return "" if it is not writable.
proc GetBinDir {dir} {
    set bindir [file join $dir bin]
    if {[file exists $bindir]} {
        if {[file isdirectory $bindir] && [file writable $bindir]} {
            return $bindir
        }
        # bin exists but is not a writable directory
        return ""
    }
    if {[catch {file mkdir $bindir}]} {
        return ""
    }
    return $bindir
}

# Is directory $dir listed in the PATH environment variable ?
proc InPath {dir} {
    if {! [info exists ::env(PATH)]} {
        return 0
    }
    set ndir [file normalize $dir]
    foreach p [split $::env(PATH) ":"] {
        if {$p ne "" && [file normalize $p] eq $ndir} {
            return 1
        }
    }
    return 0
}

# Create the symbolic link $linkPath -> $target, replacing an existing
# symbolic link (also a dangling one). A regular file is never overwritten.
# Return 1 on success, 0 otherwise.
proc MakeLink {linkPath target} {
    # 'file exists' is false for a dangling link, so use lstat
    if {! [catch {file lstat $linkPath st}]} {
        if {$st(type) ne "link"} {
            puts "Warning : $linkPath already exists and is not a symbolic link. It was left untouched."
            return 0
        }
        if {[catch {file delete $linkPath} msg]} {
            puts "Warning : cannot replace $linkPath : $msg"
            return 0
        }
    }
    if {[catch {file link -symbolic $linkPath $target} msg]} {
        puts "Warning : cannot create link $linkPath : $msg"
        return 0
    }
    return 1
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# Directory containing the files to install (the directory of this script)
set SrcDir [file dirname [file normalize [info script]]]

# Determine the OS type
set os [::platform::generic]
set macos [expr {[string first "macosx" $os] > -1}]

# Detect the shell and the file where the aliases / hints will be written
set shell ""
set FileShellRC ""
if {[info exists env(SHELL)] && $env(SHELL) ne ""} {
    set shell [file tail $env(SHELL)]
    # the file is only created on macOS, where the aliases are written to it
    set FileShellRC [ShellFileToUse $shell $macos $macos]
}

# Check that the distribution is complete
set Lmissing {}
foreach f {lib doc etc LICENSE ordalie} {
    if {! [file exists [file join $SrcDir $f]]} {
        lappend Lmissing $f
    }
}
if {$Lmissing ne {}} {
    puts "Error ! The following files are missing in $SrcDir :\n    $Lmissing"
    exit 1
}

puts "\n\n\n"
puts "    ORDALIE Installation :"
puts "--------------------------\n\n"

# choice of installation location
puts "Choose installation location :"
puts "- (H) ORDALIE will be installed in your HOME directory (Recommended)"
puts "- (U) You can also install ORDALIE in /usr/local/. Be sure you have privileges to install into this directory !"
puts "- (o) Alternatively, you can define another custom directory."
set ok 0
set instDir ""
set BinLinkDir ""
while {! $ok} {
    set rep [string tolower [Ask "\n(h/u/o) : "]]
    switch -- $rep {
        "u" {
            set instDir "/usr/local"
            if {! [file isdirectory $instDir]} {
                puts "\nError !\nThe $instDir directory does not exist !\nChoose another installation directory"
            } elseif {! [file writable $instDir]} {
                puts "\nError !\nYou have no write permission in $instDir !\nChoose another installation directory (or run this script with the required privileges)"
            } else {
                set instBinDir [GetBinDir $instDir]
                if {$instBinDir eq ""} {
                    puts "ERROR !\n[file join $instDir bin] does not exist or cannot be created !\nChoose another installation directory !"
                } else {
                    # /usr/local/bin is writable
                    set ok 1
                    set BinLinkDir $instBinDir
                }
            }
        }
        "h" {
            if {! [info exists env(HOME)]} {
                puts "\nError !\nThe HOME environment variable does not exist !\nChoose the 'o' option and type the absolute path to your home directory"
            } else {
                set ok 1
                set instDir $env(HOME)
                set BinLinkDir [GetBinDir $instDir]
            }
        }
        "o" {
            set ok2 0
            while {! $ok2} {
                set dir [Ask "Specify the absolute path to the installation directory : "]
                # Expand a leading ~ ourselves (Tcl 9 does not do it any more)
                if {([string equal $dir "~"] || [string match "~/*" $dir]) && [info exists env(HOME)]} {
                    set dir [file join $env(HOME) [string range $dir 2 end]]
                }
                set dir [file normalize $dir]
                if {! [file isdirectory $dir]} {
                    puts "Error ! Directory $dir does not exist !"
                } elseif {! [file writable $dir]} {
                    puts "Error ! You have no write permission in $dir !"
                } else {
                    set ok2 1
                    set ok 1
                    set instDir $dir
                    set BinLinkDir [file join $dir ordalie bin]
                }
            }
        }
        default {
            puts "Please answer h, u or o."
        }
    }
}

# in all cases create an 'ordalie' directory in the installation directory
set OrdalieDir [file join $instDir ordalie]
set OrdalieExe [file join $OrdalieDir bin ordalie]

# Never erase the directory we are installing from
set nOrd [file normalize $OrdalieDir]
if {$SrcDir eq $nOrd || [string first "$nOrd/" "$SrcDir/"] == 0} {
    puts "\nError !\nThe installation directory $OrdalieDir contains the files being installed."
    puts "Unpack the distribution somewhere else, or choose another installation directory."
    exit 1
}
if {[file exists $OrdalieDir] && ! [file isdirectory $OrdalieDir]} {
    puts "\nError !\n$OrdalieDir exists and is not a directory !"
    exit 1
}

puts "\nCopying files in $OrdalieDir ..."
puts ""

if {! [file exists $OrdalieDir]} {
    if {[catch {file mkdir $OrdalieDir} msg]} {
        puts "\nError ! Cannot create installation directory $OrdalieDir\n$msg"
        exit 1
    }
} else {
    # OrdalieDir exists : previous installation, empty it
    puts "A previous installation was found in $OrdalieDir : it is replaced."
    set Lf [glob -nocomplain -directory $OrdalieDir -- *]
    if {$Lf ne {}} {
        if {[catch {file delete -force -- {*}$Lf} msg]} {
            puts "\nError ! Cannot empty $OrdalieDir\n$msg"
            exit 1
        }
    }
}

set Lsrc {}
foreach f {lib doc etc LICENSE} {
    lappend Lsrc [file join $SrcDir $f]
}
if {[catch {
    file mkdir [file join $OrdalieDir bin]
    file copy -force -- {*}$Lsrc $OrdalieDir
    file copy -force -- [file join $SrcDir ordalie] $OrdalieExe
    # bin/mafft-<platform> : Ordalie looks for MAFFT in <OrdalieDir>/bin
    foreach f [glob -nocomplain -directory [file join $SrcDir bin] -- *] {
        file copy -force -- $f [file join $OrdalieDir bin]
    }
    # the uninstaller is kept in the installation, since this directory
    # can be deleted once ORDALIE is installed
    if {[file exists [file join $SrcDir uninstall.tcl]]} {
        file copy -force -- [file join $SrcDir uninstall.tcl] $OrdalieDir
        file attributes [file join $OrdalieDir uninstall.tcl] -permissions u+rwx,go+rx
    }
    # symbolic form : works the same with Tcl 8 and Tcl 9 (no octal notation)
    file attributes $OrdalieExe -permissions u+rwx,go+rx
} msg]} {
    puts "\nError ! Copy of the files failed :\n$msg"
    exit 1
}

set Lprogs {msacuts msainfo msaconvert viewpdb viewtree}

if {! $macos} {
    # ---------------------------------------------------------------- linux box
    if {$BinLinkDir ne ""} {
        set linkOk 1
        # When the 'bin' directory is the one holding the executable itself
        # (custom directory), 'ordalie' is already in place : no link needed.
        if {[file normalize $BinLinkDir] ne [file normalize [file join $OrdalieDir bin]]} {
            if {! [MakeLink [file join $BinLinkDir ordalie] $OrdalieExe]} {
                set linkOk 0
                puts "\nUnable to create a link to the executable !"
            }
        }
        foreach prog $Lprogs {
            if {! [MakeLink [file join $BinLinkDir $prog] $OrdalieExe]} {
                set linkOk 0
            }
        }

        if {$linkOk} {
            puts "\n\nORDALIE is installed and ready to run.\n"
        } else {
            puts "\n\nORDALIE is installed, but some links could not be created."
            puts "You can launch ORDALIE by typing :\n$OrdalieExe\n"
        }
        if {! [InPath $BinLinkDir]} {
            puts "Note : $BinLinkDir is not in your PATH."
            puts "To be able to type 'ordalie' from anywhere, add this line to [expr {$FileShellRC ne "" ? $FileShellRC : "your shell startup file"}] :\n"
            puts "    export PATH=[ShQuote $BinLinkDir]:\"\$PATH\"\n"
            puts "and open a new terminal."
        }
    } else {
        # no writable bin directory
        puts "\n\nORDALIE is installed, but no writable 'bin' directory was found to create links."
        puts "You can launch ORDALIE by typing :\n$OrdalieExe\n"
    }
} else {
    # ------------------------------------------------------------ mac os computers
    lappend Lprogs ordalie
    if {$FileShellRC ne ""} {
        # read the file where the aliases will be written to
        set o [open $FileShellRC r]
        set content [read $o]
        close $o

        # keep a copy, since the file is rewritten. Written from $content :
        # 'file copy' of a symbolic link (dotfiles manager) would only copy
        # the link, and the copy would be rewritten too.
        catch {
            set o [open ${FileShellRC}.ordalie.bak w]
            puts -nonewline $o $content
            close $o
        }

        # remove the aliases of a previous installation
        set Lkept {}
        foreach line [split $content "\n"] {
            set drop [string equal $line "# ORDALIE aliases"]
            foreach prog $Lprogs {
                if {[string match "alias $prog=*" $line]} {
                    set drop 1
                    break
                }
            }
            if {! $drop} {
                lappend Lkept $line
            }
        }
        # drop trailing empty lines
        while {[llength $Lkept] > 0 && [lindex $Lkept end] eq ""} {
            set Lkept [lrange $Lkept 0 end-1]
        }

        # create aliases
        set Laliases [list "# ORDALIE aliases"]
        foreach prog $Lprogs {
            lappend Laliases "alias $prog=[ShQuote $OrdalieExe]"
        }

        # write the file back, followed by the new aliases
        if {[catch {
            set o [open $FileShellRC w]
            if {[llength $Lkept] > 0} {
                puts $o [join $Lkept "\n"]
                puts $o ""
            }
            puts $o [join $Laliases "\n"]
            close $o
        } msg]} {
            puts "\nError ! Cannot update $FileShellRC : $msg"
            puts "The previous content was saved in ${FileShellRC}.ordalie.bak"
            exit 1
        }

        puts "\n\nORDALIE is installed. The aliases were added to $FileShellRC"
        puts "To finish the installation, open a new terminal, or type :\n\nsource [ShQuote $FileShellRC]\n\n"
    } else {
        puts "\n\nORDALIE is installed, but no shell startup file could be updated."
        puts "Add these lines to the startup file of your shell (bash or zsh syntax) :\n"
        foreach prog $Lprogs {
            puts "alias $prog=[ShQuote $OrdalieExe]"
        }
        puts ""
    }
}

if {[file exists [file join $OrdalieDir uninstall.tcl]]} {
    puts "To uninstall ORDALIE later, type :\n\n[ShQuote [file join $OrdalieDir uninstall.tcl]]\n"
}

exit 0


# ----------------------------------------------------------------------------
# Personal notes (not part of the installer). They were found after 'exit 0'
# in the original file.
#
# dmg-imprimerie@
#
# tout est en bold
# select shift ne preend pas dernireree seq
# re-aligned seq , noms seq desollidarise des seqs.
# ----------------------------------------------------------------------------
