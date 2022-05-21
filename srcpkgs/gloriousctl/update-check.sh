#!/usr/bin/env sh

# Set $CURRENT to the timestamp of the last commit of the current version:
PKGNAME="gloriousctl"
CURRENT="2021-11-30T17:29:15Z"

URL="https://api.github.com/repos/enkore/gloriousctl/commits?page=1&per_page=1"
LAST=$(curl -s "$URL"  | jq -r '.[0].commit.committer.date')
if [ "$CURRENT" = "$LAST" ]; then
    exit 0
else
    echo "$PKGNAME latest commit date: $CURRENT -> $LAST"
fi
