# Tcl Group Module: Prototypical-based composable data objects

A Tcl library for creating and managing "groups," which are composite, prototype-based data objects built on Tcl's associative arrays.

## Description

This package provides a powerful, idiomatic Tcl system for creating flexible data objects. It supports two main object-oriented patterns: **composition** (building complex objects from smaller pieces) and **prototypical inheritance** (cloning objects to create new ones that inherit their behavior).

This library is ideal for managing complex, structured data, such as application configurations. It can ingest and egress data in various formats (YAML, JSON, legacy) and includes an optional, high-performance **C extension** to provide robust and reliable JSON parsing, bypassing the inherent type ambiguities of Tcl.

## Core Concepts

This library provides two powerful, distinct mechanisms for creating and structuring objects:

1. **Composition**: This is the primary mechanism for building complex **data objects**. You can define common data structures once (as simple arrays or as other `group` objects) and reuse them as components to assemble larger, more complex groups. This is the recommended pattern for structuring configuration data.

2. **Prototypical Inheritance**: This is the primary mechanism for creating objects that share **behavior (methods)**. You can create a new `group` by cloning a "prototype." The new object maintains a live link to its parent, allowing it to inherit methods and receive updates dynamically.

## High-Performance C Extension

To solve the fundamental ambiguity issues with Tcl's type system when parsing complex, nested data, this module includes an optional C extension. This extension uses the battle-hardened `json-c` library to provide a fast, reliable, and robust engine for JSON parsing.

When compiled and available, the `group::fromJson` command will automatically use this C engine, guaranteeing correct parsing of any valid JSON file.

* [**C Extension README**](./lib/README.md): See the detailed guide for dependencies and compilation instructions.

## Documentation

* [**Composition Guide**](./docs/composition.md): Learn how to build complex data objects by assembling them from components.

* [**Prototypical Inheritance Guide**](./docs/prototypes.md): Learn how to use the prototype-based OOP features to create objects that inherit behavior.

* [**Input/Output Guide**](./docs/io.md): Learn how to ingest and egress data in various formats/types.

## API

The library provides a single `group` command with the following subcommands:

* `group create <group_name> {key value ...}`

* `group createFromLists <group_name> <key_list> <value_list>`

* `group copy <new_group_name> <source_group_name>`

* `group fromYaml <group_name> <%filename | $data>`

* `group toYaml <group_name> <%filename | $varname>`

* `group fromJson <group_name> <%filename | $data>`

* `group toJson <group_name> <%filename | $varname> ?indent_width?`

* `group fromLegacy <group_name> <%filename | $data>`

* `group toLegacy <group_name> <%filename | $varname>`

* `group dump <group_name>`

* `group setLeafPlaceholder <placeholder_string>`

* ...and more.

## References

* [The Tclers' Wiki](https://wiki.tcl-lang.org/)

* [Official Tcl Documentation](https://www.tcl.tk/man/)

## Author

This `group` module was designed and written by **Rudolph Pienaar**.
