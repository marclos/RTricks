#!/usr/bin/env Rscript
# ============================================================
#  NOx-O3 Photochemical Box Model: Animated Visualizations
#
#  Outputs (in working directory):
#    nox_concentrations.gif  -- diurnal [NO], [NO2], [O3] for 4 scenarios
#    nox_rates.gif           -- O3 production vs consumption rates
#    nox_cycle_diagram.png   -- annotated reaction cycle schematic
#
#  Chemistry modelled:
#    R1: NO2 + hv  -> NO + O3   (J*[NO2], the O3 SOURCE)
#    R3: NO  + O3  -> NO2 + O2  (k3*[NO]*[O3], the O3 SINK)
#    Rv: RO2 + NO  -> NO2 + RO  (kv*[RO2]*[NO], VOC peroxy pathway)
#       ^ Rv shifts NO->NO2 WITHOUT consuming O3 -- key to VOC ozone formation
#
#  Photostationary steady state (R1 = R3):
#    [O3]_ss = J*[NO2] / (k3*[NO])
#
#  Scenarios show the effect of:
#    - Temperature  (higher T -> faster k3 -> lower [O3]_ss)
#    - Light / UV   (higher J -> faster R1 -> higher [O3]_ss and faster cycling)
#    - VOC loading  (RO2 builds up NO2/NO ratio -> higher [O3] without consuming O3)
# ============================================================

## 0. Packages -----------------------------------------------
library(deSolve)
library(ggplot2)
library(gganimate)
library(dplyr)
library(tidyr)
library(magick)
library(scales)

## 1. Constants & Rate Functions -----------------------------
n_air  <- 2.46e19          # molec cm-3 at 298 K, 1 atm
ppb_cf <- n_air * 1e-9     # factor: cm3/molec/s -> ppb-1 s-1

# k(NO + O3 -> NO2): Arrhenius, JPL-2019 recommendation
# k = 3.0x10-12 x exp(-1500/T)  cm3 molec-1 s-1
k_NO_O3 <- function(T) 3.0e-12 * exp(-1500 / T) * ppb_cf

# k(RO2 + NO -> NO2): fast, weak T-dependence
kv <- 8.0e-12 * ppb_cf   # ppb-1 s-1

# PM2.5 formation rate constants
# k_nit: OH + NO2 -> HNO3 -> nitrate aerosol (simplified, effective)
#   JPL: ~3.6e-11 cm3/molec/s at 1 atm -> ppb-1 s-1
k_nit <- 3.6e-11 * ppb_cf              # ppb-1 s-1  (NO2 + OH -> HNO3)
# k_soa: RO2 oxidation products partition to aerosol
#   crude yield: ~5% of Rv reaction mass goes to SOA (Hallquist et al.)
soa_yield <- 0.05                       # dimensionless yield
# PM2.5 dry deposition lifetime ~12 h (urban surface)
k_dep <- 1 / (12 * 3600)               # s-1

# J(NO2): sinusoidal over 06:00-20:00; zero at night
J_t <- function(hr, Jmax) Jmax * pmax(0, sin(pi * (hr - 6) / 14))

# [OH] diurnal: peaks ~2e6 molec/cm3 at noon (Seinfeld & Pandis)
# Converted to ppb-equivalent for rate calcs: 1 ppb = n_air*1e-9 molec/cm3
OH_t <- function(hr) {
  oh_peak <- 2e6 / (2.46e19 * 1e-9)   # ~8e-5 ppb at 298 K
  oh_peak * pmax(0, sin(pi * (hr - 6) / 14))
}

## 2. ODE Box Model ------------------------------------------
nox_ode <- function(t, y, p) {
  with(as.list(c(y, p)), {
    J   <- J_t(t / 3600, Jmax)         # current photolysis rate
    k3  <- k_NO_O3(T_K)                # T-dependent rate constant
    oh  <- OH_t(t / 3600)              # [OH] in ppb-equivalent
    # clamp to zero
    no  <- max(NO,   0)
    no2 <- max(NO2,  0)
    o3  <- max(O3,   0)
    pm  <- max(PM25, 0)

    R1  <- J  * no2                    # photolysis  -- O3 source
    R3  <- k3 * no * o3                # titration   -- O3 + NO sink
    Rv  <- kv * RO2 * no               # VOC peroxy  -- no O3 loss

    # PM2.5 sources:
    #   P_nit: OH + NO2 -> HNO3 -> nitrate aerosol (daytime only)
    #   P_soa: fraction of VOC oxidation (Rv) yields SOA
    P_nit <- k_nit * oh * no2          # ppb/s  (secondary inorganic)
    P_soa <- soa_yield * Rv            # ppb/s  (secondary organic)
    P_pm  <- P_nit + P_soa
    L_pm  <- k_dep * pm                # deposition loss

    list(c(
      NO   =  R1 - R3 - Rv,
      NO2  = -R1 + R3 + Rv,
      O3   =  R1 - R3,
      PM25 =  P_pm - L_pm
    ))
  })
}

## 3. Scenarios -----------------------------------------------
# Initial conditions: early-morning rush-hour profile (ppb)
init  <- c(NO = 15, NO2 = 30, O3 = 15, PM25 = 2)

# Time vector: one full day at 2-min resolution
times <- seq(0, 24 * 3600, by = 120)

# RO2 = 0.05 ppb for the VOC scenario -- typical high-NOx urban peroxy radical burden
sc <- data.frame(
  label = c(
    "Base Case\nT=298 K, J0, no VOC",
    "High Temperature\nT=313 K (+15 degC)",
    "Stronger UV\nJ x 1.5  (cloud-free)",
    "High VOC Loading\n[RO2] = 0.05 ppb"
  ),
  T_K  = c(298, 313, 298, 298),
  Jmax = c(8e-3, 8e-3, 1.2e-2, 8e-3),
  RO2  = c(0,   0,    0,       0.05),
  stringsAsFactors = FALSE
)
sc$label <- factor(sc$label, levels = sc$label)  # preserve order

run_scenario <- function(i) {
  out <- ode(
    y      = init,
    times  = times,
    func   = nox_ode,
    parms  = list(T_K  = sc$T_K[i],
                  Jmax = sc$Jmax[i],
                  RO2  = sc$RO2[i]),
    method = "lsoda"
  )
  df           <- as.data.frame(out)
  df$t_hr      <- df$time / 3600
  df$Scenario  <- sc$label[i]
  df$sci       <- i
  df$T_K_i     <- sc$T_K[i]
  df$Jmax_i    <- sc$Jmax[i]
  df$RO2_i     <- sc$RO2[i]
  df
}

message("Running ODE simulations...")
all_df <- do.call(rbind, lapply(seq_len(nrow(sc)), run_scenario))
all_df[c("NO","NO2","O3","PM25")] <- lapply(all_df[c("NO","NO2","O3","PM25")],
                                      function(x) pmax(x, 0))

# Compute rates
all_df <- all_df |>
  mutate(
    J_now = mapply(J_t, t_hr, Jmax_i),
    k3    = sapply(T_K_i, k_NO_O3),
    R1    = J_now * NO2,              # O3 production (ppb/s)
    R3    = k3 * NO * O3,             # O3 destruction (ppb/s)
    Rv    = kv * RO2_i * NO,          # VOC contribution (ppb/s)
    Net   = R1 - R3                   # net O3 production rate
  )

message("Simulations complete.")

## 4. ANIMATION 1: Diurnal Concentration Time Series --------
message("Building animation 1: concentrations...")

sp_pal  <- c(O3 = "#E69F00", NO2 = "#CC3311", NO = "#0077BB",
             PM25 = "#9B59B6")
sp_labs <- c(O3 = "O3", NO2 = "NO2", NO = "NO", PM25 = "PM2.5")

long_sp <- all_df |>
  select(t_hr, NO, NO2, O3, PM25, Scenario) |>
  pivot_longer(c(NO, NO2, O3, PM25),
               names_to  = "Species",
               values_to = "ppb") |>
  mutate(Species = factor(Species, levels = c("O3","NO2","NO","PM25")))

# Thin the data for smoother animation (every 4th row = 8-min steps)
long_sp_thin <- long_sp[seq(1, nrow(long_sp), 4), ]

p_conc <- ggplot(long_sp_thin,
                 aes(x = t_hr, y = ppb, colour = Species, group = Species)) +
  # daylight shading
  annotate("rect", xmin = 6, xmax = 20,
           ymin = -Inf, ymax = Inf, fill = "#FFFACD", alpha = 0.5) +
  geom_line(linewidth = 1.3, lineend = "round") +
  # EPA 8-hour O3 standard
  geom_hline(yintercept = 70, colour = "#E69F00",
             linetype = "dashed", linewidth = 0.7, alpha = 0.9) +
  annotate("text", x = 0.4, y = 72.5,
           label = "O3 NAAQS (70 ppb, 8-hr)",
           hjust = 0, size = 3, colour = "#A07000") +
  geom_hline(yintercept = 35, colour = "#9B59B6",
             linetype = "dotted", linewidth = 0.7, alpha = 0.9) +
  annotate("text", x = 0.4, y = 37,
           label = "PM2.5 NAAQS (35 ug/m3, 24-hr)",
           hjust = 0, size = 3, colour = "#7D3C98") +
  scale_colour_manual(values = sp_pal, labels = sp_labs) +
  scale_x_continuous(
    limits = c(0, 24),
    breaks = seq(0, 24, 6),
    labels = c("00:00","06:00","12:00","18:00","24:00"),
    expand = c(0, 0)
  ) +
  scale_y_log10(
    limits = c(0.01, NA),
    expand = expansion(mult = c(0, 0.08)),
    labels = scales::label_number(accuracy = 0.01)
  ) +
  facet_wrap(~ Scenario, ncol = 2) +
  labs(
    title    = "NOx-O3 Diurnal Photochemistry",
    subtitle = "Time: {sprintf('%05.1f', frame_along)} h  |  Pale yellow = daylight",
    x        = "Hour of day (local time)",
    y        = "Concentration (ppb)",
    colour   = NULL,
    caption  = paste(
      "Box model: R1 = NO2+hv -> O3  |  R3 = NO+O3 -> NO2  |  Rv = RO2+NO -> NO2",
      "PM2.5 sources: OH+NO2 -> nitrate aerosol (daytime) + SOA yield from RO2 (5%)",
      "Initial: [NO]=15, [NO2]=30, [O3]=15, [PM2.5]=2 ppb",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    legend.key.width  = unit(1.2, "cm"),
    legend.text       = element_text(size = 11),
    strip.background  = element_rect(fill = "#1d3557", colour = NA),
    strip.text        = element_text(colour = "white", face = "bold", size = 9.5),
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour = "grey80", fill = NA),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(colour = "grey40", size = 10),
    plot.caption      = element_text(colour = "grey50", size = 8)
  ) +
  transition_reveal(t_hr) +
  ease_aes("linear")

anim1 <- animate(
  p_conc,
  nframes   = 150,
  fps       = 10,
  width     = 820,
  height    = 620,
  renderer  = magick_renderer()
)
magick::image_write(anim1, "nox_concentrations.gif")
message("OK: nox_concentrations.gif")

## 5. ANIMATION 2: O3 Production vs Consumption Rates -------
## 5b. ANIMATION 2b: PM2.5 source attribution ------------------------
message("Building animation 2b: PM2.5 sources...")

# Recompute PM2.5 source terms for plotting
all_df <- all_df |>
  mutate(
    oh_now  = mapply(OH_t, t_hr),
    P_nit   = k_nit * oh_now * NO2 * 3600,   # ppb/hr nitrate
    P_soa   = soa_yield * Rv * 3600,           # ppb/hr SOA
    P_dep   = -k_dep * PM25 * 3600             # ppb/hr deposition (loss)
  )

pm_long <- all_df |>
  select(t_hr, Scenario, PM25, P_nit, P_soa, P_dep) |>
  pivot_longer(c(P_nit, P_soa, P_dep),
               names_to  = "Source",
               values_to = "rate_pph") |>
  mutate(Source = factor(Source,
    levels = c("P_nit","P_soa","P_dep"),
    labels = c("Nitrate (OH+NO2->HNO3)",
               "SOA (RO2 oxidation, 5% yield)",
               "Deposition loss")))

pm_pal <- c(
  "Nitrate (OH+NO2->HNO3)"        = "#E74C3C",
  "SOA (RO2 oxidation, 5% yield)" = "#27AE60",
  "Deposition loss"               = "#7F8C8D"
)

pm_thin <- pm_long[seq(1, nrow(pm_long), 4), ]

p_pm <- ggplot(pm_thin,
               aes(x = t_hr, y = rate_pph, colour = Source, group = Source)) +
  annotate("rect", xmin = 6, xmax = 20,
           ymin = -Inf, ymax = Inf, fill = "#FFFACD", alpha = 0.5) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.5) +
  geom_line(linewidth = 1.2, lineend = "round") +
  scale_colour_manual(values = pm_pal) +
  scale_x_continuous(limits = c(0, 24), breaks = seq(0, 24, 6),
    labels = c("00:00","06:00","12:00","18:00","24:00"), expand = c(0,0)) +
  facet_wrap(~ Scenario, ncol = 2, scales = "free_y") +
  labs(
    title    = "PM2.5 Formation & Loss Rates",
    subtitle = "Time: {sprintf('%05.1f', frame_along)} h  |  SOA only non-zero in High VOC scenario",
    x        = "Hour of day (local time)",
    y        = "Rate (ppb h-1)",
    colour   = NULL,
    caption  = paste(
      "Nitrate pathway active only during daylight (requires OH from photochemistry).",
      "SOA scales with RO2 loading -- near-zero in base/temp/UV scenarios.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    legend.key.width  = unit(1.2, "cm"),
    legend.text       = element_text(size = 9),
    strip.background  = element_rect(fill = "#1d3557", colour = NA),
    strip.text        = element_text(colour = "white", face = "bold", size = 9.5),
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour = "grey80", fill = NA),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(colour = "grey40", size = 10),
    plot.caption      = element_text(colour = "grey50", size = 8)
  ) +
  transition_reveal(t_hr) +
  ease_aes("linear")

anim_pm <- animate(p_pm, nframes = 150, fps = 10,
                   width = 820, height = 620,
                   renderer = magick_renderer())
magick::image_write(anim_pm, "nox_pm25_sources.gif")
message("OK: nox_pm25_sources.gif")

message("Building animation 2: reaction rates...")

# Convert ppb/s -> ppb/hr for readability
rates_long <- all_df |>
  select(t_hr, Scenario, R1, R3, Rv, Net) |>
  mutate(
    R1_hr  = R1  * 3600,
    R3_hr  = R3  * 3600,
    Rv_hr  = Rv  * 3600,
    Net_hr = Net * 3600
  ) |>
  select(t_hr, Scenario, R1_hr, R3_hr, Rv_hr, Net_hr) |>
  pivot_longer(c(R1_hr, R3_hr, Rv_hr, Net_hr),
               names_to  = "Term",
               values_to = "rate_pph") |>
  mutate(
    Term = factor(Term,
                  levels = c("R1_hr","R3_hr","Rv_hr","Net_hr"),
                  labels = c(
                    "R1: NO2+hv  (O3 production)",
                    "R3: NO+O3   (O3 destruction)",
                    "Rv: RO2+NO  (VOC, no O3 loss)",
                    "Net O3 production (R1-R3)"
                  ))
  )

rate_pal <- c(
  "R1: NO2+hv  (O3 production)"   = "#3498db",
  "R3: NO+O3   (O3 destruction)"  = "#e74c3c",
  "Rv: RO2+NO  (VOC, no O3 loss)" = "#2ecc71",
  "Net O3 production (R1-R3)"      = "#f39c12"
)

rates_thin <- rates_long[seq(1, nrow(rates_long), 4), ]

p_rates <- ggplot(rates_thin,
                  aes(x = t_hr, y = rate_pph,
                      colour = Term, group = Term)) +
  annotate("rect", xmin = 6, xmax = 20,
           ymin = -Inf, ymax = Inf, fill = "#FFFACD", alpha = 0.5) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.6) +
  geom_line(linewidth = 1.2, lineend = "round") +
  scale_colour_manual(values = rate_pal) +
  scale_x_continuous(
    limits = c(0, 24),
    breaks = seq(0, 24, 6),
    labels = c("00:00","06:00","12:00","18:00","24:00"),
    expand = c(0, 0)
  ) +
  scale_y_continuous(trans = scales::pseudo_log_trans(sigma = 0.1),
                     labels = scales::label_number(accuracy = 0.01)) +
  facet_wrap(~ Scenario, ncol = 2, scales = "free_y") +
  labs(
    title    = "O3 Production & Consumption Rates",
    subtitle = "Time: {sprintf('%05.1f', frame_along)} h  |  When R1 > R3, O3 accumulates",
    x        = "Hour of day (local time)",
    y        = "Rate (ppb h-1)",
    colour   = NULL,
    caption  = paste(
      "R1 peaks at solar noon when J(NO2) is maximum.",
      "Rv adds to NO2 production without reducing O3 -- the core VOC ozone-formation mechanism.",
      sep = "\n"
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    legend.key.width  = unit(1.2, "cm"),
    legend.text       = element_text(size = 9),
    strip.background  = element_rect(fill = "#1d3557", colour = NA),
    strip.text        = element_text(colour = "white", face = "bold", size = 9.5),
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour = "grey80", fill = NA),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(colour = "grey40", size = 10),
    plot.caption      = element_text(colour = "grey50", size = 8)
  ) +
  transition_reveal(t_hr) +
  ease_aes("linear")

anim2 <- animate(
  p_rates,
  nframes   = 150,
  fps       = 10,
  width     = 820,
  height    = 620,
  renderer  = magick_renderer()
)
magick::image_write(anim2, "nox_rates.gif")
message("OK: nox_rates.gif")

## 6. STATIC: Reaction Cycle Diagram (base R) ---------------
message("Building cycle diagram...")

png("nox_cycle_diagram.png", width = 1100, height = 1080, res = 130,
    bg = "#0d1b2a")

# Bezier curved arrow: quadratic curve + arrowhead
bezier_arrow <- function(x0, y0, x1, y1,
                         bend = 0.25, col = "white",
                         lwd = 3, n = 120) {
  # control point displaced perpendicular to the chord
  cx <- (x0 + x1) / 2 - bend * (y1 - y0)
  cy <- (y0 + y1) / 2 + bend * (x1 - x0)
  t  <- seq(0, 1, length.out = n)
  px <- (1-t)^2 * x0 + 2*(1-t)*t * cx + t^2 * x1
  py <- (1-t)^2 * y0 + 2*(1-t)*t * cy + t^2 * y1
  lines(px, py, col = col, lwd = lwd, lend = 1)
  # arrowhead at the tip
  arrows(px[n-3], py[n-3], px[n], py[n],
         col = col, lwd = lwd, length = 0.18, angle = 22, code = 2)
}

draw_node <- function(x, y, label, fill, r = 0.28, text_col = "white") {
  theta <- seq(0, 2*pi, length.out = 100)
  polygon(x + r * cos(theta), y + r * sin(theta),
          col = fill, border = NA)
  text(x, y, label, col = text_col, cex = 1.5, font = 2)
}

par(bg = "#0d1b2a", fg = "white",
    mar  = c(3, 2, 1, 2),
    oma  = c(0, 0, 7, 0))   # top outer margin for description banner

plot(NA, xlim = c(-3.2, 3.2), ylim = c(-3.0, 3.0),
     asp = 1, axes = FALSE, xlab = "", ylab = "",
     main = "")

title(main = "NOx-O3 Photostationary State Cycle",
      col.main = "white", cex.main = 1.6, font.main = 2)

# --- Description banner in outer margin ---
par(xpd = NA)
# Banner background rectangle (in figure coords mapped to outer margin)
usr <- par("usr"); fig <- par("fig"); pin <- par("pin")

mtext(
  "Photostationary State (Troposphere)",
  side = 3, outer = TRUE, line = 5.2,
  col = "#FFD700", cex = 1.25, font = 2, adj = 0.5
)
mtext(
  "In the lower atmosphere, a rapid balance exists between nitrogen dioxide (NO2),",
  side = 3, outer = TRUE, line = 3.7,
  col = "#e0e8f0", cex = 0.95, adj = 0.5
)
mtext(
  "nitric oxide (NO), and ozone (O3), known as the photostationary state.",
  side = 3, outer = TRUE, line = 2.5,
  col = "#e0e8f0", cex = 0.95, adj = 0.5
)
mtext(
  "Sunlight (hv) drives NO2 photolysis; O3 and NO recombine in the dark. VOCs break the cycle.",
  side = 3, outer = TRUE, line = 1.2,
  col = "#a8c4d8", cex = 0.85, adj = 0.5
)
par(xpd = FALSE)

# ---- node positions ----
NO2 <- c( 0.0,  2.0)
NO  <- c(-2.0, -1.0)
O3  <- c( 2.0, -1.0)
hv  <- c(-1.4,  2.8)
RO2 <- c( 1.5,  2.8)

# ---- ARROWS (drawn before nodes so nodes sit on top) ----

# R1a: NO2 -> NO  (blue, photolysis branch)
bezier_arrow(NO2[1]-0.22, NO2[2]-0.18,
             NO[1]+0.22,  NO[2]+0.22,
             bend = -0.15, col = "#4fc3f7", lwd = 5)

# R1b: NO2 -> O3  (blue, photolysis produces O3)
bezier_arrow(NO2[1]+0.22, NO2[2]-0.18,
             O3[1]-0.22,  O3[2]+0.22,
             bend = 0.15, col = "#4fc3f7", lwd = 5)

# R3: O3 + NO -> NO2  (red, two incoming arrows to NO2)
bezier_arrow(O3[1]-0.15,  O3[2]+0.28,
             NO2[1]+0.18, NO2[2]-0.22,
             bend = -0.2, col = "#ef5350", lwd = 5)

bezier_arrow(NO[1]+0.15, NO[2]+0.28,
             NO2[1]-0.18, NO2[2]-0.22,
             bend = 0.2, col = "#ef5350", lwd = 5)

# Rv: RO2 + NO -> NO2  (green dashed -- VOC peroxy pathway)
# Draw as a bottom arc: NO -> NO2 separate from R3 arc
bezier_arrow(NO[1]+0.28, NO[2]+0.05,
             NO2[1]-0.05, NO2[2]-0.30,
             bend = 0.55, col = "#66bb6a", lwd = 4)

# hv -> NO2 (yellow, photon absorbed by NO2)
arrows(hv[1]+0.12, hv[2]-0.18,
       NO2[1]-0.18, NO2[2]+0.24,
       col = "#ffee58", lwd = 4, length = 0.18, angle = 22)

# ---- NODES ----
draw_node(NO2[1], NO2[2], "NO2", "#5c35cc")
draw_node(NO[1],  NO[2],  "NO",  "#1565c0")
draw_node(O3[1],  O3[2],  "O3",  "#e65100")
draw_node(hv[1],  hv[2],  "hv",  "#f9a825", r = 0.22, text_col = "#1a1a1a")
draw_node(RO2[1], RO2[2], "RO2\n(VOC)", "#1b5e20", r = 0.32, text_col = "white")

# RO2 -> enters the Rv arrow (small connector)
arrows(RO2[1]-0.22, RO2[2]-0.22,
       NO[1]+0.8, NO[2]+0.5,
       col = "#66bb6a", lwd = 3, length = 0.15, angle = 22, lty = 2)

# ---- RATE LABELS ----
text(-2.1, 0.85,
     expression(paste("R1 = J(NO"[2], ") * [NO"[2], "]")),
     col = "#4fc3f7", cex = 1.0, adj = 1)

text( 2.1, 0.85,
     expression(paste("R3 = k"[3], "(T) * [NO] * [O"[3], "]")),
     col = "#ef5350", cex = 1.0, adj = 0)

text(-0.6, -0.05,
     expression(paste("R"[v], " = k"[v], " * [RO"[2], "] * [NO]")),
     col = "#66bb6a", cex = 0.95, adj = 0)

# ---- KEY: steady-state formula ----
rect(-2.8, -2.85, 2.8, -1.7, col = "#1a2a3a", border = "#4fc3f7", lwd = 1.5)
text(0, -2.0,
     expression(paste("[O"[3], "]"["ss"], " = ",
                       frac("J * [NO"[2], "]", "k"[3], "(T) * [NO]"))),
     col = "white", cex = 1.3, adj = 0.5)
text(0, -2.65,
     "VOC (RO2) elevates [NO2]/[NO] without consuming O3 --> higher [O3]_ss",
     col = "#66bb6a", cex = 0.9, adj = 0.5)

# ---- LEGEND: temperature & light effects ----
legend(
  x = -3.15, y = -1.1,
  legend = c(
    "R1 photolysis (O3 source)  ^ with light",
    "R3 titration   (O3 sink)   ^ with temperature",
    "Rv VOC peroxy (no O3 loss)  ^ with VOC/RO2"
  ),
  col    = c("#4fc3f7","#ef5350","#66bb6a"),
  lwd    = 3.5,
  bty    = "n",
  text.col = "white",
  cex    = 0.85
)

dev.off()
message("OK: nox_cycle_diagram.png")

message("\nAll three outputs written successfully.")
