# simplified carbon calculation

# import libraries 
library(raster)
library(glue)
library(rgdal)
library(dplyr)

wd = '/home/freddie/Cloud_Free_Metrics/PA_paper'

setwd(wd)
aoi <- readOGR("shapefiles/combined_formatted_PAs_v1_4_nov_22.geojson") 

# subset for serengeti
pa <- aoi[aoi$NAME == 'Serengeti',]

# import gfw
gfw <- raster('gfw_data/gfw_2021_v1_9.tif')
gfw[gfw < 10] <- NA
gfw[gfw > 9] <- 1

# reproj to raster crs 
pa <- spTransform(pa, crs(gfw))

# import loss
loss <- raster('gfw_data/regrid_sum_1km_2010_def_gfw_gee_v1.tif')
gfw[loss > 555] <- 0

# crop to PA
gfw_cp <- crop(mask(gfw, pa), pa)
plot(gfw_cp)

# import carbon layers
abc <- raster('carbon_layers/regrid_1km_aboveground_biomass_carbon_2010.tif') # tonnes per ha, pixels are 1km * 1km
bgc <- raster('carbon_layers/regrid_1km_below_biomass_carbon_2010.tif') # tonnes per ha, pixels are 1km * 1km

# mask to forested areas
abc_cp <- crop(mask(abc, pa), pa)
bgc_cp <- crop(mask(bgc, pa), pa)

abc_cp[is.na(gfw)] <- NA
bgc_cp[is.na(gfw)] <- NA

# agricultural change import
ag_2050 <- raster('Ag_change/regrid_41893_2020_656_MOESM11_ESM_change_2015.tif')
ag_2010 <- raster('Ag_change/regrid_AgriculturalLandCover_2010.tif')
ag_2010_cp <- crop(mask(ag_2010, pa), pa)
ag_2050_cp <- crop(mask(ag_2050, pa), pa)

# convert carbon to ag layer proportions
abc_2010 <- (1 - ag_2010_cp) * abc_cp
bgc_2010 <-  (1 - ag_2010_cp) * bgc_cp

abc_2050 <- (1 - ag_2050_cp) * abc_cp
bgc_2050 <-  (1 - ag_2050_cp) * bgc_cp

# extract above ground only.
abc_sum_2010 <- extract(abc_2010, pa, fun = sum, df = T, na.rm = T)
agc_sum_2050 <- extract(abc_2050, pa, fun = sum, df = T, na.rm = T)

# convert from tonnes ha to tonnes km2
abc_sum_2010_tonnes_pa <- abc_sum_2010 * 100 # convert to tones km2
abc_sum_2050_tonnes_pa <- agc_sum_2050 * 100 # convert to tones km2

# difference 
differnce_carbon_total_tonnes_pa <- abc_sum_2010_tonnes_pa - abc_sum_2050_tonnes_pa

# per year
loss_carbon_total_tonnes_pa_per_year <- differnce_carbon_total_tonnes_pa/40

# revenue 
carbon_revenue_per_year <- loss_carbon_total_tonnes_pa_per_year * 5 
