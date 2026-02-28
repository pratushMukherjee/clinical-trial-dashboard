# System Architecture

## Architecture Overview

The dashboard follows a **modular Shiny architecture** without the golem framework. This choice keeps the codebase accessible for review while achieving separation of concerns.

```
                    +------------------+
                    |     app.R        |  Entry point
                    +------------------+
                           |
                    +------------------+
                    |    global.R      |  Package loading, data loading, config
                    +------------------+
                           |
              +------------+------------+
              |                         |
       +------+------+          +------+------+
       |    ui.R     |          |  server.R   |
       | (dashboard  |          | (module     |
       |  layout)    |          |  orchestr.) |
       +------+------+          +------+------+
              |                         |
    +---------+---------+     +---------+---------+
    |   Module UIs      |     |  Module Servers   |
    | (mod_*_ui.R)      |     | (mod_*_server.R)  |
    +-------------------+     +---------+---------+
                                        |
                              +---------+---------+
                              |   Utility Files   |
                              | (utils_*.R)       |
                              | Pure functions,   |
                              | testable logic    |
                              +-------------------+
                                        |
                              +---------+---------+
                              |   Python ML       |
                              | (via reticulate)  |
                              +-------------------+
```

## Key Design Decisions

### 1. Modular Shiny without golem
Chose a flat module structure over the golem framework because it keeps the codebase accessible for portfolio review while still achieving separation of concerns. Each module has its own UI and server file.

### 2. Utility functions as the backbone
All business logic lives in `utils_*.R` files as pure, testable functions. Module server files are thin orchestrators that call these utilities. This directly mirrors the job requirement for "standardized functions and reusable components."

### 3. Demo mode as first-class citizen
Every AI feature works without API keys. A dashboard that fails when a third-party API is unavailable is not production-ready.

### 4. Logistic Regression over deep learning
With ~100 training examples, TF-IDF + Logistic Regression outperforms deep learning while being interpretable, fast, and deployment-friendly.

### 5. Intentional data quality issues
The generated data contains deliberate errors (missing values, date inversions, outliers). This makes the Data Quality Radar demo compelling.

### 6. CDISC SDTM compliance
Every variable name, controlled terminology value, and domain structure follows the SDTM Implementation Guide v3.3.

## Data Flow

1. `global.R` loads all SDTM CSVs via `utils_data_loading.R`
2. Datasets stored in `reactiveValues` shared across all modules
3. Quality checks run via `utils_data_quality.R` (pure functions)
4. AI features call `utils_ai_api.R` which routes to API or demo mode
5. ML classifier calls Python via reticulate or falls back to R keywords

## Module Dependency Map

| Module | Depends On |
|--------|-----------|
| Data Overview | utils_data_loading, utils_helpers |
| Data Quality Radar | utils_data_quality, utils_sdtm_checks, utils_visualization |
| Query Refiner | utils_ai_api |
| Protocol Deviation Classifier | python/deviation_classifier (or R fallback) |
| Data Chat | utils_ai_api |
| Automated Checks | utils_sdtm_checks |
