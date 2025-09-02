#
# This script demonstrates the prototypical inheritance features
# of the Tcl Group module.
#

# Add the library directory to the auto_path and load the package
lappend auto_path [file join [file dirname [info script]] ../lib]
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir .. lib group.tcl]

#package require group

# ===========================================================
# == 1. Define a "base" group to act as our prototype
# ===========================================================

# Define some bird-related methods
proc aboutMe_print {group_name} {
    upvar 1 $group_name group
    puts ""
    puts "--- Info for group $group_name ---"
    puts "Taxonomy: $group(taxonomy)"
    puts "Type: $group(type)"
    puts "Name: $group(name)"

    if {[info exists group(parent)]} {
        puts "Parent-group: $group(parent)"
    } else {
        puts "Parent-group: None"
    }
    puts "---------------------------"
    puts ""
}

proc name_set {group_name name} {
    upvar 1 $group_name group
    set group(name) $name
}

proc hop {group_name where} {
    upvar 1 $group_name group
    puts "$group(type): I can hop! $where"
}

proc nest {group_name where} {
    upvar 1 $group_name group
    puts "$group(type): I am nesting! $where"
}

group create bird {
    # Group member variables
    name            "bird-basegroup"
    type            "bird_generic"
    taxonomy        "animalia/chordata/aves"

    # Group methods
    aboutMe_print   "aboutMe_print"
    name_set        "name_set"
    hop             "hop"
    nest            "nest"
}

puts "--- Testing the bird object ---"
bird aboutMe_print
bird hop "On the ground"
bird nest "In a tree"
puts ""

# ===========================================================
# == 2. Create a "child" group by copying the prototype
# ===========================================================

group copy eagle bird
group copy robin bird

set eagle(type) "raptor"
set eagle(name) "fish-eagle"
append eagle(taxonomy) "/accipitriformes/accipitridae/haliaeetus/vocifer"

set robin(type) "thrush"
set robin(name) "garden-variety"
append robin(taxonomy) "/passeriforms/turdidae/turdus/migratorius"

eagle aboutMe_print
eagle nest "In a tree by a body of water"
robin aboutMe_print
robin hop "Usually in someone's garden"

# ===========================================================
# == 3. Demonstrate the LIVE prototype chain
# ===========================================================

proc fly {group_name where} {
    upvar 1 $group_name group
    puts "$group(name) -- I can fly! $where"
}

# Add this to the base group... now all copies automatically
# get the behavior!
set bird(fly) fly

puts "\nAdded 'fly' method to base group. Now all copies can fly too! "
eagle fly "Over a lake!"
robin fly "Over a backyard!"
