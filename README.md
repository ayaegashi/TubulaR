# TubulaR: An augmented version of Unravel for novice learners of piping in R.

## Project by RunLin Wang and Ayana Yaegashi

Unravel is an R addin introduced at UIST '21 by Nischal Shrestha, Titus Barik, and Chris Parnin. Unravel helped data scientists understand fluent programming (function composition via pipes) through a visual interface. The original Unravel [paper](http://nischalshrestha.me/docs/unravel.pdf) can be found here, and its corresponding GitHub repository is here: https://github.com/nischalshrestha/Unravel. Most of this project's code is based heavily off of Unravel.

We build additional features off of Unravel to make it more tailored for novice learners of piping in R. These features include a more informative pop up dialog and a "Help" tab with a cheatsheet of piping functions in the `dplyr` package in R. We call this version with augmented features TubulaR, referencing piping and the programming language R.

To install TubulaR, run the following code in RStudio.

```r
# install.packages('devtools')
devtools::install_github('ayaegashi/TubulaR')
```

# Usage

Download our repository and run the "Unravel.Rproj" file after installing TubulaR using the code above. In this R environment, TubulaR has access to the web-scraped links and information that is incorporated into the pop up boxes. 

With TubulaR, you can visualize `dplyr` or `tidyr` code which opens up a Shiny app in RStudio. The easiest way to use TubulaR is to highlight the tidyverse code you want to visualize, then go to Addins -\> Unravel code. This will open up the app on the Viewer pane in RStudio by default. If you want to respect your currently chosen browser window, you can pass `viewer = FALSE` using the programmatic way shown below.

This style of coding always involves starting with a source of data. So, the first expression or line is "locked" such that you can't enable/disable or reorder it and other operations can't be reordered before the first line (as shown at the end of the GIF above).

You can also invoke it programmatically using the following function by wrapping or piping your code to the function:

```r
# wrapped
Unravel::unravel(
  mtcars %>%
    group_by(cyl) %>% 
    summarise(mean_mpg = mean(mpg))
)
# piped
mtcars %>%
  group_by(cyl) %>% 
  summarise(mean_mpg = mean(mpg)) %>%
  Unravel::unravel()
```
