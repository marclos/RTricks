# ClimateNarratives — Student Workflow

**Version 0.3.1** | Step-by-step guide to analyzing climate trends in R  
**Revision Date:** February 10, 2026

---

## Before You Start

You need:

- Access to RStudio Server (your instructor will provide the URL and login)
- The file **`ClimateNarratives_0.3.1.tar.gz`** (your instructor will provide this)
- Your assigned **two-letter state code** (e.g., `CA` for California, `TX` for Texas, `AK` for Alaska)
- An internet connection (the server needs it to download weather data from NOAA)

---

## Part 1: Install the Package (Do This Once, the Very First Time)

You only do Part 1 once. After the package is installed, you never need to repeat these steps.

### Step 1 — Log in to RStudio Server

Open your web browser and go to the RStudio Server URL your instructor gave you. Log in with your username and password. You should see the RStudio interface with a Console pane on the left.

### Step 2 — Create a folder for the installer

In the **Console** (bottom left pane), type this exactly and press Enter:

```r
dir.create("~/ClimateNarratives_setup")
```

This creates a folder in your home directory to hold the installer file.

**Check:** In the **Files** pane (bottom right of RStudio), click the Home icon (the little house). You should see a folder called `ClimateNarratives_setup`.

> **Learning note:** `dir.create()` is an R function that creates a new folder on disk. The `~` symbol means "my home directory" — it is a shortcut so you don't need to type the full path. You will see `~` used throughout R and Linux.

### Step 3 — Upload the tar.gz file

1. In the **Files** pane (bottom right), click into the `ClimateNarratives_setup` folder
2. Click the **Upload** button (it has an upward arrow icon)
3. Click **Choose File** and select the `ClimateNarratives_0.3.1.tar.gz` file from your computer
4. Click **OK**

**Check:** You should now see `ClimateNarratives_0.3.1.tar.gz` listed in the Files pane inside the `ClimateNarratives_setup` folder.

### Step 4 — Point R at that folder

In the **Console**, type:

```r
setwd("~/ClimateNarratives_setup")
```

Then verify the file is there:

```r
file.exists("ClimateNarratives_0.3.1.tar.gz")
```

This **must** print `TRUE`. If it prints `FALSE`:

- Did you upload the file? (Go back to Step 3.)
- Did you upload it into the `ClimateNarratives_setup` folder, or somewhere else? Check the Files pane.
- Did you type the `setwd(...)` line? Run `getwd()` to see where R is looking.

**Do not continue until `file.exists(...)` returns `TRUE`.**

> **Learning note:** `setwd()` stands for "set working directory." It tells R which folder to look in when you reference files by name. `getwd()` ("get working directory") shows you where R is currently looking. When `file.exists()` returns FALSE, it usually means R is looking in the wrong folder.

### Step 5 — Install the required packages (dependencies)

ClimateNarratives needs several other R packages to work. Install them first. Copy and paste this entire block into the Console and press Enter:

```r
install.packages(c(
  "dplyr", "tidyr", "ggplot2", "lubridate",
  "sp", "sf", "gstat", "raster", "stars",
  "viridis", "maps", "mapdata", "patchwork"
))
```

This takes several minutes. You will see a lot of text scrolling by — that is normal. Wait until you see the `>` prompt again before continuing.

**Check:** After it finishes, look for any lines containing `had non-zero exit status`. That means a package failed to install. If you see it, note the package name and try installing it individually:

```r
install.packages("sf")      # replace with whichever package failed
```

If a package keeps failing, tell your instructor — it may need a system library installed on the server.

> **Learning note:** R packages are collections of code that other people wrote and shared. They extend what R can do. The `c()` function creates a vector (a list of items). Here we're passing a vector of package names to `install.packages()`. Each package brings different capabilities: `ggplot2` makes plots, `sf` handles spatial data, `gstat` does kriging interpolation, and so on.

### Step 6 — Install ClimateNarratives

Now install the actual package. Type:

```r
install.packages("ClimateNarratives_0.3.1.tar.gz", repos = NULL, type = "source")
```

Wait for it to finish. The last lines should include:

```
* DONE (ClimateNarratives)
```

**If you see `ERROR` or `had non-zero exit status` instead:**
Read the error message. It usually names a missing package. Go back to Step 5 and install that package, then try Step 6 again.

> **Learning note:** The `repos = NULL` argument tells R "don't look online — install from this local file instead." The `type = "source"` tells R this is raw source code that needs to be compiled, not a pre-built binary.

### Step 7 — Verify it works

Load the package:

```r
library(ClimateNarratives)
```

You should see this startup message:

```
===========================================================
 ClimateNarratives v0.3.1
===========================================================
 Regional Climate Trends Analysis and Visualization
 Type ?ClimateNarratives for help
===========================================================
```

**If you see a `!!!` warning about missing packages instead**, run `check_dependencies()`, then try `library(ClimateNarratives)` again.

**If the startup message shows `v0.3.1`, Part 1 is done. The package is installed permanently on the server. You will not need to repeat Part 1.**

> **Learning note:** `library()` loads a package into your current R session so you can use its functions. This is different from `install.packages()`, which puts the package on disk. You only install once, but you run `library()` every time you start a new R session.

---

## Part 2: Download Your State's Data (Do This Once Per State)

### Step 8 — Initialize your project

```r
initialize_project("XX")
```

Replace `XX` with your state code. For example:

```r
initialize_project("CA")   # California
initialize_project("TX")   # Texas
initialize_project("NY")   # New York
initialize_project("AK")   # Alaska
```

**What this does:**

- Creates a project folder in your home directory (e.g., `~/ClimateNarratives_CA/`)
- Creates `Data/`, `Output/`, and `Figures/` subfolders inside it
- Downloads a list of available weather stations from NOAA
- Changes your working directory to the project folder (you do NOT need to call `setwd()` yourself)

You should see output ending with `Setup Complete!` and a count of potential stations.

**Pause and explore:** After this step, look at what was created:

```r
getwd()                    # Should show ~/ClimateNarratives_XX/
list.files()               # Should show Data, Figures, Output folders
ls()                       # Should show my.state, my.inventory, etc.
nrow(my.inventory)         # How many potential stations?
head(my.inventory)         # What does the station data look like?
```

> **Learning note:** `ls()` lists all variables currently in your R environment (the "workspace"). `head()` shows the first 6 rows of a data frame — a very useful way to peek at data without printing thousands of rows. `nrow()` counts rows. These are functions you will use constantly in R.

### Step 9 — Select stations

```r
select_stations(n = 50)
```

This picks the 50 stations with the longest, most complete records in your state.

**Pause and explore:** What stations were selected?

```r
nrow(my.inventory)                       # Should now be 50 (or fewer)
summary(my.inventory$RECORD_LENGTH)      # How long are these records?
head(my.inventory[, c("ID", "NAME", "FIRSTYEAR", "LASTYEAR")])
```

> **Learning note:** `summary()` gives you the min, max, median, mean, and quartiles of a numeric vector. The `$` operator extracts a single column from a data frame: `my.inventory$RECORD_LENGTH` pulls out just the record-length column. The `[, c(...)]` notation selects specific columns by name.

### Step 10 — Download data from NOAA

```r
download_stations()
```

**This takes 10–30 minutes.** You will see progress for each station. You can keep working in another browser tab while it runs.

If it gets interrupted (connection drops, you close your laptop, etc.), just run `download_stations()` again — it skips stations already downloaded.

### Step 11 — Save data in efficient format

```r
load_and_save_stations(cleanup = TRUE)
```

This converts the downloaded files into a single compressed file that loads much faster in the future. Setting `cleanup = TRUE` deletes the temporary files to save disk space.

**Pause and explore:** What is in your Data folder now?

```r
list.files("Data/")                     # See all data files
file.info("Data/all_stations_raw.RData")$size / 1024^2  # File size in MB
```

**Part 2 is done.** Your data is saved to disk and ready for analysis.

---

## Part 3: Analysis and Visualization

### What to do every time you open RStudio

When your R session ends (you log out, your session times out, or you restart R), all variables in memory are erased. Your files on disk are fine — they are saved permanently. But R needs to reload them.

**Every time you start a new R session, run these three lines first:**

```r
library(ClimateNarratives)
initialize_project("XX")     # your state code — e.g., "CA"
load_stations()
```

What each line does:

- `library(ClimateNarratives)` — loads the package functions (they are not available until you do this)
- `initialize_project("XX")` — sets your working directory to `~/ClimateNarratives_XX/` and creates the path variables (`datafolder`, `figuresfolder`). **This replaces any need to call `setwd()` yourself.**
- `load_stations()` — loads your previously saved weather data from the `Data/` folder back into memory

You do NOT need to:

- Call `setwd()` — `initialize_project()` handles it
- Re-download anything — your data is still on disk
- Re-install the package — it is already installed

### Step 12 — Explore a single station (optional but recommended)

Before running the full analysis, it helps to look at what one station's raw data looks like:

```r
# See station names
names(station_list)[1:5]

# Look at raw data for the first station
head(station_list[[1]])

# Clean one station manually to understand the pipeline
one_station <- station_list[[1]]
one_station <- fixDates.fun(one_station)     # adds Ymd, MONTH, YEAR columns
one_station <- fixValues.fun(one_station)     # converts tenths to real units
head(one_station)

# Check data coverage
coverage.fun(one_station, "TMAX")
coverage.fun(one_station, "PRCP")
```

> **Learning note:** `station_list` is a *named list* — a special R data structure where each element has a name (here, the station ID) and contains a data frame. The `[[1]]` notation extracts the first element. You can also use `station_list[["USC00045123"]]` to extract by name.

### Step 13 — Calculate climate trends

**Basic analysis (OLS regression — same as v0.3.0):**

```r
trends <- process_all_stations()
```

**Full v0.3.1 analysis with all new features:**

```r
trends <- process_all_stations(
  trend_method = "Theil-Sen",        # robust non-parametric trends
  compute_extreme_precip = TRUE,      # precipitation intensity indices
  compute_nonlinear = TRUE            # detect nonlinear warming
)
```

This runs the full analysis: cleaning dates, converting units, filtering incomplete months, calculating anomalies, and fitting trend lines. It takes a minute or two.

**You may see messages like:**

- `"Station USC00045123: Normals period = 1971-2000"` — This is normal. That station did not have enough data in the standard 1961–1990 baseline period, so the package used a different 30-year window. The station is still included.
- `"Station USC00067890: Cannot compute normals... Skipping."` — That station did not have enough data for any baseline period. It is excluded. A few skipped stations is expected.

**Pause and explore the results:**

```r
cat("Stations analyzed:", nrow(trends), "\n")
names(trends)                             # What columns are available?
summary(trends$annual_trend_TMAX)         # Temperature trends

# Compare OLS vs Theil-Sen (if you used Theil-Sen)
# Run OLS version first for comparison:
# trends_ols <- process_all_stations(trend_method = "OLS")
# plot(trends_ols$annual_trend_TMAX, trends$annual_trend_TMAX,
#      xlab = "OLS trend", ylab = "Theil-Sen trend")
# abline(0, 1, lty = 2)   # 1:1 line
```

> **Learning note:** `names()` shows all column names in a data frame. `summary()` on a numeric column gives the five-number summary plus the mean. The `#` character makes everything after it a comment — R ignores it. Comments are essential for documenting what your code does.

**What the v0.3.1 options do:**

- **`trend_method = "Theil-Sen"`** — Instead of fitting a straight line through the data (ordinary least-squares regression), this computes the *median of all pairwise slopes*. This means a single extreme year cannot pull the trend up or down. The significance test used is Mann-Kendall (rank-based), which is better suited to climate data than the OLS t-test because it does not assume the residuals are normally distributed.

- **`compute_extreme_precip = TRUE`** — Calculates whether rainfall is getting *more intense* even if annual totals are not changing. Computes: average rainfall on wet days (intensity), count of heavy-rain days (≥25mm), wettest day per year, and longest dry spell. These are standard climate extreme indices used in the published literature.

- **`compute_nonlinear = TRUE`** — Fits a smooth curve (GAM) instead of a straight line. If the curve is nearly straight, the "effective degrees of freedom" (edf) will be close to 1. If warming is *accelerating*, edf will be higher (2–4). This tells you whether a linear trend is a good summary or whether something more complex is happening.

**Explore the new columns:**

```r
# If you used compute_extreme_precip = TRUE:
summary(trends$trend_intensity)       # mm/day per century change
summary(trends$trend_heavy_days)      # heavy-day count per century change
summary(trends$trend_max_daily)       # max daily precip per century change
summary(trends$trend_dry_spell_max)   # dry spell length per century change

# If you used compute_nonlinear = TRUE:
summary(trends$gam_edf_TMAX)          # 1 = linear, >2 = nonlinear
summary(trends$gam_edf_TMIN)
summary(trends$gam_dev_explained_TMAX)  # How much variance explained
```

### Step 14 — Create spatial objects

```r
create_spatial_objects(trends)
```

This converts your trend data into a spatial format that can be mapped. It creates two objects:

- `trends_sf` — Simple Features format (modern R spatial)
- `trends_sp` — SpatialPointsDataFrame (needed for kriging)

> **Learning note:** "Spatial data" means data that has geographic coordinates (latitude, longitude) attached. The `sf` and `sp` packages provide two different ways to represent this in R. We need both: `sf` for modern spatial operations, and `sp` for the `gstat` kriging functions.

### Step 15 — Make heat maps

**Annual maximum temperature trend:**

```r
map_tmax <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMAX",
  title = paste(my.state, "- Annual Maximum Temperature Trend"),
  subtitle = "Change in degrees C per 100 years",
  state = my.state,
  colors = "temp"
)
print(map_tmax)
```

The plot appears in the **Plots** pane (bottom right of RStudio). You can click the **Zoom** button to see it larger, or **Export** to save it.

**Save it as a high-resolution image:**

```r
ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map_tmax, width = 10, height = 8, dpi = 300)
```

The file saves into your `Figures/` folder. Find it in the Files pane under `~/ClimateNarratives_XX/Figures/`.

> **Learning note:** `ggsave()` saves the most recent ggplot to a file. The `paste0()` function concatenates strings without spaces — so `paste0("Figures/", "TMAX_annual_", "CA", ".png")` produces `"Figures/TMAX_annual_CA.png"`. The `dpi = 300` means 300 dots per inch — publication quality.

**Annual minimum temperature trend:**

```r
map_tmin <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMIN",
  title = paste(my.state, "- Annual Minimum Temperature Trend"),
  subtitle = "Change in degrees C per 100 years",
  state = my.state,
  colors = "temp"
)
ggsave(paste0(figuresfolder, "TMIN_annual_", my.state, ".png"),
       map_tmin, width = 10, height = 8, dpi = 300)
```

**Precipitation trend** (uses a different color scheme):

```r
map_prcp <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_PRCP",
  title = paste(my.state, "- Annual Precipitation Trend"),
  subtitle = "Change in mm per 100 years",
  state = my.state,
  colors = "precip"
)
ggsave(paste0(figuresfolder, "PRCP_annual_", my.state, ".png"),
       map_prcp, width = 10, height = 8, dpi = 300)
```

**Precipitation intensity trend (v0.3.1 — requires `compute_extreme_precip = TRUE`):**

```r
map_intensity <- create_heatmap(
  trends_sp,
  trend_var = "trend_intensity",
  title = paste(my.state, "- Precipitation Intensity Trend"),
  subtitle = "Change in mm/day on wet days per 100 years",
  state = my.state,
  colors = "precip"
)
ggsave(paste0(figuresfolder, "PRCP_intensity_", my.state, ".png"),
       map_intensity, width = 10, height = 8, dpi = 300)
```

**Heavy precipitation days trend (v0.3.1):**

```r
map_heavy <- create_heatmap(
  trends_sp,
  trend_var = "trend_heavy_days",
  title = paste(my.state, "- Heavy Precipitation Days Trend"),
  subtitle = "Change in days >= 25mm per 100 years",
  state = my.state,
  colors = "precip"
)
ggsave(paste0(figuresfolder, "PRCP_heavy_", my.state, ".png"),
       map_heavy, width = 10, height = 8, dpi = 300)
```

### Step 16 — Seasonal comparison (4-panel map)

```r
library(patchwork)

winter_map <- create_heatmap(trends_sp, "winter_trend_TMAX",
              "Winter (Dec-Feb)", state = my.state, resolution = 0.15) +
  theme(legend.position = "none")

spring_map <- create_heatmap(trends_sp, "spring_trend_TMAX",
              "Spring (Mar-May)", state = my.state, resolution = 0.15) +
  theme(legend.position = "none")

summer_map <- create_heatmap(trends_sp, "summer_trend_TMAX",
              "Summer (Jun-Aug)", state = my.state, resolution = 0.15) +
  theme(legend.position = "right")

fall_map <- create_heatmap(trends_sp, "fall_trend_TMAX",
            "Fall (Sep-Nov)", state = my.state, resolution = 0.15) +
  theme(legend.position = "none")

seasonal_panel <- (winter_map | spring_map) / (summer_map | fall_map) +
  plot_annotation(
    title = paste("Seasonal TMAX Trends -", my.state),
    subtitle = "Change in degrees C per 100 years by season"
  )

ggsave(paste0(figuresfolder, "Seasonal_TMAX_", my.state, ".png"),
       seasonal_panel, width = 12, height = 10, dpi = 300)
```

> **Learning note:** The `+` operator with ggplot adds layers or theme modifications. The `|` and `/` operators come from the `patchwork` package and lay plots out side-by-side (`|`) or stacked (`/`). `plot_annotation()` adds a shared title to the combined panel.

### Step 17 — Additional exploration (optional)

```r
# Distribution of trends across stations
hist(trends$annual_trend_TMAX,
     main = "Distribution of TMAX Trends Across Stations",
     xlab = "Trend (°C/century)", col = "lightblue")

# Compare daytime vs nighttime warming
plot(trends$annual_trend_TMIN ~ trends$annual_trend_TMAX,
     main = "Daytime vs Nighttime Warming",
     xlab = "TMAX Trend (°C/century)",
     ylab = "TMIN Trend (°C/century)")
abline(0, 1, lty = 2)  # 1:1 line — points above = more nighttime warming

# Check if warming is nonlinear (v0.3.1)
if ("gam_edf_TMAX" %in% names(trends)) {
  cat("Stations with nonlinear TMAX trend (edf > 2):",
      sum(trends$gam_edf_TMAX > 2, na.rm = TRUE), "of", nrow(trends), "\n")
}
```

---

## What Happens When You Close RStudio

| What | Saved to disk? | What to do next session |
|------|---------------|------------------------|
| The ClimateNarratives package | Yes — installed permanently | Run `library(ClimateNarratives)` |
| Your downloaded weather data | Yes — in `~/ClimateNarratives_XX/Data/` | Run `load_stations()` |
| Your saved heat map images | Yes — in `~/ClimateNarratives_XX/Figures/` | Nothing — the PNG files are already saved |
| Variables in memory (`trends`, `my.state`, `map_tmax`, etc.) | No — R clears memory | Re-run `initialize_project()` and `load_stations()` |
| Your working directory setting | No — resets when session ends | `initialize_project()` sets it for you |

**Every new session, start with:**

```r
library(ClimateNarratives)
initialize_project("XX")
load_stations()
```

---

## Quick-Start Template (After Parts 1 and 2 Are Done)

Copy this block, change the state code on line 2, and run it:

```r
library(ClimateNarratives)
initialize_project("CA")     # <-- CHANGE THIS TO YOUR STATE
load_stations()

# Full v0.3.1 analysis
trends <- process_all_stations(
  trend_method = "Theil-Sen",
  compute_extreme_precip = TRUE,
  compute_nonlinear = TRUE
)
create_spatial_objects(trends)

map <- create_heatmap(trends_sp, "annual_trend_TMAX",
       paste(my.state, "Annual TMAX Trend"), state = my.state)
print(map)
ggsave(paste0(figuresfolder, "TMAX_", my.state, ".png"),
       map, width = 10, height = 8, dpi = 300)
```

---

## Understanding Your Results

### What Are Climate Normals?

A "normal" is the average value for each month over a 30-year baseline period. The standard period is 1961–1990 (set by the World Meteorological Organization). If a station does not have enough data in that window, the package tries 1971–2000, then 1981–2010, then the full record, and tells you which period it used.

### What Is an Anomaly?

Anomaly = Observed value minus Normal

- **Positive anomaly** = warmer (or wetter) than the baseline average
- **Negative anomaly** = cooler (or drier) than the baseline average

### What Is a Trend?

A trend is the slope of a line fitted through the anomalies over time, reported as change per century:

- **TMAX trend of +1.5 °C/century** = max temperatures increased ~1.5°C over 100 years
- **PRCP trend of -25 mm/century** = annual precipitation decreased ~25mm over 100 years

### OLS vs Theil-Sen Trends (v0.3.1)

| | OLS (default) | Theil-Sen |
|---|---|---|
| **What it is** | Ordinary least-squares regression slope | Median of all pairwise slopes |
| **Sensitive to outliers?** | Yes — one extreme year can pull the line | No — median ignores extremes |
| **Significance test** | t-test (assumes normal residuals) | Mann-Kendall (rank-based, no normality assumed) |
| **Best for** | Teaching linear regression concepts | Publication-quality climate analysis |
| **When they differ** | Heavy-tailed or autocorrelated data | They agree when data is well-behaved |

> **Learning note:** In a statistics class you learn OLS regression. OLS finds the slope that minimizes the sum of squared residuals. Theil-Sen finds the *median* of all possible slopes you could draw between pairs of points. Because it uses the median, a single outlier year (drought, heat wave, cold snap) cannot skew the result. Both are valid — they answer slightly different questions.

### Extreme Precipitation Indices (v0.3.1)

| Index | Column name | What it tells you |
|-------|-------------|-------------------|
| Intensity (SDII) | `trend_intensity` | Average rainfall on days when it rains. Rising = rain events getting heavier |
| Heavy days (R25mm) | `trend_heavy_days` | How often we get 1+ inch of rain. Rising = more frequent downpours |
| Max daily (Rx1day) | `trend_max_daily` | The wettest day of the year. Rising = worst storms intensifying |
| Dry spell (CDD) | `trend_dry_spell_max` | Longest run of no rain. Rising = longer droughts between storms |
| % from heavy events | `trend_pct_heavy` | What fraction of annual rain falls in big storms. Rising = more feast-or-famine |

These are standard indices defined by the Expert Team on Climate Change Detection and Indices (ETCCDI) and used in the published climate literature.

### Nonlinear Diagnostics (v0.3.1)

The GAM "edf" (effective degrees of freedom) tells you whether a straight line is a good summary:

- **edf near 1**: Warming is steady and linear. The OLS trend is a fine summary.
- **edf of 2–3**: Warming is *accelerating* (or decelerating). A curve fits better than a line.
- **edf > 4**: Something more complex is happening — possibly a sudden shift or an oscillation.

The `gam_dev_explained_TMAX` column tells you what percentage of the variance in annual anomalies is explained by the smooth trend. Higher = stronger trend signal.

> **Learning note:** A GAM (Generalized Additive Model) is a flexible regression where the relationship between X and Y doesn't have to be a straight line. The model automatically determines how wiggly the curve needs to be. The "effective degrees of freedom" measures this wiggliness — 1 = straight line, higher = more curves.

### Monthly Completeness (v0.3.1 Data Quality Improvement)

Version 0.3.1 now checks that each month has enough daily observations before computing a monthly value. This matters most for precipitation: if only 15 of 30 days were recorded, `sum(na.rm=TRUE)` would produce roughly *half* the true monthly total, creating a systematic downward bias. The defaults require at least 20 days for temperature and 25 days for precipitation.

### What to Look For in Your Maps

- Is your state warming uniformly, or are some regions warming faster?
- Is nighttime warming (TMIN) different from daytime warming (TMAX)?
- Do seasonal patterns differ? (Many states warm more in winter than summer.)
- Is precipitation increasing, decreasing, or mixed across your state?
- **New in v0.3.1:** Is precipitation *intensity* increasing even where totals are flat?
- **New in v0.3.1:** Are heavy-rain days increasing in some regions more than others?
- **New in v0.3.1:** Do some stations show nonlinear (accelerating) warming?

---

## Available Heat Map Variables

| Variable | What it shows |
|----------|---------------|
| `annual_trend_TMAX` | Annual maximum temperature trend |
| `annual_trend_TMIN` | Annual minimum temperature trend |
| `annual_trend_PRCP` | Annual precipitation trend |
| `winter_trend_TMAX` | Winter (Dec-Feb) max temp trend |
| `spring_trend_TMAX` | Spring (Mar-May) max temp trend |
| `summer_trend_TMAX` | Summer (Jun-Aug) max temp trend |
| `fall_trend_TMAX` | Fall (Sep-Nov) max temp trend |
| **`trend_intensity`** | **Precipitation intensity trend (v0.3.1)** |
| **`trend_heavy_days`** | **Heavy precipitation day trend (v0.3.1)** |
| **`trend_max_daily`** | **Max daily precipitation trend (v0.3.1)** |
| **`trend_pct_heavy`** | **Fraction from heavy events trend (v0.3.1)** |
| **`trend_dry_spell_max`** | **Dry spell length trend (v0.3.1)** |

Replace `TMAX` with `TMIN` or `PRCP` for min temperature or precipitation versions of the seasonal trends.

---

## Troubleshooting

### `file.exists("ClimateNarratives_0.3.1.tar.gz")` returns FALSE

The file is not in your current working directory. Check:

1. Did you upload it? (Part 1, Step 3)
2. Did you upload it into the `ClimateNarratives_setup` folder? Check the Files pane.
3. Did you run `setwd("~/ClimateNarratives_setup")`? Run `getwd()` to see where R is looking.

### "there is no package called ..."

A required package is missing. Install it:

```r
install.packages("sf")   # replace with the package name from the error
```

Or install all dependencies at once (copy-paste from Part 1, Step 5).

### "Run initialize_project() first!"

You need to run `initialize_project("XX")` at the start of every R session. This is the most common error — it just means you started a new session and forgot the setup lines.

### "RData file not found"

Your data has not been downloaded yet, or the download did not finish. Go back to Part 2 (Steps 9–11).

### "could not find function 'process_all_stations'"

Either the package is not loaded, or an old version is installed. Try:

```r
library(ClimateNarratives)
```

If that does not help, reinstall:

```r
setwd("~/ClimateNarratives_setup")
install.packages("ClimateNarratives_0.3.1.tar.gz", repos = NULL, type = "source")
```

Then go to Session > Restart R in the RStudio menu, and try `library(ClimateNarratives)` again.

### Download seems stuck

NOAA servers can be slow. For 50 stations, expect 10–30 minutes. If it stops with errors, run `download_stations()` again — it skips stations already downloaded.

### Messages about normals periods

`"Normals period = 1971-2000"` is informational. The station is still analyzed. This is not an error.

### Warning about skipped stations

`"Cannot compute normals for TMAX. Skipping."` means that station did not have enough data. A few skipped stations is expected.

### Heat map looks odd

- Need at least 20 stations (50 is better)
- Try `resolution = 0.15` for smaller states, `resolution = 0.08` for large states
- Make sure `trends_sp` exists: run `create_spatial_objects(trends)`

### "trend_intensity" or "gam_edf_TMAX" column not found

You need to enable these features explicitly:

```r
trends <- process_all_stations(
  compute_extreme_precip = TRUE,   # for trend_intensity, etc.
  compute_nonlinear = TRUE         # for gam_edf_TMAX, etc.
)
```

### Extreme precip map has many NA stations

Some stations don't have 330+ days of precipitation data per year. The function requires good annual coverage to produce reliable indices. Stations with sparse records are excluded — this is expected.

### Where are my files?

Run `getwd()` to see your current project folder. Your files are in:

- `Data/` — Weather data
- `Figures/` — Saved heat maps
- `Output/` — Analysis results

Or navigate in the Files pane (bottom right of RStudio).

---

## Getting Help

```r
?initialize_project          # Help for a specific function
?process_all_stations        # Analysis pipeline options
?create_heatmap              # Visualization parameters
?ExtremePrecp.fun            # Extreme precipitation indices
?monthlyTrend_robust.fun     # Theil-Sen / Mann-Kendall trends
?nonlinearTrend.fun          # GAM nonlinear diagnostics
?ClimateNarratives           # Package overview
help(package = "ClimateNarratives")   # List all functions
```

If you are stuck, show your instructor the **exact error message** — copy the red text from the Console.
