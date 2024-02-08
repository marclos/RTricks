# Guide2functions.R
# Updated: 2024-02-07


#-------------------------------------------------------------------------------
# Function to Read CSV Files into R
ReadStations.fun <- function(datafolder){
  StationList <- list.files(datafolder, full.names=TRUE, pattern = "\\.csv$")
   # exclude unfinished stuff
  StationList <- StationList[!grepl("\\-TMAX.csv$", StationList)]
  StationList <- StationList[!grepl("\\-TMIN.csv$", StationList)]
  StationList <- StationList[!grepl("\\-PRCP.csv$", StationList)]
  #CHCNd_ID = read.csv(my.inventory.csv))
  # Fix Variable Names based on NOAA Documentation
  colnames <- c("ID", "DATE", "ELEMENT", "VALUE", 
                "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  for (i in 1:length(StationList)){
    assign(paste0("station", i), read.csv(StationList[i], 
        header=TRUE, col.names=colnames), envir = parent.frame())
  return(paste0("station", i))
  }
}

#-------------------------------------------------------------------------------
ReadStations2.fun <- function(datafolder){
  my.stations = read.csv(paste0(datafolder, "my.inventory.csv"))
# Fix Variable Names based on NOAA Documentation
colnames <- c("ID", "DATE", "ELEMENT", "VALUE", 
              "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
for (i in 1:nrow(my.stations)){
  assign(my.stations$ID[i], 
  read.csv(paste0(datafolder, noquote(my.stations$ID[i]), ".csv"), header=TRUE, col.names=colnames), envir = parent.frame())
}
}

#-------------------------------------------------------------------------------
# number of observations for each dataframe
# 2/8/2024 Not working yet.
sortStations.fun <- function(my.inventory){
  for(i in 1:nrow(my.inventory)){
    x[i] <- nrow(my.inventory$ID[i])
    print(x[i])
    return(x)
  }}


#-------------------------------------------------------------------------------
# function to fix date formats, etc.
fixDates.fun <- function(station){
  station$Ymd = as.Date(as.character(station$DATE), format = "%Y%m%d")
  station$MONTH = as.numeric(format(station$Ymd, "%m"))
  station$YEAR = as.numeric(format(station$Ymd, "%Y"))
  return(station)
}

#-------------------------------------------------------------------------------
# Data Coverage Function --Determine percent missing
coverage.fun <- function(station, element="TMAX"){
  Dates.all = data.frame(Ymd=seq.Date(from=min(station$Ymd), 
                          to=max(station$Ymd), by="day"))
  station.full = merge(Dates.all, station, all = TRUE)
  station.coverage = 
    sum(!is.na(station.full$VALUE[station.full$ELEMENT==element]))/
  length(station.full$VALUE[station.full$ELEMENT==element])*100
  return(round(station.coverage,2))
  }


#-------------------------------------------------------------------------------
# Function to Convert/Transform Units
fixValues.fun <- function(station){
    station$VALUE = station$VALUE/10
  return(station)
}

#-------------------------------------------------------------------------------
# QA/QC Function
QAQC.fun <- function(station){
  par(mfrow=c(1,1)) # chnaged this from 3 to 1 because of window size issues
  plot(VALUE ~ Ymd, data = subset(station, 
      subset=ELEMENT=="PRCP"), type = "l", col = "blue", 
    main = "Time Series of Daily PRCP", xlab = "Date", ylab = "PRCP (mm)")
  plot(VALUE ~ Ymd, data = subset(station, subset=ELEMENT=="TMAX"), 
      type = "l", col = "blue", 
    main = "Time Series of Daily TMAX", xlab = "Date", ylab = "TMAX (C)")
  plot(VALUE ~ Ymd, data = subset(station, 
      subset=ELEMENT=="TMIN"), type = "l", col = "blue", 
    main = "Time Series of Daily TMIN", xlab = "Date", ylab = "TMIN (C)") 
  station = subset(station, Q.FLAG != "")
  station = subset(station, M.FLAG != "")
  station = subset(station, S.FLAG != "")
  return(station)
}

#-------------------------------------------------------------------------------
# Create Monthly Averages/Sums
MonthlyValues.fun <- function(x){
  x.TMAX.monthly = aggregate(VALUE ~ MONTH + YEAR, 
        data = subset(x, ELEMENT == "TMAX"), mean)
  names(x.TMAX.monthly) <- c("MONTH", "YEAR", "TMAX")
  x.TMIN.monthly = aggregate(VALUE ~ MONTH + YEAR, 
        data = subset(x, ELEMENT == "TMIN"), mean)
  names(x.TMIN.monthly) <- c("MONTH", "YEAR", "TMIN")
  x.PRCP.monthly = aggregate(VALUE ~ MONTH + YEAR, 
        data = subset(x, ELEMENT == "PRCP"), sum)
  names(x.PRCP.monthly) <- c("MONTH", "YEAR", "PRCP")
  return(list(x.TMAX.monthly, x.TMIN.monthly, x.PRCP.monthly))
}


#-------------------------------------------------------------------------------
# Function to Create Monthly Normals
MonthlyNormals.fun <- function(x){
  x.normals = subset(x, 
    Ymd >= "1961-01-01" & Ymd <= "1990-12-31")  
  x.TMAX.normals.monthly = aggregate(VALUE ~ MONTH, 
    data = subset(x.normals, ELEMENT == "TMAX"), mean)
  names(x.TMAX.normals.monthly) <- c("MONTH", "NORMALS")
  x.TMIN.normals.monthly = aggregate(VALUE ~ MONTH, 
    data = subset(x.normals, ELEMENT == "TMIN"), mean)
  names(x.TMIN.normals.monthly) <- c("MONTH", "NORMALS")
  x.PRCP.normals.month.year = aggregate(VALUE ~ MONTH + YEAR, 
    data = subset(x.normals, ELEMENT == "PRCP"), sum)
  x.PRCP.normals.monthly = aggregate(VALUE ~ MONTH, 
    data = subset(x.PRCP.normals.month.year), mean)
  names(x.PRCP.normals.monthly) <- c("MONTH", "NORMALS")
  return(list(x.TMAX.normals.monthly, 
              x.TMIN.normals.monthly, 
              x.PRCP.normals.monthly))
}

#-------------------------------------------------------------------------------
# Check on PRCP Values!
#par(mfrow=c(1,1))
#plot(VALUE ~ Ymd, data = subset(station1a, subset=ELEMENT=="PRCP"), type = "p", col = "blue", main = "Time Series of Daily PRCP", xlab = "Date", ylab = "PRCP (mm)", pch=20, cex=.2)
#plot(NORMALS ~ MONTH, data = station1.normals[[3]], type = "p", col = "blue", main = "NORMALS PRCP", xlab = "MONTH", ylab = "PRCP (mm)") 
#plot(PRCP ~ YEAR + MONTH, data = station1.monthly[[3]], type = "p", col = "blue",  main = "MONTHLY PRCP", xlab = "MONTH", ylab = "PRCP (mm)")


#-------------------------------------------------------------------------------
# Function to Calculate Monthly Anomalies
MonthlyAnomalies.fun <- function(station.monthly, station.normals){
for(i in seq_along(station.monthly)){
  TMAX <- merge(station.monthly[[1]], station.normals[[1]], by = "MONTH")
  TMAX$TMAX.a = TMAX$TMAX - TMAX$NORMALS
  TMAX$Ymd = as.Date(paste(TMAX$YEAR, TMAX$MONTH, "01", sep = "-"))
  TMIN <- merge(station.monthly[[2]], station.normals[[2]], by = "MONTH")
  TMIN$TMIN.a = TMIN$TMIN - TMIN$NORMALS
  TMIN$Ymd = as.Date(paste(TMIN$YEAR, TMIN$MONTH, "01", sep = "-"))
  PRCP <- merge(station.monthly[[3]], station.normals[[3]], by = "MONTH")
  PRCP$PRCP.a = PRCP$PRCP - PRCP$NORMALS 
  PRCP$Ymd = as.Date(paste(PRCP$YEAR, PRCP$MONTH, "01", sep = "-"))
  return(list(TMAX = TMAX, TMIN = TMIN, PRCP = PRCP))  
  }
}

#-------------------------------------------------------------------------------
# Function to Up R Environment
## Write Anomaly Data to CSV
## Remove functions from Guide 1 and 2 from environment
## Remove station data, except anomaly data from environment

## doesn't work yet
SaveCleanUp.fun <- function(datapath){
      anamolies.ls = ls(pattern="*.anomalies", envir = parent.frame())
      save(list = anamolies.ls, file=paste0(datafolder, "anamolies", ".RData"))      
      #rm(list = ls(pattern="fun"), envir = parent.frame())
      #rm(list = station.obj, envir = parent.frame())
}

# test function
# SaveCleanUp.fun(datafolder)

#-------------------------------------------------------------------------------
# Function to Save Anomaly Data

# I think this is a good idea, but the path issues are complicated, so 
# I haven't implemented it yet. 

#save(USC00042294.anomalies, file=paste0(datafolder, "anomalies", ".RData"))
