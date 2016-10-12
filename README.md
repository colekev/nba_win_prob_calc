# Creating an NBA Win Probability Calculator

The 2016 NBA season is on the horizon, so I put together a win probabilty calculator in R that I can hopefully use on live games this upcoming season.

There were a number of interesting wrinkles to the data gathering, cleaning and model-building process, which I will walk through below.

## The Data

I didn't do an exhaustive search to find the perfect NBA play-by-play data, but I still found multiple years of data (2006-2012) for free on [BasketBallValue.com](http://basketballvalue.com/downloads.php). 

It wasn't the cleanest data, as you can see below.

![pbp_clean](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_preClean.png)

Without going into it in painstaking detail, I'll only say that data cleaning took some than a few lines of code. Once the data was cleaned and I had all the relevant information, I combined that data frame with historical point spreads (generously provided by [Sports Insights](https://www.sportsinsights.com/)). It also took some renaming of the point spread data to combine it with the play-by-play data, but once I had the matching dates and vistor/home team abbreviation, the `leftjoin()` function from the [dplyr package](https://cran.rstudio.com/web/packages/dplyr/vignettes/introduction.html) worked beautifully to combine the data.

![pbp_clean_pos](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_posClean.png)

## The Process

Now I had all the data I needed for each possession to build a robust win probability calculator: the closing point spread, time remaining, point differential, possession (categorical) and whether the visiting team ended up winning the game. The goal is to use these data to estimate the probability of the visiting team winning for every possession line.

### The Models

The most logical classifer to use for predicting a categorical outcome, like whether the visiting team was going to win or not, is logistic regression. The `glm()` [function in R](http://www.statmethods.net/advstats/glm.html) using the "binomial" family

