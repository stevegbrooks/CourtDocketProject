#PDF READER - BETA VERSION

pacman::p_load(dplyr, tm, pdftools, stringr, splitstackshape)

readPDFs <- function(pdfFileNames, entriesFieldsToExtract) {
  
  output <- data.frame()
  
  for (i in seq_along(pdfFileNames)){
    
    extractor <- lapply(pdfFileNames[i], pdf_text)
    pdftext <- lapply(extractor, paste, collapse = '')
    pdftext <- unlist(pdftext)
    
    pdftext <- gsub("\\r\\n[0-9]{1}|\\[ln\\][0-9]{1}|\\r\\n|\\[ln\\]|\\\n[0-9]{1}|\\\n", 
                    "[ln]", pdftext)
    docketNum <- str_trim(str_extract(pdftext, "(?<=Docket Number:)[\\sa-zA-Z0-9\\-]*(?=\\[ln\\])"))
    arrestDate <- str_trim(str_extract(pdftext, "(?<=Arrest Date:)[\\s0-9/]*(?=\\[ln\\])"))
    
    mainDF <- as.data.frame(cbind(pdfFileNames[i], docketNum, arrestDate))
    
    mainDF$name <- str_extract(mainDF$V1, "[A-Z\\_]*(?=\\_[0-9])")
    mainDF$fileNum <- as.numeric(str_extract(mainDF$V1, "(?<=\\_)[0-9]*(?=\\.pdf)"))
    mainDF <- mainDF[,c("V1", "fileNum", "name", "docketNum", "arrestDate")]
    
    entriesDF <- data.frame()
    
    for (j in seq_along(entriesFieldsToExtract)) {
      regexString <- paste0("(?<=\\[ln\\][\\s]{32})[0-9/a-zA-Z\\s\\,\\.\\-]*\\[ln\\][\\s]{2}", 
                            entriesFieldsToExtract[j], 
                            ".*?(?=([^\\:][\\s][0-9]{2}/[0-9]{2}/[0-9]{4}){1}?|CPCMS\\s[0-9]{4})")
      
      entry <- str_extract_all(pdftext, regexString)
      entryDF <- as.data.frame(cbind(pdfFileNames[i], entry))
      entryDF <- listCol_l(entryDF, "entry", drop = T)
      
      entryDF$entry_date <- str_trim(stripWhitespace(str_extract(entryDF$entry_ul, "[\\s0-9/]*")))
      entryDF$entry_judge <- str_trim(str_extract(entryDF$entry_ul, 
                                                  "[a-zA-Z\\-\\,\\.\\s]*(?=\\[ln\\])"))
      entryDF$entry_judgeLast <- str_trim(stripWhitespace(str_extract(entryDF$entry_judge, 
                                             "[a-zA-Z]*(?=\\,)")))
      entryDF$entry_judgeFirst <- str_trim(stripWhitespace(str_extract(entryDF$entry_judge, 
                                              "(?<=\\,\\s)[a-zA-Z]*")))
      entryDF$entry_text <- str_trim(stripWhitespace(str_extract(entryDF$entry_ul, 
                                        paste0("(?<=", 
                                               entriesFieldsToExtract[j], 
                                               "\\[ln\\]).*?$"))))
      
      entryDF$entry_text <- gsub("\\[ln\\]", "", entryDF$entry_text)
      entryDF$entry_text <- gsub("CPCMS.*$", "", entryDF$entry_text, perl = T)
      
      entryDF$V1 <- as.character(entryDF$V1)
      entryDF$entriesSearchTerm <- entriesFieldsToExtract[j]
      entryDF <- entryDF[,c("V1", "entriesSearchTerm", "entry_date",  
                            "entry_judgeLast", "entry_judgeFirst", 
                            "entry_text")]
      
      if (dim(entriesDF)[2] > 0) {
        entriesDF <- rbind(entriesDF, entryDF)
      } else {
        entriesDF <- entryDF
      }
    }
    
    mainDF$V1 <- as.character(mainDF$V1)
    mainDF <- dplyr::full_join(mainDF, entriesDF, by = "V1")
    
    if (dim(output)[2] > 0){
      output <- rbind(output, mainDF)
    } else {
      output <- mainDF
    }
  }
  colnames(output)[colnames(output) == "V1"] <- "fileName"
  return(output[order(output$fileNum, output$name), ])
}
