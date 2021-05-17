---
title: "Hugo for Natives"
date: 2020-07-14T00:20:18-07:00
misc-topics: ["webdev"]
draft: false
---

## tl;dr

1. Create an empty [GitHub Pages repo][gh-pages] e.g.
`robbiesri/robbiesri.github.io` to contain the static generated site.
1. Create an empty git repo to hold the backing Hugo infrastructure
    - This can be also hosted on GitHub 😃
1. Install Hugo
1. Use Hugo to initialize a new site, pick a theme, and build some content
    - Peep the [Hugo Quick Start guide][hugo-quick-start]
1. Initialize the GitHub Pages repo as a submodule in the `./public` folder
1. Use Hugo to build the static site (`> hugo`), which deploys to `./public` by default
1. Commit and push from your GitHub Pages submodule
1. Go to your cool new GitHub Pages blog (robbiesri.github.io), and make it rain
💰

## Context

I'd been thinking about setting up a graphics/rendering blog for a minute now
but I didn't really know what the path was going to be. I was vaguely aware of
[GitHub Pages][gh-pages], but hadn't spent anytime investigating what it would
take to get it up and running. The biggest issue for me is that I have no
experience with webdev, as a native C/C++ programmer.

One day, I was looking at the big homie [MJP's blog][mjp-blog] when I realized
it was now hosted on GitHub Pages. I started to snoop around and noticed he was
using [Hugo][hugo]. I snooped around the [blog's backing repo][mjp-blog-repo],
and it seemed reasonable enough.

Because I'm a webdev rube, I was hoping to find a setup that let me write posts
in Markdown, publish quickly, is well-documented, and have some simple hooks
webpage configuration hooks. Once I started to investigate Hugo, it checked
most of the boxes, along with being fast (at least, advertised as fast) and
well-liked on GitHub. I did try to do some due diligence about other static site
generators, but that seemed like boondoggle, so I settled on Hugo.

## Hugo Setup

Setting up Hugo was pretty damn easy, and the
[Quick Start guide][hugo-quick-start] is plenty good to get setup quick.

### Install

If you're on Linux/Mac, you can probably just use your preferred package manager
to grab Hugo. If you're like me, on Windows, you can grab a binary drop on the
[Hugo releases page][hugo-releases]. Whatever platform you're on, make sure you
the `hugo` binary is easily accessible, probably by adding it to your `PATH`
environment variable.

### Test Site

If you go through the official Quick Start, it's pretty simple to create a test
site, add a theme, and load up a local server to browse your site. Hugo is as
fast as advertised. Once you start the server, it's actually really simple to
modify your posts and see them get _instantly_ updated on the rendered page.

### Themes

Picking a theme is both fun and stressful, especially when everything is brand
spanking new. The [Hugo Themes][hugo-themes] listing is fun to navigate, and
each theme landing page was useful info, a sample site, and repo.

Once you pick a theme, make sure you snoop around the theme's README to figure
out what you need to know when setting up your theme.

I ended up choosing [erblog][erblog-theme] because the test site was appealing,
and the README seemed decent. While I've had a couple hiccups during setup,
I've been satisfied with the experience so far.

## GitHub Pages Setup

Once you're comfortable with your test site, you can start the process for
setting up the actual site. You will need two Git repos:

- GitHub Pages repo - `github.com/\<USERNAME\>/\<USERNAME\>.github.io`
  - You need to create an (empty) repo at the above URL. This has to be on GitHub.
  - e.g. [https://github.com/robbiesri/robbiesri.github.io](rs-gh-io)
- Hugo site container repo
  - This will contain the Hugo site contents that source the static site, along
  with the theme and GitHub Pages repo as submodules.
  - This doesn't _have_ to be on GitHub but I did
  [host mine on GitHub][rs-gh-hugo] because why not?

You should create your site container repo, add your theme as a submodule, and
add your GitHub Pages repo as a submodule as well. There is a _trick_ with the
Pages submodule: you want to clone it into a folder called `public` because
that's the default folder that Hugo will generate the static site into. You can
actually choose the folder name, but I just used the default (as suggested by
the [Hugo GitHub deployment guide][hugo-gh-deploy].

```shell
> git clone https://github.com/robbiesri/HugoBlog
> hugo new site HugoBlog [--force] 
> cd ./HugoBlog
> git add .
> git commit -m "Initial Hugo infrastructure deployment"
> git submodule add https://github.com/ertuil/erblog themes/erblog
> git commit -m "Add erblog theme"
> git submodule add https://github.com/robbiesri/robbiesri.github.io public
```

Now you can work on creating content you'd like to be on  your site. You can
see how your page will look by using `hugo server`, and pointing your browser to
[http://localhost:1313](http://localhost:1313).

## Deploying the Site

Once you are ready to push your site to GitHub pages, it's pretty easy. If you
added posts, make sure you update the post meta-data to set their `draft` status
to `false`.

```shell
> cd ~./HugoBlog
> hugo
> cd ./public
> git add .
> git commit -m "Initial Hugo-generated static deployment for blog!"
> git push
```

Then surf over to your GitHub page (e.g. robbiesri.github.io) and enjoy the
fruits of your virtual labor (and GitHub and Hugo and your theme).

## Workflows

### Drafts

To be honest, I didn't understand _what_ the draft functionality was for.
Either the page was deployed, or it wasn't. As long as I didn't update the
static deployment, I was safe. However, I quickly took advantage of drafting
some posts without worrying about accidentally rolling them out to the public
site (though anyone can check out my open-source Hugo repo 😉).

### GitHub Pages Deployment Branch

According to the [GitHub Pages publishing doc][gh-pages-publish-doc], I'm
supposed to be able to _choose_ what branch my site is published from. However,
when I looked at the actual Settings for my repo, that wasn't the case.

![Settings pic from my repo](/post_content/misc/gh_pages_branch.PNG)

I don't mind being fixed to `master` for publishing, but I wish the docs matched
the actual behavior. I was confused when I tried changing the branch (since I
don't use `master` as the default branch if I can help it).

### Deployment Activity Log

When I was trying to figure out if my site was actually deployed, I found that
there was an [activity log][robbiesri-io-activity] that GitHub provides:

![robbiesri.github.io Activity Log](/post_content/misc/gh_pages_activity.PNG)

With this, I was able to see which commit the current deployment was grabbing.
This helped me verify and understand if my site was working as expected.

## Pending Stuff

### Markdown Editor

One of the benefits of Google was a really nice internal Markdown editor in the
web-based IDE, Cider. It provided instant visualization of the Markdown I was
writing, a really great integrated Markdown formatter (like `.clang-format` for
Markdown), and an easy full render of the generated site (that was also easy to
share).

I don't have that out in the wild. That I know of, at least. I have snooped
around for alternatives. I drafted this post in [StackEdit][stackedit], and it
was pretty fun. However, it doesn't really offer any formatting support.
And if you are using locally hosted images, it doesn't work with an online
editor.

I usually write local Markdown in VS Code, and the built-in visualizer
(`Ctrl-Shift-v`) is pretty great. But I don't like toggling between tabs. There
is support for [side-by-side viz][vs-code-md], but the last time I tested it, it
didn't really work. I also found an interesting
[Markdown formatting extension][markdown-formatter]. I think I'll stick with VS
Code for now.

### Hugo Theme/Config Management

You gotta pay the cost to be the boss, but I was slightly annoyed with the time
it took for me to figure out how to manage `config.toml` and the per-post
meta-data. It's surprisingly hard to find _good_ examples for how to set this
stuff up. I can find thousands of Hugo sites, but which ones are modelling best
practices? It's even more difficult to find good theme citizenry, especially
when the [erblog sample site][erblog-sample] isn't terribly complex (which is
fine).

On top of that, figuring out [Hugo taxonomies][hugo-taxonomies] was really
frustrating. Maybe it's more intuitive to a day-to-day webdev, but it took
me a while to figure out how to manage this correctly.  

[gh-pages]: https://pages.github.com/
[gh-pages-publish-doc]: https://docs.github.com/en/github/working-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

[hugo]: https://gohugo.io/
[hugo-quick-start]: https://gohugo.io/getting-started/quick-start/
[hugo-releases]: https://github.com/gohugoio/hugo/releases
[hugo-themes]: https://themes.gohugo.io/
[hugo-taxonomies]: https://gohugo.io/content-management/taxonomies#configure-taxonomies
[hugo-gh-deploy]: https://gohugo.io/hosting-and-deployment/hosting-on-github/

[erblog-theme]: https://themes.gohugo.io/erblog/
[erblog-sample]: https://themes.gohugo.io/theme/erblog/
[erblog-repo]: https://github.com/ertuil/erblog

[mjp-blog]: https://therealmjp.github.io/
[mjp-blog-repo]: https://github.com/TheRealMJP/TheRealMJP.github.io

[rs-gh-io]: https://github.com/robbiesri/robbiesri.github.io
[rs-gh-hugo]: https://github.com/robbiesri/HugoBlog
[robbiesri-io-activity]: https://github.com/robbiesri/robbiesri.github.io/deployments/activity_log?environment=github-pages

[stackedit]: https://stackedit.io/
[vs-code]: https://code.visualstudio.com/
[vs-code-md]: https://code.visualstudio.com/docs/languages/markdown
[markdown-formatter]: https://marketplace.visualstudio.com/items?itemName=mervin.markdown-formatter
