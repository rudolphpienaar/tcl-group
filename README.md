# Tcl Group: Prototypical Object-Oriented Programming for Tcl

**Bring JavaScript/Lua-style prototypical inheritance to Tcl.**

A lightweight OOP system for Tcl that implements **prototype-based inheritance** through object cloning and dynamic method delegation. Objects are just Tcl arrays. Methods are just procedures. Inheritance happens at runtime through a live prototype chain.

## Why This Matters

Tcl has several OOP systems (TclOO, Incr Tcl, Snit, STOOOP), but they're all **class-based**: you define classes, then instantiate objects. `tcl-group` takes a fundamentally different approach inspired by JavaScript and Lua: **objects inherit directly from other objects**.

### The Prototype Pattern in 30 Seconds

```tcl
# Define a method (just a regular proc)
proc speak {animal_name} {
    upvar 1 $animal_name animal
    puts "$animal(name) says $animal(sound)"
}

# Create a prototype object
group create animal {
    name    "Generic Animal"
    sound   "..."
    speak   "speak"
}

# Clone it to create a new object
group copy dog animal
set dog(name) "Rover"
set dog(sound) "Woof!"

# Call inherited method
dog speak
# -> "Rover says Woof!"

# Add method to parent AFTER child was created
set animal(eat) "eat_proc"

# Child immediately has the new method
dog eat  # Works! Live prototype chain.
```

**No classes. No constructors. Just objects cloning objects.**

## What Makes This Different from TclOO?

| Feature | TclOO | tcl-group |
|---------|-------|-----------|
| **Paradigm** | Class-based | **Prototype-based** |
| **Inheritance** | Static (defined at class creation) | **Dynamic (live delegation chain)** |
| **Object creation** | `Class new` (instantiation) | **`group copy` (cloning)** |
| **Add methods to parent** | Must redefine class | **Automatically available to children** |
| **Object structure** | Opaque (encapsulated) | **Transparent (just Tcl arrays)** |
| **Multiple instances** | Easy (`[Class new]` each time) | Limited (global array names) |
| **Serialization** | Manual (custom per class) | **Built-in (YAML/JSON)** |
| **Learning curve** | Medium (OOP concepts + TclOO syntax) | **Low (if you know arrays + procs)** |

## Core Features

### 1. Prototypical Inheritance

Objects inherit behavior through a **live prototype chain**. The method dispatcher walks up the `parent` chain at call-time, enabling:

- **Dynamic method addition**: Add methods to prototypes after children are created
- **Flexible object hierarchies**: Chain prototypes as deep as needed
- **JavaScript/Lua-like OOP**: If you know prototypal inheritance, you already understand this

**[→ Full Prototypical Inheritance Guide](./docs/prototypes.md)**

### 2. Data Composition

Build complex data structures by composing reusable components using a straightforward sigil-based syntax:

```tcl
# Reusable components
array set db_config {host "localhost" port 5432}
group create auth_config {ssl_enabled true timeout 30}

# Compose them into a larger structure
set keys {database authentication admin}
set values {@db_config @auth_config "admin@example.com"}
group createFromLists app_config &keys &values

# Access flattened structure
puts $app_config(database,host)          # -> localhost
puts $app_config(authentication,timeout) # -> 30
```

**Sigils:**
- `@varname` - Flatten a component array/group into the parent
- `*varname` - Dereference a variable value
- `&varname` - Pass-by-name for variable arguments
- `%filepath` - File path marker for I/O operations

**[→ Composition Guide](./docs/composition.md)**

### 3. Multi-Format Serialization

Serialize and deserialize objects in YAML, JSON, or legacy formats with built-in support:

```tcl
group create game_state {
    level      5
    health     87
    inventory  "sword,shield,potion"
}

# Save to JSON
group toJson game_state %savegame.json

# Load it back
group fromJson loaded_state %savegame.json
```

Includes an **optional high-performance C extension** using `json-c` for bulletproof JSON parsing that bypasses Tcl's type ambiguities.

**[→ I/O Guide](./docs/io.md)**

## When to Use This vs TclOO

**Use `tcl-group` when you want:**
- Prototypical inheritance (JavaScript/Lua-style OOP)
- Objects that are fully introspectable (just arrays)
- Built-in serialization to/from YAML/JSON
- Minimal boilerplate for simple objects
- Rapid prototyping (game entities, event systems, data processors)
- Dynamic object modification at runtime

**Use TclOO when you want:**
- True encapsulation (private variables/methods)
- Multiple instances of the same class easily
- Compile-time optimizations
- Constructor/destructor logic
- Traditional OOP patterns (factories, singletons, etc.)
- Complex class hierarchies

## Installation

### Quick Start

```bash
git clone https://github.com/rudolphpienaar/tcl-group.git
cd tcl-group
tclsh deploy.tcl group-1.0 ~/tcl/lib
export TCLLIBPATH="~/tcl/lib"
```

Then in your Tcl script:
```tcl
package require group
group create my_object {foo "bar"}
```

### Developer Install (Symlinks)

```bash
tclsh deploy.tcl --link group-1.0 ~/tcl/lib
```

### Optional: Compile C Extension for High-Performance JSON

See [**C Extension README**](./clib/README.adoc) for compilation instructions using `json-c`.

## API Overview

```tcl
# Object Creation
group create <name> {key value ...}
group copy <new_name> <source_name>        # Clone with prototype link
group createFromLists <name> <keys> <vals> # Composition

# Serialization
group fromYaml <name> <%file | $data>
group toYaml <name> {%file | $var}
group fromJson <name> <%file | $data>
group toJson <name> {%file | $var} ?indent?
group fromLegacy <name> <%file | $data>
group toLegacy <name> {%file | $var}

# Utilities
group dump <name>                          # Pretty-print
group toTable <name> ?options?             # ASCII table format
group man                                  # Show full documentation
```

## Examples

- [**Prototypical Inheritance Example**](./examples/inheritance_example.tcl) - Birds with shared behavior
- [**Composition Example**](./examples/composition_example.tcl) - Multi-level nested configurations
- [**I/O Example**](./examples/io_example.tcl) - YAML/JSON serialization

## Philosophical Position

This library takes the position that:

1. **Not all problems need encapsulation.** Sometimes you want transparent data structures.
2. **Prototypes are simpler than classes** for many use cases (game entities, event handlers, configurations).
3. **Objects should be serializable by default.** If your object is data + behavior references, saving state is trivial.
4. **Tcl arrays are underutilized.** They're fast, simple, and global - perfect for prototype-based OOP.

If you've used JavaScript's prototypal inheritance (pre-ES6 classes) or Lua's metatable-based OOP, this will feel immediately familiar.

## Performance Notes

The method dispatcher performs **dynamic lookup** on every method call, walking the prototype chain until the method is found. For most applications this is negligible. For hot loops calling methods thousands of times per second, TclOO's compiled dispatch will be faster.

Trade-off: **Flexibility vs Speed**. We chose flexibility.

## Testing

```bash
cd tests
tclsh group_test_suite.tcl
```

Requires `yaml` and `json` packages.

## Contributing

See [**CONTRIBUTING.md**](./CONTRIBUTING.md) for guidelines.

## Author

Designed and written by **Rudolph Pienaar**.

## License

[See LICENSE](./LICENSE)

---

**Prototypical OOP for Tcl. Objects inherit from objects. No classes required.**
