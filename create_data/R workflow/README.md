# MIMIC-IV hourly-adjusted urine output and AKI analysis

SQL queries and R workflow to create datasets for hourly-adjusted urine output (UO) and AKI events, as well as the original research results from the [MIMIC critical care database](https://mimic.mit.edu). 
Our *Scientific Data article: "From Arbitrary Charting to Precise Hourly Urine Rates and AKI Staging: A Comprehensive ICU Database Analysis"*, is accompanied by this repository.

## Table of contents

* [Introduction](#introduction)
* [Main Objectives and Structure](#main-objectives-and-structure)
* [Requirements and Compatability](#requirements-and-compatability)
* [Example](#example)
* [Citation](#citation)

## Introduction

The accuracy and consistency of urine output analyses are limited by various sources of urine output and irregular collection intervals during hospitalization. In this study, we proposed a methodology for systematically correcting charted urine output records to obtain hourly-adjusted UO rates in over 70,000 ICU stays with near-total hourly availability (99.3%) across 94.9% of the ICU stays in the MIMIC database. Furthermore, we demonstrated high data consistency under thorough and conservative analyses, thus providing a reliable platform for investigating hypotheses related to UO changes in the future. In addition to the high temporal resolution, the proposed method significantly improves accuracy; specifically, 45% of the calculated hours showed a difference of 100 ml or more compared to a simple hourly volume summation.

Our protocol can be utilized to detect the onset and resolution of AKI events, label AKI stages, and accurately summate fluid balance at any given time frame with hourly resolution. Given the similar characteristics, our proposed protocol is highly adaptable for any other ICU-EHR-based database. We firmly believe that our study and protocol address a relevant issue and will serve as a platform for future AKI and fluid overload research, guideline drafting, and the creation of real-time decision-making tools.

## Main Objectives and Structure

This repository has two main objectives:

1. **Allow the creation of hourly-adjusted UO tables for each ICU stay in the MIMIC-IV database, as well as to identify the onset and resolution of AKI events.** These tables are meant to provide a reliable platform for future research to anyone who wishes to use them.

To achieve this objective, it is necessary to run several SQL queries in a particular order. Additionally, we have included a coded workflow in R that can automatically run these queries. You can find the queries, workflow, and instructions in the `create_data/...` folder.


2. **Allow the reproduction of the associtate Scientific Data article.**
 
In the `repreduce_article/...` folder, you will find the R-markdown code and instructions on how to reproduce its results.

## Requirements and Compatability

 - The MIMIC-IV database is not provided with this repository and is **required** in order to run this code. 
 - To have access to the MIMIC database, you will need the following:
    - Become a credentialed user on PhysioNet and sign the use agreement (see ['Getting Started'](https://mimic.mit.edu/docs/gettingstarted/) tutorial).
    - Have MIMIC BigQuery (cloud) access (see ['Getting Started/Cloud](https://mimic.mit.edu/docs/gettingstarted/cloud/)' tutorial )
 - To run the queries, you will need a Google Cloud Platform (GCS) billing account
 - The SQL queries are written in GoogleSQL dialect*. The supplied workflow runs the query through R, but you can also run it in BigQuery's console.
 - The code was tested on MIMIC-IV 2.4
 
***NOTE** GoogleSQL dialect (formally known as "Standard-SQL" dialect) is probably compatible with other common dialects.


## Example

See.............

## Citation

........
