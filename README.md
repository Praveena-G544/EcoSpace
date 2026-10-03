# EcoSpace — Smart Building & Solar Panel Planner

A multi-page R Shiny application for planning a rooftop solar installation:
building/rooftop analysis, real-world solar panel selection, obstacle-aware
panel arrangement, parametric visualization, capacity calculation, and a
rule-based recommendation engine.

> **Disclaimer:** This application provides an educational rooftop solar
> planning estimate based on user-provided dimensions, manufacturer
> specifications, and simplified geometric assumptions. Actual solar
> installations require professional structural, electrical, shading,
> orientation, safety, and local-code site assessments.

---

## 1. Project structure

```
EcoSpace/
├── app.R                        # Entry point - loads everything, starts the app
├── data/
│   └── solar_panels.csv         # Real panel database (see section 3)
├── R/
│   ├── config.R                 # All assumptions/defaults, clearly labeled
│   ├── data_loader.R             # Reads the CSV
│   ├── validation.R              # Input validation + friendly error messages
│   ├── building_calculations.R   # Building/rooftop geometry (area, perimeter, diagonal...)
│   ├── solar_calculations.R      # Panel-based electrical/area math
│   ├── panel_arrangement.R       # The obstacle-aware placement algorithm
│   ├── recommendation_engine.R   # Rule-based "smart recommendation"
│   ├── visualization.R           # ggplot2 parametric diagrams
│   ├── ui.R                      # All 12 pages (frontend)
│   └── server.R                  # Navigation, reactive values, calculations (backend)
├── www/
│   └── styles.css                # All CSS styling
└── README.md
```

Every file has a header comment block explaining its purpose, and every
function has a `Function name / Purpose / Input / Processing / Output`
comment directly above it — read these first when preparing your viva.

---

## 2. How to run it

1. Install **R** (https://cran.r-project.org) and **RStudio Desktop**
   (https://posit.co/download/rstudio-desktop/).
2. Open RStudio and install the required packages (run once, in the Console):
   ```r
   install.packages(c("shiny", "bslib", "shinyjs", "DT",
                       "dplyr", "readr", "ggplot2"))
   ```
3. Download/copy this whole `EcoSpace/` folder onto your computer, keeping
   the folder structure exactly as shown above.
4. In RStudio: **File → Open Project/Directory** and open the `EcoSpace`
   folder, OR just open `app.R`.
5. Click **Run App** at the top of the editor (or run `shiny::runApp()` in
   the console while your working directory is the `EcoSpace` folder).
6. The app opens in a browser/viewer window starting on the Home page.

---

## 3. About the solar panel database

`data/solar_panels.csv` contains **5 real, currently-sold solar panel
models**, each pulled from an official manufacturer datasheet (LONGi,
JinkoSolar, Trina Solar, Canadian Solar, Waaree Energies). Every row's
`source` and `datasheet_url` column tells you exactly where the numbers came
from — nothing is invented.

This is a **starter set**. The original assignment brief asks for 15–30
panels; to reach that honestly, add more rows yourself using the *same
process*:

1. Find the manufacturer's official datasheet PDF (search
   `"<manufacturer> <model> datasheet site:<manufacturer domain>"`).
2. Copy only numbers that are printed on that datasheet.
3. Leave a cell blank/`NA` if the datasheet doesn't publish that spec —
   never guess a number to fill a gap.
4. Fill in `source` with where the number came from, and `datasheet_url`
   with the direct PDF link.

This keeps the "real-world data, not fabricated" requirement intact no
matter how many panels you eventually add.

---

## 4. How the panel arrangement algorithm works 

1. Shrink the rooftop rectangle inward by the **edge clearance** → the
   "placement zone".
2. Reserve a **maintenance walkway** strip inside that zone.
3. Expand every obstacle rectangle outward by the **safety clearance** →
   its "exclusion zone".
4. Pick the panel's footprint on the roof based on orientation (Portrait =
   long side vertical, Landscape = long side horizontal).
5. Lay out a grid of candidate panel positions across the placement zone,
   spaced by the **panel gap**.
6. For every candidate position, test whether the panel rectangle overlaps
   *any* obstacle's exclusion zone (rectangle-vs-rectangle collision test).
   Skip it if it overlaps; otherwise count it as installed.
7. Do steps 4–6 for **both** Portrait and Landscape, and keep whichever
   orientation fits more panels (unless the user forced one orientation).

This means a water tank in the middle of the roof genuinely blocks the
panels that would sit on top of it — the app does not just subtract its
area from a total.

---

## 5. Test cases

| # | Scenario | Input | Expected result | What it tests |
|---|----------|-------|------------------|----------------|
| 1 | Small rooftop | 6 m × 4 m rooftop, LONGi 425W panel | Very few panels (maybe 2–4), low capacity | Basic placement on a tight roof |
| 2 | Large rooftop | 40 m × 25 m rooftop, no obstacles | Large panel count, high capacity, "Excellent fit" likely | Grid placement at scale |
| 3 | Roof with a water tank | 20 m × 10 m rooftop, Water Tank at (8,4), 3×3 m | Panels are missing specifically over the tank's footprint, not just fewer overall | Obstacle collision detection |
| 4 | Multiple obstacles | Water Tank + Staircase + AC Unit at different positions | All three zones stay empty in the visualization | Multiple simultaneous exclusion zones |
| 5 | Panel too big to fit | Very small rooftop (e.g. 2 m × 2 m) with a large panel (Jinko 2278mm) | "No valid panel arrangement was found" message, 0 panels | Zero-panel edge case handling |

---

## 6. Publishing this project to GitHub

See the step-by-step instructions given alongside this project (or your
chat conversation) for the exact `git` commands to initialize a repository,
commit these files, and push them to GitHub.

---

## 7. Live Application
[View the Live Shiny App]( https://praveena010203.shinyapps.io/EcoSpace/)



