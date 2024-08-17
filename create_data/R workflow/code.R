# Name: Ariel A Hasidim
# Title: R workflow for the creation of hourly-adjusted UO and AKI events tables.
# Date: 06-May-2023

############################################################
# INSTALL AND LOAD PACKAGES ################################
############################################################
# Installs pacman ("package manager") if needed
if (!require("pacman")) install.packages("pacman")

# Use pacman to load add-on packages as desired
pacman::p_load(pacman, DBI, bigrquery, tidyverse, here)

############################################################
# Set the stage before queries #############################
############################################################
# State your credentialed BigQuery billing account (i.e. the 'project id/name')
billing_account <- readline("Billing account:")

# Define the BigQuery connection details:
con <- dbConnect(
  bigrquery::bigquery(),
  # (Next two lines doesn't really matter, 
  # the access is only restricted by the billing account and the user permissions.)
  project = "physionet-data",
  dataset = "mimiciv_icu",
  billing = billing_account,
)

# Next, you will be prompted to log in to your Google account in order to obtain 
# an authorization token (OAuth token). 
# (This is done by listung the tables in the project)
dbListTables(con)

# Creating new dataset named "mimic_uo_and_aki" in the inside your project:
# (If not exist)
create_dataset <- paste("CREATE SCHEMA IF NOT EXISTS `",billing_account,".mimic_uo_and_aki`", sep = "")
dbSendQuery(con, statement = create_dataset)
# Ignore "Error in UseMethod("as_bq_table") : 
#         no applicable method for 'as_bq_table' applied to an object of class "NULL""

############################################################
# Running workflow to create tables ########################
############################################################
# Send queries to create all tables by order:
dbSendQuery(con, statement = read_file('../a_urine_output_raw.sql'))
dbSendQuery(con, statement = read_file('../b_uo_rate.sql'))
dbSendQuery(con, statement = read_file('../c_hourly_uo.sql'))
dbSendQuery(con, statement = read_file('../d1_kdigo_uo.sql'))
dbSendQuery(con, statement = read_file('../d2_kdigo_creatinine.sql'))
dbSendQuery(con, statement = read_file('../d3_kdigo_stages.sql'))

############################################################
# CLEAN UP #################################################
############################################################
# Clear environment
rm(list = ls())

# Clear packages
p_unload(all)  # Remove all add-ons

# Clear console
cat("\014")  # ctrl+L

# Clear mind :)
