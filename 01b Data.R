extracted_queries <- dir('~/Documents/Data/WDQS Queries', '.*\\.RData')
temp <- list()
for ( f in extracted_queries ) {
  load(file.path('~/Documents/Data/WDQS Queries', f))
  temp[[f]] <- wdqs_queries
}; rm(f)

wdqs_queries <- dplyr::bind_rows(temp)
rm(temp, extracted_queries)
