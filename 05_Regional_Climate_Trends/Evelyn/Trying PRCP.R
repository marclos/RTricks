library(sf)
library(tidyverse)

my.state <- "TX"
filename.csv <- "/Users/EvelynMineo/RTricks/04_Regional_Climate_Trends/stations.active.oldest.csv"
my.inventory <- readInventory.fun(filename.csv, my.state)

datapath = "/Users/EvelynMineo/RTricks/04_Regional_Climate_Trends/Evelyn/"
downloadStations.fun(datapath, my.inventory)

datafolder = "/Users/EvelynMineo/RTricks/04_Regional_Climate_Trends/Evelyn/"
# Folder where the functions are
ReadStations2.fun(datafolder)
# Read stations into the working environment
ls() 
# Listing files/objects in R

USC00411017 <- fixDates.fun(USC00411017)
USW00013972 <- fixDates.fun(USW00013972)

coverage.fun(USC00411017)
coverage.fun(USW00013972)

USC00411017b <- fixValues.fun(USC00411017)
USW00013972b <- fixValues.fun(USW00013972)

QAQC.fun(USC00411017b)

USC00411017.monthly <- MonthlyValues.fun(USC00411017b)
USC00411017.normals <- MonthlyNormals.fun(USC00411017b)

USC00411017.anamolies <-
  MonthlyAnamolies.fun(USC00411017.monthly, USC00411017.normals)

## Specific to Max Temp Anamolies:

plot(TMAX.a~Ymd, subset(USC00411017.anamolies$TMAX, MONTH=1))

USC00411017.trends <- monthlyTrend.fun(USC00411017.anamolies)

plot(TMAX.a~Ymd, subset(USC00411017.anamolies$TMAX, subset=MONTH==7), pch=19)

plot(TMAX.a~Ymd, data = subset(USC00411017.anamolies$TMAX, MONTH == 1),pch = 19, cex = .2, col = "grey", xlab = "Year", ylab = "Temp Anomaly", main = "Temp Anomaly trend in Texas, USC00411017, July", sub = "Trend = -1ºC/100 Yr, rsquare = 0.017, pvalue < 0.001")

USC00411017.lm = lm(TMAX.a~Ymd, data = subset(USC00411017.anamolies$TMAX, MONTH == 1))
summary(USC00411017.lm)
abline(coef(USC00411017.lm), col = "red")


USC00411017.lm = lm(TMAX.a~Ymd, data = subset(USC00411017.anamalies$TMAX, MONTH = 1))
summary(USC00411017.lm)

abline(coef(USC00411017.lm), col = "red")

## Actual data:

plot(TMAX.a~Ymd, data = subset(USC00411017.anamolies$TMAX, MONTH == 1),pch = 19, cex = .2, col = "grey", xlab = "Year", ylab = "Temp Anomaly", main = "Temp Anomaly trend in Texas, USC00411017, July", sub = "Trend = -1ºC/100 Yr, rsquare = 0.017, pvalue < 0.001")

USC00411017.lm = lm(TMAX.a~Ymd, data = subset(USC00411017.anamolies$TMAX, MONTH == 1))
summary(USC00411017.lm)
abline(coef(USC00411017.lm), col = "red")


## Communicating Trends Using ggplot

ggplot( ) +
  geom_bar(data = PRCP.Season.Total, 
           aes(x=Year, y=PRCP, fill=Season), stat="identity") + 
  xlim(min(CHCND$Year), max(CHCND$Year)-1) +
  #ylab("Number of Extreme Temps") + # for the y axis label
  geom_smooth(data = PRCP.Total, 
              aes(y=PRCP, x=Year), method = "lm", 
              se = T, color= "black") 


## Looking at just precipitation:

plot(PRCP.a~Ymd, subset(USC00411017.anamolies$PRCP, MONTH=3))

USC00411017.trends <- monthlyTrend.fun(USC00411017.anamolies)

plot(PRCP.a~Ymd, subset(USC00411017.anamolies$PRCP, subset=MONTH==3), pch=19)

plot(PRCP.a~Ymd, data = subset(USC00411017.anamolies$PRCP, MONTH == 3),pch = 19, cex = .2, col = "grey", xlab = "Year", ylab = "Precipitation Anomaly", main = "Precipitation Anomaly trend in Texas, USC00411017, March", sub = "Trend = 3 inches?/Yr, rsquare = 0.0008, pvalue < 0.008")

USC00411017.lm = lm(PRCP.a~Ymd, data = subset(USC00411017.anamolies$PRCP, MONTH == 3))
summary(USC00411017.lm)
abline(coef(USC00411017.lm), col = "red")


## Now, plotting precipitation?


ggplot( ) +
  geom_bar(data = USC00411017.anamolies$PRCP, 
           aes(x=Year, y=PRCP, fill=MONTH), stat="identity") + 
  xlim(min(USC00411017.anamolies$Year), max(USC00411017.anamolies$Year)-1) +
  #ylab("Number of Extreme Temps") + # for the y axis label
  geom_smooth(data = USC00411017.anamolies$PRCP, 
              aes(y=PRCP, x=Year), method = "lm", 
              se = T, color= "black") 


CHCNDsub = subset(CHCND, CHCND$Year<=i,
                  select=c(Month, Month.name, TMAX, TMIN))
boxplot(TMAX ~ Month.name, data=CHCNDsub, xlab="", main="")
symbol.y = (par()$yaxp[2])-diff(par()$yaxp[1:2])*.99
#symbol.y = (par()£yaxp[2])
text(sumstats$Month, symbol.y, sumstats$TMAX_Symbol,
     col="red", cex=2)
mtext(paste("Maximum Daily Temperatures", min(CHCND$Year),
            "-", i, GSOM_Longest$name), line=1)
mtext("(NOTE: Red astrisks correspond to signficant changes)",
      line=0, cex=.7)


last years file names

