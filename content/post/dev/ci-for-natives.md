---
title: "CI for a Fucking Doofus"
date: 2021-05-31T21:47:18-07:00
draft: true
---

## tl;dr

* Stack Overflow and Travis CI docs are your friend
* I have no idea if Travis CI is the best, but I liked using it
* I desperately need to learn how to setup a matching environment to what
  Travis CI has so I can test locally.


## Motivation

I've been listening to _boatloads_ of [CppCast][cppcast] while walking the
doggo. A couple weeks ago, I listed to an
[episode with Richel Bilderbeek][cppcast-richel]. I almost skipped it because I
didn't think I'd care that much about Richel. I'm glad I didn't. Excellent
episode with an excellent guest. Richel was truly passionate about CI, and is
sparked my interest. Something _particularly_ compelling was Richel discussing
a tool called [proselint][proselint]. It's a linting tool that validates prose!
It sounded cool, so I thought it would be a good test case to add to these
unread blog posts!

## Attempt 1: Copypasta alla Travis

Richel had a [sample repo][proselint-ci-sample] demonstrating CPP usage

## Attempt 2: I Know Python, Can I Use Python?

## Attempt 3: I AM A CI (LESSER) GOD

I was happy with the current setup, but I had a nagging feeling I was doing
something wrong. I don't think I wanted to use the Python language setup. I'm
not validating a Python project. It seems like the wrong environment. I want to
_use_ Python to validate my Markdown, but that is different than validating my
Python scripts.

[cppcast]: https://cppcast.com/
[cppcast-richel]: https://cppcast.com/richel-bilderbeek/

[proselint]: https://github.com/amperser/proselint
[proselint-pip]: https://pypi.org/project/proselint/
[proselint-ci-sample]: https://github.com/richelbilderbeek/travis_proselint

[markdownlint]: https://github.com/DavidAnson/markdownlint