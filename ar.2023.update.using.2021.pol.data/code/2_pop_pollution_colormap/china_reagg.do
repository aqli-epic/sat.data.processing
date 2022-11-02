/*
Generate AQLI datasets that accord to China's stance on Taiwan, South Tibet.
I.e. Change Taiwan to be province of China. Change Shannan, Nyingtri prefectures
in Tibet to include various districts of Arunachal Pradesh. Change Arunachal Pradesh
to exclude 10 of its 18 districts.

Note: three districts of AP are now counted in both AP and Nyingtri. This is okay
since the district names do not show up on the Chinese side, so no one will know.

For website, generate datasets that only contain the affected regions.
For Chinese press, generate datasets of all countries, all Chinese provinces,
and all Chinese hover regions that include the adjusted regions.

Claire Fan
Jan 31 2020
*/

local startyear = 1998
local endyear = 2020
local percents 10 20 30 40 50 60 70 80 90 100

cd "C:\Arc"

/*** I. Hover: Shannan, Nyingtri ***/

/** a. Pollution, WHO, national standard **/

*start with unrounded PM and lifeyears numbers
*clean data as in 6_final_clean.do, but without rounding
use "POV/lifeyears_hover", clear
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

*add AP districts into Shannan and Nyingtri hover regions of Tibet, change Taiwan
*hover regions to be part of China
keep if inlist(country, "China", "Taiwan") | (country=="India" & name_1=="Arunachal Pradesh" & ///
	!inlist(name_2, "Longding", "Tirap", "Changlang", "Namsai", "Lohit")) 
gen original = 1 if country == "China"
replace original = 0 if missing(original)

replace name_1 = "Taiwan" if country == "Taiwan"

replace name_1 = "Xizang" if name_1 == "Arunachal Pradesh"
replace name_2 = "Shannan" if inlist(name_2, "Tawang", "West Kameng", ///
	"East Kameng", "Papum Pare", "Kurung Kumey", "Lower Subansiri")
replace name_2 = "Nyingtri" if inlist(name_2, "Upper Subansiri", "West Siang", ///
	"Upper Siang", "East Siang", "Dibang Valley", "Lower Dibang Valley", "Anjaw")
gsort name_1 name_2 -original
by name_1 name_2: replace objectid_hover = objectid_hover[1]

replace country = "China"
replace natstandard = 35
replace iso_alpha3 = "CHN"
drop original

collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 objectid_hover country name_1 name_2 whostandard natstandard)

tempfile hover_updated_noround
save `"`hover_updated_noround'"'

*round
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

sort name_1 name_2
compress

*save all Chinese hover regions with updated Shannan, Nyingtri, Taiwan
export delimited "political_sensitivity\ChinaPC\hover\China_hover.csv", replace

*save only Shannan, Nyingtri, Taiwan
keep if inlist(name_1, "Taiwan") | (name_1 == "Xizang" & inlist(name_2, "Shannan", "Nyingtri"))
export delimited "political_sensitivity\ChinaPC\hover\taiwan_sn_hover.csv", replace

/** b. User-selected percent reductions, changes only **/
foreach pc in `percents'{
	*start with unrounded PM and lifeyears numbers
	*clean data as in 6_final_clean.do, but without rounding
	use "POV\userdefined\lifeyears_hover_`pc'percent", clear
	rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)
	rename pop population
	gen user_defined = `pc'
	format population %11.0f 
	order objectid_hover iso_alpha3 country name_1 name_2 population user_defined pm* llpp_user*
	
	*add AP districts into Shannan and Nyingtri hover regions of Tibet, change Taiwan
	*hover regions to be part of China
	keep if inlist(country, "China", "Taiwan") | (country=="India" & name_1=="Arunachal Pradesh" & ///
		!inlist(name_2, "Longding", "Tirap", "Changlang", "Namsai", "Lohit")) 
	gen original = 1 if country == "China"
	replace original = 0 if missing(original)

	replace name_1 = "Taiwan" if country == "Taiwan"

	replace name_1 = "Xizang" if name_1 == "Arunachal Pradesh"
	replace name_2 = "Shannan" if inlist(name_2, "Tawang", "West Kameng", ///
		"East Kameng", "Papum Pare", "Kurung Kumey", "Lower Subansiri")
	replace name_2 = "Nyingtri" if inlist(name_2, "Upper Subansiri", "West Siang", ///
		"Upper Siang", "East Siang", "Dibang Valley", "Lower Dibang Valley", "Anjaw")
	gsort name_1 name_2 -original
	by name_1 name_2: replace objectid_hover = objectid_hover[1]

	replace country = "China"
	replace iso_alpha3 = "CHN"
	drop original

	*save only Shannan, Nyingtri, Taiwan
	keep if inlist(name_1, "Taiwan") | (name_1 == "Xizang" & inlist(name_2, "Shannan", "Nyingtri"))
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 objectid_hover country name_1 name_2 user_defined)
	tempfile updated_hover_`pc'
	save `"`updated_hover_`pc''"'
	
	*round
	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)
			
	export delimited "political_sensitivity\ChinaPC\hover\taiwan_sn_hover_`pc'.csv", replace 
}


/*** II. Province/State: Taiwan, Xizang, AP ***/
/** a. Pollution, WHO, national standard **/
use "`hover_updated_noround'", clear
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country name_1 whostandard natstandard)
gen taiwan = 1 if name_1 == "Taiwan"
replace taiwan = 0 if missing(taiwan)
sort taiwan name_1
gen objectid_state = _n
drop taiwan
sort name_1

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

*all Chinese states, with Taiwan; Tibet adjusted to include South Tibet
export delimited "political_sensitivity\ChinaPC\state\China_state.csv", replace

*Taiwan, adjusted Tibet only
keep if inlist(name_1, "Xizang", "Taiwan")
tempfile china_state_changed
save `"`china_state_changed'"'

*new AP state
use "`hover_original_noround'", clear
keep if name_1 == "Arunachal Pradesh" & inlist(name_2, "Longding", "Tirap", ///
	"Changlang", "Namsai", "Lohit", "Anjaw", "Lower Dibang Valley", "East Siang")
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country name_1 whostandard natstandard)
append using "`china_state_changed'"
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
drop objectid_state
export delimited "political_sensitivity\ChinaPC\state\ChinaIndia_state_changed.csv", replace

/** b. User-selected percent reductions **/
foreach pc in `percents'{
	use "POV\userdefined\lifeyears_hover_`pc'percent.dta", clear
	rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)
	rename pop population
	gen user_defined = `pc'
	keep if name_1 == "Arunachal Pradesh" & inlist(name_2, "Longding", "Tirap", ///
		"Changlang", "Namsai", "Lohit", "Anjaw", "Lower Dibang Valley", "East Siang")
	
	append using "`updated_hover_`pc''"
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country name_1 user_defined)
	order country name_1 user_defined population pm* llpp*

	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)

	export delimited "political_sensitivity/ChinaPC/state/ChinaIndia_state_changed_`pc'.csv", replace
}


/*** III. country: China, India ***/
/** a. Pollution, WHO, national standard **/
*reaggregate China country-level numbers
use "`hover_updated_noround'", clear
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country whostandard natstandard)
tempfile temp
save `"`temp'"'

*reaggregate India country-level numbers
use "`hover_original_noround'", clear
keep if country=="India"
drop if name_1 == "Arunachal Pradesh" & !inlist(name_2, "Longding", "Tirap", ///
	"Changlang", "Namsai", "Lohit", "Anjaw", "Lower Dibang Valley", "East Siang")
collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
	by(iso_alpha3 country whostandard natstandard)
append using "`temp'"

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
save `"`temp'"', replace

use "POV\clean\country", clear
drop if inlist(country, "China", "India", "Taiwan", "Hong Kong", "Macao")
append using "`temp'"

sort country
replace iso_alpha3 = "IND" if country=="India"
replace iso_alpha3 = "CHN" if country=="China"

*save with all countries
export delimited "political_sensitivity\ChinaPC\country\all_country.csv", replace

*save India and China only
keep if country == "India" | country == "China"
export delimited "political_sensitivity\ChinaPC\country\ChinaIndia_country.csv", replace

/** b. User-selected percent reductions **/
tempfile china_userselected
foreach pc in `percents'{
	use "POV/userdefined/lifeyears_hover_`pc'percent.dta", clear
	rename (NAME_0 NAME_1 NAME_2) (country name_1 name_2)
	rename pop population
	gen user_defined = `pc'
	
	preserve
	keep if country=="China"
	drop if name_1 == "Xizang" & inlist(name_2, "Shannan", "Nyingtri")
	append using "`updated_hover_`pc''"
	replace country = "China" if country=="Taiwan"
	replace iso_alpha3 = "CHN" if country == "China"
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country user_defined)
	save `"`china_userselected'"', replace
	restore
	
	keep if country=="India"
	drop if name_1 == "Arunachal Pradesh" & !inlist(name_2, "Longding", "Tirap", ///
	"Changlang", "Namsai", "Lohit", "Anjaw", "Lower Dibang Valley", "East Siang")
	collapse (rawsum) population (mean) pm* llpp* [aweight = population], ///
		by(iso_alpha3 country user_defined)
	append using "`china_userselected'"
	
	forvalues y = `startyear'/`endyear'{
		replace pm`y' = round(pm`y', 0.01)
		format pm`y' %9.2f

		replace llpp_user_`y' = round(llpp_user_`y', 0.01)
		format llpp_user_`y' %9.2f
	}
	replace population = round(population, 1)
			
	export delimited "political_sensitivity\ChinaPC\country\ChinaIndia_country_`pc'.csv", replace
}
