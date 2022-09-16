#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(xtable)

## Get NOAA CO2 records via ftp
address <- "ftp://aftp.cmdl.noaa.gov/products/trends/co2/co2_mm_mlo.txt"
download.file(address, "maunaloa", quiet = F, mode = "w", cacheOK = T)

maunaloa <- read.table("maunaloa", skip=70)
names(maunaloa) <- c("year", "month", "decimal.date", "average", "interpolated", "trend", "days")
maunaloa$average[maunaloa$average==-99.99] <- NA
maunaloa <- data.frame(year=maunaloa$year, month=maunaloa$month, decimal.date=maunaloa$decimal.date, average=maunaloa$average)
head(maunaloa)

yesno = c("on", "off")

# Define UI for application that draws a histogram
ui <- fluidPage(
    # Application title
    titlePanel("Mauna Loa CO2 Records"),
    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
              sliderInput("YearMax",
                          "End of Record:",
                          min = 1959,
                          max = 2022,
                          value = 1959),
              checkboxInput("CI", "Show Confidence Intervals", value = FALSE),
              checkboxInput("lm", "Show Linear Model Statistics", value = FALSE)
        ),
       # Show a plot of the generated distribution
        mainPanel(
           plotOutput("CO2Plot"),
           tableOutput("lmTable")
           )
          
        )
    )

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  # subset datafram based on input$YearMax from ui.R

    maunaloa <- reactive(
      maunaloa <- subset(maunaloa, subset=(year <= input$YearMax))
    )

    maunaloa.lm <- reactive(  
      lm(average~year, data=maunaloa)
    )
    
    year.seq = reactive(
      seq(min(maunaloa$year), input$YearMax+1)
      )
    
    newdata.df <- reactive(data.frame(year=year.seq)
      )
      
    predict.df <- reactive(predict(maunaloa.lm, newdata.df, 
                          interval="confidence", se.fit=TRUE)
      )
    
  # draw the histogram with the specified number of bins
    
    output$CO2Plot <- renderPlot({

      par(las=1)
      if(input$YearMax < 1970){
        plot(maunaloa$decimal.date(), maunaloa$average(), type="p", ylab="ppm", xlab="Year", 
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
}

# Run the application 
shinyApp(ui = ui, server = server)
