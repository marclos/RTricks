# =============================================================================
# ClimateNarrativesFunctions_v07.R
# =============================================================================
# Consolidated R functions for Regional Climate Trends Project
# Version 7.0 - Pedagogical focus with improved variable handling
#
# Author: Marc Los Huertos
# Updated: 2025-01-23
#
# USAGE:
# source("ClimateNarrativesFunctions_v07.R")
# setup_project("CA") # Initialize project for California
#
# CHANGE LOG v7.0:
# - Fixed figuresfolder variable not being set correctly in all contexts
# - Added datafolder and figuresfolder to function returns for clarity
# - Improved error messages for missing variables
# - Enhanced documentation for teaching purposes
# - Version numbering updated to 0.07
#
# CHANGE LOG v6.0:
# - Consolidated all functions into single file
# - Increased default stations from 15 to 50 for better heat maps
# - Added automatic cleanup of .gz and .csv files after saving to RData
# - Standardized path handling with here package
# - Improved error handling and progress reporting
# - Added data quality filters (min 50 years, recent data required)
# =============================================================================

# =============================================================================
# PACKAGE DEPENDENCIES
# =============================================================================

required_packages <- c(
  "dplyr",      # Data manipulation
  "tidyr",      # Data reshaping
  "lubridate",  # Date handling
  "ggplot2",    # Plotting
  "sp",         # Spatial objects (legacy)
  "sf",         # Simple features (modern spatial)
  "gstat",      # Kriging interpolation
  "raster",     # Raster data
  "stars",      # Spatiotemporal arrays
  "viridis",    # Color scales
  "maps",       # State boundaries
  "mapdata",    # Additional map data
  "patchwork"   # Combine plots
)

#' Check and Install Required Packages
#' @export
check_packages <- function() {
  missing_pkgs <- required_packages[!required_packages %in% installed.packages()[,"Package"]]
  
  if(length(missing_pkgs) > 0) {
    message("Installing required packages: ", paste(missing_pkgs, collapse = ", "))
    install.packages(missing_pkgs, dependencies = TRUE)
  }
  
  suppressPackageStartupMessages({
    lapply(required_packages, library, character.only = TRUE)
  })
  
  message("[OK] All required packages loaded successfully.")
}

# =============================================================================
# 1. PROJECT SETUP FUNCTIONS
# =============================================================================

#' Set Up Project Directory Structure
#' 
#' Creates organized folder structure and downloads station inventory.
#' Sets global variables: my.state, my.inventory, datafolder, figuresfolder
#' 
#' @param my.state Two-letter state abbreviation (e.g., "CA", "NV", "TX")
#' @param project_path Path where project should be created (default: current directory)
#' @return List with paths and inventory data
#' @export
setup_project <- function(my.state, project_path = getwd()) {
  
  cat("\n")
  cat("===========================================================\n")
  cat("  Climate Narratives Project Setup v7.0\n")
  cat("===========================================================\n")
  cat("  Enhanced for improved spatial analysis\n")
  cat("===========================================================\n")
  cat("  Project path:", project_path, "\n")
  cat("===========================================================\n\n")
  
  # Validate state
  if (nchar(my.state) != 2) {
    stop("State must be a 2-letter abbreviation (e.g., 'CA', 'NV', 'TX')")
  }
  my.state <- toupper(my.state)
  
  # Create directory structure
  dirs <- list(
    root = project_path,
    data = file.path(project_path, "Data"),
    output = file.path(project_path, "Output"),
    figures = file.path(project_path, "Figures")
  )
  
  cat("Creating directories...\n")
  for (dir_name in names(dirs)) {
    if (dir_name == "root") next  # Skip root
    if (!dir.exists(dirs[[dir_name]])) {
      dir.create(dirs[[dir_name]], recursive = TRUE)
      cat("  [OK] Created:", dirs[[dir_name]], "\n")
    } else {
      cat("  [OK] Exists:", dirs[[dir_name]], "\n")
    }
  }
  
  # =========================================================================
  # CRITICAL: Set folder path variables in global environment
  # These are used throughout the labs for reading/writing files
  # =========================================================================
  datafolder <- paste0(dirs$data, "/")
  figuresfolder <- paste0(dirs$figures, "/")
  
  assign("datafolder", datafolder, envir = .GlobalEnv)
  assign("figuresfolder", figuresfolder, envir = .GlobalEnv)
  
  cat("\n[OK] Set folder variables:\n")
  cat("     datafolder    =", datafolder, "\n")
  cat("     figuresfolder =", figuresfolder, "\n")
  
  # Download station inventory if needed
  inventory_file <- file.path(dirs$data, "stations.active.oldest.csv")
  
  if (!file.exists(inventory_file)) {
    cat("\nDownloading station inventory from NOAA...\n")
    tryCatch({
      inventory <- download_station_inventory()
      write.csv(inventory, inventory_file, row.names = FALSE)
      cat("[OK] Saved station inventory\n")
    }, error = function(e) {
      stop("Failed to download inventory: ", e$message)
    })
  } else {
    cat("\n[OK] Station inventory already exists\n")
    inventory <- read.csv(inventory_file)
  }
  
  # Subset for the selected state
  my.inventory <- subset(inventory, STATE == my.state)
  
  if (nrow(my.inventory) == 0) {
    cat("\nAvailable states:\n")
    print(sort(unique(inventory$STATE)))
    stop("No stations found for state: ", my.state)
  }
  
  cat("\n[OK] Found", nrow(my.inventory), "potential stations for", my.state, "\n\n")
  
  # Store in global environment
  assign("my.state", my.state, envir = .GlobalEnv)
  assign("my.inventory", my.inventory, envir = .GlobalEnv)
  
  cat("===========================================================\n")
  cat("  Setup Complete!\n")
  cat("===========================================================\n")
  cat("  Variables created in global environment:\n")
  cat("    * my.state       =", my.state, "\n")
  cat("    * my.inventory   =", nrow(my.inventory), "potential stations\n")
  cat("    * datafolder     =", datafolder, "\n")
  cat("    * figuresfolder  =", figuresfolder, "\n")
  cat("===========================================================\n")
  cat("  Next step:\n")
  cat("    select_stations_for_analysis(n_stations = 50)\n")
  cat("===========================================================\n\n")
  
  invisible(list(
    state = my.state,
    inventory = my.inventory,
    datafolder = datafolder,
    figuresfolder = figuresfolder,
    paths = dirs
  ))
}

#' Download Station Inventory from NOAA
#' 
#' @return Data frame with station inventory
#' @export
download_station_inventory <- function() {
  
  cat("Downloading inventory from NOAA (this may take a minute)...\n")
  
  # Read inventory
  inventory <- read.table(
    "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-inventory.txt",
    col.names = c("ID", "LATITUDE", "LONGITUDE", "ELEMENT", "FIRSTYEAR", "LASTYEAR")
  )
  
  # Subset for TMAX and active stations
  inventory_TMAX <- subset(inventory, ELEMENT == "TMAX" & LASTYEAR >= 2023)
  
  # Read station metadata
  Stations <- read.fwf(
    "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-stations.txt",
    widths = c(11, -1, 8, -1, 9, -1, 6, -1, 2, -1, 30, -1, 3, -1, 3, -1, 5),
    col.names = c("ID", "LATITUDE", "LONGITUDE", "ELEVATION", "STATE", 
                  "NAME", "GSN_FLAG", "HCN_CRN_FLAG", "WMO_ID"),
    fill = TRUE,
    strip.white = TRUE
  )
  
  # Read state names
  States <- read.fwf(
    "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-states.txt",
    widths = c(2, -1, 46),
    col.names = c("STATE", "STATE_NAME"),
    fill = TRUE,
    strip.white = TRUE
  )
  
  # Get station metadata with state names
  StationMeta <- subset(Stations, select = c("ID", "LATITUDE", "LONGITUDE", 
                                              "ELEVATION", "STATE", "NAME"))
  StationMeta <- merge(StationMeta, States, by = "STATE")
  
  # Merge with inventory to add date ranges
  inventory_merged <- merge(
    subset(inventory_TMAX, select = c("ID", "FIRSTYEAR", "LASTYEAR")),
    StationMeta,
    by = "ID"
  )
  
  # Remove blank states
  inventory_merged <- subset(inventory_merged, STATE != "" & STATE != " ")
  
  # Calculate record length
  inventory_merged$RECORD_LENGTH <- 
    inventory_merged$LASTYEAR - inventory_merged$FIRSTYEAR + 1
  
  return(inventory_merged)
}

#' Select Stations for Analysis with Quality Filters
#' 
#' Enhanced function to select optimal stations for spatial analysis
#' 
#' @param n_stations Number of stations to select (default = 50 for better heat maps)
#' @param min_years Minimum record length in years (default = 50)
#' @param min_last_year Stations must have data through at least this year (default = 2020)
#' @return Filtered inventory data frame
#' @export
select_stations_for_analysis <- function(n_stations = 50, 
                                          min_years = 50,
                                          min_last_year = 2020) {
  
  # Check required variables exist
  if (!exists("my.inventory", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'my.inventory' not found.")
  }
  if (!exists("my.state", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'my.state' not found.")
  }
  if (!exists("datafolder", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'datafolder' not found.")
  }
  
  cat("===========================================================\n")
  cat("  Selecting Stations for Analysis v7.0\n")
  cat("===========================================================\n")
  
  cat("Quality filters:\n")
  cat("  Minimum record length:", min_years, "years\n")
  cat("  Must have data through:", min_last_year, "\n")
  cat("  Target number of stations:", n_stations, "\n\n")
  
  # Filter for quality
  filtered <- my.inventory %>%
    filter(
      RECORD_LENGTH >= min_years,
      LASTYEAR >= min_last_year
    ) %>%
    arrange(desc(RECORD_LENGTH), FIRSTYEAR)
  
  cat("Stations meeting quality criteria:", nrow(filtered), "\n")
  
  # Select top N
  if (nrow(filtered) > n_stations) {
    selected <- filtered[1:n_stations, ]
    cat("Selected top", n_stations, "stations by record length\n")
  } else {
    selected <- filtered
    cat("Using all", nrow(filtered), "available stations\n")
    warning("Fewer stations available than requested. Consider lowering min_years.")
  }
  
  cat("===========================================================\n")
  cat("Selected Station Summary:\n")
  cat("===========================================================\n")
  cat("  Number of stations:", nrow(selected), "\n")
  cat("  Oldest station start:", min(selected$FIRSTYEAR), "\n")
  cat("  Newest station start:", max(selected$FIRSTYEAR), "\n")
  cat("  Average record length:", round(mean(selected$RECORD_LENGTH), 1), "years\n")
  cat("  Median record length:", median(selected$RECORD_LENGTH), "years\n")
  cat("===========================================================\n")
  
  # Save selected inventory
  write.csv(selected, 
            paste0(datafolder, "selected_inventory_", my.state, ".csv"),
            row.names = FALSE)
  
  # Update global environment
  assign("my.inventory", selected, envir = .GlobalEnv)
  
  cat("[OK] Updated my.inventory with", nrow(selected), "selected stations\n")
  cat("[OK] Saved to:", paste0(datafolder, "selected_inventory_", my.state, ".csv\n\n"))
  
  cat("Next step: download_stations()\n\n")
  
  invisible(selected)
}

# =============================================================================
# 2. DATA DOWNLOAD FUNCTIONS
# =============================================================================

#' Download Weather Station Data from NOAA
#' 
#' Downloads and saves both .gz and .csv formats, then cleans up after saving to RData
#' 
#' @param cleanup Remove .gz and .csv files after saving to RData (default = TRUE)
#' @param verbose Show progress messages (default = TRUE)
#' @return Invisible list of successfully downloaded stations
#' @export
download_stations <- function(cleanup = TRUE, verbose = TRUE) {
  
  if (!exists("my.inventory", envir = .GlobalEnv)) {
    stop("Run setup_project() and select_stations_for_analysis() first!")
  }
  if (!exists("datafolder", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'datafolder' not found.")
  }
  
  col_names <- c("ID", "DATE", "ELEMENT", "VALUE", 
                 "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  
  n_stations <- nrow(my.inventory)
  success_count <- 0
  failed_stations <- character(0)
  
  if (verbose) {
    cat("===========================================================\n")
    cat("  Downloading Weather Station Data\n")
    cat("===========================================================\n")
    cat("Stations to download:", n_stations, "\n")
    cat("This may take 10-30 minutes depending on connection...\n\n")
  }
  
  start_time <- Sys.time()
  
  for (i in 1:n_stations) {
    
    station_id <- my.inventory$ID[i]
    
    tryCatch({
      url <- paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/", 
                    station_id, ".csv.gz")
      
      gz_file <- paste0(datafolder, station_id, ".csv.gz")
      csv_file <- paste0(datafolder, station_id, ".csv")
      
      if (verbose) {
        cat(sprintf("[%d/%d] %s ... ", i, n_stations, station_id))
      }
      
      # Download compressed file
      download.file(url, gz_file, quiet = !verbose, mode = "wb")
      
      # Read and save as CSV
      station_data <- read.csv(gz_file, header = FALSE, stringsAsFactors = FALSE)
      names(station_data) <- col_names
      write.csv(station_data, csv_file, row.names = FALSE)
      
      success_count <- success_count + 1
      
      if (verbose) {
        cat(sprintf("OK (%s records)\n", format(nrow(station_data), big.mark = ",")))
      }
      
      Sys.sleep(0.5)  # Be nice to NOAA servers
      
    }, error = function(e) {
      failed_stations <<- c(failed_stations, station_id)
      if (verbose) {
        cat("FAILED:", e$message, "\n")
      }
    })
  }
  
  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  
  if (verbose) {
    cat("===========================================================\n")
    cat("Download Summary:\n")
    cat("===========================================================\n")
    cat("  Successfully downloaded:", success_count, "/", n_stations, "\n")
    cat("  Time elapsed:", round(elapsed, 1), "minutes\n")
    
    if (length(failed_stations) > 0) {
      cat("  Failed stations:", length(failed_stations), "\n")
      cat("  ", paste(failed_stations, collapse = ", "), "\n")
    }
    cat("===========================================================\n")
  }
  
  # Save successful inventory
  successful_inventory <- my.inventory[!my.inventory$ID %in% failed_stations, ]
  write.csv(successful_inventory, 
            paste0(datafolder, "downloaded_inventory.csv"), 
            row.names = FALSE)
  
  if (verbose) {
    cat("[OK] Saved inventory of downloaded stations\n\n")
    
    if (cleanup) {
      cat("Next step: load_and_save_stations() to process and clean up files\n\n")
    } else {
      cat("Next step: load_stations()\n\n")
    }
  }
  
  return(invisible(successful_inventory$ID))
}

# =============================================================================
# 3. DATA LOADING AND PROCESSING FUNCTIONS
# =============================================================================

#' Load Stations and Save to RData with Cleanup
#' 
#' Loads all station CSV files, saves to RData format, then optionally removes
#' .gz and .csv files to save disk space
#' 
#' @param cleanup Remove .gz and .csv files after saving (default = TRUE)
#' @param verbose Show progress messages (default = TRUE)
#' @export
load_and_save_stations <- function(cleanup = TRUE, verbose = TRUE) {
  
  if (!exists("datafolder", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'datafolder' not found.")
  }
  
  inventory_file <- paste0(datafolder, "downloaded_inventory.csv")
  
  if (!file.exists(inventory_file)) {
    stop("No downloaded_inventory.csv found. Run download_stations() first.")
  }
  
  station_inventory <- read.csv(inventory_file, stringsAsFactors = FALSE)
  
  if (verbose) {
    cat("===========================================================\n")
    cat("  Loading and Processing Station Data\n")
    cat("===========================================================\n")
  }
  
  col_names <- c("ID", "DATE", "ELEMENT", "VALUE", 
                 "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  
  loaded_count <- 0
  failed_count <- 0
  station_list <- list()
  files_to_remove <- character(0)
  
  for (i in 1:nrow(station_inventory)) {
    
    station_id <- station_inventory$ID[i]
    csv_file <- paste0(datafolder, station_id, ".csv")
    gz_file <- paste0(datafolder, station_id, ".csv.gz")
    
    if (!file.exists(csv_file)) {
      if (verbose) warning("File not found: ", csv_file)
      failed_count <- failed_count + 1
      next
    }
    
    tryCatch({
      station_data <- read.csv(csv_file, stringsAsFactors = FALSE)
      
      # Store in list
      station_list[[station_id]] <- station_data
      
      # Also assign to global environment
      assign(station_id, station_data, envir = .GlobalEnv)
      
      loaded_count <- loaded_count + 1
      
      # Track files for cleanup
      if (cleanup) {
        if (file.exists(csv_file)) files_to_remove <- c(files_to_remove, csv_file)
        if (file.exists(gz_file)) files_to_remove <- c(files_to_remove, gz_file)
      }
      
      if (verbose) {
        cat(sprintf("[%d/%d] %s (%s records)\n", 
                    i, nrow(station_inventory), station_id, 
                    format(nrow(station_data), big.mark = ",")))
      }
      
    }, error = function(e) {
      warning("Failed to load ", station_id, ": ", e$message)
      failed_count <- failed_count + 1
    })
  }
  
  # Save all stations to RData
  rdata_file <- paste0(datafolder, "all_stations_raw.RData")
  save(station_list, station_inventory, file = rdata_file)
  
  if (verbose) {
    cat("\n[OK] Saved", loaded_count, "stations to:", rdata_file, "\n")
    cat("     File size:", 
        format(file.info(rdata_file)$size / 1024^2, digits = 2), "MB\n")
  }
  
  # Cleanup if requested
  if (cleanup && length(files_to_remove) > 0) {
    if (verbose) {
      cat("\nCleaning up temporary files...\n")
      cat("  Removing", length(files_to_remove), ".csv and .gz files\n")
    }
    
    space_saved <- sum(file.info(files_to_remove)$size, na.rm = TRUE)
    file.remove(files_to_remove)
    
    if (verbose) {
      cat("  Freed up", 
          format(space_saved / 1024^2, digits = 2), "MB of disk space\n")
    }
  }
  
  if (verbose) {
    cat("===========================================================\n")
    cat("Loading Summary:\n")
    cat("===========================================================\n")
    cat("  Successfully loaded:", loaded_count, "stations\n")
    cat("  Failed to load:", failed_count, "stations\n")
    cat("  Saved to RData:", rdata_file, "\n")
    if (cleanup) {
      cat("  Cleaned up temporary files: YES\n")
    } else {
      cat("  Cleaned up temporary files: NO\n")
    }
    cat("===========================================================\n")
    
    cat("Next step: process_all_stations()\n\n")
  }
  
  invisible(station_inventory$ID)
}

#' Load Previously Saved Station Data
#' 
#' @param verbose Show progress (default = TRUE)
#' @export
load_stations <- function(verbose = TRUE) {
  
  if (!exists("datafolder", envir = .GlobalEnv)) {
    stop("Run setup_project() first! Variable 'datafolder' not found.")
  }
  
  rdata_file <- paste0(datafolder, "all_stations_raw.RData")
  
  if (!file.exists(rdata_file)) {
    stop("RData file not found. Run load_and_save_stations() first.")
  }
  
  load(rdata_file, envir = .GlobalEnv)
  
  # Also assign individual stations to global environment
  for (station_id in names(station_list)) {
    assign(station_id, station_list[[station_id]], envir = .GlobalEnv)
  }
  
  if (verbose) {
    cat("[OK] Loaded", length(station_list), "stations from", rdata_file, "\n")
  }
  
  invisible(names(station_list))
}

# =============================================================================
# 4. DATA CLEANING FUNCTIONS
# =============================================================================

#' Fix Date Formats
#' 
#' Converts NOAA's integer date format (YYYYMMDD) to proper R Date objects
#' and extracts MONTH and YEAR columns for aggregation.
#' 
#' @param station Data frame with station data containing DATE column
#' @return Data frame with Ymd (Date), MONTH, and YEAR columns added
#' @export
#' @examples
#' # Example: Convert date 20230715 to Date "2023-07-15"
#' # station$Ymd <- as.Date("20230715", format = "%Y%m%d")
fixDates.fun <- function(station) {
  # Convert integer date to character, then to Date object
  station$Ymd <- as.Date(as.character(station$DATE), format = "%Y%m%d")
  
  # Extract month (1-12) and year (e.g., 2023)
  station$MONTH <- as.numeric(format(station$Ymd, "%m"))
  station$YEAR <- as.numeric(format(station$Ymd, "%Y"))
  
  return(station)
}

#' Convert NOAA Value Units
#' 
#' NOAA stores values in scaled units to save space:
#' - Temperature (TMAX, TMIN): tenths of degrees Celsius
#' - Precipitation (PRCP): tenths of millimeters
#' - Snow (SNOW, SNWD): millimeters
#' 
#' This function converts to standard units.
#' 
#' @param station Data frame with station data
#' @return Data frame with converted values
#' @export
#' @examples
#' # Temperature: 235 (tenths of C) -> 23.5 C
#' # Precipitation: 50 (tenths of mm) -> 5.0 mm
fixValues.fun <- function(station) {
  # TMAX and TMIN: tenths of degrees C -> degrees C
  temp_idx <- station$ELEMENT %in% c("TMAX", "TMIN")
  station$VALUE[temp_idx] <- station$VALUE[temp_idx] / 10
  
  # PRCP: tenths of mm -> mm
  prcp_idx <- station$ELEMENT == "PRCP"
  station$VALUE[prcp_idx] <- station$VALUE[prcp_idx] / 10
  
  # SNOW and SNWD: mm -> cm
  snow_idx <- station$ELEMENT %in% c("SNOW", "SNWD")
  station$VALUE[snow_idx] <- station$VALUE[snow_idx] / 10
  
  return(station)
}

#' Calculate Data Coverage
#' 
#' Calculates the percentage of days with valid observations
#' over the station's entire record.
#' 
#' @param station Data frame with station data (after fixDates.fun)
#' @param element Element to check coverage for (default: "TMAX")
#' @return Coverage percentage (0-100)
#' @export
coverage.fun <- function(station, element = "TMAX") {
  if (!"Ymd" %in% names(station)) {
    stop("Run fixDates.fun() first")
  }
  
  # Create complete date sequence
  Dates.all <- data.frame(Ymd = seq.Date(
    from = min(station$Ymd, na.rm = TRUE),
    to = max(station$Ymd, na.rm = TRUE),
    by = "day"
  ))
  
  # Merge to find gaps
  station.full <- merge(Dates.all, station, all = TRUE)
  
  # Calculate coverage percentage
  coverage <- sum(!is.na(station.full$VALUE[station.full$ELEMENT == element])) /
    length(station.full$VALUE[station.full$ELEMENT == element]) * 100
  
  return(round(coverage, 2))
}

# =============================================================================
# 5. MONTHLY AGGREGATION FUNCTIONS
# =============================================================================

#' Calculate Monthly Values
#' 
#' Aggregates daily data to monthly means (for temperature)
#' or monthly totals (for precipitation).
#' 
#' @param station Data frame with cleaned station data
#' @return List with TMAX, TMIN, PRCP monthly data frames
#' @export
MonthlyValues.fun <- function(station) {
  
  # TMAX: monthly mean of daily maximum temperatures
  TMAX.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "TMAX"),
                            mean, na.rm = TRUE)
  names(TMAX.monthly) <- c("MONTH", "YEAR", "TMAX")
  
  # TMIN: monthly mean of daily minimum temperatures
  TMIN.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "TMIN"),
                            mean, na.rm = TRUE)
  names(TMIN.monthly) <- c("MONTH", "YEAR", "TMIN")
  
  # PRCP: monthly total precipitation
  PRCP.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "PRCP"),
                            sum, na.rm = TRUE)
  names(PRCP.monthly) <- c("MONTH", "YEAR", "PRCP")
  
  return(list(TMAX = TMAX.monthly, TMIN = TMIN.monthly, PRCP = PRCP.monthly))
}

#' Calculate Climate Normals (1961-1990)
#' 
#' Calculates the 30-year climate normal baseline (1961-1990)
#' used as a reference for anomaly calculations.
#' 
#' @param station Data frame with cleaned station data
#' @return List with TMAX, TMIN, PRCP normals
#' @export
MonthlyNormals.fun <- function(station) {
  
  # Subset to the standard normal period
  station.normals <- subset(station, 
                            Ymd >= as.Date("1961-01-01") & 
                              Ymd <= as.Date("1990-12-31"))
  
  if (nrow(station.normals) == 0) {
    warning("No data in 1961-1990 period. Using all available data.")
    station.normals <- station
  }
  
  # Temperature normals: mean of monthly means
  TMAX.normals <- aggregate(VALUE ~ MONTH,
                            data = subset(station.normals, ELEMENT == "TMAX"),
                            mean, na.rm = TRUE)
  names(TMAX.normals) <- c("MONTH", "NORMALS")
  
  TMIN.normals <- aggregate(VALUE ~ MONTH,
                            data = subset(station.normals, ELEMENT == "TMIN"),
                            mean, na.rm = TRUE)
  names(TMIN.normals) <- c("MONTH", "NORMALS")
  
  # Precipitation normals: mean of monthly totals
  PRCP.month.year <- aggregate(VALUE ~ MONTH + YEAR,
                               data = subset(station.normals, ELEMENT == "PRCP"),
                               sum, na.rm = TRUE)
  PRCP.normals <- aggregate(VALUE ~ MONTH, 
                            data = PRCP.month.year, 
                            mean, na.rm = TRUE)
  names(PRCP.normals) <- c("MONTH", "NORMALS")
  
  return(list(TMAX = TMAX.normals, TMIN = TMIN.normals, PRCP = PRCP.normals))
}

#' Calculate Monthly Anomalies
#' 
#' Anomaly = Observed value - Climate normal
#' Positive anomaly = warmer/wetter than normal
#' Negative anomaly = cooler/drier than normal
#' 
#' @param station.monthly Output from MonthlyValues.fun
#' @param station.normals Output from MonthlyNormals.fun
#' @return List with TMAX, TMIN, PRCP anomalies
#' @export
MonthlyAnomalies.fun <- function(station.monthly, station.normals) {
  
  # Merge monthly values with normals by month
  TMAX <- merge(station.monthly$TMAX, station.normals$TMAX, by = "MONTH")
  TMAX$TMAX.a <- TMAX$TMAX - TMAX$NORMALS
  TMAX$Ymd <- as.Date(paste(TMAX$YEAR, TMAX$MONTH, "01", sep = "-"))
  
  TMIN <- merge(station.monthly$TMIN, station.normals$TMIN, by = "MONTH")
  TMIN$TMIN.a <- TMIN$TMIN - TMIN$NORMALS
  TMIN$Ymd <- as.Date(paste(TMIN$YEAR, TMIN$MONTH, "01", sep = "-"))
  
  PRCP <- merge(station.monthly$PRCP, station.normals$PRCP, by = "MONTH")
  PRCP$PRCP.a <- PRCP$PRCP - PRCP$NORMALS
  PRCP$Ymd <- as.Date(paste(PRCP$YEAR, PRCP$MONTH, "01", sep = "-"))
  
  return(list(TMAX = TMAX, TMIN = TMIN, PRCP = PRCP))
}

# =============================================================================
# 6. TREND ANALYSIS FUNCTIONS
# =============================================================================

#' Calculate Monthly Trends
#' 
#' Fits linear regression to monthly anomalies over time.
#' Reports slope (trend), standard error, t-value, p-value, and R-squared.
#' 
#' @param station.anomalies Output from MonthlyAnomalies.fun
#' @return Data frame with trend statistics for each month and element
#' @export
monthlyTrend.fun <- function(station.anomalies) {
  
  results <- data.frame()
  
  for (element in c("TMAX", "TMIN", "PRCP")) {
    data <- station.anomalies[[element]]
    anom_col <- paste0(element, ".a")
    
    for (m in 1:12) {
      month_data <- subset(data, MONTH == m)
      
      # Need at least 10 years for meaningful trend
      if (nrow(month_data) >= 10) {
        formula <- as.formula(paste(anom_col, "~ YEAR"))
        model <- lm(formula, data = month_data)
        s <- summary(model)
        
        results <- rbind(results, data.frame(
          MONTH = m,
          ELEMENT = element,
          Estimate = coef(model)[2],        # Slope (change per year)
          Std.Error = s$coefficients[2, 2],
          t.value = s$coefficients[2, 3],
          `Pr(>|t|)` = s$coefficients[2, 4],
          r.squared = s$r.squared,
          check.names = FALSE
        ))
      }
    }
  }
  
  # Add significance stars
  results$Signif <- ""
  results$Signif[results$`Pr(>|t|)` < 0.05] <- "*"
  results$Signif[results$`Pr(>|t|)` < 0.01] <- "**"
  results$Signif[results$`Pr(>|t|)` < 0.001] <- "***"
  
  return(results)
}

# =============================================================================
# 7. BATCH PROCESSING FOR SPATIAL ANALYSIS
# =============================================================================

#' Process All Stations for Spatial Analysis
#' 
#' Processes all stations and calculates annual and seasonal trends
#' 
#' @param verbose Show progress (default = TRUE)
#' @return Data frame with spatial trend data
#' @export
process_all_stations_for_spatial <- function(verbose = TRUE) {
  
  # Check if data exists, if not try to load it
  if (!exists("station_list", envir = .GlobalEnv) || 
      !exists("station_inventory", envir = .GlobalEnv)) {
    
    # Try to load from RData file
    if (!exists("datafolder", envir = .GlobalEnv)) {
      stop("Run setup_project() first to set up datafolder variable!")
    }
    
    rdata_file <- paste0(datafolder, "all_stations_raw.RData")
    
    if (file.exists(rdata_file)) {
      if (verbose) {
        cat("Loading station data from RData file...\n")
      }
      load(rdata_file, envir = .GlobalEnv)
    } else {
      stop("Station data not found!\n",
           "  Expected file: ", rdata_file, "\n",
           "  Run load_and_save_stations() first!")
    }
  }
  
  all_trends <- data.frame()
  start_time <- Sys.time()
  
  if (verbose) {
    cat("===========================================================\n")
    cat("  Processing All Stations for Spatial Analysis\n")
    cat("===========================================================\n")
    cat("Processing", length(station_list), "stations...\n\n")
  }
  
  for (i in 1:length(station_list)) {
    
    station_id <- names(station_list)[i]
    
    if (verbose) {
      cat(sprintf("[%d/%d] %s ... ", i, length(station_list), station_id))
    }
    
    tryCatch({
      
      # Process station
      station <- station_list[[station_id]]
      station_a <- fixDates.fun(station)
      station_b <- fixValues.fun(station_a)
      
      # Calculate anomalies
      station_monthly <- MonthlyValues.fun(station_b)
      station_normals <- MonthlyNormals.fun(station_b)
      station_anomalies <- MonthlyAnomalies.fun(station_monthly, station_normals)
      
      # Calculate trends
      monthly_trends <- monthlyTrend.fun(station_anomalies)
      
      # Calculate annual trends (mean across all months)
      annual_trends <- monthly_trends %>%
        group_by(ELEMENT) %>%
        summarise(
          annual_estimate = mean(Estimate, na.rm = TRUE),
          annual_pvalue = mean(`Pr(>|t|)`, na.rm = TRUE),
          annual_r2 = mean(r.squared, na.rm = TRUE),
          .groups = "drop"
        )
      
      # Calculate seasonal trends
      winter_trends <- monthly_trends %>%
        filter(MONTH %in% c(12, 1, 2)) %>%
        group_by(ELEMENT) %>%
        summarise(winter_estimate = mean(Estimate, na.rm = TRUE),
                  winter_pvalue = mean(`Pr(>|t|)`, na.rm = TRUE),
                  .groups = "drop")
      
      spring_trends <- monthly_trends %>%
        filter(MONTH %in% c(3, 4, 5)) %>%
        group_by(ELEMENT) %>%
        summarise(spring_estimate = mean(Estimate, na.rm = TRUE),
                  spring_pvalue = mean(`Pr(>|t|)`, na.rm = TRUE),
                  .groups = "drop")
      
      summer_trends <- monthly_trends %>%
        filter(MONTH %in% c(6, 7, 8)) %>%
        group_by(ELEMENT) %>%
        summarise(summer_estimate = mean(Estimate, na.rm = TRUE),
                  summer_pvalue = mean(`Pr(>|t|)`, na.rm = TRUE),
                  .groups = "drop")
      
      fall_trends <- monthly_trends %>%
        filter(MONTH %in% c(9, 10, 11)) %>%
        group_by(ELEMENT) %>%
        summarise(fall_estimate = mean(Estimate, na.rm = TRUE),
                  fall_pvalue = mean(`Pr(>|t|)`, na.rm = TRUE),
                  .groups = "drop")
      
      # Combine trends
      combined <- annual_trends %>%
        left_join(winter_trends, by = "ELEMENT") %>%
        left_join(spring_trends, by = "ELEMENT") %>%
        left_join(summer_trends, by = "ELEMENT") %>%
        left_join(fall_trends, by = "ELEMENT")
      
      # Convert to per-century trends
      trend_cols <- grep("_estimate", names(combined), value = TRUE)
      for (col in trend_cols) {
        new_col <- gsub("_estimate", "_trend", col)
        combined[[new_col]] <- combined[[col]] * 100  # per-year to per-century
      }
      
      # Add metadata
      inv_row <- station_inventory[station_inventory$ID == station_id, ]
      combined$ID <- station_id
      combined$LATITUDE <- inv_row$LATITUDE
      combined$LONGITUDE <- inv_row$LONGITUDE
      
      # Add ELEVATION if it exists in inventory
      if ("ELEVATION" %in% names(station_inventory)) {
        combined$ELEVATION <- inv_row$ELEVATION
      } else {
        combined$ELEVATION <- NA
      }
      
      combined$STATE <- inv_row$STATE
      
      # Reshape to wide
      station_wide <- combined %>%
        pivot_wider(
          names_from = ELEMENT,
          values_from = -c(ELEMENT, ID, LATITUDE, LONGITUDE, ELEVATION, STATE),
          names_sep = "_"
        )
      
      all_trends <- bind_rows(all_trends, station_wide)
      
      if (verbose) cat("OK\n")
      
    }, error = function(e) {
      if (verbose) cat("ERROR:", conditionMessage(e), "\n")
    })
  }
  
  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  
  if (verbose) {
    cat("===========================================================\n")
    cat("Processing Summary:\n")
    cat("===========================================================\n")
    cat("  Successfully processed:", nrow(all_trends), "stations\n")
    cat("  Time elapsed:", round(elapsed, 1), "minutes\n")
    cat("===========================================================\n")
  }
  
  # Save results
  write.csv(all_trends, 
            paste0(datafolder, "spatial_trends_", my.state, ".csv"),
            row.names = FALSE)
  
  # Save with consistent variable name
  all_station_trends <- all_trends
  save(all_station_trends, 
       file = paste0(datafolder, "spatial_trends_", my.state, ".RData"))
  
  if (verbose) {
    cat("[OK] Saved spatial trends data\n\n")
  }
  
  # Assign to global environment
  assign("all_station_trends", all_trends, envir = .GlobalEnv)
  
  return(all_trends)
}

# =============================================================================
# 8. SPATIAL VISUALIZATION FUNCTIONS
# =============================================================================

#' Create Spatial Objects from Trend Data
#' @param trends_df Data frame with trend data and coordinates
#' @return List with sf and sp objects
#' @export
create_spatial_objects <- function(trends_df) {
  
  # Create sf object
  trends_sf <- st_as_sf(
    trends_df,
    coords = c("LONGITUDE", "LATITUDE"),
    crs = 4326,
    remove = FALSE
  )
  
  # Create sp object (for gstat)
  trends_sp <- as(trends_sf, "Spatial")
  
  # Assign to global environment
  assign("trends_sf", trends_sf, envir = .GlobalEnv)
  assign("trends_sp", trends_sp, envir = .GlobalEnv)
  
  cat("[OK] Created spatial objects:\n")
  cat("     trends_sf:", nrow(trends_sf), "features\n")
  cat("     trends_sp:", length(trends_sp), "features\n\n")
  
  invisible(list(sf = trends_sf, sp = trends_sp))
}

#' Create Heat Map with Kriging Interpolation
#' @param trends_sp Spatial points object
#' @param trend_var Variable to map
#' @param title Plot title
#' @param subtitle Plot subtitle
#' @param state State abbreviation
#' @param colors Color scheme ("temp" or "precip")
#' @param resolution Grid resolution in degrees (default = 0.1)
#' @return ggplot object
#' @export
create_heatmap <- function(trends_sp, 
                           trend_var,
                           title,
                           subtitle = "",
                           state,
                           colors = "temp",
                           resolution = 0.1) {
  
  # Create interpolation grid
  bbox <- st_bbox(st_as_sf(trends_sp))
  x_range <- c(bbox["xmin"] - 0.2, bbox["xmax"] + 0.2)
  y_range <- c(bbox["ymin"] - 0.2, bbox["ymax"] + 0.2)
  
  grid_x <- seq(x_range[1], x_range[2], by = resolution)
  grid_y <- seq(y_range[1], y_range[2], by = resolution)
  
  grid_df <- expand.grid(x = grid_x, y = grid_y)
  coordinates(grid_df) <- ~x + y
  proj4string(grid_df) <- CRS("+proj=longlat +datum=WGS84")
  gridded(grid_df) <- TRUE
  
  # Perform kriging
  cat("Fitting variogram for", trend_var, "...\n")
  formula_str <- as.formula(paste(trend_var, "~ 1"))
  v <- variogram(formula_str, trends_sp)
  v.fit <- fit.variogram(v, vgm(c("Sph", "Exp", "Gau")))
  
  cat("Performing kriging interpolation...\n")
  kriged <- krige(formula_str, trends_sp, grid_df, model = v.fit)
  
  kriged_df <- as.data.frame(kriged)
  names(kriged_df)[1:2] <- c("x", "y")
  names(kriged_df)[3] <- "prediction"
  
  # Get state boundary
  us_states <- map_data("state")
  state_name <- tolower(state.name[state.abb == state])
  state_boundary <- us_states %>% filter(region == state_name)
  
  # Color scale
  if (colors == "temp") {
    color_scale <- scale_fill_gradient2(
      low = "blue", mid = "white", high = "red",
      midpoint = 0, name = "Trend"
    )
  } else {
    color_scale <- scale_fill_gradient2(
      low = "brown", mid = "white", high = "darkgreen",
      midpoint = 0, name = "Trend"
    )
  }
  
  # Create plot
  p <- ggplot() +
    geom_raster(data = kriged_df, aes(x = x, y = y, fill = prediction), 
                alpha = 0.8) +
    color_scale +
    geom_polygon(data = state_boundary, 
                 aes(x = long, y = lat, group = group),
                 fill = NA, color = "black", linewidth = 1) +
    geom_point(data = as.data.frame(trends_sp),
               aes(x = LONGITUDE, y = LATITUDE),
               color = "black", size = 2, shape = 21, 
               fill = "white", stroke = 0.5) +
    coord_fixed(ratio = 1) +
    labs(title = title, subtitle = subtitle,
         x = "Longitude", y = "Latitude",
         caption = paste("Based on", length(trends_sp), 
                         "weather stations | Interpolation: Ordinary kriging")) +
    theme_minimal() +
    theme(plot.title = element_text(size = 14, face = "bold"),
          plot.subtitle = element_text(size = 11),
          legend.position = "right")
  
  return(p)
}

# =============================================================================
# STARTUP MESSAGE
# =============================================================================

cat("\n")
cat("===========================================================\n")
cat(" Climate Narratives Functions v7.0 Loaded Successfully!\n")
cat("===========================================================\n")
cat(" Run check_packages() to verify dependencies\n")
cat("===========================================================\n")
cat("\n")
cat(" QUICK START:\n")
cat(" 1. setup_project('CA')\n")
cat(" 2. select_stations_for_analysis(n_stations = 50)\n")
cat(" 3. download_stations()\n")
cat(" 4. load_and_save_stations(cleanup = TRUE)\n")
cat(" 5. process_all_stations_for_spatial()\n")
cat(" 6. create_spatial_objects(all_station_trends)\n")
cat("\n")
cat(" NEW IN v7.0:\n")
cat(" - Fixed figuresfolder variable handling\n")
cat(" - Improved error messages\n")
cat(" - Better documentation for teaching\n")
cat("\n")
cat("===========================================================\n")
cat("\n")
