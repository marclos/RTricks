---
  title: "Environmental Statistics – Instructor Analysis Key"
output: html_document
---
  
  ## Dataset 1: Urban Heat & Vegetation
  **Statistical method:** Linear regression

```r
urban_heat <- read.csv("dataset1_urban_heat.csv")
lm(Surface_Temperature_C ~ Vegetation_Percent, data = urban_heat)
```

Interpretation: Expect a significant negative slope indicating vegetation reduces surface temperature.

---
  
  ## Dataset 2: Water Quality
  **Statistical method:** Two-sample t-test

```r
water_quality <- read.csv("dataset2_water_quality.csv")
t.test(Nitrate_mgL ~ Location, data = water_quality)
```

Interpretation: Downstream nitrate concentrations should be significantly higher.

---
  
  ## Dataset 3: Algal Growth
  **Statistical method:** One-way ANOVA

```r
algae <- read.csv("dataset3_algae.csv")
aov(Algal_Cover_Percent ~ Fertilizer_Level, data = algae)
summary(aov(Algal_Cover_Percent ~ Fertilizer_Level, data = algae))
```

Follow-up with:
  ```r
TukeyHSD(aov(Algal_Cover_Percent ~ Fertilizer_Level, data = algae))
```

---
  
  ## Dataset 4: Hydrology
  **Statistical method:** Pearson correlation

```r
hydrology <- read.csv("dataset4_hydrology.csv")
cor.test(hydrology$Rainfall_mm, hydrology$Streamflow_m3s)
```

Interpretation: Strong positive correlation expected.

---
  
  ## Dataset 5: Biodiversity
  **Statistical method:** Kruskal-Wallis test

```r
biodiversity <- read.csv("dataset5_biodiversity.csv")
kruskal.test(Species_Richness ~ Habitat, data = biodiversity)
```

Interpretation: Species richness differs by habitat type.

---
  
  ## Dataset 6: Air Quality Policy
  **Statistical method:** Paired t-test

```r
air_quality <- read.csv("dataset6_air_quality.csv")
t.test(air_quality$PM25_Before, air_quality$PM25_After, paired = TRUE)
```

Interpretation: Significant decrease in PM2.5 after policy implementation.
