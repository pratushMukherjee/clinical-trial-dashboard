# Functional Requirements

## Purpose
Cloud-based clinical data review dashboard supporting streamlined data quality monitoring, AI-powered query refinement, and automated validation for MedTech surgical clinical trials.

## Functional Requirements

### FR-01: Data Loading and Display
- Load CDISC SDTM datasets (DM, AE, LB, VS, DV) from CSV files
- Validate required columns per domain
- Display data in interactive, filterable tables
- Show KPI value boxes (total subjects, sites, duration, completion rate)

### FR-02: Data Quality Radar
- Run automated quality checks across all loaded domains
- Check categories: missing data, outliers, date logic, cross-form consistency, SDTM compliance
- Display radar chart with quality dimension scores (0-100)
- Detailed findings table with severity, description, affected subjects
- Filter by domain, check type, severity
- Export findings as CSV report

### FR-03: AI Query Refiner
- Accept informal/natural language queries about clinical data
- Refine into precise CDISC-compliant queries
- Return: refined query, relevant domains/variables, R code, assumptions
- Support OpenAI GPT-4 and demo mode (keyword matching)

### FR-04: Protocol Deviation Classifier
- Classify deviation descriptions into 7 TransCelerate categories
- Display predicted category, confidence score, probability distribution
- Support batch classification of entire DV dataset
- Show confusion matrix and accuracy metrics
- R-native fallback when Python unavailable

### FR-05: Data Chat
- Natural language interface for data exploration
- Return data tables, charts, or text based on query type
- Quick-action buttons for common queries
- Show generated R code for transparency

### FR-06: Automated Checks
- Pre-built edit checks with pass/fail status
- Dataset comparison (upload second CSV, show differences)
- Track violations per check with affected record counts

## Non-Functional Requirements
- Dashboard must work in Demo Mode without API keys
- All modules load within 5 seconds
- Tests pass with zero failures
- Deployable to shinyapps.io
