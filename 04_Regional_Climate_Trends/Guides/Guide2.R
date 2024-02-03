# Guide2.R

cleandataframe.fun <- function(x=station1){
  if(x$VALUE==-9999) {x$VALUE <- NA}
  x$Ymd = as.Date(as.character(x$DATE), format = "%Y%m%d")
  x$MONTH = as.numeric(format(x$Ymd, "%m"))
  x$YEAR = as.numeric(format(x$Ymd, "%Y"))
}


# Download Station Data and Read Into R
#downloadStations.fun <- function(datafolder, my.inventory=my.inventory){





