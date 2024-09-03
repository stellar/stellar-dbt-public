{{ config(
    severity="error"
    , tags=["singular_test"]
    )
}}

with bucketlist_db_size as (
  select sequence,
    closed_at,
    total_byte_size_of_bucket_list / 1000000000 as bl_db_gb
  from `crypto-stellar.crypto_stellar.history_ledgers`
  where closed_at >= current_timestamp() - interval 1 hour
  -- alert when the bucketlist has grown larger than 12 gb
    and total_byte_size_of_bucket_list / 1000000000 >= 12 
)

select 
if (
  (select count(*)
    from bucketlist_db_size
  ) = 0,
  --Return when True:
  'Bucketlist is under 12GB',
  -- Return Alert when False:
  ERROR('BucketlistDB size has exceeded 12GB!'))
  ;
  select true;
