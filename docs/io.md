# I/O Guide: Working with Files and Strings

The `group` library provides a flexible set of procedures for serializing group objects to and from different data formats. All I/O procedures support working with both files on disk and in-memory Tcl strings.

## The I/O Mechanism: The `%` Sigil

The behavior of all `from...` and `to...` procedures is controlled by a special syntactic marker, or **sigil**: the percent sign (`%`).

* **Reading/Writing to a File**: If the `destination` or `sink` argument is prefixed with `%`, the procedure treats the rest of the string as a **file path**.

* **Reading/Writing to a String**: If the `%` prefix is absent, the procedure works with in-memory data:
    * `from...` procedures will treat the `destination` argument as the literal string data to be parsed.
    * `to...` procedures will treat the `sink` argument as the **name of a variable** in the caller's scope that should be populated with the output string.

## Supported Formats

The library supports three formats for serialization:

1.  **YAML**: `fromYaml`, `toYaml` (Recommended)
2.  **JSON**: `fromJson`, `toJson`
3.  **Legacy**: `fromLegacy`, `toLegacy` (For compatibility with the original `.object` file format)

## Examples

### Reading Data (`from...`)

```tcl
# Load the library
package require group

# --- Example 1: Reading from a YAML file ---
# Assume 'config.yaml' exists on disk.
group fromYaml my_group_from_file %config.yaml

# --- Example 2: Reading from a JSON string in memory ---
set json_string {
    "name": "In-Memory Group",
    "version": "1.0"
}
group fromJson my_group_from_string $json_string

parray my_group_from_string
# -> Outputs:
# my_group_from_string(name)    = In-Memory Group
# my_group_from_string(version) = 1.0
```

### Writing Dat (`to...`)

```tcl
# Create a group with flattened keys to save
group create my_group {
    name "Test Group"
    id 123
    schedule,Mon "daily"
    schedule,Sun "monthly"
}

# --- Example 1: Writing to a JSON file ---
# The flattened 'schedule,*' keys will become a nested object.
group toJson my_group %output.json
# -> This creates 'output.json' with the content:
#    {
#       "name": "Test Group",
#       "id": 123,
#       "schedule": {
#          "Mon": "daily",
#          "Sun": "monthly"
#       }
#    }

# --- Example 2: Writing to a Tcl variable ---
group toYaml my_group yaml_output_variable
puts $yaml_output_variable
# -> Outputs the NESTED structure:
# name: Test Group
# id: 123
# schedule:
#   Mon: daily
#   Sun: monthly
```
