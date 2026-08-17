# ClimateNarratives — Student Workflow

**Version 0.3.0** | Step-by-step guide to analyzing climate trends in R  
**Revision Date:** February 10, 2026

---

## Before You Start

You need:

- Access to RStudio Server (your instructor will provide the URL and login)
- The file **`ClimateNarratives_0.3.0.tar.gz`** (your instructor will provide this)
- Your assigned **two-letter state code** (e.g., `CA` for California, `TX` for Texas)
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

### Step 3 — Upload the tar.gz file

1. In the **Files** pane (bottom right), click into the `ClimateNarratives_setup` folder
2. Click the **Upload** button (it has an upward arrow icon)
3. Click **Choose File** and select the `ClimateNarratives_0.3.0.tar.gz` file from your computer
4. Click **OK**

**Check:** You should now see `ClimateNarratives_0.3.0.tar.gz` listed in the Files pane inside the `ClimateNarratives_setup` folder.

### Step 4 — Point R at that folder

In the **Console**, type:

```r
setwd("~/ClimateNarratives_setup")
```

Then verify the file is there:

```r
file.exists("ClimateNarratives_0.3.0.tar.gz")
```

This **must** print `TRUE`. If it prints `FALSE`:

- Did you upload the file? (Go back to Step 3.)
- Did you upload it into the `ClimateNarratives_setup` folder, or somewhere else? Check the Files pane.
- Did you type the `setwd(...)` line? Run `getwd()` to see where R is looking.

**Do not continue until `file.exists(...)` returns `TRUE`.**

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

### Step 6 — Install ClimateNarratives

Now install the actual package. Type:

```r
install.packages("ClimateNarratives_0.3.0.tar.gz", repos = NULL, type = "source")
```

Wait for it to finish. The last lines should include:

```
* DONE (ClimateNarratives)
```

**If you see `ERROR` or `had non-zero exit status` instead:**
Read the error message. It usually names a missing package. Go back to Step 5 and install that package, then try Step 6 again.

### Step 7 — Verify it works

Load the package:

```r
library(ClimateNarratives)
```

You should see this startup message:

```
===========================================================
 ClimateNarratives v0.3.0
===========================================================
 Regional Climate Trends Analysis and Visualization
 Type ?ClimateNarratives for help
===========================================================
```

**If you see a `!!!` warning about missing packages instead**, run `check_dependencies()`, then try `library(ClimateNarratives)` again.

**If the startup message shows `v0.3.0`, Part 1 is done. The package is installed permanently on the server. You will not need to repeat Part 1.**

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
```

**What this does:**

- Creates a project folder in your home directory (e.g., `~/ClimateNarratives_CA/`)
- Creates `Data/`, `Output/`, and `Figures/` subfolders inside it
- Downloads a list of available weather stations from NOAA
- Changes your working directory to the project folder (you do NOT need to call `setwd()` yourself)

You should see output ending with `Setup Complete!` and a count of potential stations.

### Step 9 — Select stations

```r
select_stations(n = 50)
```

This picks the 50 stations with the longest, most complete records in your state.

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

### Step 12 — Calculate climate trends

```r
trends <- process_all_stations()
```

This runs the full analysis: cleaning dates, converting units, calculating anomalies, and fitting trend lines. It takes a minute or two.

**You may see messages like:**

- `"Station USC00045123: Normals period = 1971-2000"` — This is normal. That station did not have enough data in the standard 1961–1990 baseline period, so the package used a different 30-year window. The station is still included.
- `"Station USC00067890: Cannot compute normals... Skipping."` — That station did not have enough data for any baseline period. It is excluded. A few skipped stations is expected.

Check the results:

```r
cat("Stations analyzed:", nrow(trends), "\n")
summary(trends$annual_trend_TMAX)
```

### Step 13 — Create spatial objects

```r
create_spatial_objects(trends)
```

This converts your trend data into a spatial format that can be mapped.

### Step 14 — Make heat maps

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

**Save it as a high-resolution image:**

```r
ggsave(paste0(figuresfolder, "TMAX_annual_", my.state, ".png"),
       map_tmax, width = 10, height = 8, dpi = 300)
```

The file saves into your `Figures/` folder. Find it in the Files pane under `~/ClimateNarratives_XX/Figures/`.

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

### Step 15 — Seasonal comparison (4-panel map)

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

trends <- process_all_stations()
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

A "normal" is the average value for each month over a 30-year baseline period. The standard period is 1961–1990 (set by the World Meteorological Organization). If a station does not have enough data in that window, the package uses a later period and tells you.

### What Is an Anomaly?

Anomaly = Observed value minus Normal

- **Positive anomaly** = warmer (or wetter) than the baseline average
- **Negative anomaly** = cooler (or drier) than the baseline average

### What Is a Trend?

A trend is the slope of a line fitted through the anomalies over time, reported as change per century:

- **TMAX trend of +1.5 degrees C/century** = max temperatures increased ~1.5 degrees C over 100 years
- **PRCP trend of -25 mm/century** = annual precipitation decreased ~25mm over 100 years

### What to Look For in Your Maps

- Is your state warming uniformly, or are some regions warming faster?
- Is nighttime warming (TMIN) different from daytime warming (TMAX)?
- Do seasonal patterns differ? (Many states warm more in winter than summer.)
- Is precipitation increasing, decreasing, or mixed across your state?

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

Replace `TMAX` with `TMIN` or `PRCP` for min temperature or precipitation versions.

---

## Troubleshooting

### `file.exists("ClimateNarratives_0.3.0.tar.gz")` returns FALSE

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
install.packages("ClimateNarratives_0.3.0.tar.gz", repos = NULL, type = "source")
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
?ClimateNarratives           # Package overview
help(package = "ClimateNarratives")   # List all functions
```

If you are stuck, show your instructor the **exact error message** — copy the red text from the Console.
