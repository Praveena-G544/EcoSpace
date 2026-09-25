# =============================================================================
# FILE: config.R
# PURPOSE: Central place for every "assumption" number used in this app.
#
# WHY THIS FILE EXISTS
# ---------------------------------------------------------------------------
# Anything in this file is a PROJECT ASSUMPTION, not a manufacturer spec and
# not something the user typed in. Keeping these numbers in one place means:
#   1. In your viva you can point to this ONE file and say "these are the
#      default values I assumed, and here is why".
#   2. If a professor asks "why 0.5m edge clearance?", you change ONE number
#      here instead of hunting through the whole app.
#
# NONE of these numbers are official installation standards. They are
# reasonable, commonly-seen defaults chosen for a student project.
# =============================================================================

# ---- Panel spacing defaults (metres) --------------------------------------
DEFAULT_PANEL_GAP_M          <- 0.02  # small gap between adjacent panels
DEFAULT_EDGE_CLEARANCE_M     <- 0.5   # empty margin kept from every roof edge
DEFAULT_MAINTENANCE_WIDTH_M  <- 0.6   # width of a walkway left for maintenance
DEFAULT_SAFETY_CLEARANCE_M   <- 0.3   # extra buffer kept around obstacles

# ---- Rooftop usability defaults --------------------------------------------
DEFAULT_SOLAR_PERCENTAGE     <- 70    # % of rooftop assumed usable for solar

# ---- Recommendation engine thresholds --------------------------------------
# These decide which "fit level" the app reports, based on how much of the
# usable rooftop area actually ends up covered by panels (utilisation %).
RECOMMENDATION_THRESHOLDS <- list(
  excellent = 70,   # utilisation >= 70%  -> "Excellent fit"
  good      = 50,   # utilisation >= 50%  -> "Good fit"
  moderate  = 30,   # utilisation >= 30%  -> "Moderate fit"
  limited   = 10    # utilisation >= 10%  -> "Limited fit"
                    # utilisation <  10%  -> "Not suitable"
)

# ---- Dropdown choices used throughout the UI --------------------------------
OBSTACLE_TYPES <- c(
  "Water Tank", "Staircase", "AC Unit", "Ventilation Unit",
  "Existing Structure", "Solar Water Heater", "Other"
)

ROOF_TYPES <- c("Flat", "Sloped", "Gable", "Hip", "Other")

ORIENTATION_CHOICES <- c("Portrait", "Landscape", "Automatic (compare both)")

# ---- Application-wide disclaimer text --------------------------------------
APP_DISCLAIMER <- paste(
  "This application provides an educational rooftop solar planning estimate",
  "based on user-provided dimensions, manufacturer specifications, and",
  "simplified geometric assumptions. Actual solar installations require",
  "professional structural, electrical, shading, orientation, safety, and",
  "local-code site assessments."
)
