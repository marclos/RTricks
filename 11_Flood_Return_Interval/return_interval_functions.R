# Flood Frequency Functions
# Marc Los Huertos
# April 4, 2024
# Version 1.0


# Get Annual Peak Flow Data Function
# Need one library; I think!

# Remeber -- you much "source()" this file to load functions into the R environment

# This function gets the annual peak flow data from the USGS NWIS database. It will
# return a data frame with the annual peak flow data. The function takes three arguments:
# site: the USGS site number
# startDate: the start date for the data (optional)
# endDate: the end date for the data (optional)
# The function will return a data frame, but must include an assignment statement
# to save the data. The function will also remove any rows with missing values in the
# peak flow or date columns. 

getAnnualPeak.fun<- function(site, startDate="", endDate=""){
  # Load required libraries
  library(dataRetrieval)
#  library(ggplot2)
#  suppressMessages(library(dplyr))
  
  annualpeak <- readNWISpeak(site, startDate, endDate)
  annualpeak = annualpeak[complete.cases(annualpeak$peak_va),]
  annualpeak = annualpeak[complete.cases(annualpeak$peak_dt),]
  return(annualpeak)
}

# Split Data Function
# This function splits the annual peak data into two periods based on a date.
# It creates a list of two data frames, which is a pain to deal with, but it's 
# the most effecient in the day that I wrote this function.

# NOTE: returns a list of two data frames, i.e. need assign list name!

splitdata.fun<- function(annualpeak, splitdate){
  
  period1 = annualpeak[annualpeak$peak_dt < splitdate,]
  period2 = annualpeak[annualpeak$peak_dt >= splitdate,]
  periodlist = list(period1, period2)
  return(periodlist)
}


# This is a complicated function, luckily, I was able to get some of the code
# from ChatGPT.  I think it is a good example of how to use the function
# to create a plot of the flood return interval.  It is a little bit of a mess
# but it works. I hope to fix it and make it better for 2026.

plot_floodreturn.fun <- function(annualpeak, Qmax_2025){
  
  graphlab = paste(range(format(as.Date(
    annualpeak$peak_dt, format="%d/%m/%Y"),"%Y")), 
    collapse = "-")
  
  Q = annualpeak$peak_va
  va_range = range(annualpeak$peak_va)
  site_no = annualpeak$site_no[1]
  
  #Generate plotting positions
  n = length(Q)
  r = n + 1 - rank(Q)  # highest Q has rank r = 1
  T = (n + 1)/r
  
  # Set up x axis tick positions and labels
  Ttick = c(1.001,1.01,1.1,1.5,2,3,4,5,6,7,8,9,10,11,12,13,14,
            15,16,17,18,19,20,25,30,35,40,45,50,60,70,80,90,100)
  xtlab = c(1.001,1.01,1.1,1.5,2,NA,NA,5,NA,NA,NA,NA,10,NA,NA,
            NA,NA,15,NA,NA,NA,NA,20,NA,30,NA,NA,NA,50,NA,NA,NA,NA,100)
  y = -log(-log(1 - 1/T))
  ytick = -log(-log(1 - 1/Ttick))
  xmin = min(min(y),min(ytick))
  xmax = max(ytick)
  
  # Fit a line by method of moments, along with 95% confidence intervals
  KTtick = -(sqrt(6)/pi)*(0.5772 + log(log(Ttick/(Ttick-1))))
  QTtick = mean(Q) + KTtick*sd(Q) 
  nQ = length(Q)
  se = (sd(Q)*sqrt((1+1.14*KTtick + 1.1*KTtick^2)))/sqrt(nQ) 
  LB = QTtick - qt(0.975, nQ - 1)*se
  UB = QTtick + qt(0.975, nQ - 1)*se
  max = max(UB)
  Qmax = max(QTtick)
  
  
  # Plot peak flow series with Gumbel axis
  plot(y, Q,
       ylab = expression( "Annual Peak Flow (cfs)" ) ,
       xaxt = "n", xlab = "Return Period, T (year)",
       ylim = c(0, va_range[2]),
       xlim = c(xmin, xmax),
       pch = 21, bg = "orange",
       main = paste(site_no, graphlab)
  )  
  par(cex = 0.65)
  axis(1, at = ytick, labels = as.character(xtlab))
  
  # Add fitted line and confidence limits
  lines(ytick, QTtick, col = "black", lty=1, lwd=2)  
  lines(ytick, LB, col = "blue", lty = 1, lwd=1.5)
  lines(ytick, UB, col = "red", lty = 1, lwd=1.5)  
  
  # Draw grid lines
  abline(v = ytick, lty = 3, col="light gray")             
  abline(h = seq(0, va_range[2], length.out=6), lty = 3,col="light gray") 
  par(cex = 1)
  
  abline(h=Qmax_2025, lty=3, lwd=2, col="red")
}

# End of Function File