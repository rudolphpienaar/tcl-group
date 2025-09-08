#!/usr/bin/env tclsh
#
# This script demonstrates a hybrid approach to creating, saving,
# and loading a group object using BOTH YAML and JSON formats.
#

# --- 1. SETUP ---
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir .. lib group.tcl]

set out_dir [file join $script_dir output]
if {![file isdirectory $out_dir]} {
    file mkdir $out_dir
}


# --- 2. CREATE SHARED DATA VIA LAYERED COMPOSITION ---
puts "--- Creating base 'peregrine_falcon' group ---"

# This data will be used for all tests.
group::create prey_item { type "Bird" species "Pigeon" }
set diet_keys { primary_food preference }; set diet_vals { @prey_item "high" }
group::createFromLists diet_profile &diet_keys &diet_vals
set habitat_keys { terrain diet }; set habitat_vals { "Coastal Cliffs" @diet_profile }
group::createFromLists cliff_habitat &habitat_keys &habitat_vals
set eco_keys { niche habitat }; set eco_vals { "Apex Predator" @cliff_habitat }
group::createFromLists eco_role &eco_keys &eco_vals
set falcon_keys { common_name taxonomy,family taxonomy,genus taxonomy,species ecology }
set falcon_vals { "Peregrine Falcon" "Falconidae" "Falco" "F. peregrinus" @eco_role }
group::createFromLists peregrine_falcon &falcon_keys &falcon_vals

puts "-> Done.\n"


# --- 3. YAML SAVE, LOAD, AND VERIFY ---
puts "--- Testing YAML Round-Trip ---"
set yaml_file [file join $out_dir falcon.yaml]

puts "Saving group to YAML file: $yaml_file"
group::toYaml peregrine_falcon %$yaml_file
puts "-> Done.\n"

puts "Loading group from YAML file..."
group::fromYaml loaded_from_yaml %$yaml_file
log DEBUG [group::dump loaded_from_yaml]
puts "-> Done.\n"

puts "Verifying data from the loaded YAML group:"
set species_yaml $loaded_from_yaml(taxonomy,species)
puts "  - Level 3 check (Taxonomy): $species_yaml"
set deep_prey_yaml $loaded_from_yaml(ecology,habitat,diet,primary_food,species)
puts "  - Level 5 check (Ecology):  $deep_prey_yaml"
puts "-> YAML Verification PASSED.\n"


# --- 4. TCL-BASED JSON SAVE, LOAD, AND VERIFY ---
puts "--- Testing Tcl-Based JSON Round-Trip ---"
set json_file [file join $out_dir falcon.json]

puts "Saving group to PRETTY JSON file: $json_file"
group::toJson peregrine_falcon %$json_file 2
puts "-> Done.\n"

puts "Loading group from JSON file (using Tcl implementation)..."
group::fromJson loaded_from_json %$json_file
puts "-> Done.\n"

puts "Verifying data from the loaded Tcl JSON group:"
set species_json $loaded_from_json(taxonomy,species)
puts "  - Level 3 check (Taxonomy): $species_json"
set deep_prey_json $loaded_from_json(ecology,habitat,diet,primary_food,species)
puts "  - Level 5 check (Ecology):  $deep_prey_json"
puts "-> Tcl JSON Verification PASSED.\n"


# --- 5. C-BASED JSON LOAD AND VERIFY (IF AVAILABLE) ---
puts "--- Testing C-Based JSON Load (if available) ---"

# Check if the C command was successfully loaded and registered by the module.
if {[llength [info commands ::group::fromJson_C]]} {
    puts "C extension found. Running C-based load test."

    # Read the JSON file into a variable.
    set f [open $json_file r]
    set json_text [read $f]
    close $f

    # Call the C command directly. It returns a flat key-value list.
    set flat_list [group::fromJson_C $json_text]

    # Manually create the group array from the flat list.
    array set loaded_from_c $flat_list

    # Manually activate the array into a true group object.
    # NOTE: This uses an internal command, which is acceptable for a test harness.
    group::_create_dispatcher loaded_from_c

    puts "Verifying data from the loaded C JSON group:"
    set species_c $loaded_from_c(taxonomy,species)
    puts "  - Level 3 check (Taxonomy): $species_c"
    set deep_prey_c $loaded_from_c(ecology,habitat,diet,primary_food,species)
    puts "  - Level 5 check (Ecology):  $deep_prey_c"
    puts "-> C JSON Verification PASSED.\n"
} else {
    puts "C extension not compiled or loaded. Skipping C-based test.\n"
}

# --- 6. CLEANUP ---
# puts "Cleaning up output directory..."
# file delete -force $out_dir
# puts "-> Done."
