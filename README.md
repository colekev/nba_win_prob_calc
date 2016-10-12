# Creating an NBA Win Probability Calculator

The 2016 NBA season is on the horizon, so I put together a win probabilty calculator in R that I can hopefully use on live games this upcoming season.

There were a number of interesting wrinkles to the data gathering, cleaning and model-building process, which I will walk through below.

## The Data

I didn't do an exhaustive search to find the perfect NBA play-by-play data, but I still found multiple years of data (2006-2012) for free on [BasketBallValue.com](http://basketballvalue.com/downloads.php). 

It wasn't the cleanest data, as you can see below.

![pbp_clean](https://github.com/colekev/nba_win_prob_calc/blob/master/images/pbp_preClean.png)
