******************************************
* 7_shp_to_dta.do 
*
* Convert each tile of population points
* joined to colormap into dta file, to be
* merged with pollution points.
*
* Runtime: 20min
* Claire 8/2/19
******************************************
*local pop_year = 2019

cd "C:\Arc\Preserve\data\population\intermediate\pop_points_joined_notjoined\joined\2019"

local start_i = 1
local end_i = 25

forvalues n=`start_i'/`end_i' {
	capture confirm file "pop_join_`n'w_coords.shp"
	if _rc==0{
		shp2dta using "pop_join_`n'w_coords.shp", database("pop_join_`n'w_coords") ///
			coordinates("pop_join_`n'w_coords") replace
	}
}

shp2dta using "pop_join_nn_w_coords.shp", database("pop_join_26w_coords") ///
	coordinates("pop_join_26w_coords") replace
