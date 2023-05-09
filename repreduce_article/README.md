# Repreducing Study's Results

The code above is used to repreduce results for the [*From Arbitrary Charting to Precise Hourly Urine Rates and AKI Staging: A Comprehensive ICU Database Analysis*]() study.

## Instructions

The results are generated in R-markdown which require [R and Rstudio](https://posit.co/download/rstudio-desktop/).

**Steps and prerequisites:**
1. Follow `create_data/...` instructions to complete all steps and create all associated tables
2. The repo should already be clone to your local machine
3. Open the `repreduce_article/reproduce_article.Rproj` project
4. The `run_results.Rmd` file should open automaticlly in the R session (if not - open it)
5. Use `Knit with Parameters...` button to run the full analysis (for more info see [ Knitting with parameters](https://bookdown.org/yihui/rmarkdown/params-knit.html))
<img width="508" alt="Screenshot 2023-05-08 at 12 02 12" src="https://user-images.githubusercontent.com/23483971/236784019-7c5475f2-9797-4e8d-acf5-2d903077060b.png">

6. Enter your GCS-BigQuery billing-account/project-id in the prompt
    - The billing-account/project-id should be the same one used to create the associated tables
7. Start "kniting"
    - This may take a while, mainly querying the data on cloud and running the quantile analysis for low UO rates
