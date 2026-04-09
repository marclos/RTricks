# =============================================================================
# EPA_25_functions.R
#
# Helper functions for the Environmental Justice & Pi (EJnPi) course module.
# Source this file directly from GitHub in your Rmd setup chunk:
#
#   source("https://raw.githubusercontent.com/marclos/RTrics/master/docs/EPA_25d_functions.R")
#
# Functions defined here:
#   prepare_epa_pm25(raw)                         -- clean raw AQS CSV columns
#   get_epa_pm25(state_fips, county_fips,         -- download + cache EPA data
#                start_year, end_year, cache_dir)
#
# Last updated: 2026-03
# Author: Marc Los Huertos
# =============================================================================


# -----------------------------------------------------------------------------
# prepare_epa_pm25(raw)
#
# Selects and renames the columns students work with from a raw AQS bulk CSV
# dataframe. Builds the standard SS-CCC-NNNN site identifier, parses the date
# string, and drops rows with missing AQI.
#
# Argument:
#   raw  -- a dataframe read directly from an EPA AQS bulk CSV
#
# Returns a dataframe with columns:
#   Site.ID         character  "SS-CCC-NNNN" station identifier
#   Site.Name       character  local station name
#   Date            Date       calendar date of observation
#   PM2.5.AQI.Value numeric    daily AQI value
#   PM2.5.Conc      numeric    daily mean concentration (ug/m3)
# -----------------------------------------------------------------------------
prepare_epa_pm25 <- function(raw) {
  out <- data.frame(
    Site.ID         = paste0(formatC(raw$State.Code,  width = 2, flag = "0"), "-",
                             formatC(raw$County.Code, width = 3, flag = "0"), "-",
                             formatC(raw$Site.Num,    width = 4, flag = "0")),
    Site.Name       = raw$Local.Site.Name,
    Date            = as.Date(raw$Date.Local),
    PM2.5.AQI.Value = raw$AQI,
    PM2.5.Conc      = raw$Arithmetic.Mean,
    stringsAsFactors = FALSE
  )
  out[!is.na(out$PM2.5.AQI.Value), ]
}


# -----------------------------------------------------------------------------
# get_epa_pm25(state_fips, county_fips, start_year, end_year, cache_dir)
#
# Downloads annual EPA AQS bulk PM2.5 files (parameter code 88101), filters
# to one county, and calls prepare_epa_pm25() to return analysis-ready data.
# Saves a local .rds cache so repeated knits skip the download entirely.
#
# Arguments:
#   state_fips  -- 2-digit state FIPS code as character string, e.g. "06"
#                  (must be quoted to preserve any leading zero)
#   county_fips -- 3-digit county FIPS code as character string, e.g. "071"
#   start_year  -- first calendar year to download (integer)
#   end_year    -- last calendar year to download (integer)
#   cache_dir   -- path to folder for the .rds cache file; created if absent
#                  default: "data"
#
# Returns:
#   A dataframe produced by prepare_epa_pm25() with columns:
#   Site.ID, Site.Name, Date, PM2.5.AQI.Value, PM2.5.Conc
#
# Notes:
#   - First run downloads ~50 MB per year; allow 10-20 min for 30 years.
#   - Cache is named <state_fips><county_fips>_PM25_daily.rds so different
#     counties never collide.
#   - If a single year's download fails (server timeout, missing file), that
#     year is skipped with a message and the rest continue.
# -----------------------------------------------------------------------------
get_epa_pm25 <- function(state_fips, county_fips,
                          start_year, end_year,
                          cache_dir = "data") {

  cache_file <- file.path(cache_dir,
                          paste0(state_fips, county_fips, "_PM25_daily.rds"))

  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

  # Return cached data immediately if it exists
  if (file.exists(cache_file)) {
    message("Loading cached data: ", cache_file)
    return(readRDS(cache_file))
  }

  # Download one year at a time
  base_url <- "https://aqs.epa.gov/aqsweb/airdata/daily_88101_%d.zip"
  years    <- seq(start_year, end_year)
  raw_list <- vector("list", length(years))

  for (i in seq_along(years)) {
    yr  <- years[i]
    tmp <- tempfile(fileext = ".zip")
    message("Downloading ", yr, "  (", i, " of ", length(years), ")")

    tryCatch({
      download.file(sprintf(base_url, yr), tmp, quiet = TRUE, mode = "wb")
      csv_path      <- unzip(tmp, exdir = tempdir())
      df            <- read.csv(csv_path[1], stringsAsFactors = FALSE)
      df            <- df[df$State.Code  == as.integer(state_fips) &
                          df$County.Code == as.integer(county_fips), ]
      raw_list[[i]] <- df
      unlink(tmp); unlink(csv_path)
    }, error = function(e) {
      message("  Skipping ", yr, ": ", conditionMessage(e))
    })
  }

  raw <- do.call(rbind, Filter(Negate(is.null), raw_list))
  out <- prepare_epa_pm25(raw)

  saveRDS(out, cache_file)
  message("Saved to: ", cache_file)
  out
}
