#!/usr/bin/env tclsh
#
# This script demonstrates a hybrid approach to creating, saving,
# and loading a deeply nested group object.
#

# --- 1. SETUP ---
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir .. lib group.tcl]

set out_dir [file join $script_dir output]
if {![file isdirectory $out_dir]} {
    file mkdir $out_dir
}


# --- 2. CREATE DATA VIA LAYERED COMPOSITION (5 LEVELS) ---
puts "Creating nested components for bird's ecology..."

# Level 5 (Deepest component)
group::create prey_item {
    type    "Bird"
    species "Pigeon"
}

# Level 4 (Composes Level 5)
set diet_keys { primary_food preference }
set diet_vals { @prey_item "high" }
group::createFromLists diet_profile &diet_keys &diet_vals

# Level 3 (Composes Level 4)
set habitat_keys { terrain diet }
set habitat_vals { "Coastal Cliffs" @diet_profile }
group::createFromLists cliff_habitat &habitat_keys &habitat_vals

# Level 2 (Composes Level 3)
set eco_keys { niche habitat }
set eco_vals { "Apex Predator" @cliff_habitat }
group::createFromLists eco_role &eco_keys &eco_vals

# --- 3. CREATE FINAL GROUP (HYBRID APPROACH) ---
puts "Creating final 'peregrine_falcon' group..."

# To use composition sigils, we must use createFromLists.
# First, define the keys and values for the top-level group.
set falcon_keys {
    common_name
    taxonomy,family
    taxonomy,genus
    taxonomy,species
    ecology
}
set falcon_vals {
    "Peregrine Falcon"
    "Falconidae"
    "Falco"
    "F. peregrinus"
    @eco_role
}

# Now, create the final group using the correct constructor.
group::createFromLists peregrine_falcon &falcon_keys &falcon_vals

puts "-> Done."
puts ""

# --- 4. SAVE AND LOAD THE FINAL GROUP ---
set yaml_file [file join $out_dir falcon.yaml]

puts "Saving final group to YAML file: $yaml_file"
group::toYaml peregrine_falcon %$yaml_file
puts "-> Done."
puts ""

puts "Loading group from YAML file..."
group::fromYaml loaded_falcon %$yaml_file
puts "Read:"
puts "-> Done."
puts ""


# --- 5. VERIFICATION ---
puts "Verifying data from the loaded group:"

# Access a value from the comma-separated key part
set species $loaded_falcon(taxonomy,species)
puts "  - Level 3 check (Taxonomy): $species"

# Access a value from the deepest part of the composed structure
# Path: ecology -> habitat -> diet -> primary_food -> species (5 levels)
set deep_prey $loaded_falcon(ecology,habitat,diet,primary_food,species)
puts "  - Level 5 check (Ecology):  $deep_prey"
puts ""


# --- 6. CLEANUP ---
# puts "Cleaning up output directory..."
# file delete -force $out_dir
# puts "-> Done."
