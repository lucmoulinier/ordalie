#!/bin/sh
# The two lines below are read by sh, bash or zsh and restart this script with
# the first tclsh found. Tcl reads them as a single comment. \
for t in tclsh tclsh9.0 tclsh8.6 tclsh8.5; do if command -v $t >/dev/null 2>&1; then exec $t "$0" "$@"; fi; done; \
echo "Error ! tclsh was not found. Please install Tcl/Tk 8.6, then run this script again." >&2; exit 1

#
# This script uninstalls ORDALIE software from Unix-like machines (Linux and
# macOS). It undoes what install.tcl did :
#  - Linux : removes the symbolic links ordalie, msacut, ... that point to
#            the ORDALIE executable ;
#  - macOS : removes the ORDALIE aliases from the shell startup files ;
#  - removes the ORDALIE installation directory.
#
# (c) Luc Moulinier 2025
#
# Usage : ./uninstall.tcl  or  sh uninstall.tcl  or  tclsh uninstall.tcl
# (from bash, zsh or any other shell). install.tcl copies this script into
# the installation directory (for example ~/ordalie/uninstall.tcl).

package require Tcl 8.5-
package require platform

# ----------------------------------------------------------------------------
# Procedures (ShellFileToUse and ShQuote are the same as in install.tcl)
# ----------------------------------------------------------------------------

# Prompt the user and return the trimmed answer.
# Abort cleanly on end of file (Ctrl-D, closed stdin).
proc Ask {prompt} {
    puts -nonewline $prompt
    flush stdout
    if {[gets stdin line] < 0} {
        puts "\n\nUninstallation aborted."
        exit 1
    }
    return [string trim $line]
}

proc AskConfirm {msg} {
    while {1} {
        set rep [string tolower [Ask "$msg (y/n) : "]]
        switch -- $rep {
            "y" - "yes" { return 1 }
            "n" - "no"  { return 0 }
            default     { puts "Please answer y or n." }
        }
    }
}

# Return the startup file read by the user's interactive shell, which
# received the ORDALIE aliases (macOS).
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

# Does $dir look like an ORDALIE installation made by install.tcl ?
proc IsOrdalieDir {dir} {
    return [expr {[file isdirectory $dir] && [file exists [file join $dir bin ordalie]]}]
}

# Remove the symbolic link $link if it points to $exe. Never touches a
# regular file, nor a link to something else. Return 1 if removed.
proc RemoveLinkTo {link exe} {
    if {[catch {file lstat $link st}] || $st(type) ne "link"} {
        return 0
    }
    if {[catch {file readlink $link} target]} {
        return 0
    }
    if {$target ne $exe && [file normalize $target] ne [file normalize $exe]} {
        return 0
    }
    if {[catch {file delete -- $link} msg]} {
        puts "  Warning : cannot remove $link : $msg"
        return 0
    }
    puts "  Removed link : $link"
    return 1
}

# Remove the ORDALIE aliases (and the "# ORDALIE aliases" line) from $file.
# A copy of the previous content is written to $file.ordalie.bak.
proc RemoveAliases {file progs} {
    if {[catch {
        set o [open $file r]
        set content [read $o]
        close $o
    } msg]} {
        puts "  Warning : cannot read $file : $msg"
        return
    }

    set Lkept {}
    set changed 0
    foreach line [split $content "\n"] {
        set drop [string equal $line "# ORDALIE aliases"]
        foreach prog $progs {
            if {[string match "alias $prog=*" $line]} {
                puts "  Removed alias : $line"
                set drop 1
                break
            }
        }
        if {$drop} {
            set changed 1
        } else {
            lappend Lkept $line
        }
    }
    if {! $changed} {
        return
    }

    # Written from $content : 'file copy' of a symbolic link (dotfiles
    # manager) would only copy the link.
    catch {
        set o [open ${file}.ordalie.bak w]
        puts -nonewline $o $content
        close $o
    }
    # drop trailing empty lines, then end the file with one newline
    while {[llength $Lkept] > 0 && [lindex $Lkept end] eq ""} {
        set Lkept [lrange $Lkept 0 end-1]
    }
    if {[catch {
        set o [open $file w]
        if {[llength $Lkept] > 0} {
            puts $o [join $Lkept "\n"]
        }
        close $o
    } msg]} {
        puts "  Error ! Cannot update $file : $msg"
        puts "  The previous content was saved in ${file}.ordalie.bak"
        return
    }
    puts "  Updated : $file (previous content saved in ${file}.ordalie.bak)"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

set os [::platform::generic]
set macos [expr {[string first "macosx" $os] > -1}]

set shell ""
set FileShellRC ""
if {[info exists env(SHELL)] && $env(SHELL) ne ""} {
    set shell [file tail $env(SHELL)]
    set FileShellRC [ShellFileToUse $shell $macos 0]
}

puts "\n\n"
puts "    ORDALIE Uninstallation :"
puts "------------------------------\n"

# msacuts : name of the msacut link made by the installers before 2026/11/26
set Lprogs {msacut msacuts msainfo msaconvert viewpdb viewtree ordalie}

# 1. this script is normally in the installation directory itself
set OrdalieDir ""
set ScriptDir [file dirname [file normalize [info script]]]
if {[IsOrdalieDir $ScriptDir]} {
    set OrdalieDir $ScriptDir
} else {
    # 2. the standard locations of install.tcl
    set candidates {}
    if {[info exists env(HOME)]} {
        lappend candidates [file join $env(HOME) ordalie]
    }
    lappend candidates [file join /usr/local ordalie]
    foreach c $candidates {
        if {[IsOrdalieDir $c]} {
            set OrdalieDir $c
            break
        }
    }
}

# 3. otherwise ask the user
while {$OrdalieDir eq ""} {
    puts "The ORDALIE installation directory was not found."
    set dir [Ask "Type the path to the ORDALIE installation directory (empty answer to quit) : "]
    if {$dir eq ""} {
        puts "Uninstallation cancelled."
        exit 0
    }
    # Expand a leading ~ ourselves (Tcl 9 does not do it any more)
    if {([string equal $dir "~"] || [string match "~/*" $dir]) && [info exists env(HOME)]} {
        set dir [file join $env(HOME) [string range $dir 2 end]]
    }
    set dir [file normalize $dir]
    if {[IsOrdalieDir $dir]} {
        set OrdalieDir $dir
    } elseif {[IsOrdalieDir [file join $dir ordalie]]} {
        # the directory chosen at installation, which contains 'ordalie'
        set OrdalieDir [file join $dir ordalie]
    } else {
        puts "Error ! $dir is not an ORDALIE installation (there is no bin/ordalie in it).\n"
    }
}
set OrdalieExe [file join $OrdalieDir bin ordalie]

puts "ORDALIE installation found : $OrdalieDir\n"
if {! [AskConfirm "This will permanently remove ORDALIE from $OrdalieDir. Continue ?"]} {
    puts "Uninstallation cancelled."
    exit 0
}
puts ""

if {! $macos} {
    # ---------------------------------------------------------------- linux box
    # install.tcl created the links in <installation directory>/bin :
    # ~/bin, /usr/local/bin, or <OrdalieDir>/bin (removed below)
    puts "Removing symbolic links ..."
    set Lbin [list [file join [file dirname $OrdalieDir] bin] /usr/local/bin]
    if {[info exists env(HOME)]} {
        lappend Lbin [file join $env(HOME) bin]
    }
    set Ldone {}
    set nLinks 0
    foreach bindir $Lbin {
        set nb [file normalize $bindir]
        if {$nb in $Ldone || ! [file isdirectory $bindir]} {
            continue
        }
        lappend Ldone $nb
        foreach prog $Lprogs {
            incr nLinks [RemoveLinkTo [file join $bindir $prog] $OrdalieExe]
        }
    }
    if {$nLinks == 0} {
        puts "  No link to $OrdalieExe was found."
    }
} else {
    # ------------------------------------------------------------ mac os computers
    # the file of the current shell, and any other startup file that still
    # holds ORDALIE aliases (the user may have changed of shell)
    puts "Removing shell aliases ..."
    set Lfiles {}
    if {$FileShellRC ne "" && [file exists $FileShellRC]} {
        lappend Lfiles $FileShellRC
    }
    if {[info exists env(HOME)]} {
        set Lother {}
        foreach c {.zshrc .bash_profile .bash_login .profile .bashrc} {
            lappend Lother [file join $env(HOME) $c]
        }
        if {[info exists env(ZDOTDIR)]} {
            lappend Lother [file join $env(ZDOTDIR) .zshrc]
        }
        foreach f $Lother {
            if {$f in $Lfiles || ! [file isfile $f] || ! [file writable $f]} {
                continue
            }
            if {! [catch {set o [open $f r]; set c [read $o]; close $o}] \
                    && [string first "# ORDALIE aliases" $c] > -1} {
                lappend Lfiles $f
            }
        }
    }
    if {$Lfiles eq {}} {
        puts "  No shell startup file with ORDALIE aliases was found."
    }
    foreach f $Lfiles {
        RemoveAliases $f $Lprogs
    }
}

puts "\nRemoving installation directory $OrdalieDir ..."
if {[catch {file delete -force -- $OrdalieDir} msg]} {
    puts "Error ! Could not remove $OrdalieDir : $msg"
    exit 1
}
puts "  Removed : $OrdalieDir"

puts "\n\nORDALIE has been uninstalled."
if {$macos} {
    puts "Open a new terminal : the aliases are still defined in the terminals already open."
} else {
    puts "If you added an 'export PATH=...' line for ORDALIE to your shell startup file,"
    puts "you can now remove it."
}
puts ""
exit 0
