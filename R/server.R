# =============================================================================
# FILE: server.R
# PURPOSE: All the "thinking" behind the app. Reads user inputs, validates
#          them, calls the calculation files, and writes results back to the
#          UI outputs defined in ui.R.
#
# KEY SHINY CONCEPTS USED IN THIS FILE (explained briefly for your viva)
# ---------------------------------------------------------------------------
# reactiveVal()     - a single piece of "live" data (like the obstacles
#                      table, or the calculated results) that automatically
#                      re-triggers anything that reads it whenever it changes.
# observeEvent()    - runs a block of code ONLY when a specific button is
#                      clicked or input changes. Used here for every
#                      navigation button and every "Add obstacle" click.
# renderPlot()      - tells Shiny "this output is a picture"; re-draws
#                      automatically whenever the data behind it changes.
# renderUI()        - tells Shiny "this output is a chunk of HTML/UI";
#                      lets us build result cards dynamically in R code.
# req()             - short for "require"; stops the code below it from
#                      running until a value exists (e.g. a panel has been
#                      selected). Prevents errors from empty inputs.
# validate()/need() - shows a friendly message in the UI instead of a red
#                      error, when an input fails a check.
#
# WHY INPUTS SURVIVE NAVIGATION
# ---------------------------------------------------------------------------
# Every page's UI is built once, when the app starts, and stays in the page
# (it is only hidden with CSS, never removed). Because of this, Shiny keeps
# every input's value in memory automatically - you do not need to write any
# extra code to "save" a text box's value before moving to the next page.
# =============================================================================

server <- function(input, output, session) {

  # ---------------------------------------------------------------------
  # Load the real solar panel database ONCE when the app starts.
  # ---------------------------------------------------------------------
  panels_data <- load_solar_panel_data("data/solar_panels.csv")

  updateSelectInput(session, "filter_manufacturer",
                     choices = c("All", sort(unique(panels_data$manufacturer))))
  updateSelectInput(session, "filter_technology",
                     choices = c("All", sort(unique(panels_data$technology))))

  # ---------------------------------------------------------------------
  # Reactive values that need to persist and be recalculated - these hold
  # things that are NOT simple form inputs (dynamic tables and results).
  # ---------------------------------------------------------------------
  obstacles_rv        <- reactiveVal(data.frame(
    type = character(), length_m = numeric(), width_m = numeric(),
    x_m = numeric(), y_m = numeric(), stringsAsFactors = FALSE
  ))
  selected_panel_id   <- reactiveVal(NULL)
  building_summary_rv <- reactiveVal(NULL)
  arrangement_rv      <- reactiveVal(NULL)
  solar_results_rv     <- reactiveVal(NULL)
  recommendation_rv    <- reactiveVal(NULL)

  # =========================================================================
  # NAVIGATION - one small helper used by every Back/Next button
  # =========================================================================
  go_to_page <- function(hide_id, show_id) {
    shinyjs::hide(hide_id)
    shinyjs::show(show_id)
    # FIX: DataTables (the searchable panel table, and the obstacle tables)
    # gets initialised while its page div still has "display:none" on it.
    # DataTables reads the container's width at draw time, so if it is
    # hidden at that moment it draws with a wrong width and its Previous/
    # Next pagination buttons become unresponsive, and only a partial page
    # of rows appears correct. Triggering a window "resize" event after the
    # page becomes visible makes DataTables recalculate its layout and
    # restores normal pagination.
    shinyjs::delay(100, shinyjs::runjs("$(window).trigger('resize');"))
  }

  observeEvent(input$btn_get_started, go_to_page("page_home", "page_building_info"))
  observeEvent(input$btn_home_from_building_info, go_to_page("page_building_info", "page_home"))
  observeEvent(input$btn_back_to_building_info, go_to_page("page_building_analysis", "page_building_info"))
  observeEvent(input$btn_back_to_building_analysis, go_to_page("page_building_viz", "page_building_analysis"))
  observeEvent(input$btn_continue_to_solar, go_to_page("page_building_viz", "page_panel_selection"))
  observeEvent(input$btn_back_to_building_viz, go_to_page("page_panel_selection", "page_building_viz"))
  observeEvent(input$btn_back_to_panel_selection, go_to_page("page_installation_req", "page_panel_selection"))
  observeEvent(input$btn_back_to_installation, go_to_page("page_panel_arrangement", "page_installation_req"))
  observeEvent(input$btn_back_to_arrangement, go_to_page("page_rooftop_viz", "page_panel_arrangement"))
  observeEvent(input$btn_back_to_rooftop_viz, go_to_page("page_solar_results", "page_rooftop_viz"))
  observeEvent(input$btn_back_to_solar_results, go_to_page("page_electrical_info", "page_solar_results"))
  observeEvent(input$btn_back_to_electrical, go_to_page("page_recommendation", "page_electrical_info"))

  observeEvent(input$btn_view_installation, go_to_page("page_panel_arrangement", "page_rooftop_viz"))
  observeEvent(input$btn_view_electrical, go_to_page("page_solar_results", "page_electrical_info"))

  observeEvent(input$btn_start_new_project, {
    session$reload()
  })

  # =========================================================================
  # OBSTACLES - add / remove / display (shared by Page 2 and Page 6)
  # =========================================================================
  observeEvent(input$btn_add_obstacle, {
    current <- obstacles_rv()
    new_row <- data.frame(
      type = input$new_obstacle_type,
      length_m = input$new_obstacle_length,
      width_m = input$new_obstacle_width,
      x_m = input$new_obstacle_x,
      y_m = input$new_obstacle_y,
      stringsAsFactors = FALSE
    )
    obstacles_rv(rbind(current, new_row))
  })

  observeEvent(input$btn_remove_obstacle, {
    selected_row <- input$obstacles_table_view_rows_selected
    current <- obstacles_rv()
    if (!is.null(selected_row) && nrow(current) >= selected_row) {
      obstacles_rv(current[-selected_row, , drop = FALSE])
    }
  })

  output$obstacles_table_view <- renderDT({
    datatable(obstacles_rv(), selection = "single", options = list(dom = "t"))
  })
  output$obstacles_table_view_2 <- renderDT({
    datatable(obstacles_rv(), selection = "none", options = list(dom = "t"))
  })

  # =========================================================================
  # PAGE 3 - BUILDING ANALYSIS
  # =========================================================================
  observeEvent(input$btn_analyze_building, {

    errors <- validate_building_inputs(
      input$building_length, input$building_width, input$number_of_floors,
      input$rooftop_length, input$rooftop_width, input$solar_percentage
    )

    rooftop_area_check <- calculate_rooftop_area(input$rooftop_length, input$rooftop_width)
    maintenance_error <- validate_maintenance_area(input$maintenance_area_input, rooftop_area_check)
    if (!is.null(maintenance_error)) errors <- c(errors, maintenance_error)

    if (length(errors) > 0) {
      showNotification(paste(errors, collapse = " | "), type = "error", duration = 8)
      return(NULL)
    }

    summary_result <- calculate_building_summary(
      building_length = input$building_length,
      building_width  = input$building_width,
      number_of_floors = input$number_of_floors,
      rooftop_length  = input$rooftop_length,
      rooftop_width   = input$rooftop_width,
      solar_percentage = input$solar_percentage,
      obstacles_table = obstacles_rv(),
      maintenance_area = input$maintenance_area_input,
      safety_area = input$safety_clearance_input
    )

    building_summary_rv(summary_result)
    go_to_page("page_building_info", "page_building_analysis")
  })

  # Small helper used in several places: turn a named list of metrics into
  # a row of little "stat cards".
  make_stat_cards <- function(metric_list) {
    cards <- lapply(names(metric_list), function(metric_name) {
      value <- metric_list[[metric_name]]
      div(class = "stat-card",
        div(class = "stat-value", value),
        div(class = "stat-label", metric_name)
      )
    })
    div(class = "stat-card-row", cards)
  }

  output$building_analysis_cards <- renderUI({
    req(building_summary_rv())
    s <- building_summary_rv()
    make_stat_cards(list(
      "Building Area (m^2)"        = round(s$building_area, 2),
      "Building Perimeter (m)"     = round(s$building_perimeter, 2),
      "Building Diagonal (m)"      = round(s$building_diagonal, 2),
      "Total Floor Area (m^2)"     = round(s$total_floor_area, 2),
      "Rooftop Area (m^2)"         = round(s$rooftop_area, 2),
      "Solar Available Area (m^2)" = round(s$solar_available_area, 2),
      "Obstacle Area (m^2)"        = round(s$obstacle_area, 2),
      "Maintenance Area (m^2)"     = round(s$maintenance_area, 2),
      "Safety Area (m^2)"          = round(s$safety_area, 2),
      "Final Usable Solar Area (m^2)" = round(s$final_usable_area, 2)
    ))
  })

  observeEvent(input$btn_generate_building_viz, {
    req(building_summary_rv())
    go_to_page("page_building_analysis", "page_building_viz")
  })

  # =========================================================================
  # PAGE 4 - BUILDING VISUALIZATION
  # =========================================================================
  output$building_diagram_plot <- renderPlot({
    req(building_summary_rv())
    draw_building_diagram(
      building_length = input$building_length,
      building_width  = input$building_width,
      rooftop_length  = input$rooftop_length,
      rooftop_width   = input$rooftop_width,
      obstacles_table = obstacles_rv(),
      roof_type       = input$roof_type
    )
  })

  output$building_summary_cards <- renderUI({
    req(building_summary_rv())
    s <- building_summary_rv()
    make_stat_cards(list(
      "Floors"                     = input$number_of_floors,
      "Roof Type"                  = input$roof_type,
      "Rooftop Area (m^2)"         = round(s$rooftop_area, 2),
      "Available Solar Area (m^2)" = round(s$solar_available_area, 2),
      "Obstacles"                  = nrow(obstacles_rv()),
      "Maintenance Area (m^2)"     = round(s$maintenance_area, 2),
      "Safety Area (m^2)"          = round(s$safety_area, 2)
    ))
  })

  # =========================================================================
  # PAGE 5 - SOLAR PANEL SELECTION
  # =========================================================================
  filtered_panels <- reactive({
    data <- panels_data
    if (!is.null(input$filter_manufacturer) && input$filter_manufacturer != "All") {
      data <- data[data$manufacturer == input$filter_manufacturer, ]
    }
    if (!is.null(input$filter_technology) && input$filter_technology != "All") {
      data <- data[data$technology == input$filter_technology, ]
    }
    if (!is.null(input$filter_min_power)) {
      data <- data[is.na(data$power_w) | data$power_w >= input$filter_min_power, ]
    }
    if (!is.null(input$filter_min_efficiency)) {
      data <- data[is.na(data$efficiency_percent) | data$efficiency_percent >= input$filter_min_efficiency, ]
    }
    data
  })

  output$panel_selection_table <- renderDT({
    datatable(
      filtered_panels()[, c("panel_id", "manufacturer", "model", "power_w",
                             "efficiency_percent", "technology")],
      selection = "single",
      options = list(pageLength = 5, lengthMenu = c(5, 10, 25, 50),
                     autoWidth = FALSE, scrollX = TRUE)
    )
  })

  observeEvent(input$panel_selection_table_rows_selected, {
    selected_row <- input$panel_selection_table_rows_selected
    req(selected_row)
    selected_panel_id(filtered_panels()$panel_id[selected_row])
  })

  output$selected_panel_details <- renderUI({
    req(selected_panel_id())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    if (nrow(panel_row) == 0) return(NULL)

    card(
      card_header(paste("Selected Panel:", panel_row$manufacturer, panel_row$model)),
      make_stat_cards(list(
        "Series"      = panel_row$series,
        "Technology"  = panel_row$technology,
        "Power (W)"   = panel_row$power_w,
        "Length (mm)" = panel_row$length_mm,
        "Width (mm)"  = panel_row$width_mm,
        "Thickness (mm)" = panel_row$thickness_mm,
        "Weight (kg)" = panel_row$weight_kg,
        "Efficiency (%)" = panel_row$efficiency_percent,
        "Voc (V)"     = panel_row$voc_v,
        "Isc (A)"     = panel_row$isc_a,
        "Vmp (V)"     = panel_row$vmp_v,
        "Imp (A)"     = panel_row$imp_a,
        "Max System Voltage (V)" = panel_row$max_system_voltage_v,
        "Max Series Fuse (A)"    = panel_row$max_series_fuse_a,
        "Temp. Coeff. Pmax (%/C)" = panel_row$temperature_coefficient_pmax,
        "Warranty (years)"       = panel_row$warranty_years
      )),
      p(strong("Source: "), panel_row$source),
      if (!is.na(panel_row$datasheet_url) && nzchar(panel_row$datasheet_url)) {
        tags$a(href = panel_row$datasheet_url, target = "_blank",
               class = "btn btn-outline-primary", "View Manufacturer Datasheet")
      }
    )
  })

  # =========================================================================
  # NAVIGATE forward once a panel has been chosen
  # =========================================================================
  observeEvent(input$btn_continue_to_installation, {
    if (is.null(selected_panel_id())) {
      showNotification("Please select a solar panel before continuing.", type = "warning")
      return(NULL)
    }
    go_to_page("page_panel_selection", "page_installation_req")
  })

  # =========================================================================
  # PAGE 7 - PANEL ARRANGEMENT
  # =========================================================================
  observeEvent(input$btn_calculate_arrangement, {

    req(selected_panel_id(), building_summary_rv())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())

    spacing_errors <- validate_spacing_inputs(
      input$panel_gap_input, input$edge_clearance_input,
      input$maintenance_width_input, input$safety_clearance_2_input
    )
    if (length(spacing_errors) > 0) {
      showNotification(paste(spacing_errors, collapse = " | "), type = "error")
      return(NULL)
    }

    panel_length_m <- convert_mm_to_m(panel_row$length_mm)
    panel_width_m  <- convert_mm_to_m(panel_row$width_mm)

    arrangement_result <- plan_panel_arrangement(
      rooftop_length = input$rooftop_length,
      rooftop_width  = input$rooftop_width,
      panel_length_m = panel_length_m,
      panel_width_m  = panel_width_m,
      orientation_choice = input$panel_orientation,
      panel_gap = input$panel_gap_input,
      edge_clearance = input$edge_clearance_input,
      maintenance_width = input$maintenance_width_input,
      safety_clearance = input$safety_clearance_2_input,
      obstacles_table = obstacles_rv()
    )

    arrangement_rv(arrangement_result)

    if (arrangement_result$total_panels == 0) {
      showNotification(
        "No valid panel arrangement was found. Consider increasing the usable rooftop area or selecting a smaller panel.",
        type = "warning", duration = 10
      )
    }

    go_to_page("page_installation_req", "page_panel_arrangement")
  })

  output$arrangement_summary_cards <- renderUI({
    req(arrangement_rv())
    a <- arrangement_rv()
    make_stat_cards(list(
      "Panels Installed" = a$total_panels,
      "Rows"             = a$rows,
      "Columns"          = a$columns,
      "Orientation"      = a$orientation,
      "Used Area (m^2)"  = round(a$used_area_m2, 2),
      "Portrait Count"   = a$portrait_panel_count,
      "Landscape Count"  = a$landscape_panel_count
    ))
  })

  # =========================================================================
  # PAGE 8 - ROOFTOP SOLAR VISUALIZATION
  # =========================================================================
  output$rooftop_solar_plot <- renderPlot({
    req(arrangement_rv())
    a <- arrangement_rv()
    draw_rooftop_solar_diagram(
      rooftop_length = input$rooftop_length,
      rooftop_width  = input$rooftop_width,
      panel_positions = a$panel_positions,
      obstacles_table = obstacles_rv(),
      orientation = a$orientation
    )
  })

  output$rooftop_viz_summary <- renderUI({
    req(arrangement_rv(), building_summary_rv())
    a <- arrangement_rv()
    s <- building_summary_rv()
    unused <- max(s$final_usable_area - a$used_area_m2, 0)
    make_stat_cards(list(
      "Panels Installed" = a$total_panels,
      "Rows"    = a$rows,
      "Columns" = a$columns,
      "Orientation" = a$orientation,
      "Used Area (m^2)"   = round(a$used_area_m2, 2),
      "Unused Area (m^2)" = round(unused, 2)
    ))
  })

  # =========================================================================
  # PAGE 9 - SOLAR CALCULATION RESULTS
  # =========================================================================
  observeEvent(input$btn_view_results, {
    req(arrangement_rv(), building_summary_rv(), selected_panel_id())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    results <- build_solar_results_summary(
      panel_row = panel_row,
      number_of_panels = arrangement_rv()$total_panels,
      usable_area = building_summary_rv()$final_usable_area
    )
    solar_results_rv(results)
    go_to_page("page_rooftop_viz", "page_solar_results")
  })

  output$solar_results_cards <- renderUI({
    req(solar_results_rv())
    r <- solar_results_rv()
    make_stat_cards(list(
      "Number of Panels"       = r$number_of_panels,
      "Panel Area (m^2)"       = round(r$panel_area_m2, 3),
      "Total Panel Area (m^2)" = round(r$total_panel_area, 2),
      "Usable Rooftop Area (m^2)" = round(r$usable_area, 2),
      "Used Area (m^2)"        = round(r$total_panel_area, 2),
      "Unused Area (m^2)"      = round(r$remaining_area, 2),
      "Total Power (W)"        = round(r$total_power_w, 1),
      "Installed Capacity (kW)" = round(r$total_capacity_kw, 2),
      "Rooftop Utilisation (%)" = round(r$utilisation_pct, 1)
    ))
  })

  # =========================================================================
  # PAGE 10 - ELECTRICAL INFORMATION
  # =========================================================================
  output$electrical_info_cards <- renderUI({
    req(selected_panel_id())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    make_stat_cards(list(
      "Rated Power (W)"     = panel_row$power_w,
      "Voc (V)"             = panel_row$voc_v,
      "Isc (A)"             = panel_row$isc_a,
      "Vmp (V)"             = panel_row$vmp_v,
      "Imp (A)"             = panel_row$imp_a,
      "Max System Voltage (V)" = panel_row$max_system_voltage_v,
      "Max Series Fuse (A)"    = panel_row$max_series_fuse_a,
      "Temp. Coeff. Pmax (%/C)" = panel_row$temperature_coefficient_pmax,
      "Efficiency (%)"      = panel_row$efficiency_percent
    ))
  })

  # =========================================================================
  # PAGE 11 - SMART RECOMMENDATION
  # =========================================================================
  observeEvent(input$btn_view_recommendation, {
    req(solar_results_rv(), arrangement_rv(), building_summary_rv(), selected_panel_id())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    rec <- generate_recommendation(
      solar_results = solar_results_rv(),
      arrangement = arrangement_rv(),
      building_summary = building_summary_rv(),
      panel_row = panel_row,
      thresholds = RECOMMENDATION_THRESHOLDS,
      obstacle_count = nrow(obstacles_rv())
    )
    recommendation_rv(rec)
    go_to_page("page_electrical_info", "page_recommendation")
  })

  output$recommendation_output <- renderUI({
    req(recommendation_rv())
    rec <- recommendation_rv()
    div(
      div(class = paste("fit-badge", tolower(gsub(" ", "-", rec$fit_level))), rec$fit_level),
      p(class = "recommendation-text", rec$recommendation_text)
    )
  })

  # =========================================================================
  # PAGE 12 - FINAL DASHBOARD
  # =========================================================================
  observeEvent(input$btn_view_dashboard, {
    go_to_page("page_recommendation", "page_dashboard")
  })

  output$dashboard_building_metrics <- renderUI({
    req(building_summary_rv())
    s <- building_summary_rv()
    card(card_header("Building Metrics"), make_stat_cards(list(
      "Building Name" = input$building_name,
      "Length (m)" = input$building_length,
      "Width (m)"  = input$building_width,
      "Floors"     = input$number_of_floors,
      "Building Area (m^2)" = round(s$building_area, 2),
      "Total Floor Area (m^2)" = round(s$total_floor_area, 2),
      "Roof Type"  = input$roof_type
    )))
  })

  output$dashboard_rooftop_metrics <- renderUI({
    req(building_summary_rv())
    s <- building_summary_rv()
    card(card_header("Rooftop Metrics"), make_stat_cards(list(
      "Rooftop Length (m)" = input$rooftop_length,
      "Rooftop Width (m)"  = input$rooftop_width,
      "Rooftop Area (m^2)" = round(s$rooftop_area, 2),
      "Available Solar %"  = input$solar_percentage,
      "Obstacle Area (m^2)" = round(s$obstacle_area, 2),
      "Maintenance Area (m^2)" = round(s$maintenance_area, 2),
      "Safety Area (m^2)"  = round(s$safety_area, 2),
      "Final Usable Area (m^2)" = round(s$final_usable_area, 2)
    )))
  })

  output$dashboard_panel_metrics <- renderUI({
    req(selected_panel_id(), arrangement_rv())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    a <- arrangement_rv()
    card(card_header("Solar Panel Metrics"), make_stat_cards(list(
      "Manufacturer" = panel_row$manufacturer,
      "Model"        = panel_row$model,
      "Technology"   = panel_row$technology,
      "Rated Power (W)" = panel_row$power_w,
      "Dimensions (mm)" = paste(panel_row$length_mm, "x", panel_row$width_mm),
      "Efficiency (%)"  = panel_row$efficiency_percent,
      "Weight (kg)"     = panel_row$weight_kg,
      "Number of Panels" = a$total_panels,
      "Orientation"     = a$orientation,
      "Rows"            = a$rows,
      "Columns"         = a$columns
    )))
  })

  output$dashboard_capacity_banner <- renderUI({
    req(solar_results_rv())
    div(class = "capacity-banner",
        paste0("Installed Capacity = ", round(solar_results_rv()$total_capacity_kw, 2), " kW"))
  })

  output$dashboard_electrical_metrics <- renderUI({
    req(selected_panel_id())
    panel_row <- get_panel_by_id(panels_data, selected_panel_id())
    card(card_header("Electrical Metrics"), make_stat_cards(list(
      "Voc (V)" = panel_row$voc_v, "Isc (A)" = panel_row$isc_a,
      "Vmp (V)" = panel_row$vmp_v, "Imp (A)" = panel_row$imp_a,
      "Max System Voltage (V)" = panel_row$max_system_voltage_v,
      "Max Fuse (A)" = panel_row$max_series_fuse_a,
      "Efficiency (%)" = panel_row$efficiency_percent
    )))
  })

  output$dashboard_recommendation <- renderUI({
    req(recommendation_rv())
    rec <- recommendation_rv()
    card(card_header("Smart Recommendation"),
      div(class = paste("fit-badge", tolower(gsub(" ", "-", rec$fit_level))), rec$fit_level),
      p(rec$recommendation_text)
    )
  })

  output$dashboard_utilisation_chart <- renderPlot({
    req(solar_results_rv(), building_summary_rv())
    s <- building_summary_rv()
    r <- solar_results_rv()
    chart_data <- data.frame(
      category = c("Panel Area", "Obstacle Area", "Maintenance Area", "Remaining Area"),
      area_m2  = c(r$total_panel_area, s$obstacle_area, s$maintenance_area, r$remaining_area)
    )
    ggplot(chart_data, aes(x = category, y = area_m2, fill = category)) +
      geom_col() +
      labs(title = "Rooftop Area Utilisation Breakdown", x = NULL, y = "Area (m^2)") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
  })

  output$dashboard_rooftop_plot <- renderPlot({
    req(arrangement_rv())
    a <- arrangement_rv()
    draw_rooftop_solar_diagram(
      rooftop_length = input$rooftop_length,
      rooftop_width  = input$rooftop_width,
      panel_positions = a$panel_positions,
      obstacles_table = obstacles_rv(),
      orientation = a$orientation
    )
  })
}
