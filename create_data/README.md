# Creation of UO and KDIGO stages tables

The code above is used to create hourly-adjusted UO and KDIGO staging tables for each ICU stay in the MIMIC-IV database. These tables are meant to provide a reliable platform for future research to anyone who wishes to use them. To achieve this objective, it is necessary to run several SQL queries in a particular order. Additionally, we have included a coded workflow in R that can automatically run these queries. 

## Instructions

**We provided a workflow to run all the queries in R** which require [R and Rstudio](https://posit.co/download/rstudio-desktop/).

Steps:
1. Clone the repo to your local machine
2. Open the `create_data/R workflow/R workflow.Rproj` project
3. In the R session, the `code.R` file should open automatically (if not - open it)
4. Run the commands one-by-one (with <kbd>⌘ Cmd</kbd> + <kbd>⏎ Return</kbd> 
or <kbd>Ctrl</kbd> + <kbd>⏎ Enter</kbd>)
    - Pay attention to the instructions in the comments
6. You will be asked to log in to your Google account and state the associated billing account/project name

**NOTE:** Alternativly, all the queries above can be run manually at the BigQuery console consecutively.


## Structure of the resultant tables

### `mimic_uo_and_aki.c_hourly_uo` table:
| Field name                      | Type     | Description                                                    |
| ------------------------------- | -------- | -------------------------------------------------------------- |
| STAY_ID                         | INTEGER  | ICU stay ID                                                    |
| T_PLUS                          | INTEGER  | Index hour in ICU stay                                         |
| TIME_INTERVAL_STARTS            | DATETIME | Date and time for index hour onset                             |
| TIME_INTERVAL_FINISH            | DATETIME | Date and time for index hour end                               |
| HOURLY_VALID_WEIGHTED_MEAN_RATE | FLOAT    | Valid total hourly urine output                                |
| SIMPLE_SUM                      | FLOAT    | Simple raw urine output hourly summation (for testing purposes) |
| WEIGHT_ADMIT                    | FLOAT    | Patient weight at admission                                    |
