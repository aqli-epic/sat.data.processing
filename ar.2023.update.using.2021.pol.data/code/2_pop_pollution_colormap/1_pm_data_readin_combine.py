###########################################

# 1_pm_data_readin_combine.py

#

# Raw pollution data are in netcdf format.

# Read in netcdf files and create single

# CSV dataset containing PM across all years

# at all grid points for which data exists

# (i.e. non-ocean).

###########################################


# install packages using the "conda/pip" command, for e.g. conda install xarray


import xarray as xr
import pandas as pandas


# As of October 20, 2022, this is equal to 1998. But double check every year before running the code.
startyear = 1998

# Update to the latest data for which data is available.
endyear = 2021

# home dir (set this to be the root of your folder)

home_dir = "C:/Users/Aarsh/Desktop/aqli-epic/sat.data.processing/"

# set the dir variable to the directory path where the raw netCDF files (at the given resolution of choice) are stored.
data_dir = home_dir + "data/input/pollution/0.1x0.1/"

# Read in first year's data. The code will be adjusted every year based on that year's file naming system. 
# Please observe the file naming system and accordingly modify the path below.

pm_raw = xr.open_dataset(data_dir + "V5GL03.HybridPM25-NoDust-NoSeaSaltc_0p10.Global."+str(startyear)+ "01-" + str(startyear) + "12" + ".nc")

# Convert raster to dataframe

pm_df = pm_raw.to_dataframe()

# Data has NAs over ocean. Drop these.

# The data as of now (before entering the loop) has the following dimensions: (1383167, 1).
# Once we enter the loop, one additional column (for each additional year) gets added to the dataset with every iteration, 
# until the final iteration, where the dimension of the dataset = (1383167, 24). 24 means 24 years
# worth of data from 1998 to 2021. "lat" and "lon" function sort of like columns, but they are not
# taken into account by Python, while counting the total number of columns in the dataset.

pm_df = pm_df.dropna()

# Rename the PM column to be year-specific, so can be merged with other years' data

colname = "pm" + str(startyear)

# Every year the columns are prefixed with a certain string (this year its "GWRPM25"). 
# Every year its different, please double check and update if necessary. 
pm_df = pm_df.rename(columns = {"GWRPM25":colname})

# Sanity check, pm_df dimension (1383167, 24), where 24 refers to the 24 years columns and then there are two other "sort of" columns, 
# but they are not counted as columns (lat, lon)
print("Dataset dimension for start year ", "(", startyear, "): ", pm_df.shape)

#> Do the same thing with other years and merge all years together

# We do "endyear + 1" because the for loop stops at "upper limit - 1".
for year in range(startyear+1,endyear+1):
    
    # read raw netCDF file data
	raw = xr.open_dataset(data_dir + "V5GL03.HybridPM25-NoDust-NoSeaSaltc_0p10.Global."+str(year)+ "01-" + str(year) + "12" + ".nc")
    
    # convert raster to dataframe    
	df = raw.to_dataframe()
	
    # drop NAs, one possible reason: data has NAs over the Ocean. Drop these.
	df = df.dropna()
    
    # rename the columns such that they contain the "year" in their name
	colname = "pm" + str(year)

    # rename columns from default prefix of "GWRPM25" to year wise names.
	df = df.rename(columns = {"GWRPM25":colname})

    # merge the dataset corresponding to "year", with the dataset from the previous iteration
	pm_df = pm_df.merge(df, on = ['lat', 'lon'], how = 'outer')
    
# Save as CSV to be read in by Stata (the output file contains the following columns: "lat", "lon", and 
# one column each for pmXXXX, where XXXX is a year from 1998 to 2021).

pm_df.to_csv(home_dir + "data/intermediate/2_pop_pollution_colormap/1_pm_data_readin_combine/pm_allyears.csv")