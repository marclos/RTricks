# =============================================================================
# ClimateNarratives - Complete Example Workflow
# =============================================================================
# This script demonstrates a complete climate analysis workflow using the
# ClimateNarratives package, from setup through visualization.
#
# >>> ONLY ONE LINE TO EDIT: change my_state below to YOUR state code <<<
#
# Time required: 30-60 minutes (mostly download time)
# Disk space: ~100-500 MB per state
# =============================================================================

# =============================================================================
# STEP 1: LOAD PACKAGE
# =============================================================================

library(ClimateNarratives)

# Check that package loaded successfully
cat("ClimateNarratives package loaded!\n")

# =============================================================================
# STEP 2: INITIALIZE PROJECT
# =============================================================================

# +-------------------------------------------------------------------+
# |  EDIT THIS LINE: change "CA" to your state abbreviation           |
# |  Examples: "TX", "NY", "FL", "OR", "RI", etc.                    |
# +-------------------------------------------------------------------+
my_state <- "CA"

# Initialize project -- this auto-creates ~/ClimateNarratives_CA/
# (or _TX, _NY, etc.) with Data/, Output/, and Figures/ subfolders.
# It also sets your working directory, so ggsave() just works.
cat("\n=== Initializing Project ===\n")
initialize_project(my_state)

# After this call the following are ready to use:
#   my.state       - your state code
#   my.inventory   - station data frame
#   datafolder     - "Data/"       (relative -- works because wd is set)
#   figuresfolder  - "Figures/"    (relative -- works because wd is set)

# =============================================================================
# STEP 3: SELECT HIGH-QUALITY STATIONS
# =============================================================================

cat("\n=== Selecting Weather Stations ===\n")

# Select 50 stations with good data quality
# Adjust n_stations, min_years, or min_last_year if needed
select_stations(
  n = 50,              # Number of stations to select
  min_years = 50,      # Minimum years of data required
  min_last_year = 2020 # Must have data through this year
)

# This updates my.inventory with selected stations
cat("Selected", nrow(my.inventory), "stations for analysis\n")

# =============================================================================
# STEP 4: DOWNLOAD DATA FROM NOAA
# =============================================================================

cat("\n=== Downloading Data ===\n")
cat("This step takes 10-30 minutes...\n")
cat("Download will resume if interrupted\n\n")

# Download station data from NOAA
download_stations()

# Note: If download fails partway through, just run download_stations() again
# It will skip already-downloaded stations

# =============================================================================
# STEP 5: PROCESS AND SAVE DATA
# =============================================================================

cat("\n=== Processing Downloaded Data ===\n")

# Load CSV files and save as RData (much faster to load later)
# cleanup = TRUE removes temporary CSV files to save disk space
load_and_save_stations(cleanup = TRUE)

# Data is now saved in: Data/all_stations_raw.RData

# =============================================================================
# STEP 6: CALCULATE CLIMATE TRENDS
# =============================================================================

cat("\n=== Analyzing Climate Trends ===\n")

# This step processes all stations to calculate:
# - Monthly anomalies (deviation from 1961-1990 normal)
# - Annual trends
# - Seasonal trends (winter, spring, summer, fall)
# - For TMAX, TMIN, and PRCP
#
# NOTE: Some stations may lack data in the 1961-1990 normals period.
#       The package automatically falls back to alternative periods
#       (1971-2000, 1981-2010, or full record) and tells you which
#       stations were affected. Stations with truly inadequate data
#       are skipped with a warning -- this is expected behavior.

trends <- process_all_stations()

# View summary
cat("\nTrend Summary:\n")
cat("Stations with valid trends:", nrow(trends), "\n")
cat("Mean annual TMAX trend:",
    round(mean(trends$annual_trend_TMAX, na.rm = TRUE), 2), "\u00b0C/century\n")
cat("Mean annual TMIN trend:",
    round(mean(trends$annual_trend_TMIN, na.rm = TRUE), 2), "\u00b0C/century\n")
cat("Mean annual PRCP trend:",
    round(mean(trends$annual_trend_PRCP, na.rm = TRUE), 1), "mm/century\n")

# =============================================================================
# STEP 7: CREATE SPATIAL OBJECTS
# =============================================================================

cat("\n=== Creating Spatial Objects ===\n")

# Convert trend data to spatial format for mapping
spatial_objects <- create_spatial_objects(trends)

# This creates two objects:
# - trends_sf (Simple Features format - modern)
# - trends_sp (Spatial Points format - for kriging)

# =============================================================================
# STEP 8: CREATE HEAT MAPS
# =============================================================================

cat("\n=== Generating Heat Maps ===\n")

# NOTE: ggsave paths like "Figures/..." work because initialize_project()
#       set the working directory to your project folder.

# Annual Maximum Temperature Trend
cat("Creating TMAX heat map...\n")
map_tmax <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMAX",
  title = paste(my.state, "- Annual Maximum Temperature Trend"),
  subtitle = "Change in \u00b0C per 100 years",
  state = my.state,
  colors = "temp"
)

ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map_tmax, width = 10, height = 8, dpi = 300)

# Annual Minimum Temperature Trend
cat("Creating TMIN heat map...\n")
map_tmin <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMIN",
  title = paste(my.state, "- Annual Minimum Temperature Trend"),
  subtitle = "Change in \u00b0C per 100 years",
  state = my.state,
  colors = "temp"
)

ggsave(paste0(figuresfolder, "TMIN_annual_", my.state, ".png"),
       map_tmin, width = 10, height = 8, dpi = 300)

# Annual Precipitation Trend
cat("Creating precipitation heat map...\n")
map_prcp <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_PRCP",
  title = paste(my.state, "- Annual Precipitation Trend"),
  subtitle = "Change in mm per 100 years",
  state = my.state,
  colors = "precip"  # Different color scheme for precipitation
)

ggsave(paste0(figuresfolder, "PRCP_annual_", my.state, ".png"),
       map_prcp, width = 10, height = 8, dpi = 300)

# =============================================================================
# STEP 9: CREATE SEASONAL COMPARISON
# =============================================================================

cat("\n=== Creating Seasonal Comparison ===\n")

library(patchwork)

# Create seasonal maps (simplified for panel layout)
winter_map <- create_heatmap(trends_sp, "winter_trend_TMAX",
                             "Winter (Dec-Feb)", state = my.state,
                             resolution = 0.15) +
  theme(legend.position = "none")

spring_map <- create_heatmap(trends_sp, "spring_trend_TMAX",
                             "Spring (Mar-May)", state = my.state,
                             resolution = 0.15) +
  theme(legend.position = "none")

summer_map <- create_heatmap(trends_sp, "summer_trend_TMAX",
                             "Summer (Jun-Aug)", state = my.state,
                             resolution = 0.15) +
  theme(legend.position = "right")

fall_map <- create_heatmap(trends_sp, "fall_trend_TMAX",
                           "Fall (Sep-Nov)", state = my.state,
                           resolution = 0.15) +
  theme(legend.position = "none")

# Combine into 2x2 panel
seasonal_panel <- (winter_map | spring_map) / (summer_map | fall_map) +
  plot_annotation(
    title = paste("Seasonal TMAX Trends -", my.state),
    subtitle = "Change in \u00b0C per 100 years by season"
  )

# Save
ggsave(paste0(figuresfolder, "Seasonal_TMAX_", my.state, ".png"),
       seasonal_panel, width = 12, height = 10, dpi = 300)

# =============================================================================
# STEP 10: SUMMARY AND NEXT STEPS
# =============================================================================

cat("\n")
cat("===========================================================\n")
cat("  ANALYSIS COMPLETE!\n")
cat("===========================================================\n")
cat("State:", my.state, "\n")
cat("Stations analyzed:", nrow(trends), "\n")
cat("\nFiles created in:", figuresfolder, "\n")
cat("  - TMAX_annual_", my.state, ".png\n", sep = "")
cat("  - TMIN_annual_", my.state, ".png\n", sep = "")
cat("  - PRCP_annual_", my.state, ".png\n", sep = "")
cat("  - Seasonal_TMAX_", my.state, ".png\n", sep = "")
cat("\nData saved in:", datafolder, "\n")
cat("  - all_stations_raw.RData\n")
cat("  - spatial_trends_", my.state, ".RData\n", sep = "")
cat("===========================================================\n")
cat("\nFull path to your project:\n")
cat("  ", getwd(), "\n")
cat("===========================================================\n")
cat("\nNEXT STEPS:\n")
cat("1. View heat maps in Figures/ folder\n")
cat("2. Explore seasonal patterns\n")
cat("3. Compare TMAX vs TMIN warming\n")
cat("4. Analyze regional differences\n")
cat("5. Create visualizations for your narrative video\n")
cat("===========================================================\n\n")

# =============================================================================
# ADDITIONAL ANALYSIS IDEAS
# =============================================================================

# Uncomment to explore further:

# # View trend statistics
# summary(trends$annual_trend_TMAX)
# hist(trends$annual_trend_TMAX, main = "Distribution of TMAX Trends")
#
# # Compare daytime vs nighttime warming
# plot(annual_trend_TMIN ~ annual_trend_TMAX, data = trends,
#      main = "Daytime vs Nighttime Warming",
#      xlab = "TMAX Trend (\u00b0C/century)",
#      ylab = "TMIN Trend (\u00b0C/century)")
# abline(0, 1, lty = 2)
#
# # Examine elevation effects
# if ("ELEVATION" %in% names(trends)) {
#   plot(annual_trend_TMAX ~ ELEVATION, data = trends,
#        main = "Temperature Trend vs Elevation")
# }
#
# # Regional breakdown
# trends$region <- cut(trends$LATITUDE, breaks = 3,
#                      labels = c("South", "Central", "North"))
# aggregate(annual_trend_TMAX ~ region, data = trends, mean)

cat("Workflow complete! Happy analyzing!\n\n")
