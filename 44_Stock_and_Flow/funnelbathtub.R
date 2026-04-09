# Load necessary library
library(ggplot2)

# Define parameters
max_volume <- 500              # Maximum volume of the funnel in liters
funnel_radius <- 5           # Radius of the funnel at the top (meters)
funnel_height <- 1.5           # Maximum height of the funnel (meters)
fill_rate <- 5               # Fill rate reduced by a factor of 10 (liters per second)
drain_rate <- 1                # Drain rate in liters per second
time_hours <- 5               # Simulation duration in hours
time_seconds <- time_hours * 3600 # Convert time to seconds

# Function to calculate height based on volume
calculate_height <- function(volume, radius) {
  height <- (3 * volume) / (pi * radius^2) # Height in meters
  return(height)
}

# Initialize variables
time <- seq(0, time_seconds, by = 1) # Time in seconds
volume <- numeric(length(time))     # Volume at each time step
height <- numeric(length(time))     # Height at each time step
volume[1] <- 0                      # Initial volume
height[1] <- calculate_height(volume[1], funnel_radius)

# Simulate the water volume and height over time
for (t in 2:length(time)) {
  volume[t] <- volume[t - 1] + (fill_rate - drain_rate) # Net flow
  if (volume[t] > max_volume) volume[t] <- max_volume  # Prevent overflow
  if (volume[t] < 0) volume[t] <- 0                    # Prevent negative volume
  height[t] <- calculate_height(volume[t], funnel_radius) # Calculate height
}

# Create a data frame for plotting and reporting
data <- data.frame(
  Time = time / 3600, # Convert time to hours
  Volume = volume,    # Volume in liters
  Height = height     # Height in meters
)

# Display first few rows of the dataset
print(head(data))

# Plot water volume over time
plot_volume <- ggplot(data, aes(x = Time, y = Volume)) 
print(plot_volume)
