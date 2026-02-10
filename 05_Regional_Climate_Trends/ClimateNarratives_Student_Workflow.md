# ClimateNarratives — Student Workflow

**Your step-by-step guide to analyzing climate trends in R**

---

## Before You Start

You need:

- Access to RStudio Server (your instructor will provide the URL)
- Your assigned **two-letter state code** (e.g., `CA` for California, `TX` for Texas)
- An internet connection (for the initial data download)

---

## Session 1: Setup and Download (Do Once)

### Step 1 — Load the Package

Open RStudio Server and type in the Console:

```r
library(ClimateNarratives)
```

**If you see a `!!!` warning about missing packages**, run this first:

```r
check_dependencies()
```

This installs everything the package needs. You will see OK or FAILED next to each package. Once they all say OK, try `library(ClimateNarratives)` again.

### Step 2 — Initialize Your Project

```r
initialize_project("XX")
```

Replace `XX` with your state code. For example:

```r
initialize_project("CA")   # California
initialize_project("TX")   # Texas
initialize_project("NY")   # New York
```

**What this does:**
- Creates a project folder in your home directory (e.g., `~/ClimateNarratives_CA/`)
- Creates `Data/`, `Output/`, and `Figures/` subfolders
- Downloads a list of available weather stations from NOAA
- Sets your working directory so that all files save to the right place

You should see a summary ending with "Setup Complete!" and a count of potential stations.

### Step 3 — Select Stations

```r
select_stations(n = 50)
```

This picks the 50 stations with the longest, most complete records in your state. You will see a summary of what was selected.

### Step 4 — Download Data from NOAA

```r
download_stations()
```

**This takes 10–30 minutes.** You will see progress for each station. You can keep working in another browser tab while it runs.

If it gets interrupted (connection drops, you close your laptop, etc.), just run `download_stations()` again — it skips stations that were already downloaded.

### Step 5 — Save Data in Efficient Format

```r
load_and_save_stations(cleanup = TRUE)
```

This converts the downloaded files into a single compressed file (`Data/all_stations_raw.RData`) that loads much faster. Setting `cleanup = TRUE` deletes the temporary files to save disk space.

**You are done with Session 1.** Your data is saved and ready for analysis.

---

## Session 2 (and Beyond): Analysis

Every time you come back to RStudio, start with these two lines:

```r
library(ClimateNarratives)
initialize_project("XX")     # your state code
```

Then reload your saved data:

```r
load_stations()
```

### Step 6 — Calculate Climate Trends

```r
trends <- process_all_stations()
```

This runs the full analysis: cleaning dates, converting units, calculating anomalies, and fitting trend lines. It takes a minute or two.

**You may see messages like:**
- `"Station USC00045123: Normals period = 1971-2000"` — This is normal. It means that station did not have enough data in the standard 1961–1990 baseline period, so the package used a different 30-year window. The station is still included in your analysis.
- `"Station USC00067890: Cannot compute normals... Skipping."` — This station did not have enough data for any baseline period. It is excluded. A few skipped stations is expected.

Check the results:

```r
cat("Stations analyzed:", nrow(trends), "\n")
summary(trends$annual_trend_TMAX)
```

### Step 7 — Create Spatial Objects

```r
create_spatial_objects(trends)
```

This converts your trend data into a spatial format that can be mapped.

### Step 8 — Make Heat Maps

**Annual maximum temperature trend:**

```r
map_tmax <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMAX",
  title = paste(my.state, "- Annual Maximum Temperature Trend"),
  subtitle = "Change in °C per 100 years",
  state = my.state,
  colors = "temp"
)
print(map_tmax)
```

**Save it as a high-resolution image:**

```r
ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map_tmax, width = 10, height = 8, dpi = 300)
```

The file is saved in your `Figures/` folder. You can find it in the Files pane in RStudio.

**Annual minimum temperature trend:**

```r
map_tmin <- create_heatmap(
  trends_sp,
  trend_var = "annual_trend_TMIN",
  title = paste(my.state, "- Annual Minimum Temperature Trend"),
  subtitle = "Change in °C per 100 years",
  state = my.state,
  colors = "temp"
)
ggsave(paste0(figuresfolder, "TMIN_annual_", my.state, ".png"),
       map_tmin, width = 10, height = 8, dpi = 300)
```

**Precipitation trend** (use `colors = "precip"` for a different color scheme):

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

### Step 9 — Seasonal Comparison (4-Panel Map)

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
    subtitle = "Change in °C per 100 years by season"
  )

ggsave(paste0(figuresfolder, "Seasonal_TMAX_", my.state, ".png"),
       seasonal_panel, width = 12, height = 10, dpi = 300)
```

---

## Quick-Start Template

Copy this entire block, change the state code on line 3, and run it all:

```r
# ---- CHANGE THIS TO YOUR STATE ----
MY_STATE <- "CA"
# ------------------------------------

library(ClimateNarratives)
initialize_project(MY_STATE)

# First time only (skip if you already downloaded):
# select_stations(n = 50)
# download_stations()
# load_and_save_stations(cleanup = TRUE)

# Every session:
load_stations()
trends <- process_all_stations()
create_spatial_objects(trends)

map <- create_heatmap(trends_sp, "annual_trend_TMAX",
       paste(my.state, "Annual TMAX Trend"), state = my.state)
ggsave(paste0(figuresfolder, "TMAX_", my.state, ".png"),
       map, width = 10, height = 8, dpi = 300)
```

---

## Understanding Your Results

### What Are Climate Normals?

A "normal" is the average value for each month over a 30-year baseline period. The standard period is 1961–1990 (set by the World Meteorological Organization). If a station does not have enough data in that window, the package uses a later period and tells you.

### What Is an Anomaly?

Anomaly = Observed value − Normal

- **Positive anomaly** = warmer (or wetter) than the baseline average
- **Negative anomaly** = cooler (or drier) than the baseline average

### What Is a Trend?

A trend is the slope of a line fitted through the anomalies over time. It is reported as change per century:

- **TMAX trend of +1.5 °C/century** means maximum temperatures have increased by about 1.5°C over 100 years
- **PRCP trend of −25 mm/century** means annual precipitation has decreased by about 25mm over 100 years

### What to Look For in Your Maps

- **Is your state warming uniformly, or are some regions warming faster?**
- **Is nighttime warming (TMIN) different from daytime warming (TMAX)?** (Often TMIN increases faster due to urbanization and cloud cover.)
- **Do seasonal patterns differ?** (Many states warm more in winter than summer.)
- **Is precipitation increasing, decreasing, or mixed across your state?**

---

## Available Heat Map Variables

| Variable | What it shows |
|----------|---------------|
| `annual_trend_TMAX` | Annual maximum temperature trend |
| `annual_trend_TMIN` | Annual minimum temperature trend |
| `annual_trend_PRCP` | Annual precipitation trend |
| `winter_trend_TMAX` | Winter (Dec–Feb) max temp trend |
| `spring_trend_TMAX` | Spring (Mar–May) max temp trend |
| `summer_trend_TMAX` | Summer (Jun–Aug) max temp trend |
| `fall_trend_TMAX` | Fall (Sep–Nov) max temp trend |

Replace `TMAX` with `TMIN` or `PRCP` for minimum temperature or precipitation versions.

---

## Troubleshooting

### "there is no package called ..."

Run `check_dependencies()` and follow the instructions it prints.

### "Run initialize_project() first!"

You need to run `initialize_project("XX")` at the start of every R session (replace XX with your state code). This sets up the paths and variables that all other functions depend on.

### "RData file not found"

You haven't downloaded your data yet, or the download didn't finish. Run:

```r
select_stations(n = 50)
download_stations()
load_and_save_stations()
```

### Download seems stuck

NOAA servers can be slow. Each station has a 0.5-second delay between downloads. For 50 stations, expect 10–30 minutes. If it stops with errors, just run `download_stations()` again.

### Messages about normals periods

Messages like `"Normals period = 1971-2000"` are informational — the station is still analyzed using the best available data. This is not an error.

### Warning about skipped stations

`"Cannot compute normals for TMAX. Skipping."` means that station did not have enough data. A few skipped stations is expected and will not ruin your analysis.

### Heat map looks odd

- Make sure you have at least 20 stations (50 is better)
- Try `resolution = 0.15` for smaller states or `resolution = 0.08` for large states
- Check that `trends_sp` exists: run `create_spatial_objects(trends)` if needed

### Where are my files?

Your project folder is `~/ClimateNarratives_XX/`. Inside it:

- `Data/` — Your weather data
- `Figures/` — Your saved heat maps
- `Output/` — Analysis results

In RStudio, use the Files pane (bottom right) to navigate there. Or run `getwd()` to see where you are.

---

## Getting Help

```r
?initialize_project          # Help for a specific function
?ClimateNarratives           # Package overview
help(package = "ClimateNarratives")   # List all functions
```

If you are stuck, show your instructor the **exact error message** (copy the red text from the Console). Most problems are solved by one of:

1. `check_dependencies()`
2. `initialize_project("XX")`
3. Re-running a step that was skipped or interrupted
