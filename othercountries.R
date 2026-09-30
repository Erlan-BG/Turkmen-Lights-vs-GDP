library(terra)
library(stringr)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)

# Crop the global VNL v2.1 annual composites to each comparison country and sum the lights.
# Run once from the project folder; turkmen.qmd only needs the outputs.

global_folder <- "VIIRS Data/VIIRS Data for Other Countries"
isos <- c("TKM", "GEO", "DEU", "MYS", "AZE", "UZB")

countries <- ne_countries(scale = "medium", returnclass = "sf") |>
  filter(adm0_a3 %in% isos) |>
  vect()

global_files <- list.files(
  global_folder,
  pattern = "average_masked.*\\.tif\\.gz$",
  full.names = TRUE
)

out_path <- function(iso, year) {
  file.path("VIIRS Data", iso, sprintf("%s_VNL_v21_%d_average_masked.tif", iso, year))
}

#crop

for (file in global_files) {
  year <- str_extract(basename(file), "(?<=npp_)20\\d{2}") |>
    as.integer()
  # read straight from the .gz: unzipped, each global file is ~11 GB
  r <- rast(paste0("/vsigzip/", normalizePath(file)))
  
  for (iso in isos) {
    out <- out_path(iso, year)
    if (file.exists(out)) next # already done; lets you rerun after an interruption
    dir.create(dirname(out), showWarnings = FALSE)
    border <- countries[countries$adm0_a3 == iso]
    crop(r, border) |>
      mask(border) |>
      writeRaster(out)
    message(iso, " ", year, " done")
  }
}

#sumlights

lights_by_country <- expand.grid(iso3 = isos, year = 2014:2021, stringsAsFactors = FALSE) |>
  rowwise() |>
  mutate(lights = global(rast(out_path(iso3, year)), fun = "sum", na.rm = TRUE)[[1]]) |>
  ungroup() |>
  arrange(iso3, year)

write.csv(lights_by_country, "lights_by_country.csv", row.names = FALSE)

print(lights_by_country) #remove later