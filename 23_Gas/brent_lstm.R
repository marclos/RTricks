
# ============================================================
# Deep Learning (LSTM) Model to Predict Brent Oil Prices in R
# ONE SCRIPT — COPY/SAVE AS: brent_lstm.R
# ============================================================

# -----------------------------
# 1. Load libraries
# -----------------------------
suppressPackageStartupMessages({
  library(tidyverse)
  library(quantmod)
  library(scales)
  library(keras)
  library(tensorflow)
})

# Uncomment once if TensorFlow is not installed
# tensorflow::install_tensorflow()

set.seed(123)

# -----------------------------
# 2. Download Brent oil prices
# -----------------------------
getSymbols("DCOILBRENTEU", src = "FRED")

brent <- na.omit(DCOILBRENTEU)

brent_df <- tibble(
  date = index(brent),
  price = as.numeric(brent$DCOILBRENTEU)
)

# -----------------------------
# 3. Normalize prices
# -----------------------------
price_min <- min(brent_df$price)
price_max <- max(brent_df$price)

price_scaled <- rescale(brent_df$price)

# -----------------------------
# 4. Create LSTM sequences
# -----------------------------
create_sequences <- function(data, lookback = 30) {
  X <- list()
  y <- list()
  
  for (i in (lookback + 1):length(data)) {
    X[[i - lookback]] <- data[(i - lookback):(i - 1)]
    y[[i - lookback]] <- data[i]
  }
  
  list(
    X = array(unlist(X), dim = c(length(X), lookback, 1)),
    y = array(unlist(y))
  )
}

lookback <- 30
seq_data <- create_sequences(price_scaled, lookback)

X <- seq_data$X
y <- seq_data$y

# -----------------------------
# 5. Train / test split
# -----------------------------
train_size <- floor(0.8 * dim(X)[1])

X_train <- X[1:train_size,,]
y_train <- y[1:train_size]

X_test  <- X[(train_size + 1):dim(X)[1],,]
y_test  <- y[(train_size + 1):length(y)]

# -----------------------------
# 6. Build LSTM model
# -----------------------------
model <- keras_model_sequential() %>%
  layer_lstm(
    units = 50,
    return_sequences = TRUE,
    input_shape = c(lookback, 1)
  ) %>%
  layer_lstm(units = 50) %>%
  layer_dense(units = 1)

model %>% compile(
  optimizer = "adam",
  loss = "mean_squared_error"
)

print(summary(model))

# -----------------------------
# 7. Train model
# -----------------------------
history <- model %>% fit(
  X_train,
  y_train,
  epochs = 30,
  batch_size = 32,
  validation_split = 0.1,
  verbose = 1
)

# -----------------------------
# 8. Predict prices
# -----------------------------
pred_scaled <- model %>% predict(X_test)

predicted <- pred_scaled * (price_max - price_min) + price_min
actual    <- y_test * (price_max - price_min) + price_min

# -----------------------------
# 9. Evaluate model
# -----------------------------
rmse <- sqrt(mean((predicted - actual)^2))
cat("RMSE:", rmse, "\n")

# -----------------------------
# 10. Plot results
# -----------------------------
results <- tibble(
  date = brent_df$date[(train_size + lookback + 1):nrow(brent_df)],
  actual = actual,
  predicted = predicted[,1]
)

ggplot(results, aes(x = date)) +
  geom_line(aes(y = actual), color = "black") +
  geom_line(aes(y = predicted), color = "blue") +
  labs(
    title = "Brent Oil Price Prediction (LSTM)",
    x = "Date",
    y = "USD per Barrel"
  ) +
  theme_minimal()

# -----------------------------
# 11. Forecast next 10 days
# -----------------------------
forecast_days <- 10
last_sequence <- X_test[dim(X_test)[1],,, drop = FALSE]

future_scaled <- numeric(forecast_days)

for (i in 1:forecast_days) {
  next_pred <- model %>% predict(last_sequence)
  future_scaled[i] <- next_pred
  
  last_sequence <- array(
    c(last_sequence[,,][2:lookback], next_pred),
    dim = c(1, lookback, 1)
  )
}

future_prices <- future_scaled * (price_max - price_min) + price_min
print(future_prices)
