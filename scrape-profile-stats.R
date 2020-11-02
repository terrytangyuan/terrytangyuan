library(rvest)

gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"
readme_loc <- "README.md"

citations <- read_html(gscholar_link) %>%
  html_nodes("#gsc_rsb_st") %>%
  .[[1]] %>%
  html_table() %>%
  .[1, "All"]

readme_txt <- readLines(readme_loc)
readme_txt <- gsub(
  "Scholar-\\d?.?\\d?k?-_.svg",
  sprintf("Scholar-%sk-_.svg", round(citations / 1000, digits = 1)),
  readme_txt)
writeLines(readme_txt, con = readme_loc)
