###########################################

# 1_pm_data_readin_combine.py

#

# Raw pollution data are in netcdf format.

# Read in netcdf files and create single

# CSV dataset containing PM across all years

# at all grid points for which data exists

# (i.e. non-ocean).

###########################################

import xarray as xr



startyear = 1998

endyear = 2020



dir = "C:/Arc/Preserve/data/pollution/0.1x0.1/"



# Read in first year's data

pm_raw = xr.open_dataset(dir + "V5GL02.HybridPM25-NoDust-NoSeaSaltc_0p10.Global."+str(startyear)+".nc")

# Convert raster to dataframe

pm_df = pm_raw.to_dataframe()

# Data has NAs over ocean. Drop these.

pm_df = pm_df.dropna()

# Rename the PM column to be year-specific, so can be merged with other years' data

colname = "pm" + str(startyear)

pm_df = pm_df.rename(columns = {"GWRPM25":colname})



# Do the same thing with other years and merge all years together

for year in range(startyear+1,endyear+1):
    
	raw = xr.open_dataset(dir + "V5GL02.HybridPM25-NoDust-NoSeaSaltc_0p10.Global."+str(year)+".nc")

	df = raw.to_dataframe()
	
	df = df.dropna()

	colname = "pm" + str(year)

	df = df.rename(columns = {"GWRPM25":colname})

	pm_df = pm_df.merge(df, on = ['lat', 'lon'], how = 'outer')
    
    



# Save as CSV to be read in by Stata

pm_df.to_csv(dir + "pm_allyears.csv")