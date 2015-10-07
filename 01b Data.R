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
  mutate(sample = ifelse(query %in% sample_queries$query,
                         "yes", "no"))

## Okay, time for soft-matching...

# Let's load in and crop example queries compiled from:
# - https://www.mediawiki.org/wiki/Wikibase/Indexing/SPARQL_Query_Examples
# - https://github.com/smalyshev/pywikibot-core/blob/prefer/prefer.py#L36
# - https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/queries
example_queries <- suppressWarnings(
  dir('examples') %>%
    file.path('examples/', .) %>%
    lapply(readLines) %>%
    lapply(paste0, collapse = "\n") %>%
    strtrim(width = 1630) # max(sapply(wdqs_queries$query, nchar))
)

library(stringdist) # install.packages('stringdist')
# temp <- optimize(f = function(p) {
#   sum(ain(sample_queries$query, example_queries,
#           maxDist = 100, method = "jw", p = p))
# }, interval = c(0.001, 0.25), maximum = TRUE)
# temp
# 
# wdqs_queries$sample <- ifelse(ain(sample_queries$query, example_queries, maxDist = temp$maximum),
#                               "probably", wdqs_queries$sample)

# ain(example_queries, sample_queries$query, maxDist = temp$maximum)

wdqs_queries$query_id <- 1:nrow(wdqs_queries)

save(list = c('wdqs_queries', 'users', 'sample_queries'),
     file = 'data/Queries_2015-10-05.RData')

rm(list = ls())
