###############################################

# 4_export_notjoined_pop.R

#

# Description: Joins together chunks of not-

# joined points into a single shapefile,

# to be used in QGIS.

#

# Runtime: 1 minute (locally)

###############################################


# loading libraries
library(sf)
library(dplyr)


# population year
pop_year <- 2021

# loop start and end indices (equal to the total number of tiles in which the population raster was divided initially)
start_i <- 1

end_i <- 25


# setting a variable to distinguish first iteration of the for loop from the rest of the iterations
first_in <- TRUE


# running a for loop through all not joined points shapefiles and combine them into a single "not_joined" master shape file, which will
# then be further processed in QGIS in the next step
for (i in c(start_i:end_i)) {

  # check if file exists
	if(file.exists(file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/3_join_pop_to_shp/not_joined",
	                         "/pop_notjoined", toString(i), ".shp", fsep = ""))){
    print(i)
	  # read in file if it exists
		chunk <- st_read(file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/3_join_pop_to_shp/not_joined",
		                           "/pop_notjoined", toString(i), ".shp", fsep = ""))

		# if its the first file, read it in
		if(first_in){

			altogether <- chunk

			first_in <- FALSE

      # for all files after the first file, append the results to the sf object that was created for the first file
		} else{

			altogether <- rbind(altogether, chunk)

		}

	}

}


# write the combined "not_joined" shapefile to  single shapefile.
st_write(altogether, file.path("./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/4_export_notjoined_pop/not_joined/",
                               "pop_notjoined_all.shp"), delete_layer = TRUE)

# next step: join these unjoined shapefile in QGIS.
