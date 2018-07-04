## COURT DOCKET READER - BETA VERSION

# Dependencies
library(RSelenium)
library(pacman)
parentFilePath <- "~/Desktop/Stuff/EvanProjects/CourtDocketProject/"
source(paste0(parentFilePath, "DocketScraper.R"))
source(paste0(parentFilePath, "PDFReader.R"))

# Set up Docker
system('docker kill $(docker ps -q)') #get rid of any open containers
system('docker run -d -p 4445:4444 selenium/standalone-chrome') #create a docket container
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
testNames <- testNames %>% mutate(cleanedDOB = ifelse(nchar(dob) == 7, 
                                                      paste0("0", dob), dob))
# Fill in the HTML fields
selectSearchType(remoteDriver, "Participant Name")
remoteDriver$screenshot(display = TRUE)

selectCounty(remoteDriver, "Philadelphia")
remoteDriver$screenshot(display = TRUE)

# Enter name and date of birth iteratively
arguments <- list(testNames$lastName, 
                  testNames$firstName, 
                  testNames$cleanedDOB)

searchResults <- purrr::pmap(arguments, 
                             function(x, y, z) 
                               scrapeForDockets(
                                 remoteDriver = remoteDriver, 
                                 lastName = x,
                                 firstName = y,
                                 dateOfBirth = z)) %>% dplyr::bind_rows()

#### Download PDFs - this takes awhile #########################
downloadFolderPath <- paste0(parentFilePath, "4.ScrapedPDFs/")
downloadDockets(searchResults, downloadFolderPath)
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


