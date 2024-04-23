#!/bin/bash

# start replica
docker-compose down -v
rm -rf ./master/data/*
rm -rf ./slave1/data/*
rm -rf ./slave2/data/*
# docker-compose build
docker-compose up -d

# master: wait connect success
until docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql_master database connection..."
    sleep 4
done

# master: add replica user1
priv_stmt='CREATE USER "mydb_slave1_user"@"%" IDENTIFIED BY "mydb_slave1_pwd"; GRANT REPLICATION SLAVE ON *.* TO "mydb_slave1_user"@"%"; FLUSH PRIVILEGES;'
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"
# master: add replica user2
priv_stmt='CREATE USER "mydb_slave2_user"@"%" IDENTIFIED BY "mydb_slave2_pwd"; GRANT REPLICATION SLAVE ON *.* TO "mydb_slave2_user"@"%"; FLUSH PRIVILEGES;'
docker exec mysql_master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"


# slaves: wait connect success
until docker-compose exec mysql_slave1 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql_slave1 database connection..."
    sleep 4
done

# slave1: follow master
start_slave1_stmt="CHANGE MASTER TO MASTER_HOST='mysql_master',MASTER_USER='mydb_slave1_user',MASTER_PASSWORD='mydb_slave1_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave1_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave1_cmd+="$start_slave1_stmt"
start_slave1_cmd+='"'
docker exec mysql_slave1 sh -c "$start_slave1_cmd"
# slave1: show slave status
docker exec mysql_slave1 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"


# slave2: follow master
start_slave2_stmt="CHANGE MASTER TO MASTER_HOST='mysql_master',MASTER_USER='mydb_slave2_user',MASTER_PASSWORD='mydb_slave2_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave2_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave2_cmd+="$start_slave2_stmt"
start_slave2_cmd+='"'
docker exec mysql_slave2 sh -c "$start_slave2_cmd"
# slave2: show slave status
docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"





# master: show master status
# MS_STATUS=`docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
# CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
# CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`
docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'

# master: update sql and check status
docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "USE mydb; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL); INSERT INTO users (name) VALUES (\"John Doe\");"'
docker exec mysql_master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'

# slave1: get table and check sync
docker exec mysql_slave1 sh -c 'export MYSQL_PWD=111; mysql -u root -e "USE mydb; show create table users;"'
docker exec mysql_slave1 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"
# slave2: get data and check sync
docker exec mysql_slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e "select * from mydb.users;"'
docker exec mysql_slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"



