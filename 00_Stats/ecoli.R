# 
library(gargle)

token <- token_fetch()
token

library(googlesheets4)


import <- read_sheet("https://docs.google.com/spreadsheets/d/1Bz9crqtYh255V_OMjYaLLjtqAWEwSdQSlIM15bgG2g8/edit#gid=0")
import

import %>% aov(TC_Value ~ `Site ID`, data = .)
str(import)
College_wq = as.data.frame(import)

str(College_wq)
College_wq$TC_Value[[]]


import <- read.csv(file.choose())

names(import)

summary(import %>% aov(TC_Value ~ Site_ID, data = .))

boxplot(TC_Value ~ Site_ID, data = import, xlab = "Site ID", ylab = "Total Coliforms", main = "Total Coliforms by Site ID")

#Subset data to remove missing replications

unique(import$Site_ID)

count = aggregate(import$TC_Value, by = list(import$Site_ID), FUN = length)

censured <- subset(import, subset = Replicated > 2)

summary(censured %>% aov(TC_Value ~ Site_ID, data = .))

boxplot(TC_Value ~ Site_ID, data = censured, xlab = "Site ID", ylab = "Total Coliforms", main = "Total Coliforms by Site ID")

