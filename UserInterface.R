## COURT DOCKET READER - BETA VERSION

setwd("C:/Users/sbr/Dropbox/R/CourtDocketReader")

fileNames <- list.files(pattern = "*.pdf")
source("C:/Users/sbr/Dropbox/R/CourtDocketReader/BETA/PDFReader.R")

entriesFieldsToExtract <- c("Order - Sentence/Penalty Imposed",
                            "Probation/Parole Continued",
                            "Order Granting Motion to Revoke Probation",
                            "Violation Penalties Imposed")

output <- readPDFs(fileNames, entriesFieldsToExtract)

openxlsx::write.xlsx(output, "C:/Users/sbr/Dropbox/R/CourtDocketReader/BETA/Output.xlsx")


