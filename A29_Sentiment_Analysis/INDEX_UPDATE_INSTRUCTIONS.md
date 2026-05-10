## Index Update Instructions

Add the following card to the `ea030_activities` section in `index_v07.Rmd`,
after the existing activity entries:

```r
    list(icon = "💬", title = "Sentiment Analysis of Environmental News",
         desc   = "Measuring tone in environmental news with dictionary-based, aspect-based, and transformer methods. Build validated time-series sentiment indices from a text corpus using quanteda, sentimentr, tidytext, and the text package.",
         tag    = "NLP / text",
         href   = "activities/A29_Sentiment_Analysis.html",
         status = "1st Draft"),
```

This places the module at:
  docs/activities/A29_Sentiment_Analysis.html

The knit header in the Rmd file already targets this path.

Rename the source file to: A29_Sentiment_Analysis_v01.Rmd
