---
title: "Launch Shiny App Without Blocking the Session"
date: 2018-02-13
tags: ["R","Stan","Shiny"]
---

This is a neat trick I found on [Tyler Morgan-Wall's Twitter](https://twitter.com/tylermorganwall/status/962074911949840387) and is originally attributed to [Joe Cheng](https://twitter.com/jcheng). You can run any Shiny app without blocking the session. My helper function to run ShinyStan without blocking is below:

```{R}
launch_shinystan_nonblocking <- function(fit) {
  library(future)
  plan(multisession)
  future(
    launch_shinystan(fit) #You can replace this with any other Shiny app
  )
}
```

Hope that helps!