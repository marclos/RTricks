library(xtable)

address <- "ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt"
download.file(address, "maunaloa", quiet = F, mode = "w", cacheOK = T)

maunaloa <- read.table("maunaloa", skip=70)

names(maunaloa) <- c("year", "month", "decimal.date", "average", "interpolated", "trend", "days")

maunaloa$average[maunaloa$average==-99.99] <- NA

maunaloa <- data.frame(year=maunaloa$year, month=maunaloa$month, decimal.date=maunaloa$decimal.date, average=maunaloa$average)
head(maunaloa)
input <- as.data.frame(NA)
input$YearMax = 1959

  
maunaloa <- subset(maunaloa, subset=(year <= input$YearMax))
  names(maunaloa)
  #   maunaloa.lm <- reactive(lm(average~year, data=maunaloa))
  #   
  #   year.seq = reactive(seq(min(maunaloa$year), input$YearMax+1))
  
  #   newdata.df <- reactive(data.frame(year=year.seq))
  
  #   predict.df <- reactive(predict(maunaloa.lm, newdata.df, interval="confidence", se.fit=TRUE)
)

# draw the histogram with the specified number of bins

output$CO2Plot <- renderPlot({
  
  par(las=1)
    plot(average ~ decimal.date, data=maunaloa, type="p", ylab="ppm", xlab="Year", 
         main="Carbon Dioxide Concentrations Changes, \n Mauna Loa, HI")
    
    
    lines(year.seq(), predict.df$fit[,1](), col="red", lwd=2.0)
  } else {
    plot(maunaloa$decimal.date(), maunaloa$average(), type="l", ylab="ppm", xlab="Year", 
         main="Carbon Dioxide Concentrations Changes, \n Mauna Loa, HI")
    lines(year.seq(), predict.df$fit[,1](), col="red", lwd=2.4)
  }
  if(input$CI=="X"){
    lines(year.seq, predict.df$fit[,2], col="orange", lwd=2.0)
    lines(year.seq, predict.df$fit[,3], col="orange", lwd=2.0)
  }
})

output$lmTable <- renderTable({
  #if(is.null(input$file1$datapath)){return()}
  maunaloa <- subset(maunaloa, subset=(year <= input$YearMax))
  maunaloa.lm = lm(average~year, data=maunaloa)
  xtable(maunaloa.lm)
}) 