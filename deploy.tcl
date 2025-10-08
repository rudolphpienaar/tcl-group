#!/usr/bin/env tclsh

set SCRIPT_DOCS {
NAME

  deploy.tcl - A general-purpose installer for Tcl packages.

SYNOPSIS

  tclsh deploy.tcl [--link] [--help] <versioned_name> <install_root>

DESCRIPTION

  This script installs or deploys a Tcl library from a source repository
  into a versioned directory structure suitable for use with Tcl's package
  management system (`TCLLIBPATH`).

  It follows a convention-based approach:
  - Tcl source files (.tcl) are expected in a `lib/` directory.
  - Optional pre-compiled C extensions (.so, .dylib, .dll) are expected
    in a `clib/` directory.

  The script creates the versioned destination, copies or links the files,
  and generates a `pkgIndex.tcl` that correctly handles both Tcl and C libraries.

ARGS

  --link
      (Optional) If specified, create symbolic links to the source files
      instead of copying them. This simulates an "editable" install.

  --help, -h
      (Optional) Shows this help message and exits.

  <versioned_name>
      The name of the versioned directory to create (e.g., "utils-1.0").

  <install_root>
      The root directory where Tcl libraries are stored. This path can
      use '~' to refer to the home directory.

EXAMPLE

  # Standard install (copies files)
  tclsh deploy.tcl utils-1.0 ~/src/tcl/lib
}

# --- Function for printing usage and exiting ---
proc usage {} {
    global SCRIPT_DOCS
    puts $SCRIPT_DOCS
    exit 1
}

# --- 1. Argument Parsing ---
set link_mode 0
set new_argv [list]
foreach arg $argv {
    if {$arg eq "--link"} {
        set link_mode 1
    } elseif {$arg eq "--help" || $arg eq "-h"} {
        usage
    } else {
        lappend new_argv $arg
    }
}
set argv $new_argv
set argc [llength $argv]

if {$argc != 2} {
    puts stderr "Error: Incorrect number of arguments."
    usage
}

lassign $argv versioned_name install_root

# --- 2. Define Paths ---
set install_root [file normalize $install_root]
set script_path [file normalize [info script]]
set script_dir [file dirname $script_path]
set source_lib_dir [file join $script_dir "lib"]
set source_clib_dir [file join $script_dir "clib"]
set dest_dir [file join $install_root $versioned_name]

# --- 3. Pre-flight Checks ---
set TclShell [info nameofexecutable]
if {![file isdirectory $source_lib_dir]} {
    puts stderr "Error: Source directory 'lib/' not found in repository root."
    exit 1
}
if {[catch {exec $TclShell -c {} < /dev/null} err]} {
    puts stderr "Error: 'tclsh' not found or not executable. Details: $err"
    exit 1
}

# --- 4. Installation ---
puts "--> Processing Tcl library files from 'lib/'..."
set dest_lib_dir [file join $dest_dir "lib"]
if {[catch {file mkdir $dest_lib_dir} err]} {
    puts stderr "Error: Failed to create destination directory '$dest_lib_dir': $err"
    exit 1
}
set source_files [glob -nocomplain [file join $source_lib_dir *.tcl]]
if {[llength $source_files] == 0} {
    puts stderr "Warning: No .tcl files found in '$source_lib_dir'."
}
foreach file $source_files {
    if {$link_mode} {
        set link_path [file join $dest_lib_dir [file tail $file]]
        if {[catch {file link -symbolic $link_path [file normalize $file]} err]} {
            puts stderr "Error: Failed to create link for '$file': $err"
            exit 1
        }
    } else {
        if {[catch {file copy $file $dest_lib_dir} err]} {
            puts stderr "Error: Failed to copy '$file': $err"
            exit 1
        }
    }
}

# Conditionally process the clib directory
if {[file isdirectory $source_clib_dir]} {
    puts "--> Processing C extension files from 'clib/'..."
    set dest_clib_dir [file join $dest_dir "clib"]
    if {[catch {file mkdir $dest_clib_dir} err]} {
        puts stderr "Error: Failed to create destination directory '$dest_clib_dir': $err"
        exit 1
    }
    set compiled_files [glob -nocomplain \
        [file join $source_clib_dir *.so] \
        [file join $source_clib_dir *.dll] \
        [file join $source_clib_dir *.dylib]]

    foreach file $compiled_files {
        if {$link_mode} {
            set link_path [file join $dest_clib_dir [file tail $file]]
            if {[catch {file link -symbolic $link_path [file normalize $file]} err]} {
                puts stderr "Error: Failed to create link for '$file': $err"
                exit 1
            }
        } else {
            if {[catch {file copy $file $dest_clib_dir} err]} {
                puts stderr "Error: Failed to copy '$file': $err"
                exit 1
            }
        }
    }
}

# --- 5. Generate Package Index ---
puts "--> Generating package index in '$dest_dir'..."
set old_dir [pwd]
if {[catch {cd $dest_dir} err]} {
    puts stderr "Error: Failed to change directory to '$dest_dir': $err"
    exit 1
}

set patterns_to_scan [list lib/*.tcl]
if {[file isdirectory "clib"]} {
    lappend patterns_to_scan "clib/*.so" "clib/*.dylib" "clib/*.dll"
}

if {[catch {pkg_mkIndex . {*}$patterns_to_scan} err]} {
    puts stderr "Error: pkg_mkIndex command failed: $err"
    cd $old_dir
    exit 1
}

cd $old_dir

# --- 6. Completion ---
puts ""
puts "Deployment of '$versioned_name' to '$install_root' is complete."
if {$link_mode} {
    puts "   Mode: Symbolic Links (Editable)"
} else {
    puts "   Mode: Copied Files (Standard)"
}
puts "   Ensure '$install_root' is included in your TCLLIBPATH."
