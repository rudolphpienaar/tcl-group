#!/usr/bin/env tclsh
#
# Comprehensive test suite for group.tcl module
# Run with: tclsh group_test_suite.tcl
#

package require tcltest
namespace import ::tcltest::*

# Source the module under test
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir .. lib group.tcl]

# Configure test environment
configure -verbose {pass skip start error}
testConstraint group_available \
    [expr {![catch {package require yaml}] && ![catch {package require json}]}]

# ===================================================================
# == UTILITY PROCEDURES
# ===================================================================

proc cleanup_test_groups {} {
    # Clean up any test groups that might exist
    foreach proc_name [info procs test_*] {
        catch {rename $proc_name ""}
    }
    # Clean up global test arrays
    foreach var_name [info globals test_*] {
        catch {unset ::$var_name}
    }
}

proc setup_test_components {} {
    # Set up test components for composition tests
    global test_component1 test_component2 test_admin
    array set test_component1 {
        host "localhost"
        port "3306"
        user "admin"
    }
    array set test_component2 {
        type "mysql"
        timeout "30"
        ssl "true"
    }
    set test_admin "root_user"
}

# ===================================================================
# == GROUP CREATION TESTS
# ===================================================================

test group-create-1.1 {Basic group creation} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_group1 name "TestGroup" version "1.0"
    list [array exists test_group1] [set test_group1(name)] [set test_group1(version)]
} -result {1 TestGroup 1.0} -cleanup {
    cleanup_test_groups
}

test group-create-1.2 {Empty group creation} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_empty_group
    array exists test_empty_group
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-create-1.3 {Group with method dispatcher} -constraints group_available -setup {
    cleanup_test_groups
    proc test_method {group_name} {
        upvar 1 $group_name obj
        return "method called on $obj(name)"
    }
} -body {
    group::create test_method_group name "MethodTest" test_cmd "test_method"
    test_method_group test_cmd
} -result {method called on MethodTest} -cleanup {
    cleanup_test_groups
    catch {rename test_method ""}
}

# ===================================================================
# == GROUP COPY TESTS (PROTOTYPICAL INHERITANCE)
# ===================================================================

test group-copy-2.1 {Basic group copying} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_parent name "Parent" type "base"
    group::copy test_child test_parent
    list [set test_child(name)] [set test_child(type)] [set test_child(parent)]
} -result {Parent base test_parent} -cleanup {
    cleanup_test_groups
}

test group-copy-2.2 {Prototypical inheritance with method delegation} \
    -constraints group_available -setup {
    cleanup_test_groups
    proc parent_method {group_name} {
        upvar 1 $group_name obj
        return "parent method: $obj(name)"
    }
} -body {
    group::create test_proto name "Prototype" method "parent_method"
    group::copy test_instance test_proto
    set test_instance(name) "Instance"
    test_instance method
} -result {parent method: Instance} -cleanup {
    cleanup_test_groups
    catch {rename parent_method ""}
}

test group-copy-2.3 {Child method overrides parent} -constraints group_available -setup {
    cleanup_test_groups
    proc parent_method {group_name} { return "parent" }
    proc child_method {group_name} { return "child" }
} -body {
    group::create test_parent method "parent_method"
    group::copy test_child test_parent
    set test_child(method) "child_method"
    test_child method
} -result {child} -cleanup {
    cleanup_test_groups
    catch {rename parent_method ""}
    catch {rename child_method ""}
}

# ===================================================================
# == COMPOSITION TESTS (createFromLists)
# ===================================================================

test group-compose-3.1 {Basic composition with pass-by-name} -constraints group_available -setup {
    cleanup_test_groups
    set test_keys {name version author}
    set test_values {"MyApp" "2.0" "Developer"}
} -body {
    group::createFromLists test_composed &test_keys &test_values
    list [set test_composed(name)] [set test_composed(version)] [set test_composed(author)]
} -result {MyApp 2.0 Developer} -cleanup {
    cleanup_test_groups
}

test group-compose-3.2 {Composition with @ sigil} -constraints group_available -setup {
    cleanup_test_groups
    setup_test_components
    set keys {name database admin}
    set values {"MyApp" @test_component1 *test_admin}
} -body {
    group::createFromLists test_app &keys &values
    list [set test_app(name)] \
        [set test_app(database,host)] [set test_app(database,port)] [set test_app(admin)]
} -result {MyApp localhost 3306 root_user} -cleanup {
    cleanup_test_groups
}

test group-compose-3.3 {Multiple component composition} -constraints group_available -setup {
    cleanup_test_groups
    setup_test_components
    set keys {app db_conn db_config}
    set values {"TestApp" @test_component1 @test_component2}
} -body {
    group::createFromLists test_multi &keys &values
    list [set test_multi(db_conn,host)] \
        [set test_multi(db_config,type)] [set test_multi(db_config,ssl)]
} -result {localhost mysql true} -cleanup {
    cleanup_test_groups
}

test group-compose-3.4 {Dereference with * sigil} -constraints group_available -setup {
    cleanup_test_groups
    set test_value "dynamic_content"
    set keys {static dynamic}
    set values {"fixed_content" *test_value}
} -body {
    group::createFromLists test_deref &keys &values
    list [set test_deref(static)] [set test_deref(dynamic)]
} -result {fixed_content dynamic_content} -cleanup {
    cleanup_test_groups
}

# ===================================================================
# == I/O TESTS (JSON/YAML/Legacy)
# ===================================================================

test group-io-4.1 {YAML round-trip in memory} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_yaml name "YAMLTest" config,host "localhost" config,port "8080"
    group::toYaml test_yaml yaml_output
    group::fromYaml test_restored $yaml_output
    list [set test_restored(name)] [set test_restored(config,host)] [set test_restored(config,port)]
} -result {YAMLTest localhost 8080} -cleanup {
    cleanup_test_groups
}

test group-io-4.2 {JSON round-trip in memory} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_json app "JSONTest" settings,debug "true" settings,level "3"
    group::toJson test_json json_output
    group::fromJson test_restored $json_output
    list [set test_restored(app)] \
        [set test_restored(settings,debug)] [set test_restored(settings,level)]
} -result {JSONTest true 3} -cleanup {
    cleanup_test_groups
}

test group-io-4.3 {Legacy format round-trip} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_legacy name "LegacyTest" type "old_format"
    group::toLegacy test_legacy legacy_output
    group::fromLegacy test_restored $legacy_output
    list [set test_restored(name)] [set test_restored(type)]
} -result {LegacyTest old_format} -cleanup {
    cleanup_test_groups
}

test group-io-4.4 {File I/O with % sigil} -constraints group_available -setup {
    cleanup_test_groups
    set test_file [makeFile {} test_group.yml]
} -body {
    group::create test_file_group name "FileTest" data "test_content"
    group::toYaml test_file_group %$test_file
    group::fromYaml test_loaded %$test_file
    list [set test_loaded(name)] [set test_loaded(data)]
} -result {FileTest test_content} -cleanup {
    cleanup_test_groups
    removeFile test_group.yml
}

# ===================================================================
# == UTILITY FUNCTION TESTS
# ===================================================================

test group-util-5.1 {getSubgroup extraction} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_parent rules,rule1 "allow" rules,rule2 "deny" other "value"
    group::getSubgroup extracted_rules test_parent rules

    # Sort the keys to ensure a predictable order for the test
    list [lsort [array names extracted_rules]] \
        [set extracted_rules(rules,rule1)] [set extracted_rules(rules,rule2)]

} -result {{rules,rule1 rules,rule2} allow deny} -cleanup { ;# Update the expected result
    cleanup_test_groups
}

test group-util-5.2 {orderValues with matching keys} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_ordered step1,action "first" step3,action "third" step2,action "second"
    group::orderValues test_ordered {step1 step2 step3}
} -result {first second third} -cleanup {
    cleanup_test_groups
}

test group-util-5.3 {dump format output} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_dump name "DumpTest" type "test"
    set output [group::dump test_dump]
    # Check that output contains expected format
    expr {[string match "*name>*DumpTest*" $output] && [string match "*type>*test*" $output]}
} -result {1} -cleanup {
    cleanup_test_groups
}

# ===================================================================
# == CONFIGURATION TESTS
# ===================================================================

test group-config-6.1 {File type configuration} -constraints group_available -body {
    group::setFileType "json"
    group::getFileType
} -result {json} -cleanup {
    group::setFileType "yml"
}

test group-config-6.2 {Man page display} -constraints group_available -body {
    # Test that man command doesn't error
    catch {group::man} output
    expr {[string length $output] > 100}
} -result {1}

# ===================================================================
# == ERROR HANDLING TESTS
# ===================================================================

test group-error-7.1 {Method not found error} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_error_group name "ErrorTest"
    catch {test_error_group nonexistent_method} error
    string match "*no method*nonexistent_method*" $error
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-7.2 {Invalid file read with % sigil} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    catch {group::fromYaml test_invalid %/nonexistent/path/file.yml} error
    expr {[string length $error] > 0}
} -result {1} -cleanup {
    cleanup_test_groups
}

# ===================================================================
# == INTERNAL FUNCTION TESTS
# ===================================================================

test group-internal-8.1 {dict_flatten functionality} -constraints group_available -body {
    set nested_dict [dict create level1 [dict create level2 [dict create key "value"]]]
    set flattened [group::_dict_flatten $nested_dict]
    dict get $flattened "level1,level2,key"
} -result {value}

test group-internal-8.2 {dict_unflatten functionality} -constraints group_available -body {
    set flat_dict [dict create "level1,level2,key" "value"]
    set nested [group::_dict_unflatten $flat_dict]
    dict get $nested level1 level2 key
} -result {value}

test group-internal-8.3 {deref_arg with & sigil} -constraints group_available -setup {
    set test_list {a b c}
    # --- HIGHLIGHT START ---
    # This helper proc adds the necessary stack level for "upvar 2" to work.
    proc call_deref {arg} {
        return [group::_deref_arg $arg]
    }
    # --- HIGHLIGHT END ---
} -body {
    # --- HIGHLIGHT START ---
    # Call the helper instead of calling _deref_arg directly.
    call_deref &test_list
    # --- HIGHLIGHT END ---
} -result {a b c} -cleanup {
    # --- HIGHLIGHT START ---
    rename call_deref ""
    # --- HIGHLIGHT END ---
}

test group-internal-8.4 {deref_arg without sigil} -constraints group_available -body {
    group::_deref_arg "direct_value"
} -result {direct_value}

# ===================================================================
# == COMPLEX INTEGRATION TESTS
# ===================================================================

test group-integration-9.1 {Complex composition with inheritance} \
    -constraints group_available \
    -setup {
    cleanup_test_groups
    setup_test_components
    proc base_method {group_name} {
        # --- HIGHLIGHT START ---
        # Use robust upvar #0 to access the global group array
        upvar #0 $group_name obj
        # --- HIGHLIGHT END ---
        return "base: $obj(name)"
    }
} -body {
    # Create base prototype
    group::create base_proto name "BaseProto" method "base_method"

    # Create composed child
    set keys {name database config}
    set values {"ComposedChild" @test_component1 @test_component2}
    group::createFromLists composed_child &keys &values

    # Copy prototype to composed child (manual inheritance)
    array set temp_proto [array get base_proto]
    foreach {key value} [array get temp_proto] {
        # --- HIGHLIGHT START ---
        # Only set the property if it doesn't already exist in the child
        if {![info exists composed_child($key)]} {
            set composed_child($key) $value
        }
        # --- HIGHLIGHT END ---
    }
    # Manually create the dispatcher *after* mixing in the method property
    group::_create_dispatcher composed_child

    # Test inherited method with composed data
    list [composed_child method] \
        [set composed_child(database,host)] [set composed_child(config,type)]
} -result {{base: ComposedChild} localhost mysql} -cleanup {
    cleanup_test_groups
    catch {rename base_method ""}
}

# ===================================================================
# == ERROR HANDLING & INPUT VALIDATION TESTS (ADDED)
# ===================================================================

test group-error-10.1 {fromYaml with corrupt data} -constraints group_available -setup {
    cleanup_test_groups
    # Use a string that is guaranteed to be a YAML syntax error.
    set corrupt_yaml "\{"
} -body {
    catch {group::fromYaml test_corrupt $corrupt_yaml}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.2 {fromJson with corrupt data} -constraints group_available -setup {
    cleanup_test_groups
    # Use a string that is guaranteed to be a JSON syntax error.
    set corrupt_json "\{"
} -body {
    catch {group::fromJson test_corrupt $corrupt_json}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.3 {fromLegacy with corrupt data} -constraints group_available -setup {
    cleanup_test_groups
    set corrupt_legacy "key value"
} -body {
    catch {group::fromLegacy test_corrupt $corrupt_legacy}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.4 {create with odd number of arguments} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    catch {group::create test_bad_args key1 val1 key2}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.5 {createFromLists with mismatched list lengths} \
    -constraints group_available -setup {
    cleanup_test_groups
    set keys {a b}
    set values {1}
} -body {
    catch {group::createFromLists test_mismatch &keys &values}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.6 {copy from non-existent group} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    catch {group::copy test_new non_existent_source}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.7 {toYaml on non-existent group} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    catch {group::toYaml non_existent_source output_var}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.8 {@ sigil with non-existent variable} -constraints group_available -setup {
    cleanup_test_groups
    set keys {a}
    set values {@no_such_var}
} -body {
    catch {group::createFromLists test_bad_sigil &keys &values}
} -result {1} -cleanup {
    cleanup_test_groups
}

test group-error-10.9 {* sigil with non-existent variable} -constraints group_available -setup {
    cleanup_test_groups
    set keys {a}
    set values {*no_such_var}
} -body {
    catch {group::createFromLists test_bad_sigil &keys &values}
} -result {1} -cleanup {
    cleanup_test_groups
}

# ===================================================================
# == EDGE CASE & BEHAVIOR VALIDATION TESTS (ADDED)
# ===================================================================

test group-edgecase-11.1 \
    {Deep copy behavior (child modification does not affect parent)} -constraints group_available \
    -setup {
    cleanup_test_groups
} -body {
    set original_list {a b}
    group::create test_parent data $original_list
    group::copy test_child test_parent
    # Modify the list in the child
    lappend test_child(data) "c"
    # Return the list from the parent (should be unchanged)
    set test_parent(data)
} -result {a b} -cleanup { ;# Corrected: Assert the parent's list is NOT changed
    cleanup_test_groups
}

test group-edgecase-11.2 {Nested composition} -constraints group_available -setup {
    cleanup_test_groups
    array set component_c { deep_key "deep_value" }
    set keys_b { name component }
    set values_b { "ComponentB" @component_c }
    group::createFromLists component_b &keys_b &values_b
    set keys_a { app component }
    set values_a { "AppA" @component_b }
} -body {
    group::createFromLists test_nested &keys_a &values_a
    set test_nested(component,component,deep_key)
} -result {deep_value} -cleanup {
    cleanup_test_groups
}

test group-edgecase-11.3 {getSubgroup with no matching keys} -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_parent key1 "val1" key2 "val2"
    group::getSubgroup extracted test_parent "nonexistent"
    array size extracted
} -result {0} -cleanup {
    cleanup_test_groups
}

test group-edgecase-11.4 {orderValues with non-existent key in order list} \
    -constraints group_available -setup {
    cleanup_test_groups
} -body {
    group::create test_ordered key1 "val1" key3 "val3"
    # "key2" does not exist in the group
    group::orderValues test_ordered {key1 key2 key3}
} -result {val1 val3} -cleanup {
    cleanup_test_groups
}


# ===================================================================
# == RUN TESTS
# ===================================================================

# Clean up before running
cleanup_test_groups

puts "+-------------------------------+"
puts "| All group.tcl tests evaluated |"
puts "+-------------------------------+"

# Run all tests
cleanupTests
