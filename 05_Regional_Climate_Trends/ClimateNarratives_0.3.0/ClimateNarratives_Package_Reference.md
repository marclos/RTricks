# ClimateNarratives Package Reference

**Version 0.3.0** | Regional Climate Trend Analysis and Visualization  
**Author:** Marc Los Huertos  

---

## What This Package Does

ClimateNarratives automates the workflow of downloading NOAA weather station data, calculating climate trends (temperature and precipitation), and producing publication-quality heat maps with kriging interpolation. It is designed for teaching R programming through climate science.

**Data source:** NOAA Global Historical Climatology Network – Daily (GHCN-D)  
**Analysis output:** Trend estimates in °C/century (temperature) and mm/century (precipitation)  
**Visualization:** Kriged spatial heat maps at configurable resolution  

---

## Package Structure

```
ClimateNarratives/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── ClimateNarratives-package.R   # Package docs, dependency checker, startup
│   ├── initialize.R                  # initialize_project(), set_config()
│   ├── download.R                    # select_stations(), download_stations()
│   ├── processing.R                  # load_and_save_stations()
│   ├── data_cleaning.R              # fixDates.fun(), fixValues.fun(), coverage.fun()
│   └── analysis.R                   # MonthlyValues/Normals/Anomalies/Trend functions
├── man/                             # Auto-generated help files
├── vignettes/
│   └── getting-started.Rmd
├── install_package.R                # One-step installer script
└── example_workflow.R               # Complete working example
```

---

## Dependencies

| Package(s)         | Category      | Role                                        |
|--------------------|---------------|---------------------------------------------|
| dplyr, tidyr       | Core          | Data manipulation and reshaping              |
| ggplot2            | Core          | All plotting and heat maps                   |
| lubridate          | Core          | Date parsing and extraction                  |
| sp, sf             | Spatial       | Spatial data classes (legacy and modern)      |
| gstat              | Spatial       | Variogram modeling and kriging interpolation  |
| raster, stars      | Spatial       | Raster grid creation and manipulation         |
| viridis            | Visualization | Color-blind-friendly palettes                |
| maps, mapdata      | Visualization | State boundary polygons                      |
| patchwork          | Visualization | Multi-panel plot composition                 |
| devtools, roxygen2 | Build         | Package building and documentation           |
| knitr, rmarkdown   | Build         | Vignette rendering                           |

### Dependency Check (v0.3.0 feature)

```r
# Run BEFORE installing the package to avoid silent failures:
check_dependencies()

# Just see what's missing without installing:
check_dependencies(install = FALSE)
```

At `library(ClimateNarratives)` load time, the package checks for missing core dependencies and prints a loud warning with the exact install command if anything is missing.

---

## Function Reference

### Setup & Configuration

#### `initialize_project(state, path = NULL)`

The main setup function. Creates directory structure, downloads NOAA station inventory, sets global variables, and changes your working directory to the project root.

- **state** — Two-letter state abbreviation (e.g., `"CA"`, `"TX"`, `"NY"`)
- **path** — Where to create the project. If omitted (recommended), auto-creates `~/ClimateNarratives_XX/` where XX is the state code.

**What it does:**
1. Creates `Data/`, `Output/`, `Figures/` subdirectories
2. Downloads the full NOAA station inventory (first time only; cached after that)
3. Subsets inventory to your state
4. Calls `setwd()` to the project root
5. Sets global variables: `my.state`, `my.inventory`, `datafolder`, `figuresfolder`, `projectfolder`

**Why the path auto-generates:** Students were not editing path variables, causing files to save to the wrong location. Now `initialize_project("CA")` is all you need — no path editing required.

```r
# Simplest usage (creates ~/ClimateNarratives_CA/):
initialize_project("CA")

# Custom path if needed:
initialize_project("TX", path = "~/Documents/TexasClimate")
```

#### `set_config(state, path = NULL)`

Convenience alias for `initialize_project()`.

#### `check_dependencies(install = TRUE, quiet = FALSE)`

Checks every required package one by one and prints OK or MISS for each. With `install = TRUE` (default), installs any missing packages individually so you can see exactly which ones succeed or fail.

---

### Station Selection & Download

#### `select_stations(n = 50, min_years = 50, min_last_year = 2020)`

Filters `my.inventory` for stations meeting quality criteria and selects the top `n` by record length.

- **n** — Number of stations to select (50 recommended for good kriging)
- **min_years** — Minimum record length in years
- **min_last_year** — Station must have data at least through this year

Updates `my.inventory` in the global environment. Saves selection to `Data/selected_inventory_XX.csv`.

```r
select_stations(n = 50)
select_stations(n = 30, min_years = 70, min_last_year = 2023)  # stricter
```

#### `download_stations(cleanup = TRUE, verbose = TRUE)`

Downloads daily weather data (TMAX, TMIN, PRCP) from NOAA for all stations in `my.inventory`. Includes a 0.5-second delay between requests.

- Expect 10–30 minutes for 50 stations
- If interrupted, re-run — it picks up where it left off
- Failed stations are reported at the end and excluded from the inventory

---

### Data Processing

#### `load_and_save_stations(cleanup = TRUE, verbose = TRUE)`

Reads all downloaded CSVs into a named list (`station_list`), saves to `Data/all_stations_raw.RData`, and optionally removes the temporary CSV/GZ files.

#### `load_stations(verbose = TRUE)`

Reloads previously saved `all_stations_raw.RData` into the global environment. Use this when returning to a project in a later R session.

---

### Data Cleaning

#### `fixDates.fun(station)`

Converts NOAA's integer date format (YYYYMMDD) to R Date objects. Adds `Ymd`, `MONTH`, `YEAR` columns.

#### `fixValues.fun(station)`

Converts NOAA tenths-of-units to standard units: temperatures to °C, precipitation to mm.

#### `coverage.fun(station, element = "TMAX")`

Returns the percentage of days with non-missing data for a given element.

---

### Analysis

#### `MonthlyValues.fun(station)`

Aggregates daily data to monthly: mean for TMAX/TMIN, sum for PRCP.

#### `MonthlyNormals.fun(station, min_months_required = 12, min_years_per_month = 10, station_id = "unknown")`

Calculates climate normals with an automatic fallback cascade:

1. **1961–1990** (WMO standard)
2. **1971–2000** (if #1 lacks coverage)
3. **1981–2010** (if #2 lacks coverage)
4. **Full record** (last resort)

At each level, requires all 12 months to have at least `min_years_per_month` years of data. Prints a `message()` when using a non-standard period. Returns `NULL` with a `warning()` if no period has adequate data — the station is then skipped by downstream functions.

**Why this matters:** States like Alaska, Hawaii, and some western states have stations that started after 1961. Without the fallback, these stations would produce NaN anomalies and crash the trend calculations with an unhelpful error.

#### `MonthlyAnomalies.fun(station.monthly, station.normals, station_id = "unknown")`

Calculates anomalies (observed minus normal). Returns `NULL` with a warning if the normals are NULL or the merge produces empty results.

#### `monthlyTrend.fun(station.anomalies)`

Fits linear regression trends per month per element. Each `lm()` call is wrapped in `tryCatch` so one bad month does not crash the whole station.

#### `process_all_stations()`

Runs the full pipeline (clean → normals → anomalies → trends) for every station. Skips stations that return NULL at any step and reports a summary at the end.

---

### Visualization

#### `create_spatial_objects(trends)`

Converts the trends data frame to spatial formats: `trends_sf` (sf, modern) and `trends_sp` (sp, for kriging). Both are assigned to the global environment.

#### `create_heatmap(trends_sp, trend_var, title, subtitle, state, colors = "temp", resolution = 0.1)`

Creates a kriged interpolation heat map.

- **trend_var** — Column name, e.g., `"annual_trend_TMAX"`, `"winter_trend_PRCP"`
- **colors** — `"temp"` for temperature palette, `"precip"` for precipitation palette
- **resolution** — Grid cell size in degrees (smaller = finer, but slower)

---

## Global Variables Reference

After `initialize_project()` and subsequent functions, these are available in your global environment:

| Variable          | Set by                    | Description                                              |
|-------------------|---------------------------|----------------------------------------------------------|
| `my.state`        | `initialize_project()`    | Two-letter state code                                    |
| `my.inventory`    | `initialize_project()`, updated by `select_stations()` | Data frame of stations     |
| `datafolder`      | `initialize_project()`    | `"Data/"` (relative path — works because wd is set)      |
| `figuresfolder`   | `initialize_project()`    | `"Figures/"` (relative path)                             |
| `projectfolder`   | `initialize_project()`    | Absolute path to project root                            |
| `station_list`    | `load_and_save_stations()`| Named list of all station data frames                    |
| `station_inventory`| `load_and_save_stations()`| Inventory of successfully downloaded stations            |
| `trends_sf`       | `create_spatial_objects()` | sf spatial data frame of trends                         |
| `trends_sp`       | `create_spatial_objects()` | sp SpatialPointsDataFrame of trends                     |

---

## Available Trend Variables for Heat Maps

**Temperature (°C/century):**
`annual_trend_TMAX`, `annual_trend_TMIN`, `winter_trend_TMAX`, `spring_trend_TMAX`, `summer_trend_TMAX`, `fall_trend_TMAX` (and corresponding TMIN versions)

**Precipitation (mm/century):**
`annual_trend_PRCP`, `winter_trend_PRCP`, `spring_trend_PRCP`, `summer_trend_PRCP`, `fall_trend_PRCP`

---

## File Structure After a Complete Analysis

```
~/ClimateNarratives_CA/
├── Data/
│   ├── stations.active.oldest.csv       # Full NOAA inventory (cached)
│   ├── selected_inventory_CA.csv        # Your 50 selected stations
│   ├── downloaded_inventory.csv         # Successfully downloaded stations
│   ├── all_stations_raw.RData           # All station data (fast to reload)
│   └── spatial_trends_CA.RData          # Processed trend data
├── Output/
│   └── (analysis results)
└── Figures/
    ├── TMAX_annual_CA.png
    ├── TMIN_annual_CA.png
    ├── PRCP_annual_CA.png
    └── Seasonal_TMAX_CA.png
```

---

## Version History

**v0.3.0** (current)
- Added `check_dependencies()` and startup dependency warnings — catches missing packages before they cause cryptic errors
- `initialize_project()` auto-generates path from state code (`~/ClimateNarratives_XX/`), sets working directory, uses relative paths — students no longer need to edit paths
- `MonthlyNormals.fun()` cascades through fallback periods (1961–1990 → 1971–2000 → 1981–2010 → full record) for states with poor baseline coverage
- `MonthlyAnomalies.fun()` and `monthlyTrend.fun()` handle NULL inputs gracefully — skip bad stations instead of crashing
- `install_package.R` installs dependencies one by one with clear pass/fail reporting
- Fixed NAMESPACE `st_as_sf` import (was incorrectly from `stars`, now correctly from `sf`)

**v0.2.0**
- Added `process_all_stations()`, `create_spatial_objects()`, `create_heatmap()`
- NAMESPACE and spatial function fixes
- R 3.4+ compatibility

**v0.1.0**
- Initial package: converted script-based workflow to R package structure

---

## License

GPL-3
