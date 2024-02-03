# Guide1.R

# function to read(inventory.active.oldest) and subset(my.state)
readInventory.fun<-function(filename, my.state){
  inventory.active.oldest <- read.csv(filename)
  my.inventory = subset(inventory.active.oldest, STATE == my.state)
  return(my.inventory)
}

# Download Station Data and Read Into R
downloadStations.fun <- function(datafolder, my.inventory=my.inventory){





