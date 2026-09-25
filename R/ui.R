# =============================================================================
# FILE: ui.R
# PURPOSE: Everything the user SEES. Builds all 12 pages of the app as
#          separate <div> blocks inside one Shiny UI. Only one page's div is
#          visible at a time - server.R shows/hides them using shinyjs
#          when the user clicks a navigation button. This gives us a real
#          "multi-page" feel without needing a more advanced routing system,
#          which keeps things beginner-friendly.
#
# HOW NAVIGATION WORKS (explain this in your viva)
# ---------------------------------------------------------------------------
# Every page is wrapped in a div() with a unique id, e.g. "page_home",
# "page_building_info", etc. All pages except the first are given the CSS
# style "display: none" so they start out hidden. In server.R, every "Next"
# or "Back" button has an observeEvent() that calls shinyjs::hide() on the
# current page and shinyjs::show() on the target page. This is what creates
# the feeling of moving between separate pages.
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - config.R supplies the dropdown choices (ROOF_TYPES, OBSTACLE_TYPES, etc.)
# - server.R reads every input$... defined here, runs calculations, and
#   writes results back into output$... placeholders defined here.
# - www/styles.css is loaded to style all of this.
# =============================================================================

library(shiny)
library(bslib)
library(shinyjs)
library(DT)

# ---------------------------------------------------------------------------
# Small helper: a consistent "step progress bar" shown at the top of every
# page except Home and the Dashboard. Takes the current step number (1-7)
# and prints all 7 steps, bolding the current one.
# ---------------------------------------------------------------------------
progress_bar_ui <- function(current_step) {
  steps <- c("1 Building", "2 Rooftop", "3 Solar Panel", "4 Installation",
             "5 Arrangement", "6 Visualization", "7 Results")
  spans <- lapply(seq_along(steps), function(i) {
    css_class <- if (i == current_step) "step-current" else "step-item"
    tags$span(class = css_class, steps[i])
  })
  # Join the step labels with an arrow between each one.
  joined <- list()
  for (i in seq_along(spans)) {
    joined <- append(joined, list(spans[[i]]))
    if (i < length(spans)) joined <- append(joined, list(tags$span(" \u2192 ", class = "step-arrow")))
  }
  div(class = "progress-bar-row", joined)
}

# =============================================================================
# PAGE 1 - HOME / LANDING PAGE
# =============================================================================
page_home_ui <- function() {
  div(id = "page_home", class = "app-page",
    div(class = "landing-hero",
      h1("EcoSpace", class = "landing-title"),
      h3("Smart Building & Solar Panel Planner", class = "landing-subtitle"),
      p(class = "landing-description",
        "Analyze your building and rooftop, select a real-world solar panel, ",
        "plan its installation, visualize the rooftop arrangement, and understand ",
        "the resulting solar capacity and electrical characteristics."
      ),
      actionButton("btn_get_started", "Get Started", class = "btn-primary btn-lg btn-hero")
    )
  )
}

# =============================================================================
# PAGE 2 - BUILDING INFORMATION
# =============================================================================
page_building_info_ui <- function() {
  div(id = "page_building_info", class = "app-page", style = "display:none;",
    progress_bar_ui(1),
    h2("Step 1 - Smart Building Planner"),

    card(
      card_header("Building Information"),
      layout_column_wrap(
        width = 1/2,
        textInput("building_name", "Building Name", value = "My Building"),
        selectInput("roof_type", "Roof Type", choices = ROOF_TYPES),
        numericInput("building_length", "Building Length (m)", value = 20, min = 0.1),
        numericInput("building_width", "Building Width (m)", value = 10, min = 0.1),
        numericInput("number_of_floors", "Number of Floors", value = 2, min = 1, step = 1),
        numericInput("floor_height", "Floor Height (m)", value = 3, min = 0.1),
        selectInput("building_orientation", "Building Orientation",
                    choices = c("North", "South", "East", "West",
                                "North-East", "North-West", "South-East", "South-West"))
      )
    ),

    card(
      card_header("Rooftop Information"),
      layout_column_wrap(
        width = 1/2,
        numericInput("rooftop_length", "Rooftop Length (m)", value = 20, min = 0.1),
        numericInput("rooftop_width", "Rooftop Width (m)", value = 10, min = 0.1),
        numericInput("solar_percentage", "Percentage of Roof Available for Solar (%)",
                     value = DEFAULT_SOLAR_PERCENTAGE, min = 0, max = 100),
        numericInput("safety_clearance_input", "Safety Clearance (m) [Project assumption/default]",
                     value = DEFAULT_SAFETY_CLEARANCE_M, min = 0),
        numericInput("maintenance_area_input", "Required Maintenance Area (m^2)",
                     value = 5, min = 0)
      )
    ),

    card(
      card_header("Rooftop Obstacles"),
      p("Add any equipment or structures that occupy space on the rooftop."),
      fluidRow(
        column(3, selectInput("new_obstacle_type", "Type", choices = OBSTACLE_TYPES)),
        column(2, numericInput("new_obstacle_length", "Length (m)", value = 2, min = 0.1)),
        column(2, numericInput("new_obstacle_width", "Width (m)", value = 2, min = 0.1)),
        column(2, numericInput("new_obstacle_x", "X Position (m)", value = 0, min = 0)),
        column(2, numericInput("new_obstacle_y", "Y Position (m)", value = 0, min = 0)),
        column(1, actionButton("btn_add_obstacle", "Add", class = "btn-secondary"))
      ),
      DTOutput("obstacles_table_view"),
      actionButton("btn_remove_obstacle", "Remove Selected Obstacle", class = "btn-outline-danger mt-2")
    ),

    div(class = "nav-row",
      actionButton("btn_home_from_building_info", "Back", class = "btn-secondary"),
      actionButton("btn_analyze_building", "Analyze Building", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 3 - BUILDING ANALYSIS
# =============================================================================
page_building_analysis_ui <- function() {
  div(id = "page_building_analysis", class = "app-page", style = "display:none;",
    progress_bar_ui(1),
    h2("Building Analysis"),
    uiOutput("building_analysis_cards"),
    div(class = "nav-row",
      actionButton("btn_back_to_building_info", "Back", class = "btn-secondary"),
      actionButton("btn_generate_building_viz", "Generate Building Visualization", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 4 - BUILDING VISUALIZATION
# =============================================================================
page_building_viz_ui <- function() {
  div(id = "page_building_viz", class = "app-page", style = "display:none;",
    progress_bar_ui(1),
    h2("Your Smart Building"),
    plotOutput("building_diagram_plot", height = "450px"),
    uiOutput("building_summary_cards"),
    div(class = "nav-row",
      actionButton("btn_back_to_building_analysis", "Back", class = "btn-secondary"),
      actionButton("btn_continue_to_solar", "Continue to Solar Planning", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 5 - SOLAR PANEL SELECTION
# =============================================================================
page_panel_selection_ui <- function() {
  div(id = "page_panel_selection", class = "app-page", style = "display:none;",
    progress_bar_ui(3),
    h2("Step 2 - Solar Panel Planning"),
    card(
      card_header("Filter the Real-World Panel Database"),
      fluidRow(
        column(3, selectInput("filter_manufacturer", "Manufacturer", choices = NULL)),
        column(3, selectInput("filter_technology", "Technology", choices = NULL)),
        column(3, numericInput("filter_min_power", "Minimum Power (W)", value = 0, min = 0)),
        column(3, numericInput("filter_min_efficiency", "Minimum Efficiency (%)", value = 0, min = 0))
      )
    ),
    card(
      card_header("Select a Panel"),
      DTOutput("panel_selection_table")
    ),
    uiOutput("selected_panel_details"),
    div(class = "nav-row",
      actionButton("btn_back_to_building_viz", "Back", class = "btn-secondary"),
      actionButton("btn_continue_to_installation", "Continue to Installation", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 6 - INSTALLATION REQUIREMENTS
# =============================================================================
page_installation_req_ui <- function() {
  div(id = "page_installation_req", class = "app-page", style = "display:none;",
    progress_bar_ui(4),
    h2("Step 3 - Rooftop Installation Requirements"),
    card(
      card_header("Panel Orientation"),
      selectInput("panel_orientation", "Orientation", choices = ORIENTATION_CHOICES,
                  selected = "Automatic (compare both)")
    ),
    card(
      card_header("Panel Spacing [Project assumption/default - not a universal engineering standard]"),
      layout_column_wrap(
        width = 1/2,
        numericInput("panel_gap_input", "Gap Between Panels (m)", value = DEFAULT_PANEL_GAP_M, min = 0, step = 0.01),
        numericInput("edge_clearance_input", "Edge Clearance (m)", value = DEFAULT_EDGE_CLEARANCE_M, min = 0),
        numericInput("maintenance_width_input", "Maintenance Walkway Width (m)", value = DEFAULT_MAINTENANCE_WIDTH_M, min = 0),
        numericInput("safety_clearance_2_input", "Safety Clearance Around Obstacles (m)", value = DEFAULT_SAFETY_CLEARANCE_M, min = 0)
      )
    ),
    card(
      card_header("Rooftop Obstacles (confirm or edit)"),
      DTOutput("obstacles_table_view_2")
    ),
    div(class = "nav-row",
      actionButton("btn_back_to_panel_selection", "Back", class = "btn-secondary"),
      actionButton("btn_calculate_arrangement", "Calculate Arrangement", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 7 - PANEL ARRANGEMENT
# =============================================================================
page_panel_arrangement_ui <- function() {
  div(id = "page_panel_arrangement", class = "app-page", style = "display:none;",
    progress_bar_ui(5),
    h2("Step 4 - Smart Panel Arrangement"),
    uiOutput("arrangement_summary_cards"),
    div(class = "nav-row",
      actionButton("btn_back_to_installation", "Back", class = "btn-secondary"),
      actionButton("btn_view_installation", "View Installation", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 8 - ROOFTOP SOLAR VISUALIZATION
# =============================================================================
page_rooftop_viz_ui <- function() {
  div(id = "page_rooftop_viz", class = "app-page", style = "display:none;",
    progress_bar_ui(6),
    h2("Proposed Solar Installation"),
    plotOutput("rooftop_solar_plot", height = "450px"),
    uiOutput("rooftop_viz_summary"),
    div(class = "nav-row",
      actionButton("btn_back_to_arrangement", "Back", class = "btn-secondary"),
      actionButton("btn_view_results", "View Results", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 9 - SOLAR CALCULATION RESULTS
# =============================================================================
page_solar_results_ui <- function() {
  div(id = "page_solar_results", class = "app-page", style = "display:none;",
    progress_bar_ui(7),
    h2("Solar Installation Results"),
    uiOutput("solar_results_cards"),
    div(class = "nav-row",
      actionButton("btn_back_to_rooftop_viz", "Back", class = "btn-secondary"),
      actionButton("btn_view_electrical", "View Electrical Information", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 10 - ELECTRICAL INFORMATION
# =============================================================================
page_electrical_info_ui <- function() {
  div(id = "page_electrical_info", class = "app-page", style = "display:none;",
    progress_bar_ui(7),
    h2("Electrical Information"),
    uiOutput("electrical_info_cards"),
    p(class = "disclaimer-text",
      "These are the manufacturer's rated electrical characteristics. Any string/series ",
      "calculations shown are simplified educational estimates, not a certified electrical design."
    ),
    div(class = "nav-row",
      actionButton("btn_back_to_solar_results", "Back", class = "btn-secondary"),
      actionButton("btn_view_recommendation", "View Recommendation", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 11 - SMART RECOMMENDATION
# =============================================================================
page_recommendation_ui <- function() {
  div(id = "page_recommendation", class = "app-page", style = "display:none;",
    progress_bar_ui(7),
    h2("Smart Installation Recommendation"),
    uiOutput("recommendation_output"),
    div(class = "nav-row",
      actionButton("btn_back_to_electrical", "Back", class = "btn-secondary"),
      actionButton("btn_view_dashboard", "View Dashboard", class = "btn-primary")
    )
  )
}

# =============================================================================
# PAGE 12 - FINAL DASHBOARD
# =============================================================================
page_dashboard_ui <- function() {
  div(id = "page_dashboard", class = "app-page", style = "display:none;",
    h1("Smart Building & Solar Dashboard"),
    uiOutput("dashboard_building_metrics"),
    uiOutput("dashboard_rooftop_metrics"),
    uiOutput("dashboard_panel_metrics"),
    uiOutput("dashboard_capacity_banner"),
    uiOutput("dashboard_electrical_metrics"),
    uiOutput("dashboard_recommendation"),
    h4("Rooftop Utilisation Chart"),
    plotOutput("dashboard_utilisation_chart", height = "350px"),
    h4("Final Rooftop Visualization"),
    plotOutput("dashboard_rooftop_plot", height = "400px"),
    p(class = "disclaimer-text", APP_DISCLAIMER),
    div(class = "nav-row",
      actionButton("btn_start_new_project", "Start New Project", class = "btn-primary")
    )
  )
}

# =============================================================================
# TOP-LEVEL UI - combines every page into one Shiny UI
# =============================================================================
app_ui <- page_fluid(
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#1d4ed8"),
  useShinyjs(),
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),

  div(class = "app-container",
    page_home_ui(),
    page_building_info_ui(),
    page_building_analysis_ui(),
    page_building_viz_ui(),
    page_panel_selection_ui(),
    page_installation_req_ui(),
    page_panel_arrangement_ui(),
    page_rooftop_viz_ui(),
    page_solar_results_ui(),
    page_electrical_info_ui(),
    page_recommendation_ui(),
    page_dashboard_ui()
  )
)
