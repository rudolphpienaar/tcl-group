#
# This variable contains the main documentation for the module.
# It is used by the 'group man' command for runtime introspection.
#
set GROUP_MODULE_INFO {
NAME

    group.tcl

DESCRIPTION

    This package provides a system for creating and managing "groups," which are
    composite data objects built on Tcl's associative arrays.

    A group is a collection of related data fields and associated "methods"
    (procedure names). It supports two main object-oriented patterns: composition
    and prototypical inheritance.

CORE CONCEPTS

    1. Composition: Assembling Groups from Components

    The primary data-structuring feature is the ability to build a group by
    assembling it from smaller, reusable components. This is done using the
    'group createFromLists' command, which understands special syntactic
    markers (sigils) to control its behavior.

    * '&varname' (Pass-by-Name): An argument starting with '&' is treated as
      the name of a variable containing a list, not the list itself.

    * '@varname' (Composition): A value in the data list starting with '@'
      is treated as a component array/group to be flattened into the parent.

    * '*varname' (Dereference): A value in the data list starting with '*'
      is treated as a variable name whose value should be used.

    2. Prototypical Inheritance: Cloning and Method Delegation

    The system also provides a lightweight, prototype-based OOP model for
    sharing behavior. New groups can be created by cloning a "prototype"
    ('group copy'). The new group maintains a live link to its parent,
    allowing it to inherit methods dynamically.

EXAMPLES

    # --- Example 1: Composition ---
    array set component_schedule { Mon "daily", Tue "daily", Sun "monthly" }
    group::create component_notifications { tapeCmd "echo 'Tape notification'" }
    set keys {name schedule notifications admin}
    set admin_user "rudolph"
    set values {my_backup @component_schedule @component_notifications *admin_user}
    group::createFromLists my_backup &keys &values

    # --- Example 2: Prototypical Inheritance ---
    proc print_name {group_name} { upvar 1 $group_name g; puts $g(name) }
    group::create base_group name "Base" print "print_name"
    group::copy child_group base_group
    set child_group(name) "Child"
    child_group print ; # -> Outputs: Child

    # --- Example 3: File I/O with the '%' sigil ---
    # The '%' sigil tells the I/O procs to treat the argument as a file path.
    # If the sigil is absent, the argument is treated as in-memory data.
    group::toLegacy my_backup %my_backup.object
    group::fromYaml new_group %my_backup.yaml

DEBUGGING AND LOGGING
    The module includes a conditional logging system for debugging purposes.
    The log function supports four levels: DEBUG, INFO, WARN, and ERROR.

    Logging is controlled by environment variables:
    * export GROUP_LOG_LEVEL_DEBUG=1    - Enable debug messages
    * export GROUP_LOG_LEVEL_INFO=1     - Enable info messages
    * export GROUP_LOG_LEVEL_WARN=1     - Enable warning messages
    * export GROUP_LOG_LEVEL_ERROR=1   - Enable error messages

    Log output includes timestamp, level, and color coding:
    [Dec 31 14:30:45] [DEBUG] Creating dispatcher for 'my_group'
    [Dec 31 14:30:45] [ERROR] Method 'unknown' not found

    Usage in code:
    log DEBUG "Detailed debugging information"
    log INFO "General operational messages"
    log WARN "Warning conditions"
    log ERROR "Error conditions requiring attention"

    Colors: DEBUG=cyan, INFO=green, WARN=yellow, ERROR=red
    Logging is disabled by default - no performance impact when unused.
}

package require yaml
package require json

proc log {level msg} {
    #
    # ARGS
    # level     in      Log level (DEBUG, INFO, WARN, ERROR).
    # msg       in      Message to log.
    #
    # DESC
    # Conditional logging with timestamp and color coding based on environment
    # variables. Checks for GROUP_LOG_LEVEL_<LEVEL> environment variable.
    #
    global env
    set env_var "GROUP_LOG_LEVEL_[string toupper $level]"
    if {[info exists env($env_var)] && $env($env_var)} {
        switch [string toupper $level] {
            DEBUG {set color "\033\[36m"} ;# {Cyan}
            INFO {set color "\033\[32m"} ;# {Green}
            WARN {set color "\033\[33m"} ;# {Yellow}
            ERROR {set color "\033\[31m"} ;# {Red}
            default {set color ""}
        }
        set reset "\033\[0m"
        set timestamp [clock format [clock seconds] -format "%b %d %H:%M:%S"]
        puts "${color}\[${timestamp}\] \[${level}\] ${msg}${reset}"
    }
}


namespace eval group {
    variable _fileType "yml"
    variable _manPage $::GROUP_MODULE_INFO
    variable _leaf_placeholder "__"


    # --- Load Optional C Extension ---
    # This block attempts to load the compiled C extension for high-performance
    # JSON parsing. It dynamically determines the correct library extension
    # for the current operating system (e.g., .so, .dylib).
    #
    # The 'catch' ensures that if the library is not found or fails to load,
    # a warning is logged, but the module continues to load gracefully,
    # falling back to the pure-Tcl implementations.
    if {
        [catch {
            global tcl_platform
            set lib_filename "group_parser$tcl_platform(dl_ext)"
            set lib_path [file join [file dirname [info script]] ../clib $lib_filename]
            load $lib_path
            log INFO "Successfully loaded C parser extension ($lib_filename)."
        } err]
    } {
        log WARN "Could not load optional C parser extension. Module will use Tcl-only implementations. Error: $err"
    }

    namespace export \
        create copy createFromLists \
        fromYaml toYaml fromJson toJson fromLegacy toLegacy \
        getSubgroup orderValues associate dump \
        setFileType getFileType man \
        setLeafPlaceholder getLeafPlaceholder

    namespace ensemble create

    # ===================================================================
    # == PUBLIC API IMPLEMENTATION
    # ===================================================================

    proc setLeafPlaceholder {placeholder} {
        #
        # DESC: Sets the string used to replace spaces in leaf values.
        #
        variable _leaf_placeholder
        set _leaf_placeholder $placeholder
    }

    proc getLeafPlaceholder {} {
        #
        # DESC: Returns the current placeholder string.
        #
        variable _leaf_placeholder
        return $_leaf_placeholder
    }

    proc create {group_name args} {
        #
        # ARGS
        # group_name  in/out  The name of the group object to create.
        # args        in      A list of key-value pairs, either as multiple
        #                     arguments or a single list/block.
        #
        # DESC
        # The primary, unified constructor for creating groups. It intelligently
        # handles both multi-argument and single-block styles, and processes
        # composition sigils ('@', '*') to build complex groups.
        #
        # RETURN
        # Returns 1 on success. Throws an error on failure.
        #
        upvar #0 $group_name obj

        # Determine if args is a single block or multiple arguments
        set kv_list $args
        if {[llength $args] == 1} {
            set raw_data [lindex $args 0]
            set valid_lines [regexp -all -inline -line -- {^\s*[^\s#].*} $raw_data]
            set kv_list [join $valid_lines]
        }

        # Create a temporary array in our scope to be populated by associate
        array set temp_array {}
        associate temp_array $kv_list

        # Copy the populated temp array to the final global destination
        array set obj [array get temp_array]

        _create_dispatcher $group_name
        return 1
    }

    proc createFromLists {group_name struct_arg data_arg} {
        #
        # ARGS
        # group_name    in/out      The name of the group variable to create.
        # struct_arg    in          A list of keys for the group (or '&' name of a list var).
        # data_arg      in          A parallel list of values (or '&' name of a list var).
        #
        # DESC
        # Specialized constructor for creating groups from parallel lists of keys and values.
        #
        # RETURN
        # Returns 1 on success. Throws an error on failure.
        #
        upvar 1 $group_name group_arr
        set keys [_deref_arg $struct_arg]
        set values [_deref_arg $data_arg]

        if {[llength $keys] != [llength $values]} {
            return -code error "key list and data list have different lengths"
        }

        set kv_list {}
        foreach key $keys value $values {
            lappend kv_list $key $value
        }

        associate group_arr $kv_list
        _create_dispatcher $group_name
        return 1
    }

    proc copy {new_group_name source_group_name} {
        #
        # ARGS
        # new_group_name    in/out  The name of the new group to create.
        # source_group_name in      The name of the existing group to copy.
        #
        # DESC
        # Simulates prototypical inheritance by creating a new group as a copy
        # of an existing one.
        #
        # RETURN
        # Returns 1 on success. Throws an error if the source group does not exist.
        #

        # First, check if the global variable exists. Note the "::" prefix.
        if {![info exists ::$source_group_name]} {
            return -code error "source group '$source_group_name' does not exist"
        }
        # Now that we know it exists, it's safe to link to it.
        upvar #0 $source_group_name source_obj
        upvar 1 $new_group_name new_obj
        array set new_obj [array get source_obj]
        set new_obj(parent) $source_group_name
        _create_dispatcher $new_group_name
        return 1
    }

    proc fromYaml {group_name destination} {
        #
        # ARGS
        # group_name    in/out  The name of the group object to create.
        # destination   in      YAML data as a string, or '%filepath' to read from a file.
        #
        # DESC
        # Creates a group object by loading its data from a YAML source.
        # It uses a robust multi-step process to avoid Tcl's type ambiguity:
        # 1. Pre-processes the raw YAML text to protect leaf values with spaces.
        # 2. Parses the now-"sanitized" and unambiguous text into a dictionary.
        # 3. Flattens the dictionary into the key-value list for the group.
        # 4. Creates the group array.
        # 5. Restores the original spaces in the group's values.
        #
        # RETURN
        # Returns 1 on success. Throws an error on failure.
        #
        upvar 1 $group_name obj
        variable _leaf_placeholder

        # Read the entire file into memory as a single string.
        set yaml_text ""
        if {[string match "%*" $destination]} {
            set filename [string range $destination 1 end]
            if {[catch {open $filename r} f]} {
                return -code error "could not open file '$filename': $f"
            }
            set yaml_text [read $f]
            close $f
        } else {
            set yaml_text $destination
        }

        # Step 1 & 2: Pre-process the raw text to protect leaf values.
        set sanitized_lines {}
        foreach line [split $yaml_text \n] {
            # Use a regex to find simple "key: value" lines.
            # Captures group 1: indentation, key, and separator.
            # Captures group 2: the value part of the line.
            if {[regexp {^(\s*\S+:\s+)(.*)$} $line -> prefix value_part]} {
                # This is a potential leaf. Protect its value.
                set protected_value [string map [list " " $_leaf_placeholder] $value_part]
                lappend sanitized_lines "$prefix$protected_value"
            } else {
                # This line isn't a simple key:value, so leave it untouched.
                lappend sanitized_lines $line
            }
        }
        set sanitized_yaml [join $sanitized_lines \n]

        # Step 3: Parse the now-sanitized YAML text.
        if {[catch {set nested_dict [::yaml::yaml2dict $sanitized_yaml]} err]} {
            return -code error "Failed to parse sanitized YAML data: $err"
        }

        if {[string length [string trim $sanitized_yaml]] > 0 && [dict size $nested_dict] == 0} {
            return -code error "Failed to parse YAML data: Invalid or empty format"
        }

        # Step 4: Flatten the now-safe nested dictionary.
        set flat_dict [_dict_flatten $nested_dict]

        # Step 5: Load the flat dictionary into the final group array.
        array set obj $flat_dict

        # Step 6: Restore the original values by removing the placeholders.
        _restore_leaves $group_name
        _create_dispatcher $group_name

        return 1
    }

    proc toYaml {group_name sink} {
        # Wrapper that calls the main markup engine for YAML format.
        return [_toMarkup $group_name $sink "yml"]
    }

    proc toJson {group_name sink {indent_width 0}} {
        #
        # ARGS
        # group_name    in      The name of the group object to save.
        # sink          in      Variable name to hold output, or '%filepath'.
        # indent_width  in (opt) The number of spaces to use for indentation.
        #                       Defaults to 0, which produces minified JSON.
        #
        # DESC
        # Wrapper that calls the main markup engine for JSON format.
        #
        return [_toMarkup $group_name $sink "json" $indent_width]
    }

    proc fromJson {group_name destination} {
        #
        # ARGS
        # group_name    in/out  The name of the group object to create.
        # destination   in      JSON data as a string, or '%filepath' to read from a file.
        #
        # DESC
        # Creates a group object by loading its data from a JSON source.
        # This procedure uses a robust raw-text pre-processing strategy to
        # avoid Tcl's type ambiguity issues. It sanitizes the JSON text
        # before parsing to protect string values that contain spaces.
        #
        # RETURN
        # Returns 1 on success. Throws an error on failure.
        #
        upvar 1 $group_name obj
        variable _leaf_placeholder

        # Phase 1: Read and Normalize the Raw Text
        set raw_json_text ""
        if {[string match "%*" $destination]} {
            set filename [string range $destination 1 end]
            if {[catch {open $filename r} f]} {
                return -code error "could not open file '$filename': $f"
            }
            set raw_json_text [read $f]
            close $f
        } else {
            set raw_json_text $destination
        }
        set normalized_text [string map [list "{" "{\n" "}" "\n}" "," ",\n"] $raw_json_text]


        # Phase 2: Protect the Leaf Values
        set sanitized_lines {}
        foreach line [split $normalized_text \n] {
            # This regex identifies string-based leaf nodes and captures three parts:
            # 1. prefix: Everything from the start of the line up to the value's opening quote.
            # 2. value_part: The actual string content between the quotes.
            # 3. suffix: The closing quote and the rest of the line.
            if {[regexp {^(\s*".*?":\s*")(.*)(".*)$} $line -> prefix value_part suffix]} {
                # This is a string leaf node. Protect its value.
                set protected_value [string map [list " " $_leaf_placeholder] $value_part]
                lappend sanitized_lines "$prefix$protected_value$suffix"
            } else {
                # This is a structural line ({, }), a non-string value, or empty. Leave it alone.
                lappend sanitized_lines $line
            }
        }
        set sanitized_json [join $sanitized_lines \n]


        # Phase 3: Parse and Load the Sanitized Data
        if {[catch {set nested_dict [::json::json2dict $sanitized_json]} err]} {
            return -code error "Failed to parse sanitized JSON data: $err"
        }
        set flat_dict [_dict_flatten $nested_dict]
        array set obj $flat_dict


        # Phase 4: Restore and Activate
        _restore_leaves $group_name
        _create_dispatcher $group_name

        return 1
    }

    proc fromLegacy {group_name destination} {
        #
        # ARGS
        # group_name    in/out  The name of the group object to create.
        # destination   in      Legacy .object data as a string, or '%filepath'.
        #
        # DESC
        # Creates a group object by loading data from the legacy .object format.
        #
        # RETURN
        # Returns 1 on success. Throws an error if the data is malformed.
        #
        upvar 1 $group_name obj
        global delim
        if {![info exists delim]} {set delim ">"}
        set legacy_data ""
        if {[string match "%*" $destination]} {
            set filename [string range $destination 1 end]
            if {[catch {open $filename r} f]} {
                return -code error "could not open file '$filename': $f"
            }
            set legacy_data [read $f]
            close $f
        } else {
            set legacy_data $destination
        }
        foreach line [split $legacy_data \n] {
            set record [join $line " "]
            if {[string length $record]} {
                set parts [split $record $delim]
                if {[llength $parts] < 2} {
                    return -code error "invalid legacy format: line missing delimiter"
                }
                set array_index [string trim [lindex $parts 0]]
                set array_value [lindex $parts 1]
                set obj($array_index) [string trimleft $array_value]
            }
        }
        return 1
    }

    proc toLegacy {group_name sink} {
        #
        # ARGS
        # group_name    in      The name of the group object to save.
        # sink          in      Variable name to hold output, or '%filepath'.
        #
        # DESC
        # Saves a group object's data to a legacy .object sink.
        #
        # RETURN
        # Returns 1 on success. Throws an error if the group does not exist.
        #
        if {[catch {upvar #0 $group_name obj} err]} {
            return -code error "group '$group_name' does not exist"
        }
        if {[string match "%*" $sink]} {
            set filename [string range $sink 1 end]
            dump $group_name $filename
        } else {
            upvar 1 $sink out_var
            set out_var [dump $group_name]
        }
        return 1
    }

    proc getSubgroup {group_out_var group_in_name field} {
        #
        # ARGS
        # group_out_var   out     Variable to hold the returned subgroup.
        # group_in_name   in      Name of the parent group to search.
        # field           in      The field name to extract (e.g., "rules").
        #
        # DESC
        # Extracts a subgroup from a parent group.
        #
        # RETURN
        # Returns 1 on success. Throws an error if the parent group does not exist.
        #
        if {[catch {upvar #0 $group_in_name parent_group} err]} {
            return -code error "source group '$group_in_name' does not exist"
        }
        upvar 1 $group_out_var subgroup
        set combined_list {}
        foreach {key data} [array get parent_group] {
            if {![string first $field $key]} {
                lappend combined_list [list $key $data]
            }
        }
        set sorted_list [lsort -decreasing -index 0 $combined_list]
        set lst_key {}
        set lst_data {}
        foreach pair $sorted_list {
            lassign $pair key data
            lappend lst_key $key
            lappend lst_data $data
        }
        createFromLists subgroup $lst_key $lst_data
        return 1
    }

    proc orderValues {group_name order_list} {
        #
        # ARGS
        # group_name    in      The name of the group to process.
        # order_list    in      An ordered list of key suffixes.
        #
        # DESC
        # Returns a list of values from the group, ordered according to the
        # provided list of key suffixes.
        #
        # RETURN
        # A list of values ordered according to the provided key suffixes.
        # Throws an error if the group does not exist.
        #
        if {[catch {upvar #0 $group_name group_arr} err]} {
            return -code error "group '$group_name' does not exist"
        }
        set ordered_values {}
        foreach element $order_list {
            foreach {key value} [array get group_arr] {
                if {[string match "*$element*" $key]} {
                    lappend ordered_values $value
                    break
                }
            }
        }
        return $ordered_values
    }

    proc associate {group_name kv_list} {
        #
        # ARGS
        # group_name    in/out  Name of the group array to be populated.
        # kv_list       in      A single, flat list of key-value pairs.
        #
        # DESC
        # (Internal) The core recursive array builder. It processes a key-value
        # list, handling '@' and '*' sigils for composition.
        #
        # RETURN
        # Returns 1 on success. Throws an error on failure.
        #
        upvar 1 $group_name arr

        if {[llength $kv_list] % 2 != 0} {
            return -code error "associate requires an even number of key-value pairs"
        }

        foreach {key value} $kv_list {
            if {[string match "@*" $value]} {
                set var_name [string range $value 1 end]
                if {![info exists ::$var_name]} {
                    return -code error "composition target '@$var_name' does not exist"
                }
                upvar "#0" $var_name arrn
                set nested_kv_list {}
                foreach {k v} [array get arrn] {
                    lappend nested_kv_list "$key,$k" $v
                }
                associate arr $nested_kv_list
            } elseif {[string index $value 0] eq "*"} {
                set var_name [string range $value 1 end]
                if {![info exists ::$var_name]} {
                    return -code error "dereference target '*$var_name' does not exist"
                }
                upvar "#0" $var_name deref_value
                set arr($key) "$deref_value"
            } else {
                set arr($key) $value
            }
        }
        return 1
    }

    proc dump {group_name {sink void}} {
        #
        # ARGS
        # group_name    in          Name of the group to dump.
        # sink          in (opt)    Optional filename. If "void", returns string.
        #
        # DESC
        # Dumps a group to a file in the legacy .object format or returns string.
        #
        # RETURN
        # If sink is a filename, returns 1 on success.
        # If sink is "void", returns the formatted group data as a string.
        # Throws an error if the group does not exist or the file cannot be opened.
        #
        if {[catch {upvar #0 $group_name arr} err]} {
            return -code error "group '$group_name' does not exist"
        }
        global delim
        if {![info exists delim]} {set delim ">"}
        set output_buffer ""
        set fileID ""
        if {$sink ne "void"} {
            if {[catch {open $sink w} fileID]} {
                return -code error "could not open file '$sink' for writing: $fileID"
            }
        }
        set arrlst {}
        foreach {index value} [array get arr] {
            lappend arrlst [list $index $value]
        }
        set sorted [lsort -index 0 $arrlst]
        set prevSet ""
        foreach item $sorted {
            lassign $item index value
            set currSet [lindex [split $index ,] 0]
            set line [format "%-25s %s" "$index$delim" "$value"]
            if {$currSet ne $prevSet && $prevSet ne ""} {
                if {$fileID ne ""} {puts $fileID ""} else {append output_buffer "\n"}
            }
            if {$fileID ne ""} {puts $fileID $line} else {append output_buffer "$line\n"}
            set prevSet $currSet
        }
        if {$fileID ne ""} {
            close $fileID
            return 1
        } else {
            return $output_buffer
        }
    }

    proc setFileType {type} {
        #
        # ARGS
        # type  in      The new default file type (e.g., "yml", "json").
        #
        # DESC
        # Sets the default file type for I/O operations.
        #
        variable _fileType
        set _fileType $type
    }

    proc getFileType {} {
        #
        # DESC
        # Returns the current default file type.
        #
        # RETURN
        # file_type     Current default file type string.
        #
        variable _fileType
        return $_fileType
    }

    proc man {} {
        #
        # DESC
        # Returns the module's documentation as a string.
        #
        # RETURN
        # man_page_string   A string containing the complete manual page.
        #
        variable _manPage
        return $_manPage
    }

    # ===================================================================
    # == INTERNAL IMPLEMENTATION
    # ===================================================================

    proc _create_dispatcher {group_name} {
        #
        # ARGS
        # group_name    in      The name of the group for which to create a dispatcher.
        #
        # DESC
        # (Internal) Creates a Tcl procedure in the global namespace that acts as
        # a method dispatcher for the group. This implements prototypical
        # inheritance by walking the `parent` chain to find and execute methods,
        # ensuring the method is always run in the context of the original object.
        #
        proc ::$group_name {method_name args} {
            set original_obj_name [lindex [info level 0] 0]
            set current_obj_name $original_obj_name
            set depth 0
            while {$depth < 100} {
                global $current_obj_name
                if {[info exists ${current_obj_name}($method_name)]} {
                    set proc_to_call [set ${current_obj_name}($method_name)]
                    # Use uplevel #0 to ensure method runs in the global scope,
                    # which allows the method's own "upvar #0" to work reliably.
                    return [uplevel #0 [list $proc_to_call $original_obj_name {*}$args]]
                } elseif {[info exists ${current_obj_name}(parent)]} {
                    set current_obj_name [set ${current_obj_name}(parent)]
                    incr depth
                    continue
                } else {
                    break
                }
            }
            return -code error "Group '$original_obj_name' has no method '$method_name' and no parent"
        }
    }

    proc _deref_arg {arg} {
        #
        # ARGS
        # arg           in      Argument that may contain '&' sigil for pass-by-name.
        #
        # DESC
        # (Internal) Resolves pass-by-name arguments. If arg starts with '&', treats
        # the remainder as a variable name and returns its value from the
        # caller's caller scope (2 levels up).
        #
        # RETURN
        # The dereferenced variable value or the original arg.
        #
        if {[string match "&*" $arg]} {
            set var_name [string range $arg 1 end]
            upvar 2 $var_name list_val
            return $list_val
        } else {
            return $arg
        }
    }

    proc isDict {value} {
        #
        # ARGS
        # value         in      The value to test for dictionary validity.
        #
        # DESC
        # (Internal) Tests whether a given value is a well-formed Tcl dictionary.
        #
        # RETURN
        # Boolean value: 1 if value is a valid dictionary, 0 otherwise.
        #
        return [expr {![catch {dict size $value}]}]
    }

    proc _dict_flatten {nested_dict {prefix ""}} {
        #
        # ARGS
        # nested_dict   in          A nested Tcl dictionary.
        # prefix        in (opt)    An internal string for recursive key generation.
        #
        # DESC
        # (Internal) Recursively flattens a nested dictionary into a flat
        # dictionary with comma-delimited keys. This simple version relies on
        # its input dictionary having been pre-processed to remove ambiguity
        # between leaf values and nested structures.
        #
        # RETURN
        # A flat dictionary with comma-delimited keys.
        #
        set flat_dict [dict create]
        dict for {key value} $nested_dict {
            set new_key ""
            if {$prefix eq ""} {
                set new_key $key
            } else {
                set new_key "$prefix,$key"
            }
            if {[isDict $value]} {
                # The value is a dictionary structure, so we recurse.
                dict for {k v} [_dict_flatten $value $new_key] {
                    dict set flat_dict $k $v
                }
            } else {
                # The value is a scalar (a simple string), so we record it.
                dict set flat_dict $new_key $value
            }
        }
        return $flat_dict
    }

    proc _values_whiteSpaceReplace {flat_dict} {
        #
        # ARGS
        # flat_dict        in      A flat dictionary to process
        # replacementstr   in      String to replace spaces with (default: "__")
        #
        # DESC
        # (Internal) Replaces spaces in all values of a flat dictionary
        # with the specified replacement string.
        #
        # RETURN
        # A new dictionary with spaces in values replaced.
        #
        variable _leaf_placeholder
        set result [dict create]

        dict for {key value} $flat_dict {
            set modified_value [string map [list " " $_leaf_placeholder] $value]
            dict set result $key $modified_value
        }

        return $result
    }

    proc _dict_populate {flat_dict nested_dict} {
        #
        # ARGS
        # flat_dict    in      Original flat dictionary with spaces in values
        # nested_dict  in      Correctly nested dict with __ in values
        #
        # DESC
        # (Internal) Populates a nested dictionary structure with correct values
        # from the original flat dictionary.
        #
        # RETURN
        # The nested dictionary with correct values restored.
        #
        set result $nested_dict

        log "DEBUG" "_dict_populate 1st = $flat_dict"
        log "DEBUG" "_dict_populate 2nd = $nested_dict"

        dict for {key value} $flat_dict {
            set key_parts [split $key ","]
            set command [list dict set result {*}$key_parts $value]
            set result [eval $command]
        }
        return $result
    }

    proc _dict_unflatten {flat_dict} {
        #
        # DESC
        # (Internal) Converts a flat dictionary into a nested dictionary,
        # leaving space-placeholders in the leaf values to resolve ambiguity.
        #
        if {[catch {dict size $flat_dict} size]} {
            return -code error "_dict_unflatten: invalid input dictionary: $size"
        }

        # Step 1: Create a version of the dictionary with spaces in values
        # replaced by placeholders.
        set safe_dict [_values_whiteSpaceReplace $flat_dict]

        # Step 2: Build the nested structure. The leaf values will now be
        # single "words" (e.g., "Coastal__Cliffs"), which is what we want.
        set nested_dict [dict create]
        dict for {key value} $safe_dict {
            if {$key eq ""} {continue}
            set key_parts [split $key ","]
            set nested_dict [dict set nested_dict {*}$key_parts $value]
        }

        return $nested_dict
    }

    # proc _dict_unflatten {flat_dict} {
    #     #
    #     # ARGS
    #     # flat_dict     in          A flat dictionary with comma-delimited keys.
    #     #
    #     # DESC
    #     # (Internal) Converts a flat dictionary with comma-delimited keys
    #     # into a nested dictionary structure. Uses two-step process:
    #     # 1. Build structure with space-replaced values
    #     # 2. Populate with actual values
    #     #
    #     # RETURN
    #     # The reconstructed nested dictionary structure.
    #     # Throws error if dictionary operations fail.
    #     #
    #     if {[catch {dict size $flat_dict} size]} {
    #         return -code error "_dict_unflatten: invalid input dictionary: $size"
    #     }
    #     set result [dict create]
    #     dict for {key value} $flat_dict {
    #         set key_parts [split $key ","]
    #         set command [list dict set result {*}$key_parts $value]
    #         set result [eval $command]
    #     }
    #     puts "final_dict = $result"
    #     return $result
    # }

    proc _dict_to_json {dict} {
        #
        # ARGS
        # dict      in      The Tcl dictionary to be converted.
        #
        # DESC
        # (Internal) Recursively converts a Tcl dictionary into a valid JSON string.
        #
        # RETURN
        # A string containing the valid JSON representation.
        #
        set members {}
        dict for {key value} $dict {
            set json_key "\"$key\""
            set json_value ""
            if {[string is boolean -strict $value]} {
                set json_value [expr {$value ? "true" : "false"}]
            } elseif {[string is double -strict $value]} {
                set json_value $value
            } elseif {[isDict $value]} {
                set json_value [_dict_to_json $value]
            } else {
                set escaped [string map {\\ \\\\ \" \\\"} $value]
                set json_value "\"$escaped\""
            }
            lappend members "$json_key:$json_value"
        }
        return "\{[join $members ","]\}"
    }

    proc _dict_to_yaml {dict {indent 0}} {
        #
        # ARGS
        # dict      in      The Tcl dictionary to convert to YAML
        # indent    in      Current indentation level (internal use)
        #
        # DESC
        # (Internal) Converts a Tcl dictionary to YAML format, properly handling
        # nested dictionaries to preserve structure.
        #
        # RETURN
        # A string containing valid YAML representation
        #
        set yaml ""
        set spacing [string repeat "  " $indent]

        dict for {key value} $dict {
            # Check if value is a dictionary
            if {[isDict $value] && [dict size $value] > 0} {
                # Nested dictionary - use YAML nested structure
                append yaml "${spacing}${key}:\n"
                append yaml [_dict_to_yaml $value [expr {$indent + 1}]]
            } else {
                # Scalar value - handle special cases
                if {
                    [string match "*\n*" $value] || [string match "* *" $value] ||
                    [string match "*:*" $value] || [string match "*#*" $value]
                } {
                    # Quote values with special characters
                    set escaped [string map {\" \\\" \\ \\\\} $value]
                    append yaml "${spacing}${key}: \"${escaped}\"\n"
                } elseif {$value eq ""} {
                    # Empty value
                    append yaml "${spacing}${key}: \"\"\n"
                } else {
                    # Simple scalar
                    append yaml "${spacing}${key}: ${value}\n"
                }
            }
        }
        return $yaml
    }

    proc _dict_to_yaml {dict {indent 0}} {
        #
        # ARGS
        # dict      in      The Tcl dictionary to convert to YAML
        # indent    in      Current indentation level (internal use)
        #
        # DESC
        # (Internal) Converts a Tcl dictionary to YAML format, properly handling
        # nested dictionaries to preserve structure.
        #
        # RETURN
        # A string containing valid YAML representation
        #
        set yaml ""
        set spacing [string repeat "  " $indent]

        dict for {key value} $dict {
            # This is the critical fix: Use the robust 'isDict' helper to
            # correctly distinguish between nested dictionaries and simple strings.
            if {[isDict $value] && [dict size $value] > 0} {
                # It's a real nested dictionary
                append yaml "${spacing}${key}:\n"
                append yaml [_dict_to_yaml $value [expr {$indent + 1}]]
            } else {
                # It's a scalar value (a simple string)
                if {
                    [string match "*\n*" $value] || [string match "* *" $value] ||
                    [string match "*:*" $value] || [string match "*#*" $value]
                } {
                    # Quote values with spaces or special characters
                    set escaped [string map {\" \\\" \\ \\\\} $value]
                    append yaml "${spacing}${key}: \"${escaped}\"\n"
                } elseif {$value eq ""} {
                    # Handle empty values
                    append yaml "${spacing}${key}: \"\"\n"
                } else {
                    # Handle simple, safe scalars
                    append yaml "${spacing}${key}: ${value}\n"
                }
            }
        }
        return $yaml
    }

    proc _restore_leaves {group_name} {
        #
        # ARGS
        # group_name    in/out  The name of the final group array to process.
        #
        # DESC
        # (Internal) Iterates over a created group array and restores the
        # original spaces in values by replacing the configured placeholder. This
        # is the final step in the robust YAML loading process.
        #
        variable _leaf_placeholder
        upvar #0 $group_name group_arr

        # Using 'array get' and 'array set' is a safe way to iterate and modify.
        set temp_list [array get group_arr]
        set restored_list {}
        foreach {key value} $temp_list {
            set restored_value [string map [list $_leaf_placeholder " "] $value]
            lappend restored_list $key $restored_value
        }
        array set group_arr $restored_list
    }

    proc _toMarkup {group_name sink format {indent_width 0}} {
        #
        # ARGS
        # group_name    in      The group to serialize.
        # sink          in      The output file or variable.
        # format        in      The output format ("yml" or "json").
        # indent_width  in (opt) The width for JSON indentation.
        #
        # DESC
        # Main serialization engine that converts a group to either
        # JSON or YAML format and writes it to a sink.
        #
        if {[catch {upvar #0 $group_name obj} err]} {
            return -code error "group '$group_name' does not exist"
        }
        set flat_dict [array get obj]
        set nested_dict [_dict_unflatten $flat_dict]

        # Call the recursive helper to build the final string.
        set markup_data [_dict_to_markup_recursive $nested_dict $format 0 $indent_width]

        # Write to sink (file or variable).
        if {[string match "%*" $sink]} {
            set filename [string range $sink 1 end]
            if {[catch {open $filename w} f]} {
                return -code error "could not open file '$filename' for writing: $f"
            }
            if {$format eq "yml"} {puts -nonewline $f "---\n"}
            puts -nonewline $f $markup_data
            close $f
        } else {
            upvar 1 $sink out_var
            if {$format eq "yml"} {set markup_data "---\n$markup_data"}
            set out_var $markup_data
        }
        return 1
    }

    proc _dict_to_markup_recursive {dict format indent_level indent_width} {
        #
        # ARGS
        # dict          in      The dictionary to process.
        # format        in      The target format ("yml" or "json").
        # indent_level  in      The current recursion depth for indentation.
        # indent_width  in      The number of spaces per indent level for JSON.
        #
        # DESC
        # The recursive worker that builds either a JSON or YAML
        # string from a nested dictionary.
        #
        variable _leaf_placeholder
        set output ""
        set members {}

        dict for {key value} $dict {
            if {[isDict $value]} {
                # It's a nested dictionary, so we recurse.
                set nested_markup [_dict_to_markup_recursive $value $format [expr {$indent_level + 1}] $indent_width]
                if {$format eq "json"} {
                    lappend members "\"$key\":$nested_markup"
                } else {
                    set spacing [string repeat " " [expr {$indent_level * 2}]]
                    append output "${spacing}${key}:\n$nested_markup"
                }
            } else {
                # It's a scalar. Restore the spaces from the placeholder.
                set final_value [string map [list $_leaf_placeholder " "] $value]

                if {$format eq "json"} {
                    set escaped [string map {\\ \\\\ \" \\\"} $final_value]
                    lappend members "\"$key\":\"$escaped\""
                } else {
                    set spacing [string repeat " " [expr {$indent_level * 2}]]
                    if {$final_value eq "" || [string first ": " $final_value] != -1} {
                        set escaped [string map {\\ \\\\ \" \\\"} $final_value]
                        append output "${spacing}${key}: \"$escaped\"\n"
                    } else {
                        append output "${spacing}${key}: $final_value\n"
                    }
                }
            }
        }

        if {$format eq "json"} {
            if {$indent_width > 0} {
                # Pretty-print the JSON output.
                set spacing [string repeat " " [expr {$indent_level * $indent_width}]]
                set child_spacing [string repeat " " [expr {($indent_level + 1) * $indent_width}]]
                if {[llength $members] == 0} {return "{}"}
                return "{\n$child_spacing[join $members ",\n$child_spacing"]\n${spacing}}"
            } else {
                # Return minified JSON.
                return "\{[join $members ","]\}"
            }
        } else {
            return $output
        }
    }
}
