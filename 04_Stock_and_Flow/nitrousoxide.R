# Define parameters
years <- 1900:2024                       # Year range
n2o_emissions <- rep(5e6, length(years)) # Annual N₂O emissions in metric tons (example: 5 million tons/year)
n2o_lifetime <- 114                      # Atmospheric lifetime of N₂O in years
initial_n2o_stock <- 0                   # Initial stock of N₂O in the atmosphere (metric tons)

# Convert emissions to atmospheric concentration (1 ton = 1e9 micrograms; assume 1.5 ppm corresponds to ~7.8 Tg N₂O)
convert_to_ppb <- function(n2o_stock) {
  n2o_stock / 7.8e6 * 1.5
}

# Initialize variables
n2o_stock <- numeric(length(years))      # Atmospheric stock of N₂O for each year
n2o_ppb <- numeric(length(years))        # Atmospheric concentration of N₂O in ppb for each year
n2o_stock[1] <- initial_n2o_stock

# Calculate N₂O stock and concentration over time
for (i in 2:length(years)) {
  # Decay based on atmospheric lifetime
  decay_loss <- n2o_stock[i - 1] / n2o_lifetime
  # Net stock considering new emissions and decay
  n2o_stock[i] <- n2o_stock[i - 1] + n2o_emissions[i] - decay_loss
  # Convert stock to concentration
  n2o_ppb[i] <- convert_to_ppb(n2o_stock[i])
}

# Create a data frame for results
n2o_data <- data.frame(
  Year = years,
  N2O_Stock = n2o_stock, # Total N₂O in the atmosphere (metric tons)
  N2O_ppb = n2o_ppb      # Atmospheric concentration in ppb
)

# Display the first few rows of data
print(head(n2o_data))

# Plot atmospheric N₂O concentration over time
library(ggplot2)
ggplot(n2o_data, aes(x = Year, y = N2O_ppb)) +
  geom_line(color = "blue", size = 1) +
  labs(
    title = "Atmospheric N₂O Concentration Over Time",
    x = "Year",
    y = "N₂O Concentration (ppb)"
  ) +
  theme_minimal()
