# Composition Guide

The most powerful data-structuring feature of the `group` library is its ability to build complex objects by composing them from smaller, reusable components. This allows you to define common data structures once and reuse them to build larger, more complex groups.

This is the recommended pattern for structuring configuration data.

## The Composition Mechanism

Composition is handled by the `group createFromLists` command. It works by "flattening" component data into a parent group. The component to be flattened can be a **standard Tcl array** (created with `array set`) or another **`group` object**.

The system relies on special syntactic markers, or **sigils**, to control its behavior:

* **`&varname` (Pass-by-Name)**: When an argument to `group createFromLists` starts with `&`, the procedure treats it as the *name* of a variable that contains a list, rather than as the list itself.

* **`@varname` (Composition Trigger)**: When a *value* in the data list starts with `@`, it signals that this is a component that should be **flattened** into the parent group.

* **`*varname` (Dereference Trigger)**: When a *value* in the data list starts with `*`, it signals that the value of the named variable should be used.

### What happens to methods?

Composition is for **data only**. When a component `group` is flattened into a parent, only its key-value data is copied. The parent group does **not** inherit the methods of the component, and its dispatcher command has no knowledge of the component's dispatcher.

## Example: Building a Composite Group

This example shows how to build a main `server_backup` group that is composed of two smaller components: one standard Tcl array and one `group` object.

```tcl
# Load the library
package require group

# --- Step 1: Create the Component Objects ---

# Component 1: A schedule, created as a standard Tcl array
array set schedule_component {
    Mon "daily"
    Sun "monthly"
}

# Component 2: Notification settings, created as a group object
group create notify_component {
    tapeCmd  "echo 'Tape notification'"
    errorCmd "echo 'Error notification'"
}

# A global variable for dereferencing
set admin_user "rudolph"


# --- Step 2: Define the Structure for the Main Group ---
# We create variables to hold our lists.
set keys {name schedule notifications admin}
set values {
    "server-backup"
    @schedule_component
    @notify_component
    *admin_user
}


# --- Step 3: Create the Composite Group ---
# We pass the variable names with the '&' sigil for pass-by-name.
group createFromLists server_backup &keys &values


# --- Step 4: Examine the Result ---
# The data from both components has been flattened into the main group.
parray server_backup
# -> Outputs:
# server_backup(admin)                  = rudolph
# server_backup(name)                   = server-backup
# server_backup(notifications,errorCmd) = Error notification
# server_backup(notifications,tapeCmd)  = Tape notification
# server_backup(schedule,Mon)           = daily
# server_backup(schedule,Sun)           = monthly
