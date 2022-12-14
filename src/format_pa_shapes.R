# format additional PAs 

library(sf)
library(dplyr)
library(fuzzyjoin)
library(glue)

setwd('/home/freddie/Cloud_Free_Metrics/PA_paper/shapefiles/to_combine/')

form_tz <- function(shp){
  tzpa <- st_read("tz_all_pa_09052019.shp") %>% 
    unique() %>% 
    mutate(Status = replace(Status, NAME == "Kalambo falls", "NR")) %>% 
    mutate(Status = replace(Status, NAME == "Ituru Forest", "NR")) %>% 
    mutate(Status = replace(Status, NAME == "Magombera", "NR")) %>% 
    filter(!Status == "GR M") %>% 
    filter(!grepl("Mangroove|Mangrove|Merged|Monduli Juu O.A.", NAME)) %>% 
    mutate(
      livest_legal = case_when(
        Status == "CA" ~ "1",
        Status == "FR" ~ "1",
        Status == "GCA" ~ "1",
        Status == "GR" ~ "0",
        Status == "NP" ~ "0",
        Status == "NR" ~ "0",
        Status == "OA" ~ "1")) %>% 
    mutate(
      TH_legal = case_when(
        Status == "CA" ~ "0",
        Status == "FR" ~ "1",
        Status == "GCA" ~ "1",
        Status == "GR" ~ "1",
        Status == "NP" ~ "0",
        Status == "NR" ~ "0",
        Status == "OA" ~ "1"))
}

# not used as of (30 nov 2022)
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

comb_shp <- st_read('PAs_MasterFile_FEB2021.shp')
comb_shp$og_file <- 'PAs_MasterFile_FEB2021.shp'
comb_shp$livest_legal <- 'unknown'
ma_dat <- comb_shp %>% st_drop_geometry()

# shapefiles to merge 
tz_file = 'tz_all_pa_09052019.shp'
flist <- list.files('./', pattern = 'geojson', full.names = TRUE)
flist[6] <- tz_file
for (file in flist){
  
  print(file)
  shp <- st_read(file) %>% st_transform(st_crs(comb_shp))
  shp <- st_zm(shp)
  shp$livest_legal <- 'unknown'
  if (basename(file) == 'keconservnacies.geojson') { 
    shp$TH_legal <- 0}  else if (basename(file) == 'tz_all_pa_09052019.shp') {
        shp <- form_tz(shp) %>% st_transform(st_crs(comb_shp))
        #shp$HuntArea <- as.character(shp$HuntArea)
        #shp$TH_legal <- 0
        #shp$TH_legal[shp$HuntArea == "Yes"] <- 1
    } else {
      shp$TH_legal <- 1
    }
  shp$og_file <- basename(file)
  com_nmds <- intersect(names(comb_shp), names(shp))
  comb_shp <- rbind(comb_shp[com_nmds], shp[com_nmds])
    
}

# add back in Ruth data
comb_shp_dat <- sp::merge(comb_shp, ma_dat, all.x = TRUE, all.y = TRUE, by= 'NAME')

# drop dup cols_drop
comb_shp_dat_dropped <- comb_shp_dat %>%
  select(!contains(c(".y")))

# rename 
comb_shp_dat_dropped_rn <- comb_shp_dat_dropped %>%
  rename(TH_legal= TH_legal.x) %>% rename(livest_legal = livest_legal.x) %>% rename(og_file = og_file.x)

st_write(comb_shp_dat_dropped_rn, glue('combined_formatted_PAs_{Sys.Date()}.geojson'), glue('combined_formatted_PAs_{Sys.Date()}'), driver = 'GeoJSON')
