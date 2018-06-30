## COURT DOCKET READER - BETA VERSION
parentFilePath <- "/Users/sgb/Dropbox/R/CourtDocketProject/"
setwd(paste0(parentFilePath, "2.TestPDFs"))
fileNames <- list.files(pattern = "*.pdf")

source(paste0(parentFilePath, "PDFReader.R"))

entriesFieldsToExtract <- c("Order - Sentence/Penalty Imposed",
                            "Probation/Parole Continued",
                            "Order Granting Motion to Revoke Probation",
                            "Violation Penalties Imposed")

output <- readPDFs(fileNames, entriesFieldsToExtract)

openxlsx::write.xlsx(output, paste0(parentFilePath, "Output.xlsx"))


