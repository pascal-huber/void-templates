#!/bin/bash
#
# deploy.sh

set -e

# Settings
BUILD_DIR="void-packages/hostdir/binpkgs"
GHIO="${OWNER}.github.io"
URL="https://${GHIO}/${REPONAME}"

# TODO: this will cause problems for archs other than musl/glibc
case "$ARCH" in
    *musl* ) LIBC="musl" ;;
    * ) LIBC="glibc" ;;
esac

delete_or_archive(){
  if [ "$ARCHIVE" = "true" ]; then
    mkdir -p "archive/$LIBC"
    # TODO: this will cause problems when a package name is a prefix of another
    mv ${LIBC}/${1}* "archive/$LIBC"
  else
    find $LIBC -maxdepth 1 -name "${1}*" -delete
  fi
}

echo "### Started deploy to $GITHUB_REPOSITORY/$TARGET_BRANCH"

# configure git
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$EMAIL"

# Prepare gh-pages branch
if [ -z "$(git ls-remote --heads https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git ${TARGET_BRANCH})" ]; then
  echo "Create branch '${TARGET_BRANCH}'"
  git clone --quiet https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
  cd $TARGET_BRANCH
  git checkout -b $TARGET_BRANCH
else
  echo "Clone branch '${TARGET_BRANCH}'"
  git clone --quiet --branch=$TARGET_BRANCH https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
  cd $TARGET_BRANCH
fi

# Remove or archive removed packages
echo "Removing or archiving deleted packages"
RPKGS=$(cat /tmp/removed)
for pkg in ${RPKGS}; do
  echo -e "\t$pkg"
  delete_or_archive "$pkg"
done

# Delete repodata
echo "deleting repodata"
find $LIBC -name "$ARCH-repodata" -maxdepth 1 -delete

# Delete package if it the same version was built again
echo "Removing rebuilt packages"
for file in ../$BUILD_DIR/*.xbps; do
  find $LIBC -iname $file -maxdepth 1 -delete
done

# Remove or archive packages to be built
echo "Removing or archiving packages"
CPKGS=$(cat /tmp/templates)
for pkg in ${CPKGS}; do
  echo -e "\t$pkg"
  delete_or_archive "$pkg"
done

# Add new packages
echo "Adding new packages"
for pkg in ${CPKGS}; do
  echo -e "\t$pkg"
  cp -Rf ../$BUILD_DIR/$pkg* $LIBC
done

# Sign packages
echo "Signing packages"
echo "$PRIVATE_PEM" > $HOME/private.pem
echo "$PRIVATE_PEM_PUB" > $HOME/private.pem.pub
xbps-rindex --add $LIBC/*.xbps
xbps-rindex --privkey $HOME/private.pem --sign --signedby "$SIGNED_BY" $LIBC
xbps-rindex --privkey $HOME/private.pem --sign-pkg $LIBC/*.xbps

# Generate homepage
cat << EOF > index.html
<html>
<head><title>Index of /$REPONAME</title></head>
<body>
<h1>Index of /$REPONAME</h1>
<hr><pre><a href="https://$GHIO">../</a>
EOF

for d in */; do
    dir=$(basename $d)
    size=$(du -s $d | awk '{print $1;}')
    s=$(stat -c %y $d)
    stat=${s%%.*}

    if [ -d "$d" ]; then
        printf '<a href="%s">%-40s%35s%20s\n' "$dir" "$dir</a>" "$stat" "$size" >> index.html
    fi
done

# Generate index.html
cat << EOF >> index.html
</pre><hr></body>
</html>
EOF

# Generate index.html for packages
cat << EOF > $LIBC/index.html
<html>
<head><title>Index of /$REPONAME/$LIBC</title></head>
<body>
<h1>Index of /$REPONAME/$LIBC</h1>
<hr><pre><a href="$URL/">../</a>
EOF

for f in $LIBC/*;do
  file=$(basename $f)
  if [ "$file" == "index.html" ]; then
      echo "ignored: $file"
      continue
  fi

  size=$(du -s $f | awk '{print $1;}')
  s=$(stat -c %y $f)
  stat=${s%%.*}
  if [ -f "$f" ]; then
    printf '<a href="%s%s%s">%-40s%35s%20s\n' "$URL/" "$LIBC/" "$file" "$file</a>" "$stat" "$size" >> $LIBC/index.html
  fi
done

cat << EOF >> $LIBC/index.html
</pre><hr></body>
</html>
EOF

# Committing changes
echo "Committing changes"
COMMIT_MESSAGE="$GITHUB_ACTOR published a site update"
if [ -z "$(git status --porcelain)" ]; then
  result="Nothing to deploy"
else
  git lfs install
  git lfs track "*.xbps"
  git add -Af .
  git commit -m "$COMMIT_MESSAGE"
  git push -fq origin $TARGET_BRANCH > /dev/null
  if [ $? = 0 ]; then
    result="Deploy succeeded"
  else
    result="Deploy failed"
  fi
fi

# Set output
echo $result
echo "::set-output name=result::$result"

echo "### Finished deploy"
