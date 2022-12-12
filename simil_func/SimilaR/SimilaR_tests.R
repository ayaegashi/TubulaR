library(SimilaR)
library(tidyverse)
library(dplyr)

full_df <- read.csv("/Users/runlinwang/Downloads/Unravel_279/simil_func/SimilaR/all_dplyr_funcs.csv")

full <- substr(c(full_df$X0),1,nchar(c(full_df$X0))-2)

nice <- t(combn(full,2))

for (x in 1:10) {
  func1 <- noquote(nice[[x,1]])
  func2 <- noquote(nice[[x,2]])
  SimilaR_fromTwoFunctions(func1,func2)
}

SimilaR_fromTwoFunctions(arrange,mutate)

SimilaR_fromTwoFunctions(func1,func2)
print(func1)