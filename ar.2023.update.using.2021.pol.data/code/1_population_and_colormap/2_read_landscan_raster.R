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



pop_year <- 2019



ddir <- "C:/Arc/Preserve/data/population"                          #run on Acropolis



landscan <- raster::raster(file.path(ddir, "/raw/landscan", pop_year, "/lspop", pop_year, fsep = ""))



# Will split raster in parallel, using 4 cores or however many are available

# cl <- pmin(parallel::detectCores(), 4)
# 
# beginCluster(cl)

# (Aarsh) I am not using the parallel cores option. I think it was messing with the splitting.

tiles <- splitRaster(landscan, nx = 5, ny = 5, path = file.path(ddir, "intermediate/split_raster", pop_year))

# endCluster()



print("2_read_landscan_raster.R COMPLETED")

end_time <- Sys.time()

elapsed_time <- end_time - start_time

print(str_c("Elapsed Time: ", elapsed_time))


