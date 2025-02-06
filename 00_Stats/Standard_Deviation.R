R1 = c(4.5, 2, 10, 7, 10, 10, 6.5, 4, 4, 9, 13, 5, 4.5, 6, 8, 7.5, 4, NA)
R2 = c(10, 6, 8, 8, NA,  8, 8, 4.5, 8, 3, NA, 10, 10, 9.5, 11, NA, 6, 9)

length(R1)

mean(R1)

R1.mean = mean(R1, na.rm = TRUE); R1.mean

R1.nonmissing = R1[!is.na(R1)]; R1.nonmissing

N = length(R1.nonmissing); N

R1.residual = R1.mean-R1.nonmissing; R1.residual

plot(R1.residual)

sum(R1.residual, na.rm=TRUE)

SS = sum(R1.residual^2, na.rm=TRUE)

sqrt(SS/N)
  
sd(R1.nonmissing)

par(las=1)
boxplot(R1, R2)

round(mean(R1, na.rm = TRUE), 1); round(mean(R2, na.rm = TRUE), 1)

t.test(R1, R2)
