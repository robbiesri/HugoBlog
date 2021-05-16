---
title: "Add comments to Hugo with utterances"
date: 2020-07-18T15:12:23-07:00
misc-topics: ["webdev"]
draft: false
---

## tl;dr

1. Add the [utterances GitHub app][utterances-app] to your GitHub Pages repo
    * `utterances` uses GitHub Issues to manage the comments, so it needs
    authorization
1. Go through the [utterances setup][utterances-home] to create the script blob
that will add comments to your blog posts.
1. Check your theme documentation to determine where you should add your
`utterances` script blob.
1. Regenerate the static site (`> hugo`), and push the modified post contents.
    * You can test them locally with (`> hugo server`) to see how the embedded
    comments look!
1. Reload your blog posts, and enjoy your new commenting system!
1. If you are hosting your backing Hugo repo on GitHub, you'll need to fork the
theme submodule, since you'll be modifying theme files directly.
    * If you are keeping the Hugo repo local, no need, since you don't need to
    push your theme changes anywhere.

## Choosing a Comment System for Hugo

I wanted to add comments, even though I anticipated most of the discussion
for the blog posts would be on Twitter. I also thought it would be interesting
to learn about the different systems, and integration process.

I didn't really want to use a comment system where I didn't somehow _own_ the comments, which excluded services like Disqus. There's other drama associated with Disqus, so I was happy to skip it.

That left with me either self-hosting or a system that used
[GitHub Issues][gh-issues] to manage the comments. I didn't really feel like
setting up my own webserver, so I settled on a GitHub Issues system.
Technically, I still don't _own_ the comments because GitHub owns the issues.
Plus, if I want to change the comment system, it'll probably be way harder to
convert the existing comments to another format. If I had self-hosting, I could
probably write a script to convert the old comment format. But...whatever. This
is good enough for me.

I had settled on a couple systems to check out, though there are plenty:

* [gitalk][gitalk]
* [utterances][utterances-repo]

As far as I can tell, the projects started almost the same time (H1 2017). I
ended up picking `utterances` because the setup seemed easier, and I thought
the comment block looked nicer. Plus I'd seen it on some other blogs I like.
Good enough for them, good enough for me.

Note: I was surprised that there weren't (m)any comparison articles about
picking comment systems for statically generated blogs. Maybe there's more in
the `jekyll` ecosystem, but I just didn't find anything really useful.

## Supporting `utterances`

It was actually really simple to add `utterances` to the blog. It boiled down
to a few simple steps:

1. Authorize the [utterances GitHub app][utterances-app] on my blog repo
    * I added it to [https://github.com/robbiesri/robbiesri.github.io](blog)
1. Generate the script blob from the [utterances home page][utterances-home]
1. Look at my theme documentation to determine where to add the script blob
    * [ertuil/erblog][erblog-hooks] has a specific page for add hooks
1. Generate and push the static site, with comments added to posts!

Really the only 'tricky' part was figuring out where to add the script blob,
along with experimenting with the visual appearance of the comment interface. I
was lucky that [ertuil/erblog][erblog-hooks] clearly defines where to add my
customized `utterances` script blob.

`themes/erblog/layouts/partials/self-define-single.html`:

```html
<script src="https://utteranc.es/client.js"
        repo="robbiesri/robbiesri.github.io"
        issue-term="title"
        label="comments"
        theme="icy-dark"
        crossorigin="anonymous"
        async>
</script>    
```

The [utterances home page][utterances-home] is actually great at visualizing the
different themes live in the page. So I was able to get a quick idea of what the
themes would look like.

Also, the `utterances` comment blob shows up in the local server
(`> hugo server -D`), which was a pleasant surprise!

## Bonus: Forking the Theme

Because I decided to host the backing Hugo store in a
[GitHub repo][backing-hugo], I ran into a little snag: modifying the theme
contents! In order to keep everything in sync remotely, I'd have to fork the
theme.

This wasn't a huge deal, but then I got to modify other parts of the theme,
which I was originally hesitant (read: too lazy) to do. But now that it's
forked, it's been fun making changes.

Though, I do wonder if Hugo itself should provide support for a standard
comment hook, maybe somewhere in `config.toml`. But not enough to file an issue
on their repo 😛

[gh-issues]: https://guides.github.com/features/issues/

[gitalk]: https://github.com/gitalk/gitalk

[utterances-repo]: https://github.com/utterance/utterances
[utterances-home]: https://utteranc.es/
[utterances-app]: https://github.com/apps/utterances

[erblog-hooks]: https://github.com/ertuil/erblog/blob/master/README.md#4-user-defined-html-hooks

[backing-hugo]: https://github.com/robbiesri/HugoBlog
[blog]: https://github.com/robbiesri/robbiesri.github.io
