###############################################

# 4_export_notjoined_pop.R

#

# Description: Joins together chunks of not-

# joined points into a single shapefile,

# to be used in QGIS.

#

# Runtime: 1 minute

###############################################



library(sf)

library(dplyr)



pop_year <- 2019



pop_dir <- "C:/Arc/Preserve/data/population/intermediate/pop_points_joined_notjoined/notjoined"   



start_i <- 1

end_i <- 25



first_in <- TRUE



for (i in c(start_i:end_i)) {	

	if(file.exists(file.path(pop_dir, "/", pop_year, "/pop_notjoined_", toString(i), ".shp", fsep = ""))){

		chunk <- st_read(file.path(pop_dir, "/", pop_year, "/pop_notjoined_", toString(i), ".shp", fsep = ""))

		if(first_in){

			altogether <- chunk

			first_in <- FALSE

		} else{

			altogether <- rbind(altogether, chunk)

		}

	}

}



st_write(altogether, file.path(pop_dir, "/", pop_year, "pop_notjoined_all.shp"), delete_layer = TRUE)