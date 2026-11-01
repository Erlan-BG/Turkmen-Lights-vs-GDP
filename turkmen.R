library(terra)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(ggplot2)
library(tidyr)
library(wbstats)
library(ggthemes)


viirs_folder <- "VIIRS Data"
years <- 2014:2021

tkm <- ne_countries(
  country = "Turkmenistan",
  scale = "medium",
  returnclass = "sf"
)

tkm <- vect(tkm)

#only the Turkmenistan year folders; the country folders (AZE, DEU, ...) are for othercountries.R
viirs_files <- file.path(
  viirs_folder,
  years,
  sprintf("TKM_VNL_v2_%d_average_masked.tif", years)
)

#pullviirs

process_viirs <- function(file, year) {
  #crop
  r <- rast(file)
  tkm_r <- project(tkm, crs(r))
  r_tkm <- crop(r, tkm_r)
  r_tkm <- mask(r_tkm, tkm_r)
  #sumlights
  light_sum <- global(
    r_tkm,
    fun = "sum",
    na.rm = TRUE
  )[[1]]

  data.frame(
    year = year,
    lights = light_sum
  )
}

lights_data <- Map(
  process_viirs,
  viirs_files,
  years
  ) |>
  bind_rows() |>
  arrange(year)

#pullwbgdp

gdp_data <- wb_data(
  indicator = c(real_gdp ="NY.GDP.MKTP.KD"), #real GDP adj for inflation
  country = "TKM",
  start_date = min(years),
  end_date = max(years)
) |>
  transmute(
    year = as.integer(date),
    real_gdp
  ) |>
arrange(year)

#combine

turkmen_data <- left_join(
  gdp_data,
  lights_data,
  by = "year"
)

# GDP-lights elasticity: Chiovelli, Michalopoulos, Papaioannou & Regan (2025), GWU CER WP 2025-009
elasticity <- 0.15

# baseline growth not captured by lights (stands in for the GWU constant + population term)
# IMF staff real GDP growth 2015-2020, Bayar & Gogoberishvili (2023), IMF WP/23/207, Table 3.1
imf_growth <- c(3.0, -1.0, 4.7, 0.9, -3.4, -3.0)
alpha <- prod(1 + imf_growth / 100)^(1 / length(imf_growth)) - 1 # compound annual rate, ~0.16%

turkmen_data <- turkmen_data |>
  mutate(
    gdp_index = real_gdp / real_gdp[year == min(years)] * 100,
    lights_index = lights / lights[year == min(years)] * 100,
    lights_implied_gdp_index = 100 * (lights / lights[year == min(years)])^elasticity,
    lights_implied_alpha_index = lights_implied_gdp_index * (1 + alpha)^(year - min(years)),
    gap = gdp_index - lights_implied_gdp_index #index points official GDP is above the lights
  )

print(turkmen_data)

#headline numbers (the story's "53% vs -3%, gap of 56 points, ~6.7 pp a year")

last_year <- filter(turkmen_data, year == max(years))
n_years <- max(years) - min(years)

headline <- data.frame(
  official_growth = last_year$gdp_index - 100,
  lights_implied_growth = last_year$lights_implied_gdp_index - 100,
  gap_points = last_year$gap,
  #annual overstatement: official yearly growth rate minus the lights-implied one
  gap_per_year = 100 * ((last_year$gdp_index / 100)^(1 / n_years) -
                          (last_year$lights_implied_gdp_index / 100)^(1 / n_years))
)

print(round(headline, 1))

#elasticity sensitivity: light fell, so any positive beta gives a shrinking economy

lights_ratio <- last_year$lights_index / 100

beta_check <- data.frame(beta = c(0.04, 0.15, 0.26, 0.40, 1)) |>
  mutate(lights_implied_growth = 100 * (lights_ratio^beta - 1))

print(round(beta_check, 2))

# plotthedata

plot_data <- turkmen_data |>
  select(
    year,
    'Official GDP' = gdp_index,
    'Lights-Implied GDP' = lights_implied_gdp_index
  ) |>
  pivot_longer(
    cols = -year,
    names_to = "series",
    values_to = "index"
  )

turkplot <- ggplot(
  plot_data,
  aes(
    x = year,
    y = index,
    linetype = series
  )
) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  labs(
    title = "Turkmenistan: Official GDP vs Nighttime Implied GDP",
    x = NULL,
    y = sprintf("GDP (index, %d = 100)", min(years)),
    linetype = NULL,
    caption = "Sources: World Bank WDI; VIIRS VNL v2; elasticity 0.15 from Chiovelli et al. (2025)"
  ) +
  theme_tufte(base_size = 11, base_family = "serif", ticks=TRUE)

print(turkplot)
