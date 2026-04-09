############################################
# Camera trap analysis: 1-week dataset
############################################

# Provide a tutorial for students to evaluate 10 camera traps with ~12
# taxa and create effective graphics and some statistical tools that 
# can test various hypotheses.


library(tidyverse)
library(lubridate)
library(janitor)
# Path to your Excel file

file_path <- "/home/mwl04747/RTricks/15_Camera_Traps/Camera Trap Data Entry.xlsx"
# List all sheets
all_sheets <- excel_sheets(file_path)
cam_raw <- read_excel(
path  = file_path,
sheet = "Combined"
)


cam_raw$datetime <- cam_raw$Datetime_corrected

# ---- Starting point: cam_raw with datetime ----
# (from your code)

cam <- cam_raw %>%
  clean_names() %>%
  mutate(
    date = as.Date(datetime),
    hour = hour(datetime)
  )

# Quick sanity checks
stopifnot(!any(is.na(cam$datetime)))
summary(cam$date)

unique(cam_raw$Taxa_code)

ambiguous_patterns <- c(
  " and ",
  " or ",
  "/",
  "unknown",
  "unidentified",
  "n/a",
  "^na$",
  "bird$",
  "small brown bird"
)


cam_clean <- cam %>%
  filter(
    !str_detect(
      str_to_lower(taxa_code),
      paste(ambiguous_patterns, collapse = "|")
    )
  )

unique(cam_clean$taxa_code)

############################################
# 4. Collapse behaviors into functional types
############################################

unique(cam_clean$behavior_code)


cam <- cam_clean %>%
  mutate(
    behavior_function = case_when(
      str_detect(behavior_code, "walk|run|hop|fly|climb|crawl") ~ "movement",
      str_detect(behavior_code, "eat|dig|cache")                ~ "foraging",
      str_detect(behavior_code, "sniff")                        ~ "investigation",
      str_detect(behavior_code, "stare")                        ~ "vigilance",
      str_detect(behavior_code, "stop|stand|sit|lay")           ~ "stationary",
      TRUE                                                      ~ "other"
    )
  )

unique(cam$behavior_function)

############################################
# 1. Define independent detection events
#    (30-minute rule; camera x species)
############################################

cam_events <- cam %>%
  arrange(camera_id, taxa_code, datetime) %>%
  group_by(camera_id, taxa_code) %>%
  mutate(
    minutes_since_last = as.numeric(
      difftime(datetime, lag(datetime), units = "mins")
    ),
    new_event = if_else(
      is.na(minutes_since_last) | minutes_since_last > 30,
      1,
      0
    ),
    event_id = cumsum(new_event)
  ) %>%
  ungroup()

############################################
# 2. Event-level detection summary
############################################

event_summary <- cam_events %>%
  distinct(camera_id, taxa_code, event_id) %>%
  count(taxa_code, name = "detection_events") %>%
  arrange(desc(detection_events))

print(event_summary)

############################################
# 3. Ethogram: behavioral composition
#    (descriptive, not inferential)
############################################

ethogram <- cam_events %>%
  count(taxa_code, behavior_function) %>%
  group_by(taxa_code) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

ggplot(ethogram,
       aes(x = taxa_code,
           y = prop,
           fill = behavior_function)) +
  geom_col() +
  theme_bw() +
  ylab("Proportion of observed behaviors") +
  xlab("Taxon")


############################################
# 5. Day vs night behavior comparison
#    (descriptive shift, not hypothesis test)
############################################

cam_events <- cam_events %>%
  mutate(
    diel = if_else(hour >= 6 & hour < 18, "day", "night")
  )

behavior_diel <- cam_events %>%
  count(taxa_code, diel, behavior_function) %>%
  group_by(taxa_code, diel) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

ggplot(behavior_diel,
       aes(x = diel,
           y = prop,
           fill = behavior_function)) +
  geom_col() +
  facet_wrap(~ taxa_code) +
  theme_bw() +
  ylab("Proportion of behaviors") +
  xlab("Time of day")

############################################
# 6. Activity pattern by hour
############################################

ggplot(cam_events,
       aes(x = hour)) +
  geom_histogram(binwidth = 1, boundary = 0) +
  facet_wrap(~ taxa_code, scales = "free_y") +
  theme_bw() +
  xlab("Hour of day") +
  ylab("Number of detection events")

taxon_hour <- cam_events %>%
  distinct(taxa_code, event_id, hour) %>%
  count(taxa_code, hour, name = "events")

cam_events %>%
  distinct(taxa_code, event_id, hour) %>%
  count(taxa_code, hour, name = "events")


ggplot(taxon_hour,
       aes(x = hour,
           y = taxa_code,
           fill = events)) +
  geom_tile(color = "white") +
  scale_fill_viridis_c(option = "C") +
  theme_bw() +
  xlab("Hour of day") +
  ylab("Taxon") +
  ggtitle("Hourly detection patterns by taxon")

############################################
# 7. Camera-level descriptive patterns
############################################
unique(cam$camera_id)
camera_summary <- cam_events %>%
  distinct(camera_id, taxa_code, event_id) %>%
  count(camera_id, taxa_code)

print(camera_summary)

camera_behavior <- cam_events %>%
  distinct(camera_id, taxa_code, event_id, behavior_function) %>%
  count(camera_id, behavior_function, name = "events")

ggplot(camera_behavior,
       aes(x = camera_id,
           y = events,
           fill = behavior_function)) +
  geom_col() +
  theme_bw() +
  xlab("Camera ID") +
  ylab("Number of detection events") +
  ggtitle("Camera activity profiles by behavior function") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

############################################
# End of 1-week camera trap analysis
############################################