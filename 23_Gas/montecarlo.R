############################################################
# US GASOLINE PRICE MODELING WITH MONTE CARLO SIMULATION
# Conventional predictors + multiple models
# Author: ---
############################################################


############################################################
# 1. LOAD LIBRARIES
############################################################

library(tidyverse)
library(lubridate)
library(glmnet)
library(randomForest)
library(forecast)
library(MASS)

set.seed(123)


############################################################
# 2. CREATE (PLACEHOLDER) DATA STRUCTURE
# Replace this section with EIA / FRED / BLS data pulls
############################################################

n <- 250  # weekly observations (~5 years)

data <- tibble(
  date = seq.Date(from = as.Date("2020-01-03"), by = "week", length.out = n),
  gas_price = 2.5 + cumsum(rnorm(n, 0, 0.03)),     # $/gallon
  crude_oil = 60 + cumsum(rnorm(n, 0, 1)),         # $/barrel
  refinery_util = 85 + rnorm(n, 0, 2),             # %
  gasoline_inventory = 230 + rnorm(n, 0, 5),       # million barrels
  cpi = 260 + cumsum(rnorm(n, 0.05, 0.02)),        # index
  unemployment = 5 + rnorm(n, 0, 0.4),             # %
  usd_index = 100 + rnorm(n, 0, 1)                 # USD strength
)


############################################################
# 3. FEATURE ENGINEERING
############################################################

data <- data %>%
  mutate(
    week = week(date),
    log_crude = log(crude_oil),
    summer = if_else(week %in% 18:40, 1, 0),    # driving season
    lag_gas_price = lag(gas_price, 1)
  ) %>%
  drop_na()


############################################################
# 4. TRAIN / TEST SPLIT
############################################################

split_point <- floor(0.8 * nrow(data))

train <- data[1:split_point, ]
test  <- data[(split_point + 1):nrow(data), ]


############################################################
# 5. MODEL 1: LINEAR REGRESSION (ECONOMIC BASELINE)
############################################################

lm_model <- lm(
  gas_price ~ log_crude + refinery_util + gasoline_inventory +
    cpi + unemployment + usd_index + summer + lag_gas_price,
  data = train
)


############################################################
# 6. MODEL 2: LASSO REGRESSION (REGULARIZED)
############################################################

x_train <- model.matrix(gas_price ~ . -date -week, train)[, -1]
y_train <- train$gas_price

x_test <- model.matrix(gas_price ~ . -date -week, test)[, -1]

cv_lasso <- cv.glmnet(x_train, y_train, alpha = 1)
lasso_model <- glmnet(
  x_train,
  y_train,
  alpha = 1,
  lambda = cv_lasso$lambda.min
)


############################################################
# 7. MODEL 3: RANDOM FOREST (NONLINEAR)
############################################################

rf_model <- randomForest(
  gas_price ~ log_crude + refinery_util + gasoline_inventory +
    cpi + unemployment + usd_index + summer + lag_gas_price,
  data = train,
  ntree = 500,
  importance = TRUE
)


############################################################
# 8. MODEL EVALUATION (RMSE)
############################################################

rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2))
}

results <- tibble(
  Model = c("Linear", "LASSO", "Random Forest"),
  RMSE = c(
    rmse(test$gas_price, predict(lm_model, test)),
    rmse(test$gas_price, predict(lasso_model, x_test)),
    rmse(test$gas_price, predict(rf_model, test))
  )
)

print(results)


############################################################
# 9. MONTE CARLO SETUP
# Simulate uncertainty in economic/energy predictors
############################################################

predictors <- train %>%
  dplyr::select(
    log_crude,
    refinery_util,
    gasoline_inventory,
    cpi,
    unemployment,
    usd_index
  )


mu <- colMeans(predictors)
Sigma <- cov(predictors)


############################################################
# 10. MONTE CARLO SIMULATION
############################################################

n_sim <- 10000

sim_predictors <- mvrnorm(
  n = n_sim,
  mu = mu,
  Sigma = Sigma
) %>%
  as.data.frame()

sim_predictors <- sim_predictors %>%
  mutate(
    summer = 1,
    lag_gas_price = tail(train$gas_price, 1)
  )


############################################################
# 11. SIMULATED GASOLINE PRICES
############################################################

sim_prices <- predict(
  lm_model,
  newdata = sim_predictors
)


############################################################
# 12. MONTE CARLO RESULTS
############################################################

print(summary(sim_prices))

print(
  quantile(sim_prices, probs = c(0.05, 0.50, 0.95))
)

hist(
  sim_prices,
  breaks = 50,
  col = "lightblue",
  main = "Monte Carlo Distribution of US Gasoline Prices",
  xlab = "Price ($/gallon)"
)


############################################################
# END OF SCRIPT
############################################################