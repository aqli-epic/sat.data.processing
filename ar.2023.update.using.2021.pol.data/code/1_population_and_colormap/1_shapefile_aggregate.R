#> Last updated by Aarsh Batra (aarshbatra@uchicagotrust.org): November 02, 2022.

##########################################################

# 1_shapefile_aggregate.R

#

# Input: GADM shapefiles by admin level

# Output: Colormap, hover region, and US/China/India

#         shapefiles, with known errors corrected. Also,

#         crosswalk files between color and hover, and

#         hover and states.

##########################################################

#> benchmarking
start_time <- Sys.time()


library(dplyr)

library(sf)

library(ggplot2)

library(data.table)

library(assertthat)

library(haven)

library(geodata)

#> enter path to where your shapefiles folder is stored
ddir <- "./ar.2023.update.using.2021.pol.data/data/input/shapefiles"

# in_dir <- "gadm_levels"
#
# pak_dir <- "Pakistan/OCHA Pakistan shapefiles 20181218"

#> assuming the home directory is set to your root (.) below figure out the total number of layers in the geopackage data source
layer_info <- st_layers(dsn = "./ar.2023.update.using.2021.pol.data/data/input/shapefiles/gadm_410-levels/gadm_410-levels.gpkg")

#> reading in the gadm level geopackage file (which contains 6 layers, starting from "ADM_0" and going till to "ADM_5", even though we end up using only ADM_0, ADM_1, ADM_2. Also, keeping only relevant columns.

# admin level 0 (country)
gadm0 <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/gadm_410-levels/gadm_410-levels.gpkg", layer = "ADM_0", stringsAsFactors = FALSE) %>%
  select(GID_0, COUNTRY, geom) %>%
  rename(iso_alpha3 = GID_0,
         NAME_0 = COUNTRY,
         geometry = geom)

# admin level 1 (e.g. state), the terminology may be different for different countries. In this there is one polygon
# for which NAME_0 and NAME_1 equals the string "NA"
gadm1 <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/gadm_410-levels/gadm_410-levels.gpkg", layer = "ADM_1", stringsAsFactors = FALSE) %>%
  select(GID_0, COUNTRY, NAME_1, geom) %>%
  rename(iso_alpha3 = GID_0,
         NAME_0 = COUNTRY,
         geometry = geom)

# admin level 2 (e.g county, prefecture, district, etc.)
gadm2 <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/gadm_410-levels/gadm_410-levels.gpkg", layer = "ADM_2", stringsAsFactors = FALSE) %>%
  select(GID_0, COUNTRY, NAME_1, NAME_2, geom) %>%
  rename(iso_alpha3 = GID_0,
         NAME_0 = COUNTRY,
         geometry = geom)

# admin level 3 (e.g. sub-districts), this level we  don't use as of now (October 2022) in AQLI
gadm3 <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/gadm_410-levels/gadm_410-levels.gpkg", layer = "ADM_3", stringsAsFactors = FALSE) %>%
  select(GID_0, COUNTRY, NAME_1, NAME_2, NAME_3, geom) %>%
  rename(iso_alpha3 = GID_0,
         NAME_0 = COUNTRY,
         geometry = geom)


#> sanity checks on raw shape files

# duplicate country names in the gadm0 file (why?): India, China, Pakistan (probably due to political sensitivity)
gadm0$NAME_0[which(duplicated(gadm0$NAME_0))]

# any countries that are NA or "NA"
gadm0 %>% as_tibble() %>% filter(is.na(NAME_0)) # no
gadm1 %>% as_tibble() %>% filter(is.na(NAME_0)) # no
gadm2 %>% as_tibble() %>% filter(is.na(NAME_0)) # no

gadm0 %>% as_tibble() %>% filter(NAME_0 == "NA") # no
gadm1 %>% as_tibble() %>% filter(NAME_0 == "NA") # yes (1 row, this is an area in Scotland called Shetland Islands as per Google Maos. Assign it "United Kingdom" as its country, with "GBR" as its iso_alpha code.
gadm2 %>% as_tibble() %>% filter(NAME_0 == "NA") #no

# any states that are NA or "NA"
gadm1 %>% as_tibble() %>% filter(is.na(NAME_1)) # no
gadm2 %>% as_tibble() %>% filter(is.na(NAME_1)) # no

gadm1 %>% as_tibble() %>% filter(NAME_1 == "NA") # yes (5 rows): United Kingdom, Ireland, Marshall Islands, Netherlands, "NA"
gadm2 %>% as_tibble() %>% filter(NAME_1 == "NA") # yes (2 rows): United Kingdom

# any counties/districts/prefectures, etc that are NA
gadm2 %>% as_tibble() %>% filter(is.na(NAME_2)) # no
gadm2 %>% st_drop_geometry() %>% as_tibble() %>% filter(NAME_2 == "NA") %>% View()  # yes (104 rows): Åland, United Arab Emirates, Chile, United Kingdom, Ukraine, Uruguay,


#> setting the "NA" country in gadm1, to "United Kingdom", before creating the colormap shapefile
gadm1 <- gadm1 %>%
  mutate(NAME_1 = ifelse(NAME_0 == "NA", "Shetland Islands", NAME_1),
    NAME_0 = ifelse(NAME_0 == "NA", "United Kingdom", NAME_0),
         iso_alpha3 = ifelse(iso_alpha3 == "NA", "GBR", iso_alpha3))

#> ######## 1. Generate colormap shapefile ########

#Colormap = admin2 + (admin1 regions of countries with no admin2 recorded) + (admin0 of countries with no admin1 or admin2 recorded)

#Find countries in gadm1 shapefile but not in gadm2 shapefile

countries_to_add <- anti_join(data.frame(NAME_0=unique(gadm1$NAME_0)), data.frame(NAME_0=unique(gadm2$NAME_0)), by= "NAME_0")


# update the gadm2 shape file
gadm2 <- gadm1 %>%

  filter(NAME_0 %in% countries_to_add$NAME_0) %>%

  mutate(NAME_2 = "") %>%

  rbind(gadm2)



#Find countries in gadm0 shapefile but not in gadm1 (therefore also not in gadm2) shapefile

countries_to_add <- anti_join(data.frame(NAME_0=gadm0$NAME_0), data.frame(NAME_0=unique(gadm1$NAME_0)), by= "NAME_0")



gadm2 <- gadm0 %>%

  filter(NAME_0 %in% countries_to_add$NAME_0) %>%

  mutate(NAME_1 = "", NAME_2 = "") %>%

  rbind(gadm2)



#Number of countries in gadm2 shapefile should now equal number of countries in country-level shapefile

assert_that(length(unique(gadm2$NAME_0))==length(unique(gadm0$NAME_0))) # TRUE



# Delete Antarctica, because there is literally no air pollution (read this: https://www.npolar.no/en/themes/pollutants-in-antarctica/#toggle-id-1)

gadm2 <- gadm2 %>%

  filter(NAME_0 != "Antarctica")



# For Pakistan, replace "divisions" with shapefile of up-to-date districts, which is an admin level people care more about,

# and up-to-date province boundaries.

pak_districts <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/pakistan/pak_adm_wfp_20220909_shp/pak_admbnda_adm2_wfp_20220909.shp")

pak_districts <- pak_districts %>%
  rename(NAME_0 = ADM0_EN,
         NAME_1 = ADM1_EN,
         NAME_2 = ADM2_EN) %>%
  mutate(iso_alpha3 = "PAK") %>%
  select(iso_alpha3, NAME_0, NAME_1, NAME_2, geometry)

# replace pakistan division level polygons with the district wise polygons generated above.
gadm2 <- gadm2 %>%

  filter(NAME_0 != "Pakistan") %>%

  rbind(pak_districts)

  # these commented statements were adjustments made in the old code for Pakistan. We no longer need these adjustments as the new shapefile
  # already takes care of it. Also, in defining Pakistan, I have assumed that Azad Kashmir and Gilgit-Baltistan (previously known as Northern Areas)
  # are now part of Pakistan.

  # mutate(NAME_1 = ifelse(NAME_1 == "Northern Areas", "Gilgit-Baltistan", NAME_1)) %>%
  #
  # mutate(NAME_2 = ifelse(NAME_2 %in% c("Azad Kashmir", "Northern Areas"), "", NAME_2))



# In Nepal 7 provinces were created and the new shape file names all of them except Province number 1 and 2. Rename "Province 2" to "Madhesh" and
# "Province 1" remains the same. See the complete list here: https://en.wikipedia.org/wiki/Provinces_of_Nepal. Also, "district" is not an
# official administrative region in Nepal. It lies somewhere between ADM1 and ADM2. In other words, a district in Nepal would have multiple
# ADM2 regions in it. In the past, we used "districts" instead of "ADM2", probably because ADM2 regions end up becoming super small. As of
# now, I have continued to use the "districts" shape file.

nepal_districts <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/nepal/npl_admbnda_nd_20201117_shp/npl_admbnda_districts_nd_20201117.shp") %>%

  select(ADM0_EN, ADM1_EN, DIST_EN, geometry) %>%

  mutate(ADM1_EN = ifelse(ADM1_EN == "Province 2", "Madhesh", ADM1_EN)) %>%

  mutate(iso_alpha3 = "NPL") %>%

  rename(NAME_0 = ADM0_EN, NAME_1 = ADM1_EN, NAME_2 = DIST_EN)


# replace nepal gadm level 2 polygons with the updated nepal district wise polygons
gadm2 <- gadm2 %>%

  filter(NAME_0 != "Nepal") %>%

  rbind(nepal_districts)



# In Bangladesh, correct misspelled name "Netrakona" to "Netrokona", and in the new shape file the Mymensingh Division (that was carved out from Dhaka Division in 2015)
# is exactly what it should be, so past adjustments for that are no longer needed (hence removing that bit, but just wanted to add this note for the legacy code).

gadm2 <- gadm2 %>%

  mutate(NAME_2 = ifelse(NAME_0 == "Bangladesh" & NAME_1 == "Dhaka" & NAME_2 == "Netrakona", "Netrokona", NAME_2))



# Myanmar increased number of districts (ADM2 regions) in 2015. Also updating this by using the latest available shape file from November 17, 2020.
# But, do note that there aren't many changes compared to the last shape file. Myanmar administrative divisions are higher in number than we
# usually find in other countries (See: https://themimu.info/sites/themimu.info/files/documents/Administrative_Structure_2008Constitution_20Mar2020.pdf).
# Also, for our purposes, we assume ST to be "NAME_1" and "DT" to be "NAME_2". Compared to the previous shape file, this has been updated and
# contains updated border information.

myanmar_districts <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/myanmar/mmr_polbnda_adm2_250k_mimu_June_2021/mmr_polbnda_adm2_250k_mimu_june2021.shp") %>%

  select(ST, DT, geometry) %>%

  rename(NAME_1 = ST, NAME_2 = DT) %>%

  mutate(NAME_0 = "Myanmar") %>%

  mutate(iso_alpha3 = "MMR")


# replace Myanmar gadm level 2 polygons with the updated (last updated: June, 2021) Myanmar admin 2 level polygons
gadm2 <- gadm2 %>%

  filter(NAME_0 != "Myanmar") %>%

  rbind(myanmar_districts)



# In the new shape file, Hong Kong and Macao were a part of China, so that bit is up to date.


# Change Delhi's name_2 from "West" to "NCT of Delhi" (this stays)

gadm2 <- gadm2 %>%

  mutate(NAME_2 = ifelse(NAME_1 == "NCT of Delhi", NAME_1, NAME_2))



# Account for Telangana's many new districts. As of April 2019, there are 33 new districts.

# I started off with a base shape file of Telangana. This is not a gadm shapefile, its a different one
# (as listed above), because the gadm level 2 shape file only takes into account a subset of the 33 districts of Telangana. This is why we have
# to use a separate shape file for Telangana. But, even this new shapefile loaded in "telangana_districts" variable above does not contain
# 2 sub-district polygons. Two sub-districts of Bhadradri Kothagudem district (Bhadrachalam, Borgampad) are not included in the above definition of Bhadradri Kothagudem.
# These 2 sub-districts will be "unioned" with the rest of the definition of Bhadradri Kothagudem. All of this is done in QGIS. It can be done
# in R, but the st_union function of R is less accurate than the corresponding "dissolve" feature of QGIS. So, I have modified the base raw shapefile
# of Telangana, by making this additional adjustment. I'll directly load this file in and it'll be named the "telangana_districts_adjusted", to differentiate it from
# the raw telangana shape file (both of these will be present in the data/raw folder itself, the raw file can be identified with the "raw" suffix in
# front of it).

# In case you want to recreate the steps by which I got the asjusted base shape file for Telangana in QGIS, do this:

# Step 1: Take a symmetrical difference between telangana state level shape file (stored in the "telangana_other/telangana_state_gadm1" folder)
# and the telangana district level shape file (stored in the "telangana_raw_districts" folder). This will give you a shape that will comprise
# of the two missing sub-districts of Bhadradri Kothagudem (Bhadrachalam, Borgampad) and some additional space, which we will group into
# Bhadradri Kothagudem itself.

# Step 2: Use the output from Step 1 and to it add the rest of the "Bhadradri Kothagudem" (present in the telangana_other/bhadradri_kothagudem_district folder),
# by using a "union" operation. Then, dissolve this union into a single polygon, which will then be the final "Bhadradri Kothagudem" district.

# Step 3: Add the output from Step 2, to the "everything_except_bhadradri_kothagudem_district_non_gadm.shp" file (by taking a union), present in the folder of the
# same name.

# At this point, you'll have a final Telangana base shape file that I'll further clean in R below.

# Also, just a quick note - past code that was used to make similar adjustments to Telangana was inaccurate and it left a blank white spot
# in the map (which can be seen if you zoom in around the areas mentioned above). That spot is fixed using the above process. So, all past adjustment
# code has been removed. Also, in the past code comments it was mentioned that Bhadrachalam and Bhadradri are supposed to be part of
# Andhra Pradesh, but that's not true, they belong in the "Bhadradri Kothagudem" district of Telangana itself.

telangana_districts <- st_read("./ar.2023.update.using.2021.pol.data/data/input/shapefiles/telangana/telangana_adjusted/telangana_adjusted_base_map_used_in_colormap.shp")

telangana_districts <- telangana_districts %>%
  st_make_valid() %>%
  group_by(NAME_2_2) %>% # this takes care of the duplicate polygons and makes sure that the final number of polygons in Telangana = 33.
  summarise() %>%
  ungroup() %>%
  rename(NAME_2 = NAME_2_2) %>%
  mutate(NAME_0 = "India",
         NAME_1 = "Telangana",
         iso_alpha3 = "IND") %>%
  select(iso_alpha3, NAME_0, NAME_1, NAME_2)

gadm2 <- gadm2 %>%

  filter(!(NAME_0=="India" & NAME_1 == "Telangana")) %>%

  rbind(telangana_districts)


# In the old shape file it was assumed that parts of Bhadradri Kothagudem stayed in Andhra Pradesh's East Godavri region and were grouped
# back into AP. But, that is incrorect. Those parts should stay in "Bhadradri Kothagudem" (which is a district in Telangana), and the above
# Telangana adjustment takes that into account. So, now the additional adjustment in AP's West/East Godavri region is not needed (hence removed). Also, previously,
# the AP adjustment was leading to a "white" crack in the map, a place with no data lying at the border of  East Godavri and Bhadradri
# Kothagudem. But, the above Telangana adjustment has now fixed that, such that there is no place with in Telangana or AP, where there is
# missing data.


# New district "Charkhi Dadri" in Haryana carved out of Bhiwani district (this stays)

bhiwani <- gadm3 %>%

  filter(NAME_1 == "Haryana" & NAME_2 == "Bhiwani") %>%

  mutate(NAME_2 = ifelse(NAME_3 == "Dadri", "Charkhi Dadri", "Bhiwani")) %>%

  group_by(iso_alpha3, NAME_0, NAME_1, NAME_2) %>%

  summarise()


# replacing the current bhiwani district defintion with the above definition.
gadm2 <- gadm2 %>%

  filter(!(NAME_1 == "Haryana" & NAME_2 == "Bhiwani")) %>%

  rbind(bhiwani)



# Correct misspelled/changed Indian district names, mostly identified by Vikram at EPIC-India

gadm2 <- gadm2 %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Maharashtra" & NAME_2 == "Raigarh", "Raigad", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Maharashtra" & NAME_2 == "Buldana", "Buldhana", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Maharashtra" & NAME_2 == "Bid", "Beed", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Maharashtra" & NAME_2 == "Garhchiroli", "Gadchiroli", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Chhattisgarh" & NAME_2 == "Kabeerdham", "Kabirdham", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Gujarat" & NAME_2 == "Banas Kantha", "Banaskantha", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Gujarat" & NAME_2 == "The Dangs", "Dang", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Haryana" & NAME_2 == "Gurgaon", "Gurugram", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Bellary", "Ballari", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Bijapur", "Vijaypura", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Chikballapura", "Chikballapur", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Gulbarga", "Kalaburagi", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Shimoga", "Shivamogga", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Karnataka" & NAME_2 == "Tumkur", "Tumakuru", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Madhya Pradesh" & NAME_2 == "West Nimar", "Khargone", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Maharashtra" & NAME_2 == "Ahmadnagar", "Ahmednagar", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Odisha" & NAME_2 == "Bauda", "Boudh", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Odisha" & NAME_2 == "Debagarh", "Deogarh", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Odisha" & NAME_2 == "Nabarangapur", "Nabarangpur", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Punjab" & NAME_2 == "Muktsar", "Sri Muktsar Sahib", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Rajasthan" & NAME_2 == "Jhunjhunun", "Jhunjhunu", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Tamil Nadu" & NAME_2 == "Thoothukkudi", "Thoothukudi", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Tamil Nadu" & NAME_2 == "Virudunagar", "Virudhunagar", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Tripura" & NAME_2 == "Sipahijala", "Sepahijala", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Uttar Pradesh" & NAME_2 == "Allahabad", "Prayagraj", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Uttar Pradesh" & NAME_2 == "Sant Ravi Das Nagar", "Bhadohi", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Uttarakhand" & NAME_2 == "Garhwal", "Pauri Garhwal", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "West Bengal" & NAME_2 == "Darjiling", "Darjeeling", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "West Bengal" & NAME_2 == "Haora", "Howrah", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "West Bengal" & NAME_2 == "Hugli", "Hooghly", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Bhadradri", "Bhadradri Kothagudem", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Jagitial", "Jagtial", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Jayashankar", "Jayashankar Bhupalpally", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Jogulamba", "Jogulamba Gadwal", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Komarambhem", "Kumuram Bheem", NAME_2))%>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Peddapalle", "Peddapalli", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Rajanna", "Rajanna Sircilla", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Warangal_Rural", "Warangal (Rural)", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Warangal_Urban", "Warangal (Urban)", NAME_2)) %>%

  mutate(NAME_2 = ifelse(NAME_0 == "India" & NAME_1 == "Telangana" & NAME_2 == "Yadadri", "Yadadri Bhuvanagiri", NAME_2))



# As of Oct 31, 2019, Ladakh has been carved out of Jammu and Kashmir as separate union territory

gadm2 <- gadm2 %>%

  mutate(NAME_1 = ifelse(NAME_1 == "Jammu and Kashmir" & NAME_2 %in% c("Kargil", "Leh (Ladakh)"), "Ladakh", NAME_1))



# Delete fake lake counties in the Great Lakes region. Conveniently, there are no real counties

# named exactly after the lakes.

gadm2 <- gadm2 %>%

  filter(!(NAME_0 %in% c("United States", "Canada") & NAME_2 %in% c("Lake Michigan", "Lake Erie", "Lake Huron", "Lake Superior", "Lake Ontario", "Lake Hurron")))



# Correct outdated prefecture name in China

gadm2 <- gadm2 %>%

  mutate(NAME_2 = ifelse(NAME_0 == "China" & NAME_1 == "Hubei" & NAME_2 == "Xiangfan", "Xiangyang", NAME_2))



# Separate two prefectures in Liaoning, China that are incorrectly lumped as one

tieling_yingkou <- gadm3 %>%

  filter(NAME_0 == "China" & NAME_1 == "Liaoning" & NAME_2 == "Tieling") %>%

  mutate(NAME_2 = ifelse(NAME_3 %in% c("Gai", "Yinzhou", "Yingkou"), "Yingkou", "Tieling")) %>%

  group_by(iso_alpha3, NAME_0, NAME_1, NAME_2) %>%

  summarise()



gadm2 <- gadm2 %>%

  filter(!(NAME_0 == "China" & NAME_1 == "Liaoning" & NAME_2 == "Tieling")) %>%

  rbind(tieling_yingkou)



# Anhui, China

# Chaohu Prefecture was split among Hefei, Ma'anshan, and Wuhu Prefectures in 2011

# Zongyang County transferred from Anqing Prefecture to Tongling Prefecture in 2016

# Shou County transferred from Lu'an Prefecutre to Huainan Prefecture in 2015

chaohu <- gadm3 %>%

  filter(NAME_0 == "China" & NAME_1 == "Anhui" & NAME_2 == "Chaohu")



anqing_tongling <- gadm3 %>%

  filter(NAME_0 == "China" & NAME_1 == "Anhui" & NAME_2 %in% c("Anqing", "Tongling")) %>%

  mutate(NAME_2 = ifelse(NAME_3 == "Zongyang", "Tongling", NAME_2)) %>%

  group_by(iso_alpha3, NAME_0, NAME_1, NAME_2) %>%

  summarise()



luan_huainan <- gadm3 %>%

  filter(NAME_0 == "China" & NAME_1 == "Anhui" & NAME_2 %in% c("Lu'an", "Huainan")) %>%

  mutate(NAME_2 = ifelse(NAME_3 == "Shou", "Huainan", NAME_2)) %>%

  group_by(iso_alpha3, NAME_0, NAME_1, NAME_2) %>%

  summarise()



anhui <- gadm2 %>%

  filter(NAME_0 == "China" & NAME_1 == "Anhui") %>%

  filter(!(NAME_2 %in% c("Chaohu", "Anqing", "Tongling", "Lu'an", "Huainan"))) %>%

  mutate(NAME_3 = NAME_2) %>%

  rbind(chaohu) %>%

  mutate(NAME_3 = ifelse(NAME_3 %in% c("Chao", "Lujiang"), "Hefei", NAME_3)) %>%

  mutate(NAME_3 = ifelse(NAME_3 == "Wuwei", "Wuhu", NAME_3)) %>%

  mutate(NAME_3 = ifelse(NAME_3 %in% c("He", "Hanshan"), "Ma'anshan", NAME_3)) %>%

  group_by(iso_alpha3, NAME_0, NAME_1, NAME_3) %>%

  summarise() %>%

  rename(NAME_2 = NAME_3) %>%

  rbind(anqing_tongling) %>%

  rbind(luan_huainan) %>%

  st_buffer(0.01)



gadm2 <- gadm2 %>%

  filter(!(NAME_0 == "China" & NAME_1 == "Anhui")) %>%

  rbind(anhui)



# Sort and create numeric ID variable. ID name needs to be <=10 chars for export as SHP.

gadm2 <- gadm2[with(gadm2, order(NAME_0, NAME_1, NAME_2)),] %>%

  mutate(objectid = row_number())



# Resolve self-intersecting polygons, which would cause problems for st_intersection commands later in code

gadm2[which(st_is_valid(gadm2) == FALSE),] <- st_buffer(gadm2[which(st_is_valid(gadm2) == FALSE),], dist = 0)



# Export colormap shapefile

st_write(gadm2, file.path(ddir, "color/colormap.shp"), layer_options = "ENCODING=UTF-8", delete_layer = TRUE)

print("All adjustments to shapefile completed and color map shape file written.")

######## 2. Aggregate to hover shapefile ########

# List of countries for which whole country should be single hover region

agg0 <- c("Akrotiri and Dhekelia", "American Samoa", "Andorra", "Antigua and Barbuda", "Barbados",

						 "Bonaire, Sint Eustatius and Saba", "British Virgin Islands", "Cape Verde", "Cayman Islands",

						 "Comoros", "Cyprus", "Dominica", "Faroe Islands", "Fiji", "French Polynesia",

						 "French Southern Territories", "Grenada", "Guernsey", "Isle of Man", "Liechtenstein",

						 "Martinique", "Mauritius", "Mayotte", "Micronesia", "Montserrat", "Nauru",

						 "New Caledonia", "Northern Cyprus", "Northern Mariana Islands", "Palau", "Puerto Rico",

						 "Reunion", "Saint Helena", "Saint Kitts and Nevis", "Saint Lucia", "Saint Pierre and Miquelon",

						 "Saint Vincent and the Grenadines", "Samoa", "San Marino", "Seychelles",

						 "Solomon Islands", "Svalbard and Jan Mayen", "Timor-Leste", "Tokelau", "Tonga",

						 "Trinidad and Tobago", "Turks and Caicos Islands", "Tuvalu", "United States Minor Outlying Islands",

						 "Vanuatu", "Virgin Islands, U.S.", "Wallis and Futuna")

# Aland, Sao Tome and Principe have Unicode characters in their names which can cause problems,

# so use ISO code to get them

agg0_iso <- c("ALA", "STP")



# List of countries for which hover regions should be admin1 regions because there are too many admin2 regions and/or admin2 regions are too small

agg1 <- c("Afghanistan", "Algeria", "Argentina", "Armenia", "Australia", "Austria",

						 "Azerbaijan", "Bahamas", "Benin", "Bhutan", "Brazil",

						 "Brunei", "Bulgaria", "Burundi", "Cambodia", "Colombia", "Costa Rica", "Croatia", "Cuba", "Czech Republic",

						 "Denmark", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Estonia",

						 "Ethiopia", "Gambia", "Georgia", "Germany", "Guatemala", "Guinea-Bissau",

						 "Guyana", "Haiti", "Honduras", "Hungary", "Iceland", "Iran", "Israel",

						 "Jamaica", "Japan", "Jordan", "Kenya", "Kazakhstan", "Kosovo",

						 "Kyrgyzstan", "Laos", "Lebanon", "Lesotho", "Liberia",

						 "Libya", "Macedonia", "Malawi", "Mexico", "Mongolia", "Namibia",

						 "Netherlands", "New Zealand", "Nicaragua", "Nigeria", "North Korea", "Norway",

						 "Palestina", "Panama", "Paraguay", "Philippines", "Poland", "Portugal",

						 "Romania", "Russia", "Rwanda", "Senegal", "Serbia", "Slovakia", "Slovenia",

						 "Sri Lanka", "Suriname", "Swaziland", "Sweden", "Switzerland", "Tajikistan",

						 "Tanzania", "Thailand", "Togo", "Tunisia", "Turkey",

						 "Turkmenistan", "Uganda", "Ukraine", "Uruguay", "Uzbekistan",

						 "Venezuela", "Vietnam", "Yemen")



# Start with color shapefile, and delete regions in above countries

hover <- gadm2 %>%

  filter(!(NAME_0 %in% agg0 | iso_alpha3 %in% agg0_iso | NAME_0 %in% agg1)) %>%

  select(-objectid)



# Add in country-level polygons for countries in agg0

hover <- gadm0 %>%

  filter(NAME_0 %in% agg0 | iso_alpha3 %in% agg0_iso) %>%

  mutate(NAME_1 = "", NAME_2 = "") %>%

  rbind(hover)



# Add in admin1-level polygons for countries in agg1

# Note: If any of the countries in agg1 were modified manually above, then

# their admin1 polygons in gadm1 are possibly wrong. In this case, for those

# countries, start with gadm2, group by NAME_1, and summarize.

hover <- gadm1 %>%

  filter(NAME_0 %in% agg1) %>%

  mutate(NAME_2 = "") %>%

  rbind(hover)



# Create ID

hover <- hover[with(hover, order(NAME_0, NAME_1, NAME_2)),] %>%

  mutate(objectid = row_number())



# Export as shapefile

st_write(hover, file.path(ddir, "county_hover/hover.shp"), layer_options = "ENCODING=UTF-8", delete_layer = TRUE)


print("Hover map shape file written")


######## 3. Generate hover/color crosswalk file ########

# Make sure region names uniquely identify observations

assert_that(any(duplicated(data.table(gadm2 %>% st_set_geometry(NULL)), by=c("NAME_0", "NAME_1", "NAME_2")))==FALSE)



# Start with colormap regions that have 1-to-1 correspondance with hover regions

hover_color_cw <- inner_join(gadm2 %>% st_set_geometry(NULL) %>% rename(objectid_color = objectid),

  hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid), by=c("NAME_0", "NAME_1", "NAME_2")) %>%

  select(objectid_color, objectid_hover)



# Add in colormap regions that got replaced by admin1 regions in hover shapefile

hover_color_cw <- inner_join(gadm2 %>% st_set_geometry(NULL) %>% rename(objectid_color = objectid) %>% filter(NAME_0 %in% agg1),

  hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid), by=c("NAME_0", "NAME_1")) %>%

  select(objectid_color, objectid_hover) %>%

  rbind(hover_color_cw)



# Add in colormap regions that got replaced by admin0 regions in hover shapefile

hover_color_cw <- inner_join(gadm2 %>% st_set_geometry(NULL) %>% rename(objectid_color = objectid) %>% filter(NAME_0 %in% agg0 | iso_alpha3 %in% agg0_iso),

  hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid), by=c("NAME_0")) %>%

  select(objectid_color, objectid_hover) %>%

  rbind(hover_color_cw)



# Remove duplicate rows

hover_color_cw <- hover_color_cw[!duplicated(data.table(hover_color_cw)),]

assert_that(any(duplicated(data.table(hover_color_cw)))==FALSE)



# Export as text file

write.table(hover_color_cw, file = file.path(ddir, "crosswalks/gadm_hover_color_crosswalk.txt"), row.names = FALSE, quote = FALSE, sep = ",")


print("hover/color crosswalk file written")

######## 4. Generate US China India state/province shapefiles ########

# US: make state shapefile from admin2 shapefile to account for lakes in state shapes

us_state <- gadm2 %>%

  filter(NAME_0 == "United States") %>%

  group_by(NAME_0, NAME_1, iso_alpha3) %>%

  summarise()

us_state <- us_state[with(us_state, order(NAME_1)),] %>%

  tibble::rowid_to_column("id_state")

st_write(us_state, file.path(ddir, "usa_india_china_state/USA_adm1.shp"), layer_options = "ENCODING=UTF-8", delete_layer = TRUE)



# China - remembering to add in Hong Kong and Macao

china_state <- gadm0 %>%

  filter(NAME_0 %in% c("Hong Kong", "Macao")) %>%

  mutate(NAME_1 = NAME_0, NAME_0 = "China") %>%

  rbind(gadm1 %>% filter(NAME_0 == "China"))

china_state <- china_state[with(china_state, order(NAME_1)),] %>%

  tibble::rowid_to_column("id_state")

st_write(china_state, file.path(ddir, "usa_india_china_state/CHN_adm1.shp"), layer_options = "ENCODING=UTF-8", delete_layer = TRUE)



# India: make state shapefile from admin2 shapefile to account for separate Ladahk UT

india_state <- gadm2 %>%

  filter(NAME_0 == "India") %>%

  group_by(NAME_0, NAME_1, iso_alpha3) %>%

  summarise()

india_state <- india_state[with(india_state, order(NAME_1)),] %>%

  tibble::rowid_to_column("id_state")

st_write(india_state, file.path(ddir, "usa_india_china_state/IND_adm1.shp"), layer_options = "ENCODING=UTF-8", delete_layer = TRUE)


print("USA/India/China state shape files written")

######## 5. Generate crosswalk files between US China India state/province and hover regions ########

us_state_cw <- inner_join(hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid),

    us_state %>% st_set_geometry(NULL)%>% rename(objectid_state = id_state),

    by=c("NAME_0", "NAME_1")) %>%

  select(objectid_hover, objectid_state)

assert_that(nrow(us_state_cw)==nrow(hover %>% filter(NAME_0=="United States")))

write.table(us_state_cw, file = file.path(ddir, "crosswalks/USA_state_hover_crosswalk.txt"), row.names = FALSE, quote = FALSE, sep = ",")



china_state_cw <- inner_join(hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid),

    china_state %>% st_set_geometry(NULL)%>% rename(objectid_state = id_state),

    by=c("NAME_0", "NAME_1")) %>%

  select(objectid_hover, objectid_state)

assert_that(nrow(china_state_cw)==nrow(hover %>% filter(NAME_0=="China")))

write.table(china_state_cw, file = file.path(ddir, "crosswalks/China_state_hover_crosswalk.txt"), row.names = FALSE, quote = FALSE, sep = ",")



india_state_cw <- inner_join(hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid),

    india_state %>% st_set_geometry(NULL)%>% rename(objectid_state = id_state),

    by=c("NAME_0", "NAME_1")) %>%

  select(objectid_hover, objectid_state)

assert_that(nrow(india_state_cw)==nrow(hover %>% filter(NAME_0=="India")))

write.table(india_state_cw, file = file.path(ddir, "crosswalks/India_state_hover_crosswalk.txt"), row.names = FALSE, quote = FALSE, sep = ",")


print("USA, India, China State cross walks written")

######## 6. Generate colormap/national PM2.5 standard correspondance and objectid/region name files ########

standards <- read_dta("C:/Arc/Preserve/data/standards/country_standards.dta") %>%

  rename(NAME_0 = Country, pm25standard = PM25Standard)



color_country_cw <- gadm2 %>%

  st_set_geometry(NULL) %>%

  left_join(standards, by = "NAME_0") %>%

  select(objectid, pm25standard)



write_dta(color_country_cw, "C:/Arc/Preserve/data/standards/colormap_country_standards.dta")



color_names <- gadm2 %>% st_set_geometry(NULL) %>% rename(objectid_color = objectid)

write_dta(color_names, file.path(ddir, "crosswalks/color_names.dta"))



hover_names <- hover %>% st_set_geometry(NULL) %>% rename(objectid_hover = objectid)

write_dta(hover_names, file.path(ddir, "crosswalks/hover_names.dta"))

print("All Done!")

end_time <- Sys.time()

elapsed_time <- end_time - start_time

print(str_c("Elapsed Time:", elapsed_time, sep = " "))
