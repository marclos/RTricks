# Carbon Dioxide Record and Regression
# 11/28/2022 Added Interface and variable
# 11/20/2022 get reactive to work!

library(xtable)
library(shiny)

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Old Faithful Geyser Data"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            sliderInput("bins",
                        "Number of bins:",
                        min = 1,
                        max = 50,
                        value = 30)
        ),

        # Show a plot of the generated distribution
        mainPanel(
           plotOutput("distPlot")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

#input = data.frame(NA)
#input$bins = 30
  new <- reactive({
    subset(faithful, subset=(waiting < input$bins*3), select="waiting")
  })
  #x    <- faithful
  bins <- reactive({seq(min(new()$waiting), max(new()$waiting), length.out = input$bins + 1)
    }) 
  
    output$distPlot <- renderPlot({
        # generate bins based on input$bins from ui.R



        # draw the histogram with the specified number of bins
        hist(new()$waiting, breaks = bins(), col = 'darkgray', border = 'white',
             xlab = 'Waiting time to next eruption (in mins)',
             main = 'Histogram of waiting times')
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
