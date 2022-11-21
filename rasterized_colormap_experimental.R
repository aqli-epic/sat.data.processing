# Join Rasters.R - Experimenting with a new AQLI backend workflow----------------

# load libraries
library(raster)
library(rgdal)
library(dplyr)
library(ncdf4)
library(assertthat)
library(fasterize)
library(sf)
library(SpaDES)

# load population and population rasters of the same resolution (0.008333 x 0.008333) and extent (prepared in QGIS) for LA

pol_0.0083_la_2021 <- raster::raster("./qgis_experimentation/pol_0.0083_la_qgis.tif")
pop_0.0083_la_2021 <- raster("./qgis_experimentation/landscan_0.0083_la_raw.tif")

pop_weighted_pol_0.0083_2021 <- pol_0.0083_la_2021 * (pop_0.0083_la_2021/sum(values(pop_0.0083_la_2021), na.rm = TRUE))

pop_weighted_pol_0.0083_2021 %>% raster::writeRaster("./qgis_experimentation/pop_weighted_pol_0.0083_2021.tif")


pol_0.0083_la_2021_subtract_from_5 <- pol_0.0083_la_2021 - 5
pol_0.0083_la_2021_abs_val_post_subtraction <- overlay(pol_0.008_la_2021, pol_0.0083_la_2021_subtract_from_5,
                                                       fun = function(l1, l2){return(ifelse(l2 < 0, 0, l2))})


pol_0.0083_la_2021 <- foster::matchResolution(pol_0.0083_la_2021, pop_0.0083_la_2021)

writeRaster(pol_0.0083_la_2021, "./qgis_experimentation/pol_0.0083_la_qgis_resamp.tif")






### PREPARE POLLUTION RASTERS
# Read in pollution netcdf files for 2021 only
pol_0.01 <- raster("./ar.2023.update.using.2021.pol.data/data/input/pollution/0.01x0.01/foo.nc")
pol_0.083 <- raster("./qgis_experimentation/pol_la_0.083.tif")
foo <- foster::matchResolution(c(pol_0.01, pop_0.083))

crs(pol_0.01) <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"
names(pol_0.01) <- "pm2021"

# If pollution rasters have x and y switched, then transpose them
if(bbox(pol_0.01)[2,1]< -90 | bbox(pol_0.01)[2,2]>90){
  pol_0.01 <- pol_0.01 %>% flip(direction = 'x') %>% t() %>% flip(direction = 'x')
}
assert_that(bbox(pol_0.01)[1,1]< -175 & bbox(pol_0.01)[1,2]>175 & bbox(pol_0.01)[2,1]<bbox(pol_0.01)[2,2])

# reading in population raster
landscan <- raster("C:/Users/Aarsh/Desktop/aqli-epic/sat.data.processing/ar.2023.update.using.2021.pol.data/data/input/population/landscan-global-2021.tif")

# Read in colormap polygons
colormap <- st_read("C:/Users/Aarsh/Desktop/aqli-epic/sat.data.processing/ar.2023.update.using.2021.pol.data/data/intermediate/1_population_and_colormap/1_shapefile_aggregate/colormap.shp", stringsAsFactors = FALSE)



 #> crop pollution data to LA

 # filtering for LA
 colormap_la <- colormap %>%
   filter(NAME_2 %in% "Los Angeles")

 # cropping pollution 0.01 data to the extent of LA
 pol_0.01_la <- raster::crop(pol_0.01, colormap_la)

 # cropping landscan 0.008333 res data to the extent of LA
 landscan_0.0083_la <- raster::crop(landscan, colormap_la)

 # write 0.01 res pol la raw data
 writeRaster(pol_0.01_la, "./qgis_experimentation/pol_0.01_la_raw.tif")

# write landscan 0.0083 res data to the extent of la
 writeRaster(landscan_0.0083_la, "./qgis_experimentation/landscan_0.0083_la_raw.tif")

# convert pollution raster to the resolution of the population raster
landscan_cropped <- landscan %>% crop(extent(pol_0.01))
factor <- dim(landscan_cropped)[1:2]/dim(pol_0.01)[1:2]
assert_that(identical(factor, round(factor))) # and in particular, both should be 6 (for 0.05x0.05 resolution pollution data, as resolution changes, this number will change proportionally, I guess?)
# Next, disaggregate and save result to file so as not to have to run the time-consuming disaggregation
# step again if process crashes before finishing for any reason
print("Beginning to disaggregate pollution rasters")
pol_0.01_disagg <- raster::disaggregate(pol_0.01, fact = factor)


### MATCH POPULATION TO POLLUTION

# cropping landscan data to LA
landscan_la <- raster::crop(landscan, colormap_la)

# setting the 4th element of landscan extent to be the same as the extent of pol_0.01_la
extent(landscan_la)[4] <- 34.82

# setting the "y" coordinate of the resolution for landscan_la to be the same as landscan (its superset)
res(landscan_la)[2] <- 0.008333333

#--------------------------------------
# # Confirm orientation of landscan raster. Remember x = longitude, y = latitude
# assert_that(min(bbox(landscan) == matrix(c(-180,-90,180,90),nrow=2,ncol=2)) == 1)

# # Pollution rasters don't cover north of 70N or south of 60S latitude. Crop
# # landscan raster to match.
# landscan_cropped <- landscan %>% crop(extent(pol_0.01))
#-------------------------------------


# Convert pollution raster brick into resolution of population raster.
# For pollution data at 0.01x0.01 degree resolution and LandScan data at 30"x30" resolution,
# resolution of latter is integer multiple of former, so can disaggregate without worrying about bilinear
# interpolation.
# First, make sure resolution of pollution data is integer multiple of resolution of LandScan data

factor <- dim(landscan_la)[1:2]/dim(pol_0.01_la)[1:2]
assert_that(identical(factor, round(factor))) # and in particular, both should be 6 (for 0.05x0.05 resolution pollution data, as resolution changes, this number will change proportionally, I guess?)
# Next, disaggregate and save result to file so as not to have to run the time-consuming disaggregation
# step again if process crashes before finishing for any reason
print("Beginning to disaggregate pollution rasters")
pol_0.01_la_disagg <- raster::disaggregate(pol_0.01_la, fact = factor)

# Now can add population layer to brick, hence matching each population point to a pollution value
values(landscan_cropped)[values(landscan_cropped)==0] <- NA
names(landscan_cropped) <- "population"
brick <- brick %>% addLayer(landscan_cropped)

### MATCH TO COLORMAP POLYGONS

# Now match each population/pollution point to a colormap polygon. To do this, convert
# polygons to raster of same resolution as population raster, with value of each cell equal
# to objectid of polygon that covers its center.
# Fasterize is an ultra-fast version of the rasterize function.
print("Beginning to rasterize shapefile")
polygon_cells <- fasterize(colormap, landscan_cropped, field = "objectid", fun = "last")
writeRaster(polygon_cells,
            filename=file.path(out_dir, "/", update_year, "update/color_rasterized.tif", fsep = ""),
            format = "GTiff", overwrite = TRUE)
brick <- brick %>% addLayer(polygon_cells)

### EXPORT RASTER STACK
raster::writeRaster(brick, filename = file.path("C:/Users/Aarsh/Desktop/aqli-epic", "sat.data.processing/all_layers.tif",
                                                fsep = ""), format = "GTiff", overwrite = TRUE)

# SANITY CHECK export a piece of the brick
tile <- brick %>% crop(extent(105, 120, 15, 30))
writeRaster(tile,
            filename = file.path(out_dir, "/", update_year, "update/brick_tile.tif", fsep = ""),
            format="GTiff", overwrite = TRUE)

endCluster()
