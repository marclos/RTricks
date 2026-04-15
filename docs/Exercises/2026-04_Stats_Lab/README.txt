ENVIRONMENTAL STATISTICS LAB
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

