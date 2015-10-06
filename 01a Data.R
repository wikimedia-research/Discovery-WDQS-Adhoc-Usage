library(magrittr)
library(readr)
library(urltools)
library(jsonlite)
library(rgeolocate)
library(uaparser)

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

get_wdqs_queries <- function(date = NULL) {
  ## Date handling
  if (is.null(date)) {
    date <- Sys.Date() - 1
  }
  ## Date subquery
  subquery <- date_clause(date)
  ## Build the hive query
  wdqs_queries_query <- paste("USE wmf;
                                SELECT ts AS timestamp, CONCAT('query.wikidata.org/', uri_query) AS uri, user_agent, client_ip, referer
                                FROM webrequest",
                                subquery,
                                "AND webrequest_source = 'misc'
                                AND uri_host = 'query.wikidata.org'
                                AND uri_path = '/bigdata/namespace/wdq/sparql'
                                AND INSTR(uri_query, '?query=') > 0;")
  ## Execute it
  wdqs_queries <- query_hive(wdqs_queries_query)
  ## Cleanup
  ## Decode queries
  wdqs_queries$query <- url_decode(url_parameters(wdqs_queries$uri, "query")$query)
  wdqs_queries$uri <- NULL
  ## Get rid of empty rows
  wdqs_queries <- wdqs_queries[wdqs_queries$query != "", ]
  
  wdqs_queries$countries <- maxmind(ips = wdqs_queries$client_ip,
                                    file = "/usr/local/share/GeoIP/GeoIP2-Country.mmdb",
                                    fields = "country_name")$country_name
  
  wdqs_queries_ua <- parse_agents(wdqs_queries$user_agent)
  wdqs_queries <- cbind(wdqs_queries, wdqs_queries_ua)
  
  wdqs_queries$date <- date
  
  ## Parse JSON geocoded data
  # geocoded_data <- wdqs_queries$geocoded_data %>% sapply(fromJSON) %>% unname %>% t %>% as.data.frame
  # names(geocoded_data) <- c("city", "country_code", "longitude", "postal_code", "timezone", "subdivision", "continent", "latitude", "country")
  # wdqs_queries$geocoded_data <- NULL
  # wdqs_queries %<>% cbind(., geocoded_data)
  
  ## Save results
  readr::write_csv(wdqs_queries, 'wdqs_queries.csv',
                   append = file.exists('wdqs_queries.csv'))
}

# get_wdqs_queries() # test run
lapply(seq(as.Date("2015-08-23"), Sys.Date()-1, "day"), get_wdqs_queries)
