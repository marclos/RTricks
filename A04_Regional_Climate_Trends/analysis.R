#' Calculate Monthly Aggregated Values
#' @param station Cleaned station data
#' @return List with TMAX, TMIN, PRCP monthly values
#' @export
MonthlyValues.fun <- function(station) {
  TMAX.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "TMAX"),
                            mean, na.rm = TRUE)
  names(TMAX.monthly) <- c("MONTH", "YEAR", "TMAX")

  TMIN.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "TMIN"),
                            mean, na.rm = TRUE)
  names(TMIN.monthly) <- c("MONTH", "YEAR", "TMIN")

  PRCP.monthly <- aggregate(VALUE ~ MONTH + YEAR,
                            data = subset(station, ELEMENT == "PRCP"),
                            sum, na.rm = TRUE)
  names(PRCP.monthly) <- c("MONTH", "YEAR", "PRCP")

  return(list(TMAX = TMAX.monthly, TMIN = TMIN.monthly, PRCP = PRCP.monthly))
}

#' Calculate Climate Normals (1991-2020)
#'
#' Calculates climate normals for the 1991-2020 baseline, the current
#' WMO/NOAA standard normals period. If the standard period has
#' insufficient data the function falls back through earlier 30-year
#' periods (1981-2010, then 1971-2000) and, as a last resort, uses the
#' full record. The cascade can be changed via \code{periods}.
#'
#' @param station Cleaned station data (must contain Ymd, ELEMENT, VALUE, MONTH)
#' @param min_months_required Minimum number of distinct months (1-12) that
#'   must be represented in the normals period for each element. Default 12
#'   (all months required).
#' @param min_years_per_month Minimum number of years of data required for
#'   each individual month to be considered reliable. Default 10.
#' @param station_id Optional station ID string used in warning messages
#'   so students can tell WHICH station had problems.
#' @param periods Character vector of 30-year baselines to try, in order,
#'   each formatted \code{"YYYY-YYYY"}. Default
#'   \code{c("1991-2020", "1981-2010", "1971-2000")}. If none succeeds the
#'   full record is used.
#'
#' @return A list with components TMAX, TMIN, PRCP (data frames with MONTH
#'   and NORMALS columns), plus an attribute \code{"normals_period"} that
#'   records which period was actually used.
#'   Returns NULL if no adequate normals can be calculated.
#'
#' @export
MonthlyNormals.fun <- function(station,
                                min_months_required = 12,
                                min_years_per_month = 10,
                                station_id = "unknown",
                                periods = c("1991-2020", "1981-2010",
                                            "1971-2000")) {

  # ---- helper: try computing normals from a subset ----
  .try_normals <- function(sdata, element, agg_fun = mean) {
    elem_data <- subset(sdata, ELEMENT == element)
    if (nrow(elem_data) == 0) return(NULL)

    if (element == "PRCP") {
      # PRCP: sum within month-year first, then average across years
      month_year <- aggregate(VALUE ~ MONTH + YEAR, data = elem_data,
                              FUN = sum, na.rm = TRUE)
      # Check month coverage (how many years per month?)
      month_counts <- table(month_year$MONTH)
    } else {
      month_counts <- table(elem_data$MONTH)
    }

    # Do we have enough months represented?
    months_present <- sum(month_counts >= min_years_per_month)
    if (months_present < min_months_required) return(NULL)

    if (element == "PRCP") {
      normals <- aggregate(VALUE ~ MONTH, data = month_year,
                           FUN = mean, na.rm = TRUE)
    } else {
      normals <- aggregate(VALUE ~ MONTH, data = elem_data,
                           FUN = mean, na.rm = TRUE)
    }
    names(normals) <- c("MONTH", "NORMALS")
    return(normals)
  }

  # ---- Try each baseline period in order --------------------------------
  # Primary is the current WMO/NOAA standard (1991-2020); earlier 30-year
  # periods are fallbacks for stations that closed before 2020. The cascade
  # is an argument so instructors can teach baseline choice by changing it.
  TMAX_n <- TMIN_n <- PRCP_n <- NULL
  all_ok <- FALSE
  period_label <- periods[1]

  for (p in periods) {
    period_label <- p
    yrs <- as.integer(strsplit(p, "-", fixed = TRUE)[[1]])
    if (length(yrs) != 2 || any(is.na(yrs)))
      stop("Each entry of `periods` must look like \"1991-2020\"; got \"", p, "\"")
    normals_data <- subset(station,
                           Ymd >= as.Date(sprintf("%d-01-01", yrs[1])) &
                           Ymd <= as.Date(sprintf("%d-12-31", yrs[2])))
    if (is.null(TMAX_n)) TMAX_n <- .try_normals(normals_data, "TMAX")
    if (is.null(TMIN_n)) TMIN_n <- .try_normals(normals_data, "TMIN")
    if (is.null(PRCP_n)) PRCP_n <- .try_normals(normals_data, "PRCP")
    all_ok <- !is.null(TMAX_n) && !is.null(TMIN_n) && !is.null(PRCP_n)
    if (all_ok) break
  }

  # ---- Last resort: full record -----------------------------------------
  if (!all_ok) {
    period_label <- "full record"
    if (is.null(TMAX_n)) TMAX_n <- .try_normals(station, "TMAX")
    if (is.null(TMIN_n)) TMIN_n <- .try_normals(station, "TMIN")
    if (is.null(PRCP_n)) PRCP_n <- .try_normals(station, "PRCP")
    all_ok <- !is.null(TMAX_n) && !is.null(TMIN_n) && !is.null(PRCP_n)
  }

  # ---- 5. If STILL not enough data, return NULL with warning ----
  if (!all_ok) {
    missing_elements <- c(
      if (is.null(TMAX_n)) "TMAX",
      if (is.null(TMIN_n)) "TMIN",
      if (is.null(PRCP_n)) "PRCP"
    )
    warning("Station ", station_id,
            ": Cannot compute normals for ", paste(missing_elements, collapse = ", "),
            ". Not enough monthly coverage (need ", min_months_required,
            " months with >= ", min_years_per_month, " years each). Skipping.")
    return(NULL)
  }

  # Report if we fell back from the standard period
  if (period_label != periods[1]) {
    message("Station ", station_id,
            ": Normals period = ", period_label,
            " (", periods[1], " had insufficient data)")
  }

  result <- list(TMAX = TMAX_n, TMIN = TMIN_n, PRCP = PRCP_n)
  attr(result, "normals_period") <- period_label
  return(result)
}

#' Calculate Monthly Anomalies
#'
#' @param station.monthly Output from MonthlyValues.fun
#' @param station.normals Output from MonthlyNormals.fun
#' @param station_id Optional station ID for warning messages
#' @return List with anomaly data frames, or NULL if merge produces no rows.
#' @export
MonthlyAnomalies.fun <- function(station.monthly, station.normals,
                                  station_id = "unknown") {

  # Guard: if normals are NULL the caller should have already handled this,
  # but be safe.
  if (is.null(station.normals)) {
    warning("Station ", station_id, ": normals are NULL, cannot compute anomalies.")
    return(NULL)
  }

  TMAX <- merge(station.monthly$TMAX, station.normals$TMAX, by = "MONTH")
  TMIN <- merge(station.monthly$TMIN, station.normals$TMIN, by = "MONTH")
  PRCP <- merge(station.monthly$PRCP, station.normals$PRCP, by = "MONTH")

  # Check that merges produced rows
  if (nrow(TMAX) == 0 || nrow(TMIN) == 0 || nrow(PRCP) == 0) {
    missing_elem <- c(
      if (nrow(TMAX) == 0) "TMAX",
      if (nrow(TMIN) == 0) "TMIN",
      if (nrow(PRCP) == 0) "PRCP"
    )
    warning("Station ", station_id,
            ": Anomaly merge produced 0 rows for ",
            paste(missing_elem, collapse = ", "),
            ". Normals months may not match data months. Skipping.")
    return(NULL)
  }

  TMAX$TMAX.a <- TMAX$TMAX - TMAX$NORMALS
  TMAX$Ymd <- as.Date(paste(TMAX$YEAR, TMAX$MONTH, "01", sep = "-"))

  TMIN$TMIN.a <- TMIN$TMIN - TMIN$NORMALS
  TMIN$Ymd <- as.Date(paste(TMIN$YEAR, TMIN$MONTH, "01", sep = "-"))

  PRCP$PRCP.a <- PRCP$PRCP - PRCP$NORMALS
  PRCP$Ymd <- as.Date(paste(PRCP$YEAR, PRCP$MONTH, "01", sep = "-"))

  return(list(TMAX = TMAX, TMIN = TMIN, PRCP = PRCP))
}

#' Calculate Monthly Trends
#' @param station.anomalies Output from MonthlyAnomalies.fun
#' @return Data frame with trend statistics
#' @export
monthlyTrend.fun <- function(station.anomalies) {

  if (is.null(station.anomalies)) return(data.frame())

  results <- data.frame()

  for (element in c("TMAX", "TMIN", "PRCP")) {
    data <- station.anomalies[[element]]
    if (is.null(data) || nrow(data) == 0) next

    anom_col <- paste0(element, ".a")

    for (m in 1:12) {
      month_data <- subset(data, MONTH == m)

      if (nrow(month_data) >= 10) {
        formula <- as.formula(paste(anom_col, "~ YEAR"))
        model <- tryCatch(lm(formula, data = month_data),
                          error = function(e) NULL)
        if (is.null(model)) next
        s <- summary(model)

        results <- rbind(results, data.frame(
          MONTH = m,
          ELEMENT = element,
          Estimate = coef(model)[2],
          Std.Error = s$coefficients[2, 2],
          t.value = s$coefficients[2, 3],
          `Pr(>|t|)` = s$coefficients[2, 4],
          r.squared = s$r.squared,
          check.names = FALSE
        ))
      }
    }
  }

  if (nrow(results) > 0) {
    results$Signif <- ""
    results$Signif[results$`Pr(>|t|)` < 0.05]  <- "*"
    results$Signif[results$`Pr(>|t|)` < 0.01]  <- "**"
    results$Signif[results$`Pr(>|t|)` < 0.001] <- "***"
  }

  return(results)
}
