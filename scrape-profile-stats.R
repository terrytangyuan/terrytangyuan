# TODO: This no longer works as Google Scholar started blocking
# library(rvest)
# gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"
# citations <- gscholar_link %>%
#   httr::GET(config = httr::config(ssl_verifypeer = FALSE)) %>%
#   read_html() %>%
#   html_nodes("#gsc_rsb_st") %>%
#   .[[1]] %>%
#   html_table() %>%
#   .[1, "All"]

readme_loc <- "README.md"

# Download images in advance so we don't rely on img.shields.io at rendering time.
imgs <- list(
  cv = "https://img.shields.io/badge/Curriculum%20Vitae--_.svg?style=social&logo=giphy",
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  # Numbers for X, LinkedIn, citations need to be updated manually
  twitter = "https://img.shields.io/badge/X-9k-_.svg?style=social&logo=x",
  linkedin = "https://img.shields.io/badge/LinkedIn-11k-_.svg?style=social&logo=linkedin",
  sponsors = sprintf("https://img.shields.io/github/sponsors/terrytangyuan?label=Sponsors&style=social&logoColor=EA4AAA"),
  citations = sprintf("https://img.shields.io/badge/Citations-8.3k-_.svg?style=social&logo=google-scholar")
)

for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}
