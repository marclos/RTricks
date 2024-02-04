# Guide3.R

# Function to Determine Trends for Each Month

# Load the data

#load("C:/Users/Owner/Documents/Georgetown/Analytics/Analytics Programming/Week 3/USC00042294.RData")

# Look at the data


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




# Plot the results

TMAX.lm <- lm(TMAX.a ~ YEAR, data=subset(USC00042294TMAX, MONTH==1))
coef(TMAX.lm)
summary(TMAX.lm)
plot(TMAX.a ~ YEAR, data=subset(USC00042294TMAX, MONTH==1), pch=19, col="gray", cex=.5)
abline(TMAX.lm, col="red")