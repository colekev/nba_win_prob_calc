# Creating an NBA Win Probability Calculator

The 2016-2017 NBA season is on the horizon, so I put together a win probability calculator in R that I can use on live games this upcoming season.

There were a number of interesting wrinkles to the data gathering, cleaning and model-building process, which I will walk through below. You can view my [R code here](https://github.com/colekev/nba_win_prob_calc/blob/master/nba_win_prob.R).

## The Data

I didn't do an exhaustive search to find the perfectly formatted NBA play-by-play data, but I still found multiple years of free data (2006-2012) on [BasketBallValue.com](http://basketballvalue.com/downloads.php). 

It wasn't the cleanest data, as you can see below.

![pbp_clean](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_preClean.png)

After I cleaned the data and had all the relevant information in a workable format, I combined the play-by-play data with historical closing point spreads for every game. (I reached out to [Sports Insights](https://www.sportsinsights.com/), which generously provided me the point spread data). Once I had the matching dates and vistor/home team abbreviations on both data frames, the `leftjoin()` function from the [dplyr package](https://cran.rstudio.com/web/packages/dplyr/vignettes/introduction.html) worked beautifully to combine them.

![pbp_clean_pos](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_posClean.png)

## The Process

I had all the data I needed for each possession to build a robust win probability calculator: the closing point spread, time remaining, point differential, possession and whether the visiting team ended up winning the game. 

#### The Models

I used logistic regression to model the likelihood of victory for the visiting team on each possession by applying the `glm()` [function in R](http://www.statmethods.net/advstats/glm.html) using the "binomial" family to the training data set. 

To get a micro view of the data, I picked one game out of the cross-validation set to check if the output looked logical.

![log_game](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinProb.png)

I made one major adjustment to the predicted probabilities from the model to make end-game results more sensical. When the time remaining equaled zero, the team with the positive point differential was set to a win probability of 1.0, and the trailing team to 0.0.

As a check on the reasonableness of my model, I looked up the historical win probability graph from [the site inpredictable](http://stats.inpredictable.com/nba/wpBox.php?season=2010&month=10&date=2010-10-26&gid=0021000003&pregm=odds) for comparison.

![inpredict_graph](https://github.com/colekev/nba_win_prob_calc/blob/master/images/inpredict.png)

#### Adjustments

A comparison of the game charts shows that the win probability movements in my model are likely too dramatic early in the game, and that the win probability should be much higher for the equivalent point differential later in the game. 

Fitting one logistic regression model to the entire length of the game could be causing larger errors in the predicted probabilities at the ends of the chart. In order to more heavily weight the nearby or local conditions in the regression calculation, I used the [locfit package](https://cran.r-project.org/web/packages/locfit/locfit.pdf) in R. Locfit uses a similar local regression smoothing/fitting technique as the more commonly known `loess` regression method, but can be applied to not only linear regression, but also logistic regression. The locfit should improve the models ability by varying the the weighting scheme based on the local conditions, not those of the entire data set.

In addition to using local fitting, I also trained and applied different locfit models based on how much time remained, with the time windows shrinking as game progressed. The best fit I found during the cross-validation process was to separate the data by quarter and train a different model for each. I also separated out the last two minutes of the game into its own model, when factos like time remaining and possession become more important.

The updated results now look more similar to the inpredictable calculator.

![loc_graph](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinProbLoc_byQtr.png)

And the mean squared error for each time remaining increment using the adjusted locfit model is lower than that of the GLM/binomial model, with the most dramatic improvements at beginnings and ends of games.

![glm_versus_loc](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinErrorDiff.png)

## Potential Issues and Next Steps

While I'm happy with the error improvement in the new model, there is still a material difference in how far the Lakers' win probability falls in the last minute of the game in my model versus inpredictable's. My model gives much less credit to the Lakers as 6.5-point favorites. This makes intuitive sense: the point spread's effect on win probability should be much lower with fewer possessions remaining. But, my model also doesn't account for the possibility of overtime, where there will be many more possessions for the favorite to impose its assumed strength.

The [Cheap Talk blog](https://cheaptalk.org/2009/06/10/the-overtime-spike-in-nba-basketball/) found that 6.26% of NBA regular season games from 1997 to 2009 went to overtime, which is more siginificant than you'd think, but probably not high enough to cause such a large benefit to the favorite in terms of late-game win probability.

I plan to continue to refine my model, in particular adding more late game features to improve the accuracy of win probabilities. I also want to build a front-end [shiny app](http://shiny.rstudio.com/) that will enable users to search and display historical win probability charts.
