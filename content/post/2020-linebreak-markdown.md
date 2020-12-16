---
title: "Enforcing line-break rules in RMarkdown / Pandoc"
date: '2020-12-16'
tags:
- R
- Markdown
---

Generating document via RMarkdown is fun! So I recently used RMarkdown to generate 
reports that were written in Czech. Interestingly, Czech has rules on some words
that are not allowed to be the last on a line of text - those are almost all single-letter
words and a few abbreviations. MS Word is actually smart enough to enforce this policy,
but this does not happen for the HTML and PDF outputs from RMarkdown.

Obviously, one could add a lot of `&nbsp;` into the source text, but that seemed
tedious and prone to error. And it turns out one can do this automatically - with
 _Lua filters_.
 
The thing is that RMarkdown uses Pandoc to convert (non-R) markdown to the target formats.
And Pandoc let's you manipulate an intermediate representation of the text using Lua - 
a tiny little language that is commonly used as scripting language in video games.
You can read more about Lua filters at [R Markdown cookbook](https://bookdown.org/yihui/rmarkdown-cookbook/lua-filters.html) and [Pandoc documentation](https://pandoc.org/lua-filters.html).

With this knowledge, we can write a filter that checks for spaces after single-letter
words and after a certain abbreviations and replaces them with an appropriate
representation of non-breaking space (currently supporting only HTML and Latex).

Lua syntax is probably slightly unfamiliar, but I hope you will be able to 
customize the script to suit your RMarkdown needs. Note that `--` marks comments.

So here are the contents of `non_breaking_policy.lua` on my computer:

```
-- Returns NBSP in appropriate output format
local function non_breaking_space()
  if FORMAT:match 'html' then
    return(pandoc.RawInline("html", "&nbsp;"))
  elseif FORMAT:match 'latex' then
    return(pandoc.RawInline("latex", "~"))
  else
    error("Unsupported format for non_breaking_policy.lua")
  end
end

-- Other strings to force a nbsp after
-- Should be all lowercase
local additional_strings = {
  ["(tj."] = true,
  ["tj."] = true,
  ["tzv."] = true
}

-- Should return true if spc is a space that should be replaced by non-breaking
-- space. txt is the element before space
local function require_non_breaking_space(txt, spc)
  return spc and spc.t == 'Space'
    and txt and txt.t == 'Str'
    and (txt.c:len() == 1 or additional_strings[pandoc.text.lower(txt.c)])
end


-- Iterate over list of content elements and replace spaces as needed
function replace_spaces (content)
  for i = #content-1, 1, -1 do
    if require_non_breaking_space(content[i], content[i+1]) then
      content[i+1] = non_breaking_space()
    end
  end

  return content
end

function replace_spaces_content (s)
  s.content = replace_spaces(s.content)
  return s
end

function replace_spaces_caption(s)
  s.caption = replace_spaces(s.caption)
  return s
end

-- In theory, we should be able to filter all inline text elemnts with:
-- return {{ Inlines = replace_spaces }}
-- But for some reason, I couldn't make it work, so explicitly lising elements
-- whose contents should be transformed.

return {{ Para = replace_spaces_content,
  Header = replace_spaces_content,
  LineBlock = replace_spaces_content,
  Plain = replace_spaces_content,
  Emph = replace_spaces_content,
  Caption = replace_spaces_content,
  Link = replace_spaces_content,
  Quoted = replace_spaces_content,
  SmallCaps = replace_spaces_content,
  Span = replace_spaces_content,
  Strikeout = replace_spaces_content,
  Strong = replace_spaces_content,
  Underline = replace_spaces_content,
  Image = replace_spaces_caption
}}
```

The Lua filter can then be used in an RMarkdown file as:

```
---
output:
  html_document:
    pandoc_args: ["--lua-filter=non_breaking_policy.lua"]
---
```

Hope that's useful to somebody.