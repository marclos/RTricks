---
  title: "Choosing Statistical Frameworks"
author: "Marc Los Huertos"
date: "EA030 · Compiled `r format(Sys.Date(), '%Y-%m-%d')`"
output:
  html_document:
  self_contained: true
theme: null
highlight: null
toc: false
---
  
  ```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo = TRUE,
  warning = FALSE,
  message = FALSE,
  fig.width = 3.4,
  fig.height = 3.2
)

library(ggplot2)
library(dplyr)
```

## Why variable types determine statistical models

> Statistical methods flow directly from the measurement scale of the dependent and independent variables.

```{r data}
aq <- airquality |> na.omit()
aq$Month <- factor(aq$Month)
aq$HighOzone <- aq$Ozone > 60
```

<table>
  <thead>
  <tr><th></th><th>Independent: Categorical</th><th>Independent: Continuous</th></tr>
  </thead>
  <tbody>
  <tr>
  <th>Dependent: Continuous</th>
  <td>
  <strong>t-test / ANOVA</strong><br>
  $Y_{ij}=\mu+\alpha_j+\varepsilon_{ij}$
  
  ```{r anova, echo=FALSE}
ggplot(aq, aes(Month, Temp)) + geom_boxplot(fill="#8aad96") + theme_minimal()
```
</td>
  <td>
  <strong>Linear regression</strong><br>
  $Y=\beta_0+\beta_1X+\varepsilon$
  
  ```{r lm, echo=FALSE}
ggplot(aq, aes(Wind, Ozone)) + geom_point() + geom_smooth(method="lm", se=FALSE) + theme_minimal()
```
</td>
  </tr>
  <tr>
  <th>Dependent: Categorical</th>
  <td>
  <strong>Chi-square / Logistic</strong><br>
  $\log\left(\frac{p}{1-p}\right)=\beta_0+\beta_1X$
  
  ```{r prop, echo=FALSE}
ggplot(aq, aes(Month, HighOzone)) + stat_summary(fun=mean, geom="point", size=3) + theme_minimal()
```
</td>
  <td>
  <strong>Logistic regression</strong><br>
  $p=\frac{1}{1+e^{-(\beta_0+\beta_1X)}}$
  
  ```{r logit, echo=FALSE}
ggplot(aq, aes(Temp, HighOzone)) + geom_jitter(height=.05, alpha=.4) + geom_smooth(method="glm", method.args=list(family="binomial"), se=FALSE) + theme_minimal()
```
</td>
  </tr>
  </tbody>
  </table>
  