# Creating an NBA Win Probability Calculator

The 2016-2017 NBA season is on the horizon, so I put together a win probability calculator in R that I can hopefully use on live games this upcoming season.

There were a number of interesting wrinkles to the data gathering, cleaning and model-building process, which I will walk through below. You can view my [R code here](https://github.com/colekev/nba_win_prob_calc/blob/master/nba_win_prob.R).

## The Data

I didn't do an exhaustive search to find the perfect NBA play-by-play data, but I still found multiple years of data (2006-2012) for free on [BasketBallValue.com](http://basketballvalue.com/downloads.php). 

It wasn't the cleanest data, as you can see below.

![pbp_clean](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_preClean.png)

Without going into it in painstaking detail, I'll only say that data cleaning took some than a few lines of code. Once the data was cleaned and I had all the relevant information, I combined that data frame with historical point spreads (generously provided by [Sports Insights](https://www.sportsinsights.com/)). It also took some renaming of the point spread data to combine it with the play-by-play data, but once I had the matching dates and vistor/home team abbreviations, the `leftjoin()` function from the [dplyr package](https://cran.rstudio.com/web/packages/dplyr/vignettes/introduction.html) worked beautifully to combine the data.

![pbp_clean_pos](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_posClean.png)

## The Process

Now I had all the data I needed for each possession to build a robust win probability calculator: the closing point spread, time remaining, point differential, possession (categorical) and whether the visiting team ended up winning the game. The goal is to use these data to estimate the probability of the visiting team winning for every possession line.

#### The Models

The most logical classifier to use for predicting a categorical outcome, like whether the visiting team was going to win or not, is logistic regression. I applied the `glm()` [function in R](http://www.statmethods.net/advstats/glm.html) using the "binomial" family to the training data set.

For illustrative purposes, I picked out one game out of the cross-validation set to check if the output looked logical.

![log_game](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinProb.png)

I made one major adjustment to the predicted probabilities to make the end-game results more sensical, and that was to make sure when the time remaining equaled zero, the team with the positive point differential was at a win probability of 1.0, and the trailing team at 0.0.

As a check on the reasonableness of my model, I used the historical win probability graph from [the site inpredictable](http://stats.inpredictable.com/nba/wpBox.php?season=2010&month=10&date=2010-10-26&gid=0021000003&pregm=odds).

![inpredict_graph](https://github.com/colekev/nba_win_prob_calc/blob/master/images/inpredict.png)

While the general shape of the Lakers' win percentage curve on my graph (purple) mirrored that of inpredictable's, the end-of-game movements for inpredictable are much more dramatic. 

#### Adjustments

Simply looking at the game chart shows clearly that the win probability movements are likely too rigid early in the game when point differential movements should be less significant, and that the win probability should be much higher for the equivalent point different later in the game. 

In order to more heavily weight the the nearby or local condition in the regression calculation, I chose to use the [locfit package](https://cran.r-project.org/web/packages/locfit/locfit.pdf) in R, which uses similar local regression smoothing/fitting as the more commonly known `loess` regression method, but available to apply to logistic regression.

In addition to using local fitting, I also trained and applied different models to the cross-validation set based on time remaining, with the time windows shrinking as game progressed.

The results now look much more similar to the inpredictable calculator.

![loc_graph](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinProbLoc_byQtr.png)

And the mean squared error for each minute increment in the cross-validation set is now lower than that of the logistic regression using GLM, with the most dramatic improvements near the beginnings and ends of games.

![glm_versus_loc](https://github.com/colekev/nba_win_prob_calc/blob/master/images/nbaWinErrorDiff.png)

## Potential Issues and Next Steps

While I'm happy with the error improvement in the new model, there is a clear difference in how far the Lakers' win probability falls in the last minute of the game in my model versus that of inpredictable. My model gives much less credit to the Lakers as 6.5-point favorites, with the win probability only moving marginally. My model makes more intuitive sense: the point spread's effect on win probability should be much lower with fewer possessions remaining. But, my model also doesn't account for the possibility that the game could go into overtime, where there will be many more possessions for the favorite to impose its superiority.

The [Cheap Talk blog](https://cheaptalk.org/2009/06/10/the-overtime-spike-in-nba-basketball/) found that 6.26% of NBA regular season games from 1997 to 2009 went to overtime, which is more siginificant than you'd think, but not high enough to cause such a large benefit to the favorite in terms of late-game win probability.

I plan to continue to refine my model, in particular adding late game features. The influence of overtime, whether or not teams are in the penalty, if teams' star players have fouled out, and if a team is particular good at shooting 3-pointers are all potentially significant for adjusting win probability.
