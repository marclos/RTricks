#!/usr/bin/env Rscript

# =============================================================================
# ClimateNarratives Package Installation Script
# =============================================================================
# This script installs ALL dependencies first, then builds and installs
# ClimateNarratives. It prints a clear pass/fail for every step so you
# can tell exactly where things stand.
#
# USAGE:
#   From R/RStudio:
#     source("install_package.R")
#
#   From command line:
#     Rscript install_package.R
# =============================================================================

cat("\n")
cat("===========================================================\n")
cat("  ClimateNarratives Package Installer\n")
cat("===========================================================\n\n")

# -------------------------------------------------------------------------
# STEP 1: Install devtools + roxygen2 (needed for building)
# -------------------------------------------------------------------------
cat("--- Step 1: Checking build tools ---\n\n")

for (pkg in c("devtools", "roxygen2")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("  Installing", pkg, "... ")
    tryCatch({
      install.packages(pkg, quiet = TRUE)
      cat("OK\n")
    }, error = function(e) {
      cat("FAILED\n")
      stop("Cannot install ", pkg, ". Error: ", conditionMessage(e))
    })
  } else {
    cat("  [OK]", pkg, "already installed\n")
  }
}

# -------------------------------------------------------------------------
# STEP 2: Install ALL dependencies (the part students trip on)
# -------------------------------------------------------------------------
cat("\n--- Step 2: Installing dependencies ---\n\n")

required <- c(
  # Core
  "dplyr", "tidyr", "ggplot2", "lubridate",
  # Spatial
  "sp", "sf", "gstat", "raster", "stars",
  # Visualization
  "viridis", "maps", "mapdata", "patchwork",
  # Vignette support
  "knitr", "rmarkdown"
)

installed_pkgs <- rownames(installed.packages())
missing <- required[!required %in% installed_pkgs]

if (length(missing) == 0) {
  cat("  All", length(required), "dependencies already installed.\n")
} else {
  cat("  Need to install", length(missing), "package(s):\n")
  cat("  ", paste(missing, collapse = ", "), "\n\n")

  failures <- character(0)
  for (pkg in missing) {
    cat("  Installing", pkg, "... ")
    tryCatch({
      install.packages(pkg, quiet = TRUE)
      if (requireNamespace(pkg, quietly = TRUE)) {
        cat("OK\n")
      } else {
        cat("FAILED (not loadable after install)\n")
        failures <- c(failures, pkg)
      }
    }, error = function(e) {
      cat("FAILED:", conditionMessage(e), "\n")
      failures <<- c(failures, pkg)
    })
  }

  if (length(failures) > 0) {
    cat("\n")
    cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
    cat("  STOP: These packages failed to install:\n")
    cat("    ", paste(failures, collapse = ", "), "\n")
    cat("  Fix these first, then re-run this script.\n")
    cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n")
    stop("Dependency installation failed. See messages above.")
  }
}

# -------------------------------------------------------------------------
# STEP 3: Build documentation
# -------------------------------------------------------------------------
cat("\n--- Step 3: Building documentation ---\n\n")

tryCatch({
  devtools::document()
  cat("  [OK] Documentation built\n")
}, error = function(e) {
  cat("  [WARN] Documentation build had issues:", conditionMessage(e), "\n")
  cat("  Continuing with install...\n")
})

# -------------------------------------------------------------------------
# STEP 4: Install the package (skip check -- students don't need it)
# -------------------------------------------------------------------------
cat("\n--- Step 4: Installing ClimateNarratives ---\n\n")

tryCatch({
  devtools::install(quick = TRUE, upgrade = "never")
  cat("  [OK] Package installed\n")
}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
  stop("Package installation failed. See error above.")
})

# -------------------------------------------------------------------------
# STEP 5: Verify
# -------------------------------------------------------------------------
cat("\n--- Step 5: Verifying installation ---\n\n")

tryCatch({
  library(ClimateNarratives)
  cat("  [OK] library(ClimateNarratives) loaded successfully!\n")
}, error = function(e) {
  cat("  FAILED to load:", conditionMessage(e), "\n")
  stop("Package loads failed even after install. See error above.")
})

cat("\n")
cat("===========================================================\n")
cat("  Installation Complete!\n")
cat("===========================================================\n")
cat("  To get started:\n")
cat("    library(ClimateNarratives)\n")
cat("    initialize_project('CA')\n")
cat("    ?ClimateNarratives\n")
cat("===========================================================\n\n")
