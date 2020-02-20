## COURT DOCKET READER - BETA VERSION

# Dependencies
library(RSelenium)
library(pacman)
parentFilePath <- "~/CourtDocketProject/"
source(paste0(parentFilePath, "DocketScraper.R"))
source(paste0(parentFilePath, "PDFReader.R"))

# Set up Docker
system('docker kill $(docker ps -q)') #get rid of any open containers
system('docker run -d -p 4445:4444 selenium/standalone-chrome') #create a docker container
# Then, set up the RSelenium remote driver object
remoteDriver <- RSelenium::remoteDriver(remoteServerAddr = "localhost",
                                        port = 4445L,
                                        browserName = "chrome")
Sys.sleep(2)
remoteDriver$open()
Sys.sleep(2)
remoteDriver$navigate("https://ujsportal.pacourts.us/DocketSheets/CP.aspx")
Sys.sleep(2)
# check that its working
remoteDriver$screenshot(display = TRUE)

# Get the list of names you want to search dockets for
testNames <- read.csv(paste0(parentFilePath, "3.TestNames/testNames.csv"), 
                      header = T, stringsAsFactors = F)
# make DOB into the following format 'MMDDYYYY' as a character string
testNames$cleanedDOB <- str_replace(testNames$dob, "(^[0-9]{1}\\/[0-9]*\\/[0-9]*)", paste0("0", "\\1"))
testNames$cleanedDOB <- str_replace(testNames$cleanedDOB, "(^[0-9]*\\/)([0-9]{1}\\/[0-9]*)", paste0("\\1", "0", "\\2"))
testNames$cleanedDOB <- str_replace_all(testNames$cleanedDOB, "\\/", "")
# make sure the names fields only have one word (preferably their actual name, and no middle initials, 'Jr.', etc...
testNames$cleanedLast <- str_extract(testNames$lastName, "^[\\w]*")
testNames$cleanedFirst <- str_extract(testNames$firstName, "^[\\w]*")

# Fill in the HTML fields
parentNode <- "#ctl00_ctl00_ctl00_cphMain_cphDynamicContent_cphDynamicContent_"
searchTypeNode <- paste0(parentNode, "searchTypeListControl")
countyNode <- paste0(parentNode, "participantCriteriaControl_countyListControl")

selectDropdown(remoteDriver, searchTypeNode, "Participant Name")
remoteDriver$screenshot(display = TRUE)

selectDropdown(remoteDriver, countyNode, "Philadelphia")
remoteDriver$screenshot(display = TRUE)

# Enter name and date of birth iteratively
arguments <- list(testNames$id,
                  testNames$cleanedLast, 
                  testNames$cleanedFirst, 
                  testNames$cleanedDOB)

searchResults <- purrr::pmap(arguments, 
                             function(q, x, y, z) 
                               scrapeForDockets(
                                 remoteDriver = remoteDriver,
                                 id = q,
                                 lastName = x,
                                 firstName = y,
                                 dateOfBirth = z)) %>% dplyr::bind_rows()

searchResults <- searchResults %>%
  group_by(id) %>%
  mutate(rowNum = 1:n())

saveRDS(searchResults, paste0(parentFilePath, "searchResults.rds"))
#### Download PDFs - this takes awhile #########################
downloadFolderPath <- paste0(parentFilePath, "4.ScrapedPDFs/")
withResults <- searchResults[which(searchResults$resultReturned == 1), ]
arguments <- list(withResults$docketURL, 
                  withResults$id, 
                  withResults$rowNum)
purrr::pmap(arguments,
          function(x, y, z) 
            downloadDocket(
              docketURL = x,
              id = y,
              rowNum = z,
              downloadFolderPath = downloadFolderPath
            ))
################################################################
# Parse PDFs
setwd(downloadFolderPath)
pdfFileNames <- list.files(pattern = "*.pdf")

entriesFieldsToExtract <- c("Order - Sentence/Penalty Imposed",
                            "Probation/Parole Continued",
                            "Order Granting Motion to Revoke Probation",
                            "Violation Penalties Imposed")

output <- readPDFs(pdfFileNames, entriesFieldsToExtract)

# Write to File
openxlsx::write.xlsx(output, paste0(parentFilePath, "Output.xlsx"))


