# Guide1.R

# function to read(inventory.active.oldest) and subset(my.state)
readInventory.fun<-function(filename, my.state){
  inventory.active.oldest <- read.csv(filename)
  my.inventory = subset(inventory.active.oldest, STATE == my.state)
  return(my.inventory)
}

# Download Station Data and Read Into R
downloadStations.fun <- function(datafolder, my.inventory=my.inventory){
  for(i in 1:nrow(my.inventory)){
    url = paste0("https://www.ncei.noaa.gov/pub/data/ghcn/daily/by_station/", 
      my.inventory$ID[i], ".csv.gz")
  

  download.file(url, paste0(datafolder, my.inventory$ID[i], ".csv.gz"), 
    quiet = FALSE, mode = "w", cacheOK = TRUE)
  
  assign(paste0("station", i), 
    read.csv(gzfile(paste0(datafolder,my.inventory$ID[i], ".csv.gz")), 
      header=FALSE))
  
# can't get the header named in loop! Grrr...
#names(paste0("station",i)) <- c("ID", "DATE", "ELEMENT", 
# "VALUE", "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
  
  print(paste("Index (Loop) ", i, " Completed.")) # Print Index Number 
  print("Think about something you are grateful for today!")  
  
} # LOOP END

# Fix Variable Names based on NOAA Documentation
names(station1) <- c("ID", "DATE", "ELEMENT", "VALUE", 
                     "M-FLAG", "Q-FLAG", "S-FLAG", "OBS-TIME")
names(station3) <- names(station2) <- names(station1)
names(station5) <- names(station4) <- names(station1)
}




