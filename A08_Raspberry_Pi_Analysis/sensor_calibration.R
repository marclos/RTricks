# =============================================================================
# Sensor Calibration Table — ea30 sp26 v05
# Clock offsets + deployment metadata for all RPiZ units
#
# Background: Pi Zeros have no RTC battery, so their clocks start from an
# arbitrary epoch each boot.  Each team member recorded the real wall-clock
# time (PST) and what the Pi's LCD displayed at that moment.
# offset_sec = real_time − pi_time  (always add this to raw Pi timestamps)
#
# Usage:
#   source("sensor_calibration.R")      # loads `calibration` tibble
#   df <- df |>
#     left_join(calibration |> select(sensor, offset_sec), by = "sensor") |>
#     mutate(datetime = datetime_pi + seconds(offset_sec))
# =============================================================================

library(tidyverse)
library(lubridate)

# Helper: compute offset in seconds from two datetime strings
offset_s <- function(real, pi) {
  as.numeric(difftime(
    ymd_hms(real, tz = "America/Los_Angeles"),
    ymd_hms(pi,   tz = "America/Los_Angeles"),
    units = "secs"
  ))
}

# -----------------------------------------------------------------------------
# Main calibration tibble
# Columns:
#   sensor        — sensor ID matching CSV filename stem
#   team_member   — student responsible for the unit
#   lab_tested    — whether unit was lab-tested before deployment (Y / NA)
#   enclosure     — enclosure type
#   location      — physical deployment location (notes)
#   real_time     — actual wall-clock time at power-on (PST)
#   pi_time       — Pi LCD time at the same moment (PST)
#   offset_sec    — seconds to ADD to all raw Pi timestamps
#   reboot        — deployment number (1 = first power-on; 2 = reboot/redeploy)
#   notes         — freeform notes
# -----------------------------------------------------------------------------

calibration <- tribble(
  ~sensor,   ~team_member, ~lab_tested, ~enclosure,              ~location,                                                    ~real_time,              ~pi_time,                ~reboot, ~notes,
  # ── PiZ series ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  "PiZ1",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ2",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ3",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ4",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ5",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ6",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ7",    "Naomi",      NA,          "square gutter angles",  "Outside Blaisdell dorm, by the back stairs",                 "2026-03-14 12:14:00",   "2026-03-04 05:41:00",   1L,      NA,
  "PiZ8",    "Sorren",     NA,          "square gutter angles",  "Outside Wig Lounge patio, side facing Lyon",                 "2026-03-10 17:22:00",   "2026-02-28 17:56:00",   1L,      NA,
  "PiZ9",    NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ10",   NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ11",   NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ12",   "Ashley",     NA,          "two square gutter angles", "Mudd-Blaisdell Courtyard",                               "2026-03-09 02:30:00",   "2026-03-01 15:43:58",   1L,      NA,
  "PiZ13",   "Mariana",    NA,          "two square gutter angles", "Outside Harwood by the bicycle racks",                   "2026-03-11 15:42:00",   "2026-03-01 14:10:43",   1L,      NA,
  "PiZ14",   NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  # PiZ15 was powered on twice — two rows, one per boot; filter reboot == 1 for
  # initial deployment offset, reboot == 2 if the unit was restarted mid-study.
  "PiZ15",   "Dessa",      NA,          "two gutter angles",     "Outside Seaver Theater, second floor",                      "2026-03-09 14:29:00",   "2026-03-04 16:48:38",   1L,      "First power-on",
  "PiZ15",   "Dessa",      NA,          "two gutter angles",     "Outside Seaver Theater, second floor",                      "2026-03-17 11:00:00",   "2026-03-03 07:08:37",   2L,      "Second power-on / reboot",
  # ── PiZ 2W series ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  # PiZ2W1: sheet says '2/9 4:47 PM'; interpreted as 3/9 because (a) raw data
  # starts 2026-02-27 and (b) all other units show Pi clocks BEHIND real time.
  # If truly Feb 9, flip the note and change real_time to "2026-02-09 16:47:00".
  "PiZ2W1",  "Kate",       NA,          "rounded gutter angles", "Outside 2F Oldenborg window facing Frary",                  "2026-03-09 16:47:00",   "2026-02-27 23:24:28",   1L,      "Sheet entry '2/9' interpreted as 3/9 — verify with Kate",
  "PiZ2W2",  "Matteo",     NA,          "two gutter angles",     "Outside bathroom window, first floor (building TBD)",       "2026-03-13 16:30:00",   "2026-02-28 00:01:50",   1L,      NA,
  "PiZ2W3",  "Matthew",    NA,          "two gutter angles",     "Outside ground floor, Mudd-Honnold Library",                "2026-03-09 23:50:00",   "2026-02-28 01:59:30",   1L,      NA,
  "PiZ2W4",  NA,           NA,          NA,                      NA,                                                           NA,                      NA,                      1L,      "No calibration data recorded",
  "PiZ2W5",  "Anna",       "Y",         "outlet box",            "Pomona Organic Farm (near dome)",                           "2026-03-09 14:31:00",   "2026-02-28 00:55:06",   1L,      NA,
) |>
  mutate(
    real_time  = ymd_hms(real_time, tz = "America/Los_Angeles"),
    pi_time    = ymd_hms(pi_time,   tz = "America/Los_Angeles"),
    offset_sec = as.numeric(difftime(real_time, pi_time, units = "secs")),
    # Human-readable offset string
    offset_label = case_when(
      is.na(offset_sec) ~ NA_character_,
      TRUE ~ {
        d <- floor(offset_sec / 86400)
        h <- floor((offset_sec %% 86400) / 3600)
        m <- floor((offset_sec %% 3600)  / 60)
        s <- round(offset_sec %% 60)
        sprintf("%dd %02dh %02dm %02ds", d, h, m, s)
      }
    )
  )

# Preview
cat("Calibration table:\n")
calibration |>
  select(sensor, team_member, location, offset_label, reboot, notes) |>
  knitr::kable(format = "simple") |>
  print()

cat(sprintf(
  "\n%d sensors total | %d with clock corrections | %d missing data\n",
  n_distinct(calibration$sensor),
  calibration |> filter(!is.na(offset_sec)) |> distinct(sensor) |> nrow(),
  calibration |> filter(is.na(offset_sec))  |> distinct(sensor) |> nrow()
))
