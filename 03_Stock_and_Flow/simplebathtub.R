# Load necessary library
library(ggplot2)

# Define parameters
max_volume <- 500 # Maximum volume of the bathtub in liters
fill_rate <- .05    # Fill rate in liters per second
drain_rate <- .04   # Drain rate in liters per second
time_hours <- 1   # Simulation duration in hours
time_seconds <- time_hours * 3600 # Convert time to seconds

# Initialize variables
time <- seq(0, time_seconds, by = 1) # Time in seconds
volume <- numeric(length(time))     # Volume at each time step
volume[1] <- 0                      # Initial volume in the bathtub

# Simulate the water volume over time
for (t in 2:length(time)) {
  volume[t] <- volume[t - 1] + (fill_rate - drain_rate) # Net flow
  if (volume[t] > max_volume) volume[t] <- max_volume  # Prevent overflow
  if (volume[t] < 0) volume[t] <- 0                    # Prevent negative volume
}

# Create a data frame for plotting
data <- data.frame(
  Time = time / 3600, # Convert time to hours for plotting
  Volume = volume
)

# Plot the changes in water volume over time
ggplot(data, aes(x = Time, y = Volume)) +
  geom_line(color = "blue", size = 1) +
  geom_hline(yintercept = max_volume, linetype = "dashed", color = "red") +
  labs(
    title = "Changes in Water Volume in Bathtub",
    x = "Time (hours)",
    y = "Water Volume (liters)"
  ) +
  theme_minimal() +
  annotate("text", x = 1, y = max_volume - 50, label = "Max Capacity", color = "red", size = 4, hjust = 0)

head(data)