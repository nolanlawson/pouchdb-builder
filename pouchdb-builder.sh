#!/bin/bash
# Build up every PouchDB from now back to the given commit,
# then upload the results to CouchDB.
#
# usage:
# COUCHDB_URL=http://mysite.com:5984/mydb ./pouchdb-builder.sh
#
# You can also specify OLDEST_COMMIT=hash to go back further.
# Default is to a commit in late 2013.
#
if [ -z $OLDEST_COMMIT ]; then
  OLDEST_COMMIT=a31c92865922b8436bd8479464d7a611c0c6683d
fi

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
