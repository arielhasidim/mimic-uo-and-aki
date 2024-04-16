# Repreducing Study's Results

The code above is used to repreduce derivation cohort results for the *Method for computerized standardization of arbitrary urinary output charting for the diagnosis of AKI: A derivation-validation proof of concept study using two multicenter databases* (DOI: [XX]()) study.

## Instructions

The results are generated in R-markdown, which requires [R and Rstudio](https://posit.co/download/rstudio-desktop/).

**Prerequisites:**
1. Follow the `create_data/...` instructions to complete all steps and create all associated tables
2. The repo should already be cloned to your local machine
3. "Run results" should be done before creating the "Supplemental materials"

**Steps for running results:**
1. Open the `repreduce_article/reproduce_article.Rproj` project
2. The `run_results.Rmd` file should open automatically in the R session (if not - open it)
3. Use the `Knit with Parameters...` button to run the full analysis (for more info, see [ Knitting with parameters](https://bookdown.org/yihui/rmarkdown/params-knit.html))
<img width="508" alt="Screenshot 2023-05-08 at 12 02 12" src="https://user-images.githubusercontent.com/23483971/236784019-7c5475f2-9797-4e8d-acf5-2d903077060b.png">

4. Enter your GCS-BigQuery billing-account/project-id in the prompt
    - The billing-account/project-id should be the same one used to create the associated tables
5. Start "knitting"
    - This may take a while, mainly querying the data on the cloud and running the quantile analysis for low UO rates
