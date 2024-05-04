# Load necessary libraries
library(ggplot2)
library(gplots)
library(cluster)
library(stats)
library(dplyr)
library(e1071)
library(tidyr)
library(data.table)
library(lubridate)
library(base)
library(rfm)

# Load dataset
retail <- Online_Retail

# Preliminary data exploration
glimpse(retail)

# Identify missing values in key columns
sum(is.na(retail$CustomerID))
sum(is.na(retail$Description))

# Replace missing customer IDs with zero
retail$CustomerID[is.na(retail$CustomerID)] <- 0

# Remove entries with unknown customers
retail_df <- retail[retail$CustomerID != 0, ]
View(retail_df)

# Recheck the cleaned data
glimpse(retail_df)

# Customer Segmentation Analysis

# Create a unique customer dataframe
cx <- data.frame(unique(retail_df$CustomerID))
colnames(cx)[1] <- "CustomerID"

# Set analysis reference date
reference_date <- mdy("12-15-2011")  # Use a date after the latest in the dataset

# Convert invoice date to date format
retail_df$InvoiceDate <- as.Date(retail_df$InvoiceDate, '%m/%d/%Y %H:%M')

# Calculate recency in days from reference date
retail_df$Recency <- as.numeric(reference_date - retail_df$InvoiceDate)
head(retail_df)

# Determine minimum recency for each customer
recency_cx <- retail_df %>%
  group_by(CustomerID) %>%
  summarize(Recency = min(Recency))

# Calculate frequency of purchases for each customer
customer_frequency_df <- aggregate(InvoiceNo ~ CustomerID, data = retail_df, FUN = function(x) length(unique(x)))
colnames(customer_frequency_df) <- c("CustomerID", "Frequency")
frequency_cx <- customer_frequency_df[customer_frequency_df$Frequency > 0, , drop = FALSE]
head(frequency_cx)

# Calculate total spend per customer
retail_df$TotalSpend <- retail_df$Quantity * retail_df$UnitPrice
monetary_value_cx <- retail_df %>%
  group_by(CustomerID) %>%
  summarise(MonetaryValue = sum(TotalSpend, na.rm = TRUE))
head(monetary_value_cx)

# Combine Recency, Frequency, and Monetary value data for RFM analysis
RFM_df <- recency_cx %>%
  full_join(frequency_cx, by = "CustomerID") %>%
  full_join(monetary_value_cx, by = "CustomerID")
head(RFM_df)

# Classify recency, frequency, and monetary values into quartiles
RFM_df$RecencyClass <- cut(RFM_df$Recency, quantile(RFM_df$Recency, probs = seq(0, 1, 0.25)), include.lowest = TRUE, ordered_result = TRUE, labels = c("Very Recent", "Recent", "Moderately Recent", "Historical"))
RFM_df$FrequencyClass <- cut(jitter(RFM_df$Frequency), quantile(jitter(RFM_df$Frequency), probs = seq(0, 1, 0.25)), include.lowest = TRUE, ordered_result = TRUE, labels = c("Rare", "Sporadic", "Routine", "Frequent"))
RFM_df$MonetoryClass <- cut(RFM_df$MonetaryValue, quantile(RFM_df$MonetaryValue, probs = seq(0, 1, 0.25)), include.lowest = TRUE, ordered_result = TRUE, labels = c("Insignificant", "Minimal", "Standard", "Major"))

# Visualize RFM segmentation
RFM_plot <- ggplot(RFM_df, aes(RFM_df$RecencyClass, RFM_df$FrequencyClass)) +
  geom_count() +
  facet_grid(RFM_df$MonetoryClass ~ .) +
  labs(x = "Recency Class", y = "Frequency Class", title = "RFM Analysis")
RFM_plot

# Clustering customers using K-means
set.seed(2020)
k_means_clusters <- kmeans(scale(RFM_df[, 2:4]), 3, nstart = 1)
RFM_df$Cluster <- as.factor(k_means_clusters$cluster)

# Analyze cluster characteristics
k_means_agg_group <- RFM_df %>%
  group_by(Cluster) %>%
  summarise(
    'User Count' = n(),
    'Avg. Recency' = scales::comma(mean(Recency)),
    'Avg. Frequency' = scales::comma(mean(Frequency)),
    'Avg. Monetary Value ($)' = scales::comma(mean(MonetaryValue)),
    'Cluster Earnings ($)' = scales::comma(sum(MonetaryValue))
  )

# Visualize user count per cluster
Cluster_size_visz <- ggplot(k_means_agg_group, aes(Cluster, `User Count`)) +
  geom_text(aes(label = `User Count`), vjust = -0.3) +
  geom_bar(aes(fill = Cluster), stat = 'identity') +
  ggtitle('User Count per Cluster') +
  xlab("Cluster Number") +
  theme_classic()
print(Cluster_size_visz)
