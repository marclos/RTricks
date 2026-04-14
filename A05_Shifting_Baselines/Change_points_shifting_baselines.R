################################################################################
# TUTORIAL: BASELINE SHIFTING AND CHANGEPOINT ANALYSIS IN R
# Topics Covered: 
#   1. Offline Detection (PELT/AMOC)
#   2. Variance Shifts
#   3. Bayesian Online Change Point Detection (BOCPD)
#   4. Handling Shifting Baselines in Online Contexts
################################################################################

# --- STEP 0: Setup ---
# Load necessary libraries. Install if missing.
if(!require(changepoint)) install.packages("changepoint")
if(!require(ocp)) install.packages("ocp")

library(changepoint)
library(ocp)

# --- STEP 1: Generate Synthetic Data with Shifting Baselines ---
set.seed(123)

# Segment 1: Baseline = 10
# Segment 2: Baseline = 20 (Irreversible shift up)
# Segment 3: Baseline = 15 (Shift down)
data_part1 <- rnorm(100, mean = 10, sd = 1)
data_part2 <- rnorm(100, mean = 20, sd = 1)
data_part3 <- rnorm(100, mean = 15, sd = 1)

# Combine into a single time series
ts_data <- c(data_part1, data_part2, data_part3)

# Visualize raw data
plot.ts(ts_data, main="Time Series with Shifting Baselines", 
        ylab="Value", col="darkgrey", lwd=1)


# --- STEP 2: Offline Analysis (Historical Data) ---

# A. Single Changepoint (AMOC: At Most One Change)
# Best for finding the most significant "break" in history.
m1 <- cpt.mean(ts_data, method = "AMOC")
plot(m1, main="Single Changepoint Detection (AMOC)")

# B. Multiple Changepoints (PELT Algorithm)
# PELT is efficient and handles multiple shifts in the baseline.
# We use the AIC penalty to balance sensitivity and overfitting.
m2 <- cpt.mean(ts_data, method = "PELT", penalty = "AIC")
plot(m2, main="Multiple Changepoints (PELT Algorithm)")

# Extract the results
cat("Changepoints detected at indices:", cpts(m2), "\n")
cat("Estimated segment means:", param.est(m2)$mean, "\n")


# --- STEP 3: Detecting Variance Shifts ---
# Sometimes the baseline is stable but the "noise" (variance) shifts.
var_data <- c(rnorm(100, 0, 1), rnorm(100, 0, 3))
m3 <- cpt.var(var_data, method = "PELT")
plot(m3, main="Detection of Shifts in Variance/Volatility")


# --- STEP 4: Bayesian Online Change Point Detection (BOCPD) ---

# CONTEXT: Detecting change points in real-time is critical for 
# finance, medicine, and environmental monitoring. 
# BOCPD uses a "Run Length" (r_t) to estimate the time since 
# the last change point.

# Note on the "Shifting Baseline Problem":
# Original BOCPD struggles when the baseline irreversibly shifts 
# far from its initial state. Sensitivity degrades because the 
# data fluctuates at locations far from the original Bayesian prior.

# Running the standard BOCPD implementation:
online_result <- onlineCPD(ts_data)

# Visualization of Online Detection
# This typically plots the data alongside the "Run Length" distribution.
# A high probability of Run Length = 0 indicates a new detected baseline.
plot(online_result)


# --- STEP 5: Addressing the Shifting Baseline (Conceptual Extension) ---

# To improve BOCPD for constantly shifting baselines:
# 1. Adapt the Hazard Function: Make the model more 'expectant' of change.
# 2. Moving Priors: Instead of a fixed baseline prior, update 
#    hyperparameters based on local segment trends.

# Example of tweaking sensitivity in the 'ocp' package:
custom_online <- onlineCPD(ts_data, 
                           probThreshold = 0.5, # Lower threshold = higher sensitivity
                           hazard_func = function(x, h) { 1/100 }) # Constant hazard

# Final Plot
par(mfrow=c(1,1))
plot(custom_online)
title(sub="Extended BOCPD for Shifting Baselines")

################################################################################
# END OF SCRIPT
################################################################################