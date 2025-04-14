set.seed(123)  # for reproducibility

# Sample size
n <- 200

# Generate fake water quality data
water_temp <- rnorm(n, mean = 22, sd = 2)             # degrees Celsius
salinity <- rnorm(n, mean = 35, sd = 1.5)             # PSU (Practical Salinity Units)
pH <- rnorm(n, mean = 8.1, sd = 0.2)                  # pH levels
dissolved_oxygen <- rnorm(n, mean = 6, sd = 1)        # mg/L

# Simulate fish abundance based on a linear relationship with some noise
fish_abundance <- 50 + 
  2 * water_temp - 
  1.5 * salinity + 
  5 * pH + 
  3 * dissolved_oxygen + 
  rnorm(n, mean = 0, sd = 10)

# Combine into a data frame
coastal_data <- data.frame(
  fish_abundance,
  water_temp,
  salinity,
  pH,
  dissolved_oxygen
)

# Peek at the data
head(coastal_data)

# Save to CSV if needed
write.csv(coastal_data, "~/RTricks/13_coastal_fish/coastal_data.csv", row.names = FALSE)
