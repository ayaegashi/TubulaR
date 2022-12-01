data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)

# Warmup: Please use piping in order to find the number of cars in the
# mtcars dataset with horsepower of over 100.
mtcars %>% filter(hp > 100) %>% count()


# Question 1: What is the average (mean) Wind speed in the dataset?
airquality %>% summarise(mean_wind = mean(Wind))


# Question 2: What is the average (mean) temperature across May and June?
airquality %>% filter(Month == 5 | Month == 6) %>% summarise(avg_tmp = mean(Temp))


# Question 3: What is the maximum wind speed during August?
airquality %>% filter(Month == 8) %>% summarise(max_speed = max(Wind))



# Question 4: Create a new column called “Hot” which is 1 if Temp is above 80 and 0 otherwise.
# (Upload a screenshot of your dataset.) How many cold observations are there?
# hint: consider using the ifelse() function in R
airquality %>% add_column(Hot = ifelse(.$Temp > 80, 1, 0)) %>% summarise(count = sum(1 - Hot))

