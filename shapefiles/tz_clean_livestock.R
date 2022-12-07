library(sf)
library(dplyr)
library(stringr)
library(mapview)

tzpa_old <- st_read("shapefiles\\combined_formatted_PAs_v1_4_nov_22.geojson")


# changed Ituru Forest, Magombera and Kalambo falls to nature reserves
# removed the merged Game Reserves as they were overlaid on blocks
# removed Mangroves, and Monduli Juu (duplicate)

tzpa <- st_read("shapefiles\\tz_all_pa_09052019\\tz_all_pa_09052019.shp") %>% 
  unique() %>% 
  mutate(Status = replace(Status, Name == "Kalambo falls", "NR")) %>% 
  mutate(Status = replace(Status, Name == "Ituru Forest", "NR")) %>% 
  mutate(Status = replace(Status, Name == "Magombera", "NR")) %>% 
  filter(!Status == "GR M") %>% 
  filter(!grepl("Mangroove|Mangrove|Merged|Monduli Juu O.A.", Name)) %>% 
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

mapview(tzpa, zcol = "Status")
mapview(tzpa, zcol = "livest_legal")
mapview(tzpa, zcol = "TH_legal")
