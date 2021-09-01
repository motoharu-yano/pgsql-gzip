rm build -rf
mkdir build
cd build

cmake \
    -D CMAKE_SYSTEM_PREFIX_PATH=$PREFIX \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=$PREFIX \
    ..

make -j$CPU_COUNT

cd ./code
/bin/bash -e ./pgsql_install.sh

export PGPORT=54322
export PGDATA=$SRC_DIR/pgdata

# cleanup required when building variants
rm -rf $PGDATA

pg_ctl initdb

# ensure that the gzip extension is loaded at process startup
echo "shared_preload_libraries = 'gzip'" >> $PGDATA/postgresql.conf

pg_ctl start -l $PGDATA/log.txt

# wait a few seconds just to make sure that the server has started
sleep 2

set +e
ctest
check_result=$?
set -e

pg_ctl stop

exit $check_result