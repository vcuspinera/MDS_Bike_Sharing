# author: Aman Kumar Garg, Victor Cuspinera-Contreras, Yingping Qian 
# date: 2020-01-22

"Cleans, splits and pre-processes (denormalized) the Bike sharing data (from https://archive.ics.uci.edu/ml/datasets/bike+sharing+dataset).
Writes the training and test data to separate csv files.

Usage: src/data_wrangling.r --input=<input> --out_dir=<out_dir>
  
Options:
--input=<input>       Path (including filename) to raw data (csv file)
--out_dir=<out_dir>   Path (excluding filename) to directory where the processed data should be written
" -> doc

library(tidyverse)
library(caret)
library(docopt)
set.seed(2020)

opt <- docopt(doc)
main <- function(input, out_dir){
  #' 
  #' Preprocess the data file and split into train and test sets
  #'
  #' @param input, str, the input data source
  #' @param out_dir, str, the path where the output will be stored
  #' 

  # Load the data
  raw_data <- read_csv(input)
  
  # Drop the unnecessary columns 
  raw_data <- raw_data %>%
    select(-instant, -dteday, -yr, -casual, -registered) 
  
  # Denormalize the temp, atemp, hum and windspeed columns
  denormalized_data <- raw_data %>%
    mutate(temp = temp * 47 + 8,
           atemp = atemp * 66 + 16,
           hum = hum * 100,
           windspeed = windspeed * 67)
  
  # Calculate mean windspeed of each season
  wind_mean <- denormalized_data %>%
    group_by(season) %>%
    summarise(wind = mean(windspeed))
  
  # fill in 0 values in windspeed with mean windspeed of each season
  denormalized_data <- denormalized_data %>% 
    mutate(windspeed = case_when((windspeed == 0 & season == 1) ~ wind_mean[[1,2]],
                                 (windspeed == 0 & season == 2) ~ wind_mean[[2,2]],
                                 (windspeed == 0 & season == 3) ~ wind_mean[[3,2]],
                                 (windspeed == 0 & season == 4) ~ wind_mean[[4,2]],
                                 TRUE ~ windspeed))
  
  # Transform the workingday back to categorical column 
  denormalized_data <- denormalized_data %>% 
    mutate(weekday = as.character(weekday))
  denormalized_data <- denormalized_data %>% 
    mutate(weekday = case_when(weekday == 0 ~ "Sunday",
                               weekday == 1 ~ "Monday",
                               weekday == 2 ~ "Tuesday",
                               weekday == 3 ~ "Wednesday",
                               weekday == 4 ~ "Thursday",
                               weekday == 5 ~ "Friday",
                               weekday == 6 ~ "Saturday",
                               TRUE ~ weekday))
  
  # split the data into 80% train and 20% test sets
  training_rows <- denormalized_data %>% 
    select(cnt) %>% 
    pull() %>%
    createDataPartition(p = 0.80, list = FALSE)
  training_data <- denormalized_data %>% 
    slice(training_rows)
  test_data <- denormalized_data %>% 
    slice(-training_rows)
  
  # write training and test data to feather files
  write_csv(training_data, paste0(out_dir, "/training_data.csv"))
  write_csv(test_data, paste0(out_dir, "/test_data.csv"))

}

test_check <- function(out_dir){
  #' 
  #' checks if the output files exist and print out the last modified date
  #'
  #' @param out_dir, str, the path where the output will be stored
  #'

  file_1 <-"/training_data.csv"
  file_2 <- "/test_data.csv"
  
  file_list = c(file_1, file_2)
  
  for (i in file_list) {
    file_path = paste0(out_dir, i)
    if (file_test("-f", file_path)) {
      print(paste(i, "is generated on", file.info(file_path)$ctime))
    } else {
      print(paste(i, "is not found!"))
    }
  }
  
}

main(opt[["--input"]], opt[["--out_dir"]])

test_check(opt[["--out_dir"]])
