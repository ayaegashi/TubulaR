data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)


# Warmup: Please use piping in order to find the number of cars in the
# mtcars dataset with horsepower of over 100.

mtcars %>%
  summary(hp>100)


# Question 1: What is the average (mean) Wind speed in the dataset?

airquality %>%
  select(Wind) %>%
  mean()

mean(airquality$Wind)

# Question 2: What is the average (mean) temperature across May and June?






# Question 3: What is the maximum wind speed during August?

aq_august <- subset(airquality, subset = airquality$Month == "8")
summary(aq_august)

# Question 4: Create a new column called “Hot” which is 1 if Temp is above 80 and 0 otherwise.
# (Upload a screenshot of your dataset.) How many cold observations are there?
# hint: consider using the ifelse() function in R
airquality %>%
  mutate(Hot = if_else(Temp > 80, 1, 0))


