library(terra)
library(stringr)
library(R.utils)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(ggplot2)
library(tidyr)
library(wbstats)
library(ggthemes)


viirs_folder <- "VIIRS Data"

tkm <- ne_countries(
  country = "Turkmenistan",
  scale = "medium",
  returnclass = "sf"
) 

tkm <- vect(tkm)

viirs_files <- list.files(
  viirs_folder,
  pattern = "\\.tif$",
  recursive = TRUE,
  full.names = TRUE
)

#pullviirsrecursive

process_viirs <- function(file) {
  #crop
  year <- str_extract(file, "20\\d{2}") |>
    as.integer()
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

lights_data <- lapply(
  viirs_files,
  process_viirs
  ) |>
  bind_rows() |>
  arrange(year)

print(lights_data) #remove later

#pullwbgdp

gdp_data <- wb_data(
  indicator = c(real_gdp ="NY.GDP.MKTP.KD"), #real GDP adj for inflation
  country = "TKM",
  start_date = 2014,
  end_date = 2021,
) |>
  transmute(
    year = as.integer(date),
    real_gdp
  ) |>
arrange(year)
  
print(gdp_data) #removelater

#combine

turkmen_data <- left_join(
  gdp_data,
  lights_data,
  by = "year"
)

#

print(turkmen_data) #removelater

elasticity <- 0.15

# baseline growth not captured by lights (stands in for the GWU constant + population term)
# IMF staff real GDP growth 2015-2020, Bayar & Gogoberishvili (2023), IMF WP/23/207, Table 3.1
imf_growth <- c(3.0, -1.0, 4.7, 0.9, -3.4, -3.0)
alpha <- prod(1 + imf_growth / 100)^(1 / length(imf_growth)) - 1 # compound annual rate, ~0.16%

turkmen_data <- turkmen_data |>
  mutate(
    gdp_index = real_gdp / real_gdp[year == 2014] * 100,
    lights_index = lights / lights[year == 2014] * 100,
    lights_implied_gdp_index = 100 * (lights / lights[year == 2014])^elasticity,
    lights_implied_alpha_index = lights_implied_gdp_index * (1 + alpha)^(year - 2014)
  )
  
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
    y = "GDP",
    linetype = NULL,
    caption = "Sources: World Bank WDI; VIIRS VNL v2; elasticity 0.15 from Chiovelli et al. (2025)"
  ) +
  theme_tufte(base_size = 11, base_family = "serif", ticks=TRUE)

print(turkplot)


