#!/usr/bin/env Rscript
# ============================================================
#  PAN (Peroxyacetyl Nitrate) Box Model: Animated Visualizations
#  VERSION 2 -- fixes gganim_plot0001.png rendering crash
#
#  Root cause of crash: at t=0, all values are at or near zero.
#  expand = c(0, 0.1) with free_y facets produces a zero-height
#  y-axis on frame 1, which gganimate cannot render to PNG.
#  Fixes applied:
#    1. Remove scales = "free_y" from facet_wrap (shared fixed scale)
#    2. Use coord_cartesian(ylim) instead of scale limits to avoid
#       dropped data warnings
#    3. expand = expansion(mult = c(0.05, 0.12)) on both animations
#    4. Initial PAN set to small positive value (1e-4 ppb) so the
#       ODE solver never hands a pure-zero state to ggplot frame 1
#    5. Transport animation: y lower bound clipped via coord_cartesian
#       so the geom_rect annotate(-Inf) does not collapse the axis
#
#  Outputs (run from ~/EJnPi or any directory with write access):
#    pan_temperature.png   -- static Arrhenius lifetime curve
#    pan_diurnal.gif       -- diurnal PAN + NO2 in 3 T regimes
#    pan_transport.gif     -- 3-stage urban -> FT -> rural trajectory
#
#  Chemistry:
#    Formation:    CH3CO3 + NO2 -> PAN      kf * [CH3CO3][NO2]
#    Decomposition: PAN -> CH3CO3 + NO2     kd(T) * [PAN]
#    kd(T) = 1.0e16 * exp(-14000/T)  s-1   (JPL-2019)
#    kf    ~ 3e-12 cm3 molec-1 s-1 at 1 atm (effective bimolecular)
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
n_air  <- 2.46e19          # molec cm-3 at 298 K, 1 atm
ppb_cf <- n_air * 1e-9     # converts cm3 molec-1 s-1 -> ppb-1 s-1

kf <- 3.0e-12 * ppb_cf    # PAN formation  (ppb-1 s-1)

kd <- function(T_K) 1.0e16 * exp(-14000 / T_K)   # decomp (s-1)
PAN_lifetime_s <- function(T_K) 1 / kd(T_K)

# Print reference lifetimes
cat("PAN thermal lifetimes:\n")
for (T in c(308, 298, 290, 283, 265)) {
  tau <- PAN_lifetime_s(T)
  unit <- if (tau < 3600) sprintf("%.1f min", tau / 60) else
          sprintf("%.1f hr",  tau / 3600)
  cat(sprintf("  T = %d K (%+.0f C): %s\n", T, T - 273, unit))
}

# Diurnal CH3CO3 (acetyl peroxy radical) profile:
# peaks ~15 ppt at noon, zero at night.  Seinfeld & Pandis Table 6.7.
CH3CO3_t <- function(hr, voc_scale = 1.0) {
  0.015 * voc_scale * pmax(0, sin(pi * (hr - 6) / 14))
}

## 2. Static: PAN lifetime curve --------------------------------
cat("\nBuilding pan_temperature.png ...\n")

T_seq  <- seq(250, 315, by = 0.5)
tau_df <- data.frame(T_C   = T_seq - 273.15,
                     tau_hr = PAN_lifetime_s(T_seq) / 3600)

refs <- data.frame(
  T_C   = c(35, 17, -8),
  label = c("Urban (35 C)", "Rural receptor (17 C)", "Free troposphere (-8 C)"),
  col   = c("#e74c3c", "#f39c12", "#2980b9"),
  hjust = c(1, 1, 0)
)

p_tau <- ggplot(tau_df, aes(x = T_C, y = tau_hr)) +
  geom_line(linewidth = 1.6, colour = "#2c3e50") +
  scale_y_log10(
    breaks = 10^seq(-2, 3),
    labels = c("0.01 hr","0.1 hr","1 hr","10 hr","100 hr","1000 hr")
  ) +
  geom_vline(xintercept = refs$T_C, colour = refs$col,
             linetype = "dashed", linewidth = 0.9) +
  geom_hline(yintercept = 24, colour = "grey60",
             linetype = "dotted", linewidth = 0.7) +
  annotate("text", x = refs$T_C, y = 300, label = refs$label,
           hjust = refs$hjust + c(-0.05, -0.05, 0.05),
           vjust = 0.5, size = 3.1, colour = refs$col) +
  annotate("text", x = 38, y = 28,
           label = "1 day", hjust = 1, size = 3, colour = "grey45") +
  labs(
    title   = "PAN Thermal Lifetime vs Temperature",
    x       = "Temperature (C)",
    y       = "Thermal lifetime (log scale)",
    caption = paste(
      "kd(T) = 1.0e16 * exp(-14000 / T)   [JPL-2019]",
      "PAN is stable at cold free-tropospheric temperatures;",
      "decomposes in minutes near the warm surface.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title   = element_text(face = "bold", size = 14),
        plot.caption = element_text(colour = "grey50", size = 8,
                                    lineheight = 1.3))

ggsave("pan_temperature.png", p_tau, width = 8, height = 5, dpi = 150)
cat("OK: pan_temperature.png\n")

## 3. ODE: diurnal PAN + NO2 -------------------------------------
pan_ode_diurnal <- function(t, y, p) {
  with(as.list(c(y, p)), {
    hr     <- t / 3600
    pan    <- max(PAN,  0)
    no2    <- max(NO2,  0)
    acc    <- CH3CO3_t(hr, voc_scale)
    R_form <- kf * acc * no2
    R_diss <- kd(T_K) * pan
    list(c(
      PAN = R_form - R_diss,
      NO2 = -R_form + R_diss + E_NO2
    ))
  })
}

diurnal_sc <- data.frame(
  label = factor(
    c("Urban -- Hot (35 C)",
      "Suburban -- Warm (25 C)",
      "Rural / Aloft (10 C)"),
    levels = c("Urban -- Hot (35 C)",
               "Suburban -- Warm (25 C)",
               "Rural / Aloft (10 C)")
  ),
  T_K       = c(308, 298, 283),
  voc_scale = c(1.0, 1.0, 0.5),
  stringsAsFactors = FALSE
)

times_day <- seq(0, 24 * 3600, by = 60)

# FIX 4: initial PAN = 1e-4 ppb (not 0) so frame-1 y-axis is non-degenerate
run_diurnal <- function(i) {
  out <- ode(
    y      = c(PAN = 1e-4, NO2 = 20),
    times  = times_day,
    func   = pan_ode_diurnal,
    parms  = list(T_K       = diurnal_sc$T_K[i],
                  voc_scale = diurnal_sc$voc_scale[i],
                  E_NO2     = 5 / 86400),
    method = "lsoda"
  )
  df          <- as.data.frame(out)
  df$t_hr     <- df$time / 3600
  df$Scenario <- diurnal_sc$label[i]
  df
}

cat("\nRunning diurnal ODE simulations...\n")
diurnal_all <- do.call(rbind, lapply(seq_len(nrow(diurnal_sc)), run_diurnal))
diurnal_all[c("PAN","NO2")] <- lapply(diurnal_all[c("PAN","NO2")],
                                       function(x) pmax(x, 0))

# Diagnostic
cat(sprintf("  Rows: %d  |  PAN [%.4f, %.2f] ppb  |  NO2 [%.2f, %.2f] ppb\n",
            nrow(diurnal_all),
            min(diurnal_all$PAN), max(diurnal_all$PAN),
            min(diurnal_all$NO2), max(diurnal_all$NO2)))

diurnal_long <- diurnal_all |>
  select(t_hr, Scenario, PAN, NO2) |>
  pivot_longer(c(PAN, NO2), names_to = "Species", values_to = "ppb") |>
  mutate(
    Species = factor(Species, levels = c("PAN","NO2")),
    ppt     = ppb * 1000   # ppb -> ppt for display
  )

# Thin to every 6th row for animation speed
diurnal_thin <- diurnal_long[seq(1, nrow(diurnal_long), 6), ]

# Global y ceiling so shared scale is sensible
y_ceil_d <- ceiling(max(diurnal_thin$ppt) * 1.15)

cat("\nBuilding pan_diurnal.gif ...\n")

p_diurnal <- ggplot(diurnal_thin,
                    aes(x = t_hr, y = ppt,
                        colour = Species, group = Species)) +
  # Daylight shading
  annotate("rect", xmin = 6, xmax = 20,
           ymin = -Inf, ymax = Inf, fill = "#FFFACD", alpha = 0.5) +
  geom_line(linewidth = 1.3, lineend = "round") +
  scale_colour_manual(
    values = c(PAN = "#8e44ad", NO2 = "#cc3311"),
    labels = c(PAN = "PAN", NO2 = "NO2")
  ) +
  scale_x_continuous(
    limits = c(0, 24),
    breaks = seq(0, 24, 6),
    labels = c("00:00","06:00","12:00","18:00","24:00"),
    expand = c(0, 0)
  ) +
  # FIX 1+3: no free_y; fixed shared scale; 5% lower expansion
  scale_y_continuous(
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  # FIX 2: coord_cartesian clips without dropping data or collapsing axis
  coord_cartesian(ylim = c(0, y_ceil_d)) +
  # FIX 1: single-column facets with FIXED shared scale
  facet_wrap(~ Scenario, ncol = 1) +
  labs(
    title    = "Diurnal PAN and NO2 Concentrations",
    subtitle = "Time: {sprintf('%05.1f', frame_along)} h  |  Pale yellow = daylight",
    x        = "Hour of day (local time)",
    y        = "Concentration (ppt)",
    colour   = NULL,
    caption  = paste(
      "PAN = CH3C(O)OONO2",
      "Formation: CH3CO3 + NO2 -> PAN  |  kf ~ 3e-12 cm3 molec-1 s-1",
      "Decomp: PAN -> CH3CO3 + NO2     |  kd(T) = 1.0e16 * exp(-14000/T)",
      "Hot air: PAN builds and collapses within hours.  Cold air: PAN persists all day.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "top",
    legend.key.width = unit(1.2, "cm"),
    strip.background = element_rect(fill = "#1d3557", colour = NA),
    strip.text       = element_text(colour = "white", face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    panel.border     = element_rect(colour = "grey80", fill = NA),
    plot.title       = element_text(face = "bold", size = 14),
    plot.subtitle    = element_text(colour = "grey40", size = 10),
    plot.caption     = element_text(colour = "grey50", size = 8,
                                    lineheight = 1.3)
  ) +
  transition_reveal(t_hr) +
  ease_aes("linear")

anim_d <- animate(p_diurnal,
                  nframes = 150, fps = 10,
                  width = 720, height = 680,
                  renderer = magick_renderer())
magick::image_write(anim_d, "pan_diurnal.gif")
cat("OK: pan_diurnal.gif\n")

## 4. ODE: three-stage transport trajectory ----------------------
# Stage 1: Urban source     6 h at 308 K  -- PAN forms, NO2 consumed
# Stage 2: Free troposphere 24 h at 265 K -- PAN frozen, transport
# Stage 3: Rural receptor   12 h at 290 K -- PAN decomposes, NO2 released

pan_ode_stage <- function(t, y, p) {
  with(as.list(c(y, p)), {
    pan    <- max(PAN, 0)
    no2    <- max(NO2, 0)
    acc    <- CH3CO3_t(t / 3600, voc_scale)
    R_form <- kf * acc * no2
    R_diss <- kd(T_K) * pan
    list(c(
      PAN = R_form - R_diss,
      NO2 = -R_form + R_diss + E_NO2
    ))
  })
}

stages <- data.frame(
  label     = c("Urban Source (35 C)",
                "Free Troposphere (-8 C)",
                "Rural Receptor (17 C)"),
  T_K       = c(308,      265,   290),
  dur_hr    = c(6,        24,    12),
  E_NO2_pph = c(20,       0,     2),      # ppb/hr NOx emission (rough)
  voc_scale = c(1.0,      0.0,   0.1),
  stringsAsFactors = FALSE
)
stages$E_NO2 <- stages$E_NO2_pph / 3600   # convert to ppb/s

cat("\nRunning transport ODE stages...\n")
transport_list <- list()
# FIX 4 applied here too: non-zero initial PAN
y0 <- c(PAN = 1e-4, NO2 = 25)

for (s in seq_len(nrow(stages))) {
  t_seq <- seq(0, stages$dur_hr[s] * 3600, by = 120)
  out_s <- ode(
    y      = y0,
    times  = t_seq,
    func   = pan_ode_stage,
    parms  = list(T_K       = stages$T_K[s],
                  voc_scale = stages$voc_scale[s],
                  E_NO2     = stages$E_NO2[s]),
    method = "lsoda"
  )
  df_s         <- as.data.frame(out_s)
  df_s$PAN     <- pmax(df_s$PAN, 0)
  df_s$NO2     <- pmax(df_s$NO2, 0)
  df_s$Stage   <- stages$label[s]
  df_s$stage_n <- s
  df_s$t_cum   <- sum(stages$dur_hr[seq_len(s - 1)]) + df_s$time / 3600
  transport_list[[s]] <- df_s
  y0 <- c(PAN = tail(df_s$PAN, 1), NO2 = tail(df_s$NO2, 1))
  cat(sprintf("  Stage %d done: final PAN=%.2f ppt  NO2=%.2f ppb\n",
              s, tail(df_s$PAN,1)*1000, tail(df_s$NO2,1)))
}

transport_all <- do.call(rbind, transport_list)

transport_long <- transport_all |>
  select(t_cum, Stage, PAN, NO2, stage_n) |>
  pivot_longer(c(PAN, NO2), names_to = "Species", values_to = "ppb") |>
  mutate(ppt = ppb * 1000)

transport_thin <- transport_long[seq(1, nrow(transport_long), 3), ]

# y ceiling for coord_cartesian
y_ceil_t <- ceiling(max(transport_thin$ppt) * 1.15)

# Stage shading rectangles
stage_bg <- data.frame(
  xmin  = c(0,  6, 30),
  xmax  = c(6, 30, 42),
  fill  = c("#ffccbc", "#bbdefb", "#dcedc8"),
  stringsAsFactors = FALSE
)

cat("\nBuilding pan_transport.gif ...\n")

p_transport <- ggplot(transport_thin,
                      aes(x = t_cum, y = ppt,
                          colour = Species, group = Species)) +
  # Stage background shading -- use finite ymin/ymax to avoid -Inf issue
  annotate("rect",
           xmin  = stage_bg$xmin, xmax = stage_bg$xmax,
           ymin  = 0,             ymax = y_ceil_t,
           fill  = stage_bg$fill, alpha = 0.4) +
  geom_vline(xintercept = c(6, 30), colour = "grey55",
             linetype = "dashed", linewidth = 0.7) +
  # Stage labels -- placed at fixed y = y_ceil_t * 0.97 to avoid Inf
  annotate("text",
           x     = c(3, 18, 36),
           y     = y_ceil_t * 0.97,
           label = c("Urban\n(35 C)", "Free Troposphere\n(-8 C)", "Rural\n(17 C)"),
           vjust = 1, hjust = 0.5, size = 3.2, fontface = "bold",
           colour = c("#c0392b","#1565c0","#2e7d32")) +
  annotate("text",
           x = c(6.4, 30.4), y = y_ceil_t * 0.85,
           label = c("Lofted", "Subsides"),
           hjust = 0, size = 2.8, colour = "grey40") +
  geom_line(linewidth = 1.4, lineend = "round") +
  scale_colour_manual(
    values = c(PAN = "#8e44ad", NO2 = "#cc3311")
  ) +
  scale_x_continuous(
    breaks = seq(0, 42, 6),
    labels = paste0(seq(0, 42, 6), " h"),
    expand = c(0, 0.5)
  ) +
  # FIX 3+5: positive lower expansion; coord_cartesian for clipping
  scale_y_continuous(
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  coord_cartesian(ylim = c(0, y_ceil_t)) +
  labs(
    title    = "PAN as a Mobile NOx Reservoir: Three-Stage Transport",
    subtitle = "Elapsed time: {sprintf('%4.1f', frame_along)} h",
    x        = "Time along trajectory (h)",
    y        = "Concentration (ppt)",
    colour   = NULL,
    caption  = paste(
      "Stage 1: Urban source at 35 C -- PAN lifetime ~8 min",
      "Stage 2: Free troposphere at -8 C -- PAN lifetime ~11 h  (NOx locked up)",
      "Stage 3: Rural receptor at 17 C -- PAN decomposes, NO2 released, O3 chemistry restarts",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "top",
    legend.key.width = unit(1.2, "cm"),
    panel.grid.minor = element_blank(),
    panel.border     = element_rect(colour = "grey80", fill = NA),
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(colour = "grey40", size = 10),
    plot.caption     = element_text(colour = "grey50", size = 8,
                                    lineheight = 1.3)
  ) +
  transition_reveal(t_cum) +
  ease_aes("linear")

anim_t <- animate(p_transport,
                  nframes = 150, fps = 10,
                  width = 820, height = 480,
                  renderer = magick_renderer())
magick::image_write(anim_t, "pan_transport.gif")
cat("OK: pan_transport.gif\n")

cat("\nAll outputs written:\n")
cat("  pan_temperature.png\n")
cat("  pan_diurnal.gif\n")
cat("  pan_transport.gif\n")
