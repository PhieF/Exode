#!/bin/sh

set -eu

PEERTUBE_PATH=${1:-/var/www/peertube/}

if [ ! -e "$PEERTUBE_PATH" ]; then
  echo "Error - path \"$PEERTUBE_PATH\" wasn't found"
  echo ""
  echo "If peertube was installed in another path, you can specify it with"
  echo "    ./upgrade.sh <PATH>"
  exit 1
fi

if [ ! -e "$PEERTUBE_PATH/versions" -o ! -e "$PEERTUBE_PATH/config/production.yaml" ]; then
  echo "Error - Couldn't find peertube installation in \"$PEERTUBE_PATH\""
  echo ""
  echo "If peertube was installed in another path, you can specify it with"
  echo "    ./upgrade.sh <PATH>"
  exit 1
fi


# Backup database
SQL_BACKUP_PATH="$PEERTUBE_PATH/backup/sql-peertube_prod-$(date +"%Y%m%d-%H%M").bak" 
DB_USER=$(node -e "console.log(require('js-yaml').safeLoad(fs.readFileSync('$PEERTUBE_PATH/config/production.yaml', 'utf8'))['database']['username'])")
DB_PASS=$(node -e "console.log(require('js-yaml').safeLoad(fs.readFileSync('$PEERTUBE_PATH/config/production.yaml', 'utf8'))['database']['password'])")
DB_HOST=$(node -e "console.log(require('js-yaml').safeLoad(fs.readFileSync('$PEERTUBE_PATH/config/production.yaml', 'utf8'))['database']['hostname'])")
DB_SUFFIX=$(node -e "console.log(require('js-yaml').safeLoad(fs.readFileSync('$PEERTUBE_PATH/config/production.yaml', 'utf8'))['database']['suffix'])")
mkdir -p $PEERTUBE_PATH/backup

# Get and Display the Latest Version
VERSION=$(curl -s https://api.github.com/repos/phief/exode/releases/latest | grep tag_name | cut -d '"' -f 4)
echo "Latest Peertube version is $VERSION"
wget -q "https://api.github.com/repos/PhieF/Exode/zipball/${VERSION}" -O "$PEERTUBE_PATH/versions/peertube-${VERSION}.zip"

cd $PEERTUBE_PATH/versions
unzip -o "peertube-${VERSION}.zip"
rm -f "peertube-${VERSION}.zip"
mv PhieF* "peertube-${VERSION}"

# Upgrade Scripts
rm -rf $PEERTUBE_PATH/peertube-latest
ln -s "$PEERTUBE_PATH/versions/peertube-${VERSION}" $PEERTUBE_PATH/peertube-latest
cd $PEERTUBE_PATH/peertube-latest
yarn install --production --pure-lockfile 
cp $PEERTUBE_PATH/peertube-latest/config/default.yaml $PEERTUBE_PATH/config/default.yaml

echo "Differences in configuration files..."
diff -u $PEERTUBE_PATH/config/production.yaml "$PEERTUBE_PATH/versions/peertube-${VERSION}/config/production.yaml.example"

