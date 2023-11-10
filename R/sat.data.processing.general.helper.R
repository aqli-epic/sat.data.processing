# satellite data processing helper script

#> writing a function that would rasterize a given number of objectid's of a shapefile to a resolution of a given reference resolution and then
# and then map pollution and population data onto it, to finally output a gadm level 2 file that would
# contain the population, pollution data for that region.



regional_summary <- function(colormap, pol_data_location, pop_raw_raster, resample_to_res, objectid_vec, pol_data_start_year, pop_raster_res){

  # pol data list
  pol_data_list <- list.files(pol_data_location) %>% sort()

  # pollution column names empty vector
  pol_col_name_vec <- c()

  # region years list
  region_years_list <- list()

  # master region years list
  master_region_years_list <- list()

  for(i in 1: length(objectid_vec)){

    # close all connections
    closeAllConnections()

    # rasterizing a subset of the colormap shapefile to a reference resolution using fasterize: test (Gujarat): Works
    region_rasterized_shapefile <- fasterize(colormap %>% filter(objectid == objectid_vec[i]),
                                             raster::raster(ext = raster::extent(colormap %>% filter(objectid == objectid_vec[i])),
                                                            resolution = resample_to_res, crs = crs(colormap)), field = "objectid", fun = "last")
    # set the name of the regional rasterized shapefile
    names(region_rasterized_shapefile) <- "objid"

    for(j in 1:length(pol_data_list)){

      # ui
      print(stringr::str_c("Region number " , i, ": Iteration #", j, "/", (update_year - pol_data_start_year) + 1, " begins"))

      # filling in the name of the current pollution year
      pol_col_name_vec[j] <- str_c("pm", (pol_data_start_year + (j-1)))

      # storing a separate copy of the current pollution year in a separate object, for later use in the rename command
      cur_pol_col_name <- pol_col_name_vec[j]

      # pollution file name given the current iteration
      cur_pol_file_name <- pol_data_list[j]

      # cur pollution file year
      cur_pol_file_year <- stringr::str_extract(str_extract(cur_pol_file_name, "(\\d+)-(\\d+)"), "....")

      # read in the pollution raster for a given year
      pol_raw_raster <- raster::raster(str_c(pol_data_location, cur_pol_file_name, sep = ""))

      # crop raw pollution raster to the extent of the above raster
      pol_raster_cropped <- crop(pol_raw_raster, extent(region_rasterized_shapefile))

      # set crs of the pollution raster
      crs(pol_raster_cropped) <- "+proj=longlat +datum=WGS84 +no_defs"

      # match resolution of pollution raster with the rasterized regionshape file
      pol_raster_cropped_new_res <- raster::resample(pol_raster_cropped, region_rasterized_shapefile, method = "ngb")

      names(pol_raster_cropped_new_res) <- "pol"

      # mask pol_2018_0.01_test_shajrah to the qgis raster
      pol_raster_cropped_new_res_masked <- raster::mask(pol_raster_cropped_new_res, region_rasterized_shapefile)

      # set the name of the pollution raster
      names(pol_raster_cropped_new_res_masked) <- "pol"

      # crop population raw data to region rasterized shapefile
      pop_raster_cropped <- crop(pop_raw_raster, extent(region_rasterized_shapefile))

      crs(pop_raster_cropped) <- "+proj=longlat +datum=WGS84 +no_defs"

      # replacing the population with population densities
      raster::values(pop_raster_cropped) <- as.vector(pop_raster_cropped * (((resample_to_res)^2)/((pop_raster_res)^2)))

      # performing idw on population densities

      #match resolution of the pop_raster_cropped population raster with region_rasterized_shapefile
      pop_raster_cropped_new_res <- raster::resample(pop_raster_cropped, region_rasterized_shapefile, method = "ngb")


      # mask population raw data to sharjah
      pop_raster_cropped_new_res_masked <- raster::mask(pop_raster_cropped_new_res,
                                                        region_rasterized_shapefile)

      # pop_raster_cropped_new_res
      names(pop_raster_cropped_new_res_masked) <- "pop"

      # create a brick
      region_brick <- region_rasterized_shapefile %>%
        addLayer(pol_raster_cropped_new_res_masked) %>%
        addLayer(pop_raster_cropped_new_res_masked)

      # brick df
      region_brick_df <- region_brick %>%
        raster::as.data.frame()

      # convert dataframe into an arrow table
      region_brick_df_arrow <- region_brick_df %>%
        arrow::as_arrow_table()

      # summarizing and finally testing (note that as a result of resampling tiny regions to a high resolution, and then
      # collapsing them at gadm level 2, the population might not be an integer, hence rounding is needed in the population column)
      region_brick_df_arrow_summary <- region_brick_df_arrow %>%
        dplyr::filter((!is.na(objid)) & ((as.character(objid) != "NA"))) %>%
        dplyr::group_by(objid) %>%
        dplyr::collect() %>%
        dplyr::mutate(pop_weights = pop/sum(pop, na.rm = TRUE),
                      pollution_pop_weighted = pop_weights*pol) %>%
        dplyr::summarise(total_population = round(sum(pop, na.rm = TRUE)),
                         avg_pm2.5_pollution = sum(pollution_pop_weighted, na.rm = TRUE)) %>%
        dplyr::rename(objectid_gadm2 = objid)

      # joining with the colormap to get area names
      region_brick_df_arrow_summary_shp <- region_brick_df_arrow_summary %>%
        left_join(colormap, by = c("objectid_gadm2" = "objectid")) %>%
        mutate(whostandard = who_pm2.5_standard) %>%
        select(objectid_gadm2, iso_alpha3, NAME_0, NAME_1, NAME_2, total_population, whostandard, avg_pm2.5_pollution, geometry) %>%
        rename(country = NAME_0, name_1 = NAME_1, name_2 = NAME_2, population = total_population, !!cur_pol_col_name := avg_pm2.5_pollution)


      # remove the geometry column
      region_brick_df_arrow_summary_non_geom <- region_brick_df_arrow_summary_shp %>%
        sf::st_as_sf() %>%
        sf::st_drop_geometry()

      region_years_list[[j]] <- region_brick_df_arrow_summary_non_geom

      if(j == 1){
        master_region_df <- region_years_list[[j]]
      } else {
        master_region_df <- master_region_df %>%
          left_join(region_years_list[[j]], by = c("objectid_gadm2", "iso_alpha3", "country", "name_1", "name_2", "population", "whostandard"))
      }


      print(str_c("j: ", j))

      # close all connections
      closeAllConnections()

    }

    master_region_years_list[[i]] <- master_region_df

    # close all connections
    closeAllConnections()

    }


  final_df_return <- dplyr::bind_rows(master_region_years_list)

  return(final_df_return)

}


#------------------------------------------------------------------------------------------------------

# obj id
pak_obj_id <- colormap %>% filter(NAME_0 == "Pakistan") %>% select(objectid) %>% st_drop_geometry() %>% unlist() %>% as.vector()

# tmp_df <- regional_summary_ar_weighted(colormap, pol_data_location, pop_raw_landscan_crop_pol, res_resample_to,objectid_vec = pak_objid, start_year, res_resample_from)
0.00833333
tmp_df_pak <- tmp_df

tmp_df_0.008333_ar_weighted <- regional_summary_ar_weighted(colormap, pol_data_location, pop_raw_landscan_crop_pol, 0.00833333,objectid_vec = pak_objid, start_year, res_resample_from)

tmp_df_0.008333_pop_weighted <- regional_summary(colormap, pol_data_location, pop_raw_landscan_crop_pol, 0.00833333, objectid_vec = pak_obj_id, start_year, res_resample_from)


tmp_df_pak_geom <- tmp_df_0.008333 %>% left_join(colormap, by = c("objectid_gadm2" = "objectid"))

tmp_df_pak_geom <- tmp_df_pak_geom %>%
  select(objectid_gadm2:pm2022, geometry) %>%
  st_as_sf()

tmp_df_pak_geom$area <- st_area(tmp_df_pak_geom)

tmp_df_pak_geom <- tmp_df_pak_geom %>%
  mutate(area = round(as.numeric(area/10^6), 2)) %>%
  select(objectid_gadm2:pm2022, area, geometry) %>%
  st_as_sf()

tmp_df_pak_non_geom <-  tmp_df_pak_geom %>%
  st_drop_geometry()

tmp_df_pak_non_geom <- tmp_df_pak_non_geom %>%
  rename(iso_alpha3 = iso_alpha3.x)

tmp_df_pak_non_geom_country_summary <-

  foo <- tmp_df_pak_non_geom %>%
  group_by(country) %>%
  mutate(area_weights = area/sum(area, na.rm = TRUE)) %>%
  dplyr::mutate(across(dplyr::starts_with("pm"), ~(.x*area_weights), .names = "{col}_area_weighted")) %>%
  dplyr::summarise(across(dplyr::contains("area_weighted"), ~(round(sum(.x, na.rm = TRUE), 2)), .names = "avg_{col}"),
                   objectid_gadm2 = objectid_gadm2[1], iso_alpha3 = iso_alpha3[1], whostandard = whostandard[1]) %>%
  dplyr::ungroup() %>%
  select(objectid_gadm2, iso_alpha3, country, whostandard, dplyr::everything())



#> regional summary function with area weighted pollution estimates, instead of population weights (testing)-----------------

regional_summary_ar_weighted <- function(colormap, pol_data_location, pop_raw_raster, resample_to_res, objectid_vec, pol_data_start_year, pop_raster_res){

  # pol data list
  pol_data_list <- list.files(pol_data_location) %>% sort()

  # pollution column names empty vector
  pol_col_name_vec <- c()

  # region years list
  region_years_list <- list()

  # master region years list
  master_region_years_list <- list()

  for(i in 1: length(objectid_vec)){

    # close all connections
    closeAllConnections()

    # rasterizing a subset of the colormap shapefile to a reference resolution using fasterize: test (Gujarat): Works
    region_rasterized_shapefile <- fasterize(colormap %>% filter(objectid == objectid_vec[i]),
                                             raster::raster(ext = raster::extent(colormap %>% filter(objectid == objectid_vec[i])),
                                                            resolution = resample_to_res, crs = crs(colormap)), field = "objectid", fun = "last")
    # set the name of the regional rasterized shapefile
    names(region_rasterized_shapefile) <- "objid"

    for(j in 1:length(pol_data_list)){

      # ui
      print(stringr::str_c("Region number " , i, ": Iteration #", j, "/", (update_year - pol_data_start_year) + 1, " begins"))

      # filling in the name of the current pollution year
      pol_col_name_vec[j] <- str_c("pm", (pol_data_start_year + (j-1)))

      # storing a separate copy of the current pollution year in a separate object, for later use in the rename command
      cur_pol_col_name <- pol_col_name_vec[j]

      # pollution file name given the current iteration
      cur_pol_file_name <- pol_data_list[j]

      # cur pollution file year
      cur_pol_file_year <- stringr::str_extract(str_extract(cur_pol_file_name, "(\\d+)-(\\d+)"), "....")

      # read in the pollution raster for a given year
      pol_raw_raster <- raster::raster(str_c(pol_data_location, cur_pol_file_name, sep = ""))

      # crop raw pollution raster to the extent of the above raster
      pol_raster_cropped <- crop(pol_raw_raster, extent(region_rasterized_shapefile))

      # set crs of the pollution raster
      crs(pol_raster_cropped) <- "+proj=longlat +datum=WGS84 +no_defs"

      # match resolution of pollution raster with the rasterized regionshape file
      pol_raster_cropped_new_res <- raster::resample(pol_raster_cropped, region_rasterized_shapefile, method = "ngb")

      names(pol_raster_cropped_new_res) <- "pol"

      # mask pol_2018_0.01_test_shajrah to the qgis raster
      pol_raster_cropped_new_res_masked <- raster::mask(pol_raster_cropped_new_res, region_rasterized_shapefile)

      # set the name of the pollution raster
      names(pol_raster_cropped_new_res_masked) <- "pol"

      # crop population raw data to region rasterized shapefile
      pop_raster_cropped <- crop(pop_raw_raster, extent(region_rasterized_shapefile))

      crs(pop_raster_cropped) <- "+proj=longlat +datum=WGS84 +no_defs"

      # replacing the population with population densities
      raster::values(pop_raster_cropped) <- as.vector(pop_raster_cropped * (((resample_to_res)^2)/((pop_raster_res)^2)))

      # performing idw on population densities

      #match resolution of the pop_raster_cropped population raster with region_rasterized_shapefile
      pop_raster_cropped_new_res <- raster::resample(pop_raster_cropped, region_rasterized_shapefile, method = "ngb")


      # mask population raw data to sharjah
      pop_raster_cropped_new_res_masked <- raster::mask(pop_raster_cropped_new_res,
                                                        region_rasterized_shapefile)

      # pop_raster_cropped_new_res
      names(pop_raster_cropped_new_res_masked) <- "pop"

      # create a brick
      region_brick <- region_rasterized_shapefile %>%
        addLayer(pol_raster_cropped_new_res_masked) %>%
        addLayer(pop_raster_cropped_new_res_masked)

      # brick df
      region_brick_df <- region_brick %>%
        raster::as.data.frame()

      # convert dataframe into an arrow table
      region_brick_df_arrow <- region_brick_df %>%
        arrow::as_arrow_table()

      # summarizing and finally testing (note that as a result of resampling tiny regions to a high resolution, and then
      # collapsing them at gadm level 2, the population might not be an integer, hence rounding is needed in the population column)
      region_brick_df_arrow_summary <- region_brick_df_arrow %>%
        dplyr::filter((!is.na(objid)) & ((as.character(objid) != "NA"))) %>%
        dplyr::group_by(objid) %>%
        dplyr::collect() %>%
        dplyr::mutate(area_weight = 1/n(),
                      pollution_area_weighted = area_weight*pol) %>%
        dplyr::summarise(avg_pm2.5_pollution = round(sum(pollution_area_weighted, na.rm = TRUE), 2)) %>%
        dplyr::rename(objectid_gadm2 = objid)

      # joining with the colormap to get area names
      region_brick_df_arrow_summary_shp <- region_brick_df_arrow_summary %>%
        left_join(colormap, by = c("objectid_gadm2" = "objectid")) %>%
        mutate(whostandard = who_pm2.5_standard) %>%
        select(objectid_gadm2, iso_alpha3, NAME_0, NAME_1, NAME_2, whostandard, avg_pm2.5_pollution, geometry) %>%
        rename(country = NAME_0, name_1 = NAME_1, name_2 = NAME_2, !!cur_pol_col_name := avg_pm2.5_pollution)


      # remove the geometry column
      region_brick_df_arrow_summary_non_geom <- region_brick_df_arrow_summary_shp %>%
        sf::st_as_sf() %>%
        sf::st_drop_geometry()

      region_years_list[[j]] <- region_brick_df_arrow_summary_non_geom

      if(j == 1){
        master_region_df <- region_years_list[[j]]
      } else {
        master_region_df <- master_region_df %>%
          left_join(region_years_list[[j]], by = c("objectid_gadm2", "iso_alpha3", "country", "name_1", "name_2", "whostandard"))
      }


      print(str_c("j: ", j))

      # close all connections
      closeAllConnections()

    }

    master_region_years_list[[i]] <- master_region_df

    # close all connections
    closeAllConnections()

  }


  final_df_return <- dplyr::bind_rows(master_region_years_list)

  return(final_df_return)

}






