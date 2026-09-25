# =============================================================================
# FILE: solar_calculations.R
# PURPOSE: Calculations that depend on the SELECTED SOLAR PANEL - its size,
#          power rating, and electrical characteristics. Building/rooftop
#          geometry lives in building_calculations.R; panel PLACEMENT lives
#          in panel_arrangement.R. This file is the "how much energy" layer.
#
# R PRACTICAL CONCEPTS DEMONSTRATED
# ---------------------------------------------------------------------------
# - Unit conversion (mm -> m)
# - Multiplication (area, power)
# - Division (W -> kW)
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - Takes the panel row from data_loader.R (one row of solar_panels.csv) and
#   the panel COUNT produced by panel_arrangement.R, and turns them into
#   capacity numbers shown on Page 9 (Solar Results) and the Dashboard.
# =============================================================================

#' Function name: convert_mm_to_m
#' Purpose:       Convert a millimetre measurement (as printed on datasheets)
#'                into metres (as used everywhere else in this app).
#' Processing:    value_mm / 1000
convert_mm_to_m <- function(value_mm) {
  value_mm / 1000
}

#' Function name: calculate_panel_area
#' Purpose:       Physical footprint area of a single panel.
#' Input:         panel_length_m, panel_width_m (metres)
#' Processing:    length * width
calculate_panel_area <- function(panel_length_m, panel_width_m) {
  panel_length_m * panel_width_m
}

#' Function name: calculate_total_panel_area
#' Purpose:       Combined footprint area of every installed panel.
#' Processing:    number_of_panels * panel_area_m2
calculate_total_panel_area <- function(number_of_panels, panel_area_m2) {
  number_of_panels * panel_area_m2
}

#' Function name: calculate_total_power_watts
#' Purpose:       Total DC power rating of the whole array, in watts.
#' Processing:    number_of_panels * panel_power_w
calculate_total_power_watts <- function(number_of_panels, panel_power_w) {
  number_of_panels * panel_power_w
}

#' Function name: calculate_total_capacity_kw
#' Purpose:       Same total power, expressed in kilowatts (the usual unit
#'                for describing a rooftop solar system's size).
#' Processing:    total_power_w / 1000
calculate_total_capacity_kw <- function(total_power_w) {
  total_power_w / 1000
}

#' Function name: calculate_remaining_area
#' Purpose:       Usable rooftop area minus the area actually covered by
#'                installed panels.
#' Processing:    max(usable_area - total_panel_area, 0)
calculate_remaining_area <- function(usable_area, total_panel_area) {
  remaining <- usable_area - total_panel_area
  max(remaining, 0)
}

#' Function name: calculate_rooftop_utilisation_percent
#' Purpose:       What fraction of the usable rooftop area ends up physically
#'                covered by panels. This single number drives the Smart
#'                Recommendation engine.
#' Processing:    (total_panel_area / usable_area) * 100
calculate_rooftop_utilisation_percent <- function(total_panel_area, usable_area) {
  if (is.na(usable_area) || usable_area <= 0) return(0)
  (total_panel_area / usable_area) * 100
}

#' Function name: build_solar_results_summary
#' Purpose:       Bundle every solar-capacity number into one list, ready to
#'                display on Page 9 and the Dashboard.
#' Input:         panel_row (one row from the CSV), number_of_panels (from
#'                the arrangement algorithm), usable_area (from
#'                building_calculations.R)
#' Output:        a named list of all solar-capacity metrics
build_solar_results_summary <- function(panel_row, number_of_panels, usable_area) {

  panel_length_m <- convert_mm_to_m(panel_row$length_mm)
  panel_width_m  <- convert_mm_to_m(panel_row$width_mm)

  panel_area_m2     <- calculate_panel_area(panel_length_m, panel_width_m)
  total_panel_area  <- calculate_total_panel_area(number_of_panels, panel_area_m2)
  total_power_w     <- calculate_total_power_watts(number_of_panels, panel_row$power_w)
  total_capacity_kw <- calculate_total_capacity_kw(total_power_w)
  remaining_area    <- calculate_remaining_area(usable_area, total_panel_area)
  utilisation_pct   <- calculate_rooftop_utilisation_percent(total_panel_area, usable_area)

  list(
    panel_length_m    = panel_length_m,
    panel_width_m     = panel_width_m,
    panel_area_m2     = panel_area_m2,
    number_of_panels  = number_of_panels,
    total_panel_area  = total_panel_area,
    total_power_w     = total_power_w,
    total_capacity_kw = total_capacity_kw,
    usable_area       = usable_area,
    remaining_area    = remaining_area,
    utilisation_pct   = utilisation_pct
  )
}
