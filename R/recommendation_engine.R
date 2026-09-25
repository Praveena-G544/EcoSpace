# =============================================================================
# FILE: recommendation_engine.R
# PURPOSE: Turn the calculated numbers (from building_calculations.R,
#          solar_calculations.R, and panel_arrangement.R) into a plain-English
#          recommendation. This is a RULE-BASED system (a set of if/else
#          checks), not machine learning - see README.md for why that is the
#          right choice for this project.
#
# HOW THE RULES WORK
# ---------------------------------------------------------------------------
# 1. Rooftop utilisation % (how much of the usable area is actually covered
#    by panels) decides the "fit level": Excellent / Good / Moderate /
#    Limited / Not suitable. Thresholds are defined in config.R so they are
#    easy to find and justify.
# 2. A set of smaller rule checks each add ONE sentence to the final
#    recommendation, based on specific conditions (obstacles present,
#    orientation chosen, panels found, etc).
# 3. All sentences are joined together into the final recommendation text
#    that is shown on Page 11 and the Dashboard.
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - server.R calls generate_recommendation() with the results already
#   produced by the other calculation files, once the user reaches Page 11.
# =============================================================================

#' Function name: determine_fit_level
#' Purpose:       Classify the installation into one of five fit levels based
#'                on rooftop utilisation percentage.
#' Input:         utilisation_pct - number between 0 and 100+
#'                thresholds - the RECOMMENDATION_THRESHOLDS list from config.R
#' Processing:    A simple ladder of if/else comparisons, highest first.
#' Output:        one of "Excellent fit", "Good fit", "Moderate fit",
#'                "Limited fit", "Not suitable"
determine_fit_level <- function(utilisation_pct, thresholds) {
  if (utilisation_pct >= thresholds$excellent) {
    return("Excellent fit")
  } else if (utilisation_pct >= thresholds$good) {
    return("Good fit")
  } else if (utilisation_pct >= thresholds$moderate) {
    return("Moderate fit")
  } else if (utilisation_pct >= thresholds$limited) {
    return("Limited fit")
  } else {
    return("Not suitable")
  }
}

#' Function name: generate_recommendation
#' Purpose:       Build the full recommendation text and fit level from
#'                every relevant calculated value.
#' Input:         solar_results   - list from build_solar_results_summary()
#'                arrangement     - list from plan_panel_arrangement()
#'                building_summary - list from calculate_building_summary()
#'                panel_row       - the selected panel's CSV row
#'                thresholds      - RECOMMENDATION_THRESHOLDS from config.R
#'                obstacle_count  - number of obstacles on the rooftop
#' Output:        a named list: fit_level (text) and recommendation_text
#'                (a paragraph built from several rule-based sentences)
generate_recommendation <- function(solar_results, arrangement,
                                     building_summary, panel_row,
                                     thresholds, obstacle_count = 0) {

  sentences <- c()

  # ---- Rule 1: overall fit level, based on rooftop utilisation ------------
  fit_level <- determine_fit_level(solar_results$utilisation_pct, thresholds)

  if (solar_results$number_of_panels == 0) {
    sentences <- c(sentences,
      "No valid panel arrangement was found. Consider increasing the usable rooftop area, reducing spacing requirements, or selecting a smaller panel."
    )
  } else {
    sentences <- c(sentences, paste0(
      "Based on the current inputs, the selected panel achieves a '", fit_level,
      "' for the available rooftop under the project's stated assumptions."
    ))

    # ---- Rule 2: panel count and capacity ---------------------------------
    sentences <- c(sentences, paste0(
      "The proposed arrangement can accommodate ", solar_results$number_of_panels,
      " panel(s), giving an estimated installed DC capacity of ",
      round(solar_results$total_capacity_kw, 2), " kW."
    ))

    # ---- Rule 3: orientation comparison -----------------------------------
    if (!is.null(arrangement$portrait_panel_count) &&
        !is.null(arrangement$landscape_panel_count) &&
        arrangement$portrait_panel_count != arrangement$landscape_panel_count) {
      better_orientation <- if (arrangement$landscape_panel_count > arrangement$portrait_panel_count) {
        "Landscape"
      } else {
        "Portrait"
      }
      sentences <- c(sentences, paste0(
        better_orientation, " orientation provides better rooftop utilisation than the alternative ",
        "orientation for this rooftop shape (", arrangement$portrait_panel_count,
        " panels in Portrait vs ", arrangement$landscape_panel_count, " panels in Landscape)."
      ))
    }

    # ---- Rule 4: remaining space --------------------------------------------
    if (solar_results$remaining_area > 0) {
      sentences <- c(sentences, paste0(
        round(solar_results$remaining_area, 2),
        " m² of usable rooftop area remains unused by this arrangement, ",
        "mainly due to panel spacing, edge clearance, and rectangular grid packing."
      ))
    }

    # ---- Rule 5: obstacle handling -------------------------------------------
    if (obstacle_count > 0) {
      sentences <- c(sentences, paste0(
        "A safety clearance has been preserved around all ", obstacle_count,
        " rooftop obstacle(s), so no panel overlaps these zones."
      ))
    }

    # ---- Rule 6: efficiency note ----------------------------------------------
    if (!is.na(panel_row$efficiency_percent) && panel_row$efficiency_percent >= 21) {
      sentences <- c(sentences,
        "The selected panel has a relatively high conversion efficiency, which helps maximise energy yield per square metre of limited rooftop space."
      )
    }
  }

  # ---- Rule 7: maintenance/safety space preserved ------------------------
  if (!is.na(building_summary$maintenance_area) && building_summary$maintenance_area > 0) {
    sentences <- c(sentences, paste0(
      "A maintenance zone of ", round(building_summary$maintenance_area, 2),
      " m² has been reserved as specified for the rooftop equipment/walkway."
    ))
  }

  recommendation_text <- paste(sentences, collapse = " ")

  list(
    fit_level           = fit_level,
    recommendation_text = recommendation_text
  )
}
