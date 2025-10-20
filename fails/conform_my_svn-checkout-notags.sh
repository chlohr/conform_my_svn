#!/bin/bash
#
# C. Lohr 2025 - GPLv3+
#
# Attempt to turn a patological multi-projects SVN repository into a "conformable" way for a svn to git conversion
# For underlaying concepts, refers to http://www.catb.org/~esr/reposurgeon/repository-editing.html#multiproject
#
# This produce a list of 'repocutter pathrename <src> <dst>' commands
# See http://www.catb.org/~esr/reposurgeon/repocutter.html
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
# Warning: This script works on the project's directory produced by a client-side 'svn checkout'.
# Note however that 'reposurgon' tools work on the SVN repository viewed from the server side.
# (Eg. get by a 'svnadmin dump', a 'svnrdump', or by a 'svnsync')
# And more precisely, the output of this script is commands to be applied on the svn dump produced by 'repotool export' on this server-side repository
# (from the 'reposurgeon' package; e.g.  (cd my_project/; repotool export) > my_project.svn )
#
# General idea: (everything in /trunk, tags and branches renamed 'archives')
# - crawl directories of the project 
# - for each path in the form './sub_tree_A/trunk'
#	rename it './trunk/sub_tree_A'
# - for each path in the form './sub_tree_A/tags/tag_name/sub_tree_B' 
#	rename it './trunk/sub_tree_A/archives/sub_tree_B'
# - for each path in the form './sub_tree_A/branches/branche_name/sub_tree_B' 
#	rename it './trunk/sub_tree_A/archives/sub_tree_B'
# - for each path having neither 'trunk' nor 'tags' in it
#	rename it './trunk'
# then:
# - save output as a shell script
# - adapt to your own needs
# - ensure having space (about 3x the repository)
# - execute, cross your fingers, and wait
#
# Good luck!
#
# Note: It seems that 'repocutter pathrename' produces inconsistent svn dump files.
# (Attempts to load the result as a svn repository show references to unknown files.)
# It seems to be a feature and not a bug: 'reposurgeon' seems ok with that.
#

if [ "$#" != 1 ]; then
  echo "Usage: $0 <svn repository>" >&2
  exit 1
fi

if [ ! -d "$1/.svn" ]; then
  echo "Error: '$1' is not an svn repository" >&2
  exit 1
fi

REPO="$1"


TMP1="${REPO}_tmp1.svn"
TMP2="${REPO}_tmp2.svn"
n=0

function set_tmp12() {
  if (( (n++ % 2) == 0 )); then 
    if (( n == 1 )); then
      MYTMP1=${REPO}.svn
    else
      MYTMP1="$TMP1"
    fi
    MYTMP2="$TMP2"
  else 
    MYTMP1="$TMP2"
    MYTMP2="$TMP1"
  fi
}

TMP=$(mktemp)

cd "$REPO"

echo "# Handling Trunks"
find . -type d -name 'trunk' -fprintf $TMP '%h\n' 
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    set_tmp12
    ACTION="repocutter pathrename \"^$SRC/trunk\" \"trunk/$SRC\" < $MYTMP1 > $MYTMP2"
    echo "echo [$n] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Tags"
find . -type d -regex '.*/tags/[^/]*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    DST=${SRC/tags/archives}
    set_tmp12
    ACTION="repocutter pathrename \"^$SRC\" \"trunk/$DST\" < $MYTMP1 > $MYTMP2"
    echo "echo [$n] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Branches"
find . -type d -regex '.*/branches/[^/]*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    DST=${SRC/branches/archives}
    set_tmp12
    ACTION="repocutter pathrename \"^$SRC\" \"trunk/$DST\" < $MYTMP1 > $MYTMP2"
    echo "echo [$n] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP


echo "# Handling Remaining"
find ./ -type d -not -regex '.*/tags/.*' -not -regex '.*/trunk/.*' -not -regex '.*/branches/.*' -not -regex '.*/\.svn/.*' -fprint $TMP
while read LINE ; do
  SRC=${LINE:2}
  if [ "$SRC" ]; then
    set_tmp12
    ACTION="repocutter pathrename \"^$SRC\" \"trunk/$SRC\" < $MYTMP1 > $MYTMP2"
    echo "echo [$n] \"$ACTION\""
    echo "$ACTION"
  fi
done < $TMP

rm -f $TMP


echo "rm -f $MYTMP1"
echo "mv $MYTMP2 ${REPO}_new.svn"
