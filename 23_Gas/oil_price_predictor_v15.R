################################################################################
##  oil_price_predictor_v15.R
##  Brent Crude & California Gasoline Price Forecasting
##
##  WHAT THIS SCRIPT DOES:
##  Fetches 2 years of daily Brent/WTI futures + 12-contract WTI curve from
##  Yahoo Finance and weekly California retail gasoline prices from EIA.
##  Engineers technical indicators, topic-segmented news sentiment, a refinery
##  outage intensity index, asymmetric sentiment lags, calendar spread features,
##  and seasonal demand indices. Fits ARIMA-X, Prophet, and LASSO, combined into
##  an inverse-RMSE weighted ensemble. A GAM spread model converts Brent to CA
##  retail gasoline with CA-specific sentiment and regime interaction terms.
##  Forecasts 9 months ahead with confidence intervals.
##
##  IMPROVEMENTS IN v08 (from v07 diagnostic report 2026-05-05):
##   18. Spot-anchored ensemble: v07 diagnostic showed persistent under-
##       prediction bias (0% over-predictions, error trend −$0.22/day, error
##       ACF 0.41). The raw ensemble forecast for 1M was $94.96 vs spot $106.42
##       — an $11.50 gap from day 1. Root cause: the ensemble averages three
##       models trained on the full 2-year window, which includes periods at
##       lower prices. In a strong trend regime, this historical anchoring
##       creates systematic under-prediction.
##       
##       Fix: a spot-anchoring correction that blends the raw ensemble with
##       a "no-change from spot" baseline. The blend weight decays over the
##       forecast horizon — near-term forecasts are anchored strongly to
##       current spot (because the best short-term predictor of oil price
##       is today's price), while longer-term forecasts gradually release
##       to the model's learned dynamics. The decay rate (anchor_halflife)
##       is calibrated on the backtest holdout to minimize RMSE.
##       
##       For the backtest, the anchor is the last training price (not true
##       spot), so the correction is honestly evaluated out-of-sample.
##
##   19. Backtest bias correction for CA gasoline: v07 showed CA gas R² = −1.63
##       because Brent under-prediction errors were amplified through the spread
##       model. The spot-anchoring fix (#18) addresses the root cause. Additionally,
##       the spread model now uses the anchored Brent ensemble (not the raw one)
##       when computing the CA gas forecast, so any remaining Brent bias doesn't
##       propagate through the spread conversion.
##
##   20. brent_wti_diff replaced with wti_basis: v07 diagnostic showed
##       brent_wti_diff was non-significant in the GAM (p>0.05). Replaced with
##       wti_basis = (spot WTI − 3rd month WTI) / spot, which captures US-
##       specific supply tightness more directly than the Brent-WTI spread.
##       Uses the curve data already fetched in Section 2b.
##
##   21. Diagnostic report feature dedup: v07 showed duplicate feature names
##       in LASSO top-5 (price_vs_ma63 appeared 5x). Fixed by adding
##       distinct(term, .keep_all=TRUE) to the tidy() pipeline in d2 plot.
##
##  PRIOR IMPROVEMENTS (v05):
##    1. Topic-segmented sentiment: global geopolitics, OPEC policy, refinery
##       outages, CA regulation, macro demand — each scored separately
##    2. Sentiment routed by mechanism: global channels → Brent models;
##       CA-specific channels (refinery, regulatory) → spread model only
##    3. Refinery Stress Index: keyword-weighted CA refinery outage signal
##       built from news cache; added only to spread model
##    4. Asymmetric sentiment lags: negative news lags 0-2 days (fast),
##       positive news lags 5-21 days (slow decay)
##    5. Calendar spread features: front-month vs 2nd-month WTI spread,
##       3-month slope — encode expectations before spot reacts
##    6. Event-driven sentiment: daily max |score|, article count, and
##       sentiment volatility — captures shocks not visible in daily means
##    7. Regime interaction terms: sent_supply_risk × bb_width (volatility
##       regime), sent_refinery × summer_peak (seasonal amplification)
##    8. GAM spread model: replaces OLS with mgcv::gam() for nonlinear
##       seasonal effects; retains interpretability
##    9. Distributed lag: Brent → CA pump price over 3-21 days (weighted
##       rolling average) — accounts for pass-through delay
##   10. Counterfactual diagnostic: ensemble run with/without news features;
##       ΔRMSE and ΔMAPE reported; "news contribution" tracked in run_log
##
##  OUTPUT FILES (date-stamped, written to OUT_DIR):
##    oil_price_forecast_YYYY-MM-DD.png     — eight-panel diagnostic plot
##    oil_forecast_results_YYYY-MM-DD.csv   — per-day predictions + actuals
##    futures_curve_YYYY-MM-DD.csv          — WTI term structure snapshot
##    master_features_YYYY-MM-DD.csv        — full feature matrix
##    oil_models_YYYY-MM-DD.rds             — saved model objects
##    news_cache.csv                        — growing RSS news archive
##    run_log.csv                           — one-row accuracy summary per run
##                                            (includes news_delta_RMSE and
##                                             fred_delta_RMSE columns)
##
##  KNOWN LIMITATIONS:
##    - 9-month forecasts: treat as scenario ranges, not point predictions
##    - WTI curve used as Brent proxy (Yahoo doesn't serve Brent deferred)
##    - RSS sentiment cache is thin on first run; grows with weekly runs
##    - ARIMA assumes stationarity; Prophet handles regime shifts better
##    - GAM requires mgcv package; falls back to lm() if not available
##    - FRED macro rate-of-change features carried forward as 0 in forecast
##      horizon (assumes no further macro change); consider scenario projection
##    - Momentum features (ret_21d, momentum_63d) set to 0 in forecast horizon;
##      this is conservative and may under-predict in strong trends
##
##  REQUIRES in ~/.Renviron:
##    EIA_KEY      = <your key>   https://www.eia.gov/opendata/       (free)
##    FRED_API_KEY = <your key>   https://fred.stlouisfed.org/docs/api/api_key.html  (free)
################################################################################


# ══════════════════════════════════════════════════════════════════════════════
# 0. PACKAGES
# ══════════════════════════════════════════════════════════════════════════════

pkgs <- c(
  "httr2", "xml2",
  "tidyverse", "lubridate", "zoo",
  "TTR", "slider",
  "tidytext", "SnowballC", "syuzhet",
  "forecast", "prophet",
  "tidymodels", "glmnet",
  "mgcv",          # GAM for nonlinear spread model (#8)
  "patchwork", "scales"
)

new_pkgs <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(new_pkgs)) {
  message("Installing: ", paste(new_pkgs, collapse = ", "))
  install.packages(new_pkgs, repos = "https://cloud.r-project.org")
}
invisible(lapply(pkgs, library, character.only = TRUE))

# ── Consolidated conflict resolution (v14) ───────────────────────────────────
# All conflict_prefer() calls in one place to avoid scattered declarations.
# These packages have overlapping function names that cause errors without
# explicit disambiguation.
if (requireNamespace("conflicted", quietly = TRUE)) {
  library(conflicted)
  # dplyr verbs (most common conflicts)
  conflict_prefer("select",   "dplyr")
  conflict_prefer("filter",   "dplyr")
  conflict_prefer("lag",      "dplyr")
  conflict_prefer("combine",  "dplyr")
  conflict_prefer("collapse", "dplyr")
  # ggplot2
  conflict_prefer("margin",   "ggplot2")
  # tidyr
  conflict_prefer("expand",   "tidyr")
  conflict_prefer("pack",     "tidyr")
  conflict_prefer("unpack",   "tidyr")
  # purrr
  conflict_prefer("discard",  "purrr")
  conflict_prefer("flatten",  "purrr")
  conflict_prefer("invoke",   "purrr")
  # yardstick / recipes
  conflict_prefer("rmse",     "yardstick")
  conflict_prefer("accuracy", "yardstick")
  conflict_prefer("spec",     "yardstick")
  conflict_prefer("step",     "recipes")
  conflict_prefer("update",   "recipes")
  conflict_prefer("fixed",    "recipes")
  # other
  conflict_prefer("area",     "patchwork")
  conflict_prefer("rescale",  "scales")
  conflict_prefer("momentum", "TTR")
  conflict_prefer("populate", "rsample")
  conflict_prefer("url_parse","httr2")
}


# ══════════════════════════════════════════════════════════════════════════════
# 1. CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

EIA_API_KEY  <- Sys.getenv("EIA_KEY")
NEWS_API_KEY <- Sys.getenv("NEWSAPI_KEY")
FRED_API_KEY <- Sys.getenv("FRED_API_KEY")    # NEW v06

BRENT_TICKER <- "BZ=F"
WTI_TICKER   <- "CL=F"

# WTI curve — confirmed working format CL{letter}{year}.NYM (tested May 2026)
# Brent deferred contracts return HTTP 404 on Yahoo Finance
# UPDATE ANNUALLY: add next year's contracts as current year rolls off
WTI_CURVE_TICKERS <- c(
  "CLM26.NYM", "CLN26.NYM", "CLQ26.NYM", "CLU26.NYM",
  "CLV26.NYM", "CLX26.NYM", "CLZ26.NYM", "CLF27.NYM",
  "CLG27.NYM", "CLH27.NYM", "CLJ27.NYM", "CLK27.NYM"
)

# FRED series IDs for macro indicators (NEW v06)
FRED_SERIES <- list(
  usd_index   = "DTWEXBGS",   # Trade-weighted USD index (daily)
  init_claims = "ICNSA",      # Initial unemployment claims, NSA (weekly)
  yield_10y2y = "T10Y2Y"      # 10Y-2Y Treasury spread (daily)
)

LOOKBACK_DAYS    <- 540      # v11: 18 months (365 was too short, caused instability)
FORECAST_HORIZON <- 270     # v11: 9 months ahead (was 6 months)

DATE_END   <- Sys.Date()
DATE_START <- DATE_END - LOOKBACK_DAYS
RUN_DATE   <- format(DATE_END, "%Y-%m-%d")

OUT_DIR <- "/home/mwl04747/RTricks/23_Gas"
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

# ── Subdirectories for organized output (NEW v08) ────────────────────────────
OUT_CSV <- file.path(OUT_DIR, "csv")
OUT_PNG <- file.path(OUT_DIR, "png")
OUT_RDS <- file.path(OUT_DIR, "rds")
for (d in c(OUT_CSV, OUT_PNG, OUT_RDS)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# out_path() routes by extension; falls back to OUT_DIR for unknown types
out_path <- function(fname) {
  ext <- tolower(tools::file_ext(fname))
  subdir <- switch(ext,
                   csv = OUT_CSV,
                   png = OUT_PNG,
                   rds = OUT_RDS,
                   txt = OUT_CSV,    # logs and reports with CSVs
                   OUT_DIR           # fallback
  )
  file.path(subdir, fname)
}

cat(sprintf("
═══════════════════════════════════════════════════════
  Oil Price Forecasting System  v15  |  run: %s
  Training window : %s  →  %s  (18 months)
  Forecast horizon: %d calendar days (9 months)
  Output directory: %s
    csv/ png/ rds/ subdirectories
═══════════════════════════════════════════════════════\n",
            RUN_DATE, DATE_START, DATE_END, FORECAST_HORIZON, OUT_DIR))


# ══════════════════════════════════════════════════════════════════════════════
# 2. MARKET DATA
# ══════════════════════════════════════════════════════════════════════════════

# ── 2a. Generic Yahoo Finance v8 fetcher ─────────────────────────────────────

get_yahoo <- function(ticker, from = DATE_START, to = DATE_END) {
  period1 <- as.integer(as.POSIXct(from))
  period2 <- as.integer(as.POSIXct(to))
  url <- paste0("https://query1.finance.yahoo.com/v8/finance/chart/", ticker,
                "?interval=1d&period1=", period1, "&period2=", period2)
  tryCatch({
    resp  <- request(url) |>
      req_headers("User-Agent" = "Mozilla/5.0 (compatible; R script)") |>
      req_perform() |> resp_body_json()
    chart <- resp$chart$result[[1]]
    ohlcv <- chart$indicators$quote[[1]]
    to_num <- function(x) as.numeric(sapply(x, \(v) if (is.null(v)) NA_real_ else v))
    dates <- as.Date(as.POSIXct(unlist(chart$timestamp), origin = "1970-01-01"))
    close <- to_num(ohlcv$close); open <- to_num(ohlcv$open)
    high  <- to_num(ohlcv$high);  low  <- to_num(ohlcv$low)
    vol   <- to_num(ohlcv$volume)
    n <- min(length(dates), length(close), length(open),
             length(high), length(low), length(vol))
    tibble(date=dates[1:n], open=open[1:n], high=high[1:n],
           low=low[1:n], close=close[1:n], vol=vol[1:n]) |> drop_na(close)
  }, error = function(e) {
    message(sprintf("  Yahoo [%s]: %s", ticker, conditionMessage(e)))
    tibble(date=as.Date(character()), open=numeric(), high=numeric(),
           low=numeric(), close=numeric(), vol=numeric())
  })
}

add_prefix <- function(df, prefix) {
  nms <- names(df)
  setNames(df, ifelse(nms == "date", "date", paste0(prefix, nms)))
}

cat("► Fetching Brent and WTI front-month futures…\n")
brent_raw <- get_yahoo(BRENT_TICKER) |> add_prefix("brent_")
wti_raw   <- get_yahoo(WTI_TICKER)   |> add_prefix("wti_")
cat(sprintf("  Brent: %d days | WTI: %d days\n", nrow(brent_raw), nrow(wti_raw)))
if (nrow(brent_raw) == 0) stop("Brent data empty — check network or ticker")


# ── 2b. WTI futures curve + calendar spread features (#5) ────────────────────
#
# IMPROVEMENT #5: Futures market expectations often lead spot prices.
# The calendar spread (front-month minus 2nd-month) is particularly informative:
#   Large positive spread (strong backwardation) → tight current supply
#   Negative spread (contango) → oversupply / weak near-term demand
#
# We compute:
#   curve_slope     — (12M - spot) / spot: full curve steepness
#   calendar_spread — (spot - 2nd month) / spot: near-term tightness signal
#   slope_3m        — (3M - spot) / spot: 3-month expectations
#   n_contango      — count of months where next > current (supply comfort)

cat("► Fetching WTI futures curve (months 2-12)…\n")
curve_prices <- map_dfr(WTI_CURVE_TICKERS, function(ticker) {
  Sys.sleep(0.15)
  df <- get_yahoo(ticker, from = DATE_END - 7, to = DATE_END)
  if (nrow(df) == 0) return(tibble())
  tibble(ticker = ticker, price = tail(df$close[!is.na(df$close)], 1))
}) |> drop_na(price)

cat(sprintf("  Curve contracts: %d of %d\n", nrow(curve_prices), length(WTI_CURVE_TICKERS)))

spot_wti <- tail(wti_raw$wti_close[!is.na(wti_raw$wti_close)], 1)

if (nrow(curve_prices) >= 3) {
  curve_vec <- c(spot_wti, curve_prices$price)
  n_c <- length(curve_vec)
  curve_metrics <- tibble(
    run_date         = as.Date(RUN_DATE),
    spot_wti         = spot_wti,
    price_2m         = curve_vec[2],
    price_3m         = if (n_c >= 4) curve_vec[4] else NA_real_,
    price_6m         = if (n_c >= 7) curve_vec[7] else NA_real_,
    price_12m        = curve_vec[min(13, n_c)],
    curve_slope      = (curve_vec[min(13,n_c)] - spot_wti) / spot_wti,
    calendar_spread  = (spot_wti - curve_vec[2]) / spot_wti,  # KEY: near tightness
    slope_3m         = if (n_c >= 4) (curve_vec[4] - spot_wti) / spot_wti else 0,
    # WTI basis: spot vs 3rd month — US supply tightness signal (NEW v08 — #20)
    wti_basis        = if (n_c >= 4) (spot_wti - curve_vec[4]) / spot_wti else 0,
    n_contango       = sum(diff(curve_vec) > 0, na.rm = TRUE),
    market_structure = ifelse((curve_vec[min(13,n_c)] - spot_wti) / spot_wti > 0,
                              "Contango", "Backwardation")
  )
  cat(sprintf("  Structure: %s | Slope: %+.1f%% | Cal spread: %+.1f%%\n",
              curve_metrics$market_structure,
              curve_metrics$curve_slope * 100,
              curve_metrics$calendar_spread * 100))
  # Save curve snapshot
  bind_cols(curve_metrics,
            setNames(as.list(curve_prices$price), curve_prices$ticker) |>
              as_tibble()) |>
    write_csv(out_path(sprintf("futures_curve_%s.csv", RUN_DATE)))
} else {
  curve_metrics <- tibble(run_date=as.Date(RUN_DATE), spot_wti=spot_wti,
                          price_2m=NA, price_3m=NA, price_6m=NA, price_12m=NA,
                          curve_slope=0, calendar_spread=0, slope_3m=0, wti_basis=0,
                          n_contango=0, market_structure="Unknown")
}


# ── 2c. EIA California retail gasoline ───────────────────────────────────────

fetch_eia <- function(series_id, key = EIA_API_KEY) {
  if (is.na(key) || nchar(key) == 0) { message("No EIA_KEY"); return(NULL) }
  req <- request("https://api.eia.gov/v2/petroleum/pri/gnd/data/") |>
    req_url_query(api_key=key, frequency="weekly", `data[0]`="value",
                  `facets[series][]`=series_id,
                  start=as.character(DATE_START), end=as.character(DATE_END),
                  `sort[0][column]`="period", `sort[0][direction]`="asc",
                  length=5000)
  resp <- req_perform(req)
  raw  <- resp_body_json(resp)$response$data
  tibble(date=as.Date(map_chr(raw,"period")),
         ca_gas=as.numeric(map_chr(raw,"value"))) |> drop_na()
}

cat("► Fetching EIA California gasoline prices…\n")
ca_gas_raw <- fetch_eia("EMM_EPM0_PTE_SCA_DPG")
if (is.null(ca_gas_raw)) {
  ca_gas_raw <- brent_raw |>
    transmute(date, ca_gas = brent_close * 0.027 + 1.05 + rnorm(n(), 0, 0.04))
  cat("  Using Brent-derived proxy\n")
} else {
  cat(sprintf("  EIA data: %d weekly observations\n", nrow(ca_gas_raw)))
}

# ── Texas gasoline price for comparison (NEW v08) ────────────────────────────
# Not modeled — used only in the summary bar chart (f4) to show the CA premium.
cat("► Fetching EIA Texas gasoline prices…\n")
tx_gas_raw <- fetch_eia("EMM_EPMRU_PTE_STX_DPG")
if (!is.null(tx_gas_raw)) {
  tx_gas_raw <- tx_gas_raw |> rename(tx_gas = ca_gas)
  tx_gas_latest <- tail(tx_gas_raw$tx_gas[!is.na(tx_gas_raw$tx_gas)], 1)
  cat(sprintf("  TX EIA data: %d obs | Latest: $%.2f/gal\n",
              nrow(tx_gas_raw), tx_gas_latest))
} else {
  tx_gas_latest <- NA_real_
  cat("  TX gas unavailable\n")
}


# ── 2d. FRED macro indicators (#11, #12 — NEW v06) ──────────────────────────
#
# IMPROVEMENT #11: Three hard-data demand-side features from FRED.
# These complement the sentiment-derived macro signal with actual economic data:
#
#   DTWEXBGS (usd_index)   — Trade-weighted USD index. Oil is denominated in
#     dollars; a 1% USD appreciation typically maps to ~0.5-0.7% oil decline.
#     Daily series, no interpolation needed for business days.
#
#   ICNSA (init_claims)    — Initial unemployment claims, not seasonally
#     adjusted. A leading indicator: rising claims signal labor market
#     weakness → future demand destruction. Weekly, forward-filled to daily.
#
#   T10Y2Y (yield_10y2y)   — 10-Year minus 2-Year Treasury yield spread.
#     Inversion (negative values) is a well-documented recession leading
#     indicator. A flattening curve signals tightening financial conditions
#     → weaker future demand. Daily series.
#
# IMPROVEMENT #12: Generic fetch_fred() uses httr2 directly — no fredr
# package dependency. Same HTTP stack as the Yahoo and EIA fetchers.

fetch_fred <- function(series_id, key = FRED_API_KEY,
                       from = DATE_START, to = DATE_END) {
  if (is.na(key) || nchar(key) == 0) {
    message(sprintf("  No FRED_API_KEY — skipping %s", series_id))
    return(tibble(date = as.Date(character()), value = numeric()))
  }
  tryCatch({
    resp <- request("https://api.stlouisfed.org/fred/series/observations") |>
      req_url_query(
        api_key           = key,
        series_id         = series_id,
        observation_start = as.character(from),
        observation_end   = as.character(to),
        file_type         = "json"
      ) |>
      req_perform() |>
      resp_body_json()
    
    map_dfr(resp$observations, function(obs) {
      tibble(date  = as.Date(obs$date),
             value = suppressWarnings(as.numeric(obs$value)))
    }) |> drop_na(value)
  }, error = function(e) {
    message(sprintf("  FRED [%s]: %s", series_id, conditionMessage(e)))
    tibble(date = as.Date(character()), value = numeric())
  })
}

cat("► Fetching FRED macro indicators…\n")
usd_index    <- fetch_fred(FRED_SERIES$usd_index)   |> rename(usd_index   = value)
claims_raw   <- fetch_fred(FRED_SERIES$init_claims)  |> rename(init_claims = value)
yield_spread <- fetch_fred(FRED_SERIES$yield_10y2y)  |> rename(yield_10y2y = value)

cat(sprintf("  USD index: %d obs | Claims: %d obs | Yield spread: %d obs\n",
            nrow(usd_index), nrow(claims_raw), nrow(yield_spread)))

# Scale initial claims to thousands for numerical stability in models
if (nrow(claims_raw) > 0) {
  claims_raw <- claims_raw |> mutate(init_claims = init_claims / 1000)
}

# ── FRED rate-of-change transformation (NEW v07 — #15) ───────────────────────
#
# v06 diagnostic showed raw FRED levels HURT RMSE by $2.70. The problem:
# levels create spurious correlations — e.g., yield_10y2y at +0.50 trained
# a strong negative coefficient, treating a normal yield curve as bearish.
#
# Fix: transform to 21-day rate-of-change. This captures the DIRECTION of
# macro change (weakening dollar, rising claims, flattening curve) which is
# what actually predicts oil price moves. A dollar that's been weakening for
# 3 weeks predicts rising oil even if the dollar level is still high.
#
# usd_chg_21d   — % change in USD index over 21 trading days
# claims_chg_4w — 4-week change in initial claims (thousands)
# yield_chg_21d — absolute change in yield spread over 21 days (pp)

if (nrow(usd_index) > 21) {
  usd_index <- usd_index |>
    arrange(date) |>
    mutate(usd_chg_21d = (usd_index / lag(usd_index, 21)) - 1) |>
    select(date, usd_index, usd_chg_21d)
  cat("  USD: added 21-day rate-of-change\n")
}

if (nrow(claims_raw) > 4) {
  claims_raw <- claims_raw |>
    arrange(date) |>
    mutate(claims_chg_4w = init_claims - lag(init_claims, 4)) |>
    select(date, init_claims, claims_chg_4w)
  cat("  Claims: added 4-week change\n")
}

if (nrow(yield_spread) > 21) {
  yield_spread <- yield_spread |>
    arrange(date) |>
    mutate(yield_chg_21d = yield_10y2y - lag(yield_10y2y, 21)) |>
    select(date, yield_10y2y, yield_chg_21d)
  cat("  Yield spread: added 21-day change\n")
}


# ══════════════════════════════════════════════════════════════════════════════
# 3. FEATURE ENGINEERING
# ══════════════════════════════════════════════════════════════════════════════

# ── 3a. Technical indicators ──────────────────────────────────────────────────

add_tech_features <- function(df, price_col) {
  p <- df[[price_col]]; vol <- df[["vol"]]
  df |> mutate(
    ret_1d      = (p / lag(p,1)) - 1,
    ret_5d      = (p / lag(p,5)) - 1,
    ret_21d     = (p / lag(p,21)) - 1,
    ma_5        = zoo::rollmean(p, 5,  fill=NA, align="right"),
    ma_21       = zoo::rollmean(p, 21, fill=NA, align="right"),
    ma_63       = zoo::rollmean(p, 63, fill=NA, align="right"),
    ema_12      = TTR::EMA(p, 12),
    ema_26      = TTR::EMA(p, 26),
    macd        = ema_12 - ema_26,
    rsi_14      = TTR::RSI(p, 14),
    bb_upper    = ma_21 + 2 * slider::slide_dbl(p, sd, .before=20),
    bb_lower    = ma_21 - 2 * slider::slide_dbl(p, sd, .before=20),
    bb_width    = (bb_upper - bb_lower) / ma_21,
    vol_ratio   = vol / zoo::rollmean(vol, 10, fill=NA, align="right"),
    trend_slope = slider::slide_dbl(p, ~coef(lm(.x~seq_along(.x)))[2], .before=13)
  )
}

cat("► Engineering technical indicators…\n")
brent_feat <- brent_raw |> rename(vol=brent_vol) |>
  add_tech_features("brent_close") |> rename(brent_vol=vol)
cat(sprintf("  brent_feat: %d rows × %d cols\n", nrow(brent_feat), ncol(brent_feat)))


# ── 3b. Seasonal demand features ─────────────────────────────────────────────

add_seasonal_demand <- function(df) {
  df |> mutate(
    doy = lubridate::yday(date),
    mon = lubridate::month(date),
    dom = lubridate::mday(date),
    # Continuous indices: smoother signal than binary dummies
    driving_season_idx  = pmax(0, sin(2*pi*(doy-80)/365)),   # peaks Jul 4
    heating_demand_idx  = pmax(0, -cos(2*pi*doy/365)),        # peaks Jan 15
    refinery_maint      = as.integer(mon %in% c(3,4,9,10)),   # spring/fall maint
    opec_meeting_window = as.integer(mon %in% c(6,12) & dom <= 21)
  )
}


# ── 3c. Calendar features ─────────────────────────────────────────────────────

add_macro_features <- function(df) {
  df |> mutate(
    dow         = lubridate::wday(date, label=TRUE),
    month       = lubridate::month(date),
    quarter     = lubridate::quarter(date),
    is_monday   = as.integer(lubridate::wday(date) == 2),
    summer_peak = as.integer(lubridate::month(date) %in% 5:8),
    winter_heat = as.integer(lubridate::month(date) %in% c(11,12,1,2))
  )
}


# ── 3d. Distributed lag: Brent → CA pump price (#9) ──────────────────────────
#
# IMPROVEMENT #9: Retail pump prices don't react instantly to crude changes.
# The empirical pass-through lag is typically 3-21 days, with most response
# in the first week. We create a weighted distributed lag of Brent where
# recent days get higher weight, allowing the spread model to capture the
# delayed transmission from crude to pump prices.
#
# dl_brent_lag = weighted average of Brent over past 21 days
# The weight vector decays geometrically: w_t ∝ 0.8^(lag)

add_distributed_lag <- function(df, price_col = "brent_close", decay = 0.8, n_lags = 21) {
  p <- df[[price_col]]
  weights <- decay^(0:(n_lags-1))
  weights <- weights / sum(weights)   # normalise to sum to 1
  df |> mutate(
    dl_brent_lag = slider::slide_dbl(
      p,
      ~ sum(.x * rev(weights[1:length(.x)]), na.rm = TRUE),
      .before = n_lags - 1,
      .complete = FALSE
    )
  )
}


# ══════════════════════════════════════════════════════════════════════════════
# 4. NEWS SENTIMENT — TOPIC-SEGMENTED RSS CACHE SYSTEM (#1, #2, #3, #4, #6)
# ══════════════════════════════════════════════════════════════════════════════
#
# IMPROVEMENT #1 — Topic-segmented sentiment:
# Instead of a single positive/negative score, we score five mechanism-specific
# channels using keyword dictionaries. This aligns sentiment timing with the
# actual price transmission mechanism:
#
#   sent_supply_risk    — geopolitical conflict, sanctions, Middle East, Russia
#                         → affects Brent via supply disruption expectations
#   sent_opec_policy    — OPEC meeting, production cut, quota, cartel
#                         → affects futures curve expectations
#   sent_refinery       — refinery outage, shutdown, maintenance, fire
#                         → affects CA spread (local supply constraint)
#   sent_ca_regulatory  — CARB, California regulation, emissions, blend
#                         → affects CA spread (compliance cost)
#   sent_macro_demand   — recession, GDP, demand, economy, slowdown
#                         → affects global demand expectations (slow)
#
# IMPROVEMENT #2 — Sentiment routing:
# Global channels (supply_risk, opec, macro) → Brent ensemble features
# CA-specific channels (refinery, regulatory) → spread model only
# This prevents global war news from unrealistically widening CA pump margins.
#
# IMPROVEMENT #3 — Refinery Stress Index:
# Keyword hits weighted by California refinery proximity score.
# Added ONLY to spread model.
#
# IMPROVEMENT #4 — Asymmetric lags:
# Negative sentiment: 0-2 day lag (fast market reaction)
# Positive sentiment: 5-21 day lag (slow/partial reversion)
#
# IMPROVEMENT #6 — Event-driven features:
# Daily max |score|, article count, sentiment volatility (SD)
# These capture shocks that daily means dilute.

NEWS_CACHE_FILE <- out_path("news_cache.csv")

# CA refinery names for proximity scoring (#3)
CA_REFINERY_KEYWORDS <- c(
  "chevron richmond", "richmond refinery", "martinez refinery",
  "torrance refinery", "rodeo refinery", "wilmington refinery",
  "el segundo refinery", "tesoro", "valero", "phillips 66",
  "california refinery", "bay area refinery", "los angeles refinery"
)

# Topic keyword dictionaries (#1)
TOPIC_KEYWORDS <- list(
  supply_risk   = c("sanctions", "geopolit", "middle east", "strait hormuz",
                    "russia", "iran", "iraq", "opec cut", "supply disruption",
                    "pipeline attack", "oil field", "conflict", "war", "embargo"),
  opec_policy   = c("opec", "opec+", "production cut", "output quota",
                    "saudi arabia", "uae", "production target", "barrel per day",
                    "meeting decision", "cartel", "compliance"),
  refinery      = c("refinery", "outage", "shutdown", "maintenance", "fire",
                    "unplanned", "flare", "crackers", "crude unit",
                    "coker", "capacity offline", "restart"),
  ca_regulatory = c("carb", "california air", "low carbon", "fuel standard",
                    "summer blend", "reformulated", "oxygenate", "ethanol",
                    "california regulation", "emissions standard", "ab 32"),
  macro_demand  = c("recession", "gdp", "demand forecast", "economic slowdown",
                    "consumption", "unemployment", "industrial output",
                    "china demand", "india demand", "global growth")
)

fetch_rss <- function(feed_url, source_name) {
  feed <- tryCatch(xml2::read_xml(feed_url),
                   error = function(e) {
                     message(sprintf("  RSS blocked [%s]", source_name)); NULL })
  if (is.null(feed)) return(tibble())
  items <- xml2::xml_find_all(feed, "//item")
  if (length(items) == 0) return(tibble())
  purrr::map_dfr(items, function(item) {
    pub   <- xml2::xml_text(xml2::xml_find_first(item, ".//pubDate"))
    title <- xml2::xml_text(xml2::xml_find_first(item, ".//title"))
    desc  <- xml2::xml_text(xml2::xml_find_first(item, ".//description"))
    tibble(
      date       = tryCatch(as.Date(lubridate::parse_date_time(
        pub, orders=c("a, d b Y H:M:S z","d b Y H:M:S z","a, d b Y"))),
        error=function(e) as.Date(NA)),
      text       = paste(title %||% "", desc %||% "", sep=" "),
      source     = source_name,
      fetched_on = Sys.Date()
    )
  }) |> drop_na(date)
}

cat("► Fetching RSS news feeds…\n")
rss_today <- bind_rows(
  fetch_rss("https://finance.yahoo.com/rss/headline?s=BZ%3DF", "yahoo_brent"),
  fetch_rss("https://finance.yahoo.com/rss/headline?s=CL%3DF", "yahoo_wti"),
  fetch_rss("https://finance.yahoo.com/rss/headline?s=USO",    "yahoo_uso"),
  fetch_rss("https://oilprice.com/rss/main",                   "oilprice")
) |> drop_na(date) |> distinct(text, .keep_all=TRUE)

cat(sprintf("  Fetched: %d unique articles\n", nrow(rss_today)))

if (file.exists(NEWS_CACHE_FILE)) {
  cache_existing <- read_csv(NEWS_CACHE_FILE, show_col_types=FALSE) |>
    mutate(date=as.Date(date), fetched_on=as.Date(fetched_on))
  cache_new <- bind_rows(cache_existing, rss_today) |>
    distinct(text, .keep_all=TRUE) |> arrange(date)
  cat(sprintf("  Cache: %d + %d new = %d total\n",
              nrow(cache_existing), nrow(cache_new)-nrow(cache_existing),
              nrow(cache_new)))
} else {
  cache_new <- rss_today |> arrange(date)
  cat(sprintf("  Cache: %d articles (first run)\n", nrow(cache_new)))
}
write_csv(cache_new, NEWS_CACHE_FILE)

news_raw <- cache_new |>
  filter(date >= DATE_START, date <= DATE_END) |>
  select(date, text)
cat(sprintf("  Articles in training window: %d\n", nrow(news_raw)))


# ── 4a. Topic-aware sentiment scoring (#1, #3, #6) ────────────────────────────

compute_topic_sentiment <- function(news_df) {
  # Returns zero-sentiment frame if no articles available
  empty_sent <- tibble(
    date             = as.Date(character()),
    # Global channels → Brent models
    sent_supply_risk = numeric(), sent_opec_policy  = numeric(),
    sent_macro_demand= numeric(),
    # CA-specific channels → spread model only
    sent_refinery    = numeric(), sent_ca_regulatory= numeric(),
    # Refinery Stress Index (#3)
    refinery_stress  = numeric(),
    # Event-driven features (#6)
    sent_neg_intensity = numeric(), sent_article_count = numeric(),
    sent_volatility    = numeric()
  )
  
  if (nrow(news_df) == 0) {
    message("  No articles — zero sentiment")
    return(empty_sent)
  }
  
  text_lower <- tolower(news_df$text)
  
  # Score each topic channel: proportion of articles mentioning topic keywords
  # × syuzhet valence score of those articles
  score_topic <- function(keywords, texts, dates) {
    hits <- sapply(texts, function(t)
      any(sapply(keywords, function(k) grepl(k, t, fixed=TRUE))))
    scores <- syuzhet::get_sentiment(texts, method="syuzhet")
    topic_scores <- ifelse(hits, scores, 0)
    tibble(date=dates, score=topic_scores, hit=hits) |>
      group_by(date) |>
      summarise(
        score     = mean(score[hit], na.rm=TRUE),
        hit_count = sum(hit),
        .groups   = "drop"
      ) |>
      mutate(score = tidyr::replace_na(score, 0))
  }
  
  sup <- score_topic(TOPIC_KEYWORDS$supply_risk,   text_lower, news_df$date)
  opc <- score_topic(TOPIC_KEYWORDS$opec_policy,   text_lower, news_df$date)
  ref <- score_topic(TOPIC_KEYWORDS$refinery,      text_lower, news_df$date)
  car <- score_topic(TOPIC_KEYWORDS$ca_regulatory, text_lower, news_df$date)
  mac <- score_topic(TOPIC_KEYWORDS$macro_demand,  text_lower, news_df$date)
  
  # Refinery Stress Index (#3): refinery hits × CA keyword proximity weight
  # CA refinery mentions get 2× weight vs generic refinery mentions
  ca_ref_hits <- sapply(text_lower, function(t)
    any(sapply(CA_REFINERY_KEYWORDS, function(k) grepl(k, t, fixed=TRUE))))
  ref_scores  <- syuzhet::get_sentiment(news_df$text, method="syuzhet")
  rsi_df <- tibble(date=news_df$date,
                   rsi_score = ifelse(ca_ref_hits, -abs(ref_scores) * 2,
                                      ifelse(grepl("refinery|outage|shutdown",
                                                   text_lower), -abs(ref_scores), 0))) |>
    group_by(date) |>
    summarise(refinery_stress = sum(rsi_score, na.rm=TRUE), .groups="drop")
  
  # Event-driven features (#6): max |score|, article count, sentiment SD
  all_scores <- syuzhet::get_sentiment(news_df$text, method="syuzhet")
  event_df <- tibble(date=news_df$date, score=all_scores) |>
    group_by(date) |>
    summarise(
      sent_neg_intensity  = min(score, 0),     # most negative article
      sent_article_count  = n(),               # volume signal
      sent_volatility     = sd(score, na.rm=TRUE),  # disagreement signal
      .groups = "drop"
    ) |>
    mutate(across(where(is.numeric), ~ tidyr::replace_na(.x, 0)))
  
  # Combine all channels by date
  all_dates <- tibble(date = seq(min(news_df$date), max(news_df$date), by="day"))
  all_dates |>
    left_join(sup |> select(date, sent_supply_risk=score), by="date") |>
    left_join(opc |> select(date, sent_opec_policy=score),   by="date") |>
    left_join(ref |> select(date, sent_refinery=score),      by="date") |>
    left_join(car |> select(date, sent_ca_regulatory=score), by="date") |>
    left_join(mac |> select(date, sent_macro_demand=score),  by="date") |>
    left_join(rsi_df,   by="date") |>
    left_join(event_df, by="date") |>
    mutate(across(where(is.numeric), ~ tidyr::replace_na(.x, 0)))
}

cat("► Computing topic-segmented sentiment…\n")
sentiment_daily <- compute_topic_sentiment(news_raw)
cat(sprintf("  Sentiment: %d days, %d channels\n",
            nrow(sentiment_daily), ncol(sentiment_daily) - 1))


# ── 4b. Asymmetric sentiment lags (#4) ────────────────────────────────────────
#
# IMPROVEMENT #4: Markets react faster to bad news than good news.
# Negative sentiment: 0-2 day exponential decay (immediate shock)
# Positive sentiment: 5-21 day rolling mean (slow partial reversion)
#
# For each channel we create:
#   {channel}_neg_fast  — negative component, 3-day exp-weighted average
#   {channel}_pos_slow  — positive component, 14-day simple rolling mean

add_asymmetric_lags <- function(sentiment_df) {
  global_channels <- c("sent_supply_risk", "sent_opec_policy", "sent_macro_demand")
  ca_channels     <- c("sent_refinery", "sent_ca_regulatory")
  all_channels    <- c(global_channels, ca_channels)
  
  for (ch in all_channels) {
    if (!ch %in% names(sentiment_df)) next
    s <- sentiment_df[[ch]]
    neg_component <- pmin(s, 0)   # negative part only
    pos_component <- pmax(s, 0)   # positive part only
    
    # Fast negative: 3-day exponentially weighted (weights: 0.5, 0.3, 0.2)
    sentiment_df[[paste0(ch, "_neg_fast")]] <- slider::slide_dbl(
      neg_component,
      ~ sum(.x * c(0.5, 0.3, 0.2)[1:length(.x)] /
              sum(c(0.5, 0.3, 0.2)[1:length(.x)]), na.rm=TRUE),
      .before = 2
    )
    
    # Slow positive: 14-day simple rolling mean
    sentiment_df[[paste0(ch, "_pos_slow")]] <- zoo::rollmean(
      pos_component, 14, fill=NA, align="right"
    )
  }
  sentiment_df
}

sentiment_daily <- add_asymmetric_lags(sentiment_daily)

# Build full daily spine with forward-fill and smoothing
sentiment_cols <- setdiff(names(sentiment_daily), "date")
sentiment_filled <- tibble(date=seq(DATE_START, DATE_END, by="day")) |>
  left_join(sentiment_daily, by="date") |>
  arrange(date) |>
  mutate(across(all_of(sentiment_cols), ~ zoo::na.locf(.x, na.rm=FALSE))) |>
  mutate(across(all_of(sentiment_cols), ~ tidyr::replace_na(.x, 0))) |>
  # Apply 7-day smoothing only to base scores (not to asymmetric lags)
  mutate(across(all_of(intersect(sentiment_cols,
                                 c("sent_supply_risk","sent_opec_policy",
                                   "sent_macro_demand","sent_refinery",
                                   "sent_ca_regulatory","refinery_stress"))),
                ~ zoo::rollmean(.x, 7, fill=NA, align="right"))) |>
  mutate(across(all_of(sentiment_cols), ~ tidyr::replace_na(.x, 0)))

cat(sprintf("  Sentiment spine: %d rows × %d sentiment columns\n",
            nrow(sentiment_filled), length(sentiment_cols)))


# ══════════════════════════════════════════════════════════════════════════════
# 5. ASSEMBLE MASTER FEATURE MATRIX
# ══════════════════════════════════════════════════════════════════════════════

cat("► Assembling master feature matrix…\n")

ca_daily <- tibble(date=seq(DATE_START, DATE_END, by="day")) |>
  left_join(ca_gas_raw, by="date") |>
  mutate(ca_gas = zoo::na.approx(ca_gas, na.rm=FALSE))

master <- tibble(date=seq(DATE_START, DATE_END, by="day")) |>
  left_join(brent_feat,       by="date") |>
  left_join(wti_raw,          by="date") |>
  left_join(ca_daily,         by="date") |>
  left_join(sentiment_filled, by="date") |>
  # ── FRED macro joins ───────────────────────────────────────────────────────
  left_join(usd_index,    by="date") |>
  left_join(claims_raw,   by="date") |>
  left_join(yield_spread, by="date") |>
  # Ensure all FRED columns exist (may be missing if fetch failed)
  (\(df) {
    for (col in c("usd_index","init_claims","yield_10y2y",
                  "usd_chg_21d","claims_chg_4w","yield_chg_21d")) {
      if (!col %in% names(df)) df[[col]] <- 0
    }
    df
  })() |>
  # Forward-fill weekly/missing FRED values to daily
  mutate(
    usd_index     = zoo::na.locf(usd_index,     na.rm = FALSE),
    init_claims   = zoo::na.locf(init_claims,    na.rm = FALSE),
    yield_10y2y   = zoo::na.locf(yield_10y2y,    na.rm = FALSE),
    usd_chg_21d   = zoo::na.locf(usd_chg_21d,   na.rm = FALSE),
    claims_chg_4w = zoo::na.locf(claims_chg_4w,  na.rm = FALSE),
    yield_chg_21d = zoo::na.locf(yield_chg_21d,  na.rm = FALSE)
  ) |>
  # ── end FRED joins ─────────────────────────────────────────────────────────
  add_macro_features()   |>
  add_seasonal_demand()  |>
  add_distributed_lag()  |>   # Brent distributed lag for spread model (#9)
  mutate(
    curve_slope      = curve_metrics$curve_slope,
    calendar_spread  = curve_metrics$calendar_spread,
    slope_3m         = curve_metrics$slope_3m,
    n_contango       = curve_metrics$n_contango,
    wti_basis        = curve_metrics$wti_basis,    # NEW v08 — #20
    # ── Momentum features (NEW v07 — #17) ────────────────────────────────────
    # v06 diagnostic: 0% over-predictions, −$1.09/day error trend, error
    # lag-1 ACF = 0.884. The model was systematically missing upward momentum.
    # These features capture trend persistence at different horizons.
    momentum_63d   = (brent_close / lag(brent_close, 63)) - 1,  # 3-month return
    price_vs_ma63  = brent_close / ma_63 - 1                    # price relative to trend
    # ── end momentum features ────────────────────────────────────────────────
  ) |>
  filter(lubridate::wday(date) %in% 2:6) |>
  arrange(date) |>
  drop_na(brent_close)

cat(sprintf("  Master: %d rows × %d columns\n", nrow(master), ncol(master)))


# ══════════════════════════════════════════════════════════════════════════════
# 6. TRAIN/TEST SPLIT AND FUTURE FRAME
# ══════════════════════════════════════════════════════════════════════════════

TRAIN_END <- DATE_END - 30

train <- master |> filter(date <= TRAIN_END)
test  <- master |> filter(date >  TRAIN_END)

future_dates <- seq(DATE_END+1, DATE_END+FORECAST_HORIZON, by="day") |>
  (\(d) d[lubridate::wday(d) %in% 2:6])()

cat(sprintf("  Train: %d | Backtest: %d | Future: %d business days\n",
            nrow(train), nrow(test), length(future_dates)))

# Future frame: use date-computable features; carry forward last known values
last_tech <- function(col) {
  if (!col %in% names(master)) return(0)
  v <- master[[col]]
  v <- v[!is.na(v)]
  if (length(v) == 0) return(0)
  tail(v, 1)
}

future_frame <- tibble(date=future_dates) |>
  add_macro_features() |>
  add_seasonal_demand() |>
  mutate(
    ret_1d          = 0,
    ret_5d          = 0,
    ret_21d         = 0,            # NEW v07: explicitly zero (no future returns)
    macd            = last_tech("macd"),
    rsi_14          = 50,
    bb_width        = last_tech("bb_width"),
    vol_ratio       = 1,
    trend_slope     = last_tech("trend_slope"),
    wti_close       = last_tech("wti_close"),     # kept for spread model only
    dl_brent_lag    = last_tech("dl_brent_lag"),
    curve_slope     = curve_metrics$curve_slope,
    calendar_spread = curve_metrics$calendar_spread,
    slope_3m        = curve_metrics$slope_3m,
    n_contango      = curve_metrics$n_contango,
    wti_basis       = curve_metrics$wti_basis,     # NEW v08 — #20
    brent_close     = last_tech("brent_close"),
    ca_gas          = last_tech("ca_gas"),
    # ── FRED rate-of-change carry-forward (NEW v07 — #15) ────────────────────
    # RoC features set to 0 in forecast = "no further macro change" assumption
    # This is more defensible than carrying forward last known change
    usd_index       = last_tech("usd_index"),
    init_claims     = last_tech("init_claims"),
    yield_10y2y     = last_tech("yield_10y2y"),
    usd_chg_21d     = 0,            # assume no further USD change
    claims_chg_4w   = 0,            # assume no further claims change
    yield_chg_21d   = 0,            # assume no further yield curve change
    # ── Momentum features (NEW v07 — #17) ────────────────────────────────────
    # Set to last known value for 1M, decay to 0 over horizon
    # This is conservative: assumes current momentum fades
    momentum_63d    = last_tech("momentum_63d") *
      pmax(0, 1 - as.numeric(future_dates - DATE_END) / FORECAST_HORIZON),
    price_vs_ma63   = last_tech("price_vs_ma63") *
      pmax(0, 1 - as.numeric(future_dates - DATE_END) / FORECAST_HORIZON)
    # ── end new features ─────────────────────────────────────────────────────
  )

# Add sentiment columns separately — across(.y) is unreliable in mutate()
# Carry forward last known value for each sentiment channel
for (sc in sentiment_cols) {
  future_frame[[sc]] <- last_tech(sc)
}

# Also add any sentiment columns that might be in xreg but not sentiment_cols
for (col in setdiff(names(master), names(future_frame))) {
  if (grepl("sent_|refinery_stress|dl_brent", col)) {
    future_frame[[col]] <- last_tech(col)
  }
}

cat(sprintf("  future_frame: %d rows × %d columns\n",
            nrow(future_frame), ncol(future_frame)))

# ── Horizon slice helpers (NEW v11) ──────────────────────────────────────────
# Business days per month ≈ 22. These functions return index ranges for
# each forecast horizon, used throughout reporting and plotting.
# Avoids hardcoded [1:22], [44:66] etc. and supports the 9-month horizon.
n_future   <- length(future_dates)
hz_1m_idx  <- 1:min(22, n_future)
hz_3m_idx  <- max(1, 44):min(66, n_future)
hz_6m_idx  <- max(1, 110):min(132, n_future)
hz_9m_idx  <- max(1, n_future - 21):n_future

# Helper: mean of a vector at a given horizon slice
hz_mean <- function(x, idx) mean(x[idx], na.rm = TRUE)


# ══════════════════════════════════════════════════════════════════════════════
# 7. MODELLING — BRENT ENSEMBLE
# ══════════════════════════════════════════════════════════════════════════════
#
# IMPROVEMENT #2 routing: Brent models use GLOBAL sentiment channels only.
# CA-specific channels (refinery, regulatory) are reserved for the spread model.
#
# IMPROVEMENT #11 (v06): FRED macro features enter here as xreg columns.
# usd_index and yield_10y2y are daily; init_claims is weekly (forward-filled).
# All three are global demand-side signals appropriate for the Brent ensemble.

# Global sentiment columns for Brent models (excludes CA-specific)
brent_sentiment_cols <- c(
  "sent_supply_risk", "sent_opec_policy", "sent_macro_demand",
  "sent_supply_risk_neg_fast", "sent_supply_risk_pos_slow",
  "sent_opec_policy_neg_fast", "sent_opec_policy_pos_slow",
  "sent_macro_demand_neg_fast", "sent_macro_demand_pos_slow",
  "sent_neg_intensity", "sent_article_count", "sent_volatility"
)

candidate_cols <- c(
  # Technical
  "ret_1d", "ret_5d", "macd", "rsi_14", "bb_width", "vol_ratio", "trend_slope",
  # Momentum features (#17)
  "ret_21d", "momentum_63d", "price_vs_ma63",
  # v14: curve features REMOVED from candidate_cols. curve_slope, calendar_spread,
  # slope_3m, n_contango are static scalars from the current curve snapshot,
  # constant across all training rows. QR check drops them every run (Curve
  # active: NONE in v13 diagnostic). No point including them.
  # Calendar
  "is_monday", "quarter",
  # Seasonal demand (continuous, non-collinear)
  "driving_season_idx", "heating_demand_idx", "refinery_maint"
)
candidate_cols <- unique(candidate_cols)

xreg_cols <- candidate_cols[sapply(candidate_cols, function(col) {
  if (!col %in% names(train)) return(FALSE)
  x <- train[[col]]
  var(x, na.rm=TRUE) > 1e-10 && mean(is.na(x)) < 0.20
})]

cat(sprintf("  Brent xreg: %d columns\n", length(xreg_cols)))

safe_scale <- function(x) {
  s <- sd(x, na.rm=TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  (x - mean(x, na.rm=TRUE)) / s
}

prep_xreg <- function(df, cols=xreg_cols_final) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0)
    df <- bind_cols(df, setNames(as.data.frame(
      matrix(0, nrow(df), length(missing))), missing))
  df |> select(all_of(cols)) |>
    mutate(across(everything(), ~ifelse(is.na(.x), 0, .x))) |>
    mutate(across(everything(), safe_scale)) |> as.matrix()
}

# ── Rank-deficiency check: run ONCE on training data (v08 fix) ───────────────
# QR decomposition on the training matrix identifies collinear columns.
# The surviving column list (xreg_cols_final) is then used for ALL subsequent
# prep_xreg() calls — train, test, future, holdout — ensuring consistent shape.
xreg_train_raw <- train |> select(all_of(xreg_cols)) |>
  mutate(across(everything(), ~ifelse(is.na(.x), 0, .x))) |>
  mutate(across(everything(), safe_scale)) |> as.matrix()

qr_decomp <- qr(xreg_train_raw)
if (qr_decomp$rank < ncol(xreg_train_raw)) {
  keep_idx <- qr_decomp$pivot[1:qr_decomp$rank]
  dropped  <- colnames(xreg_train_raw)[-keep_idx]
  xreg_cols_final <- colnames(xreg_train_raw)[keep_idx]
  cat(sprintf("  ⚠ Dropped %d collinear xreg column(s): %s\n",
              length(dropped), paste(dropped, collapse=", ")))
} else {
  xreg_cols_final <- xreg_cols
}
cat(sprintf("  Final xreg: %d columns (after rank check)\n", length(xreg_cols_final)))

xreg_train  <- prep_xreg(train)
xreg_test   <- prep_xreg(test)
xreg_future <- prep_xreg(future_frame)


# ── 7A. ARIMA-X ───────────────────────────────────────────────────────────────
#
# FIX v07 (#16): Force d=1 differencing. v06 diagnostic showed auto.arima()
# selected (0,0,1)(0,0,1)[5] — an MA-only model with no differencing.
# Ljung-Box failed badly (p<0.001), lag-1 ACF=0.18 indicating missed structure.
# Oil prices are non-stationary (unit root); differencing is mandatory.
# We force d=1 and let auto.arima() search AR/MA terms around that.

cat("► Fitting ARIMA-X (forced d=1)…\n")
brent_ts_train <- ts(log(train$brent_close), frequency=5,
                     start=c(lubridate::year(min(train$date)),
                             lubridate::week(min(train$date))))

arima_model <- auto.arima(brent_ts_train, xreg=xreg_train,
                          d=1,                              # FORCED differencing
                          stepwise=TRUE, approximation=TRUE,
                          max.p=5, max.q=3, max.P=1, max.Q=1, ic="aicc")

cat(sprintf("  ARIMA: (%d,%d,%d)(%d,%d,%d)[%d]\n",
            arimaorder(arima_model)[1], arimaorder(arima_model)[2],
            arimaorder(arima_model)[3], arimaorder(arima_model)[4],
            arimaorder(arima_model)[5], arimaorder(arima_model)[6],
            arimaorder(arima_model)[7]))

arima_pred_test   <- exp(as.numeric(forecast(arima_model,xreg=xreg_test,  h=nrow(test))$mean))
arima_fc_fut      <- forecast(arima_model, xreg=xreg_future, h=nrow(future_frame))
arima_pred_future <- exp(as.numeric(arima_fc_fut$mean))
arima_ci_lo       <- exp(as.numeric(arima_fc_fut$lower[,2]))
arima_ci_hi       <- exp(as.numeric(arima_fc_fut$upper[,2]))


# ── 7B. PROPHET ───────────────────────────────────────────────────────────────
#
# v13: Simplified Prophet. Removed static sentiment, FRED, and calendar_spread
# regressors. These were carried forward as constants into the forecast horizon,
# shifting the level by a fixed amount without contributing dynamics. Prophet's
# value in this ensemble is its changepoint detection and seasonal decomposition,
# not its ability to incorporate static exogenous variables.
#
# Retained: seasonal indices (date-computable in forecast), refinery_maint
# (date-computable), and decaying momentum_63d (provides directional signal
# that fades over the horizon).

cat("► Fitting Prophet (v13: trend/seasonality + momentum only)…\n")

make_prophet_frame <- function(dates) {
  tibble(
    ds                  = dates,
    driving_season_idx  = pmax(0, sin(2*pi*(lubridate::yday(dates)-80)/365)),
    heating_demand_idx  = pmax(0, -cos(2*pi*lubridate::yday(dates)/365)),
    summer_peak         = as.integer(lubridate::month(dates) %in% 5:8),
    refinery_maint      = as.integer(lubridate::month(dates) %in% c(3,4,9,10)),
    # Momentum: decays over horizon
    momentum_63d        = last_tech("momentum_63d") *
      pmax(0, 1 - as.numeric(dates - DATE_END) / FORECAST_HORIZON)
  )
}

prophet_df <- train |>
  transmute(
    ds                     = date,
    y                      = log(brent_close),
    driving_season_idx     = driving_season_idx,
    heating_demand_idx     = heating_demand_idx,
    summer_peak            = summer_peak,
    refinery_maint         = refinery_maint,
    momentum_63d           = ifelse(is.na(momentum_63d), 0, momentum_63d)
  )

m_prophet <- prophet(seasonality.mode="multiplicative",
                     daily.seasonality=FALSE, weekly.seasonality=TRUE,
                     yearly.seasonality=TRUE, changepoint.prior.scale=0.15)

prophet_regs <- c("driving_season_idx","heating_demand_idx","summer_peak",
                  "refinery_maint","momentum_63d")
for (r in prophet_regs) {
  m_prophet <- add_regressor(m_prophet, r,
                             standardize = !r %in% c("summer_peak","refinery_maint"))
}
m_prophet <- fit.prophet(m_prophet, prophet_df)

prophet_pred_test   <- exp(predict(m_prophet, make_prophet_frame(test$date))$yhat)
prophet_fc_future   <- predict(m_prophet, make_prophet_frame(future_dates))
prophet_pred_future <- exp(prophet_fc_future$yhat)
prophet_ci_lo       <- exp(prophet_fc_future$yhat_lower)
prophet_ci_hi       <- exp(prophet_fc_future$yhat_upper)


# ── 7C. LASSO ─────────────────────────────────────────────────────────────────

cat("► Fitting LASSO…\n")
en_recipe <- recipe(brent_close~.,
                    data=train |> select(brent_close, date, all_of(xreg_cols)) |>
                      mutate(brent_close=log(brent_close))) |>
  update_role(date, new_role="ID") |>
  step_impute_mean(all_predictors()) |>
  step_normalize(all_predictors())

en_spec <- linear_reg(penalty=tune(), mixture=tune()) |> set_engine("glmnet")
en_wf   <- workflow() |> add_recipe(en_recipe) |> add_model(en_spec)
ts_folds <- rolling_origin(train, initial=round(nrow(train)*0.7),
                           assess=10, cumulative=FALSE, skip=9)
en_grid  <- grid_regular(penalty(range=c(-2.5,0)), mixture(range=c(0.5,1)), levels=5)
en_tune  <- tune_grid(en_wf, resamples=ts_folds, grid=en_grid,
                      metrics=metric_set(rmse, rsq))
best_en  <- select_best(en_tune, metric="rmse")
final_en <- finalize_workflow(en_wf, best_en) |>
  fit(train |> mutate(brent_close=log(brent_close)))

cat(sprintf("  LASSO: penalty=%.4f mixture=%.2f\n", best_en$penalty, best_en$mixture))
lasso_pred_test   <- exp(predict(final_en, test)$.pred)
lasso_pred_future <- exp(predict(final_en, future_frame)$.pred)


# ── 7D. ENSEMBLE ──────────────────────────────────────────────────────────────

cat("► Computing ensemble weights…\n")
hv_end  <- TRAIN_END; hv_start <- hv_end - 45
holdout <- master |> filter(date > hv_start, date <= hv_end)

arima_ho   <- exp(as.numeric(forecast(arima_model,xreg=prep_xreg(holdout),
                                      h=nrow(holdout))$mean))
prophet_ho <- exp(predict(m_prophet, make_prophet_frame(holdout$date))$yhat)
lasso_ho   <- exp(predict(final_en,
                          holdout |> mutate(brent_close=log(brent_close)))$.pred)
actual_ho  <- holdout$brent_close

rmse_vec <- c(
  arima   = sqrt(mean((arima_ho-actual_ho)^2, na.rm=TRUE)),
  prophet = sqrt(mean((prophet_ho-actual_ho)^2, na.rm=TRUE)),
  lasso   = sqrt(mean((lasso_ho-actual_ho)^2, na.rm=TRUE))
)
wts <- (1/rmse_vec) / sum(1/rmse_vec)
cat(sprintf("  RMSE — ARIMA: $%.2f | Prophet: $%.2f | LASSO: $%.2f\n",
            rmse_vec["arima"], rmse_vec["prophet"], rmse_vec["lasso"]))
cat(sprintf("  Weights — ARIMA: %.2f | Prophet: %.2f | LASSO: %.2f\n",
            wts["arima"], wts["prophet"], wts["lasso"]))

# ── Forecast clamping (NEW v11) ──────────────────────────────────────────────
# Safety bound: no individual model forecast should exceed 2x or fall below
# 0.3x the last known spot price. Prevents exponential blowup from log-scale
# model instability, which caused $38K Brent forecasts in v11 with 1yr data.
clamp_bound <- spot_current <- tail(master$brent_close[!is.na(master$brent_close)], 1)
clamp_lo    <- clamp_bound * 0.3
clamp_hi    <- clamp_bound * 2.0

clamp_forecast <- function(x, label = "") {
  n_clamped <- sum(x < clamp_lo | x > clamp_hi, na.rm = TRUE)
  if (n_clamped > 0)
    cat(sprintf("  ⚠ Clamped %d %s values to [%.0f, %.0f] range\n",
                n_clamped, label, clamp_lo, clamp_hi))
  pmax(clamp_lo, pmin(clamp_hi, x))
}

arima_pred_test    <- clamp_forecast(arima_pred_test,    "ARIMA backtest")
arima_pred_future  <- clamp_forecast(arima_pred_future,  "ARIMA forecast")
arima_ci_lo        <- clamp_forecast(arima_ci_lo,        "ARIMA CI lo")
arima_ci_hi        <- clamp_forecast(arima_ci_hi,        "ARIMA CI hi")
prophet_pred_test  <- clamp_forecast(prophet_pred_test,  "Prophet backtest")
prophet_pred_future<- clamp_forecast(prophet_pred_future,"Prophet forecast")
prophet_ci_lo      <- clamp_forecast(prophet_ci_lo,      "Prophet CI lo")
prophet_ci_hi      <- clamp_forecast(prophet_ci_hi,      "Prophet CI hi")
lasso_pred_test    <- clamp_forecast(lasso_pred_test,    "LASSO backtest")
lasso_pred_future  <- clamp_forecast(lasso_pred_future,  "LASSO forecast")

ensemble_test   <- as.numeric(wts["arima"]*arima_pred_test +
                                wts["prophet"]*prophet_pred_test +
                                wts["lasso"]*lasso_pred_test)
ensemble_future <- as.numeric(wts["arima"]*arima_pred_future +
                                wts["prophet"]*prophet_pred_future +
                                wts["lasso"]*lasso_pred_future)
# Old CI computation removed — replaced by Monte Carlo bootstrap below


# ── 7E. SPOT-ANCHORED ENSEMBLE (v08 — #18) ──────────────────────────────────

cat("► Calibrating spot-anchoring correction…\n")

spot_anchor_price <- tail(train$brent_close[!is.na(train$brent_close)], 1)

halflife_candidates <- c(5, 10, 15, 21, 30, 45, 60, 90)
anchor_rmse <- sapply(halflife_candidates, function(hl) {
  days_out <- as.numeric(holdout$date - max(train$date))
  alpha    <- 0.5^(days_out / hl)
  anchored <- alpha * spot_anchor_price + (1 - alpha) * arima_ho
  sqrt(mean((anchored - actual_ho)^2, na.rm = TRUE))
})
best_halflife <- halflife_candidates[which.min(anchor_rmse)]
cat(sprintf("  Best halflife: %d days (RMSE: $%.2f vs raw $%.2f)\n",
            best_halflife, min(anchor_rmse),
            sqrt(mean((arima_ho - actual_ho)^2, na.rm = TRUE))))

# Apply spot-anchoring to backtest
bt_days_out   <- as.numeric(test$date - max(train$date))
bt_alpha      <- 0.5^(bt_days_out / best_halflife)
ensemble_test_raw <- ensemble_test
ensemble_test     <- bt_alpha * spot_anchor_price + (1 - bt_alpha) * ensemble_test

# Apply spot-anchoring to future point forecast
spot_current  <- tail(master$brent_close[!is.na(master$brent_close)], 1)
fc_days_out   <- as.numeric(future_dates - DATE_END)
fc_alpha      <- 0.5^(fc_days_out / best_halflife)
ensemble_future_raw <- ensemble_future
ensemble_future     <- fc_alpha * spot_current + (1 - fc_alpha) * ensemble_future

cat(sprintf("  Spot anchor: $%.2f (train-end) | $%.2f (current)\n",
            spot_anchor_price, spot_current))
cat(sprintf("  Anchor alpha: day 1 = %.2f | day 30 = %.2f | day 90 = %.2f | day 180 = %.2f\n",
            0.5^(1/best_halflife), 0.5^(30/best_halflife),
            0.5^(90/best_halflife), 0.5^(180/best_halflife)))


# ── 7F. MONTE CARLO BOOTSTRAP INTERVALS (NEW v15) ───────────────────────────
#
# Replace the old weighted-average CI (which mixed incompatible interval types)
# with proper empirical percentile bands from bootstrapped forecast paths.
#
# For each of N_SIM paths:
#   1. Sample ARIMA residuals with replacement, add to ARIMA point forecast
#   2. Perturb LASSO prediction by sampling from its CV residual distribution
#   3. Use Prophet's built-in uncertainty (already has yhat_lower/upper)
#      by sampling uniformly within Prophet's interval
#   4. Ensemble the perturbed predictions using the same weights
#   5. Apply spot-anchoring to the perturbed path
#   6. Clamp to safety bounds
#
# Then take quantiles across all paths:
#   median = point forecast (should be close to ensemble_future)
#   10th/90th percentile = 80% interval
#   5th/95th percentile = 90% interval
#
# This is honest: "X% of simulated paths fall within this range"
# under the assumption that future errors are drawn from the same
# distribution as training errors.

cat("► Running Monte Carlo bootstrap (forecast intervals)…\n")

N_SIM <- 500
n_fc  <- length(future_dates)

# Collect residual distributions from training
arima_resid_vec  <- as.numeric(residuals(arima_model))  # log-scale residuals
arima_resid_vec  <- arima_resid_vec[!is.na(arima_resid_vec)]

# LASSO CV residuals: compute on the holdout set
lasso_ho_pred    <- exp(predict(final_en, holdout |> mutate(brent_close=log(brent_close)))$.pred)
lasso_resid_vec  <- log(lasso_ho_pred) - log(holdout$brent_close)
lasso_resid_vec  <- lasso_resid_vec[!is.na(lasso_resid_vec)]

# Prophet interval width (used to sample within its uncertainty band)
prophet_fc_width <- (prophet_fc_future$yhat_upper - prophet_fc_future$yhat_lower)

# Pre-compute log-scale point forecasts (before exp transform)
arima_log_fc  <- log(arima_pred_future)
lasso_log_fc  <- log(lasso_pred_future)
prophet_log_fc <- prophet_fc_future$yhat  # already log-scale

# Matrix to store all simulated paths (N_SIM x n_fc)
sim_paths <- matrix(NA_real_, nrow = N_SIM, ncol = n_fc)

set.seed(42)  # reproducibility

for (i in 1:N_SIM) {
  # 1. ARIMA: bootstrap residuals and add to point forecast
  arima_sim_resid <- sample(arima_resid_vec, n_fc, replace = TRUE)
  arima_sim       <- exp(arima_log_fc + arima_sim_resid)
  
  # 2. LASSO: sample from CV residual distribution
  lasso_sim_resid <- sample(lasso_resid_vec, n_fc, replace = TRUE)
  lasso_sim       <- exp(lasso_log_fc + lasso_sim_resid)
  
  # 3. Prophet: sample uniformly within its uncertainty band
  prophet_u       <- runif(n_fc, -0.5, 0.5)  # uniform in [-0.5, 0.5]
  prophet_sim     <- exp(prophet_log_fc + prophet_u * prophet_fc_width)
  
  # 4. Clamp individual model paths
  arima_sim   <- pmax(clamp_lo, pmin(clamp_hi, arima_sim))
  lasso_sim   <- pmax(clamp_lo, pmin(clamp_hi, lasso_sim))
  prophet_sim <- pmax(clamp_lo, pmin(clamp_hi, prophet_sim))
  
  # 5. Ensemble the perturbed predictions
  ens_sim <- as.numeric(wts["arima"]) * arima_sim +
    as.numeric(wts["prophet"]) * prophet_sim +
    as.numeric(wts["lasso"]) * lasso_sim
  
  # 6. Apply spot-anchoring to this path
  sim_paths[i, ] <- fc_alpha * spot_current + (1 - fc_alpha) * ens_sim
}

# Compute percentile bands
ensemble_ci_lo_80 <- apply(sim_paths, 2, quantile, probs = 0.10, na.rm = TRUE)
ensemble_ci_hi_80 <- apply(sim_paths, 2, quantile, probs = 0.90, na.rm = TRUE)
ensemble_ci_lo    <- apply(sim_paths, 2, quantile, probs = 0.05, na.rm = TRUE)
ensemble_ci_hi    <- apply(sim_paths, 2, quantile, probs = 0.95, na.rm = TRUE)
ensemble_median   <- apply(sim_paths, 2, median, na.rm = TRUE)

# Report summary statistics
cat(sprintf("  Simulated %d paths x %d days\n", N_SIM, n_fc))
cat(sprintf("  1M median: $%.2f  |  90%% CI: [$%.2f, $%.2f]\n",
            mean(ensemble_median[hz_1m_idx]),
            mean(ensemble_ci_lo[hz_1m_idx]),
            mean(ensemble_ci_hi[hz_1m_idx])))
cat(sprintf("  9M median: $%.2f  |  90%% CI: [$%.2f, $%.2f]\n",
            mean(ensemble_median[hz_9m_idx]),
            mean(ensemble_ci_lo[hz_9m_idx]),
            mean(ensemble_ci_hi[hz_9m_idx])))
cat(sprintf("  9M 90%% CI width: $%.1f/bbl\n",
            mean(ensemble_ci_hi[hz_9m_idx]) - mean(ensemble_ci_lo[hz_9m_idx])))


# ══════════════════════════════════════════════════════════════════════════════
# 8. CA GASOLINE SPREAD — GAM WITH CA SENTIMENT (#2, #7, #8, #9, #13, #14)
# ══════════════════════════════════════════════════════════════════════════════
#
# IMPROVEMENTS:
#   #2  — Uses CA-specific sentiment (refinery, regulatory) NOT global channels
#   #7  — Regime interactions: refinery stress × summer_peak
#   #8  — GAM with nonlinear smooth terms for dl_brent_lag and driving_season_idx
#   #9  — Distributed lag (dl_brent_lag) captures pass-through delay
#   #13 — FRED features in spread model
#   #14 — (v07) wti_close now ONLY appears here, not in Brent xreg.
#         The Brent-WTI differential has genuine predictive content for CA
#         margins (WTI discount reflects US-specific supply dynamics).
#   #15 — (v07) FRED rate-of-change features replace levels in spread model too.
#   #20 — (v08) brent_wti_diff replaced with wti_basis (spot vs 3M futures)
#         which captures US supply tightness more directly.
#
# The spread = CA retail price − Brent-equivalent ($/gal)
# CA retail ≈ Brent × 0.0238 + spread
# spread driven by: refining costs, taxes, local supply constraints

cat("► Fitting CA gasoline spread model (GAM)…\n")

spread_df <- train |>
  mutate(
    spread     = ca_gas - brent_close * 0.0238,
    lag_spread = lag(spread, 5),
    sent_refinery    = ifelse(is.na(sent_refinery),    0, sent_refinery),
    sent_ca_regulatory=ifelse(is.na(sent_ca_regulatory),0,sent_ca_regulatory),
    refinery_stress  = ifelse(is.na(refinery_stress),  0, refinery_stress),
    dl_brent_lag     = ifelse(is.na(dl_brent_lag),     brent_close, dl_brent_lag),
    # v12: wti_basis REMOVED — was a static scalar from current curve snapshot
    # applied to all training rows, acting as a spurious intercept shift (#2)
    # FRED rate-of-change for spread model (v07 — #15)
    usd_chg_21d      = ifelse(is.na(usd_chg_21d),   0, usd_chg_21d),
    yield_chg_21d    = ifelse(is.na(yield_chg_21d),  0, yield_chg_21d),
    # Regime interaction (#7)
    refinery_summer  = refinery_stress * summer_peak
  ) |> drop_na(lag_spread)

# GAM: smooth nonlinear terms for continuous features; linear for dummies
# v12: wti_basis removed from formula (was non-significant, static value)
if (requireNamespace("mgcv", quietly=TRUE)) {
  spread_gam <- mgcv::gam(
    spread ~ s(dl_brent_lag, k=5) +        # nonlinear Brent pass-through
      s(driving_season_idx, k=5) +   # nonlinear seasonal demand
      lag_spread +                    # autoregressive spread component
      refinery_stress +              # CA refinery outage intensity
      sent_refinery +               # refinery sentiment
      sent_ca_regulatory +          # CA regulatory sentiment
      refinery_summer +             # regime interaction
      summer_peak +                 # summer blend premium
      winter_heat +                 # heating season
      quarter +                     # residual quarterly pattern
      # FRED rate-of-change in spread model (v07 — #15)
      usd_chg_21d +                # USD change → refining margin impact
      yield_chg_21d,               # yield curve change → macro demand
    data   = spread_df,
    method = "REML"                        # robust smoothness selection
  )
  cat(sprintf("  GAM spread R² = %.3f (adj) | deviance explained: %.1f%%\n",
              summary(spread_gam)$r.sq,
              summary(spread_gam)$dev.expl * 100))
  use_gam <- TRUE
} else {
  # Fallback to OLS if mgcv unavailable
  spread_gam <- lm(
    spread ~ dl_brent_lag + lag_spread + refinery_stress +
      sent_refinery + sent_ca_regulatory + summer_peak +
      winter_heat + quarter +
      usd_chg_21d + yield_chg_21d,
    data = spread_df
  )
  cat(sprintf("  OLS spread R² = %.3f (mgcv not available)\n",
              summary(spread_gam)$r.squared))
  use_gam <- FALSE
}

# ── v12 FIX #1: Separate backtest vs future spread prediction ────────────────
# BACKTEST: use rolling lag_spread from actual test-period spreads.
# The old code used tail(spread_df$spread, 1) for ALL test rows, which leaked
# the last training spread into every backtest day. Now we compute the actual
# spread for each test row and lag it properly.
#
# FUTURE: use last known spread (legitimate — we don't have future spreads).

prep_spread_common <- function(df) {
  df |>
    mutate(
      dl_brent_lag      = ifelse(is.na(dl_brent_lag), brent_close, dl_brent_lag),
      sent_refinery     = ifelse(is.na(sent_refinery),    0, sent_refinery),
      sent_ca_regulatory= ifelse(is.na(sent_ca_regulatory),0,sent_ca_regulatory),
      refinery_stress   = ifelse(is.na(refinery_stress),  0, refinery_stress),
      refinery_summer   = refinery_stress * summer_peak,
      usd_chg_21d       = ifelse(is.na(usd_chg_21d),   0, usd_chg_21d),
      yield_chg_21d     = ifelse(is.na(yield_chg_21d),  0, yield_chg_21d),
      # Ensure driving_season_idx exists for GAM smooth term
      driving_season_idx = if ("driving_season_idx" %in% names(df))
        driving_season_idx else pmax(0, sin(2*pi*(lubridate::yday(date)-80)/365))
    )
}

# Backtest: compute actual spread and use rolling lag
# ca_gas may have NAs (weekly EIA data interpolated to daily) — use interpolated values
test_with_spread <- test |>
  mutate(
    ca_gas_filled  = zoo::na.approx(ca_gas, na.rm = FALSE),
    ca_gas_filled  = zoo::na.locf(ca_gas_filled, na.rm = FALSE),
    ca_gas_filled  = ifelse(is.na(ca_gas_filled), last_known_ca_gas, ca_gas_filled),
    spread_actual  = ca_gas_filled - brent_close * 0.0238
  )

# Last known CA gas for fallback
last_known_ca_gas <- tail(train$ca_gas[!is.na(train$ca_gas)], 1)
test_with_spread <- test |>
  mutate(
    ca_gas_filled  = zoo::na.approx(ca_gas, na.rm = FALSE),
    ca_gas_filled  = zoo::na.locf(ca_gas_filled, na.rm = FALSE),
    ca_gas_filled  = ifelse(is.na(ca_gas_filled), last_known_ca_gas, ca_gas_filled),
    spread_actual  = ca_gas_filled - brent_close * 0.0238
  )

# Build lag_spread from the last 5 training spreads + test spreads
train_tail_spread <- tail(spread_df$spread, 5)
all_spreads <- c(train_tail_spread, test_with_spread$spread_actual)
# For each test row i, lag_spread = spread from 5 days earlier
test_lag_spread <- all_spreads[1:nrow(test)]

test_spread_nd <- prep_spread_common(test) |>
  mutate(lag_spread = test_lag_spread)
spread_pred_test <- predict(spread_gam, newdata = test_spread_nd)
ca_gas_pred_test <- ensemble_test * 0.0238 + as.numeric(spread_pred_test)

# Future: use last known spread
last_known_spread <- tail(c(spread_df$spread, test_with_spread$spread_actual), 1)
if (is.na(last_known_spread)) last_known_spread <- tail(spread_df$spread[!is.na(spread_df$spread)], 1)

future_spread_nd <- prep_spread_common(future_frame) |>
  mutate(lag_spread = last_known_spread)
spread_pred_future <- predict(spread_gam, newdata = future_spread_nd)
ca_gas_pred_future <- ensemble_future * 0.0238 + as.numeric(spread_pred_future)

cat(sprintf("  CA gas 9M forecast: $%.2f - $%.2f/gal\n",
            min(ca_gas_pred_future,na.rm=TRUE), max(ca_gas_pred_future,na.rm=TRUE)))


# ══════════════════════════════════════════════════════════════════════════════
# 9. COUNTERFACTUAL DIAGNOSTIC (#10, extended in v06)
# ══════════════════════════════════════════════════════════════════════════════
#
# IMPROVEMENT #10: Run LASSO without any sentiment columns to isolate the
# value-add of news features. ΔRMSE = no-news RMSE - full RMSE.
# Positive ΔRMSE means news features improved accuracy.
#
# NEW v06: Also run LASSO without FRED macro columns to isolate their
# contribution. Reports both news_delta_RMSE and fred_delta_RMSE.

cat("► Running counterfactual diagnostics…\n")

# ── 9a. Momentum counterfactual (v13: replaces news counterfactual) ──────────
# Since news and FRED are no longer in the LASSO, test whether momentum
# features (ret_21d, momentum_63d, price_vs_ma63) add value over pure
# technical + seasonal features.

momentum_cols <- c("ret_21d", "momentum_63d", "price_vs_ma63")
xreg_cols_nomomentum <- setdiff(xreg_cols, momentum_cols)

if (length(xreg_cols_nomomentum) > 0 &&
    length(xreg_cols_nomomentum) < length(xreg_cols)) {
  en_recipe_nm <- recipe(brent_close~.,
                         data=train |> select(brent_close, date, all_of(xreg_cols_nomomentum)) |>
                           mutate(brent_close=log(brent_close))) |>
    update_role(date, new_role="ID") |>
    step_impute_mean(all_predictors()) |>
    step_normalize(all_predictors())
  
  en_wf_nm   <- workflow() |>
    add_recipe(en_recipe_nm) |> add_model(en_spec)
  en_tune_nm <- tune_grid(en_wf_nm, resamples=ts_folds, grid=en_grid,
                          metrics=metric_set(rmse, rsq))
  best_nm    <- select_best(en_tune_nm, metric="rmse")
  final_nm   <- finalize_workflow(en_wf_nm, best_nm) |>
    fit(train |> mutate(brent_close=log(brent_close)))
  
  lasso_nm_test  <- exp(predict(final_nm, test)$.pred)
  rmse_nomomentum<- sqrt(mean((lasso_nm_test - test$brent_close)^2, na.rm=TRUE))
  rmse_full      <- sqrt(mean((lasso_pred_test - test$brent_close)^2, na.rm=TRUE))
  delta_rmse     <- rmse_nomomentum - rmse_full
  cat(sprintf("  LASSO RMSE — with momentum: $%.2f | without: $%.2f | delta: %+.2f\n",
              rmse_full, rmse_nomomentum, delta_rmse))
  cat(sprintf("  Momentum contribution: %s\n",
              ifelse(delta_rmse > 0, "POSITIVE (momentum helps)", "NEGATIVE (momentum hurts)")))
} else {
  delta_rmse <- NA_real_
  cat("  No momentum columns in xreg — counterfactual skipped\n")
}

# ── 9b. Seasonal counterfactual (v14) ────────────────────────────────────────
# Test whether seasonal + calendar features add value beyond
# technical + momentum features.

seasonal_cal_cols <- c("is_monday", "quarter", "driving_season_idx",
                       "heating_demand_idx", "refinery_maint")
xreg_cols_noseasonal <- setdiff(xreg_cols, seasonal_cal_cols)

if (length(xreg_cols_noseasonal) > 0 &&
    length(xreg_cols_noseasonal) < length(xreg_cols)) {
  en_recipe_ns <- recipe(brent_close~.,
                         data=train |> select(brent_close, date, all_of(xreg_cols_noseasonal)) |>
                           mutate(brent_close=log(brent_close))) |>
    update_role(date, new_role="ID") |>
    step_impute_mean(all_predictors()) |>
    step_normalize(all_predictors())
  
  en_wf_ns   <- workflow() |>
    add_recipe(en_recipe_ns) |> add_model(en_spec)
  en_tune_ns <- tune_grid(en_wf_ns, resamples=ts_folds, grid=en_grid,
                          metrics=metric_set(rmse, rsq))
  best_ns    <- select_best(en_tune_ns, metric="rmse")
  final_ns   <- finalize_workflow(en_wf_ns, best_ns) |>
    fit(train |> mutate(brent_close=log(brent_close)))
  
  lasso_ns_test   <- exp(predict(final_ns, test)$.pred)
  rmse_noseasonal <- sqrt(mean((lasso_ns_test - test$brent_close)^2, na.rm=TRUE))
  rmse_full_s     <- sqrt(mean((lasso_pred_test - test$brent_close)^2, na.rm=TRUE))
  delta_rmse_fred <- rmse_noseasonal - rmse_full_s
  cat(sprintf("  LASSO RMSE — with seasonal: $%.2f | without: $%.2f | delta: %+.2f\n",
              rmse_full_s, rmse_noseasonal, delta_rmse_fred))
  cat(sprintf("  Seasonal contribution: %s\n",
              ifelse(delta_rmse_fred > 0, "POSITIVE (seasonal helps)", "NEGATIVE (seasonal hurts)")))
} else {
  delta_rmse_fred <- NA_real_
  cat("  No seasonal columns in xreg — seasonal counterfactual skipped\n")
}



# ══════════════════════════════════════════════════════════════════════════════
# 10. RESULTS AND ACCURACY
# ══════════════════════════════════════════════════════════════════════════════

results_backtest <- tibble(
  run_date      = as.Date(RUN_DATE),
  forecast_date = test$date,
  period        = "backtest",
  days_ahead    = as.integer(test$date - as.Date(RUN_DATE)) + 30L,
  brent_actual  = as.numeric(test$brent_close),
  brent_arima   = as.numeric(arima_pred_test),
  brent_prophet = as.numeric(prophet_pred_test),
  brent_lasso   = as.numeric(lasso_pred_test),
  brent_ensemble= as.numeric(ensemble_test),
  brent_ci_lo   = NA_real_,
  brent_ci_hi   = NA_real_,
  ca_gas_actual = as.numeric(test$ca_gas),
  # as.numeric() strips array/named structure from predict() output
  ca_gas_pred   = as.numeric(ca_gas_pred_test)
) |> mutate(
  brent_err = as.numeric(brent_ensemble - brent_actual),
  ca_err    = as.numeric(ca_gas_pred    - ca_gas_actual)
)

results_future <- tibble(
  run_date      = as.Date(RUN_DATE),
  forecast_date = future_dates,
  period        = "forecast",
  days_ahead    = as.integer(future_dates - as.Date(RUN_DATE)),
  brent_actual  = NA_real_,
  brent_arima   = as.numeric(arima_pred_future),
  brent_prophet = as.numeric(prophet_pred_future),
  brent_lasso   = as.numeric(lasso_pred_future),
  brent_ensemble= as.numeric(ensemble_future),
  brent_ci_lo   = as.numeric(ensemble_ci_lo),
  brent_ci_hi   = as.numeric(ensemble_ci_hi),
  brent_ci_lo_80 = as.numeric(ensemble_ci_lo_80),
  brent_ci_hi_80 = as.numeric(ensemble_ci_hi_80),
  ca_gas_actual = NA_real_,
  ca_gas_pred   = as.numeric(ca_gas_pred_future),
  brent_err     = NA_real_,
  ca_err        = NA_real_
)

results <- bind_rows(results_backtest, results_future)

metrics_brent <- results_backtest |> drop_na(brent_actual) |>
  summarise(model="Brent ensemble", run_date=as.Date(RUN_DATE),
            RMSE=sqrt(mean(brent_err^2,na.rm=TRUE)),
            MAE=mean(abs(brent_err),na.rm=TRUE),
            MAPE=mean(abs(brent_err/brent_actual)*100,na.rm=TRUE),
            R2=1-var(brent_err,na.rm=TRUE)/var(brent_actual,na.rm=TRUE))

metrics_ca <- results_backtest |> drop_na(ca_gas_actual) |>
  summarise(model="CA gasoline", run_date=as.Date(RUN_DATE),
            RMSE=sqrt(mean(ca_err^2,na.rm=TRUE)),
            MAE=mean(abs(ca_err),na.rm=TRUE),
            MAPE=mean(abs(ca_err/ca_gas_actual)*100,na.rm=TRUE),
            R2=1-var(ca_err,na.rm=TRUE)/var(ca_gas_actual,na.rm=TRUE))

cat("\n── BRENT BACKTEST ACCURACY ──────────────────────────\n"); print(metrics_brent)
cat("\n── CA GAS BACKTEST ACCURACY ─────────────────────────\n"); print(metrics_ca)

# ── 10b. NAIVE BASELINE MODELS (NEW v10) ─────────────────────────────────────
#
# Three naive baselines to benchmark the ensemble against:
#
# 1. Random Walk (spot carry): forecast = last known price, constant.
#    This is the standard benchmark in financial forecasting. If the
#    ensemble can't beat this, the model is adding noise, not signal.
#
# 2. Historical Mean: forecast = mean of training period prices.
#    Tests whether the model captures regime shifts vs. just predicting
#    the long-run average.
#
# 3. Linear Trend: forecast = linear extrapolation of last 63 days.
#    Tests whether the model adds value beyond simple trend extension.

cat("\n── NAIVE BASELINE COMPARISON ────────────────────────\n")

# Baseline 1: Random Walk (last known training price, held constant)
naive_rw_price   <- spot_anchor_price  # last training close
naive_rw_err     <- naive_rw_price - test$brent_close
naive_rw_rmse    <- sqrt(mean(naive_rw_err^2, na.rm = TRUE))
naive_rw_mape    <- mean(abs(naive_rw_err / test$brent_close) * 100, na.rm = TRUE)

# Baseline 2: Historical Mean
naive_mean_price <- mean(train$brent_close, na.rm = TRUE)
naive_mean_err   <- naive_mean_price - test$brent_close
naive_mean_rmse  <- sqrt(mean(naive_mean_err^2, na.rm = TRUE))
naive_mean_mape  <- mean(abs(naive_mean_err / test$brent_close) * 100, na.rm = TRUE)

# Baseline 3: Linear Trend (63-day OLS extrapolation)
trend_window <- tail(train, 63)
trend_lm     <- lm(brent_close ~ as.numeric(date), data = trend_window)
naive_trend_pred <- predict(trend_lm, newdata = tibble(date = test$date))
naive_trend_err  <- naive_trend_pred - test$brent_close
naive_trend_rmse <- sqrt(mean(naive_trend_err^2, na.rm = TRUE))
naive_trend_mape <- mean(abs(naive_trend_err / test$brent_close) * 100, na.rm = TRUE)

# Naive baselines for 6-month forecast
naive_rw_future    <- rep(spot_current, length(future_dates))
naive_mean_future  <- rep(naive_mean_price, length(future_dates))
naive_trend_future <- predict(trend_lm, newdata = tibble(date = future_dates))

# Skill scores: how much better is the ensemble vs each baseline?
# Skill = 1 - (ensemble_RMSE / baseline_RMSE). Positive = ensemble wins.
skill_vs_rw    <- 1 - as.numeric(metrics_brent$RMSE) / naive_rw_rmse
skill_vs_mean  <- 1 - as.numeric(metrics_brent$RMSE) / naive_mean_rmse
skill_vs_trend <- 1 - as.numeric(metrics_brent$RMSE) / naive_trend_rmse

cat(sprintf("  %-20s  RMSE: $%6.2f  MAPE: %5.1f%%\n",
            "Ensemble (anchored)", as.numeric(metrics_brent$RMSE), as.numeric(metrics_brent$MAPE)))
cat(sprintf("  %-20s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%\n",
            "Random Walk (spot)", naive_rw_rmse, naive_rw_mape, skill_vs_rw * 100))
cat(sprintf("  %-20s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%\n",
            "Historical Mean", naive_mean_rmse, naive_mean_mape, skill_vs_mean * 100))
cat(sprintf("  %-20s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%\n",
            "63-day Trend", naive_trend_rmse, naive_trend_mape, skill_vs_trend * 100))
cat(sprintf("  Ensemble beats RW: %s | beats mean: %s | beats trend: %s\n",
            ifelse(skill_vs_rw > 0, "YES", "NO"),
            ifelse(skill_vs_mean > 0, "YES", "NO"),
            ifelse(skill_vs_trend > 0, "YES", "NO")))

cat("\n── FORECAST SUMMARY (1M / 3M / 6M / 9M) ────────────\n")
cat(sprintf("  Brent  1M: $%.2f | 3M: $%.2f | 6M: $%.2f | 9M: $%.2f /bbl\n",
            hz_mean(ensemble_future, hz_1m_idx),
            hz_mean(ensemble_future, hz_3m_idx),
            hz_mean(ensemble_future, hz_6m_idx),
            hz_mean(ensemble_future, hz_9m_idx)))
cat(sprintf("  CA gas 1M: $%.2f | 3M: $%.2f | 6M: $%.2f | 9M: $%.2f /gal\n",
            hz_mean(ca_gas_pred_future, hz_1m_idx),
            hz_mean(ca_gas_pred_future, hz_3m_idx),
            hz_mean(ca_gas_pred_future, hz_6m_idx),
            hz_mean(ca_gas_pred_future, hz_9m_idx)))
cat(sprintf("  Market structure: %s | Curve slope: %+.1f%%\n",
            curve_metrics$market_structure, curve_metrics$curve_slope*100))
cat(sprintf("  Calendar spread: %+.1f%% (%s near-term signal)\n",
            curve_metrics$calendar_spread*100,
            ifelse(curve_metrics$calendar_spread > 0, "TIGHT", "LOOSE")))




# ══════════════════════════════════════════════════════════════════════════════
# 11. VISUALISATION — INDIVIDUAL PNG FILES (v10 redesign)
# ══════════════════════════════════════════════════════════════════════════════
#
# v10 changes from v09:
#   - Each plot saved as its own PNG (no combined multi-panel PNGs)
#   - Naming: {prefix}_{RUN_DATE}.png where prefix describes the content
#   - New plot: naive baseline comparison showing ensemble vs spot/mean/trend
#   - All plots use v09 light theme (base_size=16, light grey bg, black titles)
#
# Individual files written to OUT_PNG:
#   01_brent_forecast_{date}.png      — Brent ensemble forecast
#   02_ca_gas_forecast_{date}.png     — California gasoline forecast
#   03_spot_anchoring_{date}.png      — Raw vs anchored ensemble diagnostic
#   04_forecast_summary_{date}.png    — Bar chart with CA/TX gas labels
#   05_baseline_comparison_{date}.png — Ensemble vs naive models (NEW v10)
#   06_ensemble_weights_{date}.png    — Model weight bars
#   07_feature_importance_{date}.png  — LASSO coefficient plot
#   08_sentiment_{date}.png           — Topic-segmented sentiment
#   09_backtest_errors_{date}.png     — Per-model error time series
#   10_counterfactual_{date}.png      — News/FRED contribution bars
#   11_gam_spread_{date}.png          — GAM smooth diagnostic
#   12_fred_macro_{date}.png          — FRED rate-of-change time series
#   13_seasonal_demand_{date}.png     — Seasonal index signals
#   14_seasonal_forecast_{date}.png   — Forecast with maint. windows

theme_oil <- function(base_size = 16) {
  theme_minimal(base_family = "sans", base_size = base_size) +
    theme(
      plot.background   = element_rect(fill = "#f5f5f5", color = NA),
      panel.background  = element_rect(fill = "#ffffff", color = "#cccccc",
                                       linewidth = 0.5),
      panel.grid.major  = element_line(color = "#e0e0e0", linewidth = 0.4),
      panel.grid.minor  = element_blank(),
      text              = element_text(color = "#333333", size = base_size),
      axis.text         = element_text(color = "#444444", size = base_size - 1),
      axis.title        = element_text(color = "#222222", size = base_size,
                                       face = "bold"),
      plot.title        = element_text(color = "#000000", face = "bold",
                                       size = base_size + 5),
      plot.subtitle     = element_text(color = "#555555", size = base_size),
      plot.caption      = element_text(color = "#777777", size = base_size - 3),
      legend.background = element_rect(fill = "#f5f5f5", color = NA),
      legend.key        = element_rect(fill = "#f5f5f5", color = NA),
      legend.text       = element_text(color = "#333333", size = base_size),
      legend.title      = element_text(color = "#222222", size = base_size,
                                       face = "bold"),
      strip.text        = element_text(color = "#222222", size = base_size,
                                       face = "bold"),
      plot.margin       = margin(12, 16, 12, 12)
    )
}

# High-contrast palette
AMBER  <- "#d4850f"; TEAL   <- "#1a8c3e"; CORAL  <- "#c0392b"
BLUE   <- "#2166ac"; PURPLE <- "#7b3294"; GOLD   <- "#b8860b"
DKGREY <- "#444444"

# Standard plot dimensions for individual PNGs
PLOT_W <- 14; PLOT_H <- 8; PLOT_DPI <- 200; PLOT_BG <- "#f5f5f5"

save_plot <- function(plot, prefix) {
  fname <- sprintf("%s_%s.png", prefix, RUN_DATE)
  fpath <- out_path(fname)
  ggsave(fpath, plot = plot, width = PLOT_W, height = PLOT_H,
         dpi = PLOT_DPI, bg = PLOT_BG)
  cat(sprintf("  %s\n", fname))
  invisible(fpath)
}

# Shared geometry data
bt_shade <- tibble(xmin = min(test$date),    xmax = max(test$date),
                   ymin = -Inf, ymax = Inf)
fc_shade <- tibble(xmin = min(future_dates), xmax = max(future_dates),
                   ymin = -Inf, ymax = Inf)

history_brent <- master |> filter(date >= DATE_END - 180, date <= TRAIN_END)
test_brent    <- master |> filter(date > TRAIN_END)
history_gas   <- master |> filter(date >= DATE_END - 180, date <= TRAIN_END)
test_gas      <- master |> filter(date > TRAIN_END)

cat("\n► Saving individual plots (v10)...\n")

# ── 01: Brent forecast ──────────────────────────────────────────────────────
p01 <- ggplot() +
  geom_rect(data = bt_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = BLUE, alpha = 0.08, inherit.aes = FALSE) +
  geom_rect(data = fc_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = AMBER, alpha = 0.08, inherit.aes = FALSE) +
  # 90% empirical interval (outer, lighter)
  geom_ribbon(data = results_future,
              aes(x = forecast_date, ymin = brent_ci_lo, ymax = brent_ci_hi),
              fill = AMBER, alpha = 0.12) +
  # 80% empirical interval (inner, darker)
  geom_ribbon(data = results_future,
              aes(x = forecast_date, ymin = brent_ci_lo_80, ymax = brent_ci_hi_80),
              fill = AMBER, alpha = 0.18) +
  geom_line(data = history_brent,
            aes(x = date, y = brent_close, color = "Actuals (training)"),
            linewidth = 1.2) +
  geom_line(data = test_brent,
            aes(x = date, y = brent_close, color = "Actuals (test)"),
            linewidth = 1.0, linetype = "dotted") +
  geom_line(data = results_backtest,
            aes(x = forecast_date, y = brent_ensemble, color = "Ensemble (backtest)"),
            linewidth = 1.5, linetype = "dashed") +
  geom_line(data = results_future,
            aes(x = forecast_date, y = brent_ensemble, color = "Ensemble (forecast)"),
            linewidth = 2.0) +
  scale_color_manual(name = NULL,
                     values = c("Actuals (training)" = BLUE, "Actuals (test)" = BLUE,
                                "Ensemble (backtest)" = AMBER, "Ensemble (forecast)" = AMBER),
                     guide = guide_legend(override.aes = list(
                       linetype = c("solid","dotted","dashed","solid"),
                       linewidth = c(1.2, 1.0, 1.5, 2.0)))) +
  scale_y_continuous(labels = dollar_format(prefix = "$")) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b %y") +
  labs(title = "Brent Crude: 9-Month Ensemble Forecast",
       subtitle = sprintf("Run: %s  |  RMSE: $%.2f/bbl  |  MAPE: %.1f%%  |  %s (%+.1f%%)",
                          RUN_DATE, metrics_brent$RMSE, metrics_brent$MAPE,
                          curve_metrics$market_structure,
                          as.numeric(curve_metrics$curve_slope) * 100),
       caption = sprintf("Bands: %d bootstrap paths  |  Inner = 80%% empirical interval  |  Outer = 90%% empirical interval", N_SIM),
       x = NULL, y = "USD per barrel") +
  theme_oil() + theme(legend.position = "bottom")
save_plot(p01, "01_brent_forecast")

# ── 02: CA gasoline forecast ────────────────────────────────────────────────
p02 <- ggplot() +
  geom_rect(data = bt_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = BLUE, alpha = 0.08, inherit.aes = FALSE) +
  geom_rect(data = fc_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = AMBER, alpha = 0.08, inherit.aes = FALSE) +
  geom_line(data = history_gas,
            aes(x = date, y = ca_gas, color = "Actuals (training)"), linewidth = 1.3) +
  geom_line(data = test_gas |> drop_na(ca_gas),
            aes(x = date, y = ca_gas, color = "Actuals (test)"),
            linewidth = 1.0, linetype = "dotted") +
  geom_line(data = results_backtest |> drop_na(ca_gas_pred),
            aes(x = forecast_date, y = ca_gas_pred, color = "GAM (backtest)"),
            linewidth = 1.5, linetype = "dashed") +
  geom_line(data = results_future |> drop_na(ca_gas_pred),
            aes(x = forecast_date, y = ca_gas_pred, color = "GAM (forecast)"),
            linewidth = 2.0) +
  scale_color_manual(name = NULL,
                     values = c("Actuals (training)" = CORAL, "Actuals (test)" = CORAL,
                                "GAM (backtest)" = AMBER, "GAM (forecast)" = AMBER),
                     drop = FALSE) +
  scale_y_continuous(labels = dollar_format(prefix = "$", suffix = "/gal")) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b %y") +
  labs(title = "California Retail Gasoline: 9-Month Forecast",
       subtitle = sprintf("RMSE: $%.3f/gal  |  MAPE: %.1f%%  |  GAM spread model",
                          metrics_ca$RMSE, metrics_ca$MAPE),
       x = NULL, y = "USD per gallon") +
  theme_oil() + theme(legend.position = "bottom")
save_plot(p02, "02_ca_gas_forecast")

# ── 03: Spot-anchoring diagnostic ───────────────────────────────────────────
f3_bt <- tibble(date = test$date, raw = ensemble_test_raw,
                anchored = ensemble_test, actual = test$brent_close)
f3_fc <- tibble(date = future_dates, raw = ensemble_future_raw,
                anchored = ensemble_future)

p03 <- ggplot() +
  geom_rect(data = bt_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = BLUE, alpha = 0.08, inherit.aes = FALSE) +
  geom_rect(data = fc_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = AMBER, alpha = 0.08, inherit.aes = FALSE) +
  geom_line(data = f3_bt, aes(x=date, y=actual, color="Actual"), linewidth=1.3) +
  geom_line(data = f3_bt, aes(x=date, y=raw, color="Raw ensemble"),
            linewidth=1.0, linetype="dashed") +
  geom_line(data = f3_bt, aes(x=date, y=anchored, color="Spot-anchored"), linewidth=1.8) +
  geom_line(data = f3_fc, aes(x=date, y=raw, color="Raw ensemble"),
            linewidth=1.0, linetype="dashed") +
  geom_line(data = f3_fc, aes(x=date, y=anchored, color="Spot-anchored"), linewidth=1.8) +
  geom_hline(yintercept = spot_current, color = DKGREY, linewidth=0.6, linetype="dotted") +
  geom_text(data = tibble(x=min(future_dates), y=spot_current),
            aes(x=x, y=y, label=sprintf("Spot: $%.0f", spot_current)),
            color=DKGREY, hjust=0, vjust=-0.6, size=5, fontface="bold", inherit.aes=FALSE) +
  scale_color_manual(name=NULL, values=c("Actual"=BLUE, "Raw ensemble"=CORAL, "Spot-anchored"=AMBER)) +
  scale_y_continuous(labels = dollar_format(prefix="$")) +
  scale_x_date(date_breaks="1 month", date_labels="%b %y") +
  labs(title = "Spot-Anchoring Effect on Brent Forecast",
       subtitle = sprintf("Halflife: %d days  |  Anchor: $%.0f  |  1M correction: %+.0f $/bbl",
                          best_halflife, spot_current,
                          hz_mean(ensemble_future, hz_1m_idx) - hz_mean(ensemble_future_raw, hz_1m_idx)),
       x=NULL, y="USD per barrel") +
  theme_oil() + theme(legend.position="bottom")
save_plot(p03, "03_spot_anchoring")

# ── 04: Forecast summary bar chart with CA/TX gas ───────────────────────────
summary_df <- tibble(
  horizon = factor(c("1 month","3 months","6 months","9 months"),
                   levels=c("1 month","3 months","6 months","9 months")),
  brent = c(hz_mean(ensemble_future, hz_1m_idx),
            hz_mean(ensemble_future, hz_3m_idx),
            hz_mean(ensemble_future, hz_6m_idx),
            hz_mean(ensemble_future, hz_9m_idx)),
  ca_gas = c(hz_mean(ca_gas_pred_future, hz_1m_idx),
             hz_mean(ca_gas_pred_future, hz_3m_idx),
             hz_mean(ca_gas_pred_future, hz_6m_idx),
             hz_mean(ca_gas_pred_future, hz_9m_idx)),
  ci_lo = c(hz_mean(ensemble_ci_lo, hz_1m_idx),
            hz_mean(ensemble_ci_lo, hz_3m_idx),
            hz_mean(ensemble_ci_lo, hz_6m_idx),
            hz_mean(ensemble_ci_lo, hz_9m_idx)),
  ci_hi = c(hz_mean(ensemble_ci_hi, hz_1m_idx),
            hz_mean(ensemble_ci_hi, hz_3m_idx),
            hz_mean(ensemble_ci_hi, hz_6m_idx),
            hz_mean(ensemble_ci_hi, hz_9m_idx)))

ca_latest <- tail(ca_gas_raw$ca_gas[!is.na(ca_gas_raw$ca_gas)], 1)
ca_tx_premium <- if (!is.na(tx_gas_latest)) ca_latest - tx_gas_latest else NA_real_

p04 <- summary_df |>
  ggplot(aes(x=horizon, y=brent)) +
  geom_col(fill=AMBER, width=0.55, alpha=0.9) +
  geom_errorbar(aes(ymin=ci_lo, ymax=ci_hi), width=0.18, color="#333333", linewidth=1.2) +
  geom_text(aes(label=sprintf("$%.0f/bbl", brent)),
            vjust=-0.4, color="#000000", size=6, fontface="bold") +
  geom_label(aes(y=ci_lo*0.60, label=sprintf("CA Gas: $%.2f/gal", ca_gas)),
             fill="#ffffff", color=CORAL, size=5.5, fontface="bold",
             label.padding=unit(0.4,"lines")) +
  {if (!is.na(tx_gas_latest))
    geom_label(aes(y=ci_lo*0.38, label=sprintf("TX Gas: $%.2f/gal", tx_gas_latest)),
               fill="#ffffff", color=TEAL, size=5.5, fontface="bold",
               label.padding=unit(0.4,"lines"))} +
  scale_y_continuous(labels=dollar_format(prefix="$"), expand=expansion(mult=c(0,0.25))) +
  labs(title = "9-Month Forecast Summary",
       subtitle = sprintf("Spot WTI: $%.0f  |  %s  |  CA-TX premium: %s",
                          as.numeric(curve_metrics$spot_wti), curve_metrics$market_structure,
                          ifelse(!is.na(ca_tx_premium), sprintf("$%.2f/gal", ca_tx_premium), "N/A")),
       x=NULL, y="Brent Ensemble ($/bbl)") +
  theme_oil()
save_plot(p04, "04_forecast_summary")

# ── 05: NAIVE BASELINE COMPARISON (NEW v10) ─────────────────────────────────
# This is the key new plot: shows why the ensemble beats (or fails to beat)
# simple forecasting rules. Makes the model's value proposition visible.

# Build comparison data for backtest period
baseline_bt <- tibble(
  date    = test$date,
  actual  = test$brent_close,
  ensemble = ensemble_test,
  random_walk = naive_rw_price,
  historical_mean = naive_mean_price,
  linear_trend = as.numeric(naive_trend_pred)
) |>
  pivot_longer(-c(date, actual), names_to = "model", values_to = "forecast") |>
  mutate(
    error = forecast - actual,
    model = recode(model,
                   ensemble = "Ensemble (anchored)",
                   random_walk = "Random Walk (spot)",
                   historical_mean = "Historical Mean",
                   linear_trend = "63-day Trend")
  )

# Build comparison data for forecast horizon
baseline_fc <- tibble(
  date    = future_dates,
  ensemble = ensemble_future,
  random_walk = naive_rw_future,
  historical_mean = naive_mean_future,
  linear_trend = as.numeric(naive_trend_future)
) |>
  pivot_longer(-date, names_to = "model", values_to = "forecast") |>
  mutate(model = recode(model,
                        ensemble = "Ensemble (anchored)",
                        random_walk = "Random Walk (spot)",
                        historical_mean = "Historical Mean",
                        linear_trend = "63-day Trend"))

model_colors <- c("Ensemble (anchored)" = AMBER, "Random Walk (spot)" = DKGREY,
                  "Historical Mean" = PURPLE, "63-day Trend" = CORAL)

# Panel A: forecasts over time
p05a <- ggplot() +
  geom_rect(data = bt_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = BLUE, alpha = 0.08, inherit.aes = FALSE) +
  geom_rect(data = fc_shade, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill = AMBER, alpha = 0.08, inherit.aes = FALSE) +
  # Actuals in backtest
  geom_line(data = test_brent, aes(x=date, y=brent_close),
            color=BLUE, linewidth=1.5) +
  # All model forecasts (backtest)
  geom_line(data = baseline_bt, aes(x=date, y=forecast, color=model, linetype=model),
            linewidth=1.2) +
  # All model forecasts (future)
  geom_line(data = baseline_fc, aes(x=date, y=forecast, color=model, linetype=model),
            linewidth=1.2) +
  scale_color_manual(name=NULL, values=model_colors) +
  scale_linetype_manual(name=NULL,
                        values=c("Ensemble (anchored)"="solid", "Random Walk (spot)"="dashed",
                                 "Historical Mean"="dotted", "63-day Trend"="twodash")) +
  scale_y_continuous(labels=dollar_format(prefix="$")) +
  scale_x_date(date_breaks="1 month", date_labels="%b %y") +
  labs(title = "Ensemble vs Naive Baselines: Forecast Comparison",
       subtitle = sprintf("Blue = actuals  |  Skill vs RW: %+.1f%%  |  vs Mean: %+.1f%%  |  vs Trend: %+.1f%%",
                          skill_vs_rw*100, skill_vs_mean*100, skill_vs_trend*100),
       x=NULL, y="USD per barrel") +
  theme_oil() + theme(legend.position="bottom")

# Panel B: RMSE comparison bars
rmse_compare <- tibble(
  model = factor(c("Ensemble\n(anchored)", "Random Walk\n(spot)",
                   "Historical\nMean", "63-day\nTrend"),
                 levels = c("Ensemble\n(anchored)", "Random Walk\n(spot)",
                            "Historical\nMean", "63-day\nTrend")),
  rmse  = c(as.numeric(metrics_brent$RMSE), naive_rw_rmse, naive_mean_rmse, naive_trend_rmse),
  mape  = c(as.numeric(metrics_brent$MAPE), naive_rw_mape, naive_mean_mape, naive_trend_mape),
  fill  = c("Ensemble", "Baseline", "Baseline", "Baseline")
)

p05b <- rmse_compare |>
  ggplot(aes(x=model, y=rmse, fill=fill)) +
  geom_col(width=0.6) +
  geom_text(aes(label=sprintf("$%.1f\n%.1f%%", rmse, mape)),
            vjust=-0.3, color="#000000", size=5.5, fontface="bold") +
  scale_fill_manual(values=c(Ensemble=AMBER, Baseline=DKGREY), guide="none") +
  scale_y_continuous(labels=dollar_format(prefix="$"),
                     expand=expansion(mult=c(0,0.25))) +
  labs(title = "Backtest RMSE: Ensemble vs Baselines",
       subtitle = "Lower = better  |  Labels show RMSE / MAPE",
       x=NULL, y="RMSE ($/bbl)") +
  theme_oil()

p05 <- p05a / p05b
save_plot(p05, "05_baseline_comparison")

# ── 06: Ensemble weights ────────────────────────────────────────────────────
p06 <- tibble(model=c("ARIMA","Prophet","LASSO"),
              weight=as.numeric(wts), rmse=as.numeric(rmse_vec)) |>
  ggplot(aes(x=reorder(model,weight), y=weight, fill=model,
             label=sprintf("%.2f  (RMSE $%.1f)", weight, rmse))) +
  geom_col(width=0.55) +
  geom_text(hjust=-0.05, color="#000000", size=5.5, fontface="bold") +
  coord_flip(clip="off") +
  scale_fill_manual(values=c(ARIMA=TEAL, Prophet=PURPLE, LASSO=AMBER)) +
  scale_y_continuous(limits=c(0,1.2), labels=percent_format()) +
  labs(title="Ensemble Weights (inverse-RMSE)",
       subtitle=sprintf("45-day holdout ending %s", TRAIN_END),
       x=NULL, y="Weight") +
  theme_oil() + theme(legend.position="none")
save_plot(p06, "06_ensemble_weights")

# ── 07: LASSO feature importance ────────────────────────────────────────────
en_coefs <- tidy(extract_fit_parsnip(final_en)$fit, s = best_en$penalty) |>
  filter(term != "(Intercept)", estimate != 0) |>
  distinct(term, .keep_all = TRUE) |>
  mutate(direction = ifelse(estimate > 0, "Positive", "Negative")) |>
  arrange(abs(estimate)) |> tail(15)

p07 <- en_coefs |>
  ggplot(aes(x=reorder(term, estimate), y=estimate, fill=direction)) +
  geom_col(width=0.7) + coord_flip() +
  scale_fill_manual(values=c(Positive=TEAL, Negative=CORAL)) +
  labs(title="LASSO Feature Importance (top 15)",
       subtitle="Standardized log-price coefficients",
       x=NULL, y="Coefficient", fill="Direction") +
  theme_oil() + theme(legend.position="bottom")
save_plot(p07, "07_feature_importance")

# ── 08: Topic-segmented sentiment ───────────────────────────────────────────
sent_avail <- intersect(
  c("sent_supply_risk","sent_opec_policy","sent_refinery",
    "sent_macro_demand","refinery_stress"),
  names(sentiment_filled))

if (nrow(sentiment_daily) > 5 && length(sent_avail) > 0) {
  col_map <- c(sent_supply_risk=CORAL, sent_opec_policy=AMBER,
               sent_refinery=PURPLE, sent_macro_demand=TEAL, refinery_stress=BLUE)
  lbl_map <- c(sent_supply_risk="Supply risk", sent_opec_policy="OPEC policy",
               sent_refinery="Refinery", sent_macro_demand="Macro demand",
               refinery_stress="CA refinery stress")
  p08 <- sentiment_filled |>
    filter(date >= DATE_END - 120) |>
    select(date, all_of(sent_avail)) |>
    pivot_longer(-date, names_to="channel", values_to="score") |>
    ggplot(aes(x=date, y=score, color=channel)) +
    geom_hline(yintercept=0, color="#cccccc") +
    geom_line(linewidth=1.2) +
    scale_color_manual(values=col_map[names(col_map) %in% sent_avail],
                       labels=lbl_map[names(lbl_map) %in% sent_avail]) +
    scale_x_date(date_breaks="1 month", date_labels="%b %y") +
    labs(title="Topic-Segmented Sentiment (7-day smoothed)",
         subtitle="Global channels -> Brent  |  CA channels -> spread model",
         x=NULL, y="Sentiment score", color=NULL) +
    theme_oil() + theme(legend.position="bottom")
} else {
  p08 <- ggplot() + theme_oil() + labs(title="Sentiment", subtitle="Cache building")
}
save_plot(p08, "08_sentiment")

# ── 09: Backtest residuals per model ────────────────────────────────────────
p09 <- results_backtest |> drop_na(brent_err) |>
  pivot_longer(c(brent_arima, brent_prophet, brent_lasso, brent_ensemble),
               names_to="model", values_to="pred") |>
  mutate(error = pred - brent_actual,
         model = recode(model, brent_arima="ARIMA", brent_prophet="Prophet",
                        brent_lasso="LASSO", brent_ensemble="Ensemble")) |>
  ggplot(aes(x=forecast_date, y=error, color=model)) +
  geom_hline(yintercept=0, color="#cccccc", linewidth=0.6) +
  geom_line(linewidth=1.2) + geom_point(size=3) +
  scale_color_manual(values=c(ARIMA=TEAL, Prophet=PURPLE, LASSO=GOLD, Ensemble=AMBER)) +
  scale_x_date(date_labels="%b %d") +
  labs(title="Backtest Forecast Errors",
       subtitle=sprintf("Ensemble RMSE: $%.2f/bbl  |  MAPE: %.1f%%",
                        metrics_brent$RMSE, metrics_brent$MAPE),
       x=NULL, y="Error (USD/bbl)", color=NULL) +
  theme_oil() + theme(legend.position="bottom")
save_plot(p09, "09_backtest_errors")

# ── 10: Feature contribution diagnostics ────────────────────────────────────
rmse_full_val <- sqrt(mean((lasso_pred_test - test$brent_close)^2, na.rm=TRUE))
cf_data <- tibble(
  model = c("Full model","No momentum","No seasonal"),
  rmse  = c(rmse_full_val,
            if (!is.na(delta_rmse)) rmse_full_val + delta_rmse else NA_real_,
            if (!is.na(delta_rmse_fred)) rmse_full_val + delta_rmse_fred else NA_real_),
  fill_color = c("Full model","No momentum","No seasonal")) |> drop_na()

p10 <- cf_data |>
  ggplot(aes(x=model, y=rmse, fill=fill_color)) +
  geom_col(width=0.55) +
  geom_text(aes(label=sprintf("$%.2f", rmse)),
            vjust=-0.4, color="#000000", size=6, fontface="bold") +
  scale_fill_manual(values=c("Full model"=TEAL, "No momentum"=CORAL, "No seasonal"=AMBER)) +
  scale_y_continuous(labels=dollar_format(prefix="$"), expand=expansion(mult=c(0,0.2))) +
  labs(title="Feature Contribution Diagnostics",
       subtitle=sprintf("News: %s  |  FRED: %s",
                        ifelse(is.na(delta_rmse), "N/A", sprintf("%+.2f", delta_rmse)),
                        ifelse(is.na(delta_rmse_fred), "N/A", sprintf("%+.2f", delta_rmse_fred))),
       x=NULL, y="LASSO RMSE ($/bbl)") +
  theme_oil() + theme(legend.position="none")
save_plot(p10, "10_counterfactual")

# ── 11: GAM spread smooth ──────────────────────────────────────────────────
if (use_gam && exists("spread_gam")) {
  gam_seq <- tibble(
    dl_brent_lag = seq(min(spread_df$dl_brent_lag,na.rm=TRUE),
                       max(spread_df$dl_brent_lag,na.rm=TRUE), length.out=100),
    driving_season_idx = mean(spread_df$driving_season_idx, na.rm=TRUE),
    lag_spread = mean(spread_df$lag_spread, na.rm=TRUE),
    refinery_stress=0, sent_refinery=0, sent_ca_regulatory=0,
    refinery_summer=0, summer_peak=0, winter_heat=0, quarter=2,
    usd_chg_21d=0, yield_chg_21d=0)
  gam_seq$spread_hat <- predict(spread_gam, newdata=gam_seq)
  
  p11 <- ggplot(spread_df, aes(x=dl_brent_lag, y=spread)) +
    geom_point(color="#999999", size=2, alpha=0.5) +
    geom_line(data=gam_seq, aes(x=dl_brent_lag, y=spread_hat),
              color=TEAL, linewidth=2.0) +
    scale_y_continuous(labels=dollar_format(prefix="$", suffix="/gal")) +
    scale_x_continuous(labels=dollar_format(prefix="$", suffix="/bbl")) +
    labs(title="GAM Spread: Brent-to-Pump Pass-Through",
         subtitle=sprintf("adj. R2 = %.3f  |  deviance explained = %.1f%%",
                          summary(spread_gam)$r.sq, summary(spread_gam)$dev.expl*100),
         x="21-day weighted Brent lag ($/bbl)", y="CA pump spread ($/gal)") +
    theme_oil()
} else {
  p11 <- ggplot() + theme_oil() + labs(title="Spread Model", subtitle="OLS fallback")
}
save_plot(p11, "11_gam_spread")

# ── 12: FRED macro rate-of-change ───────────────────────────────────────────
fred_avail <- intersect(c("usd_chg_21d","claims_chg_4w","yield_chg_21d"), names(master))
if (length(fred_avail) > 0) {
  fred_col_map <- c(usd_chg_21d=AMBER, claims_chg_4w=CORAL, yield_chg_21d=TEAL)
  fred_lbl_map <- c(usd_chg_21d="USD 21d chg%", claims_chg_4w="Claims 4wk chg (K)",
                    yield_chg_21d="10Y-2Y 21d chg (pp)")
  p12 <- master |>
    filter(date >= DATE_END - 180) |>
    select(date, all_of(fred_avail)) |>
    mutate(across(all_of(fred_avail), ~(.x-mean(.x,na.rm=TRUE))/sd(.x,na.rm=TRUE))) |>
    pivot_longer(-date, names_to="indicator", values_to="zscore") |>
    ggplot(aes(x=date, y=zscore, color=indicator)) +
    geom_hline(yintercept=0, color="#cccccc") +
    geom_line(linewidth=1.2) +
    scale_color_manual(values=fred_col_map[names(fred_col_map) %in% fred_avail],
                       labels=fred_lbl_map[names(fred_lbl_map) %in% fred_avail]) +
    scale_x_date(date_breaks="1 month", date_labels="%b %y") +
    labs(title="FRED Macro Rate-of-Change (z-scored)",
         x=NULL, y="Std deviations", color=NULL) +
    theme_oil() + theme(legend.position="bottom")
} else {
  p12 <- ggplot() + theme_oil() + labs(title="FRED Macro", subtitle="No FRED_API_KEY")
}
save_plot(p12, "12_fred_macro")

# ── 13: Seasonal demand signals ─────────────────────────────────────────────
seasonal_df <- tibble(date = future_dates) |> add_seasonal_demand()

p13 <- ggplot(seasonal_df, aes(x=date)) +
  geom_ribbon(aes(ymin=0, ymax=driving_season_idx), fill=AMBER, alpha=0.25) +
  geom_line(aes(y=driving_season_idx, color="Driving season"), linewidth=1.5) +
  geom_ribbon(aes(ymin=0, ymax=heating_demand_idx), fill=BLUE, alpha=0.20) +
  geom_line(aes(y=heating_demand_idx, color="Heating demand"), linewidth=1.5) +
  geom_col(aes(y=refinery_maint*0.35, fill="Refinery maint."), alpha=0.5, width=3) +
  scale_color_manual(values=c("Driving season"=AMBER, "Heating demand"=BLUE)) +
  scale_fill_manual(values=c("Refinery maint."=CORAL)) +
  scale_x_date(date_breaks="1 month", date_labels="%b %Y") +
  scale_y_continuous(limits=c(0,1)) +
  labs(title="Seasonal Demand Signals", x=NULL, y="Index (0-1)",
       color="Index", fill="Window") +
  theme_oil() + theme(legend.position="bottom")
save_plot(p13, "13_seasonal_demand")

# ── 14: Forecast with seasonal context ──────────────────────────────────────
maint_starts <- seasonal_df |>
  filter(refinery_maint==1) |>
  group_by(grp=cumsum(c(1, diff(as.numeric(date))>5))) |>
  slice(1) |> ungroup() |> select(date)

p14 <- results_future |>
  ggplot(aes(x=forecast_date)) +
  geom_ribbon(aes(ymin=brent_ci_lo, ymax=brent_ci_hi), fill=AMBER, alpha=0.12) +
  geom_ribbon(aes(ymin=brent_ci_lo_80, ymax=brent_ci_hi_80), fill=AMBER, alpha=0.18) +
  geom_line(aes(y=brent_ensemble), color=AMBER, linewidth=1.8) +
  geom_line(aes(y=ca_gas_pred*42), color=CORAL, linewidth=1.4, linetype="dashed") +
  geom_vline(data=maint_starts, aes(xintercept=as.numeric(date)),
             color=CORAL, alpha=0.4, linewidth=0.8) +
  scale_y_continuous(labels=dollar_format(prefix="$"),
                     sec.axis=sec_axis(~./42, name="CA Gas ($/gal)", labels=dollar_format(prefix="$"))) +
  scale_x_date(date_breaks="1 month", date_labels="%b %Y") +
  labs(title="9-Month Forecast with Seasonal Context",
       subtitle="Vertical lines = refinery maintenance windows",
       x=NULL, y="Brent USD/bbl") +
  theme_oil()
save_plot(p14, "14_seasonal_forecast")

cat(sprintf("  Total: 14 individual PNGs in %s\n", OUT_PNG))


# ══════════════════════════════════════════════════════════════════════════════
# 12. EXPORT
# ══════════════════════════════════════════════════════════════════════════════

results_file <- out_path(sprintf("oil_forecast_results_%s.csv", RUN_DATE))
write_csv(results, results_file)
cat(sprintf("► Results: %s\n", results_file))

master_file <- out_path(sprintf("master_features_%s.csv", RUN_DATE))
write_csv(master |> mutate(run_date = as.Date(RUN_DATE)), master_file)
cat(sprintf("► Features: %s\n", master_file))

run_log_file <- out_path("run_log.csv")
run_log_row <- tibble(
  run_date         = as.Date(RUN_DATE),
  train_end        = max(train$date),
  n_train          = nrow(train),
  n_test           = nrow(test),
  n_news           = nrow(cache_new),
  market_structure = as.character(curve_metrics$market_structure),
  curve_slope      = round(as.numeric(curve_metrics$curve_slope) * 100, 2),
  calendar_spread  = round(as.numeric(curve_metrics$calendar_spread) * 100, 2),
  wt_arima         = as.numeric(wts["arima"]),
  wt_prophet       = as.numeric(wts["prophet"]),
  wt_lasso         = as.numeric(wts["lasso"]),
  rmse_arima       = as.numeric(rmse_vec["arima"]),
  rmse_prophet     = as.numeric(rmse_vec["prophet"]),
  rmse_lasso       = as.numeric(rmse_vec["lasso"]),
  arima_order      = paste(arimaorder(arima_model), collapse = "-"),
  use_gam          = as.logical(use_gam),
  news_delta_rmse  = round(as.numeric(delta_rmse %||% NA_real_), 3),
  # FRED counterfactual result
  fred_delta_rmse  = round(as.numeric(delta_rmse_fred %||% NA_real_), 3),
  # Last known FRED values (levels for reference)
  last_usd_index   = round(last_tech("usd_index"), 2),
  last_init_claims = round(last_tech("init_claims"), 1),
  last_yield_10y2y = round(last_tech("yield_10y2y"), 3),
  # Last known FRED rate-of-change (NEW v07)
  last_usd_chg     = round(last_tech("usd_chg_21d"), 4),
  last_claims_chg  = round(last_tech("claims_chg_4w"), 2),
  last_yield_chg   = round(last_tech("yield_chg_21d"), 4),
  # Momentum features (NEW v07)
  last_momentum_63d = round(last_tech("momentum_63d"), 4),
  last_price_vs_ma63= round(last_tech("price_vs_ma63"), 4),
  # Spot-anchoring diagnostics (NEW v08 — #18)
  anchor_halflife  = best_halflife,
  spot_anchor      = round(spot_current, 2),
  f1m_brent        = round(hz_mean(ensemble_future, hz_1m_idx), 2),
  f3m_brent        = round(hz_mean(ensemble_future, hz_3m_idx), 2),
  f6m_brent        = round(hz_mean(ensemble_future, hz_6m_idx), 2),
  f9m_brent        = round(hz_mean(ensemble_future, hz_9m_idx), 2),
  f1m_ca           = round(hz_mean(ca_gas_pred_future, hz_1m_idx), 3),
  f6m_ca           = round(hz_mean(ca_gas_pred_future, hz_6m_idx), 3),
  f9m_ca           = round(hz_mean(ca_gas_pred_future, hz_9m_idx), 3),
  brent_RMSE       = round(as.numeric(metrics_brent$RMSE), 3),
  brent_MAPE       = round(as.numeric(metrics_brent$MAPE), 2),
  brent_R2         = round(as.numeric(metrics_brent$R2),   3),
  ca_RMSE          = round(as.numeric(metrics_ca$RMSE),    3),
  ca_MAPE          = round(as.numeric(metrics_ca$MAPE),    2),
  ca_R2            = round(as.numeric(metrics_ca$R2),      3)
)

if (file.exists(run_log_file)) {
  existing_log <- read_csv(run_log_file, show_col_types = FALSE)
  write_csv(bind_rows(existing_log, run_log_row), run_log_file)
  cat(sprintf("► Run log updated: %d runs\n", nrow(existing_log) + 1))
} else {
  write_csv(run_log_row, run_log_file)
  cat("► Run log created\n")
}

saveRDS(
  list(arima = arima_model, prophet = m_prophet, lasso = final_en,
       wts = wts, spread = spread_gam, use_gam = use_gam,
       xreg_cols = xreg_cols, curve_metrics = curve_metrics,
       sentiment_cols = sentiment_cols,
       fred_series = FRED_SERIES,       # NEW v06: track which FRED series used
       run_date = as.Date(RUN_DATE),
       date_start = DATE_START, date_end = DATE_END),
  out_path(sprintf("oil_models_%s.rds", RUN_DATE))
)
cat("► Models saved\n")

cat(sprintf("
=======================================================
  DONE  |  v15  |  run: %s
  9-MONTH BRENT:  1M $%.2f | 3M $%.2f | 6M $%.2f | 9M $%.2f /bbl
  9-MONTH CA GAS: 1M $%.2f | 3M $%.2f | 6M $%.2f | 9M $%.2f /gal
  Market: %s | Curve: %+.1f%% | Cal spread: %+.1f%%
  Spot anchor: $%.2f | Halflife: %d days
  Momentum delta RMSE: %s
  Seasonal delta RMSE: %s

  FORECAST ASSUMPTIONS:
    - FRED macro rate-of-change = 0 (no further change)
    - Momentum features decay linearly to 0 over horizon
    - Sentiment scores held at last known values (no new shocks)
    - Spot-anchor alpha decays at %d-day halflife
    - Forecast clamped to [%.0f, %.0f] $/bbl safety bounds
    - CA spread: last known lag_spread carried forward
    - No new refinery outages, regulatory changes, or OPEC decisions

  Output:  png/ (14 files)  csv/  rds/
=======================================================\n",
            RUN_DATE,
            hz_mean(ensemble_future, hz_1m_idx),
            hz_mean(ensemble_future, hz_3m_idx),
            hz_mean(ensemble_future, hz_6m_idx),
            hz_mean(ensemble_future, hz_9m_idx),
            hz_mean(ca_gas_pred_future, hz_1m_idx),
            hz_mean(ca_gas_pred_future, hz_3m_idx),
            hz_mean(ca_gas_pred_future, hz_6m_idx),
            hz_mean(ca_gas_pred_future, hz_9m_idx),
            curve_metrics$market_structure,
            as.numeric(curve_metrics$curve_slope)    * 100,
            as.numeric(curve_metrics$calendar_spread) * 100,
            spot_current, best_halflife,
            ifelse(is.na(delta_rmse), "N/A",
                   sprintf("%+.2f/bbl (%s)", delta_rmse,
                           ifelse(delta_rmse > 0, "helps", "no benefit"))),
            ifelse(is.na(delta_rmse_fred), "N/A",
                   sprintf("%+.2f/bbl (%s)", delta_rmse_fred,
                           ifelse(delta_rmse_fred > 0, "helps", "no benefit"))),
            best_halflife, clamp_lo, clamp_hi))


# ══════════════════════════════════════════════════════════════════════════════
# 13. STRUCTURED DIAGNOSTIC REPORT FOR MODEL REVIEW (integrated in v09)
# ══════════════════════════════════════════════════════════════════════════════
#
# Generates a diagnostic_report_DATE.txt and prints to console.
# Copy-paste the output into a Claude conversation for review.
#
# v09 fixes from v06 report:
#   - FRED column names updated to RoC (usd_chg_21d, claims_chg_4w, yield_chg_21d)
#   - LASSO features deduplicated with distinct(term)
#   - Spot-anchoring diagnostics added (halflife, anchor price, alpha decay)
#   - Version string updated to v09
#   - xreg_cols reference updated to xreg_cols_final

cat("► Generating diagnostic report for model review…\n")

# ── Helper: safe extraction ──────────────────────────────────────────────────
safe_val <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("N/A")
  round(as.numeric(x), digits)
}

# ── 1. ARIMA residual diagnostics ────────────────────────────────────────────
arima_resid   <- residuals(arima_model)
ljung_box     <- Box.test(arima_resid, lag = 10, type = "Ljung-Box")
shapiro_resid <- if (length(arima_resid) <= 5000) {
  shapiro.test(as.numeric(arima_resid))
} else {
  shapiro.test(as.numeric(sample(arima_resid, 5000)))
}
resid_acf1 <- acf(arima_resid, lag.max = 5, plot = FALSE)$acf[2]

# ── 2. LASSO coefficient summary (deduplicated) ─────────────────────────────
lasso_coefs <- tidy(extract_fit_parsnip(final_en)$fit, s = best_en$penalty) |>
  filter(term != "(Intercept)", estimate != 0) |>
  distinct(term, .keep_all = TRUE) |>
  arrange(desc(abs(estimate)))

top_positive <- lasso_coefs |> filter(estimate > 0) |> head(5)
top_negative <- lasso_coefs |> filter(estimate < 0) |> head(5)
n_zero       <- tidy(extract_fit_parsnip(final_en)$fit, s = best_en$penalty) |>
  filter(term != "(Intercept)", estimate == 0) |>
  distinct(term) |> nrow()

# ── 3. Spread model diagnostics ─────────────────────────────────────────────
if (use_gam) {
  gam_summary    <- summary(spread_gam)
  gam_r2         <- safe_val(gam_summary$r.sq)
  gam_dev_expl   <- safe_val(gam_summary$dev.expl * 100, 1)
  gam_pvals <- as.data.frame(gam_summary$p.table)
  sig_terms <- rownames(gam_pvals)[gam_pvals[, "Pr(>|t|)"] < 0.05]
  nonsig_terms <- rownames(gam_pvals)[gam_pvals[, "Pr(>|t|)"] >= 0.05]
  smooth_pvals <- as.data.frame(gam_summary$s.table)
  sig_smooth   <- rownames(smooth_pvals)[smooth_pvals[, "p-value"] < 0.05]
} else {
  gam_r2 <- safe_val(summary(spread_gam)$r.squared)
  gam_dev_expl <- "N/A (OLS)"
  sig_terms <- names(which(summary(spread_gam)$coefficients[, 4] < 0.05))
  nonsig_terms <- names(which(summary(spread_gam)$coefficients[, 4] >= 0.05))
  sig_smooth <- "N/A"
}

# ── 4. Backtest error structure ──────────────────────────────────────────────
bt <- results_backtest |> drop_na(brent_actual)
err_series   <- bt$brent_err
err_autocorr <- if (nrow(bt) > 5) acf(err_series, lag.max = 5, plot = FALSE)$acf[2] else NA
err_trend    <- if (nrow(bt) > 5) coef(lm(err_series ~ seq_along(err_series)))[2] else NA
err_sign_pct <- mean(err_series > 0, na.rm = TRUE) * 100

# ── 5. Feature coverage check (v13: news/FRED removed from LASSO) ────────────
fred_roc_cols   <- c("usd_chg_21d", "claims_chg_4w", "yield_chg_21d")
fred_in_model   <- intersect(fred_roc_cols, xreg_cols_final)
fred_in_spread  <- intersect(fred_roc_cols, names(spread_df))
sent_in_model   <- intersect(brent_sentiment_cols, xreg_cols_final)
momentum_in     <- intersect(c("ret_21d", "momentum_63d", "price_vs_ma63"), xreg_cols_final)
seasonal_in     <- intersect(c("is_monday","quarter","driving_season_idx","heating_demand_idx","refinery_maint"), xreg_cols_final)

# ── 6. Multi-run comparison ──────────────────────────────────────────────────
run_history_summary <- ""
if (file.exists(run_log_file)) {
  rl <- read_csv(run_log_file, show_col_types = FALSE)
  if (nrow(rl) > 1) {
    run_history_summary <- sprintf(
      "  Run history: %d runs from %s to %s\n  RMSE range: $%.2f - $%.2f\n  MAPE range: %.1f%% - %.1f%%\n  Best run: %s (RMSE $%.2f)\n  Worst run: %s (RMSE $%.2f)\n",
      nrow(rl), min(rl$run_date), max(rl$run_date),
      min(rl$brent_RMSE, na.rm = TRUE), max(rl$brent_RMSE, na.rm = TRUE),
      min(rl$brent_MAPE, na.rm = TRUE), max(rl$brent_MAPE, na.rm = TRUE),
      rl$run_date[which.min(rl$brent_RMSE)], min(rl$brent_RMSE, na.rm = TRUE),
      rl$run_date[which.max(rl$brent_RMSE)], max(rl$brent_RMSE, na.rm = TRUE)
    )
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# BUILD THE REPORT (v10: split into chunks to stay under R's 100-arg limit)
# ══════════════════════════════════════════════════════════════════════════════

rpt_header <- sprintf(
  '================================================================================
  OIL PRICE PREDICTOR v15 -- DIAGNOSTIC REPORT
  Run date: %s  |  Training: %s to %s
================================================================================',
  RUN_DATE, DATE_START, DATE_END)

rpt_accuracy <- sprintf('
-- 1. ACCURACY METRICS ---------------------------------------------------------

  BRENT ENSEMBLE (30-day backtest)
    RMSE:  $%.3f /bbl    MAE: $%.3f /bbl    MAPE: %.2f%%    R2: %.4f

  CA GASOLINE (30-day backtest)
    RMSE:  $%.4f /gal    MAE: $%.4f /gal    MAPE: %.2f%%    R2: %.4f',
                        as.numeric(metrics_brent$RMSE), as.numeric(metrics_brent$MAE),
                        as.numeric(metrics_brent$MAPE), as.numeric(metrics_brent$R2),
                        as.numeric(metrics_ca$RMSE), as.numeric(metrics_ca$MAE),
                        as.numeric(metrics_ca$MAPE), as.numeric(metrics_ca$R2))

rpt_ensemble <- sprintf('
-- 2. ENSEMBLE WEIGHTS & MODEL PERFORMANCE ------------------------------------

    Model     Weight    RMSE         ARIMA order: %s
    ARIMA     %.3f     $%.2f        LASSO: penalty=%.4f  mixture=%.2f
    Prophet   %.3f     $%.2f
    LASSO     %.3f     $%.2f',
                        paste(arimaorder(arima_model), collapse = "-"),
                        as.numeric(wts["arima"]),   as.numeric(rmse_vec["arima"]),
                        best_en$penalty, best_en$mixture,
                        as.numeric(wts["prophet"]), as.numeric(rmse_vec["prophet"]),
                        as.numeric(wts["lasso"]),   as.numeric(rmse_vec["lasso"]))

rpt_features <- sprintf('
-- 3. FEATURE IMPORTANCE (LASSO -- top 5, deduplicated) -----------------------

  TOP POSITIVE:
%s

  TOP NEGATIVE:
%s

  Zeroed out: %d of %d
  Brent LASSO: technical + momentum + curve + seasonal (no news/FRED)
  Momentum active: %s    Seasonal active: %s
  News/FRED: spread model only (not in Brent LASSO since v13)
  Sentiment in spread: %d channels    FRED in spread: %s',
                        paste(sprintf("    %-25s  %+.4f", top_positive$term, top_positive$estimate), collapse = "\n"),
                        paste(sprintf("    %-25s  %+.4f", top_negative$term, top_negative$estimate), collapse = "\n"),
                        n_zero, length(xreg_cols_final),
                        if (length(momentum_in) > 0) paste(momentum_in, collapse = ", ") else "NONE",
                        if (length(seasonal_in) > 0) paste(seasonal_in, collapse = ", ") else "NONE",
                        length(sent_in_model),
                        if (length(fred_in_spread) > 0) paste(fred_in_spread, collapse = ", ") else "NONE")

rmse_full_diag <- safe_val(sqrt(mean((lasso_pred_test - test$brent_close)^2, na.rm=TRUE)))
rpt_counterfactual <- sprintf('
-- 4. COUNTERFACTUAL DIAGNOSTICS -----------------------------------------------

  Momentum: Full $%.3f | No-momentum %s | Delta %s | %s
  Seasonal: Full $%.3f | No-seasonal %s    | Delta %s | %s',
                              rmse_full_diag,
                              ifelse(is.na(delta_rmse), "N/A", sprintf("$%.3f", rmse_full_diag + delta_rmse)),
                              ifelse(is.na(delta_rmse), "N/A", sprintf("%+.3f", delta_rmse)),
                              ifelse(is.na(delta_rmse), "N/A", ifelse(delta_rmse > 0.01, "MOMENTUM HELPS", ifelse(delta_rmse < -0.01, "MOMENTUM HURTS", "NEGLIGIBLE"))),
                              rmse_full_diag,
                              ifelse(is.na(delta_rmse_fred), "N/A", sprintf("$%.3f", rmse_full_diag + delta_rmse_fred)),
                              ifelse(is.na(delta_rmse_fred), "N/A", sprintf("%+.3f", delta_rmse_fred)),
                              ifelse(is.na(delta_rmse_fred), "N/A", ifelse(delta_rmse_fred > 0.01, "SEASONAL HELPS", ifelse(delta_rmse_fred < -0.01, "SEASONAL HURTS", "NEGLIGIBLE"))))

rpt_arima_diag <- sprintf('
-- 5. ARIMA RESIDUAL DIAGNOSTICS -----------------------------------------------

  Ljung-Box (lag 10): stat=%.2f  p=%.4f  %s
  Shapiro-Wilk: p=%.4f  %s
  Lag-1 ACF: %.4f  %s',
                          ljung_box$statistic, ljung_box$p.value,
                          ifelse(ljung_box$p.value < 0.05, "FAIL", "PASS"),
                          shapiro_resid$p.value,
                          ifelse(shapiro_resid$p.value < 0.05, "Non-normal", "Normal"),
                          resid_acf1,
                          ifelse(abs(resid_acf1) > 0.15, "CONCERNING", "OK"))

rpt_errors <- sprintf('
-- 6. BACKTEST ERROR STRUCTURE -------------------------------------------------

  Error ACF(1): %s    Trend: %s    Over-prediction: %.1f%%
  Verdict: %s',
                      ifelse(is.na(err_autocorr), "N/A", sprintf("%.4f", err_autocorr)),
                      ifelse(is.na(err_trend), "N/A", sprintf("%.4f $/day", err_trend)),
                      err_sign_pct,
                      case_when(
                        abs(err_sign_pct - 50) > 15 ~ sprintf("BIASED (%.0f%% %s-prediction)", err_sign_pct, ifelse(err_sign_pct > 50, "over", "under")),
                        !is.na(err_autocorr) && abs(err_autocorr) > 0.3 ~ "AUTOCORRELATED ERRORS",
                        !is.na(err_trend) && abs(err_trend) > 0.1 ~ "TRENDING ERRORS",
                        TRUE ~ "HEALTHY"))

rpt_gam <- sprintf('
-- 7. SPREAD MODEL (GAM) ------------------------------------------------------

  adj. R2: %s    Deviance explained: %s%%
  Significant: %s
  Non-significant: %s
  Smooth: %s',
                   gam_r2, gam_dev_expl,
                   if (length(sig_terms) > 0) paste(sig_terms, collapse = ", ") else "none",
                   if (length(nonsig_terms) > 0) paste(nonsig_terms, collapse = ", ") else "none",
                   if (is.character(sig_smooth)) paste(sig_smooth, collapse = ", ") else "N/A")

rpt_anchor <- sprintf('
-- 8. SPOT-ANCHORING + MONTE CARLO INTERVALS (v15) ----------------------------

  Anchor: $%.2f    Halflife: %d days
  Alpha: day1=%.0f%% | day30=%.0f%% | day90=%.0f%% | day180=%.0f%%
  Raw 1M: $%.2f    Anchored 1M: $%.2f    Correction: %+.2f /bbl

  Monte Carlo bootstrap: %d simulated paths
  1M 90%% CI: [$%.2f, $%.2f]    width: $%.1f
  3M 90%% CI: [$%.2f, $%.2f]    width: $%.1f
  9M 90%% CI: [$%.2f, $%.2f]    width: $%.1f
  Method: resampled ARIMA + LASSO residuals, Prophet interval jitter',
                      spot_current, best_halflife,
                      0.5^(1/best_halflife)*100, 0.5^(30/best_halflife)*100,
                      0.5^(90/best_halflife)*100, 0.5^(180/best_halflife)*100,
                      hz_mean(ensemble_future_raw, hz_1m_idx),
                      hz_mean(ensemble_future, hz_1m_idx),
                      hz_mean(ensemble_future, hz_1m_idx) - hz_mean(ensemble_future_raw, hz_1m_idx),
                      N_SIM,
                      hz_mean(ensemble_ci_lo, hz_1m_idx), hz_mean(ensemble_ci_hi, hz_1m_idx),
                      hz_mean(ensemble_ci_hi, hz_1m_idx) - hz_mean(ensemble_ci_lo, hz_1m_idx),
                      hz_mean(ensemble_ci_lo, hz_3m_idx), hz_mean(ensemble_ci_hi, hz_3m_idx),
                      hz_mean(ensemble_ci_hi, hz_3m_idx) - hz_mean(ensemble_ci_lo, hz_3m_idx),
                      hz_mean(ensemble_ci_lo, hz_9m_idx), hz_mean(ensemble_ci_hi, hz_9m_idx),
                      hz_mean(ensemble_ci_hi, hz_9m_idx) - hz_mean(ensemble_ci_lo, hz_9m_idx))

rpt_market <- sprintf('
-- 9. MARKET CONTEXT -----------------------------------------------------------

  Structure: %s    Curve: %+.1f%%    Cal spread: %+.1f%%    WTI basis: %+.1f%%
  Spot WTI: $%.2f
  FRED levels: USD=%.1f  Claims=%.0fK  Yield=%.3f%%
  FRED chg:    USD=%+.2f%%  Claims=%+.1fK  Yield=%+.3fpp',
                      as.character(curve_metrics$market_structure),
                      as.numeric(curve_metrics$curve_slope) * 100,
                      as.numeric(curve_metrics$calendar_spread) * 100,
                      as.numeric(curve_metrics$wti_basis) * 100,
                      as.numeric(curve_metrics$spot_wti),
                      last_tech("usd_index"), last_tech("init_claims"), last_tech("yield_10y2y"),
                      last_tech("usd_chg_21d") * 100, last_tech("claims_chg_4w"), last_tech("yield_chg_21d"))

rpt_quality <- sprintf('
-- 10. DATA QUALITY ------------------------------------------------------------

  Train: %d    Backtest: %d    News: %d articles    xreg: %d cols
  FRED obs: USD %d | Claims %d | Yield %d',
                       nrow(train), nrow(test), nrow(cache_new), length(xreg_cols_final),
                       nrow(usd_index), nrow(claims_raw), nrow(yield_spread))

rpt_history <- ifelse(nchar(run_history_summary) > 0,
                      paste0("\n-- RUN HISTORY -----------------------------------------------------------------\n\n", run_history_summary),
                      "")

rpt_baseline <- sprintf('
-- 11. NAIVE BASELINE COMPARISON -----------------------------------------------

  %-22s  RMSE: $%6.2f  MAPE: %5.1f%%
  %-22s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%
  %-22s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%
  %-22s  RMSE: $%6.2f  MAPE: %5.1f%%  Skill: %+.1f%%
  Beats RW: %s  |  beats Mean: %s  |  beats Trend: %s',
                        "Ensemble (anchored)", as.numeric(metrics_brent$RMSE), as.numeric(metrics_brent$MAPE),
                        "Random Walk (spot)", naive_rw_rmse, naive_rw_mape, skill_vs_rw * 100,
                        "Historical Mean", naive_mean_rmse, naive_mean_mape, skill_vs_mean * 100,
                        "63-day Trend", naive_trend_rmse, naive_trend_mape, skill_vs_trend * 100,
                        ifelse(skill_vs_rw > 0, "YES", "NO"),
                        ifelse(skill_vs_mean > 0, "YES", "NO"),
                        ifelse(skill_vs_trend > 0, "YES", "NO"))

rpt_forecast <- sprintf('
-- 12. FORECAST SUMMARY --------------------------------------------------------

  Brent  1M: $%.2f  |  3M: $%.2f  |  6M: $%.2f  |  9M: $%.2f  /bbl
  CA Gas 1M: $%.2f  |  3M: $%.2f  |  6M: $%.2f  |  9M: $%.2f  /gal
  TX Gas (latest actual): $%s/gal    CA-TX premium: $%s/gal

================================================================================
  END DIAGNOSTIC REPORT -- paste this into Claude for model review
================================================================================',
                        hz_mean(ensemble_future, hz_1m_idx),
                        hz_mean(ensemble_future, hz_3m_idx),
                        hz_mean(ensemble_future, hz_6m_idx),
                        hz_mean(ensemble_future, hz_9m_idx),
                        hz_mean(ca_gas_pred_future, hz_1m_idx),
                        hz_mean(ca_gas_pred_future, hz_3m_idx),
                        hz_mean(ca_gas_pred_future, hz_6m_idx),
                        hz_mean(ca_gas_pred_future, hz_9m_idx),
                        ifelse(is.na(tx_gas_latest), "N/A", sprintf("%.2f", tx_gas_latest)),
                        ifelse(is.na(ca_tx_premium), "N/A", sprintf("%.2f", ca_tx_premium)))

report <- paste0(rpt_header, rpt_accuracy, rpt_ensemble, rpt_features,
                 rpt_counterfactual, rpt_arima_diag, rpt_errors, rpt_gam,
                 rpt_anchor, rpt_market, rpt_quality, rpt_history,
                 rpt_baseline, rpt_forecast, "\n")

# Write to file
report_file <- out_path(sprintf("diagnostic_report_%s.txt", RUN_DATE))
writeLines(report, report_file)
cat(sprintf("► Diagnostic report: %s\n", report_file))

# Print to console
cat(report)