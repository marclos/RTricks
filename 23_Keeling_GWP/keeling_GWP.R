# 02 Getting Mauna Loa Data

CO2 <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/co2/co2_mm_mlo.csv", skip=40)
CH4 <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/ch4/ch4_mm_gl.csv", skip=45)
N2O <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/n2o/n2o_mm_gl.csv", skip=45)


names(CO2)
names(CH4)

par(las=1, mar=c(5, 4, 4, 10) + 0.1)
years = c(1958, 2025)
plot(average ~ decimal.date, data=CO2, pch=20, col='grey', cex=.2, las=1, ylab="CO2 (ppm v/v)", ylim=c(300, 430), xlim=years, xlab="Year")
par(new = TRUE)
plot(average ~ decimal, data=CH4, pch=20, col='blue', cex=.2, axes=FALSE, xlim=years, xlab=NA, ylab=NA)
axis(4, col = "blue", col.ticks='blue', col.axis='blue')
mtext("CH4 (ppb v/v)", side = 4, line = 3, las=0, col='blue')
par(new = TRUE)
plot(average ~ decimal, data=N2O, pch=20, col='red', cex=.2, axes=FALSE, xlim=years, xlab=NA, ylab=NA, ylim=c(310, 340))
axis(4, col = "red", line=5, col.ticks='red', col.axis='red')
mtext("N2O (ppb v/v)", side = 4, line = 8, las=0, col='red')

# GWP
# Required library for trapezoidal integration
if (!require("pracma")) install.packages("pracma")
library(pracma)

# Parameters
H <- 100                        # Time horizon (years)
time <- seq(0, H, by = 1)       # Time steps (1-year intervals)

# Radiative efficiencies (W/m² per ppb)
RE_CO2 <- 1.4e-5                # CO₂ radiative efficiency
RE_CH4 <- 3.63e-4               # CH₄ radiative efficiency

# Atmospheric lifetimes (years)
tau_CO2 <- 1000                 # Approximate CO₂ effective lifetime (simplified)
tau_CH4 <- 12                   # CH₄ atmospheric lifetime

# Exponential decay over time
decay_CO2 <- exp(-time / tau_CO2)
decay_CH4 <- exp(-time / tau_CH4)

plot(time, decay_CH4)

# Radiative forcing integrals (numerical approximation using trapezoidal rule)
forcing_CO2 <- trapz(time, RE_CO2 * decay_CO2)
forcing_CH4 <- trapz(time, RE_CH4 * decay_CH4)

# Calculate GWP
GWP_CH4 <- forcing_CH4 / forcing_CO2
print(paste("The GWP of CH₄ over", H, "years is:", round(GWP_CH4, 2)))


