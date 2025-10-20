# Conform my SVN

## Context and Objective

I had to migrate a project from SVN to Git.
There are tools for this: eg. the traditional [svn2git](https://github.com/nirvdrum/svn2git)
or the very versatile [reposurgeon](http://www.catb.org/esr/reposurgeon/).

However, these tools assume that the svn repository is in a "standard layout",
ie. having /trunk /tags /branches at the root.

This is not the case with my repository, which follows a [multi-project](http://www.catb.org/~esr/reposurgeon/repository-editing.html) structure.
My repository is more like a sort of large meta-project, in which, at various points in the tree structure (not necessary at the top), 
you can find interdependent subprojects that have their own trunk-tags-branches, as well as other material.


## The simplest things are often the best

I spent time and energy trying sophisticated manipulations. (See below.)
None of them gave me a really satisfactory result.
During this experience, I probably made good progress in svn.
It's a shame, I don't think I'll have the opportunity to use it again...

Well, my advice: **Do nothing!**

I decided not to attempt any transformation of any kind on my svn before converting it to git.
(But now I know why.)

I just use 'svn_add_trunk.pl' to make reposurgeon be happy (see below), 
and do a 'repocutter -s trunk push' to put everthing in '/trunk/'.
Then I let reposurgeon convert it to git.

Then, in git, I would make the '../trunks/.." disappear, and rename the "tags" and "branches" to "archives", by hand.


## A not so successful story

So, as explained in the introduction, I wanted to try to move the objects to conform to the standard layout.
But I have to do it not only on the today's state of things (otherwise it leads to failures, see below), but also on the repository history.

Reposurgeon proposes a command for this: [repocutter pathrename <src> <dst>](http://www.catb.org/~esr/reposurgeon/repocutter.html).
But it can't guess what to move and where. 
You need to specify this according to the structure of your repository and your needs.

In my case, this is quite systematically. So I wrote a script to generate repocutter commands.
(After more or less successful variants).


### General idea of the script

- Consider the svndump file of the repository (see 'svnadmin dump' 'svnrdump' 'svnsync' 'repotool export' ...)

- List directories paths mentionned in it (past & present)

- For each path in the form './sub_tree/trunk'
 
  rename it '/trunk/sub_tree'

- For each path in the form './sub_tree/tags/tag_name' 

  rename it '/tags/[some name based on sub_tree + tag_name]/sub_tree'

- For each path in the form './sub_tree/branches/branch_name' 
 
  rename it '/branches/[some name based on sub_tree + branch_name]/sub_tree'

- For each path having neither 'trunk' 'tags' 'branches' in it

  rename it in '/trunk/..'

- Expunge remaining orphans ../trunk$ ../tags$ and ../branches$

Script: conform_my_svn.sh



### Using the script
- Save output as a shell script
- Adapt to your own needs
- Ensure having space 
- Execute, cross your fingers, and wait
- Then, re-run the Makefile produced by reposurgeon


### A very mixed result

It didn't work for me for two reasons:

- Subprojects created after the fact.

  Over the course of my repository's history, some nodes in the tree have become subprojects (with their ./trunk ./tag ./branches) when they were not initially.
  Concretely, the repository contains therfore operations such as 'copy subpath/trunk/materials from subpath/materials; delete ...'.
  If above renaming rules are applied, this become 'copy trunk/subpath/materials from trunk/subpath/materials, delete ...'.
  This is an empty operation, which is ignored when applying the corresponding revision.
  Unfortunately, the objects manipulated by this operation also seem to disappear from the revision. 
  (A move is a copy+delete. I don't know if there is a way to avoid this. Any idea? With pathname closure?)
  Therefore, the following operations that are supposed to apply to objects in this revision have no ancestor.
  So, the repository become inconsistent. 

- Tags that continue their life.

  It seems to be something quite classic in the svn world. 
  After creating a tag from the current state of the trunk, we continue to slightly modify the contents of the tag.
  Not necessarily a lot, but it's enough that it's no longer strictly a tag on a version.
  It's actually something approaching a branch.
  Therefore, translating an svn tag to a git tag is not appropriate.
  But systematically translating svn tags to git branches might not be the right thing to do either... 

Don't hesitate to check your situation with a 'repocutter see' 


### Misc

- Add the creation of /trunk /tags /branches at the beginning

  Note that 'svnadmin load' fails if the tump refers to path that are not yet created. (Any tool to fix this? Boring but doable.)
  Which may be the case after performing some 'repocutter pathrename'.

  On it' side, reposurgeon doesn't really care.
  Except that it's heuristic looks at the presence of /trunk /tags /branches to decide if the svn is in a standard layout or not,
  and to performs appropriate (or not) processes.  

Script: svn_add_trunk.pl



## Bad Ideas and Fails

I must humbly admit that I also sometimes have bad ideas. ;-)
In hindsight, it is obvious that these were bad ideas.
But at the time, I really thought it could work.

### Work on the checkout

My first idea, rather naive, was to examine the tree structure on the checkout directories.
Therefore, the generated renaming rules only take into account the current tree structure, not the past one.
Unfortunately, the generated objects may point to non-existent elements.
This results in an inconsistent repository.

In my case, the tree structure had remained fairly stable over time.
But not completely. So, I didn't notice the problems immediately.

Conclusion: It's a bad idea, don't do it.

Fail scripts: conform_my_svn-checkout-stdlayout.sh conform_my_svn-checkout-notags.sh


### Just do svn mv

My second bad idea was to think about reorganizing the tree structure with "svn mv" before the conversion to git.

This approach cause amnesia by the svn to git process.
The git history start with the day of the arrival of things in /trunk /tags /braches (ie. today)
The past is forgotten.

Conclusion: It's a bad idea, don't do it.

In fact, if you don't mind forgetting the past, you don't need an svn to git conversion tool at all.
Just create a new git, copy the files from today's svn checkout into it, and you're done.

Fail script: conform_my_svn-checkout-light.sh


### Prerequisites & Target Audience

This page is dedicated to the brave souls who:

- Have really read the [reposurgeon documentation](http://www.catb.org/~esr/reposurgeon/repository-editing.html)

- Have really tried to experiment it

  (repotool initmake ; make ; etc.)

- Are lost between Step 0 and Step 1

  (If you do not understand what this means, please carefully reread the mentioned documentation)
