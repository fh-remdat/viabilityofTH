# format additional PAs 

library(sf)
library(dplyr)

setwd('/home/freddie/Cloud_Free_Metrics/PA_paper/data/')
do_fuzzy = FALSE # Do not change to true. Code to show working. 

if (do_fuzzy == TRUE) {
  # master shapefile
  ma_shp <- st_read('fwpamastershapefile/PAs_MasterFile_FEB2021.shp')
  
  # fuzzy logic names
  tz_dat <-
    'additional_shapefiles/Files/tz_all_pa_09052019/tz_all_pa_09052019.shp' %>% st_read() %>% st_transform(st_crs(ma_shp)) # %>% st_drop_geometry()
  ruth_dat <- ma_shp %>% st_drop_geometry()
  
  tz_fuzzy <- stringdist_join(
    tz_dat,
    ruth_dat,
    by = 'NAME',
    #match based on team
    mode = 'left',
    #use left join
    method = "jw",
    #use jw distance metric
    max_dist = 99,
    distance_col = 'dist'
  )  %>%
    group_by(NAME.x) %>%
    slice_min(order_by = dist, n = 1) %>%
    filter(dist < 0.1)
  
  # for those matched with tz pa file remove from ruth dataset.
  ma_shp_tz_rm <-
    ma_shp %>% filter(!NAME %in% list(tz_fuzzy$NAME.y)[[1]])
  
  # find remaining PAs where Ruth data set overlaps TZ and remove PAs where they overlap by 50% or more and keep Tz version
  st_write(
    tz_fuzzy,
    'additional_shapefiles/Files/selected/Additional_hunting_pas_per_country/selected_tz_with_ats.geojson',
    'selected_tz_with_ats',
    driver = 'GeoJSON'
  )
  tz_dat <- tz_dat %>% filter(!NAME %in% list(tz_fuzzy$NAME.y)[[1]])
  st_write(
    tz_dat,
    'additional_shapefiles/Files/selected/Additional_hunting_pas_per_country/selected_tz_no_ats.geojson',
    'selected_tz_no_ats',
    driver = 'GeoJSON'
  )
  # At this point qgis was used to manually remove any PAs in ruth data set that overlap with Tz data set. 
}


comb_shp <- st_read('formatted_pa_shapefiles/ruth_data_tz_removed.geojson')

# shapefiles to merge 
flist <- list.files('additional_shapefiles/Files/selected/Additional_hunting_pas_per_country/', pattern = 'geojson', full.names = TRUE)

for (file in flist){
  
  print(file)
  shp <- st_read(file) %>% st_transform(st_crs(comb_shp))
  shp <- st_zm(shp)
  if (basename(file) == 'keconservnacies.geojson') { 
    shp$TH_legal <- 0} else if (grepl(basename('selected_tz'), file)) {
      shp$TH_legal <- NA
    } else {
      shp$TH_legal <- 1
    }
  shp$og_file <- basename(file)
  com_nmds <- intersect(names(comb_shp), names(shp))
  comb_shp <- rbind(comb_shp[com_nmds], shp[com_nmds])
    
}

# add back in Ruth data
ma_dat <- comb_shp %>% st_drop_geometry()
comb_shp_dat <- merge(comb_shp, ma_dat)
st_write(comb_shp, 'formatted_pa_shapefiles/combined_formatted_PAs_v1_4_nov_22.geojson', 'combined_formatted_PAs_v1_4_nov_22', driver = 'GeoJSON')
