library(magrittr)
library(readr)

# query_hive; provided with a hive query it writes it out to file and then calls Hive over said file, reading the results
# and cleaning up after isself nicely when done.
query_hive <- function(query){
  
  # Write query out to tempfile and create tempfile for results.
  query_dump <- tempfile()
  cat(query, file = query_dump)
  results_dump <- tempfile()
  
  # Query and read in the results
  system(paste0("export HADOOP_HEAPSIZE=1024 && hive -f ", query_dump, " > ", results_dump))
  results <- readLines(results_dump) # includes a lot of hive garbage output we need to sanitize out
  results <- results %>%
    grep("parquet\\.hadoop", x = ., invert = TRUE, value = TRUE) %>%
    paste0(collapse = "\n") %>%
    readr::read_tsv(col_names = TRUE)
  
  # Clean up and return
  file.remove(query_dump, results_dump)
  return(results)
}

# date_clause; provided with a date it generates an appropriate set of WHERE clauses for HDFS partitioning.
date_clause <- function(date){
  return(paste("WHERE year = ", lubridate::year(date),
               "AND month = ", lubridate::month(date),
               "AND day = ", lubridate::day(date)))
}

get_wdqs_referers <- function(date = NULL) {
  ## Date handling
  if (is.null(date)) {
    date <- Sys.Date() - 1
  }
  ## Date subquery
  subquery <- date_clause(date)
  ## Build the hive query
  wdqs_queries_query <- paste("USE wmf;
                              SELECT referer, COUNT(*) as n
                              FROM webrequest",
                              subquery,
                              "AND webrequest_source = 'misc'
                              AND uri_host = 'query.wikidata.org'
                              AND uri_path IN('', '/')
                              GROUP BY referer;")
  ## Execute it
  wdqs_queries <- query_hive(wdqs_queries_query)
  wdqs_queries$date <- date
  
  ## Save results
  readr::write_csv(wdqs_queries, 'wdqs_referers.csv',
                   append = file.exists('wdqs_referers.csv'))
}

lapply(seq(as.Date("2015-08-23"), Sys.Date()-1, "day"), get_wdqs_referers)

