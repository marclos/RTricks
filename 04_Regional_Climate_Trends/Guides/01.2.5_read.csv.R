# knit rchunktest.R
x = summary(cars)

# Path: 04_Regional_Climate_Trends/01_Station_Data.R
# here::here("04_Regional_Climate_Trends", my.stations$ID[i])
my.stations = subset(stations.active.oldest, STATE == my.state)

