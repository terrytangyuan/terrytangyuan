library(rvest)
library(httr)

# Link to Google Scholar profile
gscholar_link <- "https://scholar.google.com/citations?user=2GYttqUAAAAJ&hl=en"

# These fallback values will be used when they cannot be extracted from existing SVG files or scraped from websites
total_followers_fallback <- "57.6k"
substack_formatted_fallback <- "1.6k"
citations_formatted_fallback <- "13.1k"

# Numbers for X and LinkedIn need to be updated manually
twitter_followers <- "10.1k"
linkedin_followers <- "25.4k"

# Helper function to create HTTP GET request with browser headers
make_browser_request <- function(url) {
  user_agent <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  
  url %>%
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
        "Sec-Fetch-Site" = "none",
        "Sec-Fetch-User" = "?1",
        "Cache-Control" = "max-age=0"
      )
    )
}

# Helper function to format numbers as "X.Xk" (e.g., 9400 -> "9.4k")
format_thousands <- function(number) {
  if (!is.na(number) && number >= 1000 && number < 1000000) {
    return(sprintf("%.1fk", number / 1000))
  }
  return(NULL)
}

# Helper function for retry logic with exponential backoff
retry_with_backoff <- function(scrape_fn, max_retries = 3, service_name = "service") {
  result <- NULL
  
  # Add initial random delay to avoid predictable patterns (1-3 seconds)
  initial_delay <- runif(1, 1, 3)
  message(sprintf("Adding initial delay of %.1f seconds before first %s request...", initial_delay, service_name))
  Sys.sleep(initial_delay)
  
  for (attempt in 1:max_retries) {
    tryCatch({
      result <- scrape_fn()
      
      if (!is.null(result)) {
        message(sprintf("Successfully scraped %s: %s", service_name, result))
        break
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
        message(sprintf("Warning: Could not scrape %s after %d attempts. Error: %s", service_name, max_retries, e$message))
      }
    })
  }
  
  return(result)
}

# Helper function to parse formatted numbers like "12.3k" or "1.4k" to numeric
parse_formatted_number <- function(formatted) {
  if (is.null(formatted) || is.na(formatted) || formatted == "") {
    return(NULL)
  }
  tryCatch({
    if (grepl("[kK]$", formatted)) {
      return(as.numeric(sub("[kK]$", "", formatted)) * 1000)
    }
    if (grepl("[mM]$", formatted)) {
      return(as.numeric(sub("[mM]$", "", formatted)) * 1000000)
    }
    return(as.numeric(formatted))
  }, error = function(e) {
    return(NULL)
  })
}

# Helper function to update a hardcoded fallback variable in this script.
# The path is intentionally hardcoded because this script is always executed
# from the repository root in CI, and rstudioapi is unavailable non-interactively.
update_hardcoded_value <- function(var_name, new_value) {
  script_path <- "scrape-profile-stats.R"
  tryCatch({
    lines <- readLines(script_path, warn = FALSE)
    # Allow optional spaces around the assignment operator and handle both quote styles
    pattern <- sprintf('^%s\\s*<-\\s*["\'].*["\']', var_name)
    idx <- grep(pattern, lines)
    if (length(idx) > 0) {
      lines[idx] <- sprintf('%s <- "%s"', var_name, new_value)
      writeLines(lines, script_path)
      message(sprintf("Updated hardcoded %s to %s in script", var_name, new_value))
    }
  }, error = function(e) {
    message(sprintf("Warning: Could not update %s in script: %s", var_name, e$message))
  })
}

# Helper function to pick the larger of the SVG value and the hardcoded fallback,
# update the hardcoded value in the script if the SVG value is larger, and return
# the larger value to use as the working fallback.
get_max_fallback <- function(svg_value, hardcoded_value, var_name, label) {
  svg_num <- parse_formatted_number(svg_value)
  hardcoded_num <- parse_formatted_number(hardcoded_value)

  if (!is.null(svg_num) && !is.null(hardcoded_num)) {
    if (svg_num > hardcoded_num) {
      message(sprintf("SVG value (%s) is larger than hardcoded value (%s) for %s. Using SVG value and updating script.", svg_value, hardcoded_value, label))
      update_hardcoded_value(var_name, svg_value)
      return(svg_value)
    } else {
      message(sprintf("Hardcoded value (%s) >= SVG value (%s) for %s. Using hardcoded value.", hardcoded_value, svg_value, label))
      return(hardcoded_value)
    }
  } else if (!is.null(svg_num)) {
    message(sprintf("No valid hardcoded value for %s; using SVG value (%s) and updating script.", label, svg_value))
    update_hardcoded_value(var_name, svg_value)
    return(svg_value)
  } else if (!is.null(hardcoded_num)) {
    message(sprintf("No valid SVG value for %s; using hardcoded value (%s).", label, hardcoded_value))
    return(hardcoded_value)
  } else {
    stop(sprintf("No valid fallback available for %s (both SVG and hardcoded values are missing or unparseable).", label))
  }
}

# Helper function to extract value from SVG badge file
extract_value_from_svg <- function(svg_path) {
  # Regex pattern for numeric values with optional decimal and magnitude suffix
  numeric_pattern <- '[0-9]+\\.?[0-9]*[kKmMbBtT]?'
  
  tryCatch({
    if (!file.exists(svg_path)) {
      return(NULL)
    }
    
    # Read the SVG file
    svg_content <- paste(readLines(svg_path, warn = FALSE), collapse = "\n")
    
    # Extract value from aria-label attribute (e.g., "Citations: 9.5k" or "Followers: 52.8k")
    aria_match <- regmatches(svg_content, regexec(sprintf('aria-label="[^:]+:\\s*(%s)"', numeric_pattern), svg_content))
    if (length(aria_match[[1]]) > 1) {
      return(aria_match[[1]][2])
    }
    
    # Fallback: try to extract from text elements
    text_matches <- regmatches(svg_content, gregexpr(sprintf('<text[^>]*>(%s)</text>', numeric_pattern), svg_content, perl = TRUE))
    if (length(text_matches[[1]]) > 0) {
      # Get the last match as it's usually the actual value
      last_match <- tail(text_matches[[1]], 1)
      value_match <- regmatches(last_match, regexec(sprintf('>(%s)<', numeric_pattern), last_match))
      if (length(value_match[[1]]) > 1) {
        return(value_match[[1]][2])
      }
    }
    
    return(NULL)
  }, error = function(e) {
    message("Warning: Could not extract value from ", svg_path, ": ", e$message)
    return(NULL)
  })
}

# Scrape Google Scholar citations
scrape_citations <- function() {
  citations <- gscholar_link %>%
    make_browser_request() %>%
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
  formatted <- format_thousands(citations_num)
  
  if (is.null(formatted)) {
    stop("Invalid citations number (must be between 1,000 and 1,000,000): ", citations_num)
  }
  
  return(formatted)
}

# Default to the larger of the SVG value and the hardcoded fallback for citations
citations_formatted <- get_max_fallback(
  extract_value_from_svg("imgs/citations.svg"),
  citations_formatted_fallback,
  "citations_formatted_fallback",
  "citations"
)

# Try to scrape citations with retry logic
scraped_citations <- retry_with_backoff(scrape_citations, service_name = "citations")
if (!is.null(scraped_citations)) {
  citations_formatted <- scraped_citations
}

# Scrape Substack followers
scrape_substack <- function() {
  substack_link <- "https://substack.com/@terrytangyuan"
  
  substack_page <- substack_link %>%
    make_browser_request() %>%
    read_html()
  
  # Try to extract subscriber/follower count from the page
  # Look for patterns like "1,200 subscribers" or similar
  page_text <- substack_page %>% html_text()
  
  # Try various patterns to find subscriber count
  subscriber_match <- regexpr("([0-9,]+)\\s+(subscriber|follower)s?", page_text, ignore.case = TRUE, perl = TRUE)
  
  if (subscriber_match[[1]] > 0) {
    matched_text <- regmatches(page_text, subscriber_match)
    
    # Extract just the number with proper error handling
    if (length(matched_text) > 0) {
      number_match <- regmatches(matched_text, regexpr("[0-9,]+", matched_text))
      
      if (length(number_match) > 0 && length(number_match[[1]]) > 0) {
        subscriber_num <- as.numeric(gsub(",", "", number_match[[1]]))
        formatted <- format_thousands(subscriber_num)
        
        if (!is.null(formatted)) {
          return(formatted)
        }
      }
    }
  }
  
  stop("Could not find subscriber count in Substack page")
}

# Default to the larger of the SVG value and the hardcoded fallback for Substack
substack_formatted <- get_max_fallback(
  extract_value_from_svg("imgs/substack.svg"),
  substack_formatted_fallback,
  "substack_formatted_fallback",
  "Substack"
)

# Try to scrape Substack with retry logic
scraped_substack <- retry_with_backoff(scrape_substack, service_name = "Substack followers")
if (!is.null(scraped_substack)) {
  substack_formatted <- scraped_substack
}

# Download all images (except for total followers) in advance so we don't rely on img.shields.io at rendering time.
imgs <- list(
  cv = "https://img.shields.io/badge/Curriculum%20Vitae--_.svg?style=social&logo=giphy",
  github = "https://img.shields.io/github/followers/terrytangyuan.svg?label=GitHub&style=social",
  sponsors = "https://img.shields.io/github/sponsors/terrytangyuan?label=Sponsors&style=social&logoColor=EA4AAA",
  mastodon = "https://img.shields.io/mastodon/follow/109697385486067962?domain=https%3A%2F%2Ffosstodon.org&label=Mastodon&style=social",
  citations = sprintf("https://img.shields.io/badge/Citations-%s-_.svg?style=social&logo=google-scholar", citations_formatted),
  substack = sprintf("https://img.shields.io/badge/Substack-%s-_.svg?style=social&logo=substack", substack_formatted),
  twitter = sprintf("https://img.shields.io/badge/X-%s-_.svg?style=social&logo=x", twitter_followers),
  linkedin = sprintf("https://img.shields.io/badge/LinkedIn-%s-_.svg?style=social&logo=linkedin", linkedin_followers)
)
for (i in 1:length(imgs)) {
  download.file(imgs[[i]], sprintf('imgs/%s.svg', names(imgs)[[i]]), mode = 'wb')
}

# Calculate total followers by running the Python script
# Default to the larger of the SVG value and the hardcoded fallback for total followers
total_followers <- get_max_fallback(
  extract_value_from_svg("imgs/followers.svg"),
  total_followers_fallback,
  "total_followers_fallback",
  "total followers"
)

tryCatch({
  total_followers_result <- system("python3 calculate_total_followers.py", intern = TRUE)
  if (!is.null(total_followers_result) && length(total_followers_result) > 0 && nchar(total_followers_result[[1]]) > 0) {
    total_followers <- total_followers_result[[1]]
    message("Total followers calculated: ", total_followers)
  } else {
    message("Warning: Could not calculate total followers. Using default value: ", total_followers)
  }
}, error = function(e) {
  message("Warning: Error calculating total followers. Using default value: ", total_followers, ". Error: ", e$message)
})

# Download this one separately since we'll be using all updated and downloaded SVGs to calculate the total followers
download.file(sprintf("https://img.shields.io/badge/Followers-%s-_.svg?style=social", total_followers), 'imgs/followers.svg', mode = 'wb')

# Validate downloaded SVGs
cat("\nValidating downloaded SVG files...\n")
validation_result <- system("python validate_svg.py imgs", intern = FALSE)
if (validation_result != 0) {
  stop("SVG validation failed! Please check the downloaded files.")
}
