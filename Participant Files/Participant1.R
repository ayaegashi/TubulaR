data(mtcars)
data(airquality)
library(dplyr)
library(tidyverse)

mtcars %>%
  filter(hp > 100) %>%
  nrow()


# Question 1
airquality %>%
  summary()


# Question 2
airquality %>%
  filter(Month == 5 | Month == 6) %>%
  summary()


# Question 3
airquality %>%
  filter(Month == 8) %>%
  summary()


# Question 4 mydf$TempBin <- as.numeric(mydf$Temp > 70)
airquality$Hot <- airquality %>%
                    as.numeric(Temp > 80)

