library(terra)
library(readxl)
library(dplyr)

# Turkmenistan 2019 only, for the "flares fade away" scene: EOG's 2019 flare-site list plus
# the Darvaza crater, a 3 km circle around each, pixels inside set to NA.

flare_file <- "~/Downloads/VIIRS_Global_flaring_d.7_slope_0.029353_2019_web_v20201114.xlsx"
buffer_m <- 3000

tkm_2019 <- rast("VIIRS Data/TKM/TKM_VNL_v21_2019_average_masked.tif")

#flaresites

flares <- read_excel(flare_file, sheet = "all flares") |>
  filter(`ISO Code` == "TKM") |>
  select(Longitude, Latitude) |>
  bind_rows(data.frame(Longitude = 58.4396, Latitude = 40.2525)) # Darvaza: a crater, not in EOG's list

flare_circles <- vect(flares, geom = c("Longitude", "Latitude"), crs = "EPSG:4326") |>
  buffer(width = buffer_m) # metres, since the data are lon/lat

#mask

tkm_2019_noflare <- mask(tkm_2019, flare_circles, inverse = TRUE) # NA inside the circles

writeRaster(tkm_2019_noflare, "VIIRS Data/TKM/TKM_VNL_v21_2019_noflare.tif", overwrite = TRUE)

#sumlights

with_flares <- global(tkm_2019, fun = "sum", na.rm = TRUE)[[1]]
without_flares <- global(tkm_2019_noflare, fun = "sum", na.rm = TRUE)[[1]]

cat("2019 lights with flares:   ", round(with_flares), "\n")
cat("2019 lights without flares:", round(without_flares), "\n")
cat("share from flares:         ", round(100 * (1 - without_flares / with_flares), 1), "%\n")
