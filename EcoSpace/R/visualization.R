# =============================================================================
# FILE: visualization.R
# PURPOSE: Draw the building and rooftop diagrams PROGRAMMATICALLY from the
#          user's actual numbers. Nothing here is a stock photo or an
#          AI-generated image - every rectangle on the plot is calculated
#          from the numbers the user entered (or, for panels, from the
#          panel_arrangement.R output).
#
# WHY ggplot2 + geom_rect()
# ---------------------------------------------------------------------------
# geom_rect() draws a rectangle from (xmin, ymin) to (xmax, ymax). Since
# every part of this app (building, rooftop, obstacles, panels) is
# represented as a rectangle with a position and a size, this one geometry
# is enough to draw the entire diagram. Changing an input number changes
# the rectangle's coordinates, which is exactly what "parametric" means.
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - server.R calls draw_building_diagram() for Page 4 (Building Visualization)
#   and draw_rooftop_solar_diagram() for Page 8 (Rooftop Solar Visualization).
# - Both functions return a ggplot object, which server.R renders using
#   renderPlot().
# =============================================================================

library(ggplot2)

#' Function name: draw_building_diagram
#' Purpose:       Draw a labelled top-down diagram of the building footprint,
#'                rooftop boundary, obstacles, maintenance area, and safety
#'                margin - all sized directly from the user's inputs.
#' Input:         building_length, building_width, rooftop_length, rooftop_width
#'                (all metres), obstacles_table, roof_type (text, used in title)
#' Output:        a ggplot object
draw_building_diagram <- function(building_length, building_width,
                                   rooftop_length, rooftop_width,
                                   obstacles_table, roof_type) {

  # The building footprint rectangle, anchored at the origin (0,0).
  building_rect <- data.frame(
    xmin = 0, xmax = building_length,
    ymin = 0, ymax = building_width
  )

  # The rooftop is drawn centred on top of the building footprint so the
  # two rectangles are easy to compare visually, even if their sizes differ.
  rooftop_x_offset <- (building_length - rooftop_length) / 2
  rooftop_y_offset <- (building_width  - rooftop_width)  / 2
  rooftop_rect <- data.frame(
    xmin = rooftop_x_offset, xmax = rooftop_x_offset + rooftop_length,
    ymin = rooftop_y_offset, ymax = rooftop_y_offset + rooftop_width
  )

  plot_obj <- ggplot() +
    geom_rect(data = building_rect,
              aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
              fill = "grey85", color = "black", linewidth = 0.8) +
    geom_rect(data = rooftop_rect,
              aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
              fill = NA, color = "#2563eb", linewidth = 1, linetype = "dashed")

  # Draw each obstacle as its own rectangle, positioned using the rooftop's
  # offset so obstacle coordinates line up with the rooftop rectangle above.
  if (!is.null(obstacles_table) && nrow(obstacles_table) > 0) {
    obstacle_rects <- data.frame(
      xmin  = rooftop_x_offset + obstacles_table$x_m,
      xmax  = rooftop_x_offset + obstacles_table$x_m + obstacles_table$length_m,
      ymin  = rooftop_y_offset + obstacles_table$y_m,
      ymax  = rooftop_y_offset + obstacles_table$y_m + obstacles_table$width_m,
      label = obstacles_table$type
    )
    plot_obj <- plot_obj +
      geom_rect(data = obstacle_rects,
                aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                fill = "#f87171", color = "black", alpha = 0.7) +
      geom_text(data = obstacle_rects,
                aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2, label = label),
                size = 3)
  }

  plot_obj +
    coord_fixed() +
    labs(
      title = paste0("Building Footprint (", building_length, " m x ", building_width,
                      " m) - ", roof_type, " Roof"),
      subtitle = "Dashed blue line = rooftop boundary. Red blocks = obstacles.",
      x = "Length (m)", y = "Width (m)"
    ) +
    theme_minimal(base_size = 12)
}

#' Function name: draw_rooftop_solar_diagram
#' Purpose:       Draw the rooftop with every placed solar panel, every
#'                obstacle, and the maintenance/edge margins, all generated
#'                from the panel_arrangement.R output.
#' Input:         rooftop_length, rooftop_width, panel_positions (data frame
#'                with x, y, w, h - one row per panel, from
#'                plan_panel_arrangement()$panel_positions), obstacles_table,
#'                orientation (text, used in the title)
#' Output:        a ggplot object
draw_rooftop_solar_diagram <- function(rooftop_length, rooftop_width,
                                        panel_positions, obstacles_table,
                                        orientation) {

  rooftop_rect <- data.frame(
    xmin = 0, xmax = rooftop_length, ymin = 0, ymax = rooftop_width
  )

  plot_obj <- ggplot() +
    geom_rect(data = rooftop_rect,
              aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
              fill = "grey95", color = "black", linewidth = 0.8)

  # Draw every installed panel as a small blue rectangle.
  if (!is.null(panel_positions) && nrow(panel_positions) > 0) {
    panel_rects <- data.frame(
      xmin = panel_positions$x,
      xmax = panel_positions$x + panel_positions$w,
      ymin = panel_positions$y,
      ymax = panel_positions$y + panel_positions$h
    )
    plot_obj <- plot_obj +
      geom_rect(data = panel_rects,
                aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                fill = "#1d4ed8", color = "white", linewidth = 0.3, alpha = 0.9)
  }

  # Draw obstacles on top, so they are clearly visible even where a panel
  # grid position was skipped because of them.
  if (!is.null(obstacles_table) && nrow(obstacles_table) > 0) {
    obstacle_rects <- data.frame(
      xmin = obstacles_table$x_m,
      xmax = obstacles_table$x_m + obstacles_table$length_m,
      ymin = obstacles_table$y_m,
      ymax = obstacles_table$y_m + obstacles_table$width_m,
      label = obstacles_table$type
    )
    plot_obj <- plot_obj +
      geom_rect(data = obstacle_rects,
                aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                fill = "#f87171", color = "black", alpha = 0.85) +
      geom_text(data = obstacle_rects,
                aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2, label = label),
                size = 3, color = "white")
  }

  panel_count <- if (!is.null(panel_positions)) nrow(panel_positions) else 0

  plot_obj +
    coord_fixed() +
    labs(
      title = paste0("Proposed Solar Installation - ", orientation, " Orientation"),
      subtitle = paste0(panel_count, " panels placed on a ",
                         rooftop_length, " m x ", rooftop_width, " m rooftop"),
      x = "Length (m)", y = "Width (m)"
    ) +
    theme_minimal(base_size = 12)
}
