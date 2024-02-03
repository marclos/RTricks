# Guide2.R

# Function to Read Station Data in R Environment
ReadStation.fun <- function(datafolder, station="station1"){
  station = read.csv(paste0(datafolder, station, ".csv"))
  return(station)
}

# function to fix date formats, etc.
fixdates.fun <- function(x=station1){
  x$Ymd = as.Date(as.character(x$DATE), format = "%Y%m%d")
  x$MONTH = as.numeric(format(x$Ymd, "%m"))
  x$YEAR = as.numeric(format(x$Ymd, "%Y"))
  return(x)
}

# Data Coverage Function --Determine percent missing
coverage.fun <- function(station, element){
    Dates.all = data.frame(Ymd=seq.Date(from=min(station$Ymd), to=max(station$Ymd), by="day"))
    station.full = merge(Dates.all, station, all = TRUE)
    station.coverage = sum(!is.na(station.full$VALUE[station.full$ELEMENT==element]))/
      length(station.full$VALUE[station.full$ELEMENT==element])*100
    return(round(station.coverage,2))
  }


# Create Monthly Averages/Sums
MonthlyValues.fun <- function(x=station1){
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

# Function to Create Monthly Normals
MonthlyNormals.fun <- function(x=station1){
  x.normals = subset(x, Ymd >= "1961-01-01" & Ymd <= "1990-12-31")  
  x.TMAX.normals.monthly = aggregate(VALUE ~ MONTH, 
                                     data = subset(x.normals, ELEMENT == "TMAX"), mean)
  names(x.TMAX.normals.monthly) <- c("MONTH", "NORMALS")
  x.TMIN.normals.monthly = aggregate(VALUE ~ MONTH, 
                                     data = subset(x.normals, ELEMENT == "TMIN"), mean)
  names(x.TMIN.normals.monthly) <- c("MONTH", "NORMALS")
  x.PRCP.normals.monthly = aggregate(VALUE ~ MONTH, 
                                     data = subset(x.normals, ELEMENT == "PRCP"), sum)
  names(x.PRCP.normals.monthly) <- c("MONTH", "NORMALS")
  return(list(x.TMAX.normals.monthly, x.TMIN.normals.monthly, x.PRCP.normals.monthly))
}


# Function to Create Monthly Anomalies
MonthlyAnomalies.fun <- function(station=station1){
  x.TMAX.anomaly = merge(x.TMAX.monthly, x.TMAX.normals.monthly, by = "MONTH")
  x.TMAX.anomaly$TMAX.anomaly = x.TMAX.anomaly$TMAX - x.TMAX.anomaly$NORMALS
  x.TMIN.anomaly = merge(x.TMIN.monthly, x.TMIN.normals.monthly, by = "MONTH")
  x.TMIN.anomaly$TMIN.anomaly = x.TMIN.anomaly$TMIN - x.TMIN.anomaly$NORMALS
  x.PRCP.anomaly = merge(x.PRCP.monthly, x.PRCP.normals.monthly, by = "MONTH")
  x.PRCP.anomaly$PRCP.anomaly = x.PRCP.anomaly$PRCP - x.PRCP.anomaly$NORMALS
  TEMP <- merge(x.TMAX.anomaly, x.TMIN.anomaly, by = c("MONTH", "YEAR") )
  x.anomaly <- merge(TEMP, x.PRCP.anomaly, by = c("MONTH", "YEAR"))[,c(1:3, 5:6, 8:9, 11)]
  return(x.anomaly)
}

# Function to Up R Environment
CleanUp.fun <- function(datafolder, station=station1){
  write.csv(station, file = paste0(datafolder, "station1.csv"), row.names = FALSE)
  rm(station)
  rm(list = ls()[!ls() %in% c("fixdates.fun", "coverage.fun", 
                              "MonthlyValues.fun", "MonthlyNormals.fun")])
  
}



