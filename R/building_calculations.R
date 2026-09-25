# =============================================================================
# FILE: building_calculations.R
# PURPOSE: Every calculation about the BUILDING and ROOFTOP shape/area.
#          No solar-panel-specific math lives here (that is solar_calculations.R).
#
# R PRACTICAL CONCEPTS DEMONSTRATED
# ---------------------------------------------------------------------------
# - Area & perimeter formulas (multiplication, addition)
# - sqrt() for the diagonal calculation (Pythagoras)
# - abs() for comparing expected vs actual area difference
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - server.R calls calculate_building_summary() after the user clicks
#   "Analyze Building" on Page 2, using the values stored in reactive values.
# - The returned list is used by: the results cards on Page 3, the
#   visualization on Page 4, and the Final Dashboard.
# =============================================================================

#' Function name: calculate_building_area
#' Purpose:       Building footprint area.
#' Input:         building_length, building_width (metres)
#' Processing:    length * width
#' Output:        area in square metres
calculate_building_area <- function(building_length, building_width) {
  building_length * building_width
}

#' Function name: calculate_building_perimeter
#' Purpose:       Perimeter of the building footprint.
#' Processing:    2 * (length + width)
calculate_building_perimeter <- function(building_length, building_width) {
  2 * (building_length + building_width)
}

#' Function name: calculate_building_diagonal
#' Purpose:       Straight-line distance across the building footprint.
#' Processing:    sqrt(length^2 + width^2)   <- Pythagoras' theorem
calculate_building_diagonal <- function(building_length, building_width) {
  sqrt(building_length^2 + building_width^2)
}

#' Function name: calculate_total_floor_area
#' Purpose:       Sum of the floor area across every floor of the building.
#' Processing:    building_area * number_of_floors
calculate_total_floor_area <- function(building_area, number_of_floors) {
  building_area * number_of_floors
}

#' Function name: calculate_rooftop_area
#' Purpose:       Area of the rooftop (may differ from the building footprint
#'                if the user measured the roof separately, e.g. sloped roofs).
calculate_rooftop_area <- function(rooftop_length, rooftop_width) {
  rooftop_length * rooftop_width
}

#' Function name: calculate_rooftop_perimeter
#' Purpose:       Perimeter of the rooftop rectangle.
calculate_rooftop_perimeter <- function(rooftop_length, rooftop_width) {
  2 * (rooftop_length + rooftop_width)
}

#' Function name: calculate_solar_available_area
#' Purpose:       How much of the rooftop the user says CAN be used for solar
#'                (some roofs reserve space for water tanks, walking paths etc.
#'                even before we place obstacles individually).
#' Processing:    rooftop_area * solar_percentage / 100
calculate_solar_available_area <- function(rooftop_area, solar_percentage) {
  rooftop_area * (solar_percentage / 100)
}

#' Function name: calculate_obstacle_area
#' Purpose:       Combined area of every obstacle the user listed
#'                (water tanks, staircases, AC units, etc.)
#' Input:         obstacles_table - a data frame with columns
#'                'length_m' and 'width_m', one row per obstacle.
#' Processing:    area of each obstacle = length * width, then summed.
#' Output:        total obstacle area in square metres (0 if no obstacles).
calculate_obstacle_area <- function(obstacles_table) {
  if (is.null(obstacles_table) || nrow(obstacles_table) == 0) {
    return(0)
  }
  sum(obstacles_table$length_m * obstacles_table$width_m, na.rm = TRUE)
}

#' Function name: calculate_final_usable_solar_area
#' Purpose:       The realistic amount of rooftop area left for solar panels
#'                after removing obstacles, the maintenance walkway, and the
#'                safety clearance margin.
#' Input:         solar_available_area, obstacle_area, maintenance_area,
#'                safety_area (all in square metres)
#' Processing:    subtract each requirement in turn.
#' Output:        usable area, NEVER allowed to go below 0.
calculate_final_usable_solar_area <- function(solar_available_area,
                                               obstacle_area,
                                               maintenance_area,
                                               safety_area) {
  usable <- solar_available_area - obstacle_area - maintenance_area - safety_area
  usable <- max(usable, 0)   # a negative usable area makes no physical sense
  return(usable)
}

#' Function name: calculate_area_difference
#' Purpose:       Demonstrates abs(): compares the rooftop area the user
#'                expects to use for solar against what is actually usable
#'                after obstacles/maintenance/safety are removed, and reports
#'                the size of the gap regardless of direction.
#' Processing:    abs(expected_area - actual_usable_area)
calculate_area_difference <- function(expected_area, actual_usable_area) {
  abs(expected_area - actual_usable_area)
}

#' Function name: calculate_building_summary
#' Purpose:       Runs every building-related calculation in one call and
#'                returns a single named list, which is much easier to pass
#'                around Shiny reactive values than 10 separate variables.
#' Input:         a list of the raw user inputs (see argument names below)
#' Output:        a named list with every calculated building/rooftop metric
calculate_building_summary <- function(building_length, building_width,
                                        number_of_floors,
                                        rooftop_length, rooftop_width,
                                        solar_percentage,
                                        obstacles_table,
                                        maintenance_area,
                                        safety_area) {

  building_area      <- calculate_building_area(building_length, building_width)
  building_perimeter <- calculate_building_perimeter(building_length, building_width)
  building_diagonal  <- calculate_building_diagonal(building_length, building_width)
  total_floor_area   <- calculate_total_floor_area(building_area, number_of_floors)

  rooftop_area       <- calculate_rooftop_area(rooftop_length, rooftop_width)
  rooftop_perimeter  <- calculate_rooftop_perimeter(rooftop_length, rooftop_width)
  solar_available    <- calculate_solar_available_area(rooftop_area, solar_percentage)

  obstacle_area <- calculate_obstacle_area(obstacles_table)

  final_usable_area <- calculate_final_usable_solar_area(
    solar_available, obstacle_area, maintenance_area, safety_area
  )

  area_gap <- calculate_area_difference(solar_available, final_usable_area)

  list(
    building_area       = building_area,
    building_perimeter  = building_perimeter,
    building_diagonal   = building_diagonal,
    total_floor_area    = total_floor_area,
    rooftop_area        = rooftop_area,
    rooftop_perimeter   = rooftop_perimeter,
    solar_available_area = solar_available,
    obstacle_area       = obstacle_area,
    maintenance_area    = maintenance_area,
    safety_area         = safety_area,
    final_usable_area   = final_usable_area,
    area_gap            = area_gap
  )
}
