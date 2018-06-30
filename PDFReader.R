#PDF READER - BETA VERSION

pacman::p_load(dplyr, tm, pdftools, stringr, splitstackshape, openxlsx)

readPDFs <- function(fileNames, entriesFieldsToExtract) {
  
  output <- data.frame()
  
  for (i in seq_along(fileNames)){
    
    extractor <- lapply(fileNames[i], pdf_text)
    pdftext <- lapply(extractor, paste, collapse = '')
    pdftext <- unlist(pdftext)
    
    pdftext <- gsub("\\r\\n[0-9]{1}|\\[ln\\][0-9]{1}|\\r\\n|\\[ln\\]|\\\n[0-9]{1}|\\\n", 
                    "[ln]", pdftext)
    docketNum <- str_extract(pdftext, "(?<=Docket Number:\\s)[a-zA-Z0-9\\-]*(?=\\[ln\\])")
    arrestDate <- str_extract(pdftext, "(?<=Arrest Date:[\\s]{6})[0-9/]*(?=\\[ln\\])")
    
    mainDF <- as.data.frame(cbind(fileNames[i], docketNum, arrestDate))
    
    entriesDF <- data.frame()
    
    for (j in seq_along(entriesFieldsToExtract)) {
      regexString <- paste0("(?<=\\[ln\\][\\s]{32})[0-9/a-zA-Z\\s\\,\\.\\-]*\\[ln\\][\\s]{2}", 
                            entriesFieldsToExtract[j], 
                            ".*?(?=([^\\:][\\s][0-9]{2}/[0-9]{2}/[0-9]{4}){1}?|CPCMS\\s[0-9]{4})")
      
      entry <- str_extract_all(pdftext, regexString)
      entryDF <- as.data.frame(cbind(fileNames[i], entry))
      entryDF <- listCol_l(entryDF, "entry", drop = T)
      
      entryDF$entry_date <- str_extract(entryDF$entry_ul, "[0-9/]*")
      entryDF$entry_judge <- str_trim(str_extract(entryDF$entry_ul, 
                                                  "[a-zA-Z\\-\\,\\.\\s]*(?=\\[ln\\])"))
      entryDF$entry_judgeLast <- str_extract(entryDF$entry_judge, 
                                             "[a-zA-Z]*(?=\\,)")
      entryDF$entry_judgeFirst <- str_extract(entryDF$entry_judge, 
                                              "(?<=\\,\\s)[a-zA-Z]*")
      entryDF$entry_text <- str_extract(entryDF$entry_ul, 
                                        paste0("(?<=", 
                                               entriesFieldsToExtract[j], 
                                               "\\[ln\\]).*?$"))
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
  output$entry_text <- str_trim(output$entry_text)
  output$entry_text <- gsub("\\[ln\\]", "", output$entry_text)
  output$entry_text <- gsub("CPCMS.*$", "", output$entry_text, perl = T)
  output$entry_text <- stripWhitespace(output$entry_text)
  return(output)
}
