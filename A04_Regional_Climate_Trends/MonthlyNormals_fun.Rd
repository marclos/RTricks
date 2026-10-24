\name{MonthlyNormals.fun}
\alias{MonthlyNormals.fun}
\title{Calculate Climate Normals with Fallback Periods}
\usage{
MonthlyNormals.fun(station, min_months_required = 12,
  min_years_per_month = 10, station_id = "unknown",
  periods = c("1991-2020", "1981-2010", "1971-2000"))
}
\arguments{
\item{station}{Cleaned station data (must contain Ymd, ELEMENT, VALUE, MONTH).}
\item{min_months_required}{Minimum months (1-12) that must be represented (default 12).}
\item{min_years_per_month}{Minimum years of data per month (default 10).}
\item{station_id}{Station ID string for warning messages.}
\item{periods}{Character vector of 30-year baselines to try, in order,
each formatted \code{"YYYY-YYYY"}. Default
\code{c("1991-2020", "1981-2010", "1971-2000")}.}
}
\value{
List with TMAX, TMIN, PRCP normals data frames (each with MONTH and NORMALS
columns), or NULL if no adequate normals can be calculated.
Has attribute \code{"normals_period"} recording which period was used.
}
\description{
Calculates climate normals using a cascade of fallback periods:
1991-2020 (the current WMO/NOAA standard), then 1981-2010, 1971-2000,
and finally the full record. The cascade can be changed via
\code{periods}, which makes baseline choice itself teachable. At each
level, all 12 months must have at least
\code{min_years_per_month} years of data. Returns NULL with a warning
if no period has adequate coverage.
}
\seealso{
\code{\link{MonthlyValues.fun}}, \code{\link{MonthlyAnomalies.fun}}
}
