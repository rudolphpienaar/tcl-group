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

# This data will be used for both YAML and JSON tests.
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
puts [group::dump loaded_from_yaml]
puts "-> Done.\n"

puts "Verifying data from the loaded YAML group:"
set species_yaml $loaded_from_yaml(taxonomy,species)
puts "  - Level 3 check (Taxonomy): $species_yaml"
set deep_prey_yaml $loaded_from_yaml(ecology,habitat,diet,primary_food,species)
puts "  - Level 5 check (Ecology):  $deep_prey_yaml"
puts "-> YAML Verification PASSED.\n"

# --- 4. JSON SAVE, LOAD, AND VERIFY ---
puts "--- Testing JSON Round-Trip ---"

# Define paths for both minified and pretty-printed files.
set min_json_file [file join $out_dir falcon.min.json]
set pretty_json_file [file join $out_dir falcon.pretty.json]

# --- SAVE ---
# Call 1: Default (minified) output.
# No third argument is provided, so it defaults to an indent_width of 0.
puts "Saving group to MINIFIED JSON file: $min_json_file"
group::toJson peregrine_falcon %$min_json_file
puts "-> Done.\n"

# Call 2: Pretty-printed output with a 2-space indent.
# We provide '2' as the third argument for the indent_width.
puts "Saving group to PRETTY JSON file: $pretty_json_file"
group::toJson peregrine_falcon %$pretty_json_file 2
puts "-> Done.\n"

# --- LOAD AND VERIFY ---
# We only need to load one of the files to verify the data is correct.
puts "Loading group from MINIFIED JSON file..."
group::fromJson loaded_from_json %$min_json_file
puts [group::dump loaded_from_json]
puts "-> Done.\n"

puts "Verifying data from the loaded JSON group:"
set species_json $loaded_from_json(taxonomy,species)
puts "  - Level 3 check (Taxonomy): $species_json"
set deep_prey_json $loaded_from_json(ecology,habitat,diet,primary_food,species)
puts "  - Level 5 check (Ecology):  $deep_prey_json"
puts "-> JSON Verification PASSED.\n"

# --- 5. CLEANUP ---
# puts "Cleaning up output directory..."
# file delete -force $out_dir
# puts "-> Done."
