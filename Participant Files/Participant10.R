data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)

# Warmup: Please use piping in order to find the number of cars in the
# mtcars dataset with horsepower of over 100.

mtcars %>%
  filter(hp > 100) %>%
  count()

# Question 1: What is the average (mean) Wind speed in the dataset?
airquality %>%
  summarise(mean_mpg = mean(Wind))

# 9.957516

# Question 2: What is the average (mean) temperature across May and June?
airquality %>%
  filter(Month == 5 | Month == 6) %>%
  summarise(mean_mpg = mean(Wind))

# 10.95574


# Question 3: What is the maximum wind speed during August?
airquality %>%
  filter(Month == 8) %>%
  summarise_all(max)

# 15.5

# Question 4: Create a new column called “Hot” which is 1 if Temp is above 80 and 0 otherwise.
# (Upload a screenshot of your dataset.) How many cold observations are there?
# hint: consider using the ifelse() function in R
new_aq <- airquality %>%
  mutate(Hot = ifelse(Temp>80, 1, 0)) %>%
  filter(Hot == 0) %>%
  count()

# 85
