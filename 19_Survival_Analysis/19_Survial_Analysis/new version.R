# Load libraries
library(survival)
library(survminer)
library(ggplot2)
set.seed(123)

# Parameters
n_reps <- 10
treatments <- c("Control", "TreatmentA", "TreatmentB")
hours <- 0:72
threshold <- 0.8

# Function to simulate growth
simulate_growth <- function(treatment, rep) {
  rate <- switch(treatment,
                 "Control" = 0.02,
                 "TreatmentA" = 0.03,
                 "TreatmentB" = 0.04)
  OD <- 1 / (1 + exp(-(rate * (hours - 36)))) + rnorm(length(hours), 0, 0.05)
  data.frame(Treatment = treatment, Rep = rep, Hour = hours, OD = pmax(OD, 0))
}

# Generate dataset
growth_data <- do.call(rbind,
                       lapply(treatments, function(t) {
                         do.call(rbind, lapply(1:n_reps, function(r) simulate_growth(t, r)))
                       }))

# Plot raw growth curves
ggplot(growth_data, aes(x = Hour, y = OD, color = Treatment, group = interaction(Treatment, Rep))) +
  geom_line(alpha = 0.6) +
  geom_hline(yintercept = threshold, linetype = "dashed", color = "black") +
  labs(title = "Simulated Algae Growth Curves",
       y = "Optical Density (OD)", x = "Time (hours)") +
  theme_minimal()

# Convert growth data into survival format
time_to_event <- aggregate(OD ~ Treatment + Rep, data = growth_data, function(x) {
  idx <- which(x >= threshold)
  if (length(idx) == 0) return(NA) else return(min(idx) - 1)
})
time_to_event$event <- !is.na(time_to_event$OD)
time_to_event$time <- ifelse(time_to_event$event, time_to_event$OD, 72)

# Survival object
surv_obj <- Surv(time_to_event$time, time_to_event$event)

# Kaplan-Meier fit
fit <- survfit(surv_obj ~ Treatment, data = time_to_event)

# Plot survival curves
ggsurvplot(fit, data = time_to_event,
           pval = TRUE, conf.int = TRUE,
           risk.table = TRUE,
           xlab = "Time (hours)",
           ylab = "Probability algae NOT reaching OD threshold",
           legend.title = "Treatment")

# Log-rank test
print(survdiff(surv_obj ~ Treatment, data = time_to_event))

# Cox proportional hazards model
cox_fit <- coxph(surv_obj ~ Treatment, data = time_to_event)
print(summary(cox_fit))
