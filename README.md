# MIMIC-IV hourly-adjusted urine output and AKI analysis

SQL queries and R workflow to create datasets for hourly-adjusted urine output (UO) and KDIGO staging as well as the original research results from the [MIMIC critical care database](https://mimic.mit.edu). 
This repository accompanies the article: *"Toward the standardization of big datasets of urine output for AKI analysis: a multicenter validation study"*.

## Table of contents

* [Introduction](#introduction)
* [Main Objectives and Structure](#main-objectives-and-structure)
* [Requirements and Compatability](#requirements-and-compatability)
* [Example](#example)
* [Citation](#citation)

## Introduction

Accurate diagnosis and analysis of oliguric-AKI relies on timely UO charting. The lack of standardization in handling UO data and the various interpretations of KDIGO-UO guidelines limit the ability to make consistent comparisons and draw general conclusions. We aimed to establish a method for standardizing hourly UO using real-life charting data and to examine whether this method can identify oliguric-AKI. We also aimed to validate the method externally. 

The model described, based on simple charting, can be used across the board for oliguric-AKI research. It may serve to analyze publicly available DBs and data sourced from standard EHRs as well as custom-made data in Excel tables. 

This repository addresses the derivation cohort. 

For the validation cohort see: https://github.com/arielhasidim/aumc-uo-and-aki

## Main Objectives and Structure

This repository has two main objectives:

1. **Enable the creation of hourly-adjusted UO and AKI events tables** - For further instructions visit: `create_data/...`.

2. **Enable the reproduction of the associtated article** - For further instructions visit: `reproduce_article/...`.

## Requirements and Compatability

 - The MIMIC-IV database is **required** in order to run this code and is not provided with this repository. 
 - To access the MIMIC database, you will need to:
    - Become a credentialed user on [PhysioNet](https://physionet.org) and sign the use agreement (see ['Getting Started'](https://mimic.mit.edu/docs/gettingstarted/) tutorial).
    - Have MIMIC BigQuery (cloud) access (see ['Getting Started/Cloud](https://mimic.mit.edu/docs/gettingstarted/cloud/)' tutorial )
 - You will need a Google Cloud Platform (GCS) billing account to run the queries.
 - The SQL queries are written in GoogleSQL dialect (formally known as "Standard-SQL" dialect) and are probably compatible with other common dialects.
 - The code was tested on MIMIC-IV 2.4.


## Example

After creating all the tables and reproducing the associated study, you should end up with a result page in HTML format: https://arielhasidim.github.io/mimic-uo-and-aki.

## Citation

Hasidim, A.A., Klein, M.A., Ben Shitrit, I. et al. Toward the standardization of big datasets of urine output for AKI analysis: a multicenter validation study. Sci Rep 15, 20009 (2025). https://doi.org/10.1038/s41598-025-95535-4