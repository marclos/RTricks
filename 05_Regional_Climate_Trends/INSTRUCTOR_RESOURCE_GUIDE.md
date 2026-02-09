# ClimateNarratives - Instructor Resource Guide

**Revision Date:** February 9, 2026  
**Version:** 0.2.0

---

## 📦 What You Have

A complete R package for teaching climate data analysis with real NOAA data.

**Package:** `ClimateNarratives_0.2.tar.gz`  
**Student Guide:** `STUDENT_WORKFLOW_GUIDE.md`  
**This Guide:** `INSTRUCTOR_RESOURCE_GUIDE.md`

---

## 🚀 Quick Start for Teaching

### Installation (Students)

```r
# 1. Install package
install.packages("ClimateNarratives_0.2.tar.gz", repos = NULL, type = "source")

# 2. Restart R (CRITICAL!)
q()

# 3. Setup
setwd("~/05_Regional_Climate_Trends")
library(ClimateNarratives)
library(ggplot2)

# 4. Initialize for their state
initialize_project("CA")  # Each student gets different state
```

### First Day Workflow

**Have students run together (60-90 minutes):**

```r
# Setup
setwd("~/05_Regional_Climate_Trends")
library(ClimateNarratives)
library(ggplot2)
initialize_project("CA")

# Select and download (takes 10-30 min - start early!)
select_stations(n = 50)
download_stations()

# Process (after download completes)
load_and_save_stations()

# Analyze
trends <- process_all_stations()

# Create maps
create_spatial_objects(trends)
map <- create_heatmap(trends_sp, "annual_trend_TMAX",
                      "Temperature Trends", state = my.state)

# Save
ggsave(paste0(figuresfolder, "first_map.png"), map, 
       width = 10, height = 8, dpi = 300)
```

---

## 📚 Key Documentation

### For Students

**STUDENT_WORKFLOW_GUIDE.md** - Complete tutorial covering:
- All 10 workflow steps
- What each function does "behind the scenes"
- File tracking (what appears in Data/ and Figures/)
- Climate science concepts
- Statistical concepts
- Troubleshooting guide
- Learning objectives

**Built-in help system:**
```r
?initialize_project
?create_heatmap
help(package = "ClimateNarratives")
```

### Project Path Setup

**Students must use this exact setup:**

```r
setwd("~/05_Regional_Climate_Trends")
library(ClimateNarratives)
library(ggplot2)
initialize_project("STATE")
```

**Why this matters:**
- Creates `datafolder` and `figuresfolder` variables
- Prevents path errors
- Ensures files save to correct location

---

## 🎯 Package Functions

### Setup & Data Acquisition
- `initialize_project(state, path)` - Setup folders and download inventory
- `select_stations(n, min_years, min_last_year)` - Filter quality stations
- `download_stations()` - Fetch data from NOAA (10-30 min)
- `load_and_save_stations(cleanup)` - Process and compress data
- `load_stations()` - Load previously saved data

### Analysis
- `process_all_stations()` - Calculate all trends (annual + seasonal)
- `create_spatial_objects(trends)` - Convert to sf/sp formats
- `check_station_coverage(trends)` - Assess if enough stations

### Visualization
- `create_heatmap(data, trend_var, title, state, colors)` - Kriging interpolation (20+ stations)
- `plot_station_map(data, trend_var, title, state)` - Point map (< 20 stations)
- `plot_station_trends(trends, stations, max_stations)` - Individual time series

---

## 🎓 Learning Objectives

**R Programming:**
- Package usage
- Working with data frames
- Function parameters
- Global variables
- File I/O and organization

**Data Management:**
- API data download
- Data cleaning
- Efficient storage (RData)
- Reproducible workflows

**Statistics:**
- Time series analysis
- Linear regression
- Anomaly calculation
- Climate normals (1961-1990)

**Climate Science:**
- Temperature trends (TMAX, TMIN)
- Precipitation variability
- Asymmetric warming
- Regional patterns

**Spatial Analysis:**
- Coordinate systems
- Kriging interpolation
- Spatial data formats (sf, sp)

---

## 📋 Sample Assignments

### Assignment 1: Basic Workflow (Week 1)

**Task:** Complete workflow for assigned state, create 3 heat maps

**Deliverables:**
- Heat maps: TMAX, TMIN, PRCP (PNG files)
- 1-2 page summary of trends
- Answers to questions

**Grading:**
- Workflow completion: 40%
- Figure quality: 30%
- Interpretation: 30%

### Assignment 2: Seasonal Analysis (Week 2)

**Task:** Compare seasonal warming patterns

**Deliverables:**
- 4-panel seasonal map
- Analysis of seasonal differences
- Discussion (2-3 pages)

### Assignment 3: Regional Comparison (Week 3)

**Task:** Compare 2-3 states/regions

**Deliverables:**
- Comparative analysis
- Multiple heat maps
- Final report (5-7 pages)

---

## 🎬 Demo Script for Class

**Live demonstration (15 minutes):**

```r
# 1. Load package
library(ClimateNarratives)

# 2. Setup
setwd("~/05_Regional_Climate_Trends")
initialize_project("CA")

# Show what was created
list.files("Data/")       # stations.active.oldest.csv
datafolder                # Full path
figuresfolder            # Full path

# 3. Quick demo with small dataset
select_stations(n = 10)   # Small for demo
# (Skip download - use pre-loaded data)

# 4. Show processing
load_stations()           # If data pre-loaded
head(USC00045123)         # Example station

# 5. Quick map
trends <- process_all_stations()
create_spatial_objects(trends)
map <- plot_station_map(trends_sf, "annual_trend_TMAX",
                        "Demo Map", state = "CA")
print(map)
```

---

## ⚠️ Common Student Issues & Solutions

### Issue 1: "object 'datafolder' not found"

**Cause:** Skipped `initialize_project()`

**Solution:**
```r
setwd("~/05_Regional_Climate_Trends")
library(ClimateNarratives)
initialize_project("CA")
```

### Issue 2: "could not find function 'ggsave'"

**Cause:** ggplot2 not loaded

**Solution:**
```r
library(ggplot2)
```

### Issue 3: Files not saving to correct location

**Cause:** Using hardcoded paths instead of variables

**Wrong:**
```r
write.csv(trends, "Data/trends.csv")
ggsave("Figures/map.png", map)
```

**Correct:**
```r
write.csv(trends, paste0(datafolder, "trends.csv"), row.names = FALSE)
ggsave(paste0(figuresfolder, "map.png"), map, width = 10, height = 8, dpi = 300)
```

### Issue 4: Variogram convergence warning

**Message:** "No convergence after 200 iterations"

**Solution:** This is NORMAL! Kriging still works. Ignore the warning.

### Issue 5: State has few stations (< 20)

**Solution:** Use point maps instead:
```r
check_station_coverage(trends)  # See recommendation
plot_station_map(trends_sf, "annual_trend_TMAX", "Trends", state = my.state)
```

---

## 📊 Expected Student Output

### File Structure

After completing workflow:

```
~/05_Regional_Climate_Trends/
├── Data/
│   ├── stations.active.oldest.csv
│   ├── selected_inventory_CA.csv
│   ├── all_stations_raw.RData        (50-200 MB)
│   └── climate_trends.csv
│
└── Figures/
    ├── tmax_annual_CA.png
    ├── tmin_annual_CA.png
    ├── prcp_annual_CA.png
    └── StationPlots/
        ├── station_USC00045123.png
        └── ... (10+ files)
```

### Typical Results

**For California (50 stations):**
- TMAX trend: +1.0 to +1.5°C/century
- TMIN trend: +1.2 to +1.8°C/century
- PRCP trend: -50 to +50 mm/century (high variability)
- Clear spatial patterns (inland vs. coastal)

---

## 🔧 Troubleshooting Tools

### Diagnostic Script

Students can run this to check setup:

```r
# Check package loaded
"ClimateNarratives" %in% loadedNamespaces()

# Check variables exist
exists("datafolder")
exists("figuresfolder")
exists("my.state")

# Check folders
dir.exists(datafolder)
dir.exists(figuresfolder)

# Check ggplot2
exists("ggsave")
```

### Quick Verification

**After setup, students run:**

```r
# Should all work:
datafolder        # Shows path
figuresfolder     # Shows path
my.state          # Shows state code
list.files(datafolder)  # Shows stations.active.oldest.csv
```

---

## 📝 Grading Rubric Template

### Lab Report (100 points)

**Methods (20 points):**
- Correct workflow followed
- Appropriate station selection
- Proper documentation

**Results (30 points):**
- All required figures created
- Figures properly labeled
- Trend summary table included

**Analysis (30 points):**
- Correct interpretation of trends
- Discussion of spatial patterns
- Comparison to literature/context

**Presentation (20 points):**
- Writing quality
- Figure quality (resolution, labels)
- Organization and clarity

---

## 🎯 Tips for Success

### Before Class
- Test full workflow yourself
- Pre-download data for demo
- Prepare example outputs to show
- Have diagnostic script ready

### During Class
- Start downloads early (takes time!)
- Have students work in pairs (troubleshooting)
- Walk around and check setups
- Show example results while downloads run

### After Class
- Provide example code
- Be available for path/ggsave questions
- Share example maps
- Point to STUDENT_WORKFLOW_GUIDE.md

---

## 📚 Additional Resources to Share

**Data Sources:**
- NOAA GHCN-Daily: https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily
- Climate Normals: https://www.ncei.noaa.gov/products/land-based-station/us-climate-normals

**Background Reading:**
- IPCC Reports (climate context)
- NOAA State Climate Summaries
- National Climate Assessment

**R Help:**
- R for Data Science (free online)
- Spatial Data Science with R

---

## ✅ Pre-Class Checklist

- [ ] Install package on your machine
- [ ] Test complete workflow
- [ ] Prepare state assignments
- [ ] Share STUDENT_WORKFLOW_GUIDE.md with students
- [ ] Share ClimateNarratives_0.2.tar.gz
- [ ] Test on lab computers (if applicable)
- [ ] Prepare grading rubric
- [ ] Create example outputs to show
- [ ] Set up file sharing system

---

## 🎉 Summary

**You have:**
- ✅ Production-ready R package
- ✅ Complete student tutorial (40+ pages)
- ✅ Built-in help system (12 help pages)
- ✅ Tools for all station counts (20+ or < 20)

**Students will:**
- Download real climate data
- Calculate professional trends
- Create publication-quality maps
- Learn R, stats, and climate science

**Time required:**
- Setup: 15 minutes
- Download: 10-30 minutes
- Analysis: 1-2 hours
- Total: 2-4 hours per student

---

## 📧 Support

**For package issues:**
- Check built-in help: `?function_name`
- Review STUDENT_WORKFLOW_GUIDE.md
- Common issues covered in Section "Common Student Issues"

**For teaching questions:**
- Use this guide as reference
- Adapt assignments to your course level
- Scale complexity as needed

---

**Ready to teach climate data analysis!** 🌍📊🎓
