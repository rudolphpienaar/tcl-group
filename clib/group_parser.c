#include <tcl.h>
#include <json-c/json.h>
#include <string.h>

/*
 * Recursively traverses a json-c object and flattens it into a Tcl list
 * of key-value pairs. This C implementation avoids all Tcl type ambiguity.
 */
static void FlattenJsonObj(json_object *jobj, Tcl_Obj *listObj, const char *prefix) {
    // Iterate over each key-value pair in the JSON object.
    json_object_object_foreach(jobj, key, val) {
        char new_key[1024]; // Buffer for the new flattened key.
        const char *value_str;

        // Construct the new comma-delimited key.
        if (prefix[0] == '\0') {
            snprintf(new_key, sizeof(new_key), "%s", key);
        } else {
            snprintf(new_key, sizeof(new_key), "%s,%s", prefix, key);
        }

        // Check the type of the value. C's strong typing is the key here.
        enum json_type type = json_object_get_type(val);

        if (type == json_type_object) {
            // It's a nested object (a branch), so we recurse.
            FlattenJsonObj(val, listObj, new_key);
        } else {
            // It's a scalar (a leaf), so we add it to our Tcl list.
            value_str = json_object_get_string(val);

            // Append the flattened key to the Tcl list.
            Tcl_ListObjAppendElement(NULL, listObj, Tcl_NewStringObj(new_key, -1));
            // Append the pristine value to the Tcl list.
            Tcl_ListObjAppendElement(NULL, listObj, Tcl_NewStringObj(value_str, -1));
        }
    }
}

/*
 * The C function that will be exposed to Tcl as the 'group::fromJson_C' command.
 */
static int GroupFromJsonCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    // 1. Validate arguments.
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "json_string");
        return TCL_ERROR;
    }

    // 2. Get the JSON text from the Tcl script.
    const char *json_text = Tcl_GetString(objv[1]);

    // 3. Parse the text using the robust json-c library.
    json_object *root_obj = json_tokener_parse(json_text);
    if (root_obj == NULL) {
        Tcl_SetResult(interp, "Failed to parse JSON text in C", TCL_STATIC);
        return TCL_ERROR;
    }

    // 4. Create an empty Tcl list object to hold the result.
    Tcl_Obj *resultListObj = Tcl_NewListObj(0, NULL);

    // 5. Call our recursive C function to flatten the structure.
    FlattenJsonObj(root_obj, resultListObj, "");

    // 6. Set the Tcl interpreter's result to our newly created list.
    Tcl_SetObjResult(interp, resultListObj);

    // 7. Clean up the C memory.
    json_object_put(root_obj);

    return TCL_OK;
}

/*
 * The initialization function that Tcl calls when the library is loaded.
 * Its name MUST match the Tcl 'load' command's derivation from the filename.
 * For 'group_parser.so', the expected name is 'Groupparser_Init'.
 */
int Group_parser_Init(Tcl_Interp *interp) {
    if (Tcl_InitStubs(interp, "8.5", 0) == NULL) {
        return TCL_ERROR;
    }
    // Create the new command 'group::fromJson_C'
    Tcl_CreateObjCommand(interp, "group::fromJson_C", GroupFromJsonCmd, NULL, NULL);
    return TCL_OK;
}

