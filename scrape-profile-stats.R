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
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  twitter = "https://img.shields.io/twitter/follow/TerryTangYuan?label=Twitter&style=social",
  linkedin = "https://img.shields.io/badge/LinkedIn--_.svg?style=social&logo=linkedin",
  sponsors = "https://img.shields.io/badge/Sponsors--_.svg?style=social&logo=github&logoColor=EA4AAA",
  citations = sprintf("https://img.shields.io/badge/Citations-%sk-_.svg?style=social&logo=google-scholar", round(citations / 1000, digits = 1)),
  zhihu = sprintf("https://img.shields.io/badge/%s--_.svg?style=social&logo=zhihu", URLencode("知乎", reserved = TRUE)),
  weibo = sprintf("https://img.shields.io/badge/%s--_.svg?style=social&logo=sina-weibo", URLencode("微博", reserved = TRUE))
)

for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}
