stickytraps.csv <- "/home/mwl04747/RTricks/12_Sticky_Traps/insect_sticky_trap_counts_15_traps.csv"

sticktraps.df <- read.csv(stickytraps.csv, header = TRUE, sep = ",", stringsAsFactors = FALSE)
head(sticktraps.df)


names(sticktraps.df) <- c("Trap", "Distance", "Species", "Count")

# How many traps are there?
length(unique(sticktraps.df$Trap))

# boxplot by distance with base R
boxplot(Count ~ Trap, data = sticktraps.df,
        main = "Sticky Trap Counts",
        xlab = "Trap",
        ylab = "Count")

# boxplot by distance and species with R base
boxplot(Count ~ Trap + Species, data = sticktraps.df,
        main = "Sticky Trap Counts",
        xlab = "Trap",
        ylab = "Count")

# boxplot by distance and species with R base
boxplot(Count ~ Distance, data = sticktraps.df,
        main = "Sticky Trap Counts",
        xlab = "Trap",
        ylab = "Count",
        las = 2,
        cex.axis = 0.7,
        cex.lab = 0.8,
        cex.main = 1.2)

unique(sticktraps.df$Species)

# plot counts by distance for each species with base R
plot(Count ~ Distance, data = subset(sticktraps.df, subset=Species == "Aedes aegypti"),
     main = "Sticky Trap Counts",
     col = c("red"),
     pch = 20)
points(Count ~ Distance, data = subset(sticktraps.df, subset=Species == "Culex pipiens"),
       col = c("blue"),
       pch = 20)

# OR make a loop

species = unique(sticktraps.df$Species)

# test loop
for (i in 1:length(species)) {
  print(species[i])
}

# plot counts by distance but don't put points on the plot but scale xlim and ylim
plot(Count ~ Distance, data = sticktraps.df, 
     xlim = c(0, 40),
     ylim = c(0, 45),
     type = "n",
     main = "Sticky Trap Counts",
     xlab = "Distance",
     ylab = "Count",
     cex.main = 1.2)

for (i in 1:length(species)) {
  points(Count ~ Distance, data = subset(sticktraps.df, subset=Species == species[i]),
         col = i,
         pch = 20)
}

stickytraps.mean = aggregate(Count ~ Distance + Species, data = sticktraps.df, FUN = mean)

# plot counts by distance but don't put points on the plot but scale xlim and ylim
plot(Count ~ Distance, data = stickytraps.mean, 
     xlim = c(0, 30),
     ylim = c(0, 45),
     type = "n",
     main = "Sticky Trap Counts",
     xlab = "Distance",
     ylab = "Count",
     cex.main = 1.2)

for (i in 1:length(species)) {
  points(Count ~ Distance, data = subset(stickytraps.mean, subset=Species == species[i]),
         col = i,
         pch = 20)
  lines(Count ~ Distance, data = subset(stickytraps.mean, subset=Species == species[i]),
         col = i)
}

# plot counts by distance for each species with ggplot2, with a linear model for each species
library(ggplot2)

# plot counts by distance for each species with ggplot2, with a linear model for each species
# add legend
ggplot(sticktraps.df, aes(x = Distance, y = Count, color = factor(Species))) +
  geom_point() + 
  geom_smooth(method = "lm", se = FALSE) +
#  facet_wrap(~ Species) +
  labs(title = "Sticky Trap Counts",
       x = "Distance",
       y = "Count") +
  theme(legend.position = "topright",,
        legend.text = element_text(size = 8))
# add legend


  



