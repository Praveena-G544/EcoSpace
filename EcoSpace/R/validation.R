# =============================================================================
# FILE: validation.R
# PURPOSE: Check that user-entered numbers make physical sense BEFORE any
#          calculation is performed. Returns friendly error messages instead
#          of letting the app crash or silently produce nonsense results.
#
# HOW THIS FILE IS USED
# ---------------------------------------------------------------------------
# server.R calls these functions inside validate()/need() blocks (see
# Shiny's built-in validation system) before running calculations. Each
# function below returns either NULL (meaning "no problem") or a character
# string describing the problem. server.R turns that string into a message
# the user sees on screen.
# =============================================================================

#' Function name: validate_positive_number
#' Purpose:       Generic check that a number is present and greater than zero.
#' Input:         value      - the number to check
#'                field_name - text used in the error message, e.g. "Building length"
#' Processing:    Checks for NA/NULL/non-numeric, then checks value > 0.
#' Output:        NULL if valid, or an error message string if not.
validate_positive_number <- function(value, field_name) {
  if (is.null(value) || is.na(value) || !is.numeric(value)) {
    return(paste(field_name, "must be a valid number."))
  }
  if (value <= 0) {
    return(paste(field_name, "must be greater than zero."))
  }
  return(NULL)
}

#' Function name: validate_percentage
#' Purpose:       Check that a percentage value is between 0 and 100.
validate_percentage <- function(value, field_name) {
  if (is.null(value) || is.na(value) || !is.numeric(value)) {
    return(paste(field_name, "must be a valid number."))
  }
  if (value < 0 || value > 100) {
    return(paste(field_name, "must be between 0 and 100."))
  }
  return(NULL)
}

#' Function name: validate_building_inputs
#' Purpose:       Run every check needed for Page 2 (Building Information)
#'                in one place.
#' Input:         building_length, building_width, number_of_floors,
#'                rooftop_length, rooftop_width, solar_percentage
#' Processing:    Calls the small validators above for every field and
#'                collects any error messages into one vector.
#' Output:        A character vector of error messages. Empty vector = all good.
validate_building_inputs <- function(building_length, building_width,
                                      number_of_floors,
                                      rooftop_length, rooftop_width,
                                      solar_percentage) {

  errors <- c(
    validate_positive_number(building_length, "Building length"),
    validate_positive_number(building_width, "Building width"),
    validate_positive_number(number_of_floors, "Number of floors"),
    validate_positive_number(rooftop_length, "Rooftop length"),
    validate_positive_number(rooftop_width, "Rooftop width"),
    validate_percentage(solar_percentage, "Solar available percentage")
  )

  # Remove the NULLs, keep only real error messages
  errors <- errors[!sapply(errors, is.null)]
  return(unlist(errors))
}

#' Function name: validate_obstacle
#' Purpose:       Check one obstacle's dimensions and position are sensible
#'                relative to the rooftop it sits on.
#' Input:         obstacle_length, obstacle_width, obstacle_x, obstacle_y,
#'                rooftop_length, rooftop_width
#' Processing:    Confirms positive dimensions, non-negative position, and
#'                that the obstacle rectangle does not extend past the roof.
#' Output:        A character vector of error messages (empty = valid).
validate_obstacle <- function(obstacle_length, obstacle_width,
                               obstacle_x, obstacle_y,
                               rooftop_length, rooftop_width) {

  errors <- c(
    validate_positive_number(obstacle_length, "Obstacle length"),
    validate_positive_number(obstacle_width, "Obstacle width")
  )
  errors <- errors[!sapply(errors, is.null)]

  if (!is.na(obstacle_x) && !is.na(obstacle_y)) {
    if (obstacle_x < 0 || obstacle_y < 0) {
      errors <- c(errors, "Obstacle position cannot be negative.")
    }
    if (!is.na(obstacle_length) && !is.na(obstacle_width)) {
      if ((obstacle_x + obstacle_length) > rooftop_length ||
          (obstacle_y + obstacle_width) > rooftop_width) {
        errors <- c(errors, "Obstacle extends beyond the rooftop boundary.")
      }
    }
  }

  return(errors)
}

#' Function name: validate_maintenance_area
#' Purpose:       Make sure the maintenance area the user typed in is not
#'                larger than the rooftop itself.
validate_maintenance_area <- function(maintenance_area_m2, rooftop_area_m2) {
  if (is.na(maintenance_area_m2) || is.na(rooftop_area_m2)) {
    return("Maintenance area could not be checked (missing values).")
  }
  if (maintenance_area_m2 >= rooftop_area_m2) {
    return("Maintenance area cannot be larger than the rooftop area. Please reduce it.")
  }
  return(NULL)
}

#' Function name: validate_spacing_inputs
#' Purpose:       Check panel spacing / clearance values entered on the
#'                Installation Requirements page.
validate_spacing_inputs <- function(panel_gap, edge_clearance,
                                     maintenance_width, safety_clearance) {
  errors <- c(
    validate_positive_number(panel_gap, "Panel gap")        %||% NULL,
    validate_positive_number(edge_clearance, "Edge clearance") %||% NULL,
    validate_positive_number(maintenance_width, "Maintenance walkway width") %||% NULL,
    validate_positive_number(safety_clearance, "Safety clearance") %||% NULL
  )
  errors <- errors[!sapply(errors, is.null)]
  return(unlist(errors))
}

# A tiny helper operator: `a %||% b` returns `a` unless `a` is NULL, in which
# case it returns `b`. Used above to keep the code readable.
`%||%` <- function(a, b) if (is.null(a)) b else a
