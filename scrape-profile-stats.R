library(rvest)
library(httr)

gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"

# Default to last known value in case scraping fails
citations_formatted <- "9.4k"

# Retry logic with exponential backoff and random jitter
max_retries <- 5
success <- FALSE

# Add initial random delay to avoid predictable patterns (1-3 seconds)
initial_delay <- runif(1, 1, 3)
message(sprintf("Adding initial delay of %.1f seconds before first request...", initial_delay))
Sys.sleep(initial_delay)

for (attempt in 1:max_retries) {
  tryCatch({
    # Add comprehensive browser headers to appear more like a real browser
    user_agent <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    citations <- gscholar_link %>%
      httr::GET(
        config = httr::config(
          ssl_verifypeer = FALSE,
          followlocation = TRUE
        ),
        httr::user_agent(user_agent),
        httr::add_headers(
          "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language" = "en-US,en;q=0.9",
          "Accept-Encoding" = "gzip, deflate, br",
          "DNT" = "1",
          "Connection" = "keep-alive",
          "Upgrade-Insecure-Requests" = "1",
          "Sec-Fetch-Dest" = "document",
          "Sec-Fetch-Mode" = "navigate",
          "Sec-Fetch-Site" = "same-origin",
          "Sec-Fetch-User" = "?1",
          "Cache-Control" = "max-age=0",
          "Referer" = "https://scholar.google.com/"
        )
      ) %>%
      read_html() %>%
      html_nodes("#gsc_rsb_st") %>%
      .[[1]] %>%
      html_table() %>%
      .[1, "All"]
    
    # Validate that we got citations data
    if (is.null(citations) || is.na(citations) || citations == "") {
      stop("No citations data retrieved")
    }
    
    # Format citations for badge (e.g., 9400 -> "9.4k")
    citations_num <- as.numeric(gsub(",", "", citations))
    
    # Only format if we got a valid number in the thousands range
    if (!is.na(citations_num) && citations_num >= 1000 && citations_num < 1000000) {
      citations_formatted <- sprintf("%.1fk", citations_num / 1000)
      message("Successfully scraped citations: ", citations_formatted)
      success <- TRUE
      break  # Success, exit the retry loop
    }
  }, error = function(e) {
    if (attempt < max_retries) {
      # Calculate delay with exponential backoff: 2^attempt seconds + random jitter
      base_delay <- 2^attempt
      jitter <- runif(1, 0, 2)  # Add 0-2 seconds of random jitter
      delay <- base_delay + jitter
      message(sprintf("Attempt %d failed: %s. Retrying in %.1f seconds...", attempt, e$message, delay))
      Sys.sleep(delay)
    } else {
      message("Warning: Could not scrape citations after ", max_retries, " attempts. Using default value. Error: ", e$message)
    }
  })
}

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

# Validate downloaded SVGs
cat("\nValidating downloaded SVG files...\n")
validation_result <- system("python validate_svg.py imgs", intern = FALSE)
if (validation_result != 0) {
  stop("SVG validation failed! Please check the downloaded files.")
}
