***********************************************************
* 4_lifeyears_collapse.do 
*
* Calculates lifeyears lost associated with each population
* point relative to WHO guideline and national standards,
* then collapses data to get pollution and lifeyears lost 
* aggregated to each administrative level.
*
* Note: the "precollapse" dataset is 28GB, so be sure to 
* request enough memory when running this code on server.
***********************************************************
local update_year = 2020

global ROOT "C:\Arc"

local INTERMED		  "C:\Arc\Preserve\intermed"
local OUTPUT		  "C:\Arc\Preserve\output"
local STANDARDS 	  "C:\Arc\Preserve\data\standards"
local CROSSWALKS	  "C:\Arc\Preserve\data\shapefiles\crosswalks"

*********************************************************
* 1. Prepare crosswalks
*********************************************************
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

*********************************************************
* 2. Calculate lifeyears lost
*********************************************************
use "`INTERMED'/combined", clear

* Merge in national PM2.5 standards 
* We allow unmatched observations from using because small island nations didn't get matched
* to population points
merge m:1 objectid using "`STANDARDS'/colormap_country_standards", assert(2 3) keep(3) nogen
destring pm25standard, force replace

* Calculate lifeyears lost
forvalues y = 1998/2020 {
	
	gen llpp_who5_`y' = (pm`y'-5)*.098 if pm`y' > 5
	replace llpp_who5_`y' = 0 if pm`y' <= 5

	gen llpp_country_`y' = (pm`y'-pm25standard)*.098 if pm`y' > pm25standard
	replace llpp_country_`y' = 0 if pm`y' <= pm25standard
}

* Merge in names of regions
rename objectid objectid_color
merge m:1 objectid_color using "`CROSSWALKS'/color_names", assert(2 3) keep(3) nogen

save "`INTERMED'/precollapse", replace

*********************************************************
* 3. Collapse to administrative regions, add region names
*********************************************************
/* Note: We have to keep re-loading the pre-collapse dataset instead
of using preserve .. restore because the dataset in memory is so huge that using
preserve causes the code to crash on the server. */

* Collapse to colormap level
collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 NAME_2 iso_alpha3 (rawsum) pop [aweight = pop], by(objectid_color) fast
save "`OUTPUT'/lifeyears_color.dta", replace

* Collapse to hover region level
use "`INTERMED'/precollapse", clear
merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
collapse (mean) pm* llpp* (rawsum) pop [aweight = pop], by(objectid_hover) fast
* Merge in hover region names, which leave admin1 and/or admin2 names blank where appropriate
merge 1:1 objectid_hover using "`CROSSWALKS'/hover_names", assert(2 3) keep(3) nogen
save "`OUTPUT'/lifeyears_hover.dta", replace

* Collapse to state/province level for US, China, India
use "`INTERMED'/precollapse", clear
keep if iso_alpha3 == "CHN"
merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
merge m:1 objectid_hover using "`china_cw'", assert(3) nogen
collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
save "`OUTPUT'/lifeyears_state_china.dta", replace

use "`INTERMED'/precollapse", clear
keep if iso_alpha3 == "IND"
merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
merge m:1 objectid_hover using "`india_cw'", assert(2 3)
count if _merge==2
*assert `r(N)' == 1 //Lakshadweep. No pollution data for these islands.
drop if _merge == 2
drop _merge
collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
save "`OUTPUT'/lifeyears_state_india.dta", replace

use "`INTERMED'/precollapse", clear
keep if iso_alpha3 == "USA"
merge m:1 objectid_color using "`color_hover_cw'", assert(2 3) keep(3) nogen
merge m:1 objectid_hover using "`usa_cw'"
count if _merge==2
*assert `r(N)' == 1 //Nantucket, MA. No pollution data for this island.
drop if _merge == 2
drop _merge
collapse (mean) pm* llpp* (firstnm) NAME_0 NAME_1 (rawsum) pop [aweight = pop], by(objectid_state) fast
save "`OUTPUT'/lifeyears_state_usa.dta", replace

* Collapse to national level
use "`INTERMED'/precollapse", clear
collapse (mean) pm* llpp* (firstnm) NAME_0 (rawsum) pop [aweight = pop], by(iso_alpha3) fast
save "`OUTPUT'/lifeyears_country.dta", replace

* Clean up by removing to-collapse dataset to save space
rm "`INTERMED'/precollapse.dta"
