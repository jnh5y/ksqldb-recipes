---
seo:
  title: Next Best Offer - Anticipating Your Customer's Needs 
  description: This recipe demonstrates how to use ksqlDB to present relevant offers to your customers from a banking perspective.
---

# Next Best Offer - Anticipating Your Customer's Needs

Consumers today are faced with never ending marketing messages from a variety of sources.  Often these messages are generic and don't have any consideration for the individual needs of the consumer.  This one-size-fits-all approach leads to poor conversion rates.  A better approach is to tailor offerings that take into consideration the interests of the consumer based on previous purchases or behavior.   This recipe demonstrates how to take existing customer information and provide a "Next Best Offer" to encourage sales and retain customers.

## Step-by-step

### Setup your Environment

Provision a Kafka cluster in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/?utm_source=github&utm_medium=ksqldb_recipes&utm_campaign=inventory).


--8<-- "docs/shared/ccloud_setup.md"

### Read the data in

--8<-- "docs/shared/connect.md"

```json
--8<-- "docs/predictive-analytics/next-best-offer/source.json"
```

--8<-- "docs/shared/manual_insert.md"

### Run stream processing app

This application will perform a series of joins between event streams and tables to calculate the next best offer for a banking consumer based on their activity which should yield higher customer activity and satisfaction.

--8<-- "docs/shared/ksqlb_processing_intro.md"

```sql
--8<-- "docs/predictive-analytics/next-best-offer/process.sql"
```

--8<-- "docs/shared/manual_cue.md"

```sql
--8<-- "docs/predictive-analytics/next-best-offer/manual.sql"
```


### Cleanup

--8<-- "docs/shared/cleanup.md"

## Explanation

### Creating an event stream

To get started you'll first need to create a stream that contains the customer activity:

```sql
CREATE STREAM CUSTOMER_ACTIVITY_STREAM (
    ACTIVITY_ID INTEGER,
    IP_ADDRESS STRING,
    CUSTOMER_ID INTEGER KEY,
    ACTIVITY_TYPE STRING,
    PROPENSITY_TO_BUY DOUBLE
   ) WITH (
    KAFKA_TOPIC = 'CUSTOMER_ACTIVITY_STREAM',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 6
);
```

You should take note that the `CUSTOMER_ID` field is the key in the stream's key-value pairs and you'll see why this is important in the next section.

In a production setting you'll populate the stream's underlying topic either with `KafkaProducer` application or from an external system using a [managed connector on Confluent Cloud](https://docs.confluent.io/cloud/current/connectors/index.html) But for the purpose of running this example you'll manually insert records into the stream with [INSERT VALUES](https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-reference/insert-values/#insert-values) statements:

```sql
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (1,'121.219.110.170',1,'branch_visit',0.4);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (2,'210.232.55.188',2,'deposit',0.56);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (3,'84.197.123.173',3,'web_open',0.33);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (4,'70.149.233.32',1,'deposit',0.41);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (5,'221.234.209.67',2,'deposit',0.44);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (6,'102.187.28.148',3,'web_open',0.33);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (7,'135.37.250.250',1,'mobile_open',0.97);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (8,'122.157.243.25',2,'deposit',0.83);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (9,'114.215.212.181',3,'deposit',0.86);
INSERT INTO CUSTOMER_ACTIVITY_STREAM (activity_id, ip_address, customer_id, activity_type, propensity_to_buy) VALUES (10,'248.248.0.78',1,'new_account',0.14);
```

### Adding the lookup tables

In the event stream you created above, each activity entry contains only the id for the customer, this is expected as it's a common practice to have [normalized](https://en.wikipedia.org/wiki/Database_normalization) event streams.  But when it comes time to analyze the data, it's important to have additional customer information to provide context for any analysts reviewing the results. You'll also need a table for the calculated offer based off customer activity.

#### Creating the customer table and inserting records

First you'll create the table for customer information:

```sql
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID INTEGER PRIMARY KEY,
    FIRST_NAME STRING,
    LAST_NAME STRING,
    EMAIL STRING,
    GENDER STRING,
    INCOME INTEGER,
    FICO INTEGER
) WITH (
    KAFKA_TOPIC = 'CUSTOMERS_TABLE',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 6
);
```

Typically, customer information would be sourced from an existing database. As customer details change, tables in the database are updated and we can stream them into Kafka using Kafka Connect with [change data capture](https://www.confluent.io/blog/cdc-and-streaming-analytics-using-debezium-kafka/).  The primary key for the `CUSTOMERS` is the customer id which corresponds to the key of the `CUSTOMER_ACTIVITY_STREAM` which facilitates joins for enriching customer information.  For the purposes of running the example you'll execute these insert statements to populate the `CUSTOMERS` table:

```sql
INSERT INTO CUSTOMERS (customer_id, first_name, last_name, email, gender, income, fico) VALUES  (1,'Waylen','Tubble','wtubble0@hc360.com','Male',403646, 465);
INSERT INTO CUSTOMERS (customer_id, first_name, last_name, email, gender, income, fico) VALUES  (2,'Joell','Wilshin','jwilshin1@yellowpages.com','Female',109825, 624);
INSERT INTO CUSTOMERS (customer_id, first_name, last_name, email, gender, income, fico) VALUES  (3,'Ilaire','Latus','ilatus2@baidu.com','Male',407964, 683);
```

#### Creating the offer table

The last lookup table you'll add is the `OFFERS` table:

```sql
CREATE TABLE OFFERS (
    OFFER_ID INTEGER PRIMARY KEY,
    OFFER_NAME STRING,
    OFFER_URL STRING
) WITH (
    KAFKA_TOPIC = 'OFFERS_STREAM',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 6
);
```

This table provides the enrichment information needed once the application calculates the "next best offer".

Here are the insert statements to fill the `OFFERS` table:

```sql
INSERT INTO OFFERS (offer_id, offer_name, offer_url) VALUES (1,'new_savings','http://google.com.br/magnis/dis/parturient.json');
INSERT INTO OFFERS (offer_id, offer_name, offer_url) VALUES (2,'new_checking','https://earthlink.net/in/ante.js');
INSERT INTO OFFERS (offer_id, offer_name, offer_url) VALUES (3,'new_home_loan','https://webs.com/in/ante.jpg');
INSERT INTO OFFERS (offer_id, offer_name, offer_url) VALUES (4,'new_auto_loan','http://squidoo.com/venenatis/non/sodales/sed/tincidunt/eu.js');
INSERT INTO OFFERS (offer_id, offer_name, offer_url) VALUES (5,'no_offer','https://ezinearticles.com/ipsum/primis/in/faucibus/orci/luctus.html');
```

### Determining the next best offer

Now you'll create the stream that calculates the next best offer for your customers based on their activity. 

#### Calculating the offer

To perform the next offer calculation you'll create a stream that performs a join between the `CUSTOMER_ACTIVITY_STREAM` and the `CUSTOMERS` table

```sql
CREATE STREAM NEXT_BEST_OFFER
WITH (
    KAFKA_TOPIC = 'NEXT_BEST_OFFER',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 6
) AS
SELECT 
cask.ACTIVITY_ID,
cask.CUSTOMER_ID as CUSTOMER_ID,
cask.PROPENSITY_TO_BUY,
cask.ACTIVITY_TYPE,
ct.INCOME,
ct.FICO,
CASE  
    WHEN ct.INCOME > 100000 AND ct.FICO < 700 AND cask.PROPENSITY_TO_BUY < 0.9 THEN 1
    WHEN ct.INCOME < 50000 AND cask.PROPENSITY_TO_BUY < 0.9 THEN 2
    WHEN ct.INCOME >= 50000 AND ct.FICO >= 600 AND cask.PROPENSITY_TO_BUY < 0.9 THEN 3
    WHEN ct.INCOME > 100000 AND ct.FICO >= 700 AND cask.PROPENSITY_TO_BUY < 0.9 THEN 4
    ELSE 5
END AS OFFER_ID 
FROM CUSTOMER_ACTIVITY_STREAM cask
INNER JOIN CUSTOMERS ct ON cask.CUSTOMER_ID = ct.CUSTOMER_ID
```
The `CASE` statement is the workhorse for the query and provides the next offer for the customer based on information resulting from the join.  Note that you're using an `INNER JOIN` here because if the customer id isn't found in the `CUSTOMERS` table there's no calculation to make.  You'll notice that the result of the `CASE` statement is a single integer with the code for the offer to make, so you'll have one final step to take.

#### Final results

For the last step you'll create a query which contains the final results by joining the `NEXT_BEST_OFFER` stream with the `OFFERS` table:

```sql
CREATE STREAM NEXT_BEST_OFFER_LOOKUP
WITH (
    KAFKA_TOPIC = 'NEXT_BEST_OFFER_LOOKUP',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 6
) AS
SELECT
    nbo.OFFER_ID,
    nbo.ACTIVITY_ID,
    nbo.CUSTOMER_ID,
    nbo.PROPENSITY_TO_BUY,
    nbo.ACTIVITY_TYPE,
    nbo.INCOME,
    nbo.FICO,
    ot.OFFER_NAME,
    ot.OFFER_URL
FROM NEXT_BEST_OFFER nbo
INNER JOIN OFFERS ot
ON nbo.OFFER_ID = ot.OFFER_ID;
```






