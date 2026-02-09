# ClimateNarratives - Complete Student Workflow Guide

**A Step-by-Step Tutorial for Climate Data Analysis in R**

---

## 📚 Overview

This guide walks you through a complete climate analysis workflow using the ClimateNarratives package. You'll learn:

- How to download and process real climate data from NOAA
- How to calculate climate trends and statistics
- How to create professional visualizations
- What each R function does behind the scenes
- How to track your progress using output folders

**Time Required:** 2-4 hours (mostly computer processing time)  
**Disk Space:** 100-500 MB per state  
**Prerequisites:** Basic R knowledge (variables, functions, data frames)

---

## 📖 Table of Contents

1. [Setup and Installation](#step-0-setup-and-installation)
2. [Initialize Project](#step-1-initialize-project)
3. [Select Weather Stations](#step-2-select-weather-stations)
4. [Download Data](#step-3-download-data)
5. [Process and Save Data](#step-4-process-and-save-data)
6. [Calculate Climate Trends](#step-5-calculate-climate-trends)
7. [Create Spatial Objects](#step-6-create-spatial-objects)
8. [Assess Station Coverage](#step-7-assess-station-coverage)
9. [Create Visualizations](#step-8-create-visualizations)
10. [Interpret Results](#step-9-interpret-results)

---

## STEP 0: Setup and Installation

### Install the Package

```r
# Set your working directory
setwd("~/05_Regional_Climate_Trends")

# Install ClimateNarratives
install.packages("ClimateNarratives_0.2.tar.gz", repos = NULL, type = "source")

# IMPORTANT: Restart R!
q()  # Type 'n' when asked to save workspace
# Then start R again
```

### Load the Package

```r
library(ClimateNarratives)
```

**What happens:**
- R loads all the ClimateNarratives functions
- You'll see a startup message with version info
- All functions are now available

**Help Available:**
```r
?ClimateNarratives              # Package overview
help(package = "ClimateNarratives")  # List all functions
```

---

## STEP 1: Initialize Project

### Run This Code

```r
initialize_project("CA")  # Change "CA" to your state
```

**Alternative with custom path:**
```r
initialize_project("CA", path = "~/05_Regional_Climate_Trends")
```

### What This Function Does

**Behind the scenes:**
1. Creates three folders:
   - `Data/` - For weather station data
   - `Output/` - For analysis results
   - `Figures/` - For plots and maps

2. Downloads station inventory from NOAA:
   - All weather stations in the US
   - Station locations (latitude, longitude)
   - Station metadata (name, elevation, ID)
   - Data availability (first year, last year)

3. Filters for your state:
   - Selects only stations in your state
   - Keeps only active stations (recent data)
   - Stores in variable `my.inventory`

4. Sets up global variables:
   - `my.state` - Your state abbreviation
   - `my.inventory` - Available stations data frame
   - `datafolder` - Path to Data/ folder
   - `figuresfolder` - Path to Figures/ folder

### Check Your Progress

**Look in your folder:**
```
YourProject/
├── Data/
│   └── stations.active.oldest.csv  ← Station inventory
├── Output/                          ← Empty for now
└── Figures/                         ← Empty for now
```

**Check in R:**
```r
# View your state
my.state

# See how many potential stations
nrow(my.inventory)

# View first few stations
head(my.inventory)

# See what's in the inventory
names(my.inventory)
# [1] "ID" "LATITUDE" "LONGITUDE" "ELEVATION" "STATE" "NAME" 
#     "STATE_NAME" "FIRSTYEAR" "LASTYEAR" "RECORD_LENGTH"
```

### Getting Help

```r
?initialize_project  # Detailed function documentation
```

### Key Concepts

**What is a weather station?**
- Physical location with instruments measuring temperature, precipitation, etc.
- Each station has a unique ID (e.g., "USC00045123")
- Stations have been collecting data for decades

**What is an inventory?**
- Database of all available weather stations
- Tells you where stations are located
- Shows how much data each station has

**Why do we filter by state?**
- Manageable dataset size
- Regional focus for analysis
- Local climate patterns

---

## STEP 2: Select Weather Stations

### Run This Code

```r
select_stations(n = 50)
```

**Advanced options:**
```r
# Stricter quality requirements
select_stations(n = 50, min_years = 70, min_last_year = 2023)

# Fewer stations
select_stations(n = 30)
```

### What This Function Does

**Behind the scenes:**
1. Applies quality filters:
   - Minimum record length (default: 50 years)
   - Must have recent data (default: through 2020)
   - Removes stations with gaps or poor quality

2. Ranks stations:
   - Sorts by record length (longest first)
   - Prioritizes older stations (more data)
   - Ensures good spatial coverage

3. Selects top N stations:
   - Takes the best stations
   - Balances quantity vs. quality
   - Updates `my.inventory` with selection

4. Saves selection:
   - Writes to CSV file for reference
   - Allows you to see which stations were chosen

### Check Your Progress

**Look in Data/ folder:**
```
Data/
├── stations.active.oldest.csv      ← All stations
└── selected_inventory_CA.csv       ← YOUR SELECTED STATIONS ★
```

**Check in R:**
```r
# How many stations selected?
nrow(my.inventory)

# View selected stations
head(my.inventory)

# Summary statistics
summary(my.inventory$RECORD_LENGTH)
summary(my.inventory$FIRSTYEAR)

# Oldest station
my.inventory[which.min(my.inventory$FIRSTYEAR), ]
```

### Getting Help

```r
?select_stations
example(select_stations)
```

### Key Concepts

**Why 50 stations?**
- Good balance for spatial interpolation
- Enough for reliable kriging
- Not too many (takes too long to download)

**What is record length?**
- Number of years of data available
- Longer records = better trend detection
- Need at least 30-50 years for climate trends

**Why filter for data quality?**
- Missing data affects trend calculations
- Old stations stopped collecting data
- Recent data ensures relevance

**What is kriging?**
- Spatial interpolation method
- Estimates values between stations
- Requires ~20+ stations for reliability

---

## STEP 3: Download Data

### Run This Code

```r
download_stations()
```

**This takes 10-30 minutes!** The function:
- Downloads each station sequentially
- Shows progress as it goes
- Is polite to NOAA servers (0.5 sec delay)

### What This Function Does

**Behind the scenes:**
1. Loops through selected stations:
   - Reads station IDs from `my.inventory`
   - Downloads from NOAA GHCN-Daily database
   - One station at a time

2. For each station:
   - Fetches compressed data (.csv.gz)
   - Decompresses to .csv format
   - Validates data structure
   - Shows progress message

3. Handles errors gracefully:
   - Skips failed downloads
   - Continues with remaining stations
   - Reports failures at end

4. Saves inventory of successes:
   - Creates `downloaded_inventory.csv`
   - Lists which stations completed
   - Used by next step

### Check Your Progress

**Look in Data/ folder:**
```
Data/
├── stations.active.oldest.csv
├── selected_inventory_CA.csv
├── downloaded_inventory.csv        ← Download log ★
├── USC00045123.csv.gz              ← Compressed data
├── USC00045123.csv                 ← Uncompressed data
├── USC00046336.csv.gz
├── USC00046336.csv
└── ... (many more files)
```

**Check in R:**
```r
# List downloaded files
list.files("Data/", pattern = "*.csv$")

# Count CSV files
length(list.files("Data/", pattern = "*.csv$"))

# Read one station to explore
station_data <- read.csv("Data/USC00045123.csv")
head(station_data)
names(station_data)
# [1] "ID" "DATE" "ELEMENT" "VALUE" "M.FLAG" "Q.FLAG" "S.FLAG" "OBS.TIME"
```

### Getting Help

```r
?download_stations
```

### Key Concepts

**What is GHCN-Daily?**
- Global Historical Climatology Network - Daily
- NOAA's comprehensive climate database
- Daily observations from ~100,000 stations worldwide
- Quality controlled and publicly available

**What data is downloaded?**
- Daily maximum temperature (TMAX)
- Daily minimum temperature (TMIN)
- Daily precipitation (PRCP)
- Other elements (snow, wind, etc.)

**What is the DATE format?**
- YYYYMMDD (e.g., 20230715 = July 15, 2023)
- Integer format (needs conversion)
- Handled by `fixDates.fun()` later

**What are the flags?**
- M-FLAG: Measurement flag
- Q-FLAG: Quality flag
- S-FLAG: Source flag
- Used for quality control

**Why .csv.gz format?**
- Compressed to save bandwidth
- Automatically decompressed by R
- Reduces download time

---

## STEP 4: Process and Save Data

### Run This Code

```r
load_and_save_stations(cleanup = TRUE)
```

**Options:**
```r
# Keep CSV files (uses more disk space)
load_and_save_stations(cleanup = FALSE)
```

### What This Function Does

**Behind the scenes:**
1. Loads all CSV files:
   - Reads each downloaded station
   - Stores in a named list
   - Each station is a data frame

2. Assigns to global environment:
   - Creates `station_list` (list of all stations)
   - Creates individual variables (e.g., `USC00045123`)
   - Both point to same data (memory efficient)

3. Saves to RData format:
   - Creates `all_stations_raw.RData`
   - Much smaller than CSV files (5-10x compression)
   - Much faster to load later
   - Preserves R data types

4. Cleanup (if requested):
   - Removes .csv.gz files
   - Removes .csv files
   - Keeps only .RData
   - Saves 100-500 MB disk space

### Check Your Progress

**Look in Data/ folder (after cleanup):**
```
Data/
├── stations.active.oldest.csv
├── selected_inventory_CA.csv
├── downloaded_inventory.csv
└── all_stations_raw.RData           ← ALL YOUR DATA ★★★
```

**Check in R:**
```r
# List all loaded stations
names(station_list)

# How many stations loaded?
length(station_list)

# Access a specific station
head(station_list$USC00045123)

# Or use the individual variable
head(USC00045123)

# Check data structure
str(USC00045123)

# How many observations?
nrow(USC00045123)
```

### Getting Help

```r
?load_and_save_stations
?load_stations  # For loading previously saved data
```

### Key Concepts

**What is a list in R?**
- Container holding multiple objects
- Each element can be different
- Access with `$` or `[[]]`
- Like a filing cabinet with labeled drawers

**What is RData format?**
- Native R data format
- Preserves object types exactly
- Compressed automatically
- Fast to load
- Extension: `.RData` or `.rda`

**Why cleanup?**
- CSV files are redundant after saving to RData
- Saves significant disk space
- Can always re-download if needed
- RData has everything you need

**What if I need to reload later?**
```r
# Just run this:
load_stations()
# Loads all_stations_raw.RData back into R
```

---

## STEP 5: Calculate Climate Trends

### Run This Code

```r
trends <- process_all_stations()
```

**This is the most complex step!** It calculates all climate statistics.

### What This Function Does

**Behind the scenes (for EACH station):**

1. **Fix dates** (using `fixDates.fun()`):
   - Converts DATE from YYYYMMDD to R Date objects
   - Extracts MONTH (1-12)
   - Extracts YEAR (e.g., 2023)
   ```r
   # Example:
   # DATE: 20230715 → Ymd: 2023-07-15, MONTH: 7, YEAR: 2023
   ```

2. **Fix values** (using `fixValues.fun()`):
   - Converts temperatures from tenths of °C to °C
   - Converts precipitation from tenths of mm to mm
   - NOAA stores 25.5°C as 255
   ```r
   # Example:
   # VALUE: 255 (TMAX) → 25.5°C
   # VALUE: 123 (PRCP) → 12.3 mm
   ```

3. **Calculate monthly values** (using `MonthlyValues.fun()`):
   - Aggregates daily data to monthly
   - TMAX: monthly mean of daily maximums
   - TMIN: monthly mean of daily minimums
   - PRCP: monthly total precipitation
   ```r
   # Example: July 2023
   # Daily TMAX: 28, 29, 27, 30, ... (31 days)
   # Monthly TMAX: 28.5°C (average)
   ```

4. **Calculate climate normals** (using `MonthlyNormals.fun()`):
   - Uses 1961-1990 period (WMO standard)
   - Calculates average for each month
   - Creates baseline for comparison
   ```r
   # Example: July normal
   # All July months 1961-1990: 25.2, 26.1, 24.8, ...
   # July normal: 25.5°C (30-year average)
   ```

5. **Calculate anomalies** (using `MonthlyAnomalies.fun()`):
   - Anomaly = Observed - Normal
   - Shows deviation from typical conditions
   - Positive = warmer/wetter than normal
   ```r
   # Example: July 2023
   # Observed: 28.5°C, Normal: 25.5°C
   # Anomaly: +3.0°C (warmer than normal!)
   ```

6. **Calculate annual trends**:
   - Uses linear regression on anomalies
   - Slope = trend in °C or mm per year
   - Multiplied by 100 for °C/century
   ```r
   # Example:
   # Regression: Anomaly ~ Year
   # Slope: 0.012°C/year × 100 = 1.2°C/century
   ```

7. **Calculate seasonal trends**:
   - Winter: December, January, February
   - Spring: March, April, May
   - Summer: June, July, August
   - Fall: September, October, November
   - Separate regression for each season

8. **Compile results**:
   - One row per station
   - Columns: station metadata + trends
   - Returns data frame

### Output: Comprehensive Trend Summary

The function prints a detailed report:

```
===========================================================
  CLIMATE TREND SUMMARY
===========================================================

ANNUAL TEMPERATURE TRENDS (°C per 100 years):
  Maximum Temperature (TMAX):
    Mean:   +1.234°C/century
    Median: +1.189°C/century
    Range:  +0.456 to +2.345°C/century
  
  Minimum Temperature (TMIN):
    Mean:   +1.567°C/century
    Median: +1.523°C/century
    Range:  +0.789 to +2.678°C/century

ANNUAL PRECIPITATION TRENDS (mm per 100 years):
    Mean:   +12.3 mm/century
    Median: +10.5 mm/century
    Range:  -45.2 to +78.9 mm/century

SEASONAL TMAX TRENDS (°C per 100 years):
    Winter: +1.456°C/century
    Spring: +1.234°C/century
    Summer: +1.123°C/century
    Fall:   +1.345°C/century

SEASONAL TMIN TRENDS (°C per 100 years):
    Winter: +1.789°C/century
    Spring: +1.567°C/century
    Summer: +1.456°C/century
    Fall:   +1.678°C/century

INTERPRETATION:
• Daytime temperatures WARMING at 1.23°C per 100 years
• Nighttime temperatures WARMING at 1.57°C per 100 years
• Nighttime warming exceeds daytime warming (asymmetric)
• Precipitation INCREASING at 12.3 mm per 100 years
===========================================================
```

### Check Your Progress

**Check the `trends` data frame:**
```r
# View structure
str(trends)

# View first few rows
head(trends)

# Column names
names(trends)
# [1] "ID" "NAME" "LATITUDE" "LONGITUDE" "ELEVATION"
#     "annual_trend_TMAX" "annual_trend_TMIN" "annual_trend_PRCP"
#     "winter_trend_TMAX" "spring_trend_TMAX" ...

# Summary statistics
summary(trends$annual_trend_TMAX)
summary(trends$annual_trend_TMIN)
summary(trends$annual_trend_PRCP)

# How many stations processed?
nrow(trends)

# Stations with coordinates?
sum(!is.na(trends$LATITUDE))

# Histogram of TMAX trends
hist(trends$annual_trend_TMAX, 
     main = "Distribution of TMAX Trends",
     xlab = "°C per century")
```

**Save trends for later:**
```r
# Save to CSV for Excel
write.csv(trends, "Data/climate_trends.csv", row.names = FALSE)

# Save to RData
save(trends, file = "Data/trends.RData")
```

### Getting Help

```r
?process_all_stations
?MonthlyValues.fun
?MonthlyNormals.fun
?MonthlyAnomalies.fun
```

### Key Concepts

**What is a climate normal?**
- 30-year average (WMO standard)
- Currently uses 1961-1990
- Represents "typical" climate
- Baseline for comparisons

**What is an anomaly?**
- Difference from normal
- Removes seasonal cycle
- Shows unusual conditions
- Example: +3°C anomaly in July = 3°C warmer than typical July

**What is a trend?**
- Long-term change over time
- Calculated using linear regression
- Reported per century (100 years)
- Example: +1.5°C/century = warming

**Why linear regression?**
- Simple, interpretable method
- Finds best-fit line through data
- Slope = rate of change
- Standard in climate science

**What is asymmetric warming?**
- Nighttime (TMIN) warming faster than daytime (TMAX)
- Common signal of greenhouse effect
- Clouds and humidity trap heat at night
- Regional patterns vary

---

## STEP 6: Create Spatial Objects

### Run This Code

```r
create_spatial_objects(trends)
```

### What This Function Does

**Behind the scenes:**
1. Takes trends data frame
2. Adds spatial coordinates (lat/lon)
3. Converts to two formats:
   - **sf** (Simple Features) - Modern spatial format
   - **sp** (Spatial Points) - Used for kriging

4. Creates global variables:
   - `trends_sf` - sf format
   - `trends_sp` - sp format

5. Removes stations without coordinates

### Check Your Progress

**Check spatial objects:**
```r
# View sf object
trends_sf
plot(trends_sf["annual_trend_TMAX"])  # Quick map

# View sp object  
trends_sp
class(trends_sp)  # "SpatialPointsDataFrame"

# Check coordinate system
sf::st_crs(trends_sf)

# How many spatial points?
nrow(trends_sf)
nrow(trends_sp)
```

**Save spatial data:**
```r
# Save for later use
save(trends_sf, trends_sp, 
     file = "Data/spatial_trends.RData")
```

### Getting Help

```r
?create_spatial_objects
```

### Key Concepts

**What is a spatial object?**
- Data frame + geographic coordinates
- Knows about map projections
- Can be plotted on maps
- Used for spatial analysis

**What is sf?**
- Modern spatial package
- "Simple Features" format
- Tidy data compatible
- Easy plotting with ggplot2

**What is sp?**
- Older spatial package
- Still used by many tools (like gstat)
- Required for kriging
- Being phased out but still functional

**Why two formats?**
- sf: modern, easy to use
- sp: required for gstat kriging
- Package converts between them

---

## STEP 7: Assess Station Coverage

### Run This Code

```r
assessment <- check_station_coverage(trends)
```

### What This Function Does

**Behind the scenes:**
1. Counts total stations
2. Counts stations with valid coordinates
3. Calculates spatial extent
4. Evaluates coverage quality:
   - GOOD: 20+ stations
   - FAIR: 10-20 stations
   - POOR: < 10 stations

5. Recommends visualization approach:
   - Many stations → kriging (create_heatmap)
   - Few stations → point map (plot_station_map)

6. Prints assessment report

### Check Your Progress

**Review the assessment:**
```r
# Assessment was printed
# Also stored in variable:
assessment$status
assessment$recommendation
assessment$message
assessment$n_stations
```

### Getting Help

```r
?check_station_coverage
```

### Key Concepts

**Why does station count matter?**
- Kriging needs ~20+ stations for reliability
- Fewer stations = less reliable interpolation
- Sparse coverage = large uncertainty between points

**What if I have few stations?**
- Use point maps instead
- Show individual station plots
- Consider combining with neighboring states
- Focus on station-level analysis

---

## STEP 8: Create Visualizations

### Option A: Heat Maps (Kriging Interpolation)

**Use when: 20+ stations with good coverage**

```r
# Annual TMAX trend
map_tmax <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMAX",
  title = "Annual Maximum Temperature Trend",
  subtitle = "California, 1950-2023",
  state = "CA",
  colors = "temp",
  resolution = 0.1
)

print(map_tmax)
ggsave("Figures/tmax_annual_CA.png", map_tmax, 
       width = 10, height = 8, dpi = 300)

# Annual TMIN trend
map_tmin <- create_heatmap(
  trends_sp,
  "annual_trend_TMIN",
  "Annual Minimum Temperature Trend",
  state = "CA"
)
ggsave("Figures/tmin_annual_CA.png", map_tmin,
       width = 10, height = 8, dpi = 300)

# Annual precipitation trend
map_prcp <- create_heatmap(
  trends_sp,
  "annual_trend_PRCP",
  "Annual Precipitation Trend",
  state = "CA",
  colors = "precip"  # Different color scheme
)
ggsave("Figures/prcp_annual_CA.png", map_prcp,
       width = 10, height = 8, dpi = 300)
```

**What create_heatmap() does:**
1. Creates a grid over your state
2. Uses kriging to interpolate between stations
3. Estimates values at grid points
4. Creates continuous color surface
5. Adds state boundaries
6. Returns ggplot object

### Option B: Point Maps (Simple Display)

**Use when: < 20 stations or want to show actual locations**

```r
# Point map for TMAX
map_points <- plot_station_map(
  trends_sf,
  "annual_trend_TMAX",
  "Temperature Trends by Station",
  state = "CA",
  point_size = 4,
  colors = "temp"
)

print(map_points)
ggsave("Figures/tmax_points_CA.png", map_points,
       width = 10, height = 8, dpi = 300)
```

**What plot_station_map() does:**
1. Gets state boundaries
2. Plots each station as a colored point
3. Color = trend value
4. No interpolation
5. Shows actual data locations

### Option C: Individual Station Plots

**Shows detailed time series for each station**

```r
# Plot first 10 stations
plot_station_trends(trends, max_stations = 10)

# Plot specific stations
plot_station_trends(trends, 
                    stations = c("USC00045123", "USC00046336"))

# Plot all stations (if not too many)
plot_station_trends(trends, max_stations = 50)
```

**What plot_station_trends() does:**
1. For each station:
   - Calculates monthly anomalies
   - Aggregates to annual values
   - Fits trend line
   - Creates 3-panel plot (TMAX, TMIN, PRCP)
2. Saves to Figures/StationPlots/
3. Creates high-resolution PNG files

### Option D: Seasonal Comparison

**Compare warming across seasons**

```r
library(patchwork)

# Create seasonal maps
winter <- create_heatmap(trends_sp, "winter_trend_TMAX",
                         "Winter (Dec-Feb)", state = "CA",
                         resolution = 0.15) +
  theme(legend.position = "none")

spring <- create_heatmap(trends_sp, "spring_trend_TMAX",
                         "Spring (Mar-May)", state = "CA",
                         resolution = 0.15) +
  theme(legend.position = "none")

summer <- create_heatmap(trends_sp, "summer_trend_TMAX",
                         "Summer (Jun-Aug)", state = "CA",
                         resolution = 0.15) +
  theme(legend.position = "right")

fall <- create_heatmap(trends_sp, "fall_trend_TMAX",
                       "Fall (Sep-Nov)", state = "CA",
                       resolution = 0.15) +
  theme(legend.position = "none")

# Combine into 2x2 panel
seasonal <- (winter | spring) / (summer | fall) +
  plot_annotation(
    title = "Seasonal TMAX Trends - California",
    subtitle = "Change in °C per 100 years"
  )

ggsave("Figures/seasonal_tmax_CA.png", seasonal,
       width = 12, height = 10, dpi = 300)
```

### Check Your Progress

**Look in Figures/ folder:**
```
Figures/
├── tmax_annual_CA.png              ← Heat map
├── tmin_annual_CA.png              ← Heat map
├── prcp_annual_CA.png              ← Heat map
├── tmax_points_CA.png              ← Point map
├── seasonal_tmax_CA.png            ← 4-panel comparison
└── StationPlots/
    ├── station_USC00045123.png     ← Individual station
    ├── station_USC00046336.png
    └── ... (10 files)
```

### Getting Help

```r
?create_heatmap
?plot_station_map
?plot_station_trends
```

### Key Concepts

**What is kriging?**
- Spatial interpolation method
- Uses distance weighting
- Estimates values between known points
- Creates smooth surfaces
- Named after Danie Krige (mining engineer)

**What is a variogram?**
- Shows how similarity changes with distance
- Used to fit kriging model
- Nearby points more similar than distant points
- May not converge (that's the warning you see)

**Why the variogram warning?**
- "No convergence after 200 iterations"
- Automatic fitting didn't find perfect model
- Interpolation still works!
- Results still usable
- Common with irregular station spacing

**What color schemes to use?**
- **Temperature**: Blue (cool) → White → Red (warm)
- **Precipitation**: Brown (dry) → White → Green (wet)

**What resolution to use?**
- Finer (0.05): Smoother, slower, larger file
- Coarser (0.2): Blockier, faster, smaller file
- Default (0.1): Good balance

---

## STEP 9: Interpret Results

### Understanding Your Trend Summary

**Temperature Trends:**

```
TMAX Mean: +1.23°C/century
TMIN Mean: +1.57°C/century
```

**This means:**
- Daytime highs warming ~1.2°C per 100 years
- Nighttime lows warming ~1.6°C per 100 years
- At current rate: 1.2°C warmer by 2100 (daytime)

**Asymmetric Warming:**

```
Nighttime warming exceeds daytime warming
```

**This means:**
- TMIN increasing faster than TMAX
- Classic greenhouse effect signal
- Nighttime heat retention
- Reduced diurnal temperature range

**Precipitation Trends:**

```
PRCP Mean: +12.3 mm/century
```

**This means:**
- Region getting slightly wetter
- ~12mm more per century
- High variability (large range)
- Less reliable than temperature

### Understanding Your Heat Maps

**Hot spots (red areas):**
- Stations warming faster
- Local conditions accelerating warming
- Urban heat islands?
- Regional climate patterns

**Cool spots (blue areas):**
- Stations warming slower (or cooling)
- Local conditions buffering warming
- Coastal effects?
- Elevation effects?

**Spatial patterns:**
- Coastal vs. inland differences
- Mountain vs. valley differences
- Urban vs. rural differences
- Latitude gradients

### Statistical Significance

**Look at the range:**
```
Range: +0.456 to +2.345°C/century
```

**If ALL values are positive:**
- Widespread warming
- Statistically robust
- High confidence

**If range crosses zero:**
```
Range: -0.5 to +2.0°C/century
```
- Some cooling, mostly warming
- More variable
- Check individual significance

### Comparing to Global Averages

**Global average warming:** ~1.0°C/century (1900-2023)

**If your region shows +1.5°C/century:**
- Warming faster than global average
- Regional amplification
- Local factors at play

**If your region shows +0.5°C/century:**
- Warming slower than global average
- Regional buffering
- Oceanic influence?

### Writing Up Results

**Example interpretation:**

> "Analysis of 50 weather stations across California (1950-2023) reveals significant warming trends. Annual maximum temperatures are increasing at 1.23°C per century, while minimum temperatures show even faster warming at 1.57°C per century. This asymmetric warming pattern, with nighttime temperatures increasing 30% faster than daytime temperatures, is consistent with greenhouse gas forcing. Precipitation shows a modest increasing trend of 12.3 mm per century, though with high spatial variability. Spatial analysis reveals strongest warming in inland regions, with coastal areas showing more modest trends, likely due to oceanic thermal buffering."

---

## 📊 Complete File Structure

**After running the entire workflow:**

```
YourProject/
├── Data/
│   ├── stations.active.oldest.csv      ← All available stations
│   ├── selected_inventory_CA.csv       ← Your 50 selected stations
│   ├── downloaded_inventory.csv        ← Download log
│   ├── all_stations_raw.RData          ← All station data (MAIN FILE)
│   ├── climate_trends.csv              ← Trends exported to CSV
│   ├── trends.RData                    ← Trends in R format
│   └── spatial_trends.RData            ← Spatial objects
│
├── Output/
│   └── (your analysis files)
│
└── Figures/
    ├── tmax_annual_CA.png              ← Annual TMAX heat map
    ├── tmin_annual_CA.png              ← Annual TMIN heat map
    ├── prcp_annual_CA.png              ← Annual PRCP heat map
    ├── tmax_points_CA.png              ← Point map alternative
    ├── seasonal_tmax_CA.png            ← 4-panel seasonal
    └── StationPlots/
        ├── station_USC00045123.png     ← Individual time series
        ├── station_USC00046336.png
        └── ... (10+ files)
```

---

## 🎓 Learning Objectives Achieved

By completing this workflow, you've learned:

**R Programming:**
- ✅ Loading and using packages
- ✅ Working with data frames
- ✅ Using functions with parameters
- ✅ Global vs. local variables
- ✅ Saving and loading R objects

**Data Management:**
- ✅ Downloading data from APIs
- ✅ Reading CSV files
- ✅ Data cleaning and validation
- ✅ Efficient data storage (RData)
- ✅ File organization

**Statistics:**
- ✅ Time series analysis
- ✅ Linear regression
- ✅ Trend calculation
- ✅ Anomaly computation
- ✅ Summary statistics

**Climate Science:**
- ✅ Climate normals (1961-1990)
- ✅ Temperature anomalies
- ✅ Climate trends
- ✅ Asymmetric warming
- ✅ Regional climate patterns

**Spatial Analysis:**
- ✅ Spatial data structures (sf, sp)
- ✅ Coordinate systems
- ✅ Kriging interpolation
- ✅ Spatial visualization

**Visualization:**
- ✅ Time series plots
- ✅ Heat maps
- ✅ Multi-panel figures
- ✅ Color schemes
- ✅ Publication-quality graphics

---

## 🔧 Troubleshooting Guide

### Problem: "Variable not found"

```r
Error: object 'my.state' not found
```

**Solution:** Run `initialize_project()` first!

### Problem: "No valid coordinates"

```r
Error: No valid coordinates found in trends data
```

**Solution:** Run `initialize_project()` to load station inventory.

### Problem: Download fails

**Solution:** 
- Check internet connection
- Try again with `download_stations()`
- NOAA servers may be temporarily down

### Problem: Variogram warning

```r
Warning: No convergence after 200 iterations
```

**Solution:** This is NORMAL! The map still works. Ignore this warning.

### Problem: Too few stations

```r
Status: POOR - Very few stations (7)
```

**Solution:**
- Use `plot_station_map()` instead of `create_heatmap()`
- Use `plot_station_trends()` for individual analysis
- Consider regional analysis with neighboring states

### Problem: Map looks weird

**Solutions:**
- Check you have 20+ stations
- Try coarser resolution: `resolution = 0.2`
- Check spatial coverage is good
- Use point map instead

---

## 📚 Additional Resources

### Help Commands

```r
# Package overview
?ClimateNarratives
help(package = "ClimateNarratives")

# Function help
?initialize_project
?process_all_stations
?create_heatmap

# Run examples
example(select_stations)
example(plot_station_map)
```

### Data Sources

- **NOAA GHCN-Daily:** https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily
- **Climate Normals:** https://www.ncei.noaa.gov/products/land-based-station/us-climate-normals
- **WMO Standards:** https://public.wmo.int/

### Further Reading

- Introduction to Climate Data (NOAA)
- Spatial Analysis in R (book: "Spatial Data Science")
- Time Series Analysis in R

---

## ✅ Workflow Checklist

Use this checklist to track your progress:

- [ ] Install ClimateNarratives package
- [ ] Load package with `library(ClimateNarratives)`
- [ ] Run `initialize_project()` - creates folders
- [ ] Check `Data/stations.active.oldest.csv` exists
- [ ] Run `select_stations()` - filters stations
- [ ] Check `Data/selected_inventory_CA.csv` exists
- [ ] Run `download_stations()` - 10-30 min wait
- [ ] Check many `.csv` files in Data/
- [ ] Run `load_and_save_stations()` - processes data
- [ ] Check `Data/all_stations_raw.RData` exists
- [ ] Run `trends <- process_all_stations()` - calculates trends
- [ ] Read and understand trend summary
- [ ] Save trends: `write.csv(trends, "Data/climate_trends.csv")`
- [ ] Run `create_spatial_objects(trends)` - spatial conversion
- [ ] Run `check_station_coverage(trends)` - assess coverage
- [ ] Create heat maps OR point maps (based on coverage)
- [ ] Create individual station plots
- [ ] Save all figures with `ggsave()`
- [ ] Check Figures/ folder for outputs
- [ ] Interpret results
- [ ] Write up findings

**Congratulations!** You've completed a professional climate analysis! 🎉

---

## 🎯 Next Steps

### For Your Project

1. **Analyze different seasons**
   - Compare winter vs. summer warming
   - Identify seasonal patterns

2. **Compare variables**
   - TMAX vs. TMIN warming rates
   - Temperature vs. precipitation patterns

3. **Regional analysis**
   - Coastal vs. inland differences
   - Urban vs. rural stations
   - Elevation effects

4. **Statistical testing**
   - Significance of trends
   - Correlation analysis
   - Regression diagnostics

5. **Create narrative**
   - Write up findings
   - Create presentation
   - Make video with figures

### Advanced Topics

- Multiple state comparisons
- Extreme events analysis
- Seasonal cycle changes
- Custom spatial analysis
- Advanced kriging models
- Climate model comparison

---

**End of Workflow Guide**

*For questions or issues, use `?function_name` or check package documentation.*
