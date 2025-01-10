# Example: Refrigerant reduction and GWP calculation

# Data: Refrigerant types, mass reduced (kg), and their GWP values
refrigerants <- data.frame(
  Type = c("R-134a", "R-404A", "R-410A", "R-32"),
  MassReduced_kg = c(10, 5, 8, 12), # Reduced mass in kg
  GWP = c(1430, 3922, 2088, 675)    # GWP values (AR5 or other standard)
)

# Calculate the GWP reduction for each refrigerant
refrigerants$GWP_Reduction = refrigerants$MassReduced_kg * refrigerants$GWP

# Total GWP reduction
total_gwp_reduction <- sum(refrigerants$GWP_Reduction)

# Display results
print("Refrigerant Reduction Summary:")
print(refrigerants)
cat("\nTotal GWP Reduction (kg CO2-eq):", total_gwp_reduction)

# Optional: Visualize the GWP reduction by refrigerant type
library(ggplot2)
ggplot(refrigerants, aes(x = Type, y = GWP_Reduction, fill = Type)) +
  geom_bar(stat = "identity") +
  theme_minimal() +
  labs(title = "GWP Reduction by Refrigerant Type",
       x = "Refrigerant Type",
       y = "GWP Reduction (kg CO2-eq)") +
  theme(legend.position = "none")


# Example: Refrigerant GWP reduction with technology trade-offs
# Example: Refrigerant GWP reduction with technology trade-offs

# Data: Refrigerant types, mass reduced (kg), GWP values, and energy trade-offs
refrigerants <- data.frame(
  Type = c("R-134a", "R-404A", "R-410A", "R-32"),
  MassReduced_kg = c(10, 5, 8, 12),    # Reduced mass in kg
  GWP = c(1430, 3922, 2088, 675),      # GWP values (AR5 or other standard)
  EnergyTradeoff_CO2eq = c(-200, 300, -150, -100) # Trade-offs in kg CO2-eq
)

# Calculate the GWP reduction for refrigerant replacement
refrigerants$GWP_Reduction = refrigerants$MassReduced_kg * refrigerants$GWP

# Adjust for energy-related trade-offs
refrigerants$Net_GWP_Reduction = refrigerants$GWP_Reduction + refrigerants$EnergyTradeoff_CO2eq

# Total GWP reductions
total_gwp_reduction <- sum(refrigerants$GWP_Reduction)
total_net_gwp_reduction <- sum(refrigerants$Net_GWP_Reduction)

# Display results
print("Refrigerant Reduction Summary with Trade-Offs:")
print(refrigerants)
cat("\nTotal GWP Reduction (kg CO2-eq, no trade-offs):", total_gwp_reduction)
cat("\nTotal Net GWP Reduction (kg CO2-eq, with trade-offs):", total_net_gwp_reduction)

# Optional: Visualize the GWP reduction and net GWP reduction
library(ggplot2)
ggplot(refrigerants, aes(x = Type)) +
  geom_bar(aes(y = GWP_Reduction, fill = "GWP Reduction"), stat = "identity", position = "dodge") +
  geom_bar(aes(y = Net_GWP_Reduction, fill = "Net GWP Reduction"), stat = "identity", position = "dodge") +
  scale_fill_manual(values = c("GWP Reduction" = "skyblue", "Net GWP Reduction" = "orange")) +
  theme_minimal() +
  labs(title = "GWP Reduction by Refrigerant Type with Trade-Offs",
       x = "Refrigerant Type",
       y = "GWP Reduction (kg CO2-eq)",
       fill = "Reduction Type")

