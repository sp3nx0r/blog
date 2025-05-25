---
title: "{{ replace (index (split .Name "-") 3) "-" " " | title }}"
# description: "Description" # If this is set, it is preferred to the summary in the <meta name="description" tag>
summary: "Summary" # The summary is displayed in the posts overview only
draft: true
date: {{ .Date }}
creationDate: {{ .Date }}
url: "/change-me"
# weight: 1
tags: []
# showToc: true
# tocOpen: false
# hidemeta: true
# hidesummary: true
# searchHidden: true
images:
    - "/img/1/twitter-card.png"
cover:
    image: "/img/1/twitter-card.png"
---
