# Load necessary libraries
library(tidyverse)
library(ggplot2)
library(car)

# Load your dataset
# Assuming you have a CSV file with columns like: 'fish_abundance', 'water_temp', 'salinity', 'pH', 'dissolved_oxygen', etc.
data <- read.csv("~/RTricks/13_coastal_fish/coastal_data.csv")

# Quick look at the data
str(data)
summary(data)

# Check for missing values
colSums(is.na(data))

# Simple linear regression model
model <- lm(fish_abundance ~ water_temp + salinity + pH + dissolved_oxygen, data = data)

# Model summary
summary(model)

# Diagnostic plots
par(mfrow = c(2, 2))
plot(model)

# Check multicollinearity (VIF)
vif(model)
par(mfrow= c(1,1))

plot(fish_abundance ~ water_temp + salinity + pH + dissolved_oxygen, data = data)

plot(fish_abundance ~ water_temp, data = data)

# Visualizing relationships
ggplot(data, aes(x = dissolved_oxygen, y = fish_abundance)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(title = "Fish Abundance vs Dissolved Oxygen")

ggplot(data, aes(x = salinity, y = fish_abundance)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(title = "Fish Abundance vs Salinity")
