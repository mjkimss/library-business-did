*==============================================================
* Library Openings & Local Business Formation
* Phase 4: Difference-in-Differences Analysis (Stata)
* Author: Minjoo Kim
*==============================================================

cd "/Users/minjookim/Documents/library-business-did"

*----------------------------------------------------------------
* 1. IMPORT AND INSPECT
*----------------------------------------------------------------
import delimited "data/clean/business_panel.csv", clear
describe

*----------------------------------------------------------------
* 2. CONVERT STRING DATE/QUARTER FIELDS TO STATA NUMERIC FORMATS
*    (year_quarter, treatment_quarter, treatment_date arrived as
*    plain text strings from the Python export; Stata's panel and
*    DiD commands require true numeric time variables)
*----------------------------------------------------------------
gen year_quarter_num = quarterly(year_quarter, "YQ")
format year_quarter_num %tq

gen treatment_quarter_num = quarterly(treatment_quarter, "YQ")
format treatment_quarter_num %tq

gen treatment_date_num = date(treatment_date, "YMD")
format treatment_date_num %td

drop year_quarter treatment_quarter treatment_date
rename year_quarter_num year_quarter
rename treatment_quarter_num treatment_quarter
rename treatment_date_num treatment_date

describe
list branch_ year_quarter treatment_quarter in 1/5

*----------------------------------------------------------------
* 3. SET UP PANEL STRUCTURE
*    panel_id = unique branch x radius_spec combination (14 units)
*----------------------------------------------------------------
egen panel_id = group(branch_ radius_spec)
xtset panel_id year_quarter
* Result: strongly balanced panel, 2005q1-2026q2, 14 groups

*----------------------------------------------------------------
* 4. BASELINE MODEL: TWO-WAY FIXED EFFECTS
*    (naive DiD -- kept as a baseline comparison point, not the
*    primary specification, since design has staggered treatment
*    timing across cohorts with no permanently-untreated group)
*----------------------------------------------------------------
xtreg new_business_count post i.year_quarter, fe vce(cluster panel_id)
* post coefficient: -1.90 (p=0.118), not significant
* rho = 0.74 -- most variance is between-library, confirming FE
*   was the right call vs. a naive pooled regression
* Note: only 14 clusters -- cluster-robust SEs may be unreliable
*   with this few clusters (rule of thumb wants 30-50+)

*----------------------------------------------------------------
* 5. PRIMARY SPECIFICATION: CALLAWAY & SANT'ANNA STAGGERED DiD
*    (robust to staggered adoption / no never-treated group,
*    unlike naive TWFE above -- this is the headline result)
*----------------------------------------------------------------
ssc install csdid, replace
ssc install drdid, replace

gen gvar = treatment_quarter

csdid new_business_count, ivar(panel_id) time(year_quarter) gvar(gvar) method(dripw)
* No never-treated units -- csdid automatically uses not-yet-treated
*   units as controls (appropriate for this design)
* Note: g243 (Altgeld cohort) fully omitted -- insufficient
*   observations to separately identify this single-branch cohort.
*   Reported as a limitation, not corrected.

estat simple
* HEADLINE RESULT: ATT = 0.118 (SE 1.35, p=0.931)
* No detectable effect of library treatment on new business
*   formation, full sample, both radii pooled.

estat event, window(-8 8)
* Pre_avg = -0.349 (p=0.043, significant) -- some pre-trend
*   concern, worth flagging honestly as a limitation given
*   the small number of treated cohorts (7 branches).
* Post_avg = -0.717 (p=0.523, not significant)

csdid_plot
graph export "output/figures/event_study_full_sample.png", replace width(2000)

*----------------------------------------------------------------
* 6. ROBUSTNESS CHECK: SPLIT BY RADIUS SPECIFICATION
*    (confirms the null result isn't an artifact of one
*    arbitrary distance cutoff)
*----------------------------------------------------------------

* --- 0.25 mile radius ---
preserve
keep if radius_spec == "0.25mi"
csdid new_business_count, ivar(panel_id) time(year_quarter) gvar(gvar) method(dripw)
estat simple
* ATT = 0.118 (p=0.931) -- consistent with full sample
estat event, window(-8 8)
* Pre_avg p=0.043 -- pre-trend concern persists at this radius
csdid_plot
graph export "output/figures/event_study_025mi.png", replace width(2000)
restore

* --- 0.5 mile radius ---
preserve
keep if radius_spec == "0.5mi"
csdid new_business_count, ivar(panel_id) time(year_quarter) gvar(gvar) method(dripw)
estat simple
* ATT = 0.831 (p=0.741) -- consistent null result
estat event, window(-8 8)
* Pre_avg p=0.124 -- pre-trend concern weaker/non-significant
*   at this radius
csdid_plot
graph export "output/figures/event_study_05mi.png", replace width(2000)
restore

*----------------------------------------------------------------
* SUMMARY OF FINDINGS (for memo)
*----------------------------------------------------------------
* 1. No statistically significant effect of library branch
*    openings/renovations on new business formation, robust
*    across two radius specifications (0.25mi, 0.5mi) and two
*    estimation approaches (TWFE, Callaway & Sant'Anna).
* 2. Some evidence of pre-treatment trend differences across
*    cohorts (significant at pooled + 0.25mi, not at 0.5mi),
*    a genuine limitation given only 7 treated branches.
* 3. Altgeld (single-branch, 2020 cohort) could not be
*    separately identified by the staggered estimator --
*    insufficient post-treatment observations.
* 4. Small number of treated clusters (14 panel units, 7
*    underlying libraries) limits statistical power and the
*    reliability of cluster-robust inference throughout.
