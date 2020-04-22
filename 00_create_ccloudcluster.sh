#!/bin/bash

###### set environment variables
# CCloud environment CMWORKSHOPS, have to be created before
source env-vars

## Internal variables
pwd > basedir
export BASEDIR=$(cat basedir)
echo $BASEDIR

###### Create cluster automatically

# CREATE ssource CCLOUD cluster 
ccloud update
ccloud login
# environment CMWorkshops
ccloud environment use $XX_CCLOUD_ENV
# Cluster1
ccloud kafka cluster create $XX_CCLOUD_CLUSTERNAME1 --cloud gcp --region europe-west1 > clusterid1
# set cluster id as parameter
export CCLOUD_CLUSTERID1=$(sed 's/|//g' clusterid1 | awk '/Id/{print $NF}')
export CCLOUD_CLUSTERID1_BOOTSTRAP=$(sed 's/|//g' clusterid1 | awk '/Endpoint     SASL_SSL:\/\//{print $NF}' | sed 's/SASL_SSL:\/\///g')
echo $CCLOUD_CLUSTERID1
echo $CCLOUD_CLUSTERID1_BOOTSTRAP
ccloud kafka cluster use $CCLOUD_CLUSTERID1
ccloud kafka cluster describe $CCLOUD_CLUSTERID1 -o human
# create API Keys
ccloud api-key create --resource $CCLOUD_CLUSTERID1 --description "API Key for cluster user" -o yaml > apikey1
export CCLOUD_KEY1=$(awk '/key/{print $NF}' apikey1)
export CCLOUD_SECRET1=$(awk '/secret/{print $NF}' apikey1)
echo $CCLOUD_KEY1
echo $CCLOUD_SECRET1
# create property-file for ccloud user1
echo "ssl.endpoint.identification.algorithm=https
sasl.mechanism=PLAIN
request.timeout.ms=20000
bootstrap.servers=$CCLOUD_CLUSTERID1_BOOTSTRAP
retry.backoff.ms=500
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$CCLOUD_KEY1\" password=\"$CCLOUD_SECRET1\";
security.protocol=SASL_SSL" > ccloud_user1.properties

## Create Target Cluster
# Cluster1
ccloud kafka cluster create $XX_CCLOUD_CLUSTERNAME2 --cloud aws --region eu-central-1 > clusterid2
# set cluster id as parameter
export CCLOUD_CLUSTERID2=$(sed 's/|//g' clusterid2 | awk '/Id/{print $NF}')
export CCLOUD_CLUSTERID2_BOOTSTRAP=$(sed 's/|//g' clusterid2 | awk '/Endpoint     SASL_SSL:\/\//{print $NF}' | sed 's/SASL_SSL:\/\///g')
echo $CCLOUD_CLUSTERID2
echo $CCLOUD_CLUSTERID2_BOOTSTRAP
ccloud kafka cluster use $CCLOUD_CLUSTERID2
ccloud kafka cluster describe $CCLOUD_CLUSTERID2 -o human
# create API Keys
ccloud api-key create --resource $CCLOUD_CLUSTERID2 --description "API Key for cluster user" -o yaml > apikey2
export CCLOUD_KEY2=$(awk '/key/{print $NF}' apikey2)
export CCLOUD_SECRET2=$(awk '/secret/{print $NF}' apikey2)
echo $CCLOUD_KEY2
echo $CCLOUD_SECRET2
# create property-file for ccloud user2
echo "ssl.endpoint.identification.algorithm=https
sasl.mechanism=PLAIN
request.timeout.ms=20000
bootstrap.servers=$CCLOUD_CLUSTERID2_BOOTSTRAP
retry.backoff.ms=500
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$CCLOUD_KEY2\" password=\"$CCLOUD_SECRET2\";
security.protocol=SASL_SSL" > ccloud_user2.properties
# Get Schema Registry infos
ccloud schema-registry cluster describe -o yaml > srinfos
export CCLOUD_SRID=$(awk '/cluster_id/{print $NF}'  srinfos)
export CCLOUD_SRURL=$(awk '/endpoint_url/{print $NF}'  srinfos)
echo $CCLOUD_SRID
echo $CCLOUD_SRURL
# Create SCHEMA Registry API KEY
ccloud api-key create --resource $CCLOUD_SRID --description "API Key for Replicator show case" -o yaml > srkey
export CCLOUD_SRKEY=$(awk '/key/{print $NF}' srkey)
export CCLOUD_SRSECRET=$(awk '/secret/{print $NF}' srkey)
echo $CCLOUD_SRKEY
echo $CCLOUD_SRSECRET

# create connect-avro_distributed.properties file
echo "ssl.endpoint.identification.algorithm=https
sasl.mechanism=PLAIN
request.timeout.ms=20000
bootstrap.servers=$CCLOUD_CLUSTERID2_BOOTSTRAP
retry.backoff.ms=500
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$CCLOUD_KEY2\" password=\"$CCLOUD_SECRET2\";
security.protocol=SASL_SSL
# unique name for the cluster, used in forming the Connect cluster group. Note that this must not conflict with consumer group IDs
group.id=connect-cluster-distributed
producer.ssl.endpoint.identification.algorithm=https
producer.sasl.mechanism=PLAIN
producer.request.timeout.ms=20000
producer.bootstrap.servers=$CCLOUD_CLUSTERID2_BOOTSTRAP
producer.retry.backoff.ms=500
producer.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$CCLOUD_KEY2\" password=\"$CCLOUD_SECRET2\";
producer.security.protocol=SASL_SSL
#Avro Converter with Schema Registry
key.converter=io.confluent.connect.avro.AvroConverter
key.converter.schema.registry.url=$CCLOUD_SRURL
key.converter.basic.auth.credentials.source=USER_INFO
key.converter.schema.registry.basic.auth.user.info=$CCLOUD_SRKEY:$CCLOUD_SRSECRET
value.converter=io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url=$CCLOUD_SRURL
value.converter.basic.auth.credentials.source=USER_INFO
value.converter.schema.registry.basic.auth.user.info=$CCLOUD_SRKEY:$CCLOUD_SRSECRET
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.topic=connect-offsets
offset.storage.replication.factor=3
config.storage.topic=connect-configs
config.storage.replication.factor=3
status.storage.topic=connect-status
status.storage.replication.factor=3
# Flush much faster than normal, which is useful for testing/debugging
offset.flush.interval.ms=10000
plugin.path=/Users/cmutzlitz/software/confluent/share/java
# Connection settings for destination Confluent Cloud Schema Registry
schema.registry.url=$CCLOUD_SRURL
schema.registry.client.basic.auth.credentials.source=USER_INFO
schema.registry.client.basic.auth.user.info=$CCLOUD_SRKEY:$CCLOUD_SRSECRET" > connect-avro_distributed.properties 

# create replicator json file
echo "{
\"name\": \"replicate-topic\",
\"config\": {
    \"connector.class\": \"io.confluent.connect.replicator.ReplicatorSourceConnector\",
    \"key.converter\": \"io.confluent.connect.replicator.util.ByteArrayConverter\",
    \"value.converter\": \"io.confluent.connect.replicator.util.ByteArrayConverter\",
    \"src.kafka.ssl.endpoint.identification.algorithm\":\"https\",
    \"src.kafka.sasl.mechanism\":\"PLAIN\",
    \"src.kafka.request.timeout.ms\":\"20000\",
    \"src.kafka.bootstrap.servers\":\"$CCLOUD_CLUSTERID1_BOOTSTRAP\",
    \"src.kafka.retry.backoff.ms\":\"500\",
    \"src.kafka.sasl.jaas.config\":\"org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"$CCLOUD_KEY1\\\" password=\\\"$CCLOUD_SECRET1\\\";\",
    \"src.kafka.security.protocol\":\"SASL_SSL\",
    \"dest.kafka.ssl.endpoint.identification.algorithm\":\"https\",
    \"dest.kafka.sasl.mechanism\":\"PLAIN\",
    \"dest.kafka.request.timeout.ms\":\"20000\",
    \"dest.kafka.bootstrap.servers\":\"$CCLOUD_CLUSTERID2_BOOTSTRAP\",
    \"dest.kafka.retry.backoff.ms\":\"500\",
    \"dest.kafka.sasl.jaas.config\":\"org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"$CCLOUD_KEY2\\\" password=\\\"$CCLOUD_SECRET2\\\";\",
    \"dest.kafka.security.protocol\":\"SASL_SSL\",
    \"topic.whitelist\":\"cmorders_avro\"
    }
}" > replicator_avro.json

echo "************************************************"
echo "Clusters are created give it 2 Minutes to start..."
echo "In the meantime start one iterm terminal..."
sleep 120

# create topic
# topic in ccloud
#kafka-topics --create --bootstrap-server $(sed 's/|//g' clusterid1 | awk '/Endpoint     SASL_SSL:\/\//{print $NF}' | sed 's/SASL_SSL:\/\///g') --topic cmorders \
#--replication-factor 3 --partitions 6 --command-config ./ccloud_user1.properties 
kafka-topics --create --bootstrap-server $CCLOUD_CLUSTERID1_BOOTSTRAP --topic cmorders_avro \
--replication-factor 3 --partitions 6 --command-config ./ccloud_user1.properties 
echo "Topic created"
kafka-topics --describe --bootstrap-server $CCLOUD_CLUSTERID1_BOOTSTRAP --topic cmorders_avro --command-config ./ccloud_user1.properties 

# open Replicator, Producer and Consumer Terminals
echo "Open Replicator, producer and consumer Terminals with iterm...."
open -a iterm
sleep 10
osascript 01_replicator.scpt $BASEDIR
echo ">>>>>>>>>> Connect and Replicator will be started..."
echo ">>>>>>>>>> Consume from source and target in parallel..."
echo ">>>>>>>>>> Produce and see how fast data is replicated..."
echo ">>>>>>>>>>Now switch to iTerm 2 and see producing and consuming"

# Finish
echo "Cluster $XX_CCLOUD_CLUSTERNAME1 and $XX_CCLOUD_CLUSTERNAME2 created"