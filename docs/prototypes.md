# Prototypical Inheritance Guide

The `group` system provides a lightweight, prototype-based OOP model for sharing **behavior (methods)**. This allows you to create new objects by cloning a "prototype" and inheriting its methods through a live, dynamic link.

## The Inheritance Mechanism

This system is built on three core concepts:

1.  **Method Dispatcher**: When you create a `group`, a new Tcl command with the same name is automatically created. This command acts as a "method dispatcher." When you call `my_group some_method`, this dispatcher is what looks up and executes the correct procedure.

2.  **Inheritance via Cloning**: The `group copy` command creates a new `group` by making a copy of an existing one (the "prototype"). Crucially, it adds a `parent` key to the new group that stores the name of the prototype, creating an explicit link.

3.  **Live Prototype Chain**: The method dispatcher is "smart." When you call a method on a group, the dispatcher first checks if the method exists in the group's own data array. If it is not found, it checks for a `parent` key. If a parent exists, the dispatcher **delegates the call** to the parent's dispatcher. This process repeats all the way up the prototype chain until the method is found or a root object (one with no parent) is reached.

Because this link is "live," any methods added to a parent object *after* a child is created are immediately available to the child through this delegation chain.

## Example: Cloning and Method Delegation

```tcl
# Load the library
package require group

# --- Step 1: Define "methods" and create a prototype group ---
proc print_name {group_name} {
    upvar 1 $group_name group
    puts "My name is: $group(name)"
}

proc get_parent_name {group_name} {
    upvar 1 $group_name group
    if {[info exists group(parent)]} {
        return $group(parent)
    }
    return "No Parent"
}

# Create the prototype object
group create base_object {
    name            "Base Object"
    print_name      "print_name"
}


# --- Step 2: Create a child object by cloning the prototype ---
group copy child_object base_object

# Override a data field in the child. This does not affect the parent.
set child_object(name) "Child Object"


# --- Step 3: Call an inherited method ---
# The child doesn't have 'print_name' itself, so it delegates the call
# to its parent, 'base_object'. It uses its own local data.
child_object print_name
# -> Outputs: My name is: Child Object


# --- Step 4: Add a new method to the PARENT ---
puts "Adding 'get_parent_name' to the base_object..."
set base_object(get_parent_name) "get_parent_name"


# --- Step 5: Call the NEW method on the CHILD ---
# The child finds the new method on its parent via the live link.
set parent [child_object get_parent_name]
puts "My parent is: $parent"
# -> Outputs: My parent is: base_object
