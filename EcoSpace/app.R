# =============================================================================
# FILE: app.R
# PURPOSE: The single entry point RStudio/Shiny looks for. It loads every
#          other file in the right order and starts the app with
#          shinyApp(ui, server).
#
# LOAD ORDER MATTERS
# ---------------------------------------------------------------------------
# config.R must load first (it defines constants used by ui.R and the
# calculation files). The calculation files must load before server.R uses
# their functions. ui.R needs config.R's constants when it builds dropdowns.
# =============================================================================

source("R/config.R")
source("R/data_loader.R")
source("R/validation.R")
source("R/building_calculations.R")
source("R/solar_calculations.R")
source("R/panel_arrangement.R")
source("R/recommendation_engine.R")
source("R/visualization.R")
source("R/ui.R")
source("R/server.R")

shinyApp(ui = app_ui, server = server)
