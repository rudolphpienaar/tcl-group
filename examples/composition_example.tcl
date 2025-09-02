#
# This script demonstrates the composition features
# of the Tcl Group module.
#
# Add the library directory to the auto_path and load the package
lappend auto_path [file join [file dirname [info script]] ../lib]
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir .. lib group.tcl]
#package require group

# ===========================================================
# == 1. Create component data structures
# ===========================================================

# Component 1: A simple Tcl array for database settings
array set db_config {
    host     "localhost"
    port     "5432"
    database "production"
    pool_size "10"
}

# Component 2: A group object for security settings
group create security_config {
    ssl_enabled    "true"
    cert_path      "/etc/ssl/certs"
    timeout        "30"
    max_retries    "3"
}

# Component 3: Simple variables for dereferencing
set environment "production"
set admin_email "admin@example.com"

puts "--- Component structures created ---"
puts "Database config keys: [array names db_config]"
puts "Security config data:"
parray security_config
puts ""

# ===========================================================
# == 2. Build a composite application configuration
# ===========================================================

puts "--- Creating composite application config ---"

# Define the structure for our main configuration
set config_keys {
    app_name
    environment
    database
    security
    admin_contact
    version
}

set config_values {
    "MyWebApp"
    *environment
    @db_config
    @security_config
    *admin_email
    "2.1.0"
}

# Create the composite group using the sigils:
# * = dereference a variable
# @ = flatten a component array/group
group createFromLists app_config &config_keys &config_values

puts "--- Composite configuration created ---"
puts "Flattened structure:"
parray app_config
puts ""

# ===========================================================
# == 3. Demonstrate accessing the flattened data
# ===========================================================

puts "--- Accessing composed data ---"
puts "App name: $app_config(app_name)"
puts "Environment: $app_config(environment)"
puts "Database host: $app_config(database,host)"
puts "Database port: $app_config(database,port)"
puts "SSL enabled: $app_config(security,ssl_enabled)"
puts "SSL cert path: $app_config(security,cert_path)"
puts "Admin contact: $app_config(admin_contact)"
puts ""

# ===========================================================
# == 4. Create a second composite that reuses components
# ===========================================================

puts "--- Creating a test environment config (reusing components) ---"

# We can reuse the same components with different values
set test_environment "testing"
set test_admin "test-admin@example.com"

set test_config_keys {
    app_name
    environment
    database
    security
    admin_contact
    debug_mode
}

set test_config_values {
    "MyWebApp-Test"
    *test_environment
    @db_config
    @security_config
    *test_admin
    "true"
}

group createFromLists test_app_config &test_config_keys &test_config_values

puts "Test configuration created:"
puts "App: $test_app_config(app_name)"
puts "Environment: $test_app_config(environment)"
puts "Database host: $test_app_config(database,host)"
puts "Debug mode: $test_app_config(debug_mode)"
puts ""

# ===========================================================
# == 5. Demonstrate deep nested composition (3+ levels)
# ===========================================================

puts "--- Demonstrating deep nested composition ---"

# Level 1: Basic authentication settings
array set auth_basic {
    method     "password"
    min_length "8"
    complexity "medium"
}

# Level 1: OAuth settings
array set auth_oauth {
    provider    "google"
    client_id   "abc123"
    scope       "email,profile"
}

# Level 2: Authentication component (contains Level 1)
set auth_keys {basic oauth enabled mfa_required}
set auth_values {@auth_basic @auth_oauth "true" "false"}
group createFromLists auth_config &auth_keys &auth_values

# Level 2: Logging component
group create logging_config {
    level      "INFO"
    file       "/var/log/app.log"
    rotate     "daily"
    max_size   "100MB"
}

# Level 2: Caching component
group create cache_config {
    type       "redis"
    host       "cache-server"
    port       "6379"
    ttl        "3600"
}

# Level 3: Service component (contains Level 2 components)
set service_keys {name authentication logging caching port}
set service_values {"web-service" @auth_config @logging_config @cache_config "8080"}
group createFromLists service_config &service_keys &service_values

# Level 3: Load balancer component
group create lb_config {
    algorithm  "round_robin"
    health_check "/health"
    timeout    "30"
}

# Level 4: Infrastructure component (contains Level 3 components)
set infra_keys {services load_balancer database security monitoring_enabled}
set infra_values {@service_config @lb_config @db_config @security_config "true"}
group createFromLists infrastructure &infra_keys &infra_values

puts "Deep nested composition result (4 levels deep):"
puts ""
puts "=== Level 4 (Infrastructure) ==="
puts "Monitoring enabled: $infrastructure(monitoring_enabled)"
puts ""
puts "=== Level 3 (Service) ==="
puts "Service name: $infrastructure(services,name)"
puts "Service port: $infrastructure(services,port)"
puts ""
puts "=== Level 2 (Authentication/Logging/Cache) ==="
puts "Auth enabled: $infrastructure(services,authentication,enabled)"
puts "MFA required: $infrastructure(services,authentication,mfa_required)"
puts "Log level: $infrastructure(services,logging,level)"
puts "Log file: $infrastructure(services,logging,file)"
puts "Cache type: $infrastructure(services,caching,type)"
puts "Cache TTL: $infrastructure(services,caching,ttl)"
puts ""
puts "=== Level 1 (Basic Auth/OAuth) ==="
puts "Basic auth method: $infrastructure(services,authentication,basic,method)"
puts "Password min length: $infrastructure(services,authentication,basic,min_length)"
puts "OAuth provider: $infrastructure(services,authentication,oauth,provider)"
puts "OAuth client ID: $infrastructure(services,authentication,oauth,client_id)"
puts ""
puts "=== Cross-level access (Database from Level 4, Security from Level 4) ==="
puts "DB host: $infrastructure(database,host)"
puts "DB port: $infrastructure(database,port)"
puts "SSL enabled: $infrastructure(security,ssl_enabled)"
puts "Load balancer algorithm: $infrastructure(load_balancer,algorithm)"
