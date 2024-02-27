Diesel PM Visualization
Using: CalEnviroScreen

library(sf)
library(tidyverse)
library(leaflet)

URL.path <- 'https://raw.githubusercontent.com/RadicalResearchLLC/EDVcourse/main/CalEJ4/CalEJ.geoJSON'
SoCalEJ <- st_read(URL.path) %>% 
  st_transform("+proj=longlat +ellps=WGS84 +datum=WGS84")

palDPM <- colorNumeric(palette = 'YlOrBr', domain = SoCalEJ$DieselPM_P, n = 5)

leaflet(data = SoCalEJ) %>% 
  addTiles() %>% 
  setView(lat = 34, lng = -117.60, zoom = 9) %>% 
  addPolygons(stroke = FALSE,
              fillColor = ~palDPM(DieselPM_P),
              fillOpacity = 0.8) %>% 
  addLegend(pal = palDPM, 
            title = 'Diesel Particulate Matter (%)', 
            values = ~DieselPM_P)
