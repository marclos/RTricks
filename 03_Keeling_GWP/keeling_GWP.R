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



