# Taken from wiki.tcl.tk and updated
#
# Finds an installed web browser (Firefox, Chrome/Chromium, Edge, Opera,
# Brave, Safari on macOS) and opens a file or an URL with it. Ordalie uses
# it only as a last resort, when the system handler (start, open, xdg-open,
# gio, sensible-browser) is not available (OpenInBrowser, ordali_web.tcl).
#
# Changes (2026-11-25) :
#   - Windows : the localized "Program Files" tables are removed (since Vista
#     the real folder is "Program Files" in every language) ; the folders
#     are taken from ProgramFiles, ProgramFiles(x86), ProgramW6432 and
#     LOCALAPPDATA (per-user installs of Chrome, Opera).
#   - Internet Explorer removed (retired, absent from Windows 11).
#   - Linux : several names per browser (chromium, google-chrome-stable,
#     firefox-esr, microsoft-edge-stable ...), Brave added ; the version is
#     asked to the binary found.
#   - macOS : /Applications then ~/Applications ; Firefox binary "firefox"
#     (firefox-bin for old versions) ; opened with "open -a".
#   - OpenFileInBrowser : runs the path found (Windows was given the short
#     name of the browser, e.g. "edge", which is not a command).
# Older changes : Edge support, unbalanced braces, string comparisons.

package provide browser_info 1.0

namespace eval ::browser_info {

    # macOS : application bundle and binaries inside Contents/MacOS
    variable APP_ON_MAC
    array set APP_ON_MAC {
        firefox {Firefox.app {firefox firefox-bin}}
        chrome  {{Google Chrome.app} {{Google Chrome}}}
        safari  {Safari.app {Safari}}
        opera   {Opera.app {Opera}}
        edge    {{Microsoft Edge.app} {{Microsoft Edge}}}
        brave   {{Brave Browser.app} {{Brave Browser}}}
    }

    # Windows : sub-directories (of Program Files or LOCALAPPDATA) and binary,
    # with '/' (file join accepts it on Windows too)
    variable BINARY_ON_WINDOWS
    array set BINARY_ON_WINDOWS {
        firefox {{Mozilla Firefox} firefox.exe}
        chrome  {Google/Chrome/Application chrome.exe}
        opera   {Opera opera.exe Programs/Opera launcher.exe}
        edge    {Microsoft/Edge/Application msedge.exe}
        brave   {BraveSoftware/Brave-Browser/Application brave.exe}
    }

    # Linux and other unix : names of the binary, in order
    variable BINARY_ON_LINUX
    array set BINARY_ON_LINUX {
        firefox {firefox firefox-esr}
        chrome  {google-chrome google-chrome-stable chromium chromium-browser}
        opera   {opera}
        edge    {microsoft-edge microsoft-edge-stable}
        brave   {brave-browser brave}
    }

    # Windows registry : list of triples {key pattern_of_last_subkey value}
    variable BROWSER_PATH_IN_WINDOWS_REGISTRY
    array set BROWSER_PATH_IN_WINDOWS_REGISTRY {
        firefox {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe} {} {}
            {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe} {} {}
        }
        chrome {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe} {} {}
            {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe} {} {}
        }
        opera {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\opera.exe} {} {}
            {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\opera.exe} {} {}
        }
        edge {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe} {} {}
            {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe} {} {}
        }
        brave {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\brave.exe} {} {}
            {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe} {} {}
        }
    }

    variable BROWSER_VERSION_IN_WINDOWS_REGISTRY
    array set BROWSER_VERSION_IN_WINDOWS_REGISTRY {
        opera {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall} {[Oo]pera *} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall} {[Oo]pera *} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall} {[Oo]pera *} DisplayVersion
        }
        chrome {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome} {} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome} {} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome} {} DisplayVersion
        }
        firefox {
            {HKEY_CURRENT_USER\Software\Mozilla\Mozilla Firefox} {} CurrentVersion
            {HKEY_LOCAL_MACHINE\Software\Mozilla\Mozilla Firefox} {} CurrentVersion
            {HKEY_LOCAL_MACHINE\Software\Wow6432Node\Mozilla\Mozilla Firefox} {} CurrentVersion
        }
        edge {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge} {} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge} {} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge} {} DisplayVersion
        }
        brave {
            {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\BraveSoftware Brave-Browser} {} DisplayVersion
            {HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\BraveSoftware Brave-Browser} {} DisplayVersion
        }
    }

    namespace export firefox chrome opera edge brave

    # -------------------------------------------------------------------------

    oo::class create browser_info {
        variable browser_name APP_ON_MAC BINARY_ON_WINDOWS BINARY_ON_LINUX BROWSER_PATH_IN_WINDOWS_REGISTRY BROWSER_VERSION_IN_WINDOWS_REGISTRY

        constructor {browserName} {
            set browser_name $browserName
            foreach varname [info class variables [self class]] {
                if {[string is upper [string index $varname 0]]} {
                    namespace upvar ::browser_info $varname [self namespace]::$varname
                }
            }
        }

        method name {} {
            return $browser_name
        }

        method windows_folders {} {
            # folders where browsers are installed : Program Files (64
            # and 32 bits), and LOCALAPPDATA for per-user installs.
            # The keys contain parentheses : given as strings
            set Ld {}
            foreach k [list ProgramFiles "ProgramFiles(x86)" ProgramW6432 LOCALAPPDATA] {
                foreach n [array names ::env] {
                    if {[string equal -nocase $n $k] && $::env($n) ne "" && $::env($n) ni $Ld} {
                        lappend Ld $::env($n)
                    }
                }
            }
            if {$Ld eq {}} {
                set Ld [list {C:\Program Files} {C:\Program Files (x86)}]
            }
            return $Ld
        }

        method default_windows_location_of_browser {} {
            if {! [info exists BINARY_ON_WINDOWS($browser_name)]} {
                return {}
            }
            foreach directory [my windows_folders] {
                foreach {subdir binary} $BINARY_ON_WINDOWS($browser_name) {
                    set binary_path [file join $directory $subdir $binary]
                    if {[file isfile $binary_path]} {
                        return [file nativename $binary_path]
                    }
                }
            }
            return {}
        }

        method first_value_found_in_windows_registry {data_of_paths} {
            if {[catch {package require registry}]} {
                return ""
            }
            set value_found ""
            foreach {subpath_of_keys pattern_of_last_key key_value} $data_of_paths {
                if {$pattern_of_last_key ne ""} {
                    if {[catch {registry keys $subpath_of_keys $pattern_of_last_key} list_of_subkeys] || [llength $list_of_subkeys] == 0} {
                        continue
                    }
                    set key_name "$subpath_of_keys\\[lindex $list_of_subkeys 0]"
                } else {
                    set key_name $subpath_of_keys
                }
                if {! [catch {registry get $key_name $key_value} value_found] && $value_found ne ""} {
                    return $value_found
                }
                set value_found ""
            }
            return $value_found
        }

        method mac_application {} {
            # path of the application bundle, or ""
            if {! [info exists APP_ON_MAC($browser_name)]} {
                return {}
            }
            set app [lindex $APP_ON_MAC($browser_name) 0]
            set Ld [list /Applications]
            if {[info exists ::env(HOME)]} {
                lappend Ld [file join $::env(HOME) Applications]
            }
            foreach d $Ld {
                if {[file isdirectory [file join $d $app]]} {
                    return [file join $d $app]
                }
            }
            return {}
        }

        method get_path {} {
            # path of the browser binary, "" if not found
            set path_to_browser {}
            if {$::tcl_platform(os) eq "Darwin"} {
                set app [my mac_application]
                if {$app ne ""} {
                    foreach bin [lindex $APP_ON_MAC($browser_name) 1] {
                        set p [file join $app Contents MacOS $bin]
                        if {[file isfile $p]} {
                            return $p
                        }
                    }
                }
            } elseif {$::tcl_platform(platform) eq "windows"} {
                if {[info exists BROWSER_PATH_IN_WINDOWS_REGISTRY($browser_name)]} {
                    set path_to_browser [string trim [my first_value_found_in_windows_registry $BROWSER_PATH_IN_WINDOWS_REGISTRY($browser_name)] "\""]
                }
                if {$path_to_browser ne "" && ! [file isfile $path_to_browser]} {
                    set path_to_browser {}
                }
                if {$path_to_browser eq ""} {
                    set path_to_browser [my default_windows_location_of_browser]
                }
            } elseif {[info exists BINARY_ON_LINUX($browser_name)]} {
                foreach bin $BINARY_ON_LINUX($browser_name) {
                    set exe [lindex [auto_execok $bin] 0]
                    if {$exe ne ""} {
                        return $exe
                    }
                }
            }
            return $path_to_browser
        }

        method get_version {} {
            # version of the browser, "" if unknown
            if {$::tcl_platform(platform) eq "windows"} {
                if {! [info exists BROWSER_VERSION_IN_WINDOWS_REGISTRY($browser_name)]} {
                    return ""
                }
                return [my get_version_from_text [my first_value_found_in_windows_registry $BROWSER_VERSION_IN_WINDOWS_REGISTRY($browser_name)]]
            }
            set bin [my get_path]
            if {$bin eq ""} {
                return ""
            }
            # some browsers write the version on stderr
            catch {exec $bin --version 2>@1} output
            foreach line [split $output "\n"] {
                if {[set v [my get_version_from_text $line]] ne ""} {
                    return $v
                }
            }
            return ""
        }

        method get_version_from_text {text} {
            if {[regexp {(\d+\.\d+(?:\.\d+)*)} $text -> browser_version]} {
                return $browser_version
            }
            return ""
        }

        method open {url} {
            # opens url (or file) with this browser, 1 if launched
            set path [my get_path]
            if {$path eq ""} {
                return 0
            }
            if {$::tcl_platform(os) eq "Darwin"} {
                # a binary run directly starts a second instance
                exec open -a [my mac_application] $url &
            } else {
                exec $path $url &
            }
            return 1
        }
    }

    # -------------------------------------------------------------------------
    # Singleton instances
    # -------------------------------------------------------------------------

    foreach b {firefox chrome opera edge brave} {
        browser_info create $b $b
    }
    if {$::tcl_platform(os) eq "Darwin"} {
        browser_info create safari safari
    }
    unset b

    # -------------------------------------------------------------------------

    proc ::browser_info::getbrowserinfo {} {
        # first browser found : {browser_name path}, or {}
        if {$::tcl_platform(platform) eq "windows"} {
            set browser_list {edge firefox chrome brave opera}
        } elseif {$::tcl_platform(os) eq "Darwin"} {
            set browser_list {safari firefox chrome edge brave opera}
        } else {
            set browser_list {firefox chrome edge brave opera}
        }

        foreach browser $browser_list {
            set p [::browser_info::$browser get_path]
            if {$p ne ""} {
                return [list $browser $p]
            }
        }
        return {}
    }

}; # end namespace eval ::browser_info

# -------------------------------------------------------------------------

proc OpenFileInBrowser {html_file} {
    # opens html_file (or an URL) with the first browser found ; 1 if done
    if {[llength [set browser_info [::browser_info::getbrowserinfo]]] == 0} {
        FaireLire "Cannot detect any web browser in this system!"
        return 0
    }
    set browser [lindex $browser_info 0]
    if {[catch {::browser_info::$browser open $html_file} ok]} {
        FaireLire "Could not launch $browser :\n$ok"
        return 0
    }

    return $ok
}
