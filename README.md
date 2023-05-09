# MIMIC-IV hourly-adjusted urine output and AKI analysis

SQL queries and R workflow to create datasets for hourly-adjusted urine output (UO) and AKI events as well as the original research results from the [MIMIC critical care database](https://mimic.mit.edu). 
This repository accompanies the *Scientific Data article: "From Arbitrary Charting to Precise Hourly Urine Rates and AKI Staging: A Comprehensive ICU Database Analysis"*.

## Table of contents

* [Introduction](#introduction)
* [Main Objectives and Structure](#main-objectives-and-structure)
* [Requirements and Compatability](#requirements-and-compatability)
* [Example](#example)
* [Citation](#citation)

## Introduction

The accuracy and consistency of urine output analyses are limited by various sources of urine output and irregular collection intervals during hospitalization. In this study, we proposed a methodology for systematically correcting charted urine output records to obtain hourly-adjusted UO rates in over 70,000 ICU stays with near-total hourly availability (99.3%) across 94.9% of the ICU stays in the MIMIC database. Furthermore, we demonstrated high data consistency under thorough and conservative analyses, thus providing a reliable platform for investigating hypotheses related to UO changes in the future. In addition to the high temporal resolution, the proposed method significantly improves accuracy; specifically, 45% of the calculated hours showed a difference of 100 ml or more compared to a simple hourly volume summation.

Our protocol can be utilized to detect the onset and resolution of AKI events, label AKI stages, and accurately summate fluid balance at any given time frame with hourly resolution. Given the similar characteristics, our proposed protocol is highly adaptable for use with any other ICU-EHR-based database. We firmly believe that our study and protocol address a relevant issue and will serve as a platform for future AKI and fluid overload research, guideline drafting, and the creation of real-time decision-making tools.

## Main Objectives and Structure

This repository has two main objectives:

1. **Enable the creation of hourly-adjusted UO and AKI events tables** - For further instructions visit: `create_data/...`.

2. **Enable the reproduction of the associtate Scientific Data article.** - For further instructions visit: `repreduce_article/...`.

## Requirements and Compatability

 - The MIMIC-IV database is **required** in order to run this code and is not provided with this repository. 
 - To access the MIMIC database, you will need to:
    - Become a credentialed user on [PhysioNet](https://physionet.org) and sign the use agreement (see ['Getting Started'](https://mimic.mit.edu/docs/gettingstarted/) tutorial).
    - Have MIMIC BigQuery (cloud) access (see ['Getting Started/Cloud](https://mimic.mit.edu/docs/gettingstarted/cloud/)' tutorial )
 - You will need a Google Cloud Platform (GCS) billing account to run the queries.
 - The SQL queries are written in GoogleSQL dialect (formally known as "Standard-SQL" dialect) and is probably compatible with other common dialects.
 - The code was tested on MIMIC-IV 2.4


## Example

After creating all the tables and repreducing the associated study, you should end up with a [result page in HTML format](https://defi.co.il/ariel/mimic/).

## Citation

........
