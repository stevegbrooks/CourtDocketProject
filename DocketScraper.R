## DOCKET SCRAPER - BETA VERSION
pacman::p_load(rvest, xml2, tidyverse, magrittr, tm)

#### Selecting from the Search Type Menu ####
selectDropdown <- function(remoteDriver, node, selection) {
  
  dropdownOptions <- xml2::read_html(remoteDriver$getPageSource()[[1]]) %>% #read html page
    rvest::html_nodes(node) %>% #go to node
    rvest::html_children() %>% #find the children of the node
    rvest::html_text() %>% #pull out the text
    dplyr::data_frame(options = .) #create dataframe
  
  numOfOptions <- dim(dropdownOptions)[1]
  
  dropdownOptions <-dropdownOptions %>%
    dplyr::mutate(listPosition = 1:numOfOptions,
                  x = paste0(node, " > option:nth-child(", listPosition, ")"))
  
  selectedIndex <- grep(selection, 
                        dropdownOptions$options, 
                        ignore.case = T)
  
  remoteDriver$findElement(using = 'css selector', 
                           dropdownOptions$x[selectedIndex])$clickElement()
  Sys.sleep(1)
}

scrapeForDockets <- function(remoteDriver, id, lastName, firstName, dateOfBirth) {
  print(paste("Processing", firstName, lastName))
  parentNode <- "#ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_"
  parentNode <- paste0(parentNode, "participantCriteriaControl_")
  
  #### Filling in Name ####
  lastNameNode <- paste0(parentNode, "lastNameControl")
  element <- remoteDriver$findElement(using = "css selector", 
                                      lastNameNode)
  element$clearElement()
  element$sendKeysToElement(list(lastName))
  
  firstNameNode <- paste0(parentNode, "firstNameControl")
  element <- remoteDriver$findElement(using = "css selector", 
                                      firstNameNode)
  element$clearElement()
  element$sendKeysToElement(list(firstName))
  
  #### Filling in DOB ####
  dobSplit <- strsplit(dateOfBirth, split = "")[[1]]
  dobNode <- paste0(parentNode, "dateOfBirthControl_DateTextBox")
  element <- remoteDriver$findElement(using = "css selector",
                                      dobNode)
  element$clearElement()
  element$clickElement()
  for (i in 1:5) { element$sendKeysToElement(list("\uE012")) }
  for (i in seq_along(dobSplit)) { element$sendKeysToElement(list((dobSplit[i]))) }
  
  #### Pressing "Search" Button and Getting Results ####
  searchNode <- paste0(parentNode, "searchCommandControl")
  
  searchResults <- getSearchResults(remoteDriver, 
                                    pageElement = searchNode, 
                                    lastName = lastName, 
                                    firstName = firstName, 
                                    dateOfBirth = dateOfBirth)
  
  if (all(grepl("\\/", searchResults$dateOfBirth))) {
    searchPagesNode <- paste0(parentNode, "searchResultsGridControl_casePager")
    
    searchPages <- xml2::read_html(remoteDriver$getPageSource()[[1]]) %>%
      rvest::html_nodes(searchPagesNode) %>%
      rvest::html_children() %>%
      rvest::html_text()
    searchPages <- stringr::str_extract_all(searchPages, "[2-9]*")
    
    if (length(searchPages) > 0) {
      searchPages <- searchPages[[1]][searchPages[[1]]!=""]
      hasMorePages <- !is.na(searchPages)[1]
    } else {
      hasMorePages <- F
    }
    
    if (hasMorePages) {
      secondaryPages <- dplyr::data_frame(
        pageNumber = 1:length(searchPages) + 1,
        pageElement = paste0(searchPagesNode, 
                             " > div > a:nth-child(", 
                             pageNumber + 2, ")"))
      secondaryPages <- secondaryPages[,2]
      
      secondaryResults <- purrr::pmap(secondaryPages, 
                                      ~ getSearchResults(
                                        remoteDriver = remoteDriver, 
                                        pageElement = .,
                                        lastName = lastName,
                                        firstName = firstName,
                                        dateOfBirth = dateOfBirth)) %>% dplyr::bind_rows()
      
      searchResults <- dplyr::bind_rows(searchResults, secondaryResults)
    }
    #results were returned, so flag accordingly
    baseURL <- "https://ujsportal.pacourts.us/DocketSheets/CPReport.ashx?docketNumber="
    searchResults <- searchResults %>%
      dplyr::mutate(resultReturned = 1,
                    docketURL = paste0(baseURL, docketNumber))
  } else {
    #no results were returned, so flag accordingly
    searchResults <- searchResults %>%
      dplyr::mutate(resultReturned = 0,
                    docketURL = NA_character_)
  }
  searchResults$id <- id
  print(sprintf("Returned %.0f search results", 
        nrow(searchResults[which(searchResults$resultReturned == 1),])))
  print("=============================")
  return(searchResults)
}

# Downloads PDFs based on the output of 'getDocketURLs()'
downloadDockets <- function(searchResults, downloadFolderPath) {
  
  for (i in 1:nrow(searchResults)) {
    if (searchResults$resultReturned[i] == 1) {
      fileName <- toupper(searchResults$party[1])
      fileName <- strsplit(fileName, "\\,")
      fileName <- lapply(fileName, function(x) gsub("\\s", "_", x, perl = T))
      fileName <- lapply(fileName, function(x) gsub("\\W", "", x, perl = T))
      fileName <- paste0(fileName[[1]][1], fileName[[1]][2], "_", i, ".pdf")
      
      download.file(searchResults$docketURL[i], 
                    destfile = file.path(paste0(downloadFolderPath, fileName)), 
                    mode = 'wb')
    }
  }
}

downloadDocket <- function(docketURL, id, rowNum, downloadFolderPath) {
  fileName <- paste0(id, "_", rowNum, ".pdf")
  download.file(docketURL, 
                destfile = file.path(paste0(downloadFolderPath, fileName)), 
                mode = 'wb')
}

# Cleaning Search Results Table
cleanScrapedTable <- function(searchResults) {
  nthRow <- 7
  searchResults <- searchResults[seq(1, nrow(searchResults), nthRow), ]
  searchResults <- searchResults[,8:17]
  names(searchResults) <- c("docketNumber", "shortCaption", "filingDate", 
                            "county", "party", "caseStatus", "OTN", "LOTN", 
                            "policeIncident_complaintNumber",
                            "dateOfBirth")
  rownames(searchResults) <- 1:nrow(searchResults)
  searchResults <- searchResults %>% dplyr::mutate_at(vars(colnames(searchResults)), 
                                                      funs(as.character(.)))
  return(searchResults)
}

# Getting Results from Search
getSearchResults <- function(remoteDriver, pageElement, lastName, firstName, dateOfBirth) {
  tableXPath <- '//*[@id="ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_participantCriteriaControl_searchResultsGridControl_resultsPanel"]/table'
  
  remoteDriver$findElement(using = "css selector", pageElement)$clickElement()
  Sys.sleep(1)
  
  searchResultsPage <- xml2::read_html(remoteDriver$getPageSource()[[1]])
  
  noResultsPane <- xml2::xml_find_all(searchResultsPage, xpath = "//*[@id='ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_participantCriteriaControl_searchResultsGridControl_noResultsPanel']/table/tbody/tr/td")
  
  searchResults <- data.frame()
  
  if (length(noResultsPane) == 0) {
    searchResults <- searchResultsPage %>%
      rvest::html_node(xpath = tableXPath) %>%
      rvest::html_table(fill = T)
    searchResults <- cleanScrapedTable(searchResults)
  } else {
    searchResults <- data.frame(matrix(nrow = 1, ncol = 10))
    names(searchResults) = c("docketNumber", "shortCaption", "filingDate", 
                             "county", "party", "caseStatus", "OTN", "LOTN", 
                             "policeIncident_complaintNumber",
                             "dateOfBirth")
    searchResults[1,] <- c(NA, NA, NA, NA, 
                           paste0(lastName, ", ", firstName), 
                           NA, NA, NA, NA, dateOfBirth)
  }
  return(searchResults)
}

