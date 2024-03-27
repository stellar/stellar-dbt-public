#!/bin/sh

cp .env .env.tmp

sed -i 's/export //g' .env.tmp

sed -i 's/;$//g' .env.tmp

dotenv -f .env.tmp run sqlfluff "$@"