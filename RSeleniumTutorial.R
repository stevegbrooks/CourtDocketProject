system("docker run -d -p 4446:4444 selenium/standalone-chrome")

library(RSelenium)
library(rvest)
library(xml2)
library(tidyverse)

remDr <- RSelenium::remoteDriver(remoteServerAddr = "localhost",
                                 port = 4446L,
                                 browserName = "chrome")
remDr$open()

remDr$navigate("http://apps.who.int/bloodproducts/snakeantivenoms/database/SearchFrm.aspx") #Entering our URL gets the browser to navigate to the page

snake_countries <- xml2::read_html(remDr$getPageSource()[[1]]) %>%
  rvest::html_nodes("#ddlCountry") %>%
  rvest::html_children() %>%
  rvest::html_text() %>%
  dplyr::data_frame(country_name = .)

snake_countries <- snake_countries %>%
  dplyr::mutate(list_position = 1:160,
                x = stringr::str_c("#ddlCountry > option:nth-child(",list_position, ")"))

# We chop off our first one as we are never going to navigate to there
snake_countries <- snake_countries[-1,]

element<- remDr$findElement(using = 'css selector', "#ddlCountry > option:nth-child(65)")
element$clickElement()

element <- remDr$findElement(using = 'css selector', "#SnakesGridView > tbody > tr:nth-child(12) > td > table > tbody > tr > td:nth-child(2)")
element$clickElement()
remDr$screenshot(display = TRUE)

# Then Extract The Snake Page
country_html <- xml2::read_html(remDr$getPageSource()[[1]])

# We download The Table For the First Page, and if there is only one page that's all we need to do!

country_table <- country_html %>%
  rvest::html_node("#SnakesGridView") %>%
  rvest::html_table(fill = TRUE)

# Then Determine If There Are More Pages
more_pages <- length(country_table) > 4

# Create a function to download the additional page's information

snake_country_secondary_download <- function(page_element){
  
  element <- remDr$findElement(using = 'css selector', page_element)
  element$clickElement()
  
  country_html <- xml2::read_html(remDr$getPageSource()[[1]])
  
  secondary_country <- country_html %>%
    rvest::html_node("#SnakesGridView") %>%
    rvest::html_table(fill = TRUE)
  
  secondary_country
}

# Put everything about these bigger pages in an if statement

if(more_pages == TRUE){
  # Then Work Out Exactly How Many More Pages - This is messy, I don't know why it cant go into a single html_node
  # but it seems to work this way and not the other way.
  
  country_table_number <- country_html %>%
    rvest::html_node("#SnakesGridView") %>%
    rvest::html_node("tbody > tr:nth-child(12)") %>%
    rvest::html_node("td") %>%
    rvest::html_node("table") %>%
    rvest::html_node("tr") %>%
    rvest::html_nodes("td") %>%
    length()
  
  # Create the links for these secondary pages
  country_pages <- dplyr::data_frame(
    page_number = 1:country_table_number,
    page_element = stringr::str_c("#SnakesGridView > tbody > tr:nth-child(12) > td > table > tbody > tr > td:nth-child(", page_number, ")"))
  
  country_pages <- country_pages[-1,]
  country_pages <- country_pages[,2]
  
  #country_pages left is the data_frame containing the address for the links for all the subsequent pages for each individual country
  
  #use purrr::pmap to run through each of the secondary pages with our function we created earlier. Then merge them all together
  secondary_country <- purrr::pmap(country_pages, download_secondary_country) %>%
    dplyr::bind_rows()
  
  # reformat these secondary pages, so they look the same as our pages where there's less than ten snakes
  
  country_table <- dplyr::bind_rows(country_table, secondary_country)
  country_table <- country_table[,1:4] %>%
    dplyr::filter(is.na(`Link*`))
}