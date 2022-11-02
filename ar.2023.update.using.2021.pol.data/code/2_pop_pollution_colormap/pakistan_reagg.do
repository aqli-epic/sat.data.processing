/*
Generate AQLI datasets that accord to Pakistan's stance on Kashmir.
I.e. 

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
order objectid_hover iso_alpha3 country name_1 name_2 population whostandard natstandard pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 pm2020 llpp_who5_19* llpp_who5_200* llpp_who5_2010 llpp_who5_2011 llpp_who5_2012 llpp_who5_2013 llpp_who5_2014 llpp_who5_2015 llpp_who5_2016 llpp_who5_2017 llpp_who5_2018 llpp_who5_2019 llpp_who5_2020 llpp_nat_19* llpp_nat_200* llpp_nat_2010 llpp_nat_2011 llpp_nat_2012 llpp_nat_2013 llpp_nat_2014 llpp_nat_2015 llpp_nat_2016 llpp_nat_2017 llpp_nat_2018 llpp_nat_2019 llpp_nat_2020 

tempfile hover_original_noround
save `"`hover_original_noround'"'

*merge Azad Kashmir with India-controlled Kashmir and Ladakh, change population
*of Gilgit-Baltistan to pretend it is only Gilgit
keep if inlist(country, "India", "Pakistan")
replace country = "Jammu and Kashmir" if inlist(name_1, "Azad Kashmir", "Jammu and Kashmir", "Ladakh")
replace name_1 = "Jammu and Kashmir (Disputed Territory)" if country == "Jammu and Kashmir"
replace name_2 = "" if country == "Jammu and Kashmir"
replace natstandard = 0 if country == "Jammu and Kashmir"
forvalues y = `startyear'/`endyear'{
	replace llpp_nat_`y' = . if country == "Jammu and Kashmir"
}
replace iso_alpha3 = "" if country == "Jammu and Kashmir"
replace name_1 = "Gilgit" if name_1 == "Gilgit-Baltistan"
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country name_1 name_2 whostandard natstandard)

tempfile hover_updated_noround
save `"`hover_updated_noround'"'

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

* export CSV of all hover regions in Pakistan, for press inquiries
keep if inlist(country, "Pakistan", "Jammu and Kashmir")
export delimited "political_sensitivity\PakistanPC\hover\Pakistan_hover.csv", replace

* export CSV of only affected hover regions for Constructive 
keep if inlist(name_1, "Gilgit", "Jammu and Kashmir (Disputed Territory)")
export delimited "political_sensitivity\PakistanPC\hover\GilgitKashmir_hover.csv", replace

/** b. User-selected percent reductions, changes only **/
foreach pc in `percents'{
	*start with unrounded PM and lifeyears numbers
	*clean data as in 6_final_clean.do, but without rounding
	use "POV\userdefined\lifeyears_hover_`pc'percent", clear
	rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)
	rename pop population
	gen user_defined = `pc'
	format population %11.0f 
	order objectid_hover iso_alpha3 country name_1 name_2 population user_defined pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 llpp_user_19* llpp_user_200* llpp_user_2010 llpp_user_2011 llpp_user_2012 llpp_user_2013 llpp_user_2014 llpp_user_2015 llpp_user_2016 llpp_user_2017 llpp_user_2018 llpp_user_2019
	
	*merge Azad Kashmir with India-controlled Kashmir and Ladakh, change population
	*of Gilgit-Baltistan to pretend it is only Gilgit
	keep if inlist(country, "India", "Pakistan")
	replace country = "Jammu and Kashmir" if inlist(name_1, "Azad Kashmir", "Jammu and Kashmir", "Ladakh")
	replace name_1 = "Jammu and Kashmir (Disputed Territory)" if country == "Jammu and Kashmir"
	replace name_2 = "" if country == "Jammu and Kashmir"
	replace iso_alpha3 = "" if country == "Jammu and Kashmir"
	replace name_1 = "Gilgit" if name_1 == "Gilgit-Baltistan"
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country name_1 name_2 user_defined)

	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)

	tempfile updated_hover_`pc'
	save `"`updated_hover_`pc''"'

	keep if inlist(name_1, "Gilgit", "Jammu and Kashmir (Disputed Territory)")

	export delimited "political_sensitivity\PakistanPC\hover\GilgitKashmir_hover_`pc'.csv", replace
}

/*** II. country: India, Pakistan ***/
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

export delimited "political_sensitivity\PakistanPC\country\IndiaPakistanKashmir_country.csv", replace
tempfile temp
save `"`temp'"', replace

use "POV\clean\country", clear
drop if inlist(country, "India", "Pakistan")
append using "`temp'"
sort country
*export with all countries for media inquiries
export delimited "political_sensitivity\PakistanPC\country\all_country.csv", replace

/** b. User-selected percent reductions **/
foreach pc in `percents'{
	use "`updated_hover_`pc''", clear
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country user_defined)
	order iso_alpha3 country user_defined population pm19* pm200* pm2010 pm2011 pm2012 pm2013 pm2014 pm2015 pm2016 pm2017 pm2018  pm2019 llpp_user_19* llpp_user_200* llpp_user_2010 llpp_user_2011 llpp_user_2012 llpp_user_2013 llpp_user_2014 llpp_user_2015 llpp_user_2016 llpp_user_2017 llpp_user_2018 llpp_user_2019

	export delimited "political_sensitivity\PakistanPC\country\IndiaPakistanKashmir_country_`pc'.csv", replace
}
