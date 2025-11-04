/*
Generate AQLI datasets that accord to India's stance on Kashmir.
I.e. Move Azad Kashmir from Pakistan to Jammu and Kashmir, 
Gilgit-Baltistan to Leh district of Ladakh UT. Rename Azad Kashmir
hover region as "Pakistan-Occupied Kashmir" (the Survey of India
breaks it down into districts, so we're not quite matching it).

For website, generate datasets that only contain the affected regions.
For the press, generate datasets of all countries, all Indian states,
and all Indian hover regions that include the adjusted regions.

Claire Fan
Feb 2 2020
*/
local startyear = 1998
local endyear = 2020
local percents 10 20 30 40 50 60 70 80 90 100

cd "C:\Arc"

/*** I. Hover: Change names of Azad Kashmir, Gilgit-Baltistan ***/

/** a. Pollution, WHO, national standard **/

*start with unrounded PM and lifeyears numbers
*clean data as in 6_final_clean.do, but without rounding
use "POV\lifeyears_hover", clear
rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)

* Standards
gen whostandard = 5
rename pm25standard natstandard
replace natstandard = 0 if missing(natstandard) //per Constructive's request

rename llpp_country* llpp_nat*
rename pop population
format population %11.0f
order objectid_hover iso_alpha3 country name_1 name_2 population whostandard natstandard pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 pm2020 llpp_who5_19* llpp_who5_200* llpp_who5_2010 llpp_who5_2011 llpp_who5_2012 llpp_who5_2013 llpp_who5_2014 llpp_who5_2015 llpp_who5_2016 llpp_who5_2017 llpp_who5_2018 llpp_who5_2019 llpp_who5_2020 llpp_nat_19* llpp_nat_200* llpp_nat_2010 llpp_nat_2011 llpp_nat_2012 llpp_nat_2013 llpp_nat_2014 llpp_nat_2015 llpp_nat_2016 llpp_nat_2017 llpp_nat_2018 llpp_nat_2019

tempfile hover_original_noround
save `"`hover_original_noround'"'

*transfer Azad Kashmir to Jammu and Kashmir, Gilgit-Baltistan to Leh district of Ladakh
keep if inlist(country, "India", "Pakistan")
replace country = "India" if inlist(name_1, "Azad Kashmir", "Gilgit-Baltistan")
replace name_2 = "Pakistan-Occupied Kashmir" if name_1 == "Azad Kashmir" 
replace name_1 = "Jammu and Kashmir" if name_1 == "Azad Kashmir"
gen leh = 1 if name_1 == "Ladakh" & name_2 == "Leh (Ladakh)"
replace leh = 0 if missing(leh)
gsort -leh
local leh_id = objectid_hover[1]
drop leh
replace name_2 = "Leh (Ladakh)" if name_1 == "Gilgit-Baltistan" 
replace objectid_hover = `leh_id' if name_1 == "Gilgit-Baltistan" 
replace name_1 = "Ladakh" if name_2 == "Leh (Ladakh)"
replace natstandard = 40 if country == "India"
replace iso_alpha3 = "IND" if country == "India"

collapse (rawsum) population (mean) whostandard natstandard pm* llpp* [aweight = population], by(objectid_hover iso_alpha3 country name_1 name_2)

tempfile hover_updated_noround
save `"`hover_updated_noround'"'

keep if country == "India"
sort name_1 name_2 

forvalues y = `startyear'/`endyear'{
	replace pm`y' = round(pm`y', 0.01)
	format pm`y' %9.2f

	replace llpp_who5_`y' = round(llpp_who5_`y', 0.01)
	format llpp_who5_`y' %9.2f

	replace llpp_nat_`y' = round(llpp_nat_`y', 0.01)
	replace llpp_nat_`y' = . if natstandard == 0
	format llpp_nat_`y' %9.2f
}
replace population = round(population, 1)

preserve
keep if inlist(name_2, "Pakistan-Occupied Kashmir", "Leh (Ladakh)")
export delimited "political_sensitivity\IndiaPC\hover\PoKLeh_hover.csv", replace
restore

drop objectid_hover
* export CSV of all hover regions in India, for press inquiries
export delimited "political_sensitivity\IndiaPC\hover\India_hover.csv", replace


/** b. User-selected percent reductions, changes only **/
foreach pc in `percents'{
	*start with unrounded PM and lifeyears numbers
	*clean data as in 6_final_clean.do, but without rounding
	use "POV\userdefined\lifeyears_hover_`pc'percent", clear
	rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)
	rename pop population
	gen user_defined = `pc'
	format population %11.0f 
	order objectid_hover iso_alpha3 country name_1 name_2 population user_defined pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 pm2020 llpp_user_19* llpp_user_200* llpp_user_2010 llpp_user_2011 llpp_user_2012 llpp_user_2013 llpp_user_2014 llpp_user_2015 llpp_user_2016 llpp_user_2017 llpp_user_2018 llpp_user_2019 llpp_user_2020 
	
	*transfer Azad Kashmir to Jammu and Kashmir, Gilgit-Baltistan to Ladakh
	keep if inlist(country, "India", "Pakistan")
	replace country = "India" if inlist(name_1, "Azad Kashmir", "Gilgit-Baltistan")
	replace name_2 = "Pakistan-Occupied Kashmir" if name_1 == "Azad Kashmir" 
	replace name_1 = "Jammu and Kashmir" if name_1 == "Azad Kashmir"
	gen leh = 1 if name_1 == "Ladakh" & name_2 == "Leh (Ladakh)"
	replace leh = 0 if missing(leh)
	gsort -leh
	local leh_id = objectid_hover[1]
	drop leh
	replace name_2 = "Leh (Ladakh)" if name_1 == "Gilgit-Baltistan" 
	replace objectid_hover = `leh_id' if name_1 == "Gilgit-Baltistan" 
	replace name_1 = "Ladakh" if name_2 == "Leh (Ladakh)"
	replace iso_alpha3 = "IND" if country == "India"

	collapse (rawsum) population (mean) user_defined pm* llpp* [aweight = population], by(objectid_hover iso_alpha3 country name_1 name_2)

	preserve
	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)

	keep if inlist(name_2, "Pakistan-Occupied Kashmir", "Leh (Ladakh)")
	export delimited "political_sensitivity\IndiaPC\hover\PoKLeh_hover_`pc'.csv", replace
	restore

	tempfile updated_hover_`pc'
	save `"`updated_hover_`pc''"'

}


/*** II. Province/State: Jammu and Kashmir, Ladakh ***/
/** a. Pollution, WHO, national standard **/
use "`hover_updated_noround'", clear
keep if country == "India"
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country name_1 whostandard natstandard)
sort name_1 
gen objectid_state = _n

forvalues y = `startyear'/`endyear'{
	replace pm`y' = round(pm`y', 0.01)
	format pm`y' %9.2f

	replace llpp_who5_`y' = round(llpp_who5_`y', 0.01)
	format llpp_who5_`y' %9.2f

	replace llpp_nat_`y' = round(llpp_nat_`y', 0.01)
	replace llpp_nat_`y' = . if natstandard == 0
	format llpp_nat_`y' %9.2f
}
replace population = round(population, 1)

* export CSV of all states in India, for press inquiries
export delimited "political_sensitivity\IndiaPC\state\India_state.csv", replace

*J&K, Ladakh only
keep if inlist(name_1, "Jammu and Kashmir", "Ladakh")
export delimited "political_sensitivity\IndiaPC\state\KashmirLadakh_state.csv", replace

/** b. User-selected percent reductions **/
foreach pc in `percents'{
	use "`updated_hover_`pc''", clear
	keep if inlist(name_1, "Jammu and Kashmir", "Ladakh")
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country name_1 user_defined)
	order country name_1 user_defined population pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018 pm2019 pm2020 llpp_user_19* llpp_user_200* llpp_user_2010 llpp_user_2011 llpp_user_2012 llpp_user_2013 llpp_user_2014 llpp_user_2015 llpp_user_2016 llpp_user_2017 llpp_user_2018 llpp_user_2019 llpp_user_2020 

	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)

	export delimited "political_sensitivity\IndiaPC\state\KashmirLadakh_state_`pc'.csv", replace
}


/*** III. country: India, Pakistan ***/
/** a. Pollution, WHO, national standard **/
*reaggregate China country-level numbers
use "`hover_updated_noround'", clear
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country whostandard natstandard)

forvalues y = `startyear'/`endyear'{
	replace pm`y' = round(pm`y', 0.01)
	format pm`y' %9.2f

	replace llpp_who5_`y' = round(llpp_who5_`y', 0.01)
	format llpp_who5_`y' %9.2f

	replace llpp_nat_`y' = round(llpp_nat_`y', 0.01)
	replace llpp_nat_`y' = . if natstandard == 0
	format llpp_nat_`y' %9.2f
}
replace population = round(population, 1)
export delimited "political_sensitivity\IndiaPC\country\IndiaPakistan_country.csv", replace
tempfile temp
save `"`temp'"', replace

use "POV\clean\country", clear
drop if inlist(country, "India", "Pakistan")
append using "`temp'"
sort country
*export with all countries for media inquiries
export delimited "political_sensitivity\IndiaPC\country\all_country.csv", replace

/** b. User-selected percent reductions **/
foreach pc in `percents'{
	use "`updated_hover_`pc''", clear
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country user_defined)
	order country user_defined population pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 pm2020 llpp_user_19* llpp_user_200* llpp_user_2010 llpp_user_2011 llpp_user_2012 llpp_user_2013 llpp_user_2014 llpp_user_2015 llpp_user_2016 llpp_user_2017 llpp_user_2018 llpp_user_2019 llpp_user_2020 

	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)

	export delimited "political_sensitivity\IndiaPC\country\IndiaPakistan_country_`pc'.csv", replace
}
