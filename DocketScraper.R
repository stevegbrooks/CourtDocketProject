## DOCKET SCRAPER - BETA VERSION
pacman::p_load(RSelenium, rvest, xml2, tidyverse, magrittr, tm)
system('docker run -d -p 4445:4444 selenium/standalone-chrome')
source("/Users/sgb/Dropbox/R/CourtDocketReader/2.BETA/DocketScraperUtils.R")
remDr <- RSelenium::remoteDriver(remoteServerAddr = "localhost",
                                 port = 4445L,
                                 browserName = "chrome")
remDr$open()

remDr$navigate("https://ujsportal.pacourts.us/DocketSheets/CP.aspx") 
remDr$screenshot(display = TRUE)

parentNode <- "#ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_"

#### Selecting "Participant Name" from the Search Type Menu ####
searchTypeNode <- paste0(parentNode, "searchTypeListControl")

searchTypes <- xml2::read_html(remDr$getPageSource()[[1]]) %>%
  rvest::html_nodes(searchTypeNode) %>%
  rvest::html_children() %>%
  rvest::html_text() %>%
  dplyr::data_frame(searchType = .)

numOfSearchTypes <- 7
searchTypes <- searchTypes %>%
  dplyr::mutate(listPosition = 1:numOfSearchTypes,
                x = paste0(searchTypeNode, 
                           " > option:nth-child(", 
                           listPosition, ")"))

selectedTypeIndex <- grep("Participant Name", 
                          searchTypes$searchType, 
                          ignore.case = T)

remDr$findElement(using = 'css selector', 
                  searchTypes$x[selectedTypeIndex])$clickElement()
Sys.sleep(1)

#### Selecting "Philadelphia" from the County Menu ####
parentNode <- paste0(parentNode, "participantCriteriaControl_")
countyNode <- paste0(parentNode, "countyListControl")

counties <- xml2::read_html(remDr$getPageSource()[[1]]) %>%
  rvest::html_nodes(countyNode) %>%
  rvest::html_children() %>%
  rvest::html_text() %>%
  dplyr::data_frame(county = .)

numOfCounties <- 68
counties <- counties %>%
  dplyr::mutate(listPosition = 1:numOfCounties,
                x = paste0(countyNode, 
                           " > option:nth-child(", 
                           listPosition, ")"))

selectedCountyIndex <- grep("Philadelphia", 
                            counties$county, 
                            ignore.case = T)

remDr$findElement(using = 'css selector', 
                  counties$x[selectedCountyIndex])$clickElement()
Sys.sleep(1)

#TODO - Add Iterator to handle an .xlsx/.csv file full of names
#### Filling in Name ####
lastName <- "Brooks"
lastNameNode <- paste0(parentNode, "lastNameControl")
element <- remDr$findElement(using = "css selector", 
                  lastNameNode)
element$clearElement()
element$sendKeysToElement(list(lastName))

firstName <- "Steven"
firstNameNode <- paste0(parentNode, "firstNameControl")
element <- remDr$findElement(using = "css selector", 
                  firstNameNode)
element$clearElement()
element$sendKeysToElement(list(firstName))

#### Filling in DOB ####
#TODO
dob <- "07251985"
dobSplit <- strsplit(dob, split = "")[[1]]
dobNode <- paste0(parentNode, "dateOfBirthControl_DateTextBox")
element <- remDr$findElement(using = "css selector",
                             dobNode)
element$clearElement()
element$clickElement()
for (i in 1:5) { element$sendKeysToElement(list("\uE012")) }
for (i in seq_along(dobSplit)) { element$sendKeysToElement(list((dobSplit[i]))) }
remDr$screenshot(display = TRUE)

#### Pressing "Search" Button and Getting Results ####
searchNode <- paste0(parentNode, "searchCommandControl")
tableXPath <- '//*[@id="ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_participantCriteriaControl_searchResultsGridControl_resultsPanel"]/table'

searchResults <- getSearchResults(searchNode)

#### Determining if There Are More Pages of Results ####
if (dim(searchResults)[1]>0) {
  searchPagesNode <- paste0(parentNode, "searchResultsGridControl_casePager")
  
  searchPages <- xml2::read_html(remDr$getPageSource()[[1]]) %>%
    rvest::html_nodes(searchPagesNode) %>%
    rvest::html_children() %>%
    rvest::html_text()
  searchPages <- stringr::str_extract_all(searchPages, "[2-9]*")
  searchPages <- searchPages[[1]][searchPages[[1]]!=""]
  
  hasMorePages <- !is.na(searchPages)[1]
  
  #### If There Are, Grabbing Those Results Too ####
  if (hasMorePages) {
    secondaryPages <- dplyr::data_frame(
      pageNumber = 1:length(searchPages) + 1,
      pageElement = paste0(searchPagesNode, 
                           " > div > a:nth-child(", 
                           pageNumber + 2, ")"))
    secondaryPages <- secondaryPages[,2]
    
    secondaryResults <- purrr::pmap(secondaryPages, getSearchResults) %>%
      dplyr::bind_rows()
    
    searchResults <- dplyr::bind_rows(searchResults, secondaryResults)
  }
  
  #### Add the URL string to the searchResults dataFrame ####
  baseUrl <- "https://ujsportal.pacourts.us/DocketSheets/CPReport.ashx?docketNumber="
  searchResults <- searchResults %>%
    dplyr::mutate(docketURL = paste0(baseUrl, `Docket Number`))
  
  #### Set Directory for Download Folder ####
  downloadFolder <- "/Users/sgb/Dropbox/R/CourtDocketReader/1.BETA/ScrapedPDFs/"
  
  #### Grab all the PDFs - This Takes Time! ####
  for (i in 1:nrow(searchResults)) {
    fileName <- toupper(searchResults$Party[1])
    fileName <- strsplit(fileName, "\\,")
    fileName <- lapply(fileName, function(x) gsub("\\s", "_", x, perl = T))
    fileName <- lapply(fileName, function(x) gsub("\\W", "", x, perl = T))
    fileName <- paste0(fileName[[1]][1], fileName[[1]][2], "_", i, ".pdf")
    
    download.file(searchResults$docketURL[i], 
                  destfile = file.path(paste0(downloadFolder, fileName)), 
                  mode = 'wb')
  }
}
