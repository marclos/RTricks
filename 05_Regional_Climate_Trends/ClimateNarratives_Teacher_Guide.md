# ClimateNarratives — Teacher Guide

**Version 0.3.0** | Deploying and supporting the package on RStudio Server  

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

This runs the v0.3.0 installer, which installs each dependency individually and reports pass/fail for each one. If `sf` or `gstat` fail (common — they need system libraries), you will see exactly which package failed and can install the system dependency:

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

**The key insight for v0.3.0:** Step 1 must happen before Step 2. In previous versions, students would jump straight to `devtools::install()`, a dependency would silently fail, and then `library(ClimateNarratives)` would crash. Now the installer catches this, and the `library()` startup message warns them if anything is still missing.

### Option C: From GitHub

```r
devtools::install_github("YOUR_USERNAME/ClimateNarratives")
```

This works if your server has outbound internet access. Dependencies still need to be installed first — `install_github` will attempt to install them but may fail silently for packages needing system libraries.

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

1. **"there is no package called 'sf'"** or similar at `library()` time — The v0.3.0 startup message now tells them exactly what to run. Have them do `check_dependencies()`.

2. **Students close RStudio while downloading** — Not a problem. `download_stations()` checks for existing files. They just re-run it.

3. **NOAA server is slow or down** — Occasionally NOAA is unresponsive. The function reports failures. Just retry later.

4. **Disk quota** — Each state is 100–500 MB. If your server has tight quotas, have students use `load_and_save_stations(cleanup = TRUE)` to delete the raw CSVs after converting to RData. This typically frees 60–80% of the space.

**Tip:** Assign small states (RI, DE, CT) for initial testing. California and Texas have many stations and take longer.

### Week 2: Processing and Exploration

**Student task:** Load saved data, explore individual stations, understand the data structure.

```r
library(ClimateNarratives)
initialize_project("XX")     # re-run to set paths (fast — inventory is cached)
load_stations()               # loads the RData file

# Explore a station
names(station_list)[1:5]     # see station IDs
head(station_list[[1]])      # look at raw data
```

**What will go wrong:**

1. **"Variable 'datafolder' not found"** — They forgot to run `initialize_project()`. This is the single most common error. Emphasize: every new R session starts with `library()` then `initialize_project()`.

2. **"RData file not found"** — They didn't finish Week 1 properly. Have them re-run `download_stations()` then `load_and_save_stations()`.

### Week 3: Analysis

**Student task:** Calculate trends.

```r
trends <- process_all_stations()
summary(trends$annual_trend_TMAX)
```

**What will go wrong:**

1. **Warning messages about normals periods** — This is expected and handled in v0.3.0. The package prints messages like `"Station USC00123456: Normals period = 1971-2000 (1961-1990 had insufficient data)"`. Tell students this is informational, not an error. The station is still included in the analysis using the best available baseline period.

2. **Warning messages about skipped stations** — Also expected. Some stations genuinely don't have enough data for reliable normals. The package skips them and reports how many were processed vs. skipped. If more than ~10 stations are skipped, the student may want to run `select_stations()` again with `min_years = 70` to get better-quality stations.

3. **"Processed 35/50 stations" (many skipped)** — Happens with states that have young station networks (AK, HI) or sparse coverage. Lower `min_years_per_month` to 5 if needed: this is a parameter in `MonthlyNormals.fun()`, but changing it requires editing the `process_all_stations()` call.

### Week 4: Visualization

**Student task:** Create heat maps for their narrative video.

```r
create_spatial_objects(trends)

map <- create_heatmap(trends_sp, "annual_trend_TMAX",
                      paste(my.state, "Annual Maximum Temperature Trend"),
                      state = my.state)

# Save — this just works because initialize_project() set the working directory
ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map, width = 10, height = 8, dpi = 300)
```

**What will go wrong:**

1. **Heatmap looks blocky or has artifacts** — Need more stations. 20 is the minimum for passable kriging; 50 is good.

2. **"file not found" on ggsave** — In v0.3.0 this should not happen because `initialize_project()` sets the working directory and uses relative paths. If it does happen, they likely changed their working directory manually. Have them re-run `initialize_project("XX")`.

3. **"cannot find function create_heatmap"** — This function may not be in the current R/ files (it's referenced in docs but may be in a separate file not yet in the project). If so, students need the visualization.R source file.

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

---

## State-Specific Notes

### States That Work Well (50+ long-record stations)
CA, TX, NY, PA, OH, IL, IN, NC, GA, VA, MI, MO, WI, MN, IA, KS, NE, OK, TN, KY, AL, SC, MA, CO, OR, WA

### States That Need Adjusted Parameters
- **AK, HI:** Many stations started after 1961. The normals cascade handles this, but expect more fallback messages. Use `min_years = 30`.
- **NV, WY, MT, NM, ND, SD:** Sparse station networks. Use `n = 30` instead of 50. Heat maps will be coarser.
- **RI, DE, CT:** Very small states. 20–30 stations is plenty. Kriging resolution of 0.05 works well.

### States Where Students See Interesting Patterns
- **CA:** Strong warming trend, especially inland; coastal moderation visible
- **TX:** Pronounced summer warming; regional precipitation variation
- **CO:** Elevation-dependent warming
- **FL:** Minimal TMAX trend but TMIN warming (nighttime urbanization effect)

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

Students update with:

```r
devtools::install_github("YOUR_USERNAME/ClimateNarratives")
# or if from local source:
devtools::install("/path/to/ClimateNarratives")
```

---

## Assessment Ideas

### Formative (Weekly Check-ins)
- Screenshot of `initialize_project()` output showing station count
- `summary(trends$annual_trend_TMAX)` output pasted into a discussion post
- One heat map uploaded to the LMS

### Summative (Final Product)
- 3–5 minute narrated video interpreting their state's climate trends
- At least three heat maps (TMAX, TMIN, PRCP or seasonal comparison)
- Written reflection comparing their findings to published climate data (e.g., National Climate Assessment)

### R Skills Demonstrated
- Package installation and environment management
- Data filtering and quality assessment
- Linear regression interpretation (trend slope, p-value, R²)
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

---

## Troubleshooting Checklist

If a student says "it doesn't work," walk through this:

1. `library(ClimateNarratives)` — Does it load? If not → `check_dependencies()`
2. `initialize_project("XX")` — Does it run? If not → check internet (first time only)
3. `getwd()` — Is it pointing to the project folder? If not → re-run `initialize_project()`
4. `ls()` — Do they see `my.state`, `datafolder`, etc.? If not → they're in a different session
5. `nrow(my.inventory)` — Do they have stations? If 0 → check state code
6. `list.files("Data/")` — Is the RData file there? If not → need to download/save
7. `file.exists(paste0(figuresfolder, "test.txt"))` — Can they write to Figures/? Check permissions.

---

## Contact and Resources

- Package source: `YOUR_GITHUB_URL`
- NOAA GHCN-D documentation: https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily
- National Climate Assessment: https://nca2023.globalchange.gov/
