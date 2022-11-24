###############################################

# 2_read_landscan_raster.R

#

# The raw LandScan data is a raster dataset.

# Read it in, divide into 25 tiles and export

# each as TIF file.

#

# Runtime: 2 minutes

###############################################

start_time <- Sys.time()

library(raster)

library(SpaDES)

library(parallel)

library(stringr)



pop_year <- 2021

# reading in landscan population raster for the pop_year
landscan <- raster::raster( "./ar.2023.update.using.2021.pol.data/data/input/population/landscan-global-2021.tif")



# Will split raster in parallel, using 4 cores or however many are available

# cl <- pmin(parallel::detectCores(), 4)
#
# beginCluster(cl)

# (Aarsh) I am not using the parallel cores option. I think it was messing with the splitting.

tiles <- splitRaster(landscan, nx = 5, ny = 5, path = "./ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/2_read_landscan_raster/split_raster")


print("2_read_landscan_raster.R COMPLETED")

end_time <- Sys.time()

elapsed_time <- end_time - start_time

print(str_c("Elapsed Time: ", elapsed_time)) # 2.33 minutes


