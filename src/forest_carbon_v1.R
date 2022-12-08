#!/usr/bin/env Rscript
###################################
#### Freddie Hunter 23 September ##
###################################

# Calculating potential revenue from REDD+ in PAs across subsaharan africa.

# import libraries 
library(raster)
library(glue)
library(rgdal)
library(dplyr)

wd = '/home/freddie/Cloud_Free_Metrics/PA_paper'

setwd(wd)
aoi <- readOGR("shapefiles/combined_formatted_PAs_v2_30_nov_22.geojson") 

####################################################################
# calculate carbon volume in PAs ----
####################################################################

# import gfw
gfw <- raster('gfw_data/gfw_2021_v1_9.tif')
loss <- raster('gfw_data/regrid_sum_1km_2010_def_gfw_gee_v1.tif')  # values represent number of deforested 30 by 30 pixels
aoi <- spTransform(aoi, crs(gfw))

# crop gfw to pas 
cp_gfw <- mask(crop(gfw, aoi), aoi)

#reclassify gfw 
# mask out all pixels with less than 10% forest cover. 
cp_gfw[cp_gfw < 10] <- NA
cp_gfw[cp_gfw > 9] <- 1

# mask out forest loss that has occurred within the last ten years relative to 2010.
cp_gfw[loss > 555] <- NA #555 represent the threshold for the majority of 30*30m pixels in a 1km*1km2 

# import soil carbon layers
abc <- raster('carbon_layers/regrid_1km_aboveground_biomass_carbon_2010.tif')
bgc <- raster('carbon_layers/regrid_1km_below_biomass_carbon_2010.tif')
soc_0_20 <- raster('soil_data/regrid_1_band_ext_gfw_carbon_organic_1000m.tif')
soc_20_50 <- raster('soil_data/regrid_2_band_ext_gfw_carbon_organic_1000m.tif')

# mask none forest
abc[is.na(cp_gfw)] <- NA
bgc[is.na(cp_gfw)] <- NA
soc_0_20[is.na(cp_gfw)] <- NA
soc_20_50[is.na(cp_gfw)] <- NA

# convert to unit per km2
abc_tonne_1km2 <- abc * 100 # convert from mgC/ha to mgC/km2
bgc_tonne_1km2 <- bgc * 100 # convert from mgC/ha to mgC/km2

# back transform as per isda documentation
soc_0_20_g_kg <- exp(soc_0_20/10) -1 # back transform to g/kg
soc_20_50_g_kg <- exp(soc_20_50/10) -1 # back transform to g/kg

# bulk density ----
#import
bd_0_20 <-  raster('bulk_density/regrid_band1_ext_gfw_bulk_density_1000m.tif')
bd_20_50 <- raster('bulk_density/regrid_band2_ext_gfw_bulk_density_1000m.tif')

# back transform as per isdadocumentation
bd_0_20 <- bd_0_20/100 # back transform to g/cm3
bd_20_50 <- bd_20_50/100 # back transform to g/cm3

# convert to kg/m3
bd_0_20_kg_m3 = bd_0_20 * 1000
bd_20_50_kg_m3 = bd_20_50 * 1000

# convert to only top 20cm and 20cm - 50cm
bd_0_20_g_m3_20cm <- (bd_0_20_kg_m3/100) * 20 # 20cm of 100cm is 20%
bd_20_50_g_m3_30cm <- (bd_20_50_kg_m3/100) * 30 # 30cm of 100cm is 30%

# convert to km2
bd_0_20_kg_1km2 <- bd_0_20_g_m3_20cm * 1000000
bd_20_50_kg_1km2 <- bd_20_50_g_m3_30cm * 1000000

# calc soc per km2 using bulk density. 
soc_0_20_tonnes_km2 <- (soc_0_20_g_kg * bd_0_20_kg_1km2) / 1000000
soc_20_50_tonnes_km2 <- (soc_20_50_g_kg * bd_20_50_kg_1km2) / 1000000

# add soc layers together to get 0-50cm SOC
all_soc_tonnes_km2 <- soc_0_20_tonnes_km2 + soc_20_50_tonnes_km2

# import and format agricultural change layer
ag_2050 <- raster('Ag_change/regrid_41893_2020_656_MOESM11_ESM_change_2015.tif')
ag_2010 <- raster('Ag_change/regrid_AgriculturalLandCover_2010.tif')

# convert biomass values to 2050 values using agricultural proportion
abc_tonne_1km2_2010_ag_prop <- abc_tonne_1km2 * (1 - ag_2010)
bgc_tonne_1km2_2010_ag_prop <- bgc_tonne_1km2 * (1 - ag_2010)
abc_tonne_1km2_2050_ag_prop <- abc_tonne_1km2 * (1 - ag_2050)
bgc_tonne_1km2_2050_ag_prop <- bgc_tonne_1km2 * (1 - ag_2050)

#### WARNING #### this line removes all vars except those listed. 
rm(list=setdiff(ls(), c("abc_tonne_1km2_2010_ag_prop", 'bgc_tonne_1km2_2010_ag_prop', 'abc_tonne_1km2_2050_ag_prop', 'bgc_tonne_1km2_2050_ag_prop', 'all_soc_tonnes_km2', 'aoi')))

#extract and sum all pixels per PA.
abc_sum_2010 <- extract(abc_tonne_1km2_2010_ag_prop, aoi, fun = sum, df = T, na.rm = T)
bgc_sum_2010 <- extract(bgc_tonne_1km2_2010_ag_prop, aoi, fun = sum, df = T, na.rm = T)
abc_sum_2050 <- extract(abc_tonne_1km2_2050_ag_prop, aoi, fun = sum, df = T, na.rm = T)
bgc_sum_2050 <- extract(bgc_tonne_1km2_2050_ag_prop, aoi, fun = sum, df = T, na.rm = T)
soc_sum <- extract(all_soc_tonnes_km2, aoi, fun = sum, df = T, na.rm = T)

all_sum <- cbind(abc_sum_2010, bgc_sum_2010, abc_sum_2050, bgc_sum_2050, soc_sum, aoi$NAME)
head(all_sum)
names(all_sum) <- c('ID', 'abc_sum_tonne_km2_2010', 'ID', 'bgc_sum_tonne_km2_2010', 
                    'ID', 'abc_sum_tonne_km2_2050', 'ID', 'bgc_sum_tonne_km2_2050', 
                    'ID','soc_sum','Name')

# calc difference
all_sum$abc_sum_tonne_km2_difference_annual <- (all_sum$abc_sum_tonne_km2_2010 - all_sum$abc_sum_tonne_km2_2050)/40
all_sum$bgc_sum_tonne_km2_difference_annual <- (all_sum$bgc_sum_tonne_km2_2010 - all_sum$bgc_sum_tonne_km2_2050)/40

# write result
write.csv(all_sum, 'results/zonal_stats_carbon_REDD_v3.csv', row.names = F, quote = F)

