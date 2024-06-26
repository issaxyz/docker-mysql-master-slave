#!/bin/bash

# start replica
docker-compose down -v
rm -rf ./master/data/*
rm -rf ./slave1/data/*
rm -rf ./slave2/data/*
# docker-compose build
docker-compose up -d

# master: wait connect success
until docker exec mysql-master sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql-master database connection..."
    sleep 4
done

# master: add replica user1
priv_stmt='CREATE USER "mydb_slave1_user"@"%" IDENTIFIED BY "mydb_slave1_pwd"; GRANT REPLICATION SLAVE ON *.* TO "mydb_slave1_user"@"%"; FLUSH PRIVILEGES;'
docker exec mysql-master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"
# master: add replica user2
priv_stmt='CREATE USER "mydb_slave2_user"@"%" IDENTIFIED BY "mydb_slave2_pwd"; GRANT REPLICATION SLAVE ON *.* TO "mydb_slave2_user"@"%"; FLUSH PRIVILEGES;'
docker exec mysql-master sh -c "export MYSQL_PWD=111; mysql -u root -e '$priv_stmt'"


# slaves1: wait connect success
until docker-compose exec mysql-slave1 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql-slave1 database connection..."
    sleep 4
done
# slaves2: wait connect success
until docker-compose exec mysql-slave1 sh -c 'export MYSQL_PWD=111; mysql -u root -e ";"'
do
    echo "Waiting for mysql-slave2 database connection..."
    sleep 4
done

# get log pos
MS_STATUS=`docker exec mysql-master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'`
CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`
echo "Current Log File: $CURRENT_LOG"
echo "Current Log Position: $CURRENT_POS"
echo

# slave1: follow master
start_slave1_stmt="CHANGE MASTER TO MASTER_HOST='mysql-master',MASTER_USER='mydb_slave1_user',MASTER_PASSWORD='mydb_slave1_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave1_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave1_cmd+="$start_slave1_stmt"
start_slave1_cmd+='"'
docker exec mysql-slave1 sh -c "$start_slave1_cmd"
# slave1: show slave1 status
echo "------------> slave1: show slave1 status"
docker exec mysql-slave1 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"
echo

# slave2: follow master
start_slave2_stmt="CHANGE MASTER TO MASTER_HOST='mysql-master',MASTER_USER='mydb_slave2_user',MASTER_PASSWORD='mydb_slave2_pwd',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave2_cmd='export MYSQL_PWD=111; mysql -u root -e "'
start_slave2_cmd+="$start_slave2_stmt"
start_slave2_cmd+='"'
docker exec mysql-slave2 sh -c "$start_slave2_cmd"
# slave2: show slave2 status
echo "------------> slave2: show slave2 status"
docker exec mysql-slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"
echo
echo


# master: show master status(before & after)
echo "------------> master: show master status(before & after)"
docker exec mysql-master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'
# master: update sql and check status
docker exec mysql-master sh -c 'export MYSQL_PWD=111; mysql -u root -e "USE mydb; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL); INSERT INTO users (name) VALUES (\"John Doe\");"'
docker exec mysql-master sh -c 'export MYSQL_PWD=111; mysql -u root -e "SHOW MASTER STATUS"'|tail -n 1
echo
echo
sleep 1

# slave1: get table and check sync
echo "------------>  slave1: get table"
docker exec mysql-slave1 sh -c 'export MYSQL_PWD=111; mysql -u root -e "USE mydb; show create table users;"'
echo
echo "------------>  slave1: check sync"
docker exec mysql-slave1 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"
echo
echo

# slave2: get data and check sync
echo "------------>  slave1: get data"
docker exec mysql-slave2 sh -c 'export MYSQL_PWD=111; mysql -u root -e "select * from mydb.users;"'
echo
echo "------------>  slave1: check sync"
docker exec mysql-slave2 sh -c "export MYSQL_PWD=111; mysql -u root -e 'SHOW SLAVE STATUS \G'"|egrep "Running|Pos"



