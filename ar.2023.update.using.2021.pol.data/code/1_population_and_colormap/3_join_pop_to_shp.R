####################################################

# 3_join_pop_to_shp.R

#

# Input: TIF tiles of population raster

#

# Description: Converts each raster tile into

# 	points, attempts to join to colormap shapefile

#

# Output: Shapefiles of population points, separated

#	by successfully joined to colormap shp or not.

#

# Runtime: 1-2 hours

####################################################

# benchmarking
code_run_start_time <- Sys.time()

# read in libraries
library(raster)

library(sf)

library(dplyr)

library(purrr)

library(nngeo)

library(stringr)

# turn off s2 processing
sf::sf_use_s2(FALSE)


# set raw population data year
pop_year <- 2021

#
pop_dir <- "C:/Arc/Preserve/data/population"

shp_dir <- "C:/Arc/Preserve/data/shapefiles"


# loop start and end indices (looping over each of 25 population tiles, created in the last script)
start_i <- 1

end_i <- 25


# load in colormap shapefile
colormap <- st_read("ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/1_shapefile_aggregate/colormap/colormap.shp", stringsAsFactors = FALSE) %>%

			dplyr::select(objectid, geometry)

colormap <- colormap %>%
  st_make_valid()

colormap <- colormap[with(colormap, order(objectid)),]

# Iterate over each population raster tile, convert it to a point based shape file and attempt to join that point based shape file to the colormap
# Multipolygon based shape file.
for(i in start_i:end_i){

  # Read in raster tile

  raster_i <- raster(file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/2_read_landscan_raster/split_raster/", "landscan.global.2021",
                               "_tile", i, ".grd", fsep = ""))

  print(i)

  # Convert raster tile to SF object with pop as a field and coords as geometry. Only use cells with pop>0, to save space.

  start_time <- Sys.time()

  print(i)

  points_i <- raster::rasterToPoints(raster_i, fun=function(x){x>0}) %>%

    data.frame() %>%

    sf::st_as_sf(coords = c("x", "y")) %>%
    st_make_valid()

  end_time <- Sys.time()

  names(points_i)[1] <- "pop"

  print("Raster to point:")

  print(end_time - start_time)

  # Stop and move to next tile if no points with pop>0 in this tile

  if (nrow(points_i)==0) {

    next

  }

  # Set Coordinate Reference System of pop points to be same as colormap

  print(i)

  points_i <- sf::st_set_crs(points_i, st_crs(colormap))

  # Join points to colormap shapefile

  print(i)

  start_time <- Sys.time()

  joined <- st_join(points_i, colormap, join = st_intersects, left = TRUE)

  end_time <- Sys.time()

  print("Join to colormap:")

  print(i)

  print(end_time - start_time)

  # Some coastal points contain valuable population info but do not lie directly above a shapefile polygon.

  # Separate into successfully joined and not joined points. Not joined will be put together in one shp

  # and then joined in QGIS, using the "approximate geometries by centroid" option, which is fast.

  not_joined <- joined[is.na(joined$objectid),]

  joined <- joined[!is.na(joined$objectid),]



  # Export as shapefiles

  print(i)

  st_write(joined, file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/3_join_pop_to_shp/joined/",
          "pop_joined", i, ".shp", fsep = ""), delete_layer = TRUE)

  st_write(not_joined, file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/3_join_pop_to_shp/not_joined/",
           "pop_notjoined", i, ".shp", fsep = ""), delete_layer = TRUE)

}


# alternative workflow (instead of using the for loop above, we can use the map function with a r2p_join custom function below). I did not use it
# because I found that it was helpful to see the progress (also easier to debug) using the for loop workflow. But, keeping the below code commented
# in case someone wants to use it.

# Using the "map" function------------------------------------------------------------------------------------

# r2p_join <- function(i){
#
# 	# Read in raster tile
#
# 	raster_i <- raster(file.path(pop_dir, "/intermediate/split_raster/", pop_year, "/lspop", pop_year, "_tile", i, ".grd", fsep = ""))
#
# 	print(i)
#
# 	# Convert raster tile to SF object with pop as a field and coords as geometry. Only use cells with pop>0, to save space.
#
# 	start_time <- Sys.time()
#
# 	print(i)
#
# 	points_i <- raster::rasterToPoints(raster_i, fun=function(x){x>0}) %>%
#
# 				data.frame() %>%
#
# 				sf::st_as_sf(coords = c("x", "y"))
#
# 	end_time <- Sys.time()
#
# 	names(points_i)[1] <- "pop"
#
# 	print("Raster to point:")
#
# 	print(end_time - start_time)
#
# 	# Stop and move to next tile if no points with pop>0 in this tile
#
# 	if (nrow(points_i)==0) {
#
# 		return(NULL)
#
# 	}
#
#
#
# 	# Set Coordinate Reference System of pop points to be same as colormap
#
#
# 	print(i)
#
# 	points_i <- sf::st_set_crs(points_i, st_crs(colormap))
#
# 	# Join points to colormap shapefile
#
# 	print(i)
#
# 	start_time <- Sys.time()
#
# 	joined <- st_join(points_i, colormap, join = st_intersects, left = TRUE)
#
# 	end_time <- Sys.time()
#
# 	print("Join to colormap:")
#
# 	print(i)
#
# 	print(end_time - start_time)
#
# 	# Some coastal points contain valuable population info but do not lie directly above a shapefile polygon.
#
# 	# Separate into successfully joined and not joined points. Not joined will be put together in one shp
#
# 	# and then joined in QGIS, using the "approximate geometries by centroid" option, which is fast.
#
# 	not_joined <- joined[is.na(joined$objectid),]
#
# 	joined <- joined[!is.na(joined$objectid),]
#
#
#
# 	# Export as shapefiles
#
# 	print(i)
#
# 	st_write(joined, file.path(pop_dir, "/intermediate/pop_points_joined_notjoined/joined/", pop_year, "/pop_joined_", i, ".shp", fsep = ""), delete_layer = TRUE)
#
# 	st_write(not_joined, file.path(pop_dir, "/intermediate/pop_points_joined_notjoined/notjoined/", pop_year, "/pop_notjoined_", i, ".shp", fsep = ""), delete_layer = TRUE)
#
# }



# map(c(start_i:end_i), r2p_join)

# Using the "map" function-----------------------------------------------------------------------------------


# print end time and calculate elapsed time

print("3_raster_to_points.R COMPLETED")

code_run_end_time <- Sys.time()

elapsed_time <- code_run_end_time - code_run_start_time

print(str_c("Elapsed Time: ", elapsed_time, sep =" "))
