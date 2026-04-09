# =============================================================================
# Anscombe's Quartet — Analysis and Visualization
# EA030 · Prof. Marc Los Huertos · Pomona College
# =============================================================================

library(ggplot2)
library(dplyr)

# ── 0. Load data ──────────────────────────────────────────────────────────────
anscombe <- read.csv("/home/mwl04747/RTricks/docs/basic_statistics/anscombe.csv")
anscombe$dataset <- factor(anscombe$dataset,
                           labels = paste("Dataset", 1:4))

# ── 1. Summary statistics per dataset ────────────────────────────────────────
stats <- anscombe %>%
  group_by(dataset) %>%
  summarise(
    n       = n(),
    mean_x  = mean(x),
    mean_y  = mean(y),
    sd_x    = sd(x),
    sd_y    = sd(y),
    r       = cor(x, y),
    b0      = coef(lm(y ~ x))[1],   # intercept
    b1      = coef(lm(y ~ x))[2],   # slope
    r2      = summary(lm(y ~ x))$r.squared,
    p_slope = summary(lm(y ~ x))$coefficients[2, 4],
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))

cat("─── Summary statistics ──────────────────────────────────────────────────\n")
print(as.data.frame(stats))

# ── 2. Build annotation labels (placed on each facet panel) ──────────────────
#  sprintf() formats each number; paste0() assembles the multi-line string
labels <- stats %>%
  mutate(
    label = paste0(
      "ȳ = ", mean_y,  "   ȳ = ", mean_y,  "\n",
      "x̄ = ", mean_x,  "   SD(x) = ", sd_x, "\n",
      "SD(y) = ", sd_y,"\n",
      "r = ",  r,       "   R² = ", r2,      "\n",
      "ŷ = ", round(b0, 2), " + ", round(b1, 2), "x\n",
      "p(slope) ", ifelse(p_slope < 0.001, "< 0.001",
                          paste0("= ", round(p_slope, 3)))
    )
  )

# ── 3. Plot ───────────────────────────────────────────────────────────────────
# Color palette — one per dataset
ds_colors <- c(
  "Dataset 1" = "#1e3a2f",
  "Dataset 2" = "#c8832a",
  "Dataset 3" = "#2e7d94",
  "Dataset 4" = "#7a3a2f"
)

p <- ggplot(anscombe, aes(x = x, y = y, color = dataset)) +
  
  # ── raw points ──────────────────────────────────────────────────────────────
  geom_point(size = 3, alpha = 0.85) +
  
  # ── OLS regression line (same slope/intercept for each — that's the point) ─
  geom_smooth(method = "lm", se = TRUE, linewidth = 0.9,
              color   = "#1a1a18",
              fill    = "#d4e6da",
              alpha   = 0.35) +
  
  # ── stat annotation box ─────────────────────────────────────────────────────
  geom_label(
    data       = labels,
    aes(label  = label),
    x          = -Inf, y = Inf,          # top-left corner of each panel
    hjust      = -0.05, vjust = 1.08,
    size       = 2.85,
    color      = "#1a1a18",
    fill       = "#f7f3ed",
    linewidth  = 0.25,
    label.r    = unit(3, "pt"),
    inherit.aes = FALSE
  ) +
  
  # ── facet: one panel per dataset ─────────────────────────────────────────────
  facet_wrap(~ dataset, nrow = 2, scales = "fixed") +
  
  # ── scales & labels ──────────────────────────────────────────────────────────
  scale_color_manual(values = ds_colors) +
  scale_x_continuous(breaks = seq(0, 20, 4)) +
  scale_y_continuous(breaks = seq(2, 14, 2)) +
  
  labs(
    title    = "Anscombe's Quartet",
    subtitle = paste0(
      "Four datasets with nearly identical summary statistics",
      " but completely different structures.\n",
      "All share:  x̄ = 9,  ȳ ≈ 7.50,  SD(x) ≈ 3.32,  SD(y) ≈ 2.03,",
      "  r ≈ 0.816,  ŷ = 3 + 0.5x"
    ),
    x        = "x",
    y        = "y",
    caption  = "Anscombe, F.J. (1973). Graphs in Statistical Analysis. The American Statistician, 27(1), 17–21."
  ) +
  
  # ── theme ─────────────────────────────────────────────────────────────────────
  theme_minimal(base_size = 12) +
  theme(
    plot.title       = element_text(family = "serif", face = "bold",
                                    size = 16, color = "#1e3a2f",
                                    margin = margin(b = 4)),
    plot.subtitle    = element_text(size = 9,  color = "#3a3a38",
                                    lineheight = 1.4,
                                    margin = margin(b = 12)),
    plot.caption     = element_text(size = 7.5, color = "#7a7a72",
                                    face = "italic", hjust = 0),
    strip.text       = element_text(family = "mono", face = "bold",
                                    size = 10, color = "#1e3a2f"),
    strip.background = element_rect(fill = "#d4e6da", color = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "#ede8df", linewidth = 0.4),
    panel.border     = element_rect(color = "#d4e6da", fill = NA,
                                    linewidth = 0.5),
    legend.position  = "none",
    plot.margin      = margin(16, 20, 12, 16)
  )

# ── 4. Save ───────────────────────────────────────────────────────────────────
ggsave("/home/mwl04747/RTricks/docs/basic_statistics/anscombe_plot.png", plot = p,
       width = 9, height = 7, dpi = 180, bg = "#f7f3ed")

cat("\nPlot saved to anscombe_plot.png\n")

# ── 5. Console summary table ─────────────────────────────────────────────────
cat("\n─── Key point ───────────────────────────────────────────────────────────\n")
cat("All four datasets produce nearly the same regression equation,\n")
cat("correlation coefficient, and R² — yet are structurally completely\n")
cat("different. This is why ALWAYS PLOTTING YOUR DATA matters.\n\n")

cat("Dataset 1: linear relationship with moderate scatter — OLS is appropriate\n")
cat("Dataset 2: perfect quadratic curve — linear model is wrong\n")
cat("Dataset 3: perfect line with one high-leverage outlier distorting the fit\n")
cat("Dataset 4: vertical cluster + one outlier — OLS is completely meaningless\n")