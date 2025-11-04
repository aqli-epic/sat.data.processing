***********************************************************
* 4_userdefined.do 
*
* Calculates lifeyears lost associated with each population
* point based on each possible user-selected percent
* reduction in PM2.5, then collapses data to get pollution 
* and lifeyears lost aggregated to each administrative level.
* E.g. 10 percent means life expectancy gained if reduced
* PM2.5 by 10%.
*
* Note: the "pre_collapse" dataset is 23GB, so be sure to 
* request enough memory when running this code on server.
***********************************************************

local update_year = 2020
local percents 10 20 30 40 50  60 70 80 90 100

* Directories
global ROOT "C:\Arc"
local INTERMED		  "C:\Arc\Preserve\intermed"
local OUTPUT		  "C:\Arc\Preserve\output"
local CROSSWALKS	  "C:\Arc\Preserve\data\shapefiles\crosswalks"

set varabbrev off
set more off

* SWITCHES
local sw_color 		= 1 //set to 1 to create colormap datasets
local sw_hover		= 1 //set to 1 to create hover datasets
local sw_country	= 1 //set to 1 to create country-level datasets
local sw_states		= 1 //set to 1 to create state-level datasets for US, China, India

* Load final dataset created in 5a
use "`INTERMED'/combined", clear

foreach percent in `percents' {
	display(`percent')
	
	********************************************************
	* Calculate lifeyears lost
	********************************************************
	use "`INTERMED'/combined", clear

	forvalues y = 1998/2020 {
		gen llpp_user_`y' = pm`y'*(`percent'/100)* 0.098
	}
	
	rename objectid objectid_color
	merge m:1 objectid_color using "`CROSSWALKS'/color_names", assert(2 3) keep(3) nogen
	save "`INTERMED'/pre_collapse_user_`percent'", replace

	********************************************************
	* Collapse to administrative regions, add region names
	********************************************************
	
	if `sw_color' == 1 {
		* Collapse to colormap level
		collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 NAME_2 iso_alpha3 (rawsum) pop [aweight = pop], by(objectid_color) fast
		save "`OUTPUT'/userdefined/lifeyears_color_`percent'percent", replace
	}
	
	if `sw_hover' == 1 {
		* Collapse to objectid1 level
		import delimited "`CROSSWALKS'/gadm_hover_color_crosswalk.txt", clear
		tempfile color_hover_cw
		save `"`color_hover_cw'"'

		use "`INTERMED'/pre_collapse_user_`percent'", clear
		merge m:1 objectid_color using "`color_hover_cw'", assert(1 2 3) keep(3) nogen
		collapse (mean) pm* llpp* (rawsum) pop [aweight = pop], by(objectid_hover) fast
		merge 1:1 objectid_hover using "`CROSSWALKS'/hover_names", assert(2 3) keep(3) nogen
		save "`OUTPUT'/userdefined/lifeyears_hover_`percent'percent", replace
	}
	
	if `sw_country' == 1 {
		* Collapse to country level
		use "`INTERMED'/pre_collapse_user_`percent'", clear
		egen countryid = group(iso_alpha3) // it's faster to collapse by a numerical variable
		collapse (mean) pm* llpp* (firstnm) iso_alpha3 NAME_0 (rawsum) pop [aweight = pop], by(countryid) fast
		drop countryid
		save "`OUTPUT'/userdefined/lifeyears_country_`percent'percent", replace
	
	}

	if `sw_states' == 1 {
		* Collapse to state level for US, China, India
		import delimited "`CROSSWALKS'/gadm_hover_color_crosswalk.txt", clear
		tempfile color_hover_cw
		save `"`color_hover_cw'"'

		import delimited "`CROSSWALKS'/China_state_hover_crosswalk.txt", clear
		tempfile china_cw
		save `"`china_cw'"'

		import delimited "`CROSSWALKS'/India_state_hover_crosswalk.txt", clear
		tempfile india_cw
		save `"`india_cw'"'

		import delimited "`CROSSWALKS'/USA_state_hover_crosswalk.txt", clear
		tempfile usa_cw
		save `"`usa_cw'"'

		use "`INTERMED'/pre_collapse_user_`percent'", clear
		keep if iso_alpha3 == "CHN"
		merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
		merge m:1 objectid_hover using "`china_cw'", assert(3) nogen
		collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
		save "`OUTPUT'/userdefined/lifeyears_state_china_`percent'percent.dta", replace

		use "`INTERMED'/pre_collapse_user_`percent'", clear
		keep if iso_alpha3 == "IND"
		merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
		merge m:1 objectid_hover using "`india_cw'", assert(2 3)
		count if _merge==2
		*assert `r(N)' == 1 //Lakshadweep
		drop if _merge == 2
		drop _merge
		collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
		save "`OUTPUT'/userdefined/lifeyears_state_india_`percent'percent.dta", replace

		use "`INTERMED'/pre_collapse_user_`percent'", clear
		keep if iso_alpha3 == "USA"
		merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
		merge m:1 objectid_hover using "`usa_cw'"
		count if _merge==2
		*assert `r(N)' == 1 //Nantucket, MA
		drop if _merge == 2
		drop _merge
		collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
		save "`OUTPUT'/userdefined/lifeyears_state_usa_`percent'percent.dta", replace
	}

	* Clean up by removing to-collapse dataset to save space
	rm "`INTERMED'/pre_collapse_user_`percent'.dta"
}
