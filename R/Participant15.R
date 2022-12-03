data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)


# Warmup: Please use piping in order to find the number of cars in the
# mtcars dataset with horsepower of over 100.

View(mtcars)
mtcars %>%
  count(hp > 100)

# Question 1: What is the average (mean) Wind speed in the dataset?

airquality %>%
  summarise(mean_wind = mean(Wind))

# Question 2: What is the average (mean) temperature across May and June?

airquality %>%
  group_by(Month) %>%
  summarise(mean_temp = mean(Temp))
# May: 65.5
# June: 79.1

# Question 3: What is the maximum wind speed during August?

airquality %>%
  group_by(Month) %>%
  summarise(max_wind = max(Wind))
# August: 15.5

# Question 4: Create a new column called “Hot” which is 1 if Temp is above 80 and 0 otherwise.
# (Upload a screenshot of your dataset.) How many cold observations are there?
# hint: consider using the ifelse() function in R

airquality$Hot <- airquality$Temp
airquality$Hot %>%
  factor(ifelse(Hot<80, "0", "1"))


df1<-data.frame(x)
df1$x_Factor<-factor(ifelse(df1$x<25,"Low","High"))
df1

