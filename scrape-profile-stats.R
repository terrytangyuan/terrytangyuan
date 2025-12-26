library(rvest)
library(httr)

gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"

# Default to last known value in case scraping fails
citations_formatted <- "9.5k"

tryCatch({
  citations <- gscholar_link %>%
    httr::GET(config = httr::config(ssl_verifypeer = FALSE)) %>%
    read_html() %>%
    html_nodes("#gsc_rsb_st") %>%
    .[[1]] %>%
    html_table() %>%
    .[1, "All"]
  
  # Format citations for badge (e.g., 9400 -> "9.4k")
  citations_num <- as.numeric(gsub(",", "", citations))
  
  # Only format if we got a valid number in the thousands range
  if (!is.na(citations_num) && citations_num >= 1000 && citations_num < 1000000) {
    citations_formatted <- sprintf("%.1fk", citations_num / 1000)
  }
}, error = function(e) {
  # If scraping fails, use default value
  message("Warning: Could not scrape citations. Using default value. Error: ", e$message)
})

readme_loc <- "README.md"

# Download images in advance so we don't rely on img.shields.io at rendering time.
imgs <- list(
  cv = "https://img.shields.io/badge/Curriculum%20Vitae--_.svg?style=social&logo=giphy",
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  sponsors = "https://img.shields.io/github/sponsors/terrytangyuan?label=Sponsors&style=social&logoColor=EA4AAA",
  mastodon = "https://img.shields.io/mastodon/follow/109697385486067962?domain=https%3A%2F%2Ffosstodon.org&label=Mastodon&style=social",
  # Numbers for X, LinkedIn, and Substack need to be updated manually
  twitter = "https://img.shields.io/badge/X-9.9k-_.svg?style=social&logo=x",
  linkedin = "https://img.shields.io/badge/LinkedIn-21.2k-_.svg?style=social&logo=linkedin",
  citations = sprintf("https://img.shields.io/badge/Citations-%s-_.svg?style=social&logo=google-scholar", citations_formatted),
  substack = "https://img.shields.io/badge/Substack-1.2k-_.svg?style=social&logo=substack"
)

for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}
