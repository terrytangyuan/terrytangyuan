library(rvest)

gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"
citations <- read_html(gscholar_link) %>%
  html_nodes("#gsc_rsb_st") %>%
  .[[1]] %>%
  html_table() %>%
  .[1, "All"]

citations_txt <- sprintf("%sk", floor(citations / 1000))
readme_txt <- readLines("README.md")
readme_txt <- gsub("Scholar-\\d?k?-_.svg", sprintf("Scholar-%s-_.svg", citations_txt), readme_txt)
writeLines(readme_txt, con = "README.md")
