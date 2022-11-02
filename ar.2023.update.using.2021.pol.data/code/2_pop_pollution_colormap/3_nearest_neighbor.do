/*
3_nearest_neighbor.do

Find nearest-neighbor match for all points that weren't matched using
the simple algebraic method, and then combine NN-matched points with
algebraically matched points from last step.

*/

local update_year = 2020

* Directories
global ROOT "C:\Arc"

local INTERMED		  "C:\Arc\Preserve\intermed"
local OUTPUT		  "C:\Arc\Preserve\output"

* Switches
local sw_build  = 1
local sw_append = 1

* Required programs
cap ssc install geonear

********************************************************************************

if `sw_build' == 1 {

	use "`INTERMED'/nomerges", clear

	* Keep only necessary variables
	drop pm* nomerge *lat *lon pollution_id 

	* Create base ID and save pre-match tempfile
	gen long match_id = _n
	tempfile pre_match
	save "`pre_match'", replace

	* Geonear match
	geonear match_id Y X using "`INTERMED'/pollution_loaded", ///
	 neighbors(pollution_id lat lon) long nearcount(1)

	* Merge back to pre-match tempfile
	merge 1:1 match_id using "`pre_match'", assert(match) nogen

	* Merge to pollution dataset based on distance matches
	merge m:1 pollution_id using "`INTERMED'/pollution_loaded", assert(match using) keep(match) nogen

	* Keep only necessary variables and do some renaming
	drop match_id pollution_id
	rename km_to_pollution_id dist

	* Drop invalid matches (which we define as being more than 20km away)
	drop if dist > 20
	drop dist

	* Save nearest-neighbor-matched points
	save "`INTERMED'/nn_match", replace 

}

if `sw_append' == 1{
	*********************************************************
	* Pre-process nearest-neighbor-matched gridpoints
	*********************************************************
	use "`INTERMED'/nn_match", clear
	append using "`INTERMED'/merged"
	drop nomerge

	* Pop points falling on border between two (or three) polygons got matched to both. Evenly 
	* split the population between the two polygons.
	duplicates tag X Y, generate(num_copies)
	replace pop = pop/(num_copies+1)
	drop num_copies

	*********************************************************
	* Create unique id variable
	*********************************************************
	gen double unid = _n
	isid unid

	format unid %12.0g //necessary for outsheet formatting

	* Failsafe ID variable
	gen long unid_m = 1 if _n == 1
	replace unid_m = unid_m[_n-1] + 1 if _n > 1
	isid unid_m

	* Sanity check to make sure all points have been matched to polygon shapefile
	assert !missing(objectid) & objectid != 0

	* Sanity check to make sure all points have nonmissing population
	assert pop != .

	save "`INTERMED'/combined", replace
}

