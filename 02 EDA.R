library(ggplot2)
library(magrittr)
library(gridExtra)

load('data/Queries_2015-10-05.RData')

import::from(dplyr, group_by, select, summarize,
             right_join, left_join, ungroup, mutate,
             keep_where = filter)

queried_samples <- wdqs_queries %>%
  keep_where(sample == 'yes') %>%
  right_join(sample_queries, by = 'query') %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id')

# Proportion of users who executed the sample queries:
100*length(unique(queried_samples$user_id))/nrow(users)

# Total queries and sample queries
p1 <- queried_samples %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line(size = 1.5) + ylab("Number of queries") +
  wmf::theme_fivethirtynine()
p2 <- wdqs_queries %>%
  group_by(date) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n)) +
  geom_line(size = 1.5) + ylab("Number of queries") +
  wmf::theme_fivethirtynine()

dir.create('figures')

png('figures/queries.png', width = 12, height = 6,
    units = "in", res = 300)
grid.arrange(p2, p1, nrow = 2)
dev.off()
rm(p1, p2, queried_samples)
