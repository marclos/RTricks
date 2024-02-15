# Guide1functions.R
# Updated: 2020-02-09

#-------------------------------------------------------------------------------
# function to read(inventory.active.oldest) and subset criteria (my.state)
readInventory.fun<-function(filename, my.state){
  inventory.active.oldest <- read.csv(filename)
  my.inventory = subset(inventory.active.oldest, STATE == my.state)
  return(my.inventory)
}

#-------------------------------------------------------------------------------
# Download All Weather Station Data and Read Into R
# datafolder = "/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/SP24/"
downloadStationsOLD.fun <- function(datafolder, my.inventory=my.inventory){
  # Loop through all stations and download data
  for(i in 1:nrow(my.inventory)){
    url = paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/", 
      my.inventory$ID[i], ".csv.gz")
  
  download.file(url, paste0(datafolder, my.inventory$ID[i], ".csv.gz"), 
    quiet = FALSE, mode = "w", cacheOK = TRUE)
  
  print(paste("Index (Loop) ", i, " Completed.")) # Print Index Number 
  print("Think about something you are grateful for today!")  
  
} # LOOP END
  # Recursive function to read all files into R
    # Seems to be unreliable at this stage
    # Perhaps a path problem with misnamed files
    # e.g director/filename is is concantenated with the wrong name.
    # then the remaining function seems to fail. 
  StationList.df <- lapply( # Read All Files into R
      list.files(datafolder, full.names=TRUE, pattern = "\\.gz$"), 
        read.csv, header=FALSE)
  # Fix Variable Names based on NOAA Documentation
  colnames <- c("ID", "DATE", "ELEMENT", "VALUE", 
                "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  StationList.df <- lapply(StationList.df, setNames, colnames)
  # Loop to write all files to .csv
  for (i in seq_along(StationList.df)) {
    filename = paste0(datafolder, my.inventory$ID[i], ".csv")
    write.csv(StationList.df[[i]], filename, row.names = FALSE)
  }
  
  write.csv(my.inventory, paste0(datafolder, "my.inventory.csv"), row.names = FALSE)
}

#-------------------------------------------------------------------------------
# Download All Weather Station Data and Read Into R -- Correcting Bug!
# datafolder = "/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/test/"
downloadStations.fun <- function(datafolder, my.inventory=my.inventory){
  colnames <- c("ID", "DATE", "ELEMENT", "VALUE", 
                "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  # Loop through all stations and download, read/write csv data
  for(i in 1:nrow(my.inventory)){
    url = paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/", 
                 my.inventory$ID[i], ".csv.gz")
    
    download.file(url, paste0(datafolder, my.inventory$ID[i], ".csv.gz"), 
                  quiet = FALSE, mode = "w", cacheOK = TRUE)
    station.temp <- read.csv(paste0(datafolder, my.inventory$ID[i], ".csv.gz"), header=FALSE)
    names(station.temp) <- colnames
    filename = paste0(datafolder, my.inventory$ID[i], ".csv")
    write.csv(station.temp, filename, row.names = FALSE)
    print(paste("Index (Loop) ", i, " Completed.")) # Print Index Number 
    print("NOAA site can stall -- if the loop errors out, try again.")  
  } # LOOP END
  print("Think about something you are grateful for today!") 
  #write.csv(my.inventory, paste0(datafolder, "my.inventory.csv"), row.names = FALSE)
}

# Test Function
# downloadStations.fun("/home/mwl04747/RTricks/04_Regional_Climate_Trends/Data/test/", my.inventory)




