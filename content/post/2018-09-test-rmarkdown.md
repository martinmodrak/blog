---
title: "A Plea for Tests in R Markdown"
slug: "tests-in-r-markdown"
date: 2018-09-17
tags: ["Rant","Markdown","Notebook"]
---

I've read [Yihui Xie's thoughtful response](https://yihui.name/en/2018/09/notebook-war/) to the [I don't like notebooks](https://docs.google.com/presentation/d/1n2RlMdmv1p25Xy5thJUhkKGvjtV-dkAIsUXP-AL4ffI/preview#slide=id.g362da58057_0_1) talk from JupyterCon 2018. And I agree with basically everything Yihui said, only one point felt like it could give a wrong impression. It states:

> How would you write unit tests for data analysis? I feel it will be both tricky and unnecessary.
[...]
 On the other hand, data analysts often do tests in an informal way, too. As they explore the data, they may draw plots or create summary tables, in which they may be able to discover problems (e.g., wrong categories, outliers, and so on). 

This reads as if there is no room for automated tests in markdown/notebooks. I respectfully disagree: automated tests and checks are IMHO vital for high-quality notebooks - whether we still call them unit tests or something else is besides the point. 

Let me give you an example from a recent analysis I did. I needed to connect some data containing adresses to city populations from the census. The best binding seemed to be based on post code and municipality name as neither post code nor municipality names correspond to unique rows in the census data while the combination seemed sufficient. So I wrote a simple check (note that all code is shortened for clarity and not tested to actually work):

```
non_unique_rows <- census_data %>% 
  group_by(postcode, municipality) %>% 
  summarise(count = length(id)) %>%
  filter(count > 1)
  
if(nrow(non_unique_rows) > 0) {
  stop("Municipality and postcode do not identify census data")
}
```

And this actually gave me the error message, as the data was not - contrary to my belief - unique. It turns out however that the data under analysis never referenced those non-unique rows and the check thus became:

```
non_identified_data <- main_data %>%
    select(municipality,postcode) %>%
    semi_join(non_unique_rows, by = c("postcode" = "postcode", "municipality" = "municipality"))
    
if(nrow(non_identified_data) > 0) {
  stop("Data couldn't be mapped to census data")
}
```

I could have run the check just once from the console, but storing it in the notebook has two core advantages:

* The code can be found and reused later
* When you change some preprocessing steps or update your data to a newer version you will be notified of problems

The latter advantage became apparent when I had a complicated join that was however supposed to only give exactly one match for each row in the data, so I wrote:

```
main_data_augmented <- main_data %>% 
  inner_join(...) %>%
  ...lots of complex joining...
  
if(nrow(main_data_augmented) != nrow(main_data)) {
  stop("Unexpected number of rows after join.")
}
```

This worked nicely. Later, I changed how I prepare the tables that go into the join, thinking it couldn't break anything and the above check fired, because (obviously) I made a mistake. If there was no check, the downstream analysis would run without complaining, but some rows from `main_data` would be actually copied twice as they now had more matches.

Since you should do such checks anyway to ensure your analysis is correct, storing them in the notebook is very little additional effort and can save you a lot of trouble. So please, write tests and checks within your notebooks!
