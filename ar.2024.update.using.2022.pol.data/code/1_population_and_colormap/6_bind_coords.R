###############################################

# 6_bind_coords.R

#

# Add lat-long coords as variables to each 

# tile of population points joined to colormap.

# In the next step, we'll convert the point 

# shapefiles along with the coordinates into

# dta files. This will allow us to algebraically

# join population points and pollution points

# in Stata.

#

# Claire 8/2/19

###############################################



library(sf)

library(dplyr)

library(purrr)

pop_year <- 2019



pop_dir <- "C:/Arc/Preserve/data/population/intermediate/pop_points_joined_notjoined/joined/"



start_i = 1

end_i = 25



# Write function that, for each chunk, first checks if the chunk exists - a chunk over the ocean with no population

# would not exist. If exists, the function reads it in, adds coordinates as columns, and then exports the shapefile

# with the coordinate columns.

bind_coords <- function(n) {

	if(file.exists(file.path(pop_dir, pop_year, "/pop_joined_", toString(n), ".shp", fsep=""))){

		chunk <- st_read(file.path(pop_dir, pop_year, "/pop_joined_", toString(n), ".shp", fsep=""), stringsAsFactors = FALSE)

		chunk <- cbind(st_coordinates(chunk), chunk)

		st_write(chunk, file.path(pop_dir, pop_year, "/pop_join_", toString(n), "w_coords.shp", fsep=""), delete_layer = TRUE)

	}

	return(1)

}



map(c(start_i:end_i), bind_coords)



# Do the same for the nearest neighbor-joined points from QGIS. 

chunk <- st_read(file.path(pop_dir, pop_year, "/nnjoined_pop_colormap.shp", fsep=""), stringsAsFactors = FALSE)

# Some points (in 2019 pop data, worth 3.94 million people) were joined to polygons more than 5 decimal degrees away.

# These are all in Fiji, Kiribati, Russia, Alaska, Canada, Greenland, Australia, or French Southern Territories.

# Drop them.

chunk <- chunk %>% filter(distance<=5)

chunk <- chunk %>% 

	select(pop, join_objec) %>% 

	rename(objectid = join_objec) 

chunk <- cbind(st_coordinates(chunk), chunk)

st_write(chunk, file.path(pop_dir, pop_year, "/pop_join_nn_w_coords.shp", fsep=""), delete_layer = TRUE)
