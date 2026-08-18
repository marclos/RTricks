#!/usr/bin/env Rscript

# =============================================================================
# RegionalClimateNarratives Package Installation Script (student version)
# =============================================================================
# Installs ALL dependencies first, then installs RegionalClimateNarratives from the
# Regional_Climate_Narratives_<version>.tar.gz that came in your zip. It prints a
# clear pass/fail for every step so you can tell exactly where things stand.
#
# This script does NOT need devtools or roxygen2: the tar.gz already
# contains built documentation.
#
# USAGE (from R/RStudio, with your working directory set to the folder
# containing this script and the tar.gz, e.g. ~/regional_climate_narratives):
#     source("install_package.R")
#
# From command line:
#     Rscript install_package.R
# =============================================================================

cat("\n")
cat("===========================================================\n")
cat("  Regional Climate Narratives Package Installer\n")
cat("===========================================================\n\n")

# -------------------------------------------------------------------------
# STEP 1: Find the package installer (tar.gz)
# -------------------------------------------------------------------------
cat("--- Step 1: Locating the package installer ---\n\n")

## Look in the working directory first; if this script is being source()d
## from somewhere else, also look in the script's own folder.
find_tarball <- function() {
  dirs <- getwd()
  frames <- sys.frames()
  for (fr in frames) {                       # directory of a source()d file
    of <- get0("ofile", envir = fr, ifnotfound = NULL)
    if (is.character(of)) dirs <- c(dirs, dirname(normalizePath(of)))
  }
  dirs <- unique(dirs)
  hits <- unlist(lapply(dirs, list.files,
                        pattern = "^Regional_Climate_Narratives_.*\\.tar\\.gz$",
                        full.names = TRUE))
  if (length(hits) == 0) return(NULL)
  vers <- sub("^Regional_Climate_Narratives_(.*)\\.tar\\.gz$", "\\1", basename(hits))
  hits[order(as.numeric_version(vers), decreasing = TRUE)][1]
}

tarball <- find_tarball()
if (is.null(tarball)) {
  cat("  FAILED: No Regional_Climate_Narratives_*.tar.gz found in:\n")
  cat("    ", getwd(), "\n\n")
  cat("  Fix: run  setwd(\"~/regional_climate_narratives\")  (the folder where\n")
  cat("  you uploaded the zip), then source this script again.\n\n")
  stop("Installer tar.gz not found. See message above.")
}
cat("  [OK] Found", basename(tarball), "\n")

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
  "viridis", "maps", "mapdata", "patchwork"
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
    cat("  (Show your instructor the FAILED lines above; a system\n")
    cat("  library may be missing on the server.)\n")
    cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n")
    stop("Dependency installation failed. See messages above.")
  }
}

# -------------------------------------------------------------------------
# STEP 3: Install RegionalClimateNarratives from the tar.gz
# -------------------------------------------------------------------------
cat("\n--- Step 3: Installing RegionalClimateNarratives ---\n\n")
cat("  Installing from", basename(tarball), "(this takes a minute)...\n")

tryCatch({
  install.packages(tarball, repos = NULL, type = "source", quiet = TRUE)
  cat("  [OK] Package installed\n")
}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
  stop("Package installation failed. See error above.")
})

# -------------------------------------------------------------------------
# STEP 4: Verify
# -------------------------------------------------------------------------
cat("\n--- Step 4: Verifying installation ---\n\n")

if (!requireNamespace("RegionalClimateNarratives", quietly = TRUE)) {
  cat("  FAILED: package did not install cleanly.\n")
  stop("Package load failed even after install. See error above.")
}
inst_version  <- as.character(utils::packageVersion("RegionalClimateNarratives"))
fname_version <- sub("^Regional_Climate_Narratives_(.*)\\.tar\\.gz$", "\\1",
                     basename(tarball))
cat("  [OK] Regional Climate Narratives v", inst_version, " is installed\n", sep = "")

if (!identical(inst_version, fname_version)) {
  cat("\n")
  cat("  [WARN] The file is named v", fname_version,
      " but the package inside it is v", inst_version, ".\n", sep = "")
  cat("  The installed version is v", inst_version,
      " (R uses the DESCRIPTION inside the file,\n", sep = "")
  cat("  not the filename). This is fine for the activity, but mention\n")
  cat("  it to your instructor so the file can be fixed.\n")
}

library(RegionalClimateNarratives)

cat("\n")
cat("===========================================================\n")
cat("  Installation Complete!\n")
cat("===========================================================\n")
cat("  To get started:\n")
cat("    library(RegionalClimateNarratives)\n")
cat("    initialize_project('CA')   # your state code\n")
cat("    ?RegionalClimateNarratives\n")
cat("===========================================================\n\n")
