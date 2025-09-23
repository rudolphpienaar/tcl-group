#
# Module: table.tcl
# Author: Rudolph Pienaar & Gemini Assistant
#
# DESCRIPTION
#   This module provides a self-contained, dependency-free procedure for
#   formatting a Tcl list of lists (a matrix) into a clean, human-readable,
#   bordered ASCII table.
#
#   It is specifically designed to correctly handle ANSI color escape codes,
#   ensuring that table alignment is not broken when cell contents are
#   colorized. This is achieved by calculating column widths based on the
#   raw, uncolored text before manually constructing the padded, colored output.
#
#   The primary command is 'table::render', which takes the data matrix and
#   an optional list of color arguments.
#
# USAGE EXAMPLE
#
#   # 1. Source the module
#   source [file join [file dirname [info script]] table.tcl]
#
#   # 2. Prepare the data as a list of lists (the first row is the header)
#   set my_data {
#       {Key           Value}
#       {name          "test"}
#       {managerHost   "127.0.0.1"}
#   }
#
#   # 3. Define the color options
#   set colors [list -headerKeyColor {bold yellow} -bodyValColor {green}]
#
#   # 4. Call the renderer
#   puts [table::render $my_data {*}$colors]
#

package provide table 1.0

namespace eval table {
    namespace export render

    # ===================================================================
    # == PUBLIC API IMPLEMENTATION
    # ===================================================================

    proc render {matrix args} {
        #
        # ARGS
        # matrix    in      A Tcl list of lists, where each inner list is a row.
        #                   The first row is assumed to be the header.
        # args      in      An optional key-value list of color options. Valid keys:
        #                   -headerKeyColor:  Tcl color for the header's first column.
        #                   -headerValColor:  Tcl color for the header's second column.
        #                   -bodyKeyColor:    Tcl color for the body's first column.
        #                   -bodyValColor:    Tcl color for the body's second column.
        #
        # DESC
        # A self-contained ASCII table formatter. It correctly handles ANSI
        # color codes by manually calculating padding based on the length of
        # the raw, uncolored text.
        #
        # RETURN
        # A multi-line string containing the fully formatted ASCII table.
        #
        if {[llength $matrix] == 0} {return ""}

        # --- Process optional color arguments ---
        array set colors {
            -headerKeyColor "" -headerValColor ""
            -bodyKeyColor   "" -bodyValColor   ""
        }
        array set colors $args

        # --- Separate header from body for processing ---
        set header [lindex $matrix 0]
        set body [lrange $matrix 1 end]

        # --- Step 1: Calculate column widths from RAW, UNCOLORED data ---
        set key_width [string length [lindex $header 0]]
        set val_width [string length [lindex $header 1]]

        foreach row $body {
            set current_key_width [string length [lindex $row 0]]
            set current_val_width [string length [lindex $row 1]]
            if {$current_key_width > $key_width} {set key_width $current_key_width}
            if {$current_val_width > $val_width} {set val_width $current_val_width}
        }

        # --- Step 2: Build the table border components ---
        set top_border "┌[string repeat ─ [expr {$key_width + 2}]]┬[string repeat ─ [expr {$val_width + 2}]]┐"
        set middle_border "├[string repeat ─ [expr {$key_width + 2}]]┼[string repeat ─ [expr {$val_width + 2}]]┤"
        set bottom_border "└[string repeat ─ [expr {$key_width + 2}]]┴[string repeat ─ [expr {$val_width + 2}]]┘"

        set output ""
        append output "$top_border\n"

        # --- Step 3: Manually build each colored, padded row ---
        # Helper function to build a single formatted cell.
        proc _build_cell {raw_text color_spec full_width} {
            set colored_text $raw_text
            if {$color_spec ne ""} {
                set colored_text [appUtils::colorize $color_spec $raw_text]
            }
            set padding [string repeat " " [expr {$full_width - [string length $raw_text]}]]
            return " $colored_text$padding "
        }

        # --- Build Header Row ---
        set h_key_raw [lindex $header 0]
        set h_val_raw [lindex $header 1]
        set h_cell_1 [_build_cell $h_key_raw $colors(-headerKeyColor) $key_width]
        set h_cell_2 [_build_cell $h_val_raw $colors(-headerValColor) $val_width]
        append output "|$h_cell_1│$h_cell_2|\n"
        append output "$middle_border\n"

        # --- Build Body Rows ---
        foreach row $body {
            set b_key_raw [lindex $row 0]
            set b_val_raw [lindex $row 1]
            set b_cell_1 [_build_cell $b_key_raw $colors(-bodyKeyColor) $key_width]
            set b_cell_2 [_build_cell $b_val_raw $colors(-bodyValColor) $val_width]
            append output "|$b_cell_1│$b_cell_2|\n"
        }
        append output "$bottom_border\n"

        return $output
    }
}
