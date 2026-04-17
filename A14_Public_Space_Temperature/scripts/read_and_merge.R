# =============================================================================
# read_and_merge.R
# EA030 — Activity A14: Public Space Temperature Analysis
# Marc Los Huertos · Pomona College
#
# PURPOSE
#   Read all iButton sensor CSV files from data_raw/, attach site and
#   treatment metadata from data_meta/locations_treatments.csv, and write
#   a clean merged CSV to data_processed/.
#
# HOW TO USE
#   1. Open your RStudio Project (the one containing data_raw/, data_meta/, etc.)
#   2. Place all sensor .csv files in data_raw/
#   3. Place locations_treatments.csv in data_meta/
#   4. Run this script: source("scripts/read_and_merge.R")
#   5. Find the output at: data_processed/sensor_data_merged.csv
#
# EXPECTED FILE STRUCTURE
#   my_project/
#   ├── data_raw/
#   │   ├── 260191640D.csv       <- sensor files; with header rows
#   │   ├── 260191640E.csv
#   │   └── ...
#   ├── data_clean/
#   │   ├── 260191640D.csv       <- sensor files; no header row
#   │   ├── 260191640E.csv
#   │   └── ...
#   ├── data_meta/
#   │   └── locations_treatments.csv
#   ├── data_processed/          <- created automatically if absent
#   └── scripts/
#       └── read_and_merge.R     <- this file
#
# SENSOR FILE FORMAT (no column headers, comma-separated):
#   4/10/2026,16:25:13,79.3,26.3
#   col 1 = date     (M/D/YYYY)
#   col 2 = time     (H:MM:SS)
#   col 3 = temp_F   (Fahrenheit)
#   col 4 = temp_C   (Celsius)
#
# METADATA FILE FORMAT (locations_treatments.csv):
#   Sensor_id,Site,Treatment
#   260191640D,Site A,Shade
#   260191640E,Site A,Sun
#
# DEPENDENCIES
#   tidyverse (readr, dplyr, purrr)
#   lubridate
#   Install once with: install.packages(c("tidyverse", "lubridate"))
# =============================================================================


# -----------------------------------------------------------------------------
# 0. Packages
# -----------------------------------------------------------------------------

library(tidyverse)   # readr + dplyr + purrr
library(lubridate)   # friendly date/time parsing


# -----------------------------------------------------------------------------
# 1. Paths  — adjust these if your folder names differ
# -----------------------------------------------------------------------------

clean_dir   <- "data_clean"
meta_file <- "data_meta/locations_treatments.csv"
out_file  <- "data_processed/sensor_data_merged.csv"

# Create the output directory if it does not yet exist
if (!dir.exists(dirname(out_file))) {
  dir.create(dirname(out_file), recursive = TRUE)
  message("Created directory: ", dirname(out_file))
}


# -----------------------------------------------------------------------------
# 2. Function: read a single iButton sensor file
# -----------------------------------------------------------------------------
#
# The iButton files have NO header row. We supply column names manually.
# We parse the date and time columns into a proper POSIXct datetime object
# using lubridate::mdy_hms(), and we extract the sensor ID from the filename.
#
# Arguments:
#   file_path  character — path to one .csv file, e.g. "data_clean/260191640D.csv"
#
# Returns:
#   A tibble with columns: sensor_id, datetime, temp_F, temp_C

read_sensor_file <- function(file_path) {

  # ------------------------------------------------------------------
  # 2a. Extract the sensor ID from the file name.
  #     basename()  strips the directory:  "data_raw/260191640D.csv" -> "260191640D.csv"
  #     file_path_sans_ext() strips ".csv": "260191640D.csv"         -> "260191640D"
  # ------------------------------------------------------------------
  sensor_id <- tools::file_path_sans_ext(basename(file_path))

  # ------------------------------------------------------------------
  # 2b. Read the CSV.
  #     col_names = FALSE tells readr there is no header row.
  #     We then rename the columns manually.
  # ------------------------------------------------------------------
  raw <- read_csv(
    file_path,
    col_names = c("date_str", "time_str", "temp_F", "temp_C"),
    col_types = cols(
      date_str = col_character(),
      time_str = col_character(),
      temp_F   = col_double(),
      temp_C   = col_double()
    ),
    show_col_types = FALSE
  )

  # ------------------------------------------------------------------
  # 2c. Parse datetime.
  #     We paste the two string columns ("4/10/2026" + "16:25:13")
  #     into "4/10/2026 16:25:13", then use lubridate::mdy_hms().
  #     Setting tz = "America/Los_Angeles" ensures daylight saving
  #     time is handled correctly for SoCal data.
  # ------------------------------------------------------------------
  raw |>
    mutate(
      sensor_id = sensor_id,
      datetime  = mdy_hms(paste(date_str, time_str),
                          tz = "America/Los_Angeles",
                          quiet = TRUE)  # quiet suppresses parse warnings
    ) |>
    # Keep only the columns we need going forward
    select(sensor_id, datetime, temp_F, temp_C)
}


# -----------------------------------------------------------------------------
# 3. Read ALL sensor files and stack into one data frame
# -----------------------------------------------------------------------------
#
# list.files() finds every .csv in data_raw/.
# map_dfr() applies read_sensor_file() to each path and row-binds the results.
# This is equivalent to a for-loop that grows a data frame, but cleaner.

sensor_files <- list.files(
  path       = clean_dir,
  pattern    = "\\.csv$",    # only files whose name ends in .csv
  full.names = TRUE           # return paths like "data_raw/260191640D.csv"
)

if (length(sensor_files) == 0) {
  stop(
    "No .csv files found in '", clean_dir, "/'.\n",
    "  -> Check that your sensor files are in the right folder and that\n",
    "     your working directory is set to the project root.\n",
    "     In RStudio: Session > Set Working Directory > To Project Directory"
  )
}

message("Found ", length(sensor_files), " sensor file(s). Reading...")

sensor_data <- map_dfr(sensor_files, read_sensor_file)

message("  Rows read: ", nrow(sensor_data))
message("  Date range: ", format(min(sensor_data$datetime, na.rm = TRUE)),
        " to ", format(max(sensor_data$datetime, na.rm = TRUE)))


# -----------------------------------------------------------------------------
# 4. Load location / treatment metadata
# -----------------------------------------------------------------------------

if (!file.exists(meta_file)) {
  stop(
    "Metadata file not found: '", meta_file, "'\n",
    "  -> Download locations_treatments.csv from GitHub and place it in data_meta/."
  )
}

locations <- read_csv(
  meta_file,
  col_types = cols(
    Sensor_id = col_character(),
    Site      = col_character(),
    Treatment = col_character()
  ),
  show_col_types = FALSE
) |>
  # Rename to match the column name produced by read_sensor_file()
  rename(sensor_id = Sensor_id)

message("Metadata loaded: ", nrow(locations), " sensor(s) described.")


# -----------------------------------------------------------------------------
# 5. Merge sensor data with metadata
# -----------------------------------------------------------------------------
#
# left_join() keeps every row in sensor_data and attaches the matching
# Site and Treatment from locations. Sensor IDs not found in the metadata
# will have NA in those columns — we check for this below.

sensor_merged <- sensor_data |>
  left_join(locations, by = "sensor_id")


# -----------------------------------------------------------------------------
# 6. Integrity checks
# -----------------------------------------------------------------------------

# 6a. Any sensor IDs without metadata?
missing_meta <- sensor_merged |>
  filter(is.na(Treatment)) |>
  distinct(sensor_id)

if (nrow(missing_meta) > 0) {
  warning(
    "The following sensor IDs were found in data_raw/ but are MISSING from\n",
    "locations_treatments.csv. Their rows will have NA for Site and Treatment:\n",
    "  ", paste(missing_meta$sensor_id, collapse = ", "), "\n",
    "Add these IDs to ", meta_file, " before continuing."
  )
}

# 6b. Any datetime parse failures?
n_bad_dt <- sum(is.na(sensor_merged$datetime))
if (n_bad_dt > 0) {
  warning(n_bad_dt, " rows have NA datetimes (parse failures). ",
          "Check for non-standard date formats in your sensor files.")
}

# 6c. Quick summary
message("\nMerge complete. Summary by sensor:")
sensor_merged |>
  group_by(sensor_id, Site, Treatment) |>
  summarise(
    n_rows       = n(),
    date_start   = format(min(datetime, na.rm = TRUE), "%Y-%m-%d"),
    date_end     = format(max(datetime, na.rm = TRUE), "%Y-%m-%d"),
    mean_temp_C  = round(mean(temp_C, na.rm = TRUE), 1),
    .groups = "drop"
  ) |>
  print()


# -----------------------------------------------------------------------------
# 7. Save processed data
# -----------------------------------------------------------------------------

write_csv(sensor_merged, out_file)
message("\nSaved: ", out_file)
message("Columns: ", paste(names(sensor_merged), collapse = ", "))
message("Total rows: ", nrow(sensor_merged))


# -----------------------------------------------------------------------------
# 8. (Optional) Quick preview plot
#    Uncomment the block below to generate a time-series plot after merging.
# -----------------------------------------------------------------------------

# library(ggplot2)
#
# p <- ggplot(sensor_merged,
#             aes(x = datetime, y = temp_C,
#                 colour = Treatment, group = sensor_id)) +
#   geom_line(linewidth = 0.5, alpha = 0.8) +
#   facet_wrap(~ Site) +
#   scale_colour_manual(values = c(Shade = "#2d5a3d", Sun = "#c8832a")) +
#   labs(x = NULL, y = "Temperature (°C)",
#        title = "Sensor data — merged",
#        subtitle = "One line per sensor; faceted by site") +
#   theme_minimal(base_size = 12)
#
# print(p)
# ggsave("data_processed/quick_timeseries.png", p, width = 9, height = 4, dpi = 150)
# message("Quick plot saved: data_processed/quick_timeseries.png")


# =============================================================================
# End of read_and_merge.R
# =============================================================================
