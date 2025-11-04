/*
2_pop_pollution_match.do

Algebraically match each population point to the nearest
pollution point. Not all population points get matched,
e.g. because the point on the 0.01x0.01 degree pollution data
grid nearest to the population point is over ocean. Combine
all merged points and all non-merged points from the different
chunks of population points. Non-merged points will be merged
via nearest neighbor join in the next step.

*/

* Directories

local pop_year = 2019
local update_year = 2020

global ROOT "C:\Arc"
local DATA_POLLUTION    "C:\Arc\Preserve\data\pollution\0.1x0.1"
local DATA_POPULATION   "C:\Arc\Preserve\data\population\intermediate\pop_points_joined_notjoined\joined\2019"
local INTERMED		    "C:\Arc\Preserve\intermed"
local OUTPUT		    "C:\Arc\Preserve\output"

********************************************************************************

local sw_build  = 1
local sw_append = 1


if `sw_build' == 1 {
	********************************
	* Load and format pollution data
	********************************
	import delimited "`DATA_POLLUTION'/pm_allyears.csv", clear

	* Create merge variables due to Stata rounding issues
	foreach var of varlist lat lon {
		gen temp_`var' = `var' * 1000 //remove the decimal place
		replace temp_`var' = round(temp_`var', 1)
		gen m_`var' = strofreal(temp_`var')
		drop temp_`var'
	}

	* Create unique identifier for pollution data
	gen long pollution_id = _n //_n gets observation number

	* Save pollution data
	save "`INTERMED'/pollution_loaded", replace

	************************************
	* Merge population to pollution data
	************************************

	foreach n of num 1/26 {
		capture confirm file "`DATA_POPULATION'/pop_join_`n'w_coords.dta"
		if _rc==0{
			use "`DATA_POPULATION'/pop_join_`n'w_coords.dta", clear
			drop _ID
		  * matching population points to pollution points. These formulas are for pollution data
		  * at 0.1x0.1 degree resolution, at coordinates ending in .05, .15, .25, .35, ...
		  // (point_x, point_y) = (long, lat) of population point
		  // (longitude, latitude) = (long, lat) of pollution point to be merged to
			gen lat  = round(Y - .05, .1) + .05
			gen lon = round(X - .05, .1) + .05
			
			* Create merge variables due to Stata rounding issues
			foreach var of varlist lat lon {
				gen temp_`var' = `var' * 1000 //remove the decimal place
				replace temp_`var' = round(temp_`var', 1)
				gen m_`var' = strofreal(temp_`var')
				drop temp_`var'
			}

			merge m:1 m_lat m_lon using "`INTERMED'/pollution_loaded", keep(match master) 
			gen nomerge = 1 if _merge == 1
			drop _merge

			* Save merged
			save "`INTERMED'/merged_`n'", replace
		} 
	}
}


if `sw_append' == 1 {
	************************************
	* Save merged and no-merge datasets
	************************************

	local save_switch = 0 //do not change
	tempfile nomerges
	tempfile merged

	* Create a CSV of just the lat/longs of unmatched population points
	foreach n of num 1/26 {
		capture confirm file "`INTERMED'/merged_`n'.dta"
		if _rc==0{
			use "`INTERMED'/merged_`n'.dta", clear
			keep if nomerge == 1
				
			if `save_switch' == 1 {
				append using "`nomerges'"
			}
			save `"`nomerges'"', replace
			
			local save_switch = 1
		}
	}

	* Save dataset of non-merged population points
	use "`nomerges'", clear
	save "`INTERMED'/nomerges", replace 
	outsheet using "`OUTPUT'/nomerges.csv", replace

	local save_switch = 0

	* Append all of the successfully matched points
	foreach n of num 1/26{

		capture confirm file "`INTERMED'/merged_`n'.dta"
		if _rc==0{
			use "`INTERMED'/merged_`n'.dta", clear
		
			keep if nomerge != 1
			
			if `save_switch' == 1 {
				append using "`merged'"
			}
			
			save "`merged'", replace
			
			local save_switch = 1
		}
	}

	use "`merged'", clear
	save "`INTERMED'/merged", replace

}

