-- Register the stream of SFDC CDC Opportunities
CREATE STREAM STREAM_SFDC_CDC_OPPORTUNITY_RAW
WITH (
  KAFKA_TOPIC='sfdc.cdc.raw',
  VALUE_FORMAT='AVRO',
  PARTITIONS=6
);

-- Create a new stream with Replay ID and Change Event Header for just Gap Events
CREATE STREAM STREAM_SFDC_CDC_OPPORTUNITY_CHANGE_LOG AS
  SELECT
    STREAM_SFDC_CDC_OPPORTUNITY_RAW.REPLAYID AS REPLAYID,
    STREAM_SFDC_CDC_OPPORTUNITY_RAW.CHANGEEVENTHEADER AS CHANGEEVENTHEADER
  FROM STREAM_SFDC_CDC_OPPORTUNITY_RAW
  WHERE UCASE(STREAM_SFDC_CDC_OPPORTUNITY_RAW.CHANGEEVENTHEADER->CHANGETYPE) LIKE 'GAP%'
  EMIT CHANGES;