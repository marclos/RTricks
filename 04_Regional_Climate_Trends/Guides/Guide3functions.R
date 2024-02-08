# Guide3functions.R
# Updated: 2024-02-07

# Function to Determine Trends for Each Month

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
    print("RData file does not exist.")
}
}

if (file.exists(paste0(datapath, "anamolies.RData" ))) {
  load(file="/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/SP24/anamolies.RData")
  print("RData file found and loaded")
} else {
  print("RData file does not exist.")
}

# test function
# rm(USC00042294.anamolies)
# datapath = "/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/SP24/"
# LoadData.fun(datapath)


#load("C:/Users/Owner/Documents/Georgetown/Analytics/Analytics Programming/Week 3/USC00042294.RData")

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

# Testing the trend since 1975, where evidence suggest global
# warming has been more pronounced or even accerating

# USC00042294.1975 <- lapply(USC00042294.anomalies, function(x) subset(x, YEAR >= 1975))

# test function
# USC00042294.trends <- monthlyTrend.fun(USC00042294.1975)


# Plot the results

#TMAX.lm <- lm(TMAX.a ~ YEAR, data=subset(USC00042294TMAX, MONTH==1))
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
