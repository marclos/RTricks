# Guide1.R

# function to read(inventory.active.oldest) and subset criteria (my.state)
readInventory.fun<-function(filename, my.state){
  inventory.active.oldest <- read.csv(filename)
  my.inventory = subset(inventory.active.oldest, STATE == my.state)
  return(my.inventory)
}

# Download All Weather Station Data and Read Into R
downloadStations.fun <- function(datafolder, my.inventory=my.inventory){
  for(i in 1:nrow(my.inventory)){
    url = paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/", 
      my.inventory$ID[i], ".csv.gz")
  
  download.file(url, paste0(datafolder, my.inventory$ID[i], ".csv.gz"), 
    quiet = FALSE, mode = "w", cacheOK = TRUE)
  
#  assign(paste0("station", i), 
#    read.csv(gzfile(paste0(datafolder,my.inventory$ID[i], ".csv.gz")), 
#      header=FALSE))
  
  print(paste("Index (Loop) ", i, " Completed.")) # Print Index Number 
  print("Think about something you are grateful for today!")  
  
} # LOOP END

  StationList.df <- lapply( # Read All Files into R
      list.files(datafolder, full.names=TRUE, pattern = "\\.gz$"), 
        read.csv, header=FALSE)
  # Fix Variable Names based on NOAA Documentation
  colnames <- c("ID", "DATE", "ELEMENT", "VALUE", 
                "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  lapply(StationList.df, setNames, colnames)
  
  for (i in seq_along(StationList.df)) {
    filename = paste0(datafolder, my.inventory$ID[i], ".csv")
    write.csv(StationList.df[[i]], filename, row.names = FALSE)
  }
  
  write.csv(my.inventory, paste0(datafolder, "my.inventory.csv"), row.names = FALSE)
}









