install.packages("weatherData")
library(weatherData)

station_id <- "USC00410999"
start_date <- "1900-01-01"
end_date <- Sys.Date("2024-31-01")  # Use today's date for the end date

weather_data <- getWeatherForDate(station_id, start_date, end_date)

install.packages("rnoaa")
library(rnoaa)

station_id <- "USC00410999"
start_date <- "1900-01-01"
end_date <- "2024-01-01"  # Use today's date for the end date

weather_data <- ncdc(datasetid = "GHCND", stationid = station_id, startdate = start_date, enddate = end_date, limit = 1000)
