library(dplyr)
library(readr)
library(ggplot2)
library(stringr)
library(tidyr)
library(zoo)
library(data.table)
library(locfit)
library(chron)
library(rpart)

# Get files from urls, unzip and read into data frames
temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20120510040.zip",temp)
pbp2012 <- read.table(unz(temp, "playbyplay20120510040.txt"), sep="\t", header=TRUE)
unlink(temp)

temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20102011reg20110416.zip",temp)
pbp2011 <- read.table(unz(temp, "playbyplay20102011reg20110416.txt"), sep="\t", header=TRUE)
unlink(temp)

temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20092010reg20100418.zip",temp)
pbp2010 <- read.table(unz(temp, "playbyplay20092010reg20100418.txt"), sep="\t", header=TRUE)
unlink(temp)

temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20082009reg20090420.zip",temp)
pbp2009 <- read.table(unz(temp, "playbyplay20082009reg20090420.txt"), sep="\t", header=TRUE)
unlink(temp)

temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20072008reg20081211.zip",temp)
pbp2008 <- read.table(unz(temp, "playbyplay20072008reg20081211.txt"), sep="\t", header=TRUE)
unlink(temp)

temp <- tempfile()
download.file("http://www.basketballvalue.com/publicdata/playbyplay20070420.zip",temp)
pbp2007 <- read.table(unz(temp, "playbyplay200704201041.txt"), sep="\t", header=TRUE)
unlink(temp)

pbp <- rbind(pbp2012, pbp2011, pbp2010, pbp2009, pbp2008, pbp2007)

# Add columns for teams (home, away) and score

pbp <- pbp %>%
    mutate(v = substr(GameID, 9, 11), h = substr(GameID, 12, 14), # Get vistor and home team names from GameID
           score = gsub(".*\\[(.*)\\].*", "\\1", Entry), poss = substr(score, 1, 3), # Take score info from within brackets
           points = substring(score, 5)) %>%
    separate(points, c("pointsA", "pointsB"), "-") %>% 
    mutate(pointsV = as.numeric(ifelse(poss == v, pointsA, pointsB)), # Assign vistor and home points based on matching w/ team names
           pointsH = as.numeric(ifelse(poss == h, pointsA, pointsB)), 
           pointDiffV = pointsV - pointsH) %>%
    select(-score, -pointsA, -pointsB)

# Turn blanks into NA for future replacement and remove non-scores that were in the brackets
pbp[pbp==""]  <- NA

remove <- c(" Gasol, James", " Harden, West", " Amundson, Bonner", "Roberts gains possession)",
  "AUTO", "COACH LINE", "AB", "AUTO COACH LINE")

for (word in remove){
    pbp[pbp == word] <- NA
}
# Replacing random "Dou" from poss with v

pbp <- mutate(pbp, poss = ifelse(poss == "Dou", v, poss))

# Replace NAs in points with previous row's value, filling in possessions w/o scoring

pbp <- pbp %>%
    group_by(GameID) %>%
    mutate(pointsV = na.locf(pointsV, na.rm=FALSE), 
           pointsH = na.locf(pointsH, na.rm=FALSE))

# Calculate who won and lost
## First fill in NAs with 0
pbp[is.na(pbp)]  <- 0

## Add winner to all columns
pbp <- pbp %>%
    mutate(lead = ifelse(pointsV >= pointsH, v, h)) %>%
    group_by(GameID) %>%
    arrange(LineNumber) %>%
    mutate(winner = tail(lead, n = 1))

## Add visitor win as binary 0 or 1
pbp$winV <- ifelse(pbp$winner == pbp$v, 1, 0)

# Add vistor point diff
pbp$ptDiffV <- as.numeric(pbp$pointsV) - as.numeric(pbp$pointsH)

## Transform TimeRemaining into minutes remaining
pbp$timeRemainMin <- 60 * 24 * as.numeric(times(pbp$TimeRemaining))

# Add vistor posession columns (binary)
pbp$possV <- ifelse(pbp$poss == pbp$h, 1, 0)

# Covert dates to Date objects
pbp$date <- as.Date(str_sub(pbp$GameID, 1, 8), "%Y%m%d")

#### Join point spread data
# Read in NBA point spread data from Sports Insights and only keep relevant columns, convert dates
odds <- read_csv("~/Downloads/NBA Odds - Sheet1.csv")

odds$event_date <- gsub(" 0:00","", odds$event_date) # remove time from event date

odds <- odds %>%
    mutate(date = as.Date(event_date, "%m/%d/%y")) %>%
    select(date, visitor_team, home_team, `Latest Line`)

colnames(odds) <- c("date", "v", "h", "line") # rename columns to match pbp data

odds <- odds %>%
    mutate(lineV = -line) %>%
    select(-line)

# First convert team names to the abbreviation used in pbp data
nameToAbbr <- function(column) {
    str_replace_all(column, "New Orleans Pelicans", "NOR") %>%
    str_replace_all("San Antonio Spurs", "SAS") %>%
    str_replace_all("Milwaukee Bucks", "MIL") %>%
    str_replace_all("Denver Nuggets", "DEN") %>%
    str_replace_all("Phoenix Suns", "PHX") %>%
    str_replace_all("Brooklyn Nets", "NJN") %>%
    str_replace_all("Philadelphia 76ers", "PHI") %>%
    str_replace_all("Oklahoma City Thunder", "OKC") %>%
    str_replace_all("Portland Trail Blazers", "POR") %>%
    str_replace_all("Minnesota Timberwolves", "MIN") %>%
    str_replace_all("Washington Wizards", "WAS") %>%
    str_replace_all("Cleveland Cavaliers", "CLE") %>%
    str_replace_all("Utah Jazz", "UTA") %>%
    str_replace_all("Houston Rockets", "HOU") %>%
    str_replace_all("Charlotte Hornets", "CHA") %>%
    str_replace_all("Indiana Pacers", "IND") %>%
    str_replace_all("Dallas Mavericks", "DAL") %>%
    str_replace_all("Atlanta Hawks", "ATL") %>%
    str_replace_all("Chicago Bulls", "CHI") %>%
    str_replace_all("Detroit Pistons", "DET") %>%
    str_replace_all("Boston Celtics", "BOS") %>%
    str_replace_all("Golden State Warriors", "GSW") %>%
    str_replace_all("Orlando Magic", "ORL") %>%
    str_replace_all("Toronto Raptors", "TOR") %>%
    str_replace_all("Miami Heat", "MIA") %>%
    str_replace_all("New York Knicks", "NYK") %>%
    str_replace_all("Sacramento Kings", "SAC") %>%
    str_replace_all("Los Angeles Clippers", "LAC") %>%
    str_replace_all("Memphis Grizzlies", "MEM") %>%
    str_replace_all("Seattle Supersonics", "SEA") %>%
    str_replace_all("Los Angeles Lakers", "LAL")
}

odds$h <- nameToAbbr(odds$h)
odds$v <- nameToAbbr(odds$v)

## Join odds data frame with pbp
# Only need to change one abbreviation in pbp to match odds data
pbp$v <- str_replace_all(pbp$v, "NOH", "NOR")
pbp$h <- str_replace_all(pbp$h, "NOH", "NOR")

# Join data by teams and date to add odds
pbp <- left_join(pbp, odds, by = c("v", "h", "date"))

# Get rid of columns we don't need and put into a readable order
pbp <- ungroup(pbp) %>% select(GameID, date, v, h, lineV, timeRemainMin, ptDiffV, possV, winV)

# Train set to 2009-2010 seasons and earlier
train <- filter(pbp, date <= as.Date("2010-09-01"))

# Cross-validation set 2010-2011 season
crossVal <- filter(pbp, date <= as.Date("2011-09-01"), date > as.Date("2010-10-01"))

# Test set 2011-2012 season
test <- filter(pbp, date <= as.Date("2012-09-01"), date > as.Date("2011-10-01"))

## use GLM logistic regression using timeRemaining, pt diff, possession & point spread (or line)
# start with 0
model <- glm(winV ~ timeRemainMin + ptDiffV + possV + lineV, family=binomial, data=train)
crossVal$est <- predict(model, newdata = crossVal, type="response")
crossVal$estH <- 1 - crossVal$est

# Make sure final score win probability goes to 1.0 or 0 based only on point differential
crossVal <- mutate(crossVal, est = ifelse(timeRemainMin == 0 & ptDiffV > 0, 1, 
                                          ifelse(timeRemainMin == 0 & ptDiffV < 0, 0, 
                                                 ifelse(est > 1, 1, 
                                                        ifelse(est < 0, 0, est)))), estH = 1 - est)

## Using locfit model to test against GLM regression
model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, data=train, family="binomial")
crossVal$estLoc <- predict(model, newdata = crossVal, type = "response")
crossVal$estHLoc <- 1 - crossVal$estLoc

crossVal <- mutate(crossVal, estLoc = ifelse(timeRemainMin == 0 & ptDiffV > 0, 1, 
                              ifelse(timeRemainMin == 0 & ptDiffV < 0, 0, 
                                     ifelse(estLoc > 1, 1, 
                                            ifelse(est < 0, 0, estLoc)))), estHLoc = 1 - estLoc)

# See results on single game for illustration
game <- filter(crossVal, GameID == "20101026HOULAL")

plot <- ggplot(game, aes(timeRemainMin, estLoc))

plot + geom_line(color = "red") + 
    scale_x_reverse() +
    geom_line(aes(timeRemainMin, estHLoc), color = "purple") +
    fte_theme() + 
    labs(x = "Time Remaining", y = "Win Prob", title = "10/26/2010: Lakers 112, Rockets 110")

ggsave("nbaWinProbLoc.png") # save graph

## Develop an error metric to judge the CV results. Logisitc regression, only adjusting final win probability
# Add error to each row, also create minute buckets
crossVal <- mutate(crossVal, error = winV - est, errorLoc = winV - estLoc, sqrError = error^2, 
                sqrErrorLoc = errorLoc^2, minError = round(timeRemainMin, 0))

error <- group_by(crossVal, minError) %>% 
    summarise(count = n(), rtmeanSqrError = sqrt(mean(sqrError)), rtmeanSqrErrorLoc = sqrt(mean(sqrErrorLoc))) %>%
    mutate(diffError = rtmeanSqrError - rtmeanSqrErrorLoc)

# Graph bar chart to see

ggplot(error,aes(minError,rtmeanSqrErrorLoc)) + geom_bar(stat="identity") + scale_x_reverse() +
    labs(title = "GLM - LocFit")

ggsave("nbaWinErrorLoc.png")

## Use separate models for each quarter to see if results improve
q1_train <- filter(train, timeRemainMin <= 48, timeRemainMin >36)
q1_cv <- filter(crossVal, timeRemainMin <= 48, timeRemainMin >36)

q2_train <- filter(train, timeRemainMin <= 36, timeRemainMin >24)
q2_cv <- filter(crossVal, timeRemainMin <= 36, timeRemainMin >24)

q3_train <- filter(train, timeRemainMin <= 24, timeRemainMin >12)
q3_cv <- filter(crossVal, timeRemainMin <= 24, timeRemainMin >12)

q4_train <- filter(train, timeRemainMin <= 12, timeRemainMin >2)
q4_cv <- filter(crossVal, timeRemainMin <= 12, timeRemainMin >2)

q4_2_train <- filter(train, timeRemainMin <= 2)
q4_2_cv <- filter(crossVal, timeRemainMin <= 2)

#Separate model for each quarter
q1_model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, family="binomial", data=q1_train)
q2_model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, family="binomial", data=q2_train)
q3_model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, family="binomial", data=q3_train)
q4_model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, family="binomial", data=q4_train)
q4_2_model <- locfit(winV ~ timeRemainMin + ptDiffV + possV + lineV, family="binomial", data=q4_2_train)

q1_cv$estLoc <- predict(q1_model, newdata = q1_cv, type="response")
q1_cv$estHLoc <- 1 - q1_cv$estLoc

q2_cv$estLoc <- predict(q2_model, newdata = q2_cv, type="response")
q2_cv$estHLoc <- 1 - q2_cv$estLoc

q3_cv$estLoc <- predict(q3_model, newdata = q3_cv, type="response")
q3_cv$estHLoc <- 1 - q3_cv$estLoc

q4_cv$estLoc <- predict(q4_model, newdata = q4_cv, type="response")
q4_cv$estHLoc <- 1 - q4_cv$estLoc

q4_2_cv$estLoc <- predict(q4_2_model, newdata = q4_2_cv, type="response")
q4_2_cv$estHLoc <- 1 - q4_2_cv$estLoc


#Combine
total <- rbind(q1_cv, q2_cv, q3_cv, q4_cv, q4_2_cv)

total <- ungroup(total)

total <- mutate(total, estLoc = ifelse(timeRemainMin == 0 & ptDiffV > 0, 1, 
                                       ifelse(timeRemainMin == 0 & ptDiffV < 0, 0, 
                                              ifelse(estLoc > 1, 1, 
                                                     ifelse(estLoc < 0, 0, estLoc)))), estHLoc = 1 - estLoc)

#Regraph game
game <- filter(total, GameID == "20101026HOULAL")

plot <- ggplot(game, aes(timeRemainMin, estLoc))

plot + scale_x_reverse() +
    geom_line(aes(timeRemainMin, estHLoc), color = "purple") +
    fte_theme() + 
    labs(x = "Time Remaining", y = "Win Prob", title = "10/26/2010: Lakers 112, Rockets 110") +
    coord_cartesian(ylim = c(0,1))

ggsave("nbaWinProbLoc_byQtr.png") # save graph

#Recalculate the error
total <- mutate(total, errorLoc = winV - estLoc,sqrErrorLoc = errorLoc^2, minError = round(timeRemainMin, 0))

error <- group_by(total, minError) %>% 
    summarise(count = n(), rtmeanSqrErrorLoc = sqrt(mean(sqrErrorLoc)))

# Graph bar chart to see

ggplot(error,aes(minError,rtmeanSqrErrorLoc)) + geom_bar(stat="identity") + scale_x_reverse()

ggsave("nbaWinErrorLoc_qtr_2.png")
