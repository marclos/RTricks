# ClimateNarratives — Teacher Guide

**Version 0.3.1** | Deploying and supporting the package on RStudio Server  

---

## Overview

This guide covers how to install ClimateNarratives on your RStudio Server, what to tell students, what will go wrong, and how to fix it. It is organized around the actual sequence of problems you and your students will encounter.

---

## Before the Semester: Server Setup

### Option A: System-Wide Install (Recommended)

If you have admin/sudo access, install once for everyone:

```bash
# SSH into your server
cd /path/to/ClimateNarratives

# Install dependencies system-wide in R
Rscript -e 'source("install_package.R")'
```

This runs the v0.3.1 installer, which installs each dependency individually and reports pass/fail for each one. v0.3.1 adds `mgcv` as a suggested dependency (for nonlinear trend diagnostics). It ships with base R, so it should always be present. The installer now verifies this.

If `sf` or `gstat` fail (common — they need system libraries), you will see exactly which package failed and can install the system dependency:

```bash
# Ubuntu/Debian — common system libraries needed by sf and gstat
sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev
```

Then re-run `Rscript -e 'source("install_package.R")'`.

### Option B: Students Install Themselves

If students install to their own library (no admin needed), give them this sequence:

```r
# Step 1: Check and install dependencies (do this FIRST)
source("/path/to/ClimateNarratives/R/ClimateNarratives-package.R")
check_dependencies()

# Step 2: Install the package
devtools::install("/path/to/ClimateNarratives")
```

**The key insight for v0.3.0+:** Step 1 must happen before Step 2. In previous versions, students would jump straight to `devtools::install()`, a dependency would silently fail, and then `library(ClimateNarratives)` would crash. Now the installer catches this, and the `library()` startup message warns them if anything is still missing.

### Option C: From tar.gz (What Most Students Will Do)

Distribute the `ClimateNarratives_0.3.1.tar.gz` file (e.g., via your LMS). Students follow the Student Workflow Part 1, which walks them through uploading the file, installing dependencies, and installing the package. The key steps are:

```r
# In RStudio Console:
dir.create("~/ClimateNarratives_setup")
setwd("~/ClimateNarratives_setup")
# (upload tar.gz via RStudio Files pane)

install.packages(c(
  "dplyr", "tidyr", "ggplot2", "lubridate",
  "sp", "sf", "gstat", "raster", "stars",
  "viridis", "maps", "mapdata", "patchwork"
))

install.packages("ClimateNarratives_0.3.1.tar.gz", repos = NULL, type = "source")
library(ClimateNarratives)
```

### Option D: From GitHub

```r
devtools::install_github("YOUR_USERNAME/ClimateNarratives")
```

This works if your server has outbound internet access. Dependencies still need to be installed first — `install_github` will attempt to install them but may fail silently for packages needing system libraries.

---

## What Changed in v0.3.1 (For Instructors)

### 1. Monthly Completeness Filtering

**The problem:** `MonthlyValues.fun()` was using `sum(na.rm=TRUE)` for precipitation. A month with 15 of 30 observed days produced roughly half the true total. This biased anomalies negative and depressed trend estimates downward across all stations.

**The fix:** `MonthlyValues.fun()` now counts non-missing days per month and excludes months below a threshold (default: 20 days for temperature, 25 for precipitation). An `n_days` column in the output makes the filtering transparent.

**Impact on results:** Precipitation trends will change — typically becoming less negative or more positive, since the downward bias has been removed. Temperature trends change minimally since `mean()` on partial months is a much less biased estimator than `sum()`.

**For the classroom:** This is a good teaching moment about data quality. Ask students: "If you sum 15 days of rain instead of 30, what happens to the total? What does that do to the trend over 100 years?" The answer — it makes every incomplete month look artificially dry — illustrates why `na.rm=TRUE` is not always innocent.

### 2. Theil-Sen / Mann-Kendall Robust Trends

**The problem:** OLS regression assumes normally distributed, independent residuals. Climate time series violate both assumptions (serial autocorrelation inflates OLS significance; extreme events create heavy-tailed residuals, especially for precipitation).

**The fix:** `monthlyTrend_robust.fun()` computes the Theil-Sen slope (median of all pairwise slopes) and uses the Mann-Kendall test for significance. No additional packages required — base R provides `cor.test(method="kendall")`.

**Impact on results:** Trend magnitudes are usually similar to OLS but more stable. Significance stars will be more conservative (fewer stars). This is a *better* result, not a weaker one.

**For the classroom:** Comparing OLS and Theil-Sen results side by side is an excellent exercise in statistical reasoning. Students can run `process_all_stations()` twice — once with `trend_method = "OLS"` and once with `trend_method = "Theil-Sen"` — then plot one against the other and discuss why they differ.

### 3. Extreme Precipitation Indices

**The problem:** "Is it raining more?" is only one question. For many regions, total precipitation is flat but intensity is increasing — fewer rainy days, but heavier when it rains. The previous version could not distinguish these patterns.

**The fix:** `ExtremePrecp.fun()` computes ETCCDI-standard indices: SDII (intensity), R25mm (heavy-day count), Rx1day (max daily), CDD (dry spell length), and the fraction of annual rain from heavy events.

**Impact on results:** Students can now make maps of precipitation *intensity* and *frequency* trends separately from totals. This often reveals patterns that are invisible in total-only analysis.

**For the classroom:** Ask students to compare their `annual_trend_PRCP` map with their `trend_intensity` map. In many states, total precipitation is nearly flat but intensity is clearly increasing — a hallmark of climate change's effect on the water cycle.

### 4. GAM Nonlinear Diagnostics

**The problem:** A linear trend over 100+ years may miss important structure — warming that was flat from 1920–1970 and steep from 1970–2020 will appear as a moderate linear trend that misrepresents both periods.

**The fix:** `nonlinearTrend.fun()` fits a GAM smooth using `mgcv::gam()` and reports the effective degrees of freedom (edf). An edf near 1 means the trend is genuinely linear; higher values indicate curvature.

**For the classroom:** Students can identify which stations show "accelerating" warming (edf > 2) and discuss what might cause it (urbanization, land use change, feedback loops, global forcing changes).

### 5. Alaska and Hawaii Map Boundaries

**The problem:** `create_heatmap()` used `map_data("state")`, which only contains the contiguous 48 states. Alaska and Hawaii maps rendered without any boundary polygon.

**The fix:** A new internal helper `.get_state_border()` dispatches to the correct map database: `world2` for Alaska (avoids date-line splitting), `world` for Hawaii, `state` for CONUS. No student-facing changes — it just works.

**Impact:** Students assigned AK or HI will now get proper maps with visible state boundaries.

---

## Week-by-Week Teaching Plan

### Week 1: Setup and Download

**Student task:** Install package, initialize project, select stations, start download.

**What to assign:**

```r
library(ClimateNarratives)
initialize_project("XX")     # their assigned state
select_stations(n = 50)
download_stations()           # let this run — takes 10-30 min
load_and_save_stations()
```

**What will go wrong:**

1. **"there is no package called 'sf'"** or similar at `library()` time — The v0.3.1 startup message tells them exactly what to run. Have them do `check_dependencies()`.

2. **Students close RStudio while downloading** — Not a problem. `download_stations()` checks for existing files. They just re-run it.

3. **NOAA server is slow or down** — Occasionally NOAA is unresponsive. The function reports failures. Just retry later.

4. **Disk quota** — Each state is 100–500 MB. If your server has tight quotas, have students use `load_and_save_stations(cleanup = TRUE)` to delete the raw CSVs after converting to RData. This typically frees 60–80% of the space.

5. **`file.exists()` returns FALSE** — They uploaded the file to the wrong folder, or didn't run `setwd()`. Have them check `getwd()` and the Files pane.

**Tip:** Assign small states (RI, DE, CT) for initial testing. California and Texas have many stations and take longer.

**Where students can stop and learn:** After `initialize_project()`, have students run `head(my.inventory)` and discuss what the columns mean (station ID, coordinates, elevation, years of record). This is their first exposure to real scientific data in R.

### Week 2: Processing and Exploration

**Student task:** Load saved data, explore individual stations, understand the data structure.

```r
library(ClimateNarratives)
initialize_project("XX")     # re-run to set paths (fast — inventory is cached)
load_stations()               # loads the RData file

# Explore a station
names(station_list)[1:5]     # see station IDs
head(station_list[[1]])      # look at raw data

# Clean one station manually
stn <- station_list[[1]]
stn <- fixDates.fun(stn)
stn <- fixValues.fun(stn)
head(stn)
```

**What will go wrong:**

1. **"Variable 'datafolder' not found"** — They forgot to run `initialize_project()`. This is the single most common error. Emphasize: every new R session starts with `library()` then `initialize_project()`.

2. **"RData file not found"** — They didn't finish Week 1 properly. Have them re-run `download_stations()` then `load_and_save_stations()`.

**Where students can stop and learn:**

- `str(station_list[[1]])` — shows the structure of a data frame (types, dimensions)
- `table(station_list[[1]]$ELEMENT)` — how many records per element type (TMAX, TMIN, PRCP, etc.)
- `range(stn$YEAR)` — the span of years covered
- `coverage.fun(stn, "TMAX")` vs `coverage.fun(stn, "PRCP")` — why do they differ?

### Week 3: Analysis

**Student task:** Calculate trends using both methods.

```r
# Standard OLS (for comparison and learning)
trends_ols <- process_all_stations()
summary(trends_ols$annual_trend_TMAX)

# Robust analysis with everything
trends <- process_all_stations(
  trend_method = "Theil-Sen",
  compute_extreme_precip = TRUE,
  compute_nonlinear = TRUE
)
summary(trends$annual_trend_TMAX)
```

**What will go wrong:**

1. **Warning messages about normals periods** — Expected and handled. The package prints messages like `"Station USC00123456: Normals period = 1971-2000 (1961-1990 had insufficient data)"`. Tell students this is informational, not an error. The station is still included using the best available baseline period.

2. **Warning messages about skipped stations** — Also expected. Some stations genuinely don't have enough data for reliable normals. The package skips them and reports how many were processed vs. skipped. If more than ~10 stations are skipped, the student may want to run `select_stations()` again with `min_years = 70` to get better-quality stations.

3. **Students confused by different trend values:** OLS and Theil-Sen produce slightly different numbers. Explain that Theil-Sen is the *better* estimate because it handles outliers and autocorrelation; OLS is taught in intro stats and easier to explain, but makes assumptions that climate data violates.

4. **Extreme precip columns have NAs:** Some stations don't have 330+ days of precipitation data per year. Those stations get NA for extreme indices. This is correct behavior.

5. **"Package 'mgcv' not available":** Very unlikely since mgcv ships with R. If it happens: `install.packages("mgcv")`. The function degrades gracefully (skips nonlinear analysis with a warning).

**Where students can stop and learn:**

- `names(trends)` — see all the columns produced
- `plot(trends_ols$annual_trend_TMAX, trends$annual_trend_TMAX)` + `abline(0,1)` — visual comparison of OLS vs Theil-Sen
- `cor(trends_ols$annual_trend_TMAX, trends$annual_trend_TMAX, use = "complete.obs")` — how correlated are the two methods?
- `hist(trends$gam_edf_TMAX)` — distribution of nonlinearity across stations

### Week 4: Visualization

**Student task:** Create heat maps for their narrative video.

```r
create_spatial_objects(trends)

# Standard maps
map_tmax <- create_heatmap(trends_sp, "annual_trend_TMAX",
                           paste(my.state, "Annual Maximum Temperature Trend"),
                           state = my.state)
ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map_tmax, width = 10, height = 8, dpi = 300)

# New: precipitation intensity
map_intensity <- create_heatmap(trends_sp, "trend_intensity",
                                paste(my.state, "Precip Intensity Trend"),
                                state = my.state, colors = "precip")
ggsave(paste0(figuresfolder, "PRCP_intensity_", my.state, ".png"),
       map_intensity, width = 10, height = 8, dpi = 300)
```

**What will go wrong:**

1. **Heatmap looks blocky or has artifacts** — Need more stations. 20 is the minimum for passable kriging; 50 is good.

2. **"file not found" on ggsave** — In v0.3.1 this should not happen because `initialize_project()` sets the working directory and uses relative paths. If it does happen, they likely changed their working directory manually. Have them re-run `initialize_project("XX")`.

3. **"Variable 'trend_intensity' not found"** — They ran `process_all_stations()` without `compute_extreme_precip = TRUE`. Have them re-run with the flag.

4. **Extreme precip map looks sparse** — If many stations lack good daily coverage, the kriging will be based on fewer points. Recommend `resolution = 0.15` or `0.2` for sparser data.

**Where students can stop and learn:**

- `print(map_tmax)` in the console, then click Zoom in Plots pane — explore the kriged surface
- Navigate to `Figures/` in the Files pane and click on saved PNGs — confirm they saved
- Try `map_tmax + ggplot2::labs(caption = "Data: NOAA GHCN-Daily")` — learn about adding labels

---

## Common Error Messages and What They Mean

| Error | Cause | Fix |
|-------|-------|-----|
| `there is no package called 'X'` | Missing dependency | `check_dependencies()` |
| `Run initialize_project() first!` | Forgot setup at session start | `initialize_project("XX")` |
| `RData file not found` | Didn't finish download/save | `download_stations()` then `load_and_save_stations()` |
| `No stations found for state: XX` | Invalid state code | Check the printed list of valid codes |
| `Station USC00...: Cannot compute normals` | Not enough data for any period | Expected — station is skipped |
| `Normals period = 1971-2000` | 1961–1990 had gaps | Informational only — not an error |
| `Fewer stations available than requested` | State has few long-record stations | Lower `n` or `min_years` in `select_stations()` |
| `object 'trends_sp' not found` | Didn't run spatial conversion | `create_spatial_objects(trends)` |
| `Variable 'trend_intensity' not found` | Didn't enable extreme precip | `process_all_stations(compute_extreme_precip = TRUE)` |
| `Variable 'gam_edf_TMAX' not found` | Didn't enable nonlinear | `process_all_stations(compute_nonlinear = TRUE)` |
| `Package 'mgcv' not available` | mgcv not installed (unusual) | `install.packages("mgcv")` |

---

## State-Specific Notes

### States That Work Well (50+ long-record stations)
CA, TX, NY, PA, OH, IL, IN, NC, GA, VA, MI, MO, WI, MN, IA, KS, NE, OK, TN, KY, AL, SC, MA, CO, OR, WA

### States That Need Adjusted Parameters
- **AK, HI:** Many stations started after 1961. The normals cascade handles this, but expect more fallback messages. Use `min_years = 30`. **v0.3.1:** Map boundaries now display correctly.
- **NV, WY, MT, NM, ND, SD:** Sparse station networks. Use `n = 30` instead of 50. Heat maps will be coarser.
- **RI, DE, CT:** Very small states. 20–30 stations is plenty. Kriging resolution of 0.05 works well.

### States Where Students See Interesting Patterns
- **CA:** Strong warming trend, especially inland; coastal moderation visible. Precipitation intensity increasing despite flat totals.
- **TX:** Pronounced summer warming; regional precipitation variation. Heavy-rain days increasing in eastern TX.
- **CO:** Elevation-dependent warming. GAM edf > 2 at many stations (accelerating trend).
- **FL:** Minimal TMAX trend but TMIN warming (nighttime urbanization effect). Precipitation intensity increasing.
- **NY, PA:** Extreme precipitation indices show clear upward trends even where total precipitation is nearly flat.

---

## Updating the Package

When you make changes to the R source files:

```r
# From the package directory
roxygen2::roxygenize()     # regenerate docs
devtools::install()        # reinstall

# If on GitHub
# git add . && git commit -m "description" && git push
```

Students update by re-uploading the new tar.gz and reinstalling. The `install_package.R` script handles detaching the old version automatically:

```r
setwd("~/ClimateNarratives_setup")
source("install_package.R")   # detaches old version, installs deps, reinstalls
```

If students install directly instead:

```r
detach("package:ClimateNarratives", unload = TRUE)  # unload old version
setwd("~/ClimateNarratives_setup")
install.packages("ClimateNarratives_0.3.1.tar.gz", repos = NULL, type = "source")
library(ClimateNarratives)
```

The `detach()` call removes the old package namespace from memory so that `library()` picks up the newly installed version. Students keep all their global environment variables (`my.state`, `station_list`, `trends`, etc.) since those live in `.GlobalEnv`, not in the package namespace. If ClimateNarratives is not currently loaded, the `detach()` will error harmlessly — students can skip it.

---

## Assessment Ideas

### Formative (Weekly Check-ins)
- Screenshot of `initialize_project()` output showing station count
- `summary(trends$annual_trend_TMAX)` output pasted into a discussion post
- One heat map uploaded to the LMS
- **New:** `summary()` of both OLS and Theil-Sen trends to compare

### Summative (Final Product)
- 3–5 minute narrated video interpreting their state's climate trends
- At least three heat maps (TMAX, TMIN, and one of: PRCP/intensity/heavy days)
- **New:** Discussion of whether precipitation is getting more intense (not just whether totals are changing)
- **New:** Comparison of OLS vs Theil-Sen trends (which is more appropriate and why?)
- Written reflection comparing their findings to published climate data (e.g., National Climate Assessment)

### R Skills Demonstrated
- Package installation and environment management
- Data filtering and quality assessment
- Linear regression interpretation (trend slope, p-value, R²)
- **New:** Non-parametric statistics (Theil-Sen, Mann-Kendall)
- **New:** Understanding of data completeness and bias (why `sum(na.rm=TRUE)` on incomplete months is dangerous)
- Spatial data handling and visualization
- Reproducible workflow (script runs top to bottom)

---

## Key Design Decisions (Why Things Work This Way)

**Why global variables instead of an object?**  
Students find `my.state` easier than `project$state`. The package uses `assign(..., envir = .GlobalEnv)` so variables appear in the Environment pane. This is deliberate — pedagogical clarity over software engineering purity.

**Why `setwd()` in `initialize_project()`?**  
Students do not reliably edit file paths. By setting the working directory and using relative paths (`"Data/"`, `"Figures/"`), every `ggsave()` call just works without students modifying anything.

**Why the normals cascade?**  
The original code checked `nrow == 0` for 1961–1990 and fell back to the full record. But many stations have *some* data in that window — just not enough for all 12 months. This produced NaN anomalies that crashed `lm()` downstream. The cascade checks actual month-by-month coverage and tries progressively newer standard periods before falling back to the full record.

**Why install dependencies one-by-one?**  
`install.packages(c("sf", "gstat", ...))` stops at the first failure and the error scrolls off screen. Students see 200 lines of output, miss the error, and move on. Installing one at a time with OK/FAILED per package makes the problem impossible to miss.

**Why completeness filtering instead of imputation? (v0.3.1)**  
Imputation (filling in missing days) adds complexity students don't need and introduces its own biases. Simply excluding incomplete months is transparent, conservative, and easy to explain. The `n_days` column lets students see exactly what was filtered.

**Why Theil-Sen instead of other robust methods? (v0.3.1)**  
Theil-Sen is the simplest robust slope estimator to explain ("median of all pairwise slopes"). It requires no extra packages. The `trend` or `modifiedmk` packages add pre-whitening for autocorrelation, but the added complexity is not justified for this teaching context.

**Why not require mgcv? (v0.3.1)**  
Although mgcv ships with every R installation, listing it as Suggested (not Required) means the package still installs and runs even if mgcv is somehow absent. The `nonlinearTrend.fun()` function checks at runtime and skips gracefully if missing.

**Why these extreme precip indices? (v0.3.1)**  
The ETCCDI also defines percentile-based indices (R95p, R99p) that require a baseline distribution. These are powerful but harder to explain and more prone to edge-case errors with incomplete baselines. SDII, R25mm, Rx1day, and CDD are intuitive, widely used in published literature, and do not require a baseline.

---

## Troubleshooting Checklist

If a student says "it doesn't work," walk through this:

1. `library(ClimateNarratives)` — Does it load? If not → `check_dependencies()`
2. `initialize_project("XX")` — Does it run? If not → check internet (first time only)
3. `getwd()` — Is it pointing to the project folder? If not → re-run `initialize_project()`
4. `ls()` — Do they see `my.state`, `datafolder`, etc.? If not → they're in a different session
5. `nrow(my.inventory)` — Do they have stations? If 0 → check state code
6. `list.files("Data/")` — Is the RData file there? If not → need to download/save
7. `"trend_intensity" %in% names(trends)` — Did they enable extreme precip? If FALSE → re-run with flag
8. `file.exists(paste0(figuresfolder, "test.txt"))` — Can they write to Figures/? Check permissions.

---

## Contact and Resources

- Package source: `YOUR_GITHUB_URL`
- NOAA GHCN-D documentation: https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily
- National Climate Assessment: https://nca2023.globalchange.gov/
- ETCCDI Climate Extremes Indices: http://etccdi.pacificclimate.org/list_27_indices.shtml
