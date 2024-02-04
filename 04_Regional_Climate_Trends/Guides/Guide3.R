# Guide3.R

# Function to Determine Trends for Each Month

# Read Data into List of Dataframes
# This method of using data required when I Rstudio to knit code
# which creates its own environment and the objects created in the 
# console are not available to the knitted code. Just learned 
# this from the discussion board after years of some minor 
# frustration.

load(file=paste0(datafolder, "USC00042294.anomalies", ".RData"))

read_and_load_data.fun <- function(x){
  print("This function might not be needed, waiting to see how the class does")
}


#load("C:/Users/Owner/Documents/Georgetown/Analytics/Analytics Programming/Week 3/USC00042294.RData")

# Look at the data

@------------------------------------------------------------------------------
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

USC00042294.1975 <- lapply(USC00042294.anomalies, function(x) subset(x, YEAR >= 1975))

# test function
USC00042294.trends <- monthlyTrend.fun(USC00042294.1975)


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
