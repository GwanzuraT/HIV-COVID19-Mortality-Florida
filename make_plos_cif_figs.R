# PLOS CIF figures 1–3 (reads CSVs in plos_cif_data/)
suppressPackageStartupMessages({
  library(ggplot2)
  library(readr)
  library(dplyr)
  library(scales)
  library(patchwork)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[1]) else ""
if (nzchar(this_file) && this_file != "UNKNOWN") {
  base_dir <- dirname(normalizePath(this_file, winslash = "/", mustWork = TRUE))
} else {
  base_dir <- getwd()
}
data_dir <- file.path(base_dir, "plos_cif_data")
out_dir <- base_dir
if (!dir.exists(data_dir)) stop("Missing folder: ", data_dir)

race_hex <- c(
  Hispanic             = "#E69F00",
  `Non-Hispanic Black` = "#56B4E9",
  `Non-Hispanic White` = "#009E73",
  Other                = "#CC79A7"
)
oi_extra <- c("#0072B2", "#D55E00", "#F0E442", "#000000")

# Manuscript: before = through Apr 30, 2021; during from May 1, 2021.
# Month 0 = Mar 2020 → month 13 = Apr 2021; month 14 = May 2021 (vaccine period).
BEFORE_MAX_MO <- 13L
DURING_MIN_MO <- 14L

read_pair <- function(stem) {
  bind_rows(
    read_csv(file.path(data_dir, paste0(stem, "_before.csv")), show_col_types = FALSE) |>
      mutate(period = "Before", .before = 1),
    read_csv(file.path(data_dir, paste0(stem, "_during.csv")), show_col_types = FALSE) |>
      mutate(period = "During", .before = 1)
  )
}

dedup_cif <- function(df) {
  df |>
    group_by(stratum, period, time_diff) |>
    slice_max(order_by = cif, n = 1, with_ties = FALSE) |>
    ungroup() |>
    arrange(stratum, period, time_diff)
}

pal_for_strata <- function(levels_chr, panel_is_race = FALSE) {
  lv <- levels_chr
  if (panel_is_race) {
    stopifnot(all(lv %in% names(race_hex)))
    return(unname(race_hex[lv]))
  }
  cols <- c(unname(race_hex), oi_extra)
  setNames(rep(cols, length.out = length(lv)), lv)
}

curve_levels <- function(df) {
  sl <- levels(droplevels(df$stratum))
  unlist(lapply(sl, function(s) paste0(s, c(" (Before)", " (During)"))), use.names = FALSE)
}

make_curve_df <- function(df) {
  df <- dedup_cif(df) |>
    filter(!(period == "Before" & time_diff > BEFORE_MAX_MO)) |>
    # Drop spurious SAS rows (e.g. During at month 0); during starts May 2021 = month 14+.
    filter(!(period == "During" & time_diff < DURING_MIN_MO))
  cl <- curve_levels(df)
  df |>
    mutate(
      period = factor(period, levels = c("Before", "During")),
      curve_id = factor(paste0(stratum, " (", period, ")"), levels = cl)
    )
}

plot_cif_panel <- function(df, panel_is_race = FALSE,
                           ylab = "Cumulative incidence",
                           xlab = "Months since March 2020",
                           legend_nrow = 3L) {
  d <- make_curve_df(df)
  sl <- levels(droplevels(d$stratum))
  base_cols <- pal_for_strata(sl, panel_is_race = panel_is_race)
  cl <- levels(d$curve_id)

  line_cols <- rep(unname(base_cols), each = 2)
  names(line_cols) <- cl

  lty_vals <- ifelse(grepl("Before\\)$", cl), "solid", "dashed")
  names(lty_vals) <- cl

  ggplot(d, aes(time_diff, cif, group = curve_id)) +
    geom_line(aes(colour = curve_id, linetype = curve_id), linewidth = 0.85) +
    scale_colour_manual(
      name = "curve",
      values = unname(line_cols[cl]),
      breaks = cl,
      limits = cl,
      drop = FALSE
    ) +
    scale_linetype_manual(
      name = "curve",
      values = unname(lty_vals[cl]),
      breaks = cl,
      limits = cl,
      drop = FALSE
    ) +
    scale_x_continuous(
      limits = c(0, 22),
      breaks = seq(0, 22, 2),
      expand = expansion(mult = c(0.02, 0.08), add = c(0, 0.2))
    ) +
    scale_y_continuous(labels = label_scientific(), expand = expansion(mult = c(0, 0.06))) +
    labs(x = xlab, y = ylab) +
    theme_classic(base_size = 9, base_family = "Helvetica") +
    theme(
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(size = 6.8, family = "Helvetica"),
      legend.key.width = grid::unit(1, "cm"),
      legend.key.height = grid::unit(0.42, "cm"),
      legend.box.spacing = grid::unit(0.12, "cm"),
      legend.margin = ggplot2::margin(t = 2, b = 4),
      plot.margin = ggplot2::margin(5, 8, 8, 8),
      panel.grid.major = element_line(colour = "grey90", linewidth = 0.25, linetype = "dotted"),
      panel.grid.minor = element_blank(),
      axis.text = element_text(family = "Helvetica", size = 8),
      axis.title = element_text(family = "Helvetica", size = 9)
    ) +
    guides(
      colour = guide_legend(
        nrow = legend_nrow,
        byrow = TRUE,
        override.aes = list(linewidth = 0.8)
      )
    )
}

# --- Load & factor stratum labels ---
d_race <- read_pair("race") |>
  mutate(
    stratum = factor(
      stratum,
      levels = c("Hispanic", "NHB", "NHW", "Other"),
      labels = c("Hispanic", "Non-Hispanic Black", "Non-Hispanic White", "Other")
    )
  )

d_vl <- read_pair("vl") |>
  mutate(stratum = factor(stratum, levels = c("Not suppressed", "Suppressed")))
d_rur <- read_pair("rur") |>
  mutate(stratum = factor(stratum, levels = c("Urban", "Rural")))
d_svi <- read_pair("svi") |>
  mutate(stratum = factor(stratum, levels = c("Low SVI", "Medium SVI", "High SVI")))

d_age <- read_pair("age") |>
  mutate(stratum = factor(stratum, levels = c("18-34", "35-49", "50-64", "65+")))
d_usb <- read_pair("usb") |>
  filter(stratum != "Unknown") |>
  mutate(stratum = factor(stratum, levels = c("US born", "Non-US born")))
d_sex <- read_pair("sex") |>
  mutate(stratum = factor(stratum, levels = c("Female", "Male")))
d_tr <- read_pair("tr") |>
  mutate(stratum = factor(stratum, levels = c("MSM", "Heterosexual", "IDU", "Other")))

subtitle_theme <- function() {
  theme(
    plot.subtitle = element_text(size = 8.5, face = "italic", hjust = 0, family = "Helvetica")
  )
}

# --- Build plots ---
p1 <- plot_cif_panel(d_race, panel_is_race = TRUE, legend_nrow = 4L) +
  labs(subtitle = "Race/ethnicity") +
  subtitle_theme() +
  theme(
    legend.text = element_text(size = 5.4, family = "Helvetica"),
    legend.key.width = grid::unit(0.72, "cm"),
    legend.key.height = grid::unit(0.28, "cm"),
    legend.margin = ggplot2::margin(t = 2, b = 10, r = 8, l = 8),
    plot.margin = ggplot2::margin(t = 4, r = 10, b = 10, l = 8)
  ) +
  guides(colour = guide_legend(nrow = 4L, byrow = TRUE, override.aes = list(linewidth = 0.6)))

p2a <- plot_cif_panel(d_vl, legend_nrow = 2L) + labs(subtitle = "Viral suppression") + subtitle_theme()
p2b <- plot_cif_panel(d_rur, legend_nrow = 2L) + labs(subtitle = "Rurality") + subtitle_theme()
p2c <- plot_cif_panel(d_svi, legend_nrow = 3L) + labs(subtitle = "SVI tertile") + subtitle_theme()

# Fig 2: single row, ncol = 3 (PLOS ONE height ~5 in); caption explains before/during gap
fig2 <- (
    p2a + p2b + p2c +
      plot_layout(ncol = 3L, guides = "collect") +
      plot_annotation(
        caption = paste0(
          "Solid lines: before vaccine availability (months 0–13 since March 2020); ",
          "dashed lines: during availability (months 14–22). ",
          "The break between periods reflects distinct at-risk cohorts, not missing data."
        ),
        theme = theme(
          plot.caption = element_text(
            size = 6.5, hjust = 0, colour = "grey25",
            lineheight = 1.15, family = "Helvetica", margin = ggplot2::margin(t = 6)
          ),
          plot.margin = ggplot2::margin(b = 4, r = 4, l = 4, t = 2)
        )
      )
  ) &
  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.text = element_text(size = 5.5, family = "Helvetica"),
    legend.key.width = grid::unit(0.6, "cm"),
    legend.key.height = grid::unit(0.32, "cm"),
    legend.box.spacing = grid::unit(0.06, "cm"),
    legend.margin = ggplot2::margin(t = 4, b = 4, r = 4, l = 4),
    plot.margin = ggplot2::margin(4, 4, 4, 4)
  ) &
  guides(
    colour = guide_legend(nrow = 3L, byrow = TRUE, override.aes = list(linewidth = 0.6))
  )

# 2×2 grid: top row Age | US birth; bottom Sex | HIV transmission
p3a <- plot_cif_panel(d_age, legend_nrow = 2L) +
  labs(subtitle = "Age group", x = NULL) +
  subtitle_theme()
p3b <- plot_cif_panel(d_usb, legend_nrow = 2L) +
  labs(subtitle = "US birth", x = NULL) +
  subtitle_theme()
p3c <- plot_cif_panel(d_sex, legend_nrow = 2L) +
  labs(subtitle = "Sex", x = "Months since March 2020") +
  subtitle_theme()
p3d <- plot_cif_panel(d_tr, legend_nrow = 2L) +
  labs(subtitle = "HIV transmission category", x = "Months since March 2020") +
  subtitle_theme() +
  theme(axis.title.x = element_text(margin = ggplot2::margin(t = 4)))

fig3 <- (
    (p3a | p3b) / (p3c | p3d) +
      plot_layout(guides = "collect", heights = c(1, 1), widths = c(1, 1)) +
      plot_annotation(
        theme = theme(
          plot.margin = ggplot2::margin(b = 8, r = 6, l = 6, t = 2)
        )
      )
  ) &
  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.justification = "center",
    legend.text = element_text(size = 5.2, family = "Helvetica"),
    legend.key.width = grid::unit(0.52, "cm"),
    legend.key.height = grid::unit(0.34, "cm"),
    legend.spacing.x = grid::unit(0.14, "cm"),
    legend.spacing.y = grid::unit(0.08, "cm"),
    legend.box.spacing = grid::unit(0.06, "cm"),
    legend.margin = ggplot2::margin(t = 6, b = 8, r = 6, l = 6)
  ) &
  guides(
    colour = guide_legend(
      nrow = 4L,
      byrow = TRUE,
      override.aes = list(linewidth = 0.55)
    )
  )

save_all <- function(plot, stem, w, h) {
  tif <- file.path(out_dir, paste0(stem, ".tif"))
  eps <- file.path(out_dir, paste0(stem, ".eps"))
  png <- file.path(out_dir, paste0(stem, ".png"))
  ggsave(tif, plot, device = "tiff", dpi = 300, width = w, height = h, units = "in", compression = "lzw")
  ggsave(eps, plot, device = grDevices::cairo_ps, dpi = 300, width = w, height = h, units = "in")
  ggsave(png, plot, dpi = 150, width = w, height = h, units = "in", bg = "white")
  message("Saved: ", basename(tif), ", ", basename(eps), ", ", basename(png))
}

save_all(p1, "Fig1", 6.5, 5.55)
save_all(fig2, "Fig2", 11.25, 5.0)
save_all(fig3, "Fig3", 10.0, 8.5)

message("Output directory: ", normalizePath(out_dir, winslash = "/"))
