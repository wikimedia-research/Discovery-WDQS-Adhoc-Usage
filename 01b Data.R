library(readr)
library(magrittr)
wdqs_queries <- read_csv('data/wdqs_queries.csv',
                         col_types = 'cccccccccccccccccc')

# Known user-submitted queries where a sample query was used:
sample_queries <- data.frame(query = c(wdqs_queries$query[wdqs_queries$timestamp == "2015-09-03 18:35:24"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-09-03 14:57:52"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-10-04 21:26:47"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-09-28 16:59:13"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-10-02 12:46:45"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-10-04 17:42:27"]),
                             example = c('US presidents and spouses',
                                         'Largest cities with female mayors',
                                         "Lord's cricket ground",
                                         'Places in Paris',
                                         'Male Americans born between 1875 and 1930',
                                         'Cactaceae taxon'))

# Filter out rows with nonconforming timestamps:
wdqs_queries %<>% dplyr::filter(grepl("^(2015\\-[0-9]{2}\\-[0-9]{2} [0-9]{2}\\:[0-9]{2}\\:[0-9]{2})$", timestamp))

wdqs_queries$timestamp %<>% lubridate::ymd_hms()
wdqs_queries$date %<>% as.Date()

# Assign unique user ids to group queries by:
wdqs_queries %<>%
  dplyr::mutate(user_id = factor(as.numeric(factor(paste0(client_ip, user_agent)))),
                browser_major = paste(browser, browser_major)) %>%
  dplyr::select(-c(os_major, os_minor, os_patch, os_patch_minor,
                   browser_minor, browser_patch, browser_patch_minor,
                   client_ip, user_agent))

# Separate the users out into their own table:
users <- wdqs_queries %>%
  dplyr::select(c(user_id, os, browser, browser_major, device, countries)) %>%
  unique()

# Remove reduntant user data:
wdqs_queries %<>%
  dplyr::select(-c(os, browser, browser_major, device, countries))

# Mark queries as definitely being example queries:
wdqs_queries %<>%
  dplyr::mutate(sample = ifelse(query %in% sample_queries$query,
                  "definitely yes", "definitely no"))

## Okay, time for soft-matching...

# Utility functions:
"%notin%" <- function(x, y) !(x %in% y)
condense <- function(x) {
  return(gsub("(^\\s)|(\\s$)", "", gsub("\\s+", " ", x)))
}
grid_nchar <- function(x, y) {
  x <- sapply(x, nchar); y <- sapply(y, nchar)
  n <- length(x); m <- length(y)
  temp <- matrix(0, nrow = n, ncol = m)
  for ( i in 1:n ) {
    for ( j in 1:m ) {
      temp[i, j] <- max(x[i], y[j])
    }
  }
  return(temp)
}

sample_queries %<>% dplyr::mutate(query_condensed = condense(query))

# Let's load in and crop example queries compiled from:
# - https://www.mediawiki.org/wiki/Wikibase/Indexing/SPARQL_Query_Examples
# - https://github.com/smalyshev/pywikibot-core/blob/prefer/prefer.py#L36
# - https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/queries
example_queries <- suppressWarnings(
  dir('examples') %>%
    file.path('examples/', .) %>%
    lapply(readLines) %>%
    lapply(paste0, collapse = "\n") %>%
    condense
)
names(example_queries) <- dir('examples') %>%
  gsub('_', ' ', .) %>%
  sub('\\.sparql', '', .)

wdqs_queries %<>%
  dplyr::mutate(query_condensed = condense(query),
                length = nchar(query),
                length_condensed = nchar(query_condensed))

example_queries %<>% strtrim(width = max(wdqs_queries$length_condensed))

wdqs_queries$query_id <- 1:nrow(wdqs_queries)

### Some initial values for 
# temp <- adist(sample_queries$query_condensed, example_queries)
# rownames(temp) <- sample_queries$example
# round(temp/grid_nchar(sample_queries$query_condensed, example_queries), 3)
# round(1 - temp/grid_nchar(sample_queries$query_condensed, example_queries), 3)
# (1-temp/grid_nchar(sample_queries$query_condensed, example_queries)) %>% { ./(1-.) }
### Distance => Normalized Distance => "Pseudo Probability" => "Pseudo Odds"
# #                                         us presidents and spouses
# # US presidents and spouses               0 => 0 => 1.000 => Inf
# #                                         largest cities female mayor
# # Largest cities with female mayors       414 => 0.369 => 0.631 => 1.7077295
# #                                         places in Paris
# # Places in Paris                         1 => 0.001 => 0.999 => 886.0000000
# #                                         near lords cricket ground
# # Lord's cricket ground                   91 => 0.063 => 0.937 => 14.8791209
# #                             male americans born between 1875 1930
# # Male Americans born between 1875 and 1930    0 => 0 => 1.000 => Inf
# #                                         cactaceae taxa
# # Cactaceae taxon                         224 => 0.180 => 0.820 => 4.5491071
# rm(temp)
### Okay, settling on pseudo odds of 4 as the threshold
### with 2-4 being "eh, idk, maybe, but probably not"

## Calculate the Levenshtein distance between each query
##   and each sample query we have on file:
adist_progress <- function(x, y) {
  n <- length(y); temp <- matrix(0, nrow = length(x), ncol = n)
  pb <- txtProgressBar(min = 0, max = n, style = 3)
  for ( i in 1:n ) {
    temp[, i] <- adist(x, y[i])[, 1]
    setTxtProgressBar(pb, i)
  }; close(pb)
  if ( !is.null(names(x)) ) rownames(temp) <- names(x)
  if ( !is.null(names(y)) ) colnames(temp) <- names(y)
  return(temp)
}
distances_2 <- adist_progress(wdqs_queries$query, example_queries)

## Normalize the distance by the max edit distance (length of longer string):
max_edit_distances <- grid_nchar(wdqs_queries$query_condensed, example_queries)
distances_3 <- distances_2/max_edit_distances

save(list = c('distances_2', 'max_edit_distances', 'distances_3'), file = 'data/distances.rda')

# Find the smallest distance. We will use this later.
wdqs_queries$min_distance <- apply(distances_3, 1, min)
wdqs_queries %<>%
  dplyr::mutate(pseudo_probability = 1 - min_distance,
                pseudo_odds = pseudo_probability/(1-pseudo_probability))
wdqs_queries$example <- colnames(distances_3)[apply(distances_3, 1, which.min)]

# Mark queries as being samples or not:
wdqs_queries %<>%
  dplyr::mutate(sample = ifelse(pseudo_odds >= 4 & sample != "definitely yes",
                                "probably yes", sample)) %>%
  dplyr::mutate(sample = ifelse(pseudo_odds < 4 & pseudo_odds >= 2 & sample %notin% c('definitely yes', 'probably yes'),
                                "maybe?", sample)) %>%
  dplyr::mutate(sample = factor(sample)) %>%
  dplyr::select(-c(min_distance))

save(list = c('wdqs_queries', 'users', 'sample_queries'),
     file = 'data/Queries_2015-10-05.RData')

rm(list = ls())
