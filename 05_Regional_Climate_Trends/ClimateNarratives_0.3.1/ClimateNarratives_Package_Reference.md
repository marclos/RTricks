# ClimateNarratives Package Reference

**Version 0.3.1** | Regional Climate Trend Analysis and Visualization  
**Author:** Marc Los Huertos  

---

## What This Package Does

ClimateNarratives automates the workflow of downloading NOAA weather station data, calculating climate trends (temperature and precipitation), and producing publication-quality heat maps with kriging interpolation. It is designed for teaching R programming through climate science.

**Data source:** NOAA Global Historical Climatology Network — Daily (GHCN-D)  
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
│   ├── analysis.R                   # MonthlyValues/Normals/Anomalies/Trend functions
│   │                                 # + monthlyTrend_robust.fun, ExtremePrecp.fun,
│   │                                 #   nonlinearTrend.fun (v0.3.1)
│   ├── process_all.R               # process_all_stations() orchestrator
│   └── spatial.R                    # create_spatial_objects(), create_heatmap()
├── man/                             # Auto-generated help files (21 pages)
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
| maps, mapdata      | Visualization | State boundary polygons (incl. AK/HI)       |
| patchwork          | Visualization | Multi-panel plot composition                 |
| mgcv               | Suggested     | GAM nonlinear trend diagnostics (ships with R) |
| devtools, roxygen2 | Build         | Package building and documentation           |
| knitr, rmarkdown   | Build         | Vignette rendering                           |

### Dependency Check

```r
# Run BEFORE installing the package to avoid silent failures:
check_dependencies()

# Just see what's missing without installing:
check_dependencies(install = FALSE)
```

At `library(ClimateNarratives)` load time, the package checks for missing core dependencies and prints a loud warning with the exact install command if anything is missing.

### Upgrading from a Previous Version

**Always restart R before installing** (Session > Restart R). This prevents corrupt `.rdb` help databases — the error can affect ClimateNarratives or any dependency (ggplot2, sf, etc.) that was loaded in memory during installation.

After restarting R, the `install_package.R` script handles everything:

```r
setwd("~/ClimateNarratives_setup")
source("install_package.R")
```

If installing directly, restart R first, then:

```r
setwd("~/ClimateNarratives_setup")
try(detach("package:ClimateNarratives", unload = TRUE), silent = TRUE)
remove.packages("ClimateNarratives")
install.packages("ClimateNarratives_0.3.1.tar.gz", repos = NULL, type = "source")
library(ClimateNarratives)
```

Saved data (`all_stations_raw.RData`, figures) is not affected. Reload with `load_stations()` after reinstalling. If you see `lazy-load database ... is corrupt`, remove the named package, restart R, and reinstall it.

---

## Function Reference

### Setup & Configuration

#### `initialize_project(state, path = NULL)`

The main setup function. Creates directory structure, downloads NOAA station inventory, sets global variables, and changes your working directory to the project root.

- **state** — Two-letter state abbreviation (e.g., `"CA"`, `"TX"`, `"NY"`, `"AK"`)
- **path** — Where to create the project. **Recommended:** specify this explicitly so you always know where files are saved. If omitted, auto-creates `~/ClimateNarratives_XX/` where XX is the state code, but `~` can resolve to unexpected locations on some servers.

**What it does:**
1. Creates `Data/`, `Output/`, `Figures/` subdirectories
2. Downloads the full NOAA station inventory (first time only; cached after that)
3. Subsets inventory to your state
4. Calls `setwd()` to the project root
5. Sets global variables: `my.state`, `my.inventory`, `datafolder`, `figuresfolder`, `projectfolder`

```r
# Preferred (explicit path):
initialize_project("CA", path = "~/ClimateNarratives")

# Also works (auto-generates ~/ClimateNarratives_CA/):
initialize_project("CA")

# Custom server path:
initialize_project("TX", path = "/data/students/ClimateNarratives")
```

#### `set_config(state, path = NULL)`

Convenience alias for `initialize_project()`.

#### `check_dependencies(install = TRUE, quiet = FALSE)`

Checks every required package one by one and prints OK or MISS for each. With `install = TRUE` (default), installs any missing packages individually so you can see exactly which ones succeed or fail. v0.3.1 also verifies `mgcv` (suggested, for nonlinear diagnostics).

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

#### `MonthlyValues.fun(station, min_days_temp = 20, min_days_prcp = 25)` *(updated v0.3.1)*

Aggregates daily data to monthly: mean for TMAX/TMIN, sum for PRCP.

**New in v0.3.1:** Counts non-missing days per month-year and sets months with fewer than the threshold to NA. This prevents biased precipitation totals from incomplete months. Each output data frame includes an `n_days` column showing how many days were observed.

- **min_days_temp** — Minimum days for temperature elements (default 20). Set to 0 for v0.3.0 behavior.
- **min_days_prcp** — Minimum days for precipitation (default 25, stricter because `sum()` is sensitive to gaps).

**Why this matters:** `sum(na.rm=TRUE)` on 15 of 30 days produces roughly half the true monthly precipitation, creating a systematic downward bias in trend estimates.

#### `MonthlyNormals.fun(station, min_months_required = 12, min_years_per_month = 10, station_id = "unknown")`

Calculates climate normals with an automatic fallback cascade:

1. **1961–1990** (WMO standard)
2. **1971–2000** (if #1 lacks coverage)
3. **1981–2010** (if #2 lacks coverage)
4. **Full record** (last resort)

At each level, requires all 12 months to have at least `min_years_per_month` years of data. Prints a `message()` when using a non-standard period. Returns `NULL` with a `warning()` if no period has adequate data — the station is then skipped by downstream functions.

#### `MonthlyAnomalies.fun(station.monthly, station.normals, station_id = "unknown")`

Calculates anomalies (observed minus normal). Returns `NULL` with a warning if the normals are NULL or the merge produces empty results.

#### `monthlyTrend.fun(station.anomalies)`

Fits OLS linear regression trends per month per element. Each `lm()` call is wrapped in `tryCatch` so one bad month does not crash the whole station.

#### `monthlyTrend_robust.fun(station.anomalies)` *(new v0.3.1)*

Non-parametric alternative to `monthlyTrend.fun()`. Computes:

- **Theil-Sen slope:** median of all n*(n-1)/2 pairwise slopes (resistant to outliers)
- **Mann-Kendall test:** via `cor.test(method="kendall")` (rank-based significance, no normality assumption)

Returns: MONTH, ELEMENT, Estimate, tau, p.value, method, and significance stars (*, **, ***).

No additional packages required — uses base R `cor.test()`.

```r
# Called via process_all_stations:
trends <- process_all_stations(trend_method = "Theil-Sen")
```

#### `ExtremePrecp.fun(station, min_days_per_year = 330)` *(new v0.3.1)*

Calculates ETCCDI-style extreme precipitation indices per year:

| Index | Name | Description |
|-------|------|-------------|
| SDII | `intensity` | Mean precipitation on wet days (≥1mm), in mm/day |
| R25mm | `heavy_days` | Count of days with ≥25.4mm (1 inch) precipitation |
| Rx1day | `max_daily` | Annual maximum single-day precipitation, in mm |
| CDD | `dry_spell_max` | Longest consecutive run of dry days (<1mm) |
| — | `pct_heavy` | Fraction of annual total from heavy days (≥25.4mm) |

- **min_days_per_year** — Years with fewer observed days are excluded (default 330, requiring ~90% coverage)

Returns a data frame with one row per year and columns for each index. Trends on these indices are fitted by `.fit_extreme_trends()` (internal) using either OLS or Theil-Sen, matching the `trend_method` argument in `process_all_stations()`.

#### `nonlinearTrend.fun(station.anomalies, station.monthly)` *(new v0.3.1)*

Fits `mgcv::gam(anomaly ~ s(YEAR, k=10))` on annual anomalies for TMAX, TMIN, and PRCP.

Returns a named list with:

| Field | Description |
|-------|-------------|
| `edf` | Effective degrees of freedom: 1 ≈ linear, 2–3 = curvature, >4 = complex |
| `p_smooth` | p-value of the smooth term |
| `dev_explained` | Deviance explained (like R² but for GAMs) |
| `gcv` | Generalized cross-validation score |
| `linear_slope` | OLS slope for comparison |
| `smooth_range` | Range of fitted smooth (max minus min) |

Requires `mgcv` (ships with base R). If `mgcv` is not available, returns NULL with a warning.

#### `process_all_stations(verbose = TRUE, trend_method = "OLS", min_days_temp = 20, min_days_prcp = 25, compute_extreme_precip = FALSE, compute_nonlinear = FALSE)` *(updated v0.3.1)*

Runs the full pipeline (clean → normals → anomalies → trends) for every station. Skips stations that return NULL at any step and reports a summary at the end.

**New parameters in v0.3.1:**

- **trend_method** — `"OLS"` (default, backward compatible) or `"Theil-Sen"` (robust non-parametric)
- **min_days_temp** — Passed to `MonthlyValues.fun()` (default 20)
- **min_days_prcp** — Passed to `MonthlyValues.fun()` (default 25)
- **compute_extreme_precip** — If TRUE, runs `ExtremePrecp.fun()` and adds trend columns for each index
- **compute_nonlinear** — If TRUE, runs `nonlinearTrend.fun()` and adds GAM diagnostic columns

**Backward compatibility:** All defaults reproduce v0.3.0 behavior. New features are opt-in.

---

### Visualization

#### `create_spatial_objects(trends)`

Converts the trends data frame to spatial formats: `trends_sf` (sf, modern) and `trends_sp` (sp, for kriging). Both are assigned to the global environment.

#### `create_heatmap(trends_sp, trend_var, title, subtitle, state, colors = "temp", resolution = 0.1)` *(updated v0.3.1)*

Creates a kriged interpolation heat map.

- **trend_var** — Column name, e.g., `"annual_trend_TMAX"`, `"trend_intensity"`, `"winter_trend_PRCP"`
- **colors** — `"temp"` for blue-white-red diverging, `"precip"` for brown-white-green diverging
- **resolution** — Grid cell size in degrees (smaller = finer, but slower)

**v0.3.1 improvement:** Alaska uses `map_data("world2")` with 0–360° longitude to avoid date-line splitting; Hawaii uses `map_data("world")`. CONUS states are unchanged.

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

### Temperature (°C/century)

`annual_trend_TMAX`, `annual_trend_TMIN`, `winter_trend_TMAX`, `spring_trend_TMAX`, `summer_trend_TMAX`, `fall_trend_TMAX` (and corresponding TMIN versions)

### Precipitation (mm/century)

`annual_trend_PRCP`, `winter_trend_PRCP`, `spring_trend_PRCP`, `summer_trend_PRCP`, `fall_trend_PRCP`

### Extreme Precipitation (v0.3.1, requires `compute_extreme_precip = TRUE`)

| Variable | Units | Description |
|----------|-------|-------------|
| `trend_intensity` | mm/day per century | Change in mean wet-day precipitation |
| `trend_heavy_days` | days per century | Change in count of days ≥ 25.4mm |
| `trend_max_daily` | mm per century | Change in annual maximum daily precipitation |
| `trend_dry_spell_max` | days per century | Change in longest dry spell |
| `trend_pct_heavy` | fraction per century | Change in fraction of rain from heavy events |

### Nonlinear Diagnostics (v0.3.1, requires `compute_nonlinear = TRUE`)

| Variable | Description |
|----------|-------------|
| `gam_edf_TMAX` / `_TMIN` / `_PRCP` | Effective degrees of freedom (1=linear, >2=nonlinear) |
| `gam_dev_explained_TMAX` / `_TMIN` / `_PRCP` | Fraction of variance explained by smooth |
| `gam_smooth_range_TMAX` / `_TMIN` / `_PRCP` | Range of fitted smooth curve |

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
    ├── PRCP_intensity_CA.png            # (v0.3.1)
    ├── PRCP_heavy_CA.png               # (v0.3.1)
    └── Seasonal_TMAX_CA.png
```

---

## Version History

**v0.3.1** (current)
- Monthly completeness filtering in `MonthlyValues.fun()` — prevents biased precipitation trends from incomplete months (default: 20 days temp, 25 days precip)
- Theil-Sen / Mann-Kendall robust trends via `monthlyTrend_robust.fun()` — resistant to outliers, no normality assumption
- Extreme precipitation indices via `ExtremePrecp.fun()` — SDII, R25mm, Rx1day, CDD, pct_heavy
- GAM nonlinear diagnostics via `nonlinearTrend.fun()` — detect accelerating or decelerating trends
- Alaska/Hawaii map boundary fix — `create_heatmap()` now renders AK and HI with correct state outlines
- All new features opt-in via `process_all_stations()` parameters; defaults reproduce v0.3.0 behavior

**v0.3.0**
- Added `check_dependencies()` and startup dependency warnings
- `initialize_project()` auto-generates path from state code, sets working directory
- `MonthlyNormals.fun()` cascades through fallback periods (1961–1990 → 1971–2000 → 1981–2010 → full record)
- `MonthlyAnomalies.fun()` and `monthlyTrend.fun()` handle NULL inputs gracefully
- `install_package.R` installs dependencies one by one with clear pass/fail reporting
- Fixed NAMESPACE `st_as_sf` import

**v0.2.0**
- Added `process_all_stations()`, `create_spatial_objects()`, `create_heatmap()`
- NAMESPACE and spatial function fixes
- R 3.4+ compatibility

**v0.1.0**
- Initial package: converted script-based workflow to R package structure

---

## License

GPL-3
