library(rvest)

gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"
readme_loc <- "README.md"

citations <- read_html(gscholar_link) %>%
  html_nodes("#gsc_rsb_st") %>%
  .[[1]] %>%
  html_table() %>%
  .[1, "All"]

# Download images in advance so we don't rely on img.shields.io at rendering time.
imgs <- list(
  cv = "https://img.shields.io/badge/Curriculum%20Vitae--_.svg?style=social&logo=giphy",
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  # Numbers for Twitter/X and LinkedIn need to be updated manually
  twitter = "https://img.shields.io/badge/X-9k-_.svg?style=social&logo=x",
  linkedin = "https://img.shields.io/badge/LinkedIn-11k-_.svg?style=social&logo=linkedin",
  sponsors = sprintf("https://img.shields.io/github/sponsors/terrytangyuan?label=Sponsors&style=social&logoColor=EA4AAA"),
  citations = sprintf("https://img.shields.io/badge/Citations-%sk-_.svg?style=social&logo=google-scholar", round(citations / 1000, digits = 1))
)

for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}
