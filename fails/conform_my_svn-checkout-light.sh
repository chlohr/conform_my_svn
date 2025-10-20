#!/bin/bash
#
# C. Lohr 2025 - GPLv3+
#
# Attempt to turn a patological multi-projects SVN repository into a "conformable" way for a svn to git conversion.
# For underlaying concepts, refers to http://www.catb.org/~esr/reposurgeon/repository-editing.html#multiproject
#
# This produce a list of 'svn mv <src> <dst>' commands
# Note that this approach cause amnesia by the svn to git process.
# The git history start with the day of the arrival of things in /trunk /tags /braches (ie. today)
# You forgot the past.
#
# Audience:
# This script is dedicated to the brave souls who:
# - Have really read the "reposurgeon" documentation
#   http://www.catb.org/~esr/reposurgeon/repository-editing.html
# - Have really tried to experiment it
#   (repotool initmake & make & co.)
# - Are lost between Step 0 and Step 1
#   (If you do not understand what this means, please carefully reread the mentioned documentation)
#
# Warning: This script works on the project's directory produced by a 'svn checkout'.
# The output of this script is commands to be applied on it.
#
# General idea:
# - crawl directories of the project 
# - for each path in the form './sub_tree_A/tags/tag_name/sub_tree_B' 
#	move it to './tags/[some name based on sub_tree_A + tag_name]/sub_tree_A/sub_tree_B'
# - for each path in the form './sub_tree_A/branches/branche_name/sub_tree_B' 
#	move it to './branches/[some name based on sub_tree_A + branche_name]/sub_tree_A/sub_tree_B'
# - for each path in the form './sub_tree_A/trunk'
#	move it to './trunk/sub_tree_A'
# - for each path having neither 'trunk' nor 'tags' in it
#	move it to './trunk'
# then:
# - save output as a shell script
# - adapt to your own needs
# - execute and cross your fingers
#
# Good luck!

if [ "$#" != 1 ]; then
  echo "Usage: $0 <svn repository>" >&2
  exit 1
fi

if [ ! -d "$1/.svn" ]; then
  echo "Error: '$1' is not an svn repository" >&2
  exit 1
fi

REPO="$1"

n=1
TMP=$(mktemp)

cd "$REPO"

echo "# Handling Tags"
find . -type d -regex '.*/tags/[^/]*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    AUX=${SRC/\/tags/}
    TAG=${AUX//\//_}
    DST=${SRC/\/tags*/}
    ACTION="svn mv \"$SRC\" \"tags/$TAG/$DST\""
    echo "echo [$((n++))] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Branches"
find . -type d -regex '.*/branches/[^/]*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    AUX=${SRC/\/branches/}
    BRANCH=${AUX//\//_}
    DST=${SRC/\/branches*/}
    ACTION="svn mv \"$SRC\" \"branches/$BRANCH/$DST\""
    echo "echo [$((n++))] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Trunks"
find . -type d -name 'trunk' -fprintf $TMP '%h\n' 
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    ACTION="svn mv \"$SRC/trunk\" \"trunk/$SRC\""
    echo "echo [$((n++))] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Remaining"
find ./ -type d -not -regex '.*/tags/.*' -not -regex '.*/trunk/.*' -not -regex '.*/\.svn/.*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    ACTION="svn mv \"$SRC\" \"trunk/$SRC\""
    echo "echo [$((n++))] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP

rm -f $TMP

echo "svn status"
echo "echo Now you can try a svn commit"
