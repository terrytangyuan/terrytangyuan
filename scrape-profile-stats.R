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
  cv = "https://img.shields.io/badge/CV--_.svg?style=social&logo=giphy",
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  # twitter = "https://img.shields.io/twitter/follow/TerryTangYuan?label=Twitter&style=social",
  linkedin = "https://img.shields.io/badge/LinkedIn-4k-_.svg?style=social&logo=linkedin",
  mastodon = "https://img.shields.io/mastodon/follow/109697385486067962?domain=https%3A%2F%2Ffosstodon.org&label=Mastodon&style=social",
  sponsors = sprintf("https://img.shields.io/github/sponsors/terrytangyuan?label=Sponsors&style=social&logoColor=EA4AAA"),
  citations = sprintf("https://img.shields.io/badge/Citations-%sk-_.svg?style=social&logo=google-scholar", round(citations / 1000, digits = 1)),
  wechat = sprintf("https://img.shields.io/badge/%s--_.svg?style=social&logo=wechat", URLencode("WeChat", reserved = TRUE))
)

for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}
