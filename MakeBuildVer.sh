#!/bin/bash

TARGET_FILE=$1
GIT_TAG=$2
DEFINE_PREFIX=$3

if [[ -z "$TARGET_FILE" || -z "$DEFINE_PREFIX" ]]; then
    echo Usage: MakeBuildVer.sh [TargetFile] [GitTag] [DefinePrefix]
    exit 1
fi

# === Get the current branch ===
ACTIVE_BRANCH=`git rev-parse --abbrev-ref HEAD`
FULLHASH=`git rev-parse HEAD`

# === Get the most recent tag matching our prefix ===
if [ -z "$GIT_TAG" ]; then
    ACTIVE_TAG=`git describe --tags 2>&1`
else
    ACTIVE_TAG=`git describe --tags --match "$GIT_TAG.*" 2>&1`
fi

if [[ "${ACTIVE_TAG:0:5}" == "fatal" ]]; then
    VERSION_TAG=NO TAG
    VERSION_MAJOR=0
    VERSION_MINOR=0
    VERSION_PATCH=0
    VERSION_REVISION=0
else
    if [ -z "$GIT_TAG" ]; then
        ACTIVE_TAG="X.$ACTIVE_TAG"
    fi

    # === Get the number of commits since the tag and remove the hash PREFIX-COMMITS-HASH ===
    VERSION_REVISION=`echo "$ACTIVE_TAG" | cut -d '-' -f2`
    if [ -z "$VERSION_REVISION" ]; then
        VERSION_REVISION=0
    fi

    # === Extract the major/minor/patch version from the tag (append 0s if necessary) ===
    ACTIVE_TAG=`echo "$ACTIVE_TAG" | cut -d '-' -f1`
    IFS="." read -r IGNORE VERSION_MAJOR VERSION_MINOR VERSION_PATCH IGNORE <<< "$ACTIVE_TAG.0.0"
    VERSION_TAG=`echo "$ACTIVE_TAG" | cut -d '.' -f2-`
fi

BRANCH_INFO=$ACTIVE_BRANCH

# === Treat develop branch like master branch for dirty detection ===
if [[ "$ACTIVE_BRANCH" == "develop" ]]; then
    ACTIVE_BRANCH=master
fi

# === Build the product version. If on a branch, include the branch name ===
VERSION_PRODUCT=$VERSION_TAG

if [[ "${ACTIVE_BRANCH:0:5}" == "alpha" ]]; then
    PRERELEASE_VERSION_MINOR=$((VERSION_MINOR+1))
elif [[ "${ACTIVE_BRANCH:0:4}" == "beta" ]]; then
    PRERELEASE_VERSION_MINOR=$((VERSION_MINOR+1))
fi

# === If there are any local modifications, set branch name to "dirty" ===
if ! git diff --exit-core > /dev/null 2>&1; then
    BRANCH_INFO="$BRANCH_INFO [modified]"
    if [[ "$ACTIVE_BRANCH" == "master" ]]; then
        ACTIVE_BRANCH=dirty
    fi
fi

# === If we're on master and there any local commits, set branch name to "dirty" ===
if [[ "$ACTIVE_BRANCH" == "master" ]]; then
    # === Get the upstream branch ===
    UPSTREAM_BRANCH=`git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
    if [ -z $UPSTREAM_BRANCH ]; then
        UPSTREAM_BRANCH=origin/master
    fi

    # === Determine how many local commits exist ===
    AHEAD_COUNT=`git rev-list --count $UPSTREAM_BRANCH..$ACTIVE_BRANCH`
    if [[ "$AHEAD_COUNT" != "0" ]]; then
        VERSION_REVISION=$((VERSION_REVISION-$AHEAD_COUNT))
        ACTIVE_BRANCH=dirty
    fi
fi
echo "${ACTIVE_BRANCH: -6}"

# === If not on a clean master branch, capture the branch name/dirty state ===
if [[ "$ACTIVE_BRANCH" != "master" ]]; then
    if [[ "$PRERELEASE_VERSION_MINOR" != "" ]]; then
        VERSION_PRODUCT=$VERSION_MAJOR.$PRERELEASE_VERSION_MINOR-$ACTIVE_BRANCH
    elif [[ "${ACTIVE_BRANCH: -6}" != "-fixes" ]]; then
        VERSION_PRODUCT=$VERSION_PRODUCT-$ACTIVE_BRANCH
    fi
fi

VERSION_FULL=$VERSION_TAG
if [[ "$VERSION_REVISION" != "0" ]]; then
    VERSION_FULL=$VERSION_FULL.$VERSION_REVISION
fi
if [[ "$ACTIVE_BRANCH" != "master" ]]; then
    VERSION_FULL=$VERSION_FULL-$ACTIVE_BRANCH
fi


# === Generate a new version file ===
echo "Branch: $BRANCH_INFO ($VERSION_TAG)"

echo "#define ${DEFINE_PREFIX}_VERSION \"$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH.$VERSION_REVISION\"" > Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_SHORT \"$VERSION_TAG\"" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_MAJOR $VERSION_MAJOR" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_MINOR $VERSION_MINOR" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_PATCH $VERSION_PATCH" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_REVISION $VERSION_REVISION" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_PRODUCT \"$VERSION_PRODUCT\"" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_FULL \"$VERSION_FULL\"" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_COMMIT_HASH \"$FULLHASH\"" >> Temp.txt
echo "#define ${DEFINE_PREFIX}_VERSION_COMMIT_HASH_SHORT \"${FULLHASH:0:8}\"" >> Temp.txt

# === Update the existing file only if the new file differs (fc requires backslashes) ===
if [ ! -f "$TARGET_FILE" ]; then
    # === File doesn't exist ===
    mv Temp.txt "$TARGET_FILE" > /dev/null
elif ! cmp -s "$TARGET_FILE" Temp.txt; then
    # === File has changed ===
    rm "$TARGET_FILE"
    mv Temp.txt "$TARGET_FILE" > /dev/null
else
    # === File has not changed ===
    rm Temp.txt
fi
