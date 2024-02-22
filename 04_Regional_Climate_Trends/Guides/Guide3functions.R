# Guide3functions.R
# Updated: 2024-02-15

# Read Data into List of Dataframes
# This method of using data required when I Rstudio to knit code
# which creates its own environment and the objects created in the 
# console are not available to the knitted code. Just learned 
# this from the discussion board after years of some minor 
# frustration.

#load(file=paste0(datafolder, "USC00042294.anomalies", ".RData"))

read_and_load_data.fun <- function(x){
  print("This function might not be needed, waiting to see how the class does")
}

LoadData.fun <- function(datafolder){
  if (file.exists(paste0(datafolder, "anamolies.RData" ))) {
    load(file=paste0(datafolder, "anamolies.RData"))
    print("RData file found and loaded")
  } else {
    print("RData file does not exist (Not if you have all functions in one Rmd file!).")
}
}

if (file.exists(paste0(datapath, "anomalies.RData" ))) {
  load(file=paste0(datapath, "anomalies.RData"))
  print("RData file found and loaded")
} else {
  print("RData file does not exist.")
}

# test function
# rm(USC00042294.anamolies)
# datapath = "/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/SP24/"
# LoadData.fun(datapath)

#-------------------------------------------------------------------------------
# Get Station Information, e.g. State Name, etc.
station_names = c("ID",             #  1-11   Character   11
                  "LATITUDE",       # 13-20   Real        8
                  "LONGITUDE",      # 22-30   Real        9
                  "ELEVATION",      # 32-37   Real        6
                  "STATE",          # 39-40   Character   2
                  "NAME",           # 42-71   Character
                  "GSN FLAG",       # 73-75   Character
                  "HCN/CRN FLAG",   # 77-79   Character
                  "WMO ID"          # 81-85   Character
)

# Read ghcnd-stations.txt with fixed width format
Stations = read.fwf("https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-stations.txt", 
                    col.names=station_names, fill=2,
                    widths=c(11, -1, 8, -1, 9, -1, 6, -1, 2, -1, 30, -1, 3, -1, 3, -1, 5 ))

# NOTE: Got to be a better way to get these data!

# str(Stations) # Missing State Name

# Now we'll get the state names for the states.
State_names = c("STATE", #         1-2    Character 2
                "STATE_NAME") #         4-50    Character 46
States = read.fwf("https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-states.txt", 
                  col.names=State_names, fill=2, 
                  widths=c(2, -1, 46))

# str(States)
# Merge the two datasets
StateIDs = subset(Stations, select=c("ID", "STATE", "LATITUDE", "LONGITUDE", "ELEVATION", "NAME"))
StateIDs = merge(StateIDs, States, by="STATE") # Add State Names

# Look at the data

#------------------------------------------------------------------------------
# Function to analyze each month's trend
monthlyTrend.fun <- function(station) {
  # Disaggregate the data
    TMAX = station$TMAX
    TMIN = station$TMIN
    PRCP = station$PRCP
    TMAX.lm = lapply(1:12, function(i) {
      lm(TMAX.a ~ YEAR, data=subset(TMAX, MONTH==i))
    })  
    TMIN.lm = lapply(1:12, function(i) {
      lm(TMIN.a ~ YEAR, data=subset(TMIN, MONTH==i))
    })
    PRCP.lm = lapply(1:12, function(i) {
      lm(PRCP.a ~ YEAR, data=subset(PRCP, MONTH==i))
    })
    
    # Summarize the results
    TMAX.summary <- lapply(TMAX.lm, summary)
    TMIN.summary <- lapply(TMIN.lm, summary)
    PRCP.summary <- lapply(PRCP.lm, summary)
    
    # Summarize lapply summary with a table
    # including coefficients for each month and the p-value
    TMAX.stats <- lapply(TMAX.summary, function(x) {
      c(r.squared = x$r.squared,
        x$coefficients[2,1:4]
      )
    })
    TMIN.stats <- lapply(TMIN.summary, function(x) {
      c(r.squared = x$r.squared,
        x$coefficients[2,1:4]
      )
    })
    PRCP.stats <- lapply(PRCP.summary, function(x) {
      c(r.squared = x$r.squared,
        x$coefficients[2,1:4]
      )
    })
    TMAX.stats <- lapply(TMAX.stats, function(x) x[c(1:5)])
    TMAX <- as.data.frame(do.call(rbind, TMAX.stats))
    TMAX$MONTH <- 1:12; TMAX$ELEMENT <- "TMAX"
    TMIN.stats <- lapply(TMIN.stats, function(x) x[c(1:5)])
    TMIN <- as.data.frame(do.call(rbind, TMIN.stats))
    TMIN$MONTH <- 1:12 ; TMIN$ELEMENT <- "TMIN"
    PRCP.stats <- lapply(PRCP.stats, function(x) x[c(1:5)])
    PRCP <- as.data.frame(do.call(rbind, PRCP.stats))
    PRCP$MONTH <- 1:12; PRCP$ELEMENT <- "PRCP"
    
    # Return the results
    return(rbind(TMAX[,c(7,6,2:5,1)], TMIN[,c(7,6,2:5,1)], PRCP[,c(7,6,2:5,1)]))
}

# test function
# USC00042294.trends <- monthlyTrend.fun(USC00042294.anomalies)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Function to Plot the Trend, for a given month and element
plotTrend2.fun <- function(station, element, month) {
  if(element == "TMAX"){
    list = 1
    temp = subset(station[[list]], subset=MONTH==month)
    daterange = range(temp$Ymd)
    formula = as.formula("TMAX.a ~ Ymd")
    ylab="Temperature Anamoly (C)"
    main1="Maximum Temperature"
  } else if(element == "TMIN"){
    list = 2
    temp = subset(station[[list]], subset=MONTH==month)
    daterange = range(temp$Ymd)
    formula = as.formula("TMIN.a ~ Ymd") 
    ylab="Temperature Anamoly (C)"
    main1="Minimum Temperature"
  } else if(element == "PRCP"){
    list = 3
    temp = subset(station[[list]], subset=MONTH==month)
    daterange = range(temp$Ymd)
    formula = as.formula("PRCP.a ~ Ymd")
    main1="Precipitation"
    ylab="Precipitation Anamoly (mm)"
  }
  
  temp.lm <- lm(formula, data=temp)
  
  sub=paste0("Trend: ", round(coef(temp.lm)[2]*365.25*100, 4), " C/100 Year; R-squared: ", round(summary(temp.lm)$r.squared, 3), "; p-value: ", round(summary(temp.lm)$coefficients[2,4], 3))
  
  station.text = sub("\\..*", "", deparse(substitute(station)))
  citystate = paste0(trimws(subset(StateIDs, subset = ID == substr(station.text,1,11))$NAME, which = "right"), ", ", subset(StateIDs, subset = ID == substr(station.text,1,11))$STATE)
  
  main=paste0(main1, " Anomaly (", month.name[month], ") at ", sub("\\..*", "", citystate))
  
  par(mfrow=c(1,1), mar=c(4,4,2,2), oma=c(0,0,2,0), las=1)
  plot(formula, data=temp, pch=19, 
       ylab=ylab, xlab="Year", col="gray", cex=.5, 
       main="")
  mtext(main, side=3, line=2, cex=1.1)
  mtext(sub, side=3, line=1, cex=.8)
  abline(coef(temp.lm), col="red")
}

# test function
# station = "USC00042294"
# extracting name of station from the object name
# sub("\\..*", "", deparse(substitute(USC00042294.anomalies)))
# plotTrend.fun(USC00042294.anomalies, "TMAX", 6)
# plotTrend.fun(USC00042294.anomalies, "TMIN", 7)
# plotTrend.fun(USC00042294.anomalies, "PRCP", 1)


# Testing the trend since 1975, where evidence suggest global
# warming has been more pronounced or even accerating

# USC00042294.1975 <- lapply(USC00042294.anomalies, function(x) subset(x, YEAR >= 1975))

# test function
# USC00042294.trends <- monthlyTrend.fun(USC00042294.1975)

#subset(station[element][[list]], subset=MONTH==month)

#TMIN.lm <- lm(TMIN.a ~ YEAR, data=subset(USC00042294.anamolies[[2]], MONTH==1))

#coef(TMAX.lm)
#summary(TMAX.lm)
#plot(TMAX.a ~ YEAR, data=subset(USC00042294TMAX, MONTH==1), pch=19, col="gray", cex=.5)
#abline(TMAX.lm, col="red")


#-------------------------------------------------------------------------------
#Loopwithfunction, eval=FALSE, echo=TRUE>>=

MonthEvalStats.fun <- function(GSOM) {
  sumstats = NA
  for (m in 1:12){
    TMIN.lm = lm(TMIN~Date, GSOM[GSOM$Month==m,])
    TMAX.lm = lm(TMAX~Date, GSOM[GSOM$Month==m,])
    PPT.lm  = lm(PPT~Date, GSOM[GSOM$Month==m,])
    
    sumstats = rbind(sumstats, 
                     data.frame(Month = m, Param="TMIN", Slope = coef(TMIN.lm)[2], 
                                r2 = summary(TMIN.lm)$r.squared, p_value= anova(TMIN.lm)$'Pr(>F)'[1]),
                     data.frame(Month = m, Param="TMAX", Slope = coef(TMAX.lm)[2], 
                                r2 = summary(TMAX.lm)$r.squared, p_value= anova(TMAX.lm)$'Pr(>F)'[1]),
                     data.frame(Month= m, Param="PPT", Slope = coef(PPT.lm)[2], 
                                r2 = summary(PPT.lm)$r.squared, p_value= anova(PPT.lm)$'Pr(>F)'[1]))
    
  } #end loop
  
  sumstats=data.frame(sumstats)[-1,]
  rownames(sumstats)<-NULL
  head(sumstats)
  
  sumstats$Symbol = ""
  sumstats$Symbol[sumstats$p_value < 0.05] = "*"
  sumstats$Symbol[sumstats$p_value < 0.01] = "**"
  sumstats$Symbol[sumstats$p_value < 0.001] = "***"
  return(sumstats)
}

# test function
# sumstats = MonthEvalStats(GSOM[500:4000,])


#-------------------------------------------------------------------------------
# Functions for Evaluating drought

# Function to calculate the SPI
spi.fun <- function(x, scale=3, fit="pearson3") {
  # Calculate the SPI
  spi = droughtTools::spi(x, scale=scale, fit=fit)
  return(spi)
}

# Function to Count the number of consecutive days of drought
droughtCount.fun <- function(station=USC00040693, threshold=0.1) {
  drought.df <- subset(station, ELEMENT=="PRCP")
  x <- drought.df$VALUE
  length(x)
  # Count the number of days of drought
  drought = x < threshold; str(drought)
  drought = rle(drought); str(drought)
  
  rle.values <- as.data.frame(do.call(cbind, drought)); str(rle.values)
  drought.df$Drought = as.logical(rep(rle.values$values, 
                times = rle.values$lengths)); head(drought.df)
  # change this to populate the end of the drough period MLH 2/4/2024
  drought.df$Length = rep(rle.values$lengths, rle.values$lengths); head(drought.df)
  if("Ymd" %in% names(drought.df) == FALSE){
    drought.df$Ymd = as.Date(as.character(drought.df$DATE), format = "%Y%m%d")
    drought.df$MONTH = as.numeric(format(drought.df$Ymd, "%m"))
    drought.df$YEAR = as.numeric(format(drought.df$Ymd, "%Y"))
  }
  drought.df$WY = ifelse(drought.df$MONTH < 10, drought.df$YEAR, drought.df$YEAR+1)
  #Drought = subset(station, Drought==TRUE); str(Drought)
  #values = run.length$values  
  
  str(drought.df)

  aggregate(drought.df$Drought, by=list(YEAR = drought.df$YEAR, MONTH = drought.df$MONTH), FUN=sum)
  DroughtperYear = aggregate(drought.df$Drought, by=list(WY = drought.df$WY), FUN=sum)
  RecordperYear = aggregate(drought.df$DATE, by=list(WY = drought.df$WY), FUN=length)

  drought = merge(RecordperYear, DroughtperYear, by="WY"); head(drought)
  drought$DroughtPerYear = round(drought$x.y/drought$x.x *100); head(drought)
  
  
  return(drought)
}

# Test Function
# USC00040693.drought <- droughtCount.fun(USC00040693, threshold=0.1)

# Scratch Pad
# str(USC00040693)
# USC00040693.PRCP <- subset(USC00040693, ELEMENT=="PRCP", select=VALUE)[1]$VALUE
# str(USC00040693.PRCP)
# str(USC00040693.drought)

# par(mfrow=c(1,1), las=1)
# plot(DroughtPerYear ~ WY, data=USC00040693.drought, col="gray", 
#     main="Percentage of Rainless Days", xlab="Water Year", ylab="Percent Days w/o Rain", pch=19, cex=.4)
# abline(h=mean(USC00040693.drought$DroughtPerYear), col="red", lty=2)
# abline(coef(lm(USC00040693.drought$DroughtPerYear ~ USC00040693.drought$WY)), col="blue", lty=2)
            



# What is a drought 10 days, 20 days, 40 days?

#Drought.run.10 = aggregate(lengths~Year, data=Drought.run[Drought.run$lengths>=10,], sum)
#Drought.run.20 = aggregate(lengths~Year, data=Drought.run[Drought.run$lengths>=20,], sum)
# Drought.run.40 = aggregate(lengths~Year, data=Drought.run[Drought.run$lengths>=40,], sum)

# if(Drought.run$lengths>100) {Drought.run.100 = aggregate(lengths~Year, data=Drought.run[Drought.run$lengths>=100,], sum)}
