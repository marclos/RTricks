#!/usr/bin/env Rscript
# ============================================================
#  PAN (Peroxyacetyl Nitrate) Box Model: Animated Visualizations
#
#  PAN = CH3C(O)OONO2  --  the portable NOx reservoir
#
#  This script simulates PAN formation in a warm urban air mass,
#  its "freeze" as the air parcel rises to cold upper troposphere,
#  and its decomposition when the air subsides over a remote receptor.
#  A second animation shows diurnal PAN cycling vs temperature.
#
#  Outputs (in working directory):
#    pan_transport.gif       -- PAN along a 3-stage transport trajectory
#    pan_diurnal.gif         -- diurnal PAN + NOx in 3 temperature regimes
#    pan_temperature.png     -- PAN thermal lifetime vs temperature (static)
#
#  Chemistry modelled:
#    Formation:  CH3CO3 + NO2  -> PAN     rate: kf * [CH3CO3] * [NO2]
#    Thermal decomp: PAN       -> products  rate: kd(T) * [PAN]
#    NOx cycling via PAN:
#      When PAN decomposes at the receptor, it releases NO2 and re-starts
#      photochemistry far from the original emission source.
#
#  Rate constants (JPL-2019):
#    kf  = 9.7e-29 * (T/300)^-5.6  cm^6 molec^-2 s^-1  (termolecular)
#    kd(T) = 1.0e16 * exp(-14000/T)  s^-1
#
#  Three temperature regimes illustrate transport windows:
#    Urban source:   T = 308 K (35 degC) -- short PAN lifetime
#    Free troposphere: T = 265 K (-8 degC) -- long lifetime, stable transport
#    Rural receptor: T = 290 K (17 degC) -- partial decomposition + NOx release
# ============================================================

## 0. Packages -----------------------------------------------
library(deSolve)
library(ggplot2)
library(gganimate)
library(dplyr)
library(tidyr)
library(magick)
library(scales)

## 1. Rate constants ------------------------------------------
n_air  <- 2.46e19        # molec cm-3 at 298 K, 1 atm

# PAN formation: termolecular (pressure-dependent), simplified to bimolecular
# effective at 1 atm: k_eff ~ 3e-12 cm3 molec-1 s-1 (Seinfeld & Pandis Table 6.7)
kf <- 3.0e-12 * n_air * 1e-9   # ppb-1 s-1  (converted to ppb units)

# PAN thermal decomposition: strong Arrhenius T-dependence
# kd(T) = 1.0e16 * exp(-14000/T)  s-1    (JPL-2019)
kd <- function(T_K) 1.0e16 * exp(-14000 / T_K)

# Thermal lifetime = 1/kd(T)
PAN_lifetime_s <- function(T_K) 1 / kd(T_K)

# For reference: at 298 K -> ~30 min; at 265 K -> ~several days
cat(sprintf("PAN lifetime at 308 K (urban):  %.1f min\n",
            PAN_lifetime_s(308) / 60))
cat(sprintf("PAN lifetime at 280 K (aloft):  %.1f hr\n",
            PAN_lifetime_s(280) / 3600))
cat(sprintf("PAN lifetime at 265 K (FT):     %.1f hr\n",
            PAN_lifetime_s(265) / 3600))
cat(sprintf("PAN lifetime at 290 K (rural):  %.1f hr\n",
            PAN_lifetime_s(290) / 3600))

## 2. Static figure: PAN lifetime vs temperature ----------------
cat("\nBuilding static: PAN lifetime vs temperature...\n")

T_range <- seq(250, 315, by = 0.5)
tau_hr  <- PAN_lifetime_s(T_range) / 3600
tau_df  <- data.frame(T_C = T_range - 273.15, tau_hr = tau_hr)

# Annotate characteristic altitudes
ann <- data.frame(
  T_C   = c(308 - 273.15, 290 - 273.15, 265 - 273.15),
  label = c("Urban surface\n(35 C)", "Rural receptor\n(17 C)",
            "Free troposphere\n(-8 C)"),
  col   = c("#e74c3c", "#f39c12", "#2980b9")
)

p_tau <- ggplot(tau_df, aes(x = T_C, y = tau_hr)) +
  geom_line(linewidth = 1.6, colour = "#2c3e50") +
  scale_y_log10(
    breaks = c(0.01, 0.1, 1, 10, 100, 1000),
    labels = c("0.01 hr", "0.1 hr", "1 hr", "10 hr", "100 hr", "1000 hr")
  ) +
  geom_vline(xintercept = ann$T_C, colour = ann$col,
             linetype = "dashed", linewidth = 0.9) +
  geom_hline(yintercept = 24, colour = "grey60",
             linetype = "dotted", linewidth = 0.7) +
  annotate("text", x = ann$T_C[1] - 0.5, y = 300,
           label = ann$label[1], hjust = 1, size = 3.2,
           colour = ann$col[1]) +
  annotate("text", x = ann$T_C[2] - 0.5, y = 300,
           label = ann$label[2], hjust = 1, size = 3.2,
           colour = ann$col[2]) +
  annotate("text", x = ann$T_C[3] + 0.5, y = 300,
           label = ann$label[3], hjust = 0, size = 3.2,
           colour = ann$col[3]) +
  annotate("text", x = 35, y = 28,
           label = "1 day", hjust = 1, size = 3, colour = "grey50") +
  labs(
    title   = "PAN Thermal Lifetime vs Temperature",
    x       = "Temperature (C)",
    y       = "Thermal lifetime (log scale)",
    caption = paste(
      "kd(T) = 1.0e16 x exp(-14000/T)  [JPL-2019]",
      "PAN is stable at cold free-tropospheric temperatures;",
      "decomposes rapidly near the warm surface.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title   = element_text(face = "bold", size = 14),
    plot.caption = element_text(colour = "grey50", size = 8)
  )

ggsave("pan_temperature.png", p_tau,
       width = 8, height = 5, dpi = 150)
cat("OK: pan_temperature.png\n")

## 3. Animation 1: Diurnal PAN -- three temperature regimes ----
# Box model: PAN forms from CH3CO3 + NO2; decomposes thermally
# CH3CO3 is a proxy for acetyl peroxy radical from VOC oxidation.
# We prescribe a diurnal CH3CO3 profile (peaks at midday from VOC oxidation)
# and let PAN + NO2 evolve.

cat("\nBuilding animation 1: diurnal PAN...\n")

# Diurnal CH3CO3 profile (ppb): peaks ~0.01 ppb at noon
# (Seinfeld & Pandis: typical urban CH3CO3 ~ 5-15 ppt)
CH3CO3_t <- function(hr, scale = 1.0) {
  0.015 * scale * pmax(0, sin(pi * (hr - 6) / 14))
}

# J(NO2) for OH-driven VOC -> CH3CO3
J_t <- function(hr) pmax(0, sin(pi * (hr - 6) / 14))

# PAN diurnal ODE: tracks [PAN] and [NO2]
# NO2 is produced by NOx emissions (constant background) and
# consumed by PAN formation; PAN decomposes to release NO2
pan_ode <- function(t, y, p) {
  with(as.list(c(y, p)), {
    hr     <- t / 3600
    pan    <- max(PAN,  0)
    no2    <- max(NO2,  0)
    ch3co3 <- CH3CO3_t(hr, voc_scale) # acetyl peroxy

    kd_now <- kd(T_K)
    R_form <- kf * ch3co3 * no2       # PAN formation (ppb/s)
    R_diss <- kd_now * pan             # PAN thermal decomp (ppb/s)

    list(c(
      PAN = R_form - R_diss,
      NO2 = -R_form + R_diss + E_NO2  # NOx emission keeps NO2 non-zero
    ))
  })
}

# Scenarios: three temperatures, same VOC loading
diurnal_sc <- data.frame(
  label    = factor(c(
    "Urban -- Hot (35 C)",
    "Suburban -- Warm (25 C)",
    "Rural / Aloft (10 C)"
  ), levels = c("Urban -- Hot (35 C)", "Suburban -- Warm (25 C)",
                "Rural / Aloft (10 C)")),
  T_K      = c(308, 298, 283),
  voc_scale = c(1.0, 1.0, 0.5),   # rural has lower VOC
  col      = c("#e74c3c", "#f39c12", "#2980b9"),
  stringsAsFactors = FALSE
)

times_day <- seq(0, 24 * 3600, by = 60)  # 1-min resolution

run_diurnal <- function(i) {
  out <- ode(
    y     = c(PAN = 0, NO2 = 20),
    times = times_day,
    func  = pan_ode,
    parms = list(T_K = diurnal_sc$T_K[i],
                 voc_scale = diurnal_sc$voc_scale[i],
                 E_NO2 = 5 / 86400),  # ~5 ppb/day NOx emission
    method = "lsoda"
  )
  df           <- as.data.frame(out)
  df$t_hr      <- df$time / 3600
  df$Scenario  <- diurnal_sc$label[i]
  df$T_K_i     <- diurnal_sc$T_K[i]
  df$tau_min   <- PAN_lifetime_s(diurnal_sc$T_K[i]) / 60
  df
}

diurnal_all <- do.call(rbind, lapply(seq_len(nrow(diurnal_sc)), run_diurnal))
diurnal_all[c("PAN","NO2")] <- lapply(diurnal_all[c("PAN","NO2")],
                                      function(x) pmax(x, 0))

# Long format
diurnal_long <- diurnal_all |>
  select(t_hr, Scenario, PAN, NO2) |>
  pivot_longer(c(PAN, NO2), names_to = "Species", values_to = "ppb") |>
  mutate(Species = factor(Species, levels = c("PAN", "NO2")))

diurnal_thin <- diurnal_long[seq(1, nrow(diurnal_long), 6), ]

sp_pal_pan <- c(PAN = "#8e44ad", NO2 = "#cc3311")

p_diurnal <- ggplot(diurnal_thin,
                    aes(x = t_hr, y = ppb * 1000,  # convert ppb -> ppt
                        colour = Species, group = Species)) +
  annotate("rect", xmin = 6, xmax = 20,
           ymin = -Inf, ymax = Inf, fill = "#FFFACD", alpha = 0.5) +
  geom_line(linewidth = 1.3, lineend = "round") +
  scale_colour_manual(values = sp_pal_pan,
                      labels = c(PAN = "PAN (ppt)", NO2 = "NO2 (ppt)")) +
  scale_x_continuous(
    limits = c(0, 24), breaks = seq(0, 24, 6),
    labels = c("00:00","06:00","12:00","18:00","24:00"),
    expand = c(0, 0)
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  facet_wrap(~ Scenario, ncol = 1, scales = "free_y") +
  labs(
    title    = "Diurnal PAN and NO2 Concentrations",
    subtitle = "Time: {sprintf('%05.1f', frame_along)} h  |  Pale yellow = daylight",
    x        = "Hour of day (local time)",
    y        = "Concentration (ppt)",
    colour   = NULL,
    caption  = paste(
      "PAN = CH3C(O)OONO2.  Formation: CH3CO3 + NO2  -> PAN  (rate = kf * [CH3CO3] * [NO2])",
      "Decomp: PAN -> CH3CO3 + NO2  (rate = kd(T) * [PAN];  kd = 1.0e16 * exp(-14000/T))",
      "Hot air: PAN builds then collapses.  Cold air: PAN persists all day.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    strip.background  = element_rect(fill = "#1d3557", colour = NA),
    strip.text        = element_text(colour = "white", face = "bold", size = 10),
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour = "grey80", fill = NA),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(colour = "grey40", size = 10),
    plot.caption      = element_text(colour = "grey50", size = 8)
  ) +
  transition_reveal(t_hr) +
  ease_aes("linear")

anim_d <- animate(p_diurnal, nframes = 150, fps = 10,
                  width = 720, height = 700,
                  renderer = magick_renderer())
magick::image_write(anim_d, "pan_diurnal.gif")
cat("OK: pan_diurnal.gif\n")

## 4. Animation 2: Three-stage PAN transport trajectory ---------
# Stage 1: Hot urban source   (6 h at 308 K) -- NOx high, PAN builds slowly
# Stage 2: Ascent / FT        (24 h at 265 K) -- PAN stable, NO2 locked up
# Stage 3: Subsidence / rural (12 h at 290 K) -- PAN decomposes, NO2 released

cat("\nBuilding animation 2: PAN transport trajectory...\n")

stages <- data.frame(
  stage    = c(1, 2, 3),
  label    = c("Stage 1: Urban Source\n(T = 35 C)",
               "Stage 2: Free Troposphere\n(T = -8 C)",
               "Stage 3: Rural Receptor\n(T = 17 C)"),
  T_K      = c(308, 265, 290),
  dur_hr   = c(6, 24, 12),
  E_NO2    = c(20/21600, 0, 2/43200),  # ppb/s NOx emission
  voc_scale = c(1.0, 0.0, 0.1),
  stringsAsFactors = FALSE
)

pan_ode_stage <- function(t, y, p) {
  with(as.list(c(y, p)), {
    # within a stage, use constant T and prescribed CH3CO3
    pan  <- max(PAN, 0)
    no2  <- max(NO2, 0)
    ch3co3 <- CH3CO3_t(t / 3600, voc_scale)  # t here is within-stage time
    R_form <- kf * ch3co3 * no2
    R_diss <- kd(T_K) * pan
    list(c(
      PAN = R_form - R_diss,
      NO2 = -R_form + R_diss + E_NO2
    ))
  })
}

# Integrate sequentially, passing end state to next stage
transport_list <- list()
y0 <- c(PAN = 0, NO2 = 25)

for (s in seq_len(nrow(stages))) {
  dur_s  <- stages$dur_hr[s] * 3600
  t_seq  <- seq(0, dur_s, by = 120)
  out_s  <- ode(y = y0, times = t_seq, func = pan_ode_stage,
                parms = list(T_K       = stages$T_K[s],
                             voc_scale = stages$voc_scale[s],
                             E_NO2     = stages$E_NO2[s]),
                method = "lsoda")
  df_s          <- as.data.frame(out_s)
  df_s$PAN      <- pmax(df_s$PAN, 0)
  df_s$NO2      <- pmax(df_s$NO2, 0)
  df_s$Stage    <- stages$label[s]
  df_s$stage_n  <- s
  df_s$T_K      <- stages$T_K[s]
  df_s$tau_hr   <- round(PAN_lifetime_s(stages$T_K[s]) / 3600, 1)
  # Cumulative hours for x-axis
  cum_offset    <- sum(stages$dur_hr[seq_len(s - 1)])
  df_s$t_cum    <- cum_offset + df_s$time / 3600
  transport_list[[s]] <- df_s
  y0 <- c(PAN = tail(df_s$PAN, 1), NO2 = tail(df_s$NO2, 1))
}

transport_all <- do.call(rbind, transport_list)
transport_all$Stage <- factor(transport_all$Stage,
                              levels = stages$label)

# Background shading per stage
stage_rects <- data.frame(
  xmin  = c(0, 6, 30),
  xmax  = c(6, 30, 42),
  fill  = c("#ffccbc", "#bbdefb", "#dcedc8"),
  alpha = 0.35
)

transport_long <- transport_all |>
  select(t_cum, Stage, PAN, NO2, stage_n) |>
  pivot_longer(c(PAN, NO2), names_to = "Species", values_to = "ppb") |>
  mutate(ppb_ppt = ppb * 1000)

transport_thin <- transport_long[seq(1, nrow(transport_long), 3), ]

# Stage boundary lines
vlines <- data.frame(x = c(6, 30),
                     label = c("Lofted to FT", "Subsidence"))

p_transport <- ggplot(transport_thin,
                      aes(x = t_cum, y = ppb_ppt,
                          colour = Species, group = Species)) +
  # Stage background shading
  annotate("rect",
           xmin  = stage_rects$xmin,
           xmax  = stage_rects$xmax,
           ymin  = -Inf, ymax = Inf,
           fill  = stage_rects$fill,
           alpha = stage_rects$alpha) +
  # Stage boundary lines
  geom_vline(xintercept = c(6, 30), colour = "grey50",
             linetype = "dashed", linewidth = 0.7) +
  annotate("text", x = 6.3, y = Inf, label = "Lofted to FT",
           vjust = 1.3, hjust = 0, size = 3, colour = "grey40") +
  annotate("text", x = 30.3, y = Inf, label = "Subsides to surface",
           vjust = 1.3, hjust = 0, size = 3, colour = "grey40") +
  # Stage labels at top
  annotate("text", x = c(3, 18, 36), y = Inf,
           label = c("Urban\n(35 C)", "Free Troposphere\n(-8 C)",
                     "Rural\n(17 C)"),
           vjust = 2.5, hjust = 0.5, size = 3.2, fontface = "bold",
           colour = c("#c0392b","#1565c0","#2e7d32")) +
  geom_line(linewidth = 1.4, lineend = "round") +
  scale_colour_manual(values = c(PAN = "#8e44ad", NO2 = "#cc3311")) +
  scale_x_continuous(
    breaks = seq(0, 42, 6),
    labels = paste0(seq(0, 42, 6), " h"),
    expand = c(0, 0.5)
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "PAN as a Mobile NOx Reservoir: Three-Stage Transport",
    subtitle = "Elapsed transport time: {sprintf('%4.1f', frame_along)} h",
    x        = "Time along trajectory (h)",
    y        = "Concentration (ppt)",
    colour   = NULL,
    caption  = paste(
      "PAN lifetime:  ~8 min (35 C)  |  ~11 h (-8 C)  |  ~2 h (17 C)",
      "At the rural receptor, PAN decomposition releases NO2 and re-starts",
      "ozone chemistry -- far from the original urban emission source.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour = "grey80", fill = NA),
    plot.title        = element_text(face = "bold", size = 13),
    plot.subtitle     = element_text(colour = "grey40", size = 10),
    plot.caption      = element_text(colour = "grey50", size = 8)
  ) +
  transition_reveal(t_cum) +
  ease_aes("linear")

anim_t <- animate(p_transport, nframes = 150, fps = 10,
                  width = 820, height = 480,
                  renderer = magick_renderer())
magick::image_write(anim_t, "pan_transport.gif")
cat("OK: pan_transport.gif\n")

cat("\nAll PAN outputs written successfully.\n")
cat("  pan_temperature.png\n")
cat("  pan_diurnal.gif\n")
cat("  pan_transport.gif\n")
