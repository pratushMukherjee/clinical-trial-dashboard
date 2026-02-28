# Clinical Trial Data Quality & AI Review Dashboard

[![R](https://img.shields.io/badge/R-4.3+-blue.svg)](https://cran.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-Dashboard-green.svg)](https://shiny.posit.co/)
[![Python](https://img.shields.io/badge/Python-3.9+-yellow.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> An RShiny dashboard for automated clinical trial data review, quality monitoring, and AI-powered data exploration -- built with CDISC SDTM-compliant synthetic data for a medical device surgical trial.

## Overview

This dashboard demonstrates end-to-end clinical data review capabilities for a simulated MedTech surgical device trial (SURG-2024-001), including:

- **Data Overview** -- Interactive exploration of SDTM domains with KPI value boxes, treatment arm distribution, age histograms, and demographics breakdowns
- **Data Quality Radar** -- Automated scans for missing data, outliers, cross-form inconsistencies, and date logic errors, displayed as a radar chart scoring 5 quality dimensions
- **Query Refiner** -- AI-powered refinement of informal data queries into precise, CDISC-compliant clinical data queries with R code snippets
- **Protocol Deviation Classifier** -- ML-based text classification of protocol deviations by category and severity using TF-IDF + Logistic Regression
- **Data Chat** -- Natural language interface for exploring clinical trial data with automatic table/chart generation
- **Automated Checks** -- Dataset comparison, edit check validation, and programmatic data review with pass/fail tracking

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Frontend | R Shiny + shinydashboard |
| Visualizations | plotly, ggplot2 |
| Data Tables | DT (DataTables) |
| Data Manipulation | tidyverse (dplyr, tidyr, readr, lubridate) |
| ML Model | Python scikit-learn (TF-IDF + Logistic Regression) |
| R-Python Bridge | reticulate |
| AI Features | OpenAI GPT-4 API (via httr2) with demo fallback |
| Data Standard | CDISC SDTM v3.3 |
| Testing | testthat (50 tests) |

## Quick Start

```bash
# Clone the repository
git clone https://github.com/pratushMukherjee/clinical-trial-dashboard.git
cd clinical-trial-dashboard

# Install R dependencies
Rscript -e "install.packages(c('shiny','shinydashboard','plotly','DT','dplyr','tidyr','readr','lubridate','stringr','httr2','jsonlite','ggplot2','scales','reticulate','testthat'), repos='https://cloud.r-project.org')"

# (Optional) Set up Python for ML classifier
pip install -r python/requirements.txt
python python/train_classifier.py

# (Optional) Enable live AI features
cp .Renviron.example .Renviron
# Edit .Renviron and add your OpenAI API key

# Launch the dashboard
Rscript -e "shiny::runApp()"
```

The dashboard opens at `http://localhost:PORT` and works immediately in **Demo Mode** -- no API keys or Python setup required.

## Project Structure

```
clinical-trial-dashboard/
|-- app.R                    # Entry point
|-- global.R                 # Library loads, source helpers, load data
|-- ui.R                     # shinydashboard layout with 6 tabs
|-- server.R                 # Calls all module servers
|
|-- R/                       # Modules + utilities (12 module files + 6 utility files)
|   |-- mod_data_overview_*        # Data Overview tab
|   |-- mod_data_quality_radar_*   # Data Quality Radar tab
|   |-- mod_query_refiner_*        # AI Query Refiner tab
|   |-- mod_deviation_classifier_* # ML Classifier tab
|   |-- mod_data_chat_*            # Data Chat tab
|   |-- mod_automated_checks_*     # Automated Checks tab
|   |-- utils_data_loading.R       # SDTM data loader with validation
|   |-- utils_data_quality.R       # Quality check functions
|   |-- utils_sdtm_checks.R        # CDISC compliance + edit checks
|   |-- utils_ai_api.R             # OpenAI API wrapper + demo mode
|   |-- utils_visualization.R      # Reusable plotly chart builders
|   |-- utils_helpers.R            # Date parsing, formatting
|
|-- data/                    # Synthetic CDISC SDTM datasets
|-- data-raw/                # Data generation scripts
|-- python/                  # ML model training and inference
|-- models/                  # Trained scikit-learn models
|-- tests/testthat/          # 50 unit tests
|-- docs/                    # Documentation
|-- www/                     # CSS and static assets
```

## Data

This project uses **synthetic clinical trial data** generated to comply with CDISC SDTM v3.3 standards. The simulated study ("SURG-2024-001") represents a medical device surgical trial with:

| Domain | Description | Records | Details |
|--------|-------------|---------|---------|
| DM | Demographics | 200 | 3 treatment arms, 5 sites, 4 countries |
| AE | Adverse Events | 459 | Surgical-relevant terms, severity, causality |
| LB | Laboratory Results | 6,732 | 6 lab tests across 6 visits |
| VS | Vital Signs | 5,740 | 5 vital sign tests across 6 visits |
| DV | Protocol Deviations | 107 | 7 TransCelerate categories |

**No real patient data is used.** Intentional data quality issues are embedded for testing (missing values, date inversions, outliers, cross-field mismatches).

## Features

### Data Overview
Explore SDTM domains with interactive data tables, KPI value boxes (total subjects, sites, study duration, completion rate), and plotly visualizations of treatment arm distribution, age distribution, and demographics breakdowns.

### Data Quality Radar
The centerpiece module. Runs automated quality checks across all domains and displays results as a radar chart scoring 5 dimensions (Completeness, Consistency, Validity, Timeliness, Accuracy). Detailed findings table with severity-coded rows, filterable by domain, check type, and severity. Export findings as CSV.

### AI Query Refiner
Transform informal questions ("patients with bad liver numbers") into precise, CDISC-compliant queries with:
- Refined query using proper SDTM terminology
- Relevant domains and variables identified
- Executable R/dplyr code snippet
- Documented assumptions

Works in Demo Mode with 10+ keyword-matched patterns, or live with OpenAI GPT-4.

### Protocol Deviation Classifier
ML-powered text classification using TF-IDF + Logistic Regression (scikit-learn):
- Single or batch classification of deviation descriptions
- Probability distribution chart across 7 categories
- Confusion matrix heatmap for batch results
- 90.6% cross-validation accuracy
- R-native keyword fallback when Python is unavailable

### Data Chat
Natural language interface for data exploration:
- Chat-style UI with quick-action buttons
- Returns interactive data tables or plotly charts
- Generated R code shown for transparency
- 9+ pre-programmed queries in Demo Mode

### Automated Checks
- **Edit Checks**: 6 pre-built clinical validation rules with pass/fail status
- **Dataset Comparison**: Upload a second CSV to diff records (new, deleted, modified)

## Testing

```bash
Rscript -e "library(testthat); test_dir('tests/testthat')"
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 50 ]
```

Tests cover: data loading validation, quality check functions (missing data, outliers, date logic, cross-form consistency), AI API demo mode, and query refinement.

## Documentation

- [Functional Requirements](docs/requirements.md)
- [System Architecture](docs/architecture.md)
- [SDTM Data Specification](docs/sdtm_data_spec.md)

## Demonstrated Competencies

This project demonstrates proficiency in:
- **Clinical data review and quality management** -- automated quality checks, edit validation, SDTM compliance
- **CDISC SDTM data standards** -- correct variable naming, controlled terminology, domain structure
- **RShiny dashboard development** -- modular architecture with reusable components
- **AI/ML applications in clinical data** -- GPT-4 integration, text classification, natural language data exploration
- **R + Python integration** -- reticulate bridge with graceful fallback
- **Automated data validation** -- outlier detection, missing data analysis, cross-form consistency
- **Testing and documentation** -- 50 unit tests, comprehensive docs

## License

MIT
