library(readr)
library(magrittr)
wdqs_queries <- read_csv('data/wdqs_queries.csv',
                         col_types = 'cccccccccccccccccc')

sample_queries <- data.frame(query = c(wdqs_queries$query[wdqs_queries$timestamp == "2015-09-03 18:35:24"],
                                       wdqs_queries$query[wdqs_queries$timestamp == "2015-09-03 14:57:52"]),
                             example = c('US presidents and spouses', 'Largest cities with female mayors'))

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

wdqs_queries %<>%
  mutate(sample = ifelse(query %in% sample_queries$query,
                         "yes", "no"))

save(list = c('wdqs_queries', 'users', 'sample_queries'),
     file = 'data/Queries_2015-10-05.RData')

rm(list = ls())
