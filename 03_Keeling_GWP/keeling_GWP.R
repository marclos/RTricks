# 02 Getting Mauna Loa Data

CO2 <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/co2/co2_mm_mlo.csv", skip=40)
CH4 <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/ch4/ch4_mm_gl.csv", skip=45)
N2O <- read.csv("https://gml.noaa.gov/webdata/ccgg/trends/n2o/n2o_mm_gl.csv", skip=45)


names(CO2)
names(CH4)


plot(average ~ decimal.date, data=CO2, pch=20, col='grey', cex=.3, las=1, ylab="ppm (v/v)", ylim=c(300, 430))
points(average/5 ~ decimal, data=CH4, pch=20, col='blue', cex=.3)
points(average/1 ~ decimal, data=N2O, pch=20, col='red', cex=.3)
