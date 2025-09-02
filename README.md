# Tcl Group Module

A Tcl library for creating and managing "groups," which are composite, prototype-based data objects built on Tcl's associative arrays.

## Description

This package provides a powerful, idiomatic Tcl system for creating flexible data objects. It supports two main object-oriented patterns: **composition** (building complex objects from smaller pieces) and **prototypical inheritance** (cloning objects to create new ones that inherit their behavior).

This library is ideal for managing complex, structured data, such as application configurations, where you need the flexibility to assemble objects and simulate inheritance.

## Core Concepts

This library provides two powerful, distinct mechanisms for creating and structuring objects:

1.  **Composition**: This is the primary mechanism for building complex **data objects**. You can define common data structures once (as simple arrays or as other `group` objects) and reuse them as components to assemble larger, more complex groups. This is the recommended pattern for structuring configuration data.

2.  **Prototypical Inheritance**: This is the primary mechanism for creating objects that share **behavior (methods)**. You can create a new `group` by cloning a "prototype." The new object maintains a live link to its parent, allowing it to inherit methods and receive updates dynamically.

## Documentation

* **[Composition Guide](./docs/composition.md)**: Learn how to build complex data objects by assembling them from components.
* **[Prototypical Inheritance Guide](./docs/prototypes.md)**: Learn how to use the prototype-based OOP features to create objects that inherit behavior.
* **[Input/Output Guide](./docs/io.md)**: Learn how to ingest and egress data in various formats/types.

## API

The library provides a single `group` command with the following subcommands:

* `group create <group_name> {key value ...}`
* `group copy <new_group_name> <source_group_name>`
* `group createFromLists <group_name> <key_list> <value_list>`
* `group fromYaml <group_name> <filename>`
* ...and more.

---

## References

* [The Tclers' Wiki](https://wiki.tcl-lang.org/)
* [Official Tcl Documentation](https://www.tcl.tk/man/)

## Author

This `group` module was designed and written by **Rudolph Pienaar**.
