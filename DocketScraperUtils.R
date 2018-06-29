# Function for Cleaning Search Results Table
cleanTable <- function(searchResults) {
  nthRow <- 7
  searchResults <- searchResults[seq(1, nrow(searchResults), nthRow), ]
  columnNames <- names(searchResults)[2:11]
  searchResults <- searchResults[,8:17]
  names(searchResults) <- columnNames
  rownames(searchResults) <- 1:nrow(searchResults)
  return(searchResults)
}

# Function for Getting Results from Search
getSearchResults <- function(pageElement) {
  
  remDr$findElement(using = "css selector", pageElement)$clickElement()
  Sys.sleep(1)
  
  searchResultsPage <- xml2::read_html(remDr$getPageSource()[[1]])
  
  noResultsPane <- xml2::xml_find_all(searchResultsPage, xpath = "//*[@id='ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_participantCriteriaControl_searchResultsGridControl_noResultsPanel']/table/tbody/tr/td")
  
  searchResults <- data.frame()
  
  if (length(noResultsPane) == 0) {
    searchResults <- searchResultsPage %>%
      rvest::html_node(xpath = tableXPath) %>%
      rvest::html_table(fill = T)
    
    searchResults <- cleanTable(searchResults)
  } else {
    warning(paste0("No results found for: Name: ", lastName, ", ", firstName, " | DOB: ", dob))
  }
  return(searchResults)
}
