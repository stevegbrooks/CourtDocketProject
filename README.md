# Court Docket Project

## Dependencies

The `DocketScraper.R` package uses RSelenium and Docker, neither of which have straightforward downloads/installation.

Selenium is a set of programming tools, a framework, that allows you to automate web browser actions.

RSelenium is a R package that allows you to use your seperate installation of selenium inside R

Docker is software that allows you to run an environment, where you will run Selenium in.

You must install RSelenium through GitHub, and Docker can be downloaded for free from their website.

In addition, the `PDFReader.R` module behaves itself when being run on a Windows machine. Sometimes it has trouble reading a `.pdf` when its on a Mac.

## Modules

### UserInterface.R 

Handles user input, which could either be to parse a folder full of court docket `.pdf` files, or to go and scrape court dockets from the `pacourts.com` website.

### PDFReader.R

Does the work of parsing a bunch of `.pdf` files.
Input is a vector of file names, and the output is a dataframe in "long" format, such that each row corresponds to a field in the `.pdf`. A given search might yield multiple results, and each `.pdf` can be submitted to multiple search terms.

### DocketScraper.R

Takes in a name and date of birth of an individual and, if that input yields results for the county of Philadelphia, outputs all of the court docket `.pdf` files associated with that name and date of birth.

It can also output a table of the court docket numbers, along with other perhaps relevant information, like police incident number and filing date/time.

#### DocketScraperUtils.R

Has a couple functions which help `DocketScraper.R` do its job: `cleanTable()` which turns the html table output from the search query into a clean and concise dataframe object, and `getSearchResults()` which pulls the html table output from the search query. `getSearchResults()` will throw a `warning()` if no results were found.
