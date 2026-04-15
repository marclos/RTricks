# ============================================================
# MASTER SCRIPT: Environmental Statistics Data Lab Generator
# Author: Instructor-use master file
# Purpose:
#   - Create timestamped lab folder
#   - Generate 6 synthetic environmental datasets (CSV)
#   - Generate student README.txt
#   - Generate instructor analysis_key.Rmd (clean YAML)
# ============================================================

# -------------------- USER SETTINGS -------------------------
# Change this ONE line to control all output locations
base_dir <- "/home/mwl04747/RTricks/docs/Excercises"  # <<< EDIT AS NEEDED
# ------------------------------------------------------------

# Create timestamped lab directory
lab_tag <- format(Sys.Date(), "%Y-%m")
output_dir <- file.path(base_dir, paste0(lab_tag, "_Stats_Lab"))

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

set.seed(4321)

# =================== DATASET 1 ===============================
urban_heat <- data.frame(
  Vegetation_Percent = runif(50, 5, 70)
)
urban_heat$Surface_Temperature_C <- round(
  38 - 0.08 * urban_heat$Vegetation_Percent + rnorm(50, 0, 2), 1
)

write.csv(urban_heat,
          file.path(output_dir, "dataset1_urban_heat.csv"),
          row.names = FALSE)

# =================== DATASET 2 ===============================
water_quality <- data.frame(
  Location = rep(c("Upstream", "Downstream"), each = 25),
  Nitrate_mgL = round(c(rnorm(25, 2.1, 0.4), rnorm(25, 3.0, 0.5)), 2)
)

write.csv(water_quality,
          file.path(output_dir, "dataset2_water_quality.csv"),
          row.names = FALSE)

# =================== DATASET 3 ===============================
algae <- data.frame(
  Fertilizer_Level = rep(c("Low", "Medium", "High"), each = 20),
  Algal_Cover_Percent = round(c(
    rnorm(20, 15, 2),
    rnorm(20, 22, 2.5),
    rnorm(20, 30, 3)
  ), 1)
)

write.csv(algae,
          file.path(output_dir, "dataset3_algae.csv"),
          row.names = FALSE)

# =================== DATASET 4 ===============================
hydrology <- data.frame(
  Rainfall_mm = round(runif(40, 20, 180), 1)
)
hydrology$Streamflow_m3s <- round(
  0.6 * hydrology$Rainfall_mm + rnorm(40, 0, 15), 1
)

write.csv(hydrology,
          file.path(output_dir, "dataset4_hydrology.csv"),
          row.names = FALSE)

# =================== DATASET 5 ===============================
biodiversity <- data.frame(
  Habitat = rep(c("Forest", "Grassland", "Urban"), each = 18),
  Species_Richness = c(rpois(18, 28), rpois(18, 19), rpois(18, 10))
)

write.csv(biodiversity,
          file.path(output_dir, "dataset5_biodiversity.csv"),
          row.names = FALSE)

# =================== DATASET 6 ===============================
before <- rnorm(30, 55, 6)
after <- before - rnorm(30, 7, 3)

air_quality <- data.frame(
  Site = 1:30,
  PM25_Before = round(before, 1),
  PM25_After = round(after, 1)
)

write.csv(air_quality,
          file.path(output_dir, "dataset6_air_quality.csv"),
          row.names = FALSE)

# =================== README ===============================
readme_text <- "ENVIRONMENTAL STATISTICS LAB
Framing Research Questions from Environmental Data

Each group is assigned ONE dataset. Your goal is to investigate the research
question using visualization, reasoning, and appropriate statistical methods.

Tasks:
1. Visualize the data before any formal analysis
2. Identify dependent and independent variables
3. State null and alternative hypotheses IN WORDS
4. Choose and justify an appropriate statistical approach
5. Evaluate assumptions and limitations
6. Interpret results in environmental context

The goal is reasoning — not naming a test.

------------------------------------------------------------
  
  DATASET 1: Urban Heat & Vegetation

Context:
  Urban heat islands are driven by impervious surfaces. Vegetation may mitigate
heat through shading and evapotranspiration.

Metadata:
  - Vegetation_Percent: Percent land area covered by vegetation
- Surface_Temperature_C: Surface temperature (°C)

Research Goal:
  Determine whether vegetation cover is associated with surface temperature.

Variables:
  - Independent: Vegetation_Percent
- Dependent: Surface_Temperature_C

Assumptions to Consider:
  - Are both variables continuous?
  - Does the relationship appear linear?
  - Are residuals evenly scattered?
  - Are outliers influential?
  
  Common Pitfalls:
  - Treating correlation as causation
- Ignoring non‑linear patterns
- Overinterpreting small effect sizes

------------------------------------------------------------
  
  DATASET 2: Water Quality (Upstream vs Downstream)

Context:
  Human activity often alters nutrient levels downstream.

Metadata:
  - Location: Sampling category (Upstream, Downstream)
- Nitrate_mgL: Nitrate concentration (mg/L)

Research Goal:
  Evaluate whether nitrate concentrations differ by sampling location.

Variables:
  - Independent: Location (categorical)
- Dependent: Nitrate concentration

Assumptions to Consider:
  - Are observations independent?
  - Is the response approximately normally distributed per group?
  - Are group variances similar?
  
  Common Pitfalls:
  - Treating groups as ordered when they are categorical
- Ignoring unequal variance
- Failing to visualize group overlap

------------------------------------------------------------
  
  DATASET 3: Fertilizer and Algal Growth

Context:
  Nutrient enrichment increases algal productivity but may plateau or interact
with other limiting factors.

Metadata:
  - Fertilizer_Level: Treatment category (Low, Medium, High)
- Algal_Cover_Percent: Percent surface coverage by algae

Research Goal:
  Assess whether algal cover differs across fertilizer treatments.

Variables:
  - Independent: Fertilizer_Level
- Dependent: Algal_Cover_Percent

Assumptions to Consider:
  - Independence of observations
- Normality within groups
- Similar variance among treatments

Common Pitfalls:
  - Running multiple pairwise tests without a global question
- Ignoring variance differences
- Concluding “which group is best” without post‑hoc reasoning

------------------------------------------------------------
  
  DATASET 4: Rainfall & Streamflow

Context:
  Rainfall contributes to streamflow, but responses vary due to watershed
characteristics and storm intensity.

Metadata:
  - Rainfall_mm: Rainfall amount (mm)
- Streamflow_m3s: Stream discharge (m³/s)

Research Goal:
  Examine whether rainfall and streamflow are associated.

Variables:
  - Independent: Rainfall_mm
- Dependent: Streamflow_m3s

Assumptions to Consider:
  - Linearity of relationship
- Absence of extreme leverage points
- Independence of observations

Common Pitfalls:
  - Assuming causation from association
- Ignoring nonlinear or threshold behavior
- Overinterpreting correlation strength

------------------------------------------------------------
  
  DATASET 5: Biodiversity Across Habitats

Context:
  Habitat type affects species richness via disturbance and resource availability.

Metadata:
  - Habitat: Habitat category (Forest, Grassland, Urban)
- Species_Richness: Number of observed species

Research Goal:
  Determine whether species richness differs among habitat types.

Variables:
  - Independent: Habitat
- Dependent: Species_Richness (count data)

Assumptions to Consider:
  - Is the response continuous or discrete?
  - Are distributions symmetric?
  - Are variances similar?
  
  Common Pitfalls:
  - Applying methods that assume normality to count data
- Ignoring skewness or zero inflation
- Overstating ecological mechanisms without evidence

------------------------------------------------------------
  
  DATASET 6: Air Quality Before and After Policy

Context:
  Air quality regulations aim to reduce particulate pollution.

Metadata:
  - Site: Monitoring site ID
- PM25_Before: PM2.5 concentration before policy
- PM25_After: PM2.5 concentration after policy

Research Goal:
  Evaluate whether PM2.5 concentrations changed following the policy.

Variables:
  - Independent: Time (before vs after, paired by site)
- Dependent: PM2.5 concentration

Assumptions to Consider:
  - Are observations paired?
  - Are differences normally distributed?
  - Are changes consistent across sites?
  
  Common Pitfalls:
  - Treating paired data as independent
- Ignoring direction and magnitude of change
- Focusing solely on p‑values instead of effect sizes

------------------------------------------------------------
  
  FINAL NOTE:
  There is more than one defensible analytical path.
Grades are based on justification, assumptions, and interpretation —
not on naming a specific test.
"

writeLines(readme_text,
           file.path(output_dir, "README.txt"))

# =================== INSTRUCTOR RMD ===========================
analysis_key <- "---
title: 'Environmental Statistics – Instructor Analysis Key'
output: html_document
---

## Dataset 1: Urban Heat
```{r}
d <- read.csv('dataset1_urban_heat.csv')
lm(Surface_Temperature_C ~ Vegetation_Percent, data = d)
```

## Dataset 2: Water Quality
```{r}
d <- read.csv('dataset2_water_quality.csv')
t.test(Nitrate_mgL ~ Location, data = d)
```

## Dataset 3: Algal Growth
```{r}
d <- read.csv('dataset3_algae.csv')
model <- aov(Algal_Cover_Percent ~ Fertilizer_Level, data = d)
summary(model)
TukeyHSD(model)
```

## Dataset 4: Hydrology
```{r}
d <- read.csv('dataset4_hydrology.csv')
cor.test(d$Rainfall_mm, d$Streamflow_m3s)
```

## Dataset 5: Biodiversity
```{r}
d <- read.csv('dataset5_biodiversity.csv')
kruskal.test(Species_Richness ~ Habitat, data = d)
```

## Dataset 6: Air Quality Policy
```{r}
d <- read.csv('dataset6_air_quality.csv')
t.test(d$PM25_Before, d$PM25_After, paired = TRUE)
```
"

writeLines(analysis_key,
           file.path(output_dir, "analysis_key.Rmd"))

message("Lab materials created in: ", output_dir)
