# =============================================================================
# FILE: panel_arrangement.R
# PURPOSE: Work out HOW MANY panels physically fit on the rooftop, and WHERE
#          each one goes. This is the main "smart" feature of the app.
#
# WHY WE DON'T JUST DO (rooftop_area / panel_area)
# ---------------------------------------------------------------------------
# That simple division ignores the SHAPE of the roof, the SPACING needed
# between panels, the EDGE CLEARANCE, and - most importantly - the actual
# POSITION of obstacles like water tanks. Two roofs with identical area can
# fit a very different number of panels depending on where a water tank sits.
# So instead we build a grid of candidate panel rectangles and test each one
# for collisions, which is a simplified version of how real layout software
# works.
#
# ALGORITHM OVERVIEW (step-by-step)
# ---------------------------------------------------------------------------
# 1. Shrink the rooftop rectangle inward by the edge clearance -> this is the
#    "placement zone" where panels are allowed to start.
# 2. Reserve a maintenance walkway strip along the bottom edge of that zone.
# 3. Expand every obstacle rectangle outward by the safety clearance -> this
#    is its "exclusion zone" (nothing may be placed inside it).
# 4. Depending on orientation (portrait/landscape), decide the panel's
#    footprint (length x width) on the roof.
# 5. Lay out a grid of candidate panel positions, spaced by the panel gap.
# 6. For each candidate position, check whether the panel rectangle overlaps
#    ANY obstacle exclusion zone. If yes, skip that position. If no, count it.
# 7. Repeat for the OTHER orientation, and keep whichever arrangement fits
#    more panels (this is the "compare portrait vs landscape" step).
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - server.R calls plan_panel_arrangement() after the user selects a panel
#   and confirms installation requirements (Page 6 -> Page 7).
# - The result (including the list of individual panel positions) is passed
#   straight to visualization.R to draw the rooftop diagram, and to
#   solar_calculations.R to compute total capacity.
# =============================================================================

#' Function name: rectangles_overlap
#' Purpose:       Basic rectangle-vs-rectangle collision test.
#' Input:         Two rectangles, each described by their bottom-left corner
#'                (x, y) and their size (width, height).
#' Processing:    Two rectangles do NOT overlap if one is completely to the
#'                left, right, above, or below the other. We check for that
#'                and negate it.
#' Output:        TRUE if the rectangles overlap, FALSE otherwise.
rectangles_overlap <- function(x1, y1, w1, h1, x2, y2, w2, h2) {
  no_overlap <- (x1 + w1 <= x2) || (x2 + w2 <= x1) ||
                (y1 + h1 <= y2) || (y2 + h2 <= y1)
  return(!no_overlap)
}

#' Function name: build_obstacle_exclusion_zones
#' Purpose:       Expand every obstacle rectangle outward by the safety
#'                clearance, producing the "no panels here" zones.
#' Input:         obstacles_table with columns length_m, width_m, x_m, y_m
#'                safety_clearance - metres to expand on every side
#' Output:        a data frame of expanded rectangles (x, y, w, h)
build_obstacle_exclusion_zones <- function(obstacles_table, safety_clearance) {
  if (is.null(obstacles_table) || nrow(obstacles_table) == 0) {
    return(data.frame(x = numeric(0), y = numeric(0),
                       w = numeric(0), h = numeric(0)))
  }

  data.frame(
    x = obstacles_table$x_m - safety_clearance,
    y = obstacles_table$y_m - safety_clearance,
    w = obstacles_table$length_m + (2 * safety_clearance),
    h = obstacles_table$width_m  + (2 * safety_clearance)
  )
}

#' Function name: panel_overlaps_any_obstacle
#' Purpose:       Check one candidate panel rectangle against every
#'                obstacle exclusion zone.
#' Output:        TRUE if the panel collides with at least one obstacle.
panel_overlaps_any_obstacle <- function(panel_x, panel_y, panel_w, panel_h,
                                         exclusion_zones) {
  if (nrow(exclusion_zones) == 0) return(FALSE)

  for (i in seq_len(nrow(exclusion_zones))) {
    if (rectangles_overlap(panel_x, panel_y, panel_w, panel_h,
                            exclusion_zones$x[i], exclusion_zones$y[i],
                            exclusion_zones$w[i], exclusion_zones$h[i])) {
      return(TRUE)
    }
  }
  return(FALSE)
}

#' Function name: calculate_arrangement_for_orientation
#' Purpose:       Run the full grid-placement algorithm for ONE orientation
#'                (either "Portrait" or "Landscape").
#' Input:         rooftop_length, rooftop_width (metres)
#'                panel_length_m, panel_width_m (metres, as given on datasheet)
#'                orientation - "Portrait" or "Landscape"
#'                panel_gap, edge_clearance, maintenance_width, safety_clearance
#'                obstacles_table
#' Processing:    See the step-by-step algorithm description at the top of
#'                this file.
#' Output:        a named list: orientation, rows, columns, total_panels,
#'                panel_positions (data frame, one row per placed panel),
#'                used_area_m2
calculate_arrangement_for_orientation <- function(rooftop_length, rooftop_width,
                                                   panel_length_m, panel_width_m,
                                                   orientation,
                                                   panel_gap, edge_clearance,
                                                   maintenance_width,
                                                   safety_clearance,
                                                   obstacles_table) {

  # Step 4: choose the panel's footprint on the roof for this orientation.
  # Portrait = the panel's long side runs top-to-bottom (along rooftop width).
  # Landscape = the panel's long side runs left-to-right (along rooftop length).
  long_side  <- max(panel_length_m, panel_width_m)
  short_side <- min(panel_length_m, panel_width_m)

  if (orientation == "Portrait") {
    footprint_x <- short_side   # width taken along the X (length) axis
    footprint_y <- long_side    # height taken along the Y (width) axis
  } else {
    footprint_x <- long_side
    footprint_y <- short_side
  }

  # Step 1: shrink the rooftop rectangle by the edge clearance.
  zone_x_start <- edge_clearance
  zone_y_start <- edge_clearance
  zone_width   <- rooftop_length - (2 * edge_clearance)
  zone_height  <- rooftop_width  - (2 * edge_clearance)

  # Step 2: reserve a maintenance walkway strip along the bottom of the zone.
  zone_height  <- zone_height - maintenance_width

  # If nothing sensible is left, return an empty (zero panel) result.
  if (is.na(zone_width) || is.na(zone_height) ||
      zone_width <= 0 || zone_height <= 0 ||
      is.na(footprint_x) || is.na(footprint_y) ||
      footprint_x <= 0 || footprint_y <= 0) {
    return(list(
      orientation = orientation, rows = 0, columns = 0, total_panels = 0,
      panel_positions = data.frame(x = numeric(0), y = numeric(0),
                                    w = numeric(0), h = numeric(0)),
      used_area_m2 = 0
    ))
  }

  # Step 5: work out how many rows/columns of panels fit in the placement
  # zone, counting the small gap between panels.
  columns <- floor((zone_width  + panel_gap) / (footprint_x + panel_gap))
  rows    <- floor((zone_height + panel_gap) / (footprint_y + panel_gap))
  columns <- max(columns, 0)
  rows    <- max(rows, 0)

  # Step 3: build the obstacle exclusion zones once, reuse for every panel.
  exclusion_zones <- build_obstacle_exclusion_zones(obstacles_table, safety_clearance)

  placed_panels <- list()
  panel_count   <- 0

  # Step 6: walk the grid, row by row and column by column, testing each
  # candidate position for a collision with an obstacle.
  if (rows > 0 && columns > 0) {
    for (row_index in 0:(rows - 1)) {
      for (col_index in 0:(columns - 1)) {

        candidate_x <- zone_x_start + col_index * (footprint_x + panel_gap)
        candidate_y <- zone_y_start + row_index * (footprint_y + panel_gap)

        collides <- panel_overlaps_any_obstacle(
          candidate_x, candidate_y, footprint_x, footprint_y, exclusion_zones
        )

        if (!collides) {
          panel_count <- panel_count + 1
          placed_panels[[panel_count]] <- data.frame(
            x = candidate_x, y = candidate_y, w = footprint_x, h = footprint_y
          )
        }
      }
    }
  }

  if (panel_count > 0) {
    panel_positions <- do.call(rbind, placed_panels)
  } else {
    panel_positions <- data.frame(x = numeric(0), y = numeric(0),
                                   w = numeric(0), h = numeric(0))
  }

  used_area_m2 <- panel_count * footprint_x * footprint_y

  list(
    orientation     = orientation,
    rows            = rows,
    columns         = columns,
    total_panels    = panel_count,
    panel_positions = panel_positions,
    used_area_m2    = used_area_m2
  )
}

#' Function name: plan_panel_arrangement
#' Purpose:       Top-level function called by server.R. Runs BOTH
#'                orientations (Step 7) and returns whichever one places
#'                more panels, unless the user explicitly forced one
#'                orientation on the Installation Requirements page.
#' Input:         orientation_choice - "Portrait", "Landscape", or
#'                "Automatic (compare both)"
#'                (plus all the geometry arguments used above)
#' Output:        the winning arrangement list, PLUS the losing one's panel
#'                count so the UI can show the comparison.
plan_panel_arrangement <- function(rooftop_length, rooftop_width,
                                    panel_length_m, panel_width_m,
                                    orientation_choice,
                                    panel_gap, edge_clearance,
                                    maintenance_width, safety_clearance,
                                    obstacles_table) {

  portrait_result <- calculate_arrangement_for_orientation(
    rooftop_length, rooftop_width, panel_length_m, panel_width_m,
    "Portrait", panel_gap, edge_clearance, maintenance_width,
    safety_clearance, obstacles_table
  )

  landscape_result <- calculate_arrangement_for_orientation(
    rooftop_length, rooftop_width, panel_length_m, panel_width_m,
    "Landscape", panel_gap, edge_clearance, maintenance_width,
    safety_clearance, obstacles_table
  )

  if (orientation_choice == "Portrait") {
    chosen <- portrait_result
  } else if (orientation_choice == "Landscape") {
    chosen <- landscape_result
  } else {
    # "Automatic (compare both)" -> pick whichever orientation places more panels
    if (portrait_result$total_panels >= landscape_result$total_panels) {
      chosen <- portrait_result
    } else {
      chosen <- landscape_result
    }
  }

  chosen$portrait_panel_count  <- portrait_result$total_panels
  chosen$landscape_panel_count <- landscape_result$total_panels

  return(chosen)
}
