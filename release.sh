#!/bin/bash

# قراءة النسخة الحالية
VERSION=$(cat version.txt)

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

echo "Current version: $VERSION"

echo "Select update type:"
echo "1) Patch (bug fixes)"
echo "2) Minor (new features)"
echo "3) Major (breaking changes)"

read -p "Enter choice: " choice

if [ "$choice" == "1" ]; then
  PATCH=$((PATCH + 1))
elif [ "$choice" == "2" ]; then
  MINOR=$((MINOR + 1))
  PATCH=0
elif [ "$choice" == "3" ]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
else
  echo "Invalid choice"
  exit 1
fi

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "New version: $NEW_VERSION"

# تحديث الملف
echo $NEW_VERSION > version.txt

# commit
git add .
#git commit -m "release: v$NEW_VERSION"
read -p "Enter release note: " note
git commit -m "release: v$NEW_VERSION - $note"

# tag
git tag "v$NEW_VERSION"

# push
git push origin main
git push origin "v$NEW_VERSION"

echo "✅ Release v$NEW_VERSION created successfully"