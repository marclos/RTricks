# ClimateNarratives v0.2.0 - Teaching Package

**Revision Date:** February 9, 2026

---

## 📦 What You Have

**3 files - that's it! Keep it simple!**

1. **ClimateNarratives_0.2.tar.gz** - The R package
2. **STUDENT_WORKFLOW_GUIDE.md** - For students (40+ pages)
3. **INSTRUCTOR_RESOURCE_GUIDE.md** - For you (this guide)

---

## 🚀 Quick Start

### Give Students:
1. `ClimateNarratives_0.2.tar.gz` (the package)
2. `STUDENT_WORKFLOW_GUIDE.md` (their tutorial)

### Installation:

```r
# 1. Install
install.packages("ClimateNarratives_0.2.tar.gz", repos = NULL, type = "source")

# 2. Restart R (IMPORTANT!)
q()

# 3. Setup
setwd("~/05_Regional_Climate_Trends")
library(ClimateNarratives)
library(ggplot2)
initialize_project("CA")  # Their assigned state
```

### Their Workflow:

```r
select_stations(n = 50)
download_stations()
load_and_save_stations()

trends <- process_all_stations()
create_spatial_objects(trends)

map <- create_heatmap(trends_sp, "annual_trend_TMAX",
                      "Temperature Trends", state = my.state)
ggsave(paste0(figuresfolder, "map.png"), map, 
       width = 10, height = 8, dpi = 300)
```

---

## 📚 What's in Each File

### STUDENT_WORKFLOW_GUIDE.md

Complete step-by-step tutorial:
- Setup through final maps
- What each function does
- Climate science concepts
- Statistical concepts
- Troubleshooting
- 40+ pages of detailed instruction

### INSTRUCTOR_RESOURCE_GUIDE.md

Teaching reference for you:
- Quick start guide
- Learning objectives
- Sample assignments
- Grading rubrics
- Common student issues
- Demo script
- Troubleshooting solutions

### ClimateNarratives_0.2.tar.gz

R package containing:
- 18 functions
- 12 help pages
- Complete documentation
- Source code

---

## ✅ Common Issues & Quick Fixes

### "object 'datafolder' not found"
**Solution:** Run `initialize_project()` first

### "could not find function 'ggsave'"
**Solution:** Add `library(ggplot2)` to setup

### Files not saving correctly
**Solution:** Use variables, not hardcoded paths:
```r
# ✅ CORRECT
ggsave(paste0(figuresfolder, "map.png"), map)

# ❌ WRONG
ggsave("Figures/map.png", map)
```

---

## 🎓 First Day of Class

1. Students install package
2. Run setup together (3 lines of code)
3. Start downloads (runs during break)
4. Process and analyze
5. Create first map

**Total time:** 60-90 minutes

---

## 📧 Built-in Help

Students can get help anytime:

```r
?initialize_project
?create_heatmap
help(package = "ClimateNarratives")
```

---

**That's it! Simple and effective!** 🎉
