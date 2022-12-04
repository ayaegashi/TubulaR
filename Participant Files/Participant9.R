data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)

# Warmup: Please use piping in order to find the number of cars in the
# mtcars dataset with horsepower of over 100.

mtcars %>% mutate(big_hp = between(hp,100,1000000000)) %>% summarise(count = sum(big_hp))

mtcars %>% filter(hp > 100) %>% count()


# Question 1: What is the average (mean) Wind speed in the dataset?

airquality %>% summarise(avg = mean(Wind))

# Question 2: What is the average (mean) temperature across May and June?

airquality %>% group_by(Month) %>% summarise(sum = sum(Wind), cnt = n())

(360.3+308) / (31+30)

# Question 3: What is the maximum wind speed during August?

airquality %>% group_by(Month) %>% summarize(max = max(Wind))

# Question 4: Create a new column called “Hot” which is 1 if Temp is above 80 and 0 otherwise.
# (Upload a screenshot of your dataset.) How many cold observations are there?
# hint: consider using the ifelse() function in R


airquality %>% mutate(Hot = as.integer((Temp > 80))) %>% summarise(sum = sum(Hot)) # 68
airquality %>% mutate(blah = as.integer((Temp > -100000))) %>% summarise(sum = sum(blah)) # 153

153-68
