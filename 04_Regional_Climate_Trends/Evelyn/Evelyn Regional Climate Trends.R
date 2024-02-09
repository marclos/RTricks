library(here)
## here() starts at /home/mwl04747/RTricks
library(xtable)
stations.active.oldest = read.csv(
  here("04_Regional_Climate_Trends", "stations.active.oldest.csv"))
# OR
# use file.choose() to select the file
# filename = "MY.PATH/04_Regional_Climate_Trends/stations.active.oldest.csv"
# stations.active.oldest = read.csv(filename)

plot(stations.active.oldest$LONGITUDE,
     stations.active.oldest$LATITUDE,
     xlab = "Longitude",ylab = "Latitude",
     pch=20, cex=0.3, col='gray60', las=1,
     main = "US Weather Stations")

stations.unique =
  unique(stations.active.oldest[,c("STATE", "STATE_NAME")])
xtab = xtable(stations.unique)

my.state = "TX"

my.stations = subset(stations.active.oldest, STATE == my.state)
# Download Updated Station Data
i=1
here::here("04_Regional_Climate_Trends", my.stations$ID[i])

for(i in 1:nrow(my.stations)){
  url = paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/",
               my.stations$ID[i],
               ".csv.gz")
  print(i) # Print Index Number
  download.file(url, paste0(here::here("04_Regional_Climate_Trends",
                                       "Data",
                                       "SP24/"),
                            my.stations$ID[i],
                            ".csv.gz"),
                quiet = FALSE, mode = "w", cacheOK = TRUE)
  assign(paste0("station", i),
  
  read.csv(gzfile(paste0(here::here("04_Regional_Climate_Trends",
                                    "Data", "SP24/"),my.stations$ID[i], ".csv.gz")),
           header=FALSE))}

# LOOP END
## [1] 1
## [1] 2
## [1] 3
## [1] 4
## [1] 5


names(station1) <- c("ID", "DATE", "ELEMENT", "VALUE",
                     "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
names(station3) <- names(station2) <- names(station1)
names(station5) <- names(station4) <- names(station1)


## 'data.frame': 224921 obs. of 8 variables:
## $ ID : chr "USC00043157" "USC00043157" "USC00043157" "USC00043157" ...
## $ DATE : int 18670601 18670602 18670603 18670604 18670605 18670606 18670607 18670608## $ ELEMENT : chr "PRCP" "PRCP" "PRCP" "PRCP" ...
## $ VALUE : int 0 0 0 0 0 0 0 0 0 0 ...
## $ M-FLAG : chr "" "" "" "" ...
## $ Q-FLAG : chr "" "" "" "" ...
## $ S-FLAG : chr "F" "F" "F" "F" ...
## $ OBS-TIME: int NA NA NA NA NA NA NA NA NA NA ...


