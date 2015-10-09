library(ggplot2)
library(magrittr)
library(gridExtra)

dir.create('figures')

load('data/Queries_2015-10-05.RData')

import::from(dplyr, group_by, select, summarize,
             right_join, left_join, ungroup, mutate,
             keep_where = filter)

# Proportion of users who executed the sample queries:
100*length(unique(queried_samples$user_id))/nrow(users)

# Sample queries
ggsave(plot = wdqs_queries %>%
  keep_where(sample == 'definitely yes') %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id') %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line() + ylab("Number of queries") +
  ggtitle("Queries that are definitely examples") +
  theme_bw(),
  filename = 'figures/sample_queries_1.png',
  width = 8, height = 12)
ggsave(plot = wdqs_queries %>%
  keep_where(sample == 'probably yes') %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id') %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line() + ylab("Number of queries") +
  ggtitle("Queries that are probably examples") +
  theme_bw(),
  filename = 'figures/sample_queries_2.png',
  width = 8, height = 12)
ggsave(plot = wdqs_queries %>%
  keep_where(sample == 'maybe') %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id') %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line() + ylab("Number of queries") +
  ggtitle("Queries that are maybe examples") +
  theme_bw(),
  filename = 'figures/sample_queries_3.png',
  width = 8, height = 12)

# png('figures/sample_queries.png', width = 12, height = 6,
#     units = "in", res = 300)
# grid.arrange(p1, p2, p3, nrow = 2)
# dev.off()
# rm(p1, p2, p3)

ggsave(plot = wdqs_queries %>%
  keep_where(sample %in% c('definitely yes', 'probably yes')) %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id') %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line() + ylab("Number of queries") +
  ggtitle("Queries that are definitely or probably examples") +
  theme_bw(),
  filename = 'figures/sample_queries_4.png',
  width = 8, height = 12)
ggsave(plot = wdqs_queries %>%
  keep_where(sample != 'definitely no') %>%
  select(c(example, user_id, date)) %>%
  left_join(users, by = 'user_id') %>%
  group_by(date, example) %>%
  summarize(n = n()) %>%
  ggplot(data = ., aes(x = date, y = n, color = example)) +
  geom_line() + ylab("Number of queries") +
  ggtitle("Definitely, probably, and maybe examples") +
  theme_bw(),
  filename = 'figures/sample_queries_5.png',
  width = 8, height = 12)

## Distances
# We need to investigate whether we can use a threshold of, say, 200:
#> sum(grepl("where the ?mayor has P21 (sex or gender) female", wdqs_queries$query, fixed = TRUE))/nrow(wdqs_queries)
# 2% of the queries include that comment

distances <- wdqs_queries$query %>%
  grep("where the ?mayor has P21 (sex or gender) female", ., fixed = TRUE, value = TRUE) %>%
  adist(example_queries['largest cities female mayor'])

png('figures/distance.png', width = 8, height = 8, units = "in", res = 120)
hist(distances, freq = FALSE, ylab = "", yaxt = "n",
     main = "Example query: largest cities with female mayors",
     sub = "User-submitted vs sample we provided",
     xlab = "Generalized Levenshtein (edit) distance",
     col = "cornflowerblue", border = "white", breaks = 20)
lines(density(distances[, 1], adjust = 200), lwd = 2)
dev.off()

temp <- wdqs_queries$query %>%
  grep("where the ?mayor has P21 (sex or gender) female", ., fixed = TRUE, value = TRUE) %>%
  grid_nchar(example_queries['largest cities female mayor'])
png('figures/distance_normalized.png', width = 8, height = 8, units = "in", res = 120)
hist(distances/temp, freq = FALSE, ylab = "", yaxt = "n",
     main = "Example query: largest cities with female mayors",
     sub = "User-submitted vs sample we provided",
     xlab = "Normalized Levenshtein (edit) distance",
     col = "cornflowerblue", border = "white", breaks = 20)
lines(density(distances[, 1]/temp[, 1], adjust = 200), lwd = 2)
dev.off()
rm(temp)

png('figures/distances.png', width = 14, height = 14, units = "in", res = 120)
par(mfrow = c(7, 5))
for ( i in 1:ncol(distances_2) ) {
  hist(distances_2[, i], freq = FALSE, ylab = "", yaxt = "n",
       main = colnames(distances_2)[i], xlab = "Distance",
       col = "cornflowerblue", border = "white",
       xlim = c(0, 2000))
  lines(density(distances_2[, i], adjust = 4), lwd = 2)
}
dev.off()

png('figures/distances_norm.png', width = 14, height = 14, units = "in", res = 120)
par(mfrow = c(7, 5))
for ( i in 1:ncol(distances_3) ) {
  hist(distances_3[, i], freq = FALSE, ylab = "", yaxt = "n",
       main = colnames(distances_3)[i], xlab = "Normalized Distance",
       col = "cornflowerblue", border = "white",
       xlim = c(0, 1))
  lines(density(distances_3[, i], adjust = 4), lwd = 2)
}
dev.off()

png('figures/distances_odds.png', width = 14, height = 14, units = "in", res = 120)
par(mfrow = c(7, 5))
for ( i in 1:ncol(distances_3) ) {
  hist((1-distances_3[, i])/distances_3[, i], freq = FALSE, ylab = "", yaxt = "n",
       main = colnames(distances_3)[i], xlab = "Normalized Distance",
       col = "cornflowerblue", border = "white",
       xlim = c(0, 5))
  lines(density((1-distances_3[, i])/distances_3[, i], adjust = 4), lwd = 2)
}
dev.off()

png('figures/min_distance.png', width = 8, height = 8, units = "in", res = 120)
hist(apply(distances_3, 1, min),
     freq = FALSE, yaxt = "n", ylab = "",
     xlab = "Levenshtein distance",
     main = "Minimum distance between query and example",
     col = "cornflowerblue", border = "white")
dev.off()

# hist(wdqs_queries$pseudo_odds, xlim = c(0, 20), breaks = 1000)
