# =============================================================================
# FILE: data_loader.R
# PURPOSE: Load the real solar-panel database from data/solar_panels.csv
#          and hand back a clean data frame that the rest of the app can use.
#
# WHAT THIS FILE DEMONSTRATES (R practical concept)
# ---------------------------------------------------------------------------
# - Reading a CSV file with readr::read_csv()
# - Basic data cleaning with dplyr
#
# HOW THIS FILE COMMUNICATES WITH OTHER FILES
# ---------------------------------------------------------------------------
# - server.R calls load_solar_panel_data() ONCE when the app starts, and
#   stores the result in a reactiveVal so every page can read it.
# - ui.R uses the same data (passed in from server.R) to build the searchable
#   panel table and the filter dropdowns.
# =============================================================================

library(readr)
library(dplyr)

#' Function name: load_solar_panel_data
#' Purpose:       Read the real-world solar panel CSV from disk.
#' Input:         csv_path - character string, path to the CSV file.
#' Processing:    Reads the file with readr::read_csv(), makes sure numeric
#'                columns are actually numeric (CSV sometimes stores "NA" as
#'                text), and returns the cleaned table.
#' Output:        A data frame (tibble) with one row per solar panel.
load_solar_panel_data <- function(csv_path = "data/solar_panels.csv") {

  panels <- readr::read_csv(csv_path, show_col_types = FALSE)

  # Force the numeric columns to be numeric. Some cells contain "NA" as text
  # because that specification was not published for that model - readr
  # already understands "NA" as a missing value, but we do this explicitly
  # so it is clear in the code which columns are treated as numbers.
  numeric_columns <- c(
    "power_w", "length_mm", "width_mm", "thickness_mm", "weight_kg",
    "efficiency_percent", "voc_v", "isc_a", "vmp_v", "imp_a",
    "max_system_voltage_v", "max_series_fuse_a",
    "temperature_coefficient_pmax", "warranty_years"
  )

  for (column_name in numeric_columns) {
    panels[[column_name]] <- as.numeric(panels[[column_name]])
  }

  return(panels)
}

#' Function name: get_panel_by_id
#' Purpose:       Retrieve one specific panel's full row of data.
#' Input:         panels_table - the full data frame from load_solar_panel_data()
#'                selected_id  - the panel_id string, e.g. "P003"
#' Processing:    Filters the table down to the matching row.
#' Output:        A one-row data frame for the selected panel.
get_panel_by_id <- function(panels_table, selected_id) {
  dplyr::filter(panels_table, panel_id == selected_id)
}
