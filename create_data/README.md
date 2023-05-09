# Creation of UO and AKI tables

The code above is used to create hourly-adjusted UO tables for each ICU stay in the MIMIC-IV database, as well as to identify the onset and resolution of AKI events. These tables are meant to provide a reliable platform for future research to anyone who wishes to use them. To achieve this objective, it is necessary to run several SQL queries in a particular order. Additionally, we have included a coded workflow in R that can automatically run these queries. 

## Instructions

**We provided a workflow to run all the queries in R** which require [R and Rstudio](https://posit.co/download/rstudio-desktop/).

Steps:
1. Clone the repo to your local machine
2. Open the `create_data/R workflow/R workflow.Rproj` project
3. In the R session, the `code.R` file should open automaticlly (if not - open it)
4. Run the commands one-by-one (with <kbd>⌘ Cmd</kbd> + <kbd>⏎ Return</kbd> 
or <kbd>Ctrl</kbd> + <kbd>⏎ Enter</kbd>)
    - Pay attention to the instructions in the comments
6. You will be asked to log in to your Google account and state the associated billing account/poject name

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
| SIMPLE_SUM                      | FLOAT    | Simple raw urine output hourly summatio (for testing purposes) |
| WEIGHT_ADMIT                    | FLOAT    | Patient weight at admission                                    |

### `mimic_uo_and_aki.e_aki_analysis`:
| Field name  | Type     | Description                                                       |
| ----------- | -------- | ----------------------------------------------------------------- |
| AKI_ID      | INTEGER  | Unique AKI event ID                                               |
| SUBJECT_ID  | INTEGER  | Patient ID                                                        |
| HADM_ID     | INTEGER  | Hospital Admission ID                                             |
| STAY_ID     | INTEGER  | ICU stay ID                                                       |
| WEIGHT      | FLOAT    | Admission weight                                                  |
| AKI_START   | DATETIME | Date and time for AKI onset                                       |
| AKI_STOP    | DATETIME | Date and time for AKI resolution                                  |
| AKI_TYPE    | INTEGER  | Type by KDIGO criteria; 1 for UO event, 2 for sCr event           |
| NO_START    | INTEGER  | Has there been identification of a shift from KDIGO stage 0 to >0 |
| NO_END      | INTEGER  | Has there been identification of a shift from KDIGO stage >0 to 0 |
| WORST_STAGE | INTEG    | The worst KDIGO stage in the event by AKI type                    |
