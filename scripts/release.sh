#!/bin/bash

set -eu

shutdown() {
  # Get our process group id
  # shellcheck disable=SC2009
  PGID=$(ps -o pgid= $$ | grep -o "[0-9]*")

  # Kill it in a new new process group
  setsid kill -- -"$PGID"
  exit 0
}

trap "shutdown" SIGINT SIGTERM

if [ -z "$1" ]; then
  echo "Need version as argument"
  exit -1
fi
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Need GITHUB_TOKEN env set."
  exit -1
fi

branch=$(git symbolic-ref --short -q HEAD)
if [ "$branch" != "exode" ]; then
  echo "Need to be on develop branch."
  exit -1
fi

version="v$1"
directory_name="peertube-$version"
zip_name="peertube-$version.zip"
tar_name="peertube-$version.tar.xz"

changelog=$(awk -v version="$version" '/## v/ { printit = $2 == version }; printit;' CHANGELOG.md | grep -v "$version" | sed '1{/^$/d}')

printf "Changelog will be:\\n%s\\n" "$changelog"

read -p "Are you sure to release? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 0
fi

#npm run build
#rm "./client/dist/en_US/stats.json"
#rm "./client/dist/embed-stats.json"

# Creating the archives
(
  # local variables
  directories_to_archive=("$directory_name/CREDITS.md" "$directory_name/FAQ.md" \
                          "$directory_name/LICENSE" "$directory_name/README.md" \
                          "$directory_name/client/dist/" "$directory_name/client/yarn.lock" \
                          "$directory_name/client/package.json" "$directory_name/config" \
                          "$directory_name/dist" "$directory_name/package.json" \
                          "$directory_name/scripts" "$directory_name/support" \
                          "$directory_name/tsconfig.json" "$directory_name/yarn.lock")
  # temporary setup
  cd ..
  ln -s "PeerTube" "$directory_name"

  # archive creation + signing
  zip -r "PeerTube/$zip_name" "${directories_to_archive[@]}"

  # temporary setup destruction
  rm "$directory_name"
)

# Creating the release on GitHub, with the created archives
(
  git tag "$version"
  git push --tag

  github-release release --user phief --repo peertube --tag "$version" --name "$version" --description "$changelog"
  github-release upload --user phief --repo peertube --tag "$version" --name "$zip_name" --file "$zip_name"
  github-release upload --user phief --repo peertube --tag "$version" --name "$zip_name.asc" --file "$zip_name.asc"
  github-release upload --user phief --repo peertube --tag "$version" --name "$tar_name" --file "$tar_name"
  github-release upload --user phief --repo peertube --tag "$version" --name "$tar_name.asc" --file "$tar_name.asc"

  git push origin exode

  # Update master branch
  git checkout master
  git rebase exode
  git push origin master
  git checkout exode
)
