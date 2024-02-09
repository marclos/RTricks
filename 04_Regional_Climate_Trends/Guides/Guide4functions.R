# Guide4functions.R
# Updated: 2024-02-08

# Load RData for knit Enviornment
datapath = "/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/SP24/"
if (file.exists(paste0(datapath, "anamolies.RData" ))) {
  load(file=paste0(datapath, "anamolies.RData"))
  print("RData file found and loaded")
} else {
  print("RData file does not exist.")
}

par(mfrow=c(1,1))
#-------------------------------------------------------------------------------
# Create Basic Trend Line plot by month for one element
BasicTrendPlot.fun <- function(station, month, element){
  # Create Basic Trend Line plot by month for one element
plot(TMAX.a ~ Ymd, data=subset(USC00042294.anomalies$TMAX, MONTH==6), las=1, pch=20, cex=.5, col="grey", ylab="°C Anomaly", main="Maximum Daily Temperature Anomalies for June", sub="For Station USC00042294, 1893-2012, slope = 0.001, p-value < 0.001, r2 = 0.02", xlab="Year")
  abline(lm(TMAX.a ~ Ymd, data=subset(USC00042294.anomalies$TMAX, MONTH==month)), col="red")
} 
  
# Testing Function
station = "USC00042294.anomalies"
month = 6
element = 
BasicTrendPlot.fun(station, month, elemengt)


#-------------------------------------------------------------------------------
# Plot the Trend

plotTrend.fun <- function(station, element, month) {
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
    main1="Minumum Temperature"
  } else if(element == "PRCP"){
    list = 3
    temp = subset(station[[list]], subset=MONTH==month)
    daterange = range(temp$Ymd)
    formula = as.formula("PRCP.a ~ Ymd")
    main1="Precipitation"
    ylab="Precipitation Anamoly (mm)"
  }

station.lm <- lm(formula, data=temp)

  sub=paste0("Trend: ", round(coef(station.lm)[2]*100, 4), " C/100 Year; R-squared: ", round(summary(station.lm)$r.squared, 3), "; p-value: ", round(summary(station.lm)$coefficients[2,4], 2))

main=paste0(main1, " Anamoly (", month.name[month], ") at ", sub("\\..*", "", deparse(substitute(station))))
  
par(mfrow=c(1,1), mar=c(4,4,2,2), oma=c(0,0,2,0))
plot(formula, data=temp, pch=19, 
       ylab=ylab, xlab="Year", col="gray", cex=.5, 
       main="")
  
  mtext(main, side=3, line=2, cex=1.1)
  mtext(sub, side=3, line=1, cex=.8)
  abline(coef(station.lm), col="red")
}

# test function
# plotTrend.fun(USC00042294.anomalies, "TMAX", 6)
# plotTrend.fun(USC00042294.anomalies, "TMIN", 7)
# plotTrend.fun(USC00042294.anomalies, "PRCP", 1)


  
#-------------------------------------------------------------------------------
png1975.fun <- function(x){
GSOM_1975.png = paste0(fips$State2, "_", stid, "_GSOM_1975.png")

png(paste0(png_private, GSOM_1975.png), width = 480, height = 320, units = "px", pointsize = 12, bg = "white")
par(las=1, mfrow=c(1,1))
plot(TMAX~Date, GSOM, pch=20, cex=.5, col="grey", ylab="°F", main=paste0(fips$State2, "-", stid))
GSOM.lm = lm(TMAX~Date, GSOM)
pred_dates <-data.frame(Date = GSOM$Date); 
nrow(pred_dates);# pred_dates
#Predits the values with confidence interval 
ci <- predict(GSOM.lm, newdata = pred_dates, 
              interval = 'confidence')
lines(pred_dates$Date, as.numeric(ci[,1]), col="gray50")

# Post 1975
GSOM.lm = lm(TMAX~Date, GSOM[GSOM$Year>1975,])
pred_dates <-data.frame(Date = GSOM$Date[GSOM$Year>1975]); 
nrow(pred_dates); #pred_dates
#Predits the values with confidence interval 
ci <- predict(GSOM.lm, newdata = pred_dates, 
              interval = 'confidence')
lines(pred_dates$Date, as.numeric(ci[,1]), col="red")
lines(pred_dates$Date, as.numeric(ci[,2]), col="darkorange")
lines(pred_dates$Date, ci[,3], col="darkorange")
location_index = round(length(GSOM[GSOM$Year>1975,]$Date) * 0.99,0)
text(pred_dates$Date[location_index], ci[location_index,3], 
     paste(report_prob3(GSOM.lm))[2], pos=2, cex=1.0, col="red")
#abline(coef(lm(TMAX~Date, GSOM)), col="black")
#abline(coef(lm(TMAX~Date, GSOM[GSOM$Year>1975,])), col="red")
dev.off()

}


droughplot.fun <- function(x){
  plot(lengths~Year, Drought.run.10, pch=20, cex=.5)
  points(lengths~Year, Drought.run.20, pch=20, col="blue", cex=.5)
  points(lengths~Year, Drought.run.40, pch=20, col="red", cex=.5)
  points(lengths~Year, Drought.run.100, pch=20, col="purple", cex=.5)
  
  abline(lm(lengths~Year, Drought.run.10))
  abline(lm(lengths~Year, Drought.run.20), col="blue")
  abline(lm(lengths~Year, Drought.run.40), col="red")
  abline(lm(lengths~Year, Drought.run.100), col="purple")
  summary(lm(lengths~Year, Drought.run.100))
  
  
  plot(lengths~Year, Drought.run[Drought.run$lengths>30,], pch=20)
  plot(lengths~Year, Drought.run[Drought.run$lengths>30,], pch=20)
  
  
  Drought.run.lm <- lm(lengths~Year, Drought.run[Drought.run$lengths>10,])
  summary(Drought.run.lm)
  text(min(Drought.run$Year, na.rm=T), max(Drought.run$lengths, na.rm=T), 
       paste("Slope (x100) = ", round(coef(Drought.run.lm)[2]*100, 3)), pos=4)
  #plot(PRCP.count ~ Year, data=CHCND[CHCND$PRCP==0,])
  
}

#-------------------------------------------------------------------------------
# PRCP Distrubtion Graphics

PRCPplot.fun <- function(x){
  # PRCP Distrubtion Graphics
  CHCND$Decade <- floor_decade(CHCND$Year)
  
  PRCP.Decade <- aggregate(PRCP~Month+Decade, data=CHCND, sum)
  head(PRCP.Decade)
  
  x <- PRCP.Decade$PRCP[PRCP.Decade$Decade==1900]
  df <- approxfun(density(x))
  plot(1:12, density(x))
  xnew <- c(0.45,1.84,2.3)
  points(xnew,df(xnew),col=2)
  
}

#-------------------------------------------------------------------------------

# Record Tempertures
RecordTemp.fun <- function(x){
CHCND_Mean = mean(CHCND$TMAX, na.rm=T)
CHCND$maxTMAX <- CHCND$minTMIN <- NA

for(i in 1:nrow(CHCND)){
  if(is.na(CHCND$TMAX[i])) next
  
  CHCNDmmdd <- CHCND$mmdd[i] # Index Correct Day/Month to compare
  CHCND$maxTMAX[i] <- CHCND$TMAX[i] # Assign value to maxTMAX
  
  if(CHCND$TMAX[i] < 
     max(CHCND$TMAX[CHCND$mmdd==CHCNDmmdd], na.rm=T) ){ 
    CHCND$maxTMAX[i] <- NA} else
    {
      CHCND$maxTMAX[i] <- CHCND$TMAX[i]
    }
}


for(i in 1:nrow(CHCND)){
  if(is.na(CHCND$TMIN[i])) next
  
  CHCNDmmdd <- CHCND$mmdd[i] # Index Correct Day/Month to compare  
  CHCND$minTMIN[i] <- CHCND$TMIN[i] # Assign value to mintMIN
  
  if(CHCND$TMIN[i] > 
     min(CHCND$TMIN[CHCND$mmdd==CHCNDmmdd], na.rm=T) ){ 
    CHCND$minTMIN[i] <- NA} else
    {
      CHCND$minTMIN[i] <- CHCND$TMIN[i]
    }
}
head(CHCND)
}


#-------------------------------------------------------------------------------
# Extreme Values

extremevalues.fun <- function(x){
names(CHCND)

minTMIN.length = aggregate(minTMIN~Year, data=CHCND, length)
minTMIN.length$group <- "Record Lows"
names(minTMIN.length) <- c("Year", "Num", "Group")
minTMIN.length$Num = -minTMIN.length$Num

maxTMAX.length = aggregate(maxTMAX~Year, data=CHCND, length); 
maxTMAX.length$group <- "Record Highs"
names(maxTMAX.length) <- c("Year", "Num", "Group")

records = rbind(minTMIN.length, maxTMAX.length); # records


ggplot( ) +
  geom_point(data = CHCND, aes(y=TMIN, x=YearDay), 
             size=.05, color="gray") + 
  geom_bar(data = records, aes(x=Year, y=Num, fill=Group), 
           stat="identity", position="identity") +
  xlim(min(CHCND$Year), max(CHCND$Year)-1) +
  #ylab("Number of Extreme Temps") + # for the y axis label
  scale_fill_manual("Legend", 
                    values = c("Record Highs" = "red", "Record Lows" = "blue")) +
  geom_smooth(data = CHCND, aes(y=TMIN, x=YearDay), method = "lm", se = FALSE)

ggplot( ) +
  geom_bar(data = records, aes(x=Year, y=Num, fill=Group), 
           stat="identity", position="identity") +
  xlim(min(CHCND$Year), max(CHCND$Year)-1) +
  ylab("Number of Extreme Temps") + # for the y axis label
  scale_fill_manual("Legend", 
                    values = c("Record Highs" = "red", "Record Lows" = "blue"))

}

#-------------------------------------------------------------------------------

#Record Setttig Evaluation function


RecordSetting.fun <- function(x){
  # Record Setting Evaluation

  
    library(lubridate)
  str(CHCND)
  
  TMAX.mat.noleap <- matrix(NA, nrow=366, ncol=max(CHCND$Year) - min(CHCND$Year)+1)
  TMIN.mat <- matrix(NA, nrow=366, ncol=max(CHCND$Year) - min(CHCND$Year)+1)
  #TMAX.mat.leap <- matrix(NA, nrow=1, ncol=max(CHCND$Year) - min(CHCND$Year))
  
  # Dumb Method, fraction of year might be better...
  
  CHCND.noleap = subset(CHCND, select=c(Date, Year, yday, TMAX, TMIN, PRCP), 
                        subset=(mmdd!="02-29"))
  
  ## Add yday for leap year 
  CHCND.noleap$yday[CHCND.noleap$yday>=60 & !leap_year(CHCND.noleap$Date)]<-CHCND.noleap$yday[CHCND.noleap$yday>=60 & !leap_year(CHCND.noleap$Date)] + 1
  
  ## Create leap year dataframe
  CHCND.leap  = subset(CHCND, select=c(Date, Year, yday, TMAX, TMIN, PRCP), 
                       subset=(mmdd=="02-29"))
  names(CHCND.noleap)
  years = seq(min(CHCND$Year), max(CHCND$Year), by=1)
  year.seq = data.frame(Year = years, Col = seq_len(length(seq(min(CHCND$Year), max(CHCND$Year)))))
  
  for(i in min(CHCND.noleap$Year):max(CHCND.noleap$Year)){
    for(j in c(1:59, 61:366)){
      # i=2016; j = 50;
      TMAX.mat.noleap[j, year.seq$Col[year.seq$Year==i]] <- 
        CHCND.noleap$TMAX[CHCND.noleap$Year==i & CHCND.noleap$yday == j]
      TMIN.mat[j, year.seq$Col[year.seq$Year==i]] <- 
        CHCND.noleap$TMIN[CHCND.noleap$Year==i & CHCND.noleap$yday == j]
    }
    if(leap_year(i)){
      TMAX.mat.noleap[60, year.seq$Col[year.seq$Year==i]] <- CHCND.leap$TMAX[CHCND.leap$Year== i & CHCND.leap$yday == 60]
      TMIN.mat[60, year.seq$Col[year.seq$Year==i]] <- CHCND.leap$TMIN[CHCND.leap$Year== i & CHCND.leap$yday == 60]
      print(paste0("Added Leap Year", i))
    } else {print(paste0("Process non-leap year ", i))}
  }
  
  dim(TMAX.mat.noleap)
  
  max(CHCND$yday[CHCND$Year==max(CHCND$Year)])
  
  # subset(CHCND, select=c(Date, yday, Year, TMAX), subset=(Year >= max(CHCND$Year)-1 & yday<=max(CHCND$yday[CHCND$Year<=max(CHCND$Year)]) & yday>=135))
  
  # TMAX.mat.noleap[140:144,134:135]

    records.png = paste0(fips$State2, "_", stid, "_CHCND_Temp_Records.png")
  
  png(paste0(png_private, records.png), width = 480, height = 280, units = "px", pointsize = 12, bg = "white")
  
  results<-NULL
  decades <- years[years/10 == floor(years/10)]
  i = max(CHCND$Year)
  # START LOOP
  j = which(years %in% i)  
  if(sum(is.na(TMAX.mat.noleap[,j]))==366) next
  TMAX1 = apply(TMAX.mat.noleap[,1:j], 1, function (x) which.max(x)); 
  is.na(TMAX1) <- lengths(TMAX1) == 0
  TMAX1 <- unlist(TMAX1)
  TMAX1 <- count(TMAX1)
  #str(TMAX1)
  names(TMAX1)=c("Year", "TMAX")
  TMAX_na = data.frame(Year=1:j)
  TMAX <- merge(TMAX_na, TMAX1, all.x=TRUE, by="Year")
  
  if(sum(is.na(TMIN.mat[,j]))==366) next
  # Select Minimum and Change to Negative Value
  TMIN1 = apply(TMIN.mat[,1:j], 1, function (x) which.min(x)); 
  is.na(TMIN1) <- lengths(TMIN1) == 0
  TMIN1 <- unlist(TMIN1)
  TMIN1 <- count(TMIN1) # Max Counts Negagive
  #str(TMIN1)   
  names(TMIN1)=c("Year", "TMIN")
  TMIN_na <- data.frame(Year=1:j)
  TMIN <- merge(TMIN_na, TMIN1, all.x=TRUE, by="Year")
  
  R1 <- merge(TMAX, TMIN, by="Year")
  R1$Index = rep(j, nrow(R1))
  #results = rbind(results, R)
  R1$TMIN = -R1$TMIN
  ## Sorting out X Axis
  tic.no <- 4
  rowskip = round(nrow(R1)/tic.no, 0)
  row_numb <- seq_len(nrow(R1)) %% rowskip
  row.sel = which(row_numb %in% c(1))
  index.year <- years[row.sel]
  # switch to decades?
  
  xtics = row.sel
  xlabs = index.year
  
  yrange = range(c(R1$TMIN, R1$TMAX), na.rm=T)
  ytics = floor(seq(yrange[1], yrange[2], length.out=tic.no))
  ylabs = as.character(abs(ytics))
  
  par(las=1, xpd=TRUE)
  plot(c(1,nrow(R1)), c(yrange[1], yrange[2]), ty="n", xaxt='n', yaxt='n', xlab="Year", ylab="No. of Record Temps", main="Record Highs and Lows")
  axis(2,at=ytics, labels=ylabs)
  axis(1,at=xtics, labels=xlabs)
  barplot(height = R1$TMAX, space=0, add = TRUE, axes = FALSE, col="red")
  barplot(height = R1$TMIN, space=0, add = TRUE, axes = FALSE, col="blue")
  # END LOOP
  
  dev.off()
  
}


#--------------------------------------------------------------------------------
# Box Plot Interation Function
interation.fun = function(){
for(i in min(CHCND$Year+5):max(CHCND$Year)){
  # i=1930
  CHCNDsub = subset(CHCND, CHCND$Year<=i, 
                    select=c(Month, Month.name, TMAX, TMIN))
  
  boxplot(TMAX ~ Month.name, data=CHCNDsub, xlab="",
          main=paste("Maximum Daily Temp.", min(CHCND$Year), "-",
                     i, GSOM_Longest$name),
          sub="(NOTE: Red astrisks with signfic. changes)")
  
  symbol.y = (par()$yaxp[2])-diff(par()$yaxp[1:2])*.99
  #symbol.y = (par()$yaxp[2])
  with(sumstats[sumstats$Param=="TMAX",], text(Month, symbol.y, Symbol, col="red", cex=1))
}
}

#-------------------------------------------------------------------------------
# Four Panel Plot Function

four.panel.fun = function(x){
  
  panel4.png = paste0(fips$State2, "_", stid, "_4panel.png")



png(paste0(png_private, panel4.png), width = 480, height = 480, units = "px", pointsize = 12, bg = "white")

# START ----
ylim_new=NA
for(i in seq(min(GSOM$Year), max(GSOM$Year), by=2)) 
{
  par(las=1, mfrow=c(4,1), mar= c(2, 4, 2, 1) + 0.1)
  # TMINmonthMax
  GSOMsub <- GSOM[GSOM$Month==TMINmonthMax & GSOM$Year<=i,]
  if(nrow(GSOMsub)<10) next
  plot(TMIN~Date, GSOMsub[GSOMsub$Month==TMINmonthMax,], 
       col='gray70', pch=20, xlab="", 
       main=paste("Mean", format(GSOMsub$Date,"%B")[1], 
                  "Min. Temp", GSOM_Longest$name))
  GSOM.lm = lm(TMIN~Date, GSOMsub)
  pred_dates <-data.frame(Date = GSOMsub$Date); 
  nrow(pred_dates); pred_dates
  
  #Predits the values with confidence interval 
  ci <- predict(GSOM.lm, newdata = pred_dates, 
                interval = 'confidence')
  lines(pred_dates$Date, as.numeric(ci[,1]), col="darkred")
  lines(pred_dates$Date, as.numeric(ci[,2]), col="darkorange")
  lines(pred_dates$Date, ci[,3], col="darkorange")
  location_index = round(length(GSOMsub$Date) * 0.99,0)
  text(pred_dates$Date[location_index], ci[location_index,3], 
       paste(report_prob2(GSOM.lm)), pos=2, cex=1.5)
  
  # Box Plot of TMAX by Month
  CHCNDsub = subset(CHCND, CHCND$Year<=i, 
                    select=c(Month, Month.name, TMAX, TMIN))
  boxplot(TMAX ~ Month.name, data=CHCNDsub, main="", xlab="")
  symbol.y = (par()$yaxp[2])-diff(par()$yaxp[1:2])*.99
  #symbol.y = (par()$yaxp[2])
  with(sumstats[sumstats$Param=="TMAX",], text(Month, symbol.y, Symbol, col="red", cex=1))
  mtext(paste("Maximum Daily Temp.", min(CHCND$Year), 
              "-", i, GSOM_Longest$name), line=1)
  mtext("(NOTE: Red astrisks correspond to signficant changes)", 
        line=0, cex=.7)
  
  # TMAXmonthMax 
  GSOMsub <- GSOM[GSOM$Month==TMAXmonthMax & GSOM$Year<=i,]
  ylim = range(GSOMsub$TMAX)
  #if(!is.na(ylim_new)) ylim[2]=ylim_new
  plot(TMAX~Date, GSOMsub, col='gray70', pch=20,
       ylim=ylim, xlab="",
       main=paste("Mean", format(GSOMsub$Date,"%B")[1], 
                  "Max. Temp", GSOM_Longest$name))
  GSOM.lm = lm(TMAX~Date, GSOMsub) 
  
  ci <- predict(GSOM.lm, newdata = pred_dates, 
                interval = 'confidence')
  lines(pred_dates$Date, as.numeric(ci[,1]), col="darkred")
  lines(pred_dates$Date, as.numeric(ci[,2]), col="darkorange")
  lines(pred_dates$Date, ci[,3], col="darkorange")
  
  text(pred_dates$Date[location_index], ci[location_index,3], 
       paste(report_prob2(GSOM.lm)), pos=2, cex=1.5)
}
# Record High Temperatures
# START LOOP
j = which(years %in% i)  
if(sum(is.na(TMAX.mat.noleap[,j]))==366) next
TMAX1 = apply(TMAX.mat.noleap[,1:j], 1, function (x) which.max(x)); 
is.na(TMAX1) <- lengths(TMAX1) == 0
TMAX1 <- unlist(TMAX1)
TMAX1 <- count(TMAX1)
#str(TMAX1)
names(TMAX1)=c("Year", "TMAX")
TMAX_na = data.frame(Year=1:j)
TMAX <- merge(TMAX_na, TMAX1, all.x=TRUE, by="Year")

if(sum(is.na(TMIN.mat[,j]))==366) next
# Select Minimum and Change to Negative Value
TMIN1 = apply(TMIN.mat[,1:j], 1, function (x) which.min(x)); 
is.na(TMIN1) <- lengths(TMIN1) == 0
TMIN1 <- unlist(TMIN1)
TMIN1 <- count(TMIN1) # Max Counts Negagive
#str(TMIN1)   
names(TMIN1)=c("Year", "TMIN")
TMIN_na <- data.frame(Year=1:j)
TMIN <- merge(TMIN_na, TMIN1, all.x=TRUE, by="Year")

R1 <- merge(TMAX, TMIN, by="Year")
R1$Index = rep(j, nrow(R1))
#results = rbind(results, R)
R1$TMIN = -R1$TMIN
## Sorting out X Axis
tic.no <- 4
rowskip = round(nrow(R1)/tic.no, 0)
row_numb <- seq_len(nrow(R1)) %% rowskip
row.sel = which(row_numb %in% c(1))
index.year <- years[row.sel]
# switch to decades?

xtics = row.sel
xlabs = index.year

yrange = range(c(R1$TMIN, R1$TMAX), na.rm=T)
ytics = floor(seq(yrange[1], yrange[2], length.out=tic.no))
ylabs = as.character(abs(ytics))

par(las=1, xpd=TRUE)
plot(c(1,nrow(R1)), c(yrange[1], yrange[2]), ty="n", xaxt='n', yaxt='n', ylab="No. of Record Temps", xlab="", main="Record Highs and Lows")
axis(2,at=ytics, labels=ylabs)
axis(1,at=xtics, labels=xlabs)
barplot(height = R1$TMAX, space=0, add = TRUE, axes = FALSE, col="red")
barplot(height = R1$TMIN, space=0, add = TRUE, axes = FALSE, col="blue")
# END LOOP

# STOP ----
dev.off()
}

#-------------------------------------------------------------------------------
# KISS Function

kiss <- function(x){
  dyn.load('/opt/jags/4.3.1/lib/libjags.so.4')
  library(mcp)
  
  # Define the model
  model = list(
    response ~ 1,  # plateau (int_1)
    ~ 0 + time,    # joined slope (time_2) at cp_1
    ~ 1 + time     # disjoined slope (int_3, time_3) at cp_2
  )
  
  # Get example data and fit it
  ex = mcp_example("demo")
  fit = mcp(model, data = ex$data) 
  
  summary(fit)
  
  # Simulate
  set.seed(42)  # I always use 42; no fiddling
  df = data.frame(
    x = 1:100,
    y = c(rnorm(30, 2), rnorm(40, 0), rnorm(30, 1))
  )
  
  # Plot it
  plot(df)
  abline(v = c(30, 70), col="red")
  
  model = list(y~1, 1~1, 1~1)  # three intercept-only segments
  fit_mcp = mcp(model, data = df, par_x = "x")
  
  summary(fit_mcp)
  
  library(patchwork)
  plot(fit_mcp) + plot_pars(fit_mcp, pars = c("cp_1", "cp_2"), type = "dens_overlay")
  
  model = list(
    price ~ 1 + ar(2),
    ~ 0 + time + ar(1)
  )
  ex = mcp_example("ar")
  
  ex$data$time; 
  fit = mcp(model, ex$data)
  summary(fit)
  
  plot(fit) + plot_pars(fit, pars = c("cp_1"), type = "dens_overlay")
  
  ex$data$time;  
  fit = mcp(model, ex$data)
  summary(fit)
  
  GSOM$TMAX
  test.df = data.frame(TMAX = GSOM$TMAX , time=1:1523)
  model2 = list(
    price ~ 1 + ar(2),
    ~ 0 + time + ar(1)
  )
  fit2 = mcp(model2, test.df)
  plot(fit2) + plot_pars(fit2, pars = c("cp_1"), type = "dens_overlay")

KISS.png <- paste0(fips$State2, "_", stid, "_KISS.png")

png(paste0(png_private, KISS.png), width = 480, height = 480, units = "px", pointsize = 12, bg = "white")

ylim_new=NA
for(i in seq(min(GSOM$Year), max(GSOM$Year), by=2)) 
   {
par(las=1, mfrow=c(3,1), mar= c(2, 4, 2, 1) + 0.1)
   
# Box Plot of TMAX by Month
   
CHCNDsub = subset(CHCND, CHCND$Year<=i, 
      select=c(Month, Month.name, TMAX, TMIN))
boxplot(TMAX ~ Month.name, data=CHCNDsub, main="")
symbol.y = (par()$yaxp[2])-diff(par()$yaxp[1:2])*.99
#symbol.y = (par()$yaxp[2])
text(sumstats$Month, symbol.y, sumstats$TMAX_Symbol, 
     col="red", cex=2)
mtext(paste("Maximum Daily Temperatures", min(CHCND$Year), 
      "-", i, GSOM_Longest$name), line=1)
mtext("(NOTE: Red astrisks correspond to signficant changes)", 
      line=0, cex=.7)


GSOMsub <- GSOM[GSOM$Month==TMINmonthMax & GSOM$Year<=i,]
   if(nrow(GSOMsub)<10) next

# TMIN
plot(TMIN~Date, GSOMsub[GSOMsub$Month==TMINmonthMax,], 
   col='gray70', pch=20, xlab="", 
   main=paste("Mean", format(GSOMsub$Date,"%B")[1], 
              "Min. Temp", GSOM_Longest$name))
GSOM.lm = lm(TMIN~Date, GSOMsub)
pred_dates <-data.frame(Date = GSOMsub$Date); 
nrow(pred_dates); pred_dates
#Predits the values with confidence interval 
ci <- predict(GSOM.lm, newdata = pred_dates, 
              interval = 'confidence')
lines(pred_dates$Date, as.numeric(ci[,1]), col="darkred")
lines(pred_dates$Date, as.numeric(ci[,2]), col="darkorange")
lines(pred_dates$Date, ci[,3], col="darkorange")
location_index = round(length(GSOMsub$Date) * 0.99,0)
text(pred_dates$Date[location_index], ci[location_index,3], 
     paste(report_prob2(GSOM.lm)), pos=2, cex=1.6)


# TMAX --------------------------------
ylim = range(GSOMsub$TMAX)
GSOMsub <- GSOM[GSOM$Month==TMAXmonthMax & GSOM$Year<=i,]
plot(TMAX~Date, GSOMsub, col='gray70', pch=20, xlab="",
    # ylim=ylim,
     main=paste("Mean", format(GSOMsub$Date,"%B")[1], 
                "Max. Temp", GSOM_Longest$name))
GSOM.lm = lm(TMAX~Date, GSOMsub) 

ci <- predict(GSOM.lm, newdata = pred_dates, 
              interval = 'confidence')
lines(pred_dates$Date, as.numeric(ci[,1]), col="darkred")
lines(pred_dates$Date, as.numeric(ci[,2]), col="darkorange")
lines(pred_dates$Date, ci[,3], col="darkorange")

text(pred_dates$Date[location_index], ci[location_index,3], 
     paste(report_prob2(GSOM.lm)), pos=2, cex=1.6)
}

# STOP
dev.off()

#-------------------------------------------------------------------------------
# Temp and Probablility Functions
tempprecip <- function(x){
ibrary(wesanderson)

h.ramp <- rev(heat.colors(length(unique(GSOM2$Score))+1))[-1]
h.ramp <- wes_palette("Zissou1", length(unique(GSOM2$Score)), 
      type = "continuous")[1:length(unique(GSOM2$Score))]
#TMAX.anomaly.Score = aggregate(TMAX.anom ~ Score, GSOM2, mean)
#TMAX.sd.anomaly.Score = aggregate(TMAX.anom ~ Score, GSOM2, sd)


# I hate list!
TMAX.anomaly.list = aggregate(TMAX.anom ~ Score, GSOM2, 
   FUN = function(x) c(mean = mean(x), sd = sd(x)))
TMIN.anomaly.list = aggregate(TMIN.anom ~ Score, GSOM2, 
   FUN = function(x) c(mean = mean(x), sd = sd(x)))
PPT.anomaly.list = aggregate(PPT.anom ~ Score, GSOM2, 
   FUN = function(x) c(mean = mean(x), sd = sd(x)))

GSOM_dnorm.png <- paste0(fips$State2, "_", stid, "_GSOM_dnorm.png")

png(paste0(png_private, GSOM_dnorm.png), 
    width = 480, height = 300, units = "px", pointsize = 12, bg = "white")
# TMIN
par(mfrow=c(1, 3), las=1, mar = c(5, 4, 4, 0.2) + 0.1, xpd=FALSE)
Anom.x = seq(min(GSOM2$TMIN.anom), max(GSOM2$TMIN.anom),by=.1)
Anom.y = max(dnorm(Anom.x,
   mean=TMIN.anomaly.list$TMIN.anom[1,1],
   sd=TMIN.anomaly.list$TMIN.anom[1,2]))*1.2

plot(Anom.x, dnorm(Anom.x,
   mean=TMIN.anomaly.list$TMIN.anom[1, 1],
   sd=TMIN.anomaly.list$TMIN.anom[1, 2]), 
   ty="l", col=h.ramp[1], ylim=c(0, Anom.y),
   ylab="Density", xlab="TMIN Anomaly (°F)", main="")

abline(v=TMIN.anomaly.list$TMIN.anom[1,1], col=h.ramp[1], lwd=2)
for(i in 2:nrow(TMIN.anomaly.list)){
lines(Anom.x, dnorm(Anom.x,
   mean=TMIN.anomaly.list$TMIN.anom[i, 1],
   sd=TMIN.anomaly.list$TMIN.anom[i, 2]), col=h.ramp[i])
}
abline(v=TMIN.anomaly.list$TMIN.anom[i,1], col=h.ramp[i], lwd=2)
Delta = TMIN.anomaly.list$TMIN.anom[i,1] - TMIN.anomaly.list$TMIN.anom[1,1]

text(TMIN.anomaly.list$TMIN.anom[i,1], Anom.y*.95, 
   paste0("Change ", round(Delta, 1), "°F"), pos=3, cex=.9)



# TMAX
Anom.x = seq(min(GSOM2$TMAX.anom), max(GSOM2$TMAX.anom),by=.1)
Anom.y = max(dnorm(Anom.x,
   mean=TMAX.anomaly.list$TMAX.anom[1,1],
   sd=TMAX.anomaly.list$TMAX.anom[1,2]))*1.2

plot(Anom.x, dnorm(Anom.x,
   mean=TMAX.anomaly.list$TMAX.anom[1, 1],
   sd=TMAX.anomaly.list$TMAX.anom[1, 2]), 
   ty="l", col=h.ramp[1], ylim=c(0, Anom.y),
   ylab="Density", xlab="TMAX Anomaly (°F)")

abline(v=TMAX.anomaly.list$TMAX.anom[1,1], col=h.ramp[1], lwd=2)
for(i in 2:nrow(TMAX.anomaly.list)){
lines(Anom.x, dnorm(Anom.x,
   mean=TMAX.anomaly.list$TMAX.anom[i, 1],
   sd=TMAX.anomaly.list$TMAX.anom[i, 2]), col=h.ramp[i])
}
abline(v=TMAX.anomaly.list$TMAX.anom[i,1], col=h.ramp[i], lwd=2)
Delta = TMAX.anomaly.list$TMAX.anom[i,1] - TMAX.anomaly.list$TMAX.anom[1,1]

text(TMAX.anomaly.list$TMAX.anom[i,1], Anom.y*.96, 
   paste0("Change ", round(Delta, 1), "°F"), pos=3, cex=0.9)

mtext(paste0(fips$State, " (", GSOM_Longest$name, ")"), side=3, line=2)

# PPT
Anom.x = seq(min(GSOM2$PPT.anom), max(GSOM2$PPT.anom),by=.1)
Anom.y = max(dnorm(Anom.x,
   mean=PPT.anomaly.list$PPT.anom[1,1],
   sd=PPT.anomaly.list$PPT.anom[1,2]))*1.2

plot(Anom.x, dnorm(Anom.x,
   mean=PPT.anomaly.list$PPT.anom[1, 1],
   sd=PPT.anomaly.list$PPT.anom[1, 2]), 
   ty="l", col=h.ramp[1], ylim=c(0, Anom.y),
   ylab="Density", xlab="PPT Anomaly")

abline(v=PPT.anomaly.list$PPT.anom[1,1], col=h.ramp[1], lwd=2)
for(i in 2:nrow(PPT.anomaly.list)){
lines(Anom.x, dnorm(Anom.x,
   mean=PPT.anomaly.list$PPT.anom[i, 1],
   sd=PPT.anomaly.list$PPT.anom[i, 2]), col=h.ramp[i])
}
abline(v=PPT.anomaly.list$PPT.anom[i,1], col=h.ramp[i], lwd=2)
Delta = PPT.anomaly.list$PPT.anom[i,1] - PPT.anomaly.list$PPT.anom[1,1]

text(PPT.anomaly.list$PPT.anom[i,1], Anom.y*.96,
   paste0("Change ", round(Delta, 1), " inches"), pos=3, cex=0.9)

dev.off()

}
}




