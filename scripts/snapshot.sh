#!/bin/sh

VERSION=$(echo $1 | sed 's/\./-/g')
KEYWORD=$2

SNAPSHOT_TEMPLATE="./scripts/snapshot.yaml"
SNAPSHOT=$(mktemp -t "snapshot-$VERSION")

PATTERN="/$VERSION/"

if [ -n "$KEYWORD" ] ; then
  PATTERN+=" && /$KEYWORD/"
fi

yq eval ".metadata.generateName = \"openshift-builds-$VERSION-\" | .spec.application = \"openshift-builds-$VERSION\"" $SNAPSHOT_TEMPLATE > $SNAPSHOT

kubectl get components -o name | awk "$PATTERN" | while read -r COMPONENT ; do
  JSON=$(kubectl get $COMPONENT -o json)
  NAME=$(echo $JSON | jq -r '.metadata.name')
  DOCKERFILE_URL=$(echo $JSON | jq -r '.spec.source.git.dockerfileUrl')
  URL=$(echo $JSON | jq -r '.spec.source.git.url')
  CONTAINER_IMAGE=$(echo $JSON | jq -r '.status.lastPromotedImage')
  REVISION=$(echo $JSON | jq -r '.status.lastBuiltCommit')

  yq eval ".spec.components += [{\"name\": \"$NAME\", \"containerImage\": \"$CONTAINER_IMAGE\", \"source\": {\"git\": {\"dockerfileUrl\": \"$DOCKERFILE_URL\", \"revision\": \"$REVISION\", \"url\": \"$URL\"}}}]" $SNAPSHOT -i
done
#cat $SNAPSHOT
kubectl create -f $SNAPSHOT

rm $SNAPSHOT