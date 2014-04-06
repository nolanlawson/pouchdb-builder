#!/bin/bash
# build up every pouch build from now until the given commit
#
#
OLDEST_COMMIT=a31c92865922b8436bd8479464d7a611c0c6683d
#OLDEST_COMMIT=bc5b1034f7ea12b2ebd674bdf86bb5ca9c23dc59
if [ -z $COUCHDB_URL ]; then
  COUCHDB_URL=http://localhost:5984/pouchdb_builds
fi

curl -X PUT $COUCHDB_URL

if [[ ! -d pouchdb ]]; then
  mkdir -p pouchdb
  git clone https://github.com/pouchdb/pouchdb.git
fi

cd pouchdb
git fetch
git reset --hard origin/master

while [[ $(git rev-parse HEAD) != $OLDEST_COMMIT ]]; do
  commit=$(git rev-parse HEAD)
  exists_response=$(curl -s -w '%{http_code}' $COUCHDB_URL/$commit -o /dev/null)
  if [[ exists_response -ne '404' ]]; then
    echo "already processed commit $commit"
  else
    echo "processing $commit"
    npm install
    npm run build
    commit_timestamp=$(git show --pretty=format:%ct $commit | head -n 1)
    commit_date=$(git show --pretty=format:%ci $commit | head -n 1 | sed 's/ /_/g')
    response=$(curl -X PUT $COUCHDB_URL/$commit -H 'content-type:application/json' -d '{"_id" : "'$commit'", "timestamp" : '$commit_timestamp', "date" : "'$commit_date'"}')
    echo "response is $response"
    rev=$(echo $response | egrep -Eo 'rev":"(\S+)"' | sed 's/rev":"//' | sed 's/"$//')
    echo "rev is $rev"
    curl -X PUT "$COUCHDB_URL/$commit/pouchdb.min.js?rev=$rev" -H "content-type:application/javascript" -d @dist/pouchdb-nightly.min.js    
  fi
  git reset --hard HEAD^1
  
done