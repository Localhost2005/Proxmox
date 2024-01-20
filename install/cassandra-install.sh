#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y apt-transport-https
$STD apt-get install -y gnupg
msg_ok "Installed Dependencies"

msg_info "Installing OpenJDK"
wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor >/etc/apt/trusted.gpg.d/adoptium.gpg
echo 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main' >/etc/apt/sources.list.d/adoptium.list
$STD apt-get update
$STD apt-get install -y temurin-8-jdk
msg_ok "Installed OpenJDK"


msg_info "Installing Cassandra"
cd /opt
wget -q https://dlcdn.apache.org/cassandra/4.1.3/apache-cassandra-4.1.3-bin.tar.gz
$STD tar -xvzf apache-cassandra-4.1.3-bin.tar.gz
mv apache-cassandra-4.1.3 cassandra
mv /opt/cassandra/conf/cassandra.yaml /opt/cassandra/conf/cassandra.yaml.bak
cat <<'EOF' >/opt/cassandra/conf/cassandra.yaml
# Cassandra storage config YAML

# NOTE:
#   See https://cassandra.apache.org/doc/latest/configuration/ for
#   full explanations of configuration directives
# /NOTE

# The name of the cluster. This is mainly used to prevent machines in
# one logical cluster from joining another.
cluster_name: 'Test Cluster'

# This defines the number of tokens randomly assigned to this node on the ring
# The more tokens, relative to other nodes, the larger the proportion of data
# that this node will store. You probably want all nodes to have the same number
# of tokens assuming they have equal hardware capability.
#
# If you leave this unspecified, Cassandra will use the default of 1 token for legacy compatibility,
# and will use the initial_token as described below.
#
# Specifying initial_token will override this setting on the node's initial start,
# on subsequent starts, this setting will apply even if initial token is set.
#
# See https://cassandra.apache.org/doc/latest/getting_started/production.html#tokens for
# best practice information about num_tokens.
#
num_tokens: 16

# Triggers automatic allocation of num_tokens tokens for this node. The allocation
# algorithm attempts to choose tokens in a way that optimizes replicated load over
# the nodes in the datacenter for the replica factor.
#
# The load assigned to each node will be close to proportional to its number of
# vnodes.
#
# Only supported with the Murmur3Partitioner.

# Replica factor is determined via the replication strategy used by the specified
# keyspace.
# allocate_tokens_for_keyspace: KEYSPACE

# Replica factor is explicitly set, regardless of keyspace or datacenter.
# This is the replica factor within the datacenter, like NTS.
allocate_tokens_for_local_replication_factor: 3

# initial_token allows you to specify tokens manually.  While you can use it with
# vnodes (num_tokens > 1, above) -- in which case you should provide a 
# comma-separated list -- it's primarily used when adding nodes to legacy clusters 
# that do not have vnodes enabled.
# initial_token:

# May either be "true" or "false" to enable globally
hinted_handoff_enabled: true

# When hinted_handoff_enabled is true, a black list of data centers that will not
# perform hinted handoff
# hinted_handoff_disabled_datacenters:
#    - DC1
#    - DC2

# this defines the maximum amount of time a dead host will have hints
# generated.  After it has been dead this long, new hints for it will not be
# created until it has been seen alive and gone down again.
# Min unit: ms
max_hint_window: 3h

# Maximum throttle in KiBs per second, per delivery thread.  This will be
# reduced proportionally to the number of nodes in the cluster.  (If there
# are two nodes in the cluster, each delivery thread will use the maximum
# rate; if there are three, each will throttle to half of the maximum,
# since we expect two nodes to be delivering hints simultaneously.)
# Min unit: KiB
hinted_handoff_throttle: 1024KiB

# Number of threads with which to deliver hints;
# Consider increasing this number when you have multi-dc deployments, since
# cross-dc handoff tends to be slower
max_hints_delivery_threads: 2

# Directory where Cassandra should store hints.
# If not set, the default directory is $CASSANDRA_HOME/data/hints.
# hints_directory: /var/lib/cassandra/hints

# How often hints should be flushed from the internal buffers to disk.
# Will *not* trigger fsync.
# Min unit: ms
hints_flush_period: 10000ms

# Maximum size for a single hints file, in mebibytes.
# Min unit: MiB
max_hints_file_size: 128MiB

# The file size limit to store hints for an unreachable host, in mebibytes.
# Once the local hints files have reached the limit, no more new hints will be created.
# Set a non-positive value will disable the size limit.
# max_hints_size_per_host: 0MiB

# Enable / disable automatic cleanup for the expired and orphaned hints file.
# Disable the option in order to preserve those hints on the disk.
auto_hints_cleanup_enabled: false

# Compression to apply to the hint files. If omitted, hints files
# will be written uncompressed. LZ4, Snappy, and Deflate compressors
# are supported.
#hints_compression:
#   - class_name: LZ4Compressor
#     parameters:
#         -

# Enable / disable persistent hint windows.
#
# If set to false, a hint will be stored only in case a respective node
# that hint is for is down less than or equal to max_hint_window.
#
# If set to true, a hint will be stored in case there is not any
# hint which was stored earlier than max_hint_window. This is for cases
# when a node keeps to restart and hints are not delivered yet, we would be saving
# hints for that node indefinitely.
#
# Defaults to true.
#
# hint_window_persistent_enabled: true

# Maximum throttle in KiBs per second, total. This will be
# reduced proportionally to the number of nodes in the cluster.
# Min unit: KiB
batchlog_replay_throttle: 1024KiB

# Authentication backend, implementing IAuthenticator; used to identify users
# Out of the box, Cassandra provides org.apache.cassandra.auth.{AllowAllAuthenticator,
# PasswordAuthenticator}.
#
# - AllowAllAuthenticator performs no checks - set it to disable authentication.
# - PasswordAuthenticator relies on username/password pairs to authenticate
#   users. It keeps usernames and hashed passwords in system_auth.roles table.
#   Please increase system_auth keyspace replication factor if you use this authenticator.
#   If using PasswordAuthenticator, CassandraRoleManager must also be used (see below)
authenticator: AllowAllAuthenticator

# Authorization backend, implementing IAuthorizer; used to limit access/provide permissions
# Out of the box, Cassandra provides org.apache.cassandra.auth.{AllowAllAuthorizer,
# CassandraAuthorizer}.
#
# - AllowAllAuthorizer allows any action to any user - set it to disable authorization.
# - CassandraAuthorizer stores permissions in system_auth.role_permissions table. Please
#   increase system_auth keyspace replication factor if you use this authorizer.
authorizer: AllowAllAuthorizer

# Part of the Authentication & Authorization backend, implementing IRoleManager; used
# to maintain grants and memberships between roles.
# Out of the box, Cassandra provides org.apache.cassandra.auth.CassandraRoleManager,
# which stores role information in the system_auth keyspace. Most functions of the
# IRoleManager require an authenticated login, so unless the configured IAuthenticator
# actually implements authentication, most of this functionality will be unavailable.
#
# - CassandraRoleManager stores role data in the system_auth keyspace. Please
#   increase system_auth keyspace replication factor if you use this role manager.
role_manager: CassandraRoleManager

# Network authorization backend, implementing INetworkAuthorizer; used to restrict user
# access to certain DCs
# Out of the box, Cassandra provides org.apache.cassandra.auth.{AllowAllNetworkAuthorizer,
# CassandraNetworkAuthorizer}.
#
# - AllowAllNetworkAuthorizer allows access to any DC to any user - set it to disable authorization.
# - CassandraNetworkAuthorizer stores permissions in system_auth.network_permissions table. Please
#   increase system_auth keyspace replication factor if you use this authorizer.
network_authorizer: AllowAllNetworkAuthorizer

# Depending on the auth strategy of the cluster, it can be beneficial to iterate
# from root to table (root -> ks -> table) instead of table to root (table -> ks -> root).
# As the auth entries are whitelisting, once a permission is found you know it to be
# valid. We default to false as the legacy behavior is to query at the table level then
# move back up to the root. See CASSANDRA-17016 for details.
# traverse_auth_from_root: false

# Validity period for roles cache (fetching granted roles can be an expensive
# operation depending on the role manager, CassandraRoleManager is one example)
# Granted roles are cached for authenticated sessions in AuthenticatedUser and
# after the period specified here, become eligible for (async) reload.
# Defaults to 2000, set to 0 to disable caching entirely.
# Will be disabled automatically for AllowAllAuthenticator.
# For a long-running cache using roles_cache_active_update, consider
# setting to something longer such as a daily validation: 86400000
# Min unit: ms
roles_validity: 2000ms

# Refresh interval for roles cache (if enabled).
# After this interval, cache entries become eligible for refresh. Upon next
# access, an async reload is scheduled and the old value returned until it
# completes. If roles_validity is non-zero, then this must be
# also.
# This setting is also used to inform the interval of auto-updating if
# using roles_cache_active_update.
# Defaults to the same value as roles_validity.
# For a long-running cache, consider setting this to 60000 (1 hour) etc.
# Min unit: ms
# roles_update_interval: 2000ms

# If true, cache contents are actively updated by a background task at the
# interval set by roles_update_interval. If false, cache entries
# become eligible for refresh after their update interval. Upon next access,
# an async reload is scheduled and the old value returned until it completes.
# roles_cache_active_update: false

# Validity period for permissions cache (fetching permissions can be an
# expensive operation depending on the authorizer, CassandraAuthorizer is
# one example). Defaults to 2000, set to 0 to disable.
# Will be disabled automatically for AllowAllAuthorizer.
# For a long-running cache using permissions_cache_active_update, consider
# setting to something longer such as a daily validation: 86400000ms
# Min unit: ms
permissions_validity: 2000ms

# Refresh interval for permissions cache (if enabled).
# After this interval, cache entries become eligible for refresh. Upon next
# access, an async reload is scheduled and the old value returned until it
# completes. If permissions_validity is non-zero, then this must be
# also.
# This setting is also used to inform the interval of auto-updating if
# using permissions_cache_active_update.
# Defaults to the same value as permissions_validity.
# For a longer-running permissions cache, consider setting to update hourly (60000)
# Min unit: ms
# permissions_update_interval: 2000ms

# If true, cache contents are actively updated by a background task at the
# interval set by permissions_update_interval. If false, cache entries
# become eligible for refresh after their update interval. Upon next access,
# an async reload is scheduled and the old value returned until it completes.
# permissions_cache_active_update: false

# Validity period for credentials cache. This cache is tightly coupled to
# the provided PasswordAuthenticator implementation of IAuthenticator. If
# another IAuthenticator implementation is configured, this cache will not
# be automatically used and so the following settings will have no effect.
# Please note, credentials are cached in their encrypted form, so while
# activating this cache may reduce the number of queries made to the
# underlying table, it may not  bring a significant reduction in the
# latency of individual authentication attempts.
# Defaults to 2000, set to 0 to disable credentials caching.
# For a long-running cache using credentials_cache_active_update, consider
# setting to something longer such as a daily validation: 86400000
# Min unit: ms
credentials_validity: 2000ms

# Refresh interval for credentials cache (if enabled).
# After this interval, cache entries become eligible for refresh. Upon next
# access, an async reload is scheduled and the old value returned until it
# completes. If credentials_validity is non-zero, then this must be
# also.
# This setting is also used to inform the interval of auto-updating if
# using credentials_cache_active_update.
# Defaults to the same value as credentials_validity.
# For a longer-running permissions cache, consider setting to update hourly (60000)
# Min unit: ms
# credentials_update_interval: 2000ms

# If true, cache contents are actively updated by a background task at the
# interval set by credentials_update_interval. If false (default), cache entries
# become eligible for refresh after their update interval. Upon next access,
# an async reload is scheduled and the old value returned until it completes.
# credentials_cache_active_update: false

# The partitioner is responsible for distributing groups of rows (by
# partition key) across nodes in the cluster. The partitioner can NOT be
# changed without reloading all data.  If you are adding nodes or upgrading,
# you should set this to the same partitioner that you are currently using.
#
# The default partitioner is the Murmur3Partitioner. Older partitioners
# such as the RandomPartitioner, ByteOrderedPartitioner, and
# OrderPreservingPartitioner have been included for backward compatibility only.
# For new clusters, you should NOT change this value.
#
partitioner: org.apache.cassandra.dht.Murmur3Partitioner

# Directories where Cassandra should store data on disk. If multiple
# directories are specified, Cassandra will spread data evenly across 
# them by partitioning the token ranges.
# If not set, the default directory is $CASSANDRA_HOME/data/data.
# data_file_directories:
#     - /var/lib/cassandra/data

# Directory were Cassandra should store the data of the local system keyspaces.
# By default Cassandra will store the data of the local system keyspaces in the first of the data directories specified
# by data_file_directories.
# This approach ensures that if one of the other disks is lost Cassandra can continue to operate. For extra security
# this setting allows to store those data on a different directory that provides redundancy.
# local_system_data_file_directory:

# commit log.  when running on magnetic HDD, this should be a
# separate spindle than the data directories.
# If not set, the default directory is $CASSANDRA_HOME/data/commitlog.
# commitlog_directory: /var/lib/cassandra/commitlog

# Enable / disable CDC functionality on a per-node basis. This modifies the logic used
# for write path allocation rejection (standard: never reject. cdc: reject Mutation
# containing a CDC-enabled table if at space limit in cdc_raw_directory).
cdc_enabled: false

# CommitLogSegments are moved to this directory on flush if cdc_enabled: true and the
# segment contains mutations for a CDC-enabled table. This should be placed on a
# separate spindle than the data directories. If not set, the default directory is
# $CASSANDRA_HOME/data/cdc_raw.
# cdc_raw_directory: /var/lib/cassandra/cdc_raw

# Policy for data disk failures:
#
# die
#   shut down gossip and client transports and kill the JVM for any fs errors or
#   single-sstable errors, so the node can be replaced.
#
# stop_paranoid
#   shut down gossip and client transports even for single-sstable errors,
#   kill the JVM for errors during startup.
#
# stop
#   shut down gossip and client transports, leaving the node effectively dead, but
#   can still be inspected via JMX, kill the JVM for errors during startup.
#
# best_effort
#    stop using the failed disk and respond to requests based on
#    remaining available sstables.  This means you WILL see obsolete
#    data at CL.ONE!
#
# ignore
#    ignore fatal errors and let requests fail, as in pre-1.2 Cassandra
disk_failure_policy: stop

# Policy for commit disk failures:
#
# die
#   shut down the node and kill the JVM, so the node can be replaced.
#
# stop
#   shut down the node, leaving the node effectively dead, but
#   can still be inspected via JMX.
#
# stop_commit
#   shutdown the commit log, letting writes collect but
#   continuing to service reads, as in pre-2.0.5 Cassandra
#
# ignore
#   ignore fatal errors and let the batches fail
commit_failure_policy: stop

# Maximum size of the native protocol prepared statement cache
#
# Valid values are either "auto" (omitting the value) or a value greater 0.
#
# Note that specifying a too large value will result in long running GCs and possbily
# out-of-memory errors. Keep the value at a small fraction of the heap.
#
# If you constantly see "prepared statements discarded in the last minute because
# cache limit reached" messages, the first step is to investigate the root cause
# of these messages and check whether prepared statements are used correctly -
# i.e. use bind markers for variable parts.
#
# Do only change the default value, if you really have more prepared statements than
# fit in the cache. In most cases it is not neccessary to change this value.
# Constantly re-preparing statements is a performance penalty.
#
# Default value ("auto") is 1/256th of the heap or 10MiB, whichever is greater
# Min unit: MiB
prepared_statements_cache_size:

# Maximum size of the key cache in memory.
#
# Each key cache hit saves 1 seek and each row cache hit saves 2 seeks at the
# minimum, sometimes more. The key cache is fairly tiny for the amount of
# time it saves, so it's worthwhile to use it at large numbers.
# The row cache saves even more time, but must contain the entire row,
# so it is extremely space-intensive. It's best to only use the
# row cache if you have hot rows or static rows.
#
# NOTE: if you reduce the size, you may not get you hottest keys loaded on startup.
#
# Default value is empty to make it "auto" (min(5% of Heap (in MiB), 100MiB)). Set to 0 to disable key cache.
# Min unit: MiB
key_cache_size:

# Duration in seconds after which Cassandra should
# save the key cache. Caches are saved to saved_caches_directory as
# specified in this configuration file.
#
# Saved caches greatly improve cold-start speeds, and is relatively cheap in
# terms of I/O for the key cache. Row cache saving is much more expensive and
# has limited use.
#
# Default is 14400 or 4 hours.
# Min unit: s
key_cache_save_period: 4h

# Number of keys from the key cache to save
# Disabled by default, meaning all keys are going to be saved
# key_cache_keys_to_save: 100

# Row cache implementation class name. Available implementations:
#
# org.apache.cassandra.cache.OHCProvider
#   Fully off-heap row cache implementation (default).
#
# org.apache.cassandra.cache.SerializingCacheProvider
#   This is the row cache implementation availabile
#   in previous releases of Cassandra.
# row_cache_class_name: org.apache.cassandra.cache.OHCProvider

# Maximum size of the row cache in memory.
# Please note that OHC cache implementation requires some additional off-heap memory to manage
# the map structures and some in-flight memory during operations before/after cache entries can be
# accounted against the cache capacity. This overhead is usually small compared to the whole capacity.
# Do not specify more memory that the system can afford in the worst usual situation and leave some
# headroom for OS block level cache. Do never allow your system to swap.
#
# Default value is 0, to disable row caching.
# Min unit: MiB
row_cache_size: 0MiB

# Duration in seconds after which Cassandra should save the row cache.
# Caches are saved to saved_caches_directory as specified in this configuration file.
#
# Saved caches greatly improve cold-start speeds, and is relatively cheap in
# terms of I/O for the key cache. Row cache saving is much more expensive and
# has limited use.
#
# Default is 0 to disable saving the row cache.
# Min unit: s
row_cache_save_period: 0s

# Number of keys from the row cache to save.
# Specify 0 (which is the default), meaning all keys are going to be saved
# row_cache_keys_to_save: 100

# Maximum size of the counter cache in memory.
#
# Counter cache helps to reduce counter locks' contention for hot counter cells.
# In case of RF = 1 a counter cache hit will cause Cassandra to skip the read before
# write entirely. With RF > 1 a counter cache hit will still help to reduce the duration
# of the lock hold, helping with hot counter cell updates, but will not allow skipping
# the read entirely. Only the local (clock, count) tuple of a counter cell is kept
# in memory, not the whole counter, so it's relatively cheap.
#
# NOTE: if you reduce the size, you may not get you hottest keys loaded on startup.
#
# Default value is empty to make it "auto" (min(2.5% of Heap (in MiB), 50MiB)). Set to 0 to disable counter cache.
# NOTE: if you perform counter deletes and rely on low gcgs, you should disable the counter cache.
# Min unit: MiB
counter_cache_size:

# Duration in seconds after which Cassandra should
# save the counter cache (keys only). Caches are saved to saved_caches_directory as
# specified in this configuration file.
#
# Default is 7200 or 2 hours.
# Min unit: s
counter_cache_save_period: 7200s

# Number of keys from the counter cache to save
# Disabled by default, meaning all keys are going to be saved
# counter_cache_keys_to_save: 100

# saved caches
# If not set, the default directory is $CASSANDRA_HOME/data/saved_caches.
# saved_caches_directory: /var/lib/cassandra/saved_caches

# Number of seconds the server will wait for each cache (row, key, etc ...) to load while starting
# the Cassandra process. Setting this to zero is equivalent to disabling all cache loading on startup
# while still having the cache during runtime.
# Min unit: s
# cache_load_timeout: 30s

# commitlog_sync may be either "periodic", "group", or "batch." 
# 
# When in batch mode, Cassandra won't ack writes until the commit log
# has been flushed to disk.  Each incoming write will trigger the flush task.
# commitlog_sync_batch_window_in_ms is a deprecated value. Previously it had
# almost no value, and is being removed.
#
# commitlog_sync_batch_window_in_ms: 2
#
# group mode is similar to batch mode, where Cassandra will not ack writes
# until the commit log has been flushed to disk. The difference is group
# mode will wait up to commitlog_sync_group_window between flushes.
#
# Min unit: ms
# commitlog_sync_group_window: 1000ms
#
# the default option is "periodic" where writes may be acked immediately
# and the CommitLog is simply synced every commitlog_sync_period
# milliseconds.
commitlog_sync: periodic
# Min unit: ms
commitlog_sync_period: 10000ms

# When in periodic commitlog mode, the number of milliseconds to block writes
# while waiting for a slow disk flush to complete.
# Min unit: ms
# periodic_commitlog_sync_lag_block:

# The size of the individual commitlog file segments.  A commitlog
# segment may be archived, deleted, or recycled once all the data
# in it (potentially from each columnfamily in the system) has been
# flushed to sstables.
#
# The default size is 32, which is almost always fine, but if you are
# archiving commitlog segments (see commitlog_archiving.properties),
# then you probably want a finer granularity of archiving; 8 or 16 MB
# is reasonable.
# Max mutation size is also configurable via max_mutation_size setting in
# cassandra.yaml. The default is half the size commitlog_segment_size in bytes.
# This should be positive and less than 2048.
#
# NOTE: If max_mutation_size is set explicitly then commitlog_segment_size must
# be set to at least twice the size of max_mutation_size
#
# Min unit: MiB
commitlog_segment_size: 32MiB

# Compression to apply to the commit log. If omitted, the commit log
# will be written uncompressed.  LZ4, Snappy, and Deflate compressors
# are supported.
# commitlog_compression:
#   - class_name: LZ4Compressor
#     parameters:
#         -

# Compression to apply to SSTables as they flush for compressed tables.
# Note that tables without compression enabled do not respect this flag.
#
# As high ratio compressors like LZ4HC, Zstd, and Deflate can potentially
# block flushes for too long, the default is to flush with a known fast
# compressor in those cases. Options are:
#
# none : Flush without compressing blocks but while still doing checksums.
# fast : Flush with a fast compressor. If the table is already using a
#        fast compressor that compressor is used.
# table: Always flush with the same compressor that the table uses. This
#        was the pre 4.0 behavior.
#
# flush_compression: fast

# any class that implements the SeedProvider interface and has a
# constructor that takes a Map<String, String> of parameters will do.
seed_provider:
  # Addresses of hosts that are deemed contact points.
  # Cassandra nodes use this list of hosts to find each other and learn
  # the topology of the ring.  You must change this if you are running
  # multiple nodes!
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      # seeds is actually a comma-delimited list of addresses.
      # Ex: "<ip1>,<ip2>,<ip3>"
      - seeds: "127.0.0.1:7000"

# For workloads with more data than can fit in memory, Cassandra's
# bottleneck will be reads that need to fetch data from
# disk. "concurrent_reads" should be set to (16 * number_of_drives) in
# order to allow the operations to enqueue low enough in the stack
# that the OS and drives can reorder them. Same applies to
# "concurrent_counter_writes", since counter writes read the current
# values before incrementing and writing them back.
#
# On the other hand, since writes are almost never IO bound, the ideal
# number of "concurrent_writes" is dependent on the number of cores in
# your system; (8 * number_of_cores) is a good rule of thumb.
concurrent_reads: 32
concurrent_writes: 32
concurrent_counter_writes: 32

# For materialized view writes, as there is a read involved, so this should
# be limited by the less of concurrent reads or concurrent writes.
concurrent_materialized_view_writes: 32

# Maximum memory to use for inter-node and client-server networking buffers.
#
# Defaults to the smaller of 1/16 of heap or 128MB. This pool is allocated off-heap,
# so is in addition to the memory allocated for heap. The cache also has on-heap
# overhead which is roughly 128 bytes per chunk (i.e. 0.2% of the reserved size
# if the default 64k chunk size is used).
# Memory is only allocated when needed.
# Min unit: MiB
# networking_cache_size: 128MiB

# Enable the sstable chunk cache.  The chunk cache will store recently accessed
# sections of the sstable in-memory as uncompressed buffers.
# file_cache_enabled: false

# Maximum memory to use for sstable chunk cache and buffer pooling.
# 32MB of this are reserved for pooling buffers, the rest is used for chunk cache
# that holds uncompressed sstable chunks.
# Defaults to the smaller of 1/4 of heap or 512MB. This pool is allocated off-heap,
# so is in addition to the memory allocated for heap. The cache also has on-heap
# overhead which is roughly 128 bytes per chunk (i.e. 0.2% of the reserved size
# if the default 64k chunk size is used).
# Memory is only allocated when needed.
# Min unit: MiB
# file_cache_size: 512MiB

# Flag indicating whether to allocate on or off heap when the sstable buffer
# pool is exhausted, that is when it has exceeded the maximum memory
# file_cache_size, beyond which it will not cache buffers but allocate on request.

# buffer_pool_use_heap_if_exhausted: true

# The strategy for optimizing disk read
# Possible values are:
# ssd (for solid state disks, the default)
# spinning (for spinning disks)
# disk_optimization_strategy: ssd

# Total permitted memory to use for memtables. Cassandra will stop
# accepting writes when the limit is exceeded until a flush completes,
# and will trigger a flush based on memtable_cleanup_threshold
# If omitted, Cassandra will set both to 1/4 the size of the heap.
# Min unit: MiB
# memtable_heap_space: 2048MiB
# Min unit: MiB
# memtable_offheap_space: 2048MiB

# memtable_cleanup_threshold is deprecated. The default calculation
# is the only reasonable choice. See the comments on  memtable_flush_writers
# for more information.
#
# Ratio of occupied non-flushing memtable size to total permitted size
# that will trigger a flush of the largest memtable. Larger mct will
# mean larger flushes and hence less compaction, but also less concurrent
# flush activity which can make it difficult to keep your disks fed
# under heavy write load.
#
# memtable_cleanup_threshold defaults to 1 / (memtable_flush_writers + 1)
# memtable_cleanup_threshold: 0.11

# Specify the way Cassandra allocates and manages memtable memory.
# Options are:
#
# heap_buffers
#   on heap nio buffers
#
# offheap_buffers
#   off heap (direct) nio buffers
#
# offheap_objects
#    off heap objects
memtable_allocation_type: heap_buffers

# Limit memory usage for Merkle tree calculations during repairs. The default
# is 1/16th of the available heap. The main tradeoff is that smaller trees
# have less resolution, which can lead to over-streaming data. If you see heap
# pressure during repairs, consider lowering this, but you cannot go below
# one mebibyte. If you see lots of over-streaming, consider raising
# this or using subrange repair.
#
# For more details see https://issues.apache.org/jira/browse/CASSANDRA-14096.
#
# Min unit: MiB
# repair_session_space:

# Total space to use for commit logs on disk.
#
# If space gets above this value, Cassandra will flush every dirty CF
# in the oldest segment and remove it.  So a small total commitlog space
# will tend to cause more flush activity on less-active columnfamilies.
#
# The default value is the smaller of 8192, and 1/4 of the total space
# of the commitlog volume.
#
# commitlog_total_space: 8192MiB

# This sets the number of memtable flush writer threads per disk
# as well as the total number of memtables that can be flushed concurrently.
# These are generally a combination of compute and IO bound.
#
# Memtable flushing is more CPU efficient than memtable ingest and a single thread
# can keep up with the ingest rate of a whole server on a single fast disk
# until it temporarily becomes IO bound under contention typically with compaction.
# At that point you need multiple flush threads. At some point in the future
# it may become CPU bound all the time.
#
# You can tell if flushing is falling behind using the MemtablePool.BlockedOnAllocation
# metric which should be 0, but will be non-zero if threads are blocked waiting on flushing
# to free memory.
#
# memtable_flush_writers defaults to two for a single data directory.
# This means that two  memtables can be flushed concurrently to the single data directory.
# If you have multiple data directories the default is one memtable flushing at a time
# but the flush will use a thread per data directory so you will get two or more writers.
#
# Two is generally enough to flush on a fast disk [array] mounted as a single data directory.
# Adding more flush writers will result in smaller more frequent flushes that introduce more
# compaction overhead.
#
# There is a direct tradeoff between number of memtables that can be flushed concurrently
# and flush size and frequency. More is not better you just need enough flush writers
# to never stall waiting for flushing to free memory.
#
# memtable_flush_writers: 2

# Total space to use for change-data-capture logs on disk.
#
# If space gets above this value, Cassandra will throw WriteTimeoutException
# on Mutations including tables with CDC enabled. A CDCCompactor is responsible
# for parsing the raw CDC logs and deleting them when parsing is completed.
#
# The default value is the min of 4096 MiB and 1/8th of the total space
# of the drive where cdc_raw_directory resides.
# Min unit: MiB
# cdc_total_space: 4096MiB

# When we hit our cdc_raw limit and the CDCCompactor is either running behind
# or experiencing backpressure, we check at the following interval to see if any
# new space for cdc-tracked tables has been made available. Default to 250ms
# Min unit: ms
# cdc_free_space_check_interval: 250ms

# A fixed memory pool size in MB for for SSTable index summaries. If left
# empty, this will default to 5% of the heap size. If the memory usage of
# all index summaries exceeds this limit, SSTables with low read rates will
# shrink their index summaries in order to meet this limit.  However, this
# is a best-effort process. In extreme conditions Cassandra may need to use
# more than this amount of memory.
# Min unit: KiB
index_summary_capacity:

# How frequently index summaries should be resampled.  This is done
# periodically to redistribute memory from the fixed-size pool to sstables
# proportional their recent read rates.  Setting to null value will disable this
# process, leaving existing index summaries at their current sampling level.
# Min unit: m
index_summary_resize_interval: 60m

# Whether to, when doing sequential writing, fsync() at intervals in
# order to force the operating system to flush the dirty
# buffers. Enable this to avoid sudden dirty buffer flushing from
# impacting read latencies. Almost always a good idea on SSDs; not
# necessarily on platters.
trickle_fsync: false
# Min unit: KiB
trickle_fsync_interval: 10240KiB

# TCP port, for commands and data
# For security reasons, you should not expose this port to the internet.  Firewall it if needed.
storage_port: 7000

# SSL port, for legacy encrypted communication. This property is unused unless enabled in
# server_encryption_options (see below). As of cassandra 4.0, this property is deprecated
# as a single port can be used for either/both secure and insecure connections.
# For security reasons, you should not expose this port to the internet. Firewall it if needed.
ssl_storage_port: 7001

# Address or interface to bind to and tell other Cassandra nodes to connect to.
# You _must_ change this if you want multiple nodes to be able to communicate!
#
# Set listen_address OR listen_interface, not both.
#
# Leaving it blank leaves it up to InetAddress.getLocalHost(). This
# will always do the Right Thing _if_ the node is properly configured
# (hostname, name resolution, etc), and the Right Thing is to use the
# address associated with the hostname (it might not be). If unresolvable
# it will fall back to InetAddress.getLoopbackAddress(), which is wrong for production systems.
#
# Setting listen_address to 0.0.0.0 is always wrong.
#
listen_address: localhost

# Set listen_address OR listen_interface, not both. Interfaces must correspond
# to a single address, IP aliasing is not supported.
# listen_interface: eth0

# If you choose to specify the interface by name and the interface has an ipv4 and an ipv6 address
# you can specify which should be chosen using listen_interface_prefer_ipv6. If false the first ipv4
# address will be used. If true the first ipv6 address will be used. Defaults to false preferring
# ipv4. If there is only one address it will be selected regardless of ipv4/ipv6.
# listen_interface_prefer_ipv6: false

# Address to broadcast to other Cassandra nodes
# Leaving this blank will set it to the same value as listen_address
#broadcast_address: 1.2.3.4

# When using multiple physical network interfaces, set this
# to true to listen on broadcast_address in addition to
# the listen_address, allowing nodes to communicate in both
# interfaces.
# Ignore this property if the network configuration automatically
# routes  between the public and private networks such as EC2.
# listen_on_broadcast_address: false

# Internode authentication backend, implementing IInternodeAuthenticator;
# used to allow/disallow connections from peer nodes.
# internode_authenticator: org.apache.cassandra.auth.AllowAllInternodeAuthenticator

# Whether to start the native transport server.
# The address on which the native transport is bound is defined by rpc_address.
start_native_transport: true
# port for the CQL native transport to listen for clients on
# For security reasons, you should not expose this port to the internet.  Firewall it if needed.
native_transport_port: 9042
# Enabling native transport encryption in client_encryption_options allows you to either use
# encryption for the standard port or to use a dedicated, additional port along with the unencrypted
# standard native_transport_port.
# Enabling client encryption and keeping native_transport_port_ssl disabled will use encryption
# for native_transport_port. Setting native_transport_port_ssl to a different value
# from native_transport_port will use encryption for native_transport_port_ssl while
# keeping native_transport_port unencrypted.
# native_transport_port_ssl: 9142
# The maximum threads for handling requests (note that idle threads are stopped
# after 30 seconds so there is not corresponding minimum setting).
# native_transport_max_threads: 128
#
# The maximum size of allowed frame. Frame (requests) larger than this will
# be rejected as invalid. The default is 16MiB. If you're changing this parameter,
# you may want to adjust max_value_size accordingly. This should be positive and less than 2048.
# Min unit: MiB
# native_transport_max_frame_size: 16MiB

# The maximum number of concurrent client connections.
# The default is -1, which means unlimited.
# native_transport_max_concurrent_connections: -1

# The maximum number of concurrent client connections per source ip.
# The default is -1, which means unlimited.
# native_transport_max_concurrent_connections_per_ip: -1

# Controls whether Cassandra honors older, yet currently supported, protocol versions.
# The default is true, which means all supported protocols will be honored.
native_transport_allow_older_protocols: true

# Controls when idle client connections are closed. Idle connections are ones that had neither reads
# nor writes for a time period.
#
# Clients may implement heartbeats by sending OPTIONS native protocol message after a timeout, which
# will reset idle timeout timer on the server side. To close idle client connections, corresponding
# values for heartbeat intervals have to be set on the client side.
#
# Idle connection timeouts are disabled by default.
# Min unit: ms
# native_transport_idle_timeout: 60000ms

# When enabled, limits the number of native transport requests dispatched for processing per second.
# Behavior once the limit has been breached depends on the value of THROW_ON_OVERLOAD specified in
# the STARTUP message sent by the client during connection establishment. (See section "4.1.1. STARTUP"
# in "CQL BINARY PROTOCOL v5".) With the THROW_ON_OVERLOAD flag enabled, messages that breach the limit
# are dropped, and an OverloadedException is thrown for the client to handle. When the flag is not
# enabled, the server will stop consuming messages from the channel/socket, putting backpressure on
# the client while already dispatched messages are processed.
# native_transport_rate_limiting_enabled: false
# native_transport_max_requests_per_second: 1000000

# The address or interface to bind the native transport server to.
#
# Set rpc_address OR rpc_interface, not both.
#
# Leaving rpc_address blank has the same effect as on listen_address
# (i.e. it will be based on the configured hostname of the node).
#
# Note that unlike listen_address, you can specify 0.0.0.0, but you must also
# set broadcast_rpc_address to a value other than 0.0.0.0.
#
# For security reasons, you should not expose this port to the internet.  Firewall it if needed.
# rpc_address: 0.0.0.0

# Set rpc_address OR rpc_interface, not both. Interfaces must correspond
# to a single address, IP aliasing is not supported.
rpc_interface: eth0

# If you choose to specify the interface by name and the interface has an ipv4 and an ipv6 address
# you can specify which should be chosen using rpc_interface_prefer_ipv6. If false the first ipv4
# address will be used. If true the first ipv6 address will be used. Defaults to false preferring
# ipv4. If there is only one address it will be selected regardless of ipv4/ipv6.
# rpc_interface_prefer_ipv6: false

# RPC address to broadcast to drivers and other Cassandra nodes. This cannot
# be set to 0.0.0.0. If left blank, this will be set to the value of
# rpc_address. If rpc_address is set to 0.0.0.0, broadcast_rpc_address must
# be set.
#broadcast_rpc_address: 0.0.0.0

# enable or disable keepalive on rpc/native connections
rpc_keepalive: true

# Uncomment to set socket buffer size for internode communication
# Note that when setting this, the buffer size is limited by net.core.wmem_max
# and when not setting it it is defined by net.ipv4.tcp_wmem
# See also:
# /proc/sys/net/core/wmem_max
# /proc/sys/net/core/rmem_max
# /proc/sys/net/ipv4/tcp_wmem
# /proc/sys/net/ipv4/tcp_wmem
# and 'man tcp'
# Min unit: B
# internode_socket_send_buffer_size:

# Uncomment to set socket buffer size for internode communication
# Note that when setting this, the buffer size is limited by net.core.wmem_max
# and when not setting it it is defined by net.ipv4.tcp_wmem
# Min unit: B
# internode_socket_receive_buffer_size:

# Set to true to have Cassandra create a hard link to each sstable
# flushed or streamed locally in a backups/ subdirectory of the
# keyspace data.  Removing these links is the operator's
# responsibility.
incremental_backups: false

# Whether or not to take a snapshot before each compaction.  Be
# careful using this option, since Cassandra won't clean up the
# snapshots for you.  Mostly useful if you're paranoid when there
# is a data format change.
snapshot_before_compaction: false

# Whether or not a snapshot is taken of the data before keyspace truncation
# or dropping of column families. The STRONGLY advised default of true 
# should be used to provide data safety. If you set this flag to false, you will
# lose data on truncation or drop.
auto_snapshot: true

# Adds a time-to-live (TTL) to auto snapshots generated by table
# truncation or drop (when enabled).
# After the TTL is elapsed, the snapshot is automatically cleared.
# By default, auto snapshots *do not* have TTL, uncomment the property below
# to enable TTL on auto snapshots.
# Accepted units: d (days), h (hours) or m (minutes)
# auto_snapshot_ttl: 30d

# The act of creating or clearing a snapshot involves creating or removing
# potentially tens of thousands of links, which can cause significant performance
# impact, especially on consumer grade SSDs. A non-zero value here can
# be used to throttle these links to avoid negative performance impact of
# taking and clearing snapshots
snapshot_links_per_second: 0

# Granularity of the collation index of rows within a partition.
# Increase if your rows are large, or if you have a very large
# number of rows per partition.  The competing goals are these:
#
# - a smaller granularity means more index entries are generated
#   and looking up rows withing the partition by collation column
#   is faster
# - but, Cassandra will keep the collation index in memory for hot
#   rows (as part of the key cache), so a larger granularity means
#   you can cache more hot rows
# Min unit: KiB
column_index_size: 64KiB

# Per sstable indexed key cache entries (the collation index in memory
# mentioned above) exceeding this size will not be held on heap.
# This means that only partition information is held on heap and the
# index entries are read from disk.
#
# Note that this size refers to the size of the
# serialized index information and not the size of the partition.
# Min unit: KiB
column_index_cache_size: 2KiB

# Number of simultaneous compactions to allow, NOT including
# validation "compactions" for anti-entropy repair.  Simultaneous
# compactions can help preserve read performance in a mixed read/write
# workload, by mitigating the tendency of small sstables to accumulate
# during a single long running compactions. The default is usually
# fine and if you experience problems with compaction running too
# slowly or too fast, you should look at
# compaction_throughput first.
#
# concurrent_compactors defaults to the smaller of (number of disks,
# number of cores), with a minimum of 2 and a maximum of 8.
# 
# If your data directories are backed by SSD, you should increase this
# to the number of cores.
# concurrent_compactors: 1

# Number of simultaneous repair validations to allow. If not set or set to
# a value less than 1, it defaults to the value of concurrent_compactors.
# To set a value greeater than concurrent_compactors at startup, the system
# property cassandra.allow_unlimited_concurrent_validations must be set to
# true. To dynamically resize to a value > concurrent_compactors on a running
# node, first call the bypassConcurrentValidatorsLimit method on the
# org.apache.cassandra.db:type=StorageService mbean
# concurrent_validations: 0

# Number of simultaneous materialized view builder tasks to allow.
concurrent_materialized_view_builders: 1

# Throttles compaction to the given total throughput across the entire
# system. The faster you insert data, the faster you need to compact in
# order to keep the sstable count down, but in general, setting this to
# 16 to 32 times the rate you are inserting data is more than sufficient.
# Setting this to 0 disables throttling. Note that this accounts for all types
# of compaction, including validation compaction (building Merkle trees
# for repairs).
compaction_throughput: 64MiB/s

# When compacting, the replacement sstable(s) can be opened before they
# are completely written, and used in place of the prior sstables for
# any range that has been written. This helps to smoothly transfer reads 
# between the sstables, reducing page cache churn and keeping hot rows hot
# Set sstable_preemptive_open_interval to null for disabled which is equivalent to
# sstable_preemptive_open_interval_in_mb being negative
# Min unit: MiB
sstable_preemptive_open_interval: 50MiB

# Starting from 4.1 sstables support UUID based generation identifiers. They are disabled by default
# because once enabled, there is no easy way to downgrade. When the node is restarted with this option
# set to true, each newly created sstable will have a UUID based generation identifier and such files are
# not readable by previous Cassandra versions. At some point, this option will become true by default
# and eventually get removed from the configuration.
uuid_sstable_identifiers_enabled: false

# When enabled, permits Cassandra to zero-copy stream entire eligible
# SSTables between nodes, including every component.
# This speeds up the network transfer significantly subject to
# throttling specified by entire_sstable_stream_throughput_outbound,
# and entire_sstable_inter_dc_stream_throughput_outbound
# for inter-DC transfers.
# Enabling this will reduce the GC pressure on sending and receiving node.
# When unset, the default is enabled. While this feature tries to keep the
# disks balanced, it cannot guarantee it. This feature will be automatically
# disabled if internode encryption is enabled.
# stream_entire_sstables: true

# Throttles entire SSTable outbound streaming file transfers on
# this node to the given total throughput in Mbps.
# Setting this value to 0 it disables throttling.
# When unset, the default is 200 Mbps or 24 MiB/s.
# entire_sstable_stream_throughput_outbound: 24MiB/s

# Throttles entire SSTable file streaming between datacenters.
# Setting this value to 0 disables throttling for entire SSTable inter-DC file streaming.
# When unset, the default is 200 Mbps or 24 MiB/s.
# entire_sstable_inter_dc_stream_throughput_outbound: 24MiB/s

# Throttles all outbound streaming file transfers on this node to the
# given total throughput in Mbps. This is necessary because Cassandra does
# mostly sequential IO when streaming data during bootstrap or repair, which
# can lead to saturating the network connection and degrading rpc performance.
# When unset, the default is 200 Mbps or 24 MiB/s.
# stream_throughput_outbound: 24MiB/s

# Throttles all streaming file transfer between the datacenters,
# this setting allows users to throttle inter dc stream throughput in addition
# to throttling all network stream traffic as configured with
# stream_throughput_outbound_megabits_per_sec
# When unset, the default is 200 Mbps or 24 MiB/s.
# inter_dc_stream_throughput_outbound: 24MiB/s

# Server side timeouts for requests. The server will return a timeout exception
# to the client if it can't complete an operation within the corresponding
# timeout. Those settings are a protection against:
#   1) having client wait on an operation that might never terminate due to some
#      failures.
#   2) operations that use too much CPU/read too much data (leading to memory build
#      up) by putting a limit to how long an operation will execute.
# For this reason, you should avoid putting these settings too high. In other words,
# if you are timing out requests because of underlying resource constraints then
# increasing the timeout will just cause more problems. Of course putting them too
# low is equally ill-advised since clients could get timeouts even for successful
# operations just because the timeout setting is too tight.

# How long the coordinator should wait for read operations to complete.
# Lowest acceptable value is 10 ms.
# Min unit: ms
read_request_timeout: 5000ms
# How long the coordinator should wait for seq or index scans to complete.
# Lowest acceptable value is 10 ms.
# Min unit: ms
range_request_timeout: 10000ms
# How long the coordinator should wait for writes to complete.
# Lowest acceptable value is 10 ms.
# Min unit: ms
write_request_timeout: 2000ms
# How long the coordinator should wait for counter writes to complete.
# Lowest acceptable value is 10 ms.
# Min unit: ms
counter_write_request_timeout: 5000ms
# How long a coordinator should continue to retry a CAS operation
# that contends with other proposals for the same row.
# Lowest acceptable value is 10 ms.
# Min unit: ms
cas_contention_timeout: 1000ms
# How long the coordinator should wait for truncates to complete
# (This can be much longer, because unless auto_snapshot is disabled
# we need to flush first so we can snapshot before removing the data.)
# Lowest acceptable value is 10 ms.
# Min unit: ms
truncate_request_timeout: 60000ms
# The default timeout for other, miscellaneous operations.
# Lowest acceptable value is 10 ms.
# Min unit: ms
request_timeout: 10000ms

# Defensive settings for protecting Cassandra from true network partitions.
# See (CASSANDRA-14358) for details.
#
# The amount of time to wait for internode tcp connections to establish.
# Min unit: ms
# internode_tcp_connect_timeout: 2000ms
#
# The amount of time unacknowledged data is allowed on a connection before we throw out the connection
# Note this is only supported on Linux + epoll, and it appears to behave oddly above a setting of 30000
# (it takes much longer than 30s) as of Linux 4.12. If you want something that high set this to 0
# which picks up the OS default and configure the net.ipv4.tcp_retries2 sysctl to be ~8.
# Min unit: ms
# internode_tcp_user_timeout: 30000ms

# The amount of time unacknowledged data is allowed on a streaming connection.
# The default is 5 minutes. Increase it or set it to 0 in order to increase the timeout.
# Min unit: ms
# internode_streaming_tcp_user_timeout: 300000ms

# Global, per-endpoint and per-connection limits imposed on messages queued for delivery to other nodes
# and waiting to be processed on arrival from other nodes in the cluster.  These limits are applied to the on-wire
# size of the message being sent or received.
#
# The basic per-link limit is consumed in isolation before any endpoint or global limit is imposed.
# Each node-pair has three links: urgent, small and large.  So any given node may have a maximum of
# N*3*(internode_application_send_queue_capacity+internode_application_receive_queue_capacity)
# messages queued without any coordination between them although in practice, with token-aware routing, only RF*tokens
# nodes should need to communicate with significant bandwidth.
#
# The per-endpoint limit is imposed on all messages exceeding the per-link limit, simultaneously with the global limit,
# on all links to or from a single node in the cluster.
# The global limit is imposed on all messages exceeding the per-link limit, simultaneously with the per-endpoint limit,
# on all links to or from any node in the cluster.
#
# Min unit: B
# internode_application_send_queue_capacity: 4MiB
# internode_application_send_queue_reserve_endpoint_capacity: 128MiB
# internode_application_send_queue_reserve_global_capacity: 512MiB
# internode_application_receive_queue_capacity: 4MiB
# internode_application_receive_queue_reserve_endpoint_capacity: 128MiB
# internode_application_receive_queue_reserve_global_capacity: 512MiB


# How long before a node logs slow queries. Select queries that take longer than
# this timeout to execute, will generate an aggregated log message, so that slow queries
# can be identified. Set this value to zero to disable slow query logging.
# Min unit: ms
slow_query_log_timeout: 500ms

# Enable operation timeout information exchange between nodes to accurately
# measure request timeouts.  If disabled, replicas will assume that requests
# were forwarded to them instantly by the coordinator, which means that
# under overload conditions we will waste that much extra time processing 
# already-timed-out requests.
#
# Warning: It is generally assumed that users have setup NTP on their clusters, and that clocks are modestly in sync, 
# since this is a requirement for general correctness of last write wins.
# internode_timeout: true

# Set period for idle state control messages for earlier detection of failed streams
# This node will send a keep-alive message periodically on the streaming's control channel.
# This ensures that any eventual SocketTimeoutException will occur within 2 keep-alive cycles
# If the node cannot send, or timeouts sending, the keep-alive message on the netty control channel
# the stream session is closed.
# Default value is 300s (5 minutes), which means stalled streams
# are detected within 10 minutes
# Specify 0 to disable.
# Min unit: s
# streaming_keep_alive_period: 300s

# Limit number of connections per host for streaming
# Increase this when you notice that joins are CPU-bound rather that network
# bound (for example a few nodes with big files).
# streaming_connections_per_host: 1

# Settings for stream stats tracking; used by system_views.streaming table
# How long before a stream is evicted from tracking; this impacts both historic and currently running
# streams.
# streaming_state_expires: 3d
# How much memory may be used for tracking before evicting session from tracking; once crossed
# historic and currently running streams maybe impacted.
# streaming_state_size: 40MiB
# Enable/Disable tracking of streaming stats
# streaming_stats_enabled: true

# Allows denying configurable access (rw/rr) to operations on configured ks, table, and partitions, intended for use by
# operators to manage cluster health vs application access. See CASSANDRA-12106 and CEP-13 for more details.
# partition_denylist_enabled: false

# denylist_writes_enabled: true
# denylist_reads_enabled: true
# denylist_range_reads_enabled: true

# The interval at which keys in the cache for denylisting will "expire" and async refresh from the backing DB.
# Note: this serves only as a fail-safe, as the usage pattern is expected to be "mutate state, refresh cache" on any
# changes to the underlying denylist entries. See documentation for details.
# Min unit: s
# denylist_refresh: 600s

# In the event of errors on attempting to load the denylist cache, retry on this interval.
# Min unit: s
# denylist_initial_load_retry: 5s

# We cap the number of denylisted keys allowed per table to keep things from growing unbounded. Nodes will warn above
# this limit while allowing new denylisted keys to be inserted. Denied keys are loaded in natural query / clustering
# ordering by partition key in case of overflow.
# denylist_max_keys_per_table: 1000

# We cap the total number of denylisted keys allowed in the cluster to keep things from growing unbounded.
# Nodes will warn on initial cache load that there are too many keys and be direct the operator to trim down excess
# entries to within the configured limits.
# denylist_max_keys_total: 10000

# Since the denylist in many ways serves to protect the health of the cluster from partitions operators have identified
# as being in a bad state, we usually want more robustness than just CL.ONE on operations to/from these tables to
# ensure that these safeguards are in place. That said, we allow users to configure this if they're so inclined.
# denylist_consistency_level: QUORUM

# phi value that must be reached for a host to be marked down.
# most users should never need to adjust this.
# phi_convict_threshold: 8

# endpoint_snitch -- Set this to a class that implements
# IEndpointSnitch.  The snitch has two functions:
#
# - it teaches Cassandra enough about your network topology to route
#   requests efficiently
# - it allows Cassandra to spread replicas around your cluster to avoid
#   correlated failures. It does this by grouping machines into
#   "datacenters" and "racks."  Cassandra will do its best not to have
#   more than one replica on the same "rack" (which may not actually
#   be a physical location)
#
# CASSANDRA WILL NOT ALLOW YOU TO SWITCH TO AN INCOMPATIBLE SNITCH
# ONCE DATA IS INSERTED INTO THE CLUSTER.  This would cause data loss.
# This means that if you start with the default SimpleSnitch, which
# locates every node on "rack1" in "datacenter1", your only options
# if you need to add another datacenter are GossipingPropertyFileSnitch
# (and the older PFS).  From there, if you want to migrate to an
# incompatible snitch like Ec2Snitch you can do it by adding new nodes
# under Ec2Snitch (which will locate them in a new "datacenter") and
# decommissioning the old ones.
#
# Out of the box, Cassandra provides:
#
# SimpleSnitch:
#    Treats Strategy order as proximity. This can improve cache
#    locality when disabling read repair.  Only appropriate for
#    single-datacenter deployments.
#
# GossipingPropertyFileSnitch
#    This should be your go-to snitch for production use.  The rack
#    and datacenter for the local node are defined in
#    cassandra-rackdc.properties and propagated to other nodes via
#    gossip.  If cassandra-topology.properties exists, it is used as a
#    fallback, allowing migration from the PropertyFileSnitch.
#
# PropertyFileSnitch:
#    Proximity is determined by rack and data center, which are
#    explicitly configured in cassandra-topology.properties.
#
# Ec2Snitch:
#    Appropriate for EC2 deployments in a single Region. Loads Region
#    and Availability Zone information from the EC2 API. The Region is
#    treated as the datacenter, and the Availability Zone as the rack.
#    Only private IPs are used, so this will not work across multiple
#    Regions.
#
# Ec2MultiRegionSnitch:
#    Uses public IPs as broadcast_address to allow cross-region
#    connectivity.  (Thus, you should set seed addresses to the public
#    IP as well.) You will need to open the storage_port or
#    ssl_storage_port on the public IP firewall.  (For intra-Region
#    traffic, Cassandra will switch to the private IP after
#    establishing a connection.)
#
# RackInferringSnitch:
#    Proximity is determined by rack and data center, which are
#    assumed to correspond to the 3rd and 2nd octet of each node's IP
#    address, respectively.  Unless this happens to match your
#    deployment conventions, this is best used as an example of
#    writing a custom Snitch class and is provided in that spirit.
#
# You can use a custom Snitch by setting this to the full class name
# of the snitch, which will be assumed to be on your classpath.
endpoint_snitch: SimpleSnitch

# controls how often to perform the more expensive part of host score
# calculation
# Min unit: ms
dynamic_snitch_update_interval: 100ms
# controls how often to reset all host scores, allowing a bad host to
# possibly recover
# Min unit: ms
dynamic_snitch_reset_interval: 600000ms
# if set greater than zero, this will allow
# 'pinning' of replicas to hosts in order to increase cache capacity.
# The badness threshold will control how much worse the pinned host has to be
# before the dynamic snitch will prefer other replicas over it.  This is
# expressed as a double which represents a percentage.  Thus, a value of
# 0.2 means Cassandra would continue to prefer the static snitch values
# until the pinned host was 20% worse than the fastest.
dynamic_snitch_badness_threshold: 1.0

# Configure server-to-server internode encryption
#
# JVM and netty defaults for supported SSL socket protocols and cipher suites can
# be replaced using custom encryption options. This is not recommended
# unless you have policies in place that dictate certain settings, or
# need to disable vulnerable ciphers or protocols in case the JVM cannot
# be updated.
#
# FIPS compliant settings can be configured at JVM level and should not
# involve changing encryption settings here:
# https://docs.oracle.com/javase/8/docs/technotes/guides/security/jsse/FIPS.html
#
# **NOTE** this default configuration is an insecure configuration. If you need to
# enable server-to-server encryption generate server keystores (and truststores for mutual
# authentication) per:
# http://download.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html#CreateKeystore
# Then perform the following configuration changes:
#
# Step 1: Set internode_encryption=<dc|rack|all> and explicitly set optional=true. Restart all nodes
#
# Step 2: Set optional=false (or remove it) and if you generated truststores and want to use mutual
# auth set require_client_auth=true. Restart all nodes
server_encryption_options:
  # On outbound connections, determine which type of peers to securely connect to.
  #   The available options are :
  #     none : Do not encrypt outgoing connections
  #     dc   : Encrypt connections to peers in other datacenters but not within datacenters
  #     rack : Encrypt connections to peers in other racks but not within racks
  #     all  : Always use encrypted connections
  internode_encryption: none
  # When set to true, encrypted and unencrypted connections are allowed on the storage_port
  # This should _only be true_ while in unencrypted or transitional operation
  # optional defaults to true if internode_encryption is none
  # optional: true
  # If enabled, will open up an encrypted listening socket on ssl_storage_port. Should only be used
  # during upgrade to 4.0; otherwise, set to false.
  legacy_ssl_storage_port_enabled: false
  # Set to a valid keystore if internode_encryption is dc, rack or all
  keystore: conf/.keystore
  keystore_password: cassandra
  # Configure the way Cassandra creates SSL contexts.
  # To use PEM-based key material, see org.apache.cassandra.security.PEMBasedSslContextFactory
  # ssl_context_factory:
  #     # Must be an instance of org.apache.cassandra.security.ISslContextFactory
  #     class_name: org.apache.cassandra.security.DefaultSslContextFactory
  # Verify peer server certificates
  require_client_auth: false
  # Set to a valid trustore if require_client_auth is true
  truststore: conf/.truststore
  truststore_password: cassandra
  # Verify that the host name in the certificate matches the connected host
  require_endpoint_verification: false
  # More advanced defaults:
  # protocol: TLS
  # store_type: JKS
  # cipher_suites: [
  #   TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
  #   TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256, TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
  #   TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA, TLS_RSA_WITH_AES_128_GCM_SHA256, TLS_RSA_WITH_AES_128_CBC_SHA,
  #   TLS_RSA_WITH_AES_256_CBC_SHA
  # ]

# Configure client-to-server encryption.
#
# **NOTE** this default configuration is an insecure configuration. If you need to
# enable client-to-server encryption generate server keystores (and truststores for mutual
# authentication) per:
# http://download.oracle.com/javase/8/docs/technotes/guides/security/jsse/JSSERefGuide.html#CreateKeystore
# Then perform the following configuration changes:
#
# Step 1: Set enabled=true and explicitly set optional=true. Restart all nodes
#
# Step 2: Set optional=false (or remove it) and if you generated truststores and want to use mutual
# auth set require_client_auth=true. Restart all nodes
client_encryption_options:
  # Enable client-to-server encryption
  enabled: false
  # When set to true, encrypted and unencrypted connections are allowed on the native_transport_port
  # This should _only be true_ while in unencrypted or transitional operation
  # optional defaults to true when enabled is false, and false when enabled is true.
  # optional: true
  # Set keystore and keystore_password to valid keystores if enabled is true
  keystore: conf/.keystore
  keystore_password: cassandra
  # Configure the way Cassandra creates SSL contexts.
  # To use PEM-based key material, see org.apache.cassandra.security.PEMBasedSslContextFactory
  # ssl_context_factory:
  #     # Must be an instance of org.apache.cassandra.security.ISslContextFactory
  #     class_name: org.apache.cassandra.security.DefaultSslContextFactory
  # Verify client certificates
  require_client_auth: false
  # Set trustore and truststore_password if require_client_auth is true
  # truststore: conf/.truststore
  # truststore_password: cassandra
  # More advanced defaults:
  # protocol: TLS
  # store_type: JKS
  # cipher_suites: [
  #   TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
  #   TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256, TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
  #   TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA, TLS_RSA_WITH_AES_128_GCM_SHA256, TLS_RSA_WITH_AES_128_CBC_SHA,
  #   TLS_RSA_WITH_AES_256_CBC_SHA
  # ]

# internode_compression controls whether traffic between nodes is
# compressed.
# Can be:
#
# all
#   all traffic is compressed
#
# dc
#   traffic between different datacenters is compressed
#
# none
#   nothing is compressed.
internode_compression: dc

# Enable or disable tcp_nodelay for inter-dc communication.
# Disabling it will result in larger (but fewer) network packets being sent,
# reducing overhead from the TCP protocol itself, at the cost of increasing
# latency if you block for cross-datacenter responses.
inter_dc_tcp_nodelay: false

# TTL for different trace types used during logging of the repair process.
# Min unit: s
trace_type_query_ttl: 1d
# Min unit: s
trace_type_repair_ttl: 7d

# If unset, all GC Pauses greater than gc_log_threshold will log at
# INFO level
# UDFs (user defined functions) are disabled by default.
# As of Cassandra 3.0 there is a sandbox in place that should prevent execution of evil code.
user_defined_functions_enabled: false

# Enables scripted UDFs (JavaScript UDFs).
# Java UDFs are always enabled, if user_defined_functions_enabled is true.
# Enable this option to be able to use UDFs with "language javascript" or any custom JSR-223 provider.
# This option has no effect, if user_defined_functions_enabled is false.
scripted_user_defined_functions_enabled: false

# Enables encrypting data at-rest (on disk). Different key providers can be plugged in, but the default reads from
# a JCE-style keystore. A single keystore can hold multiple keys, but the one referenced by
# the "key_alias" is the only key that will be used for encrypt opertaions; previously used keys
# can still (and should!) be in the keystore and will be used on decrypt operations
# (to handle the case of key rotation).
#
# It is strongly recommended to download and install Java Cryptography Extension (JCE)
# Unlimited Strength Jurisdiction Policy Files for your version of the JDK.
# (current link: http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html)
#
# Currently, only the following file types are supported for transparent data encryption, although
# more are coming in future cassandra releases: commitlog, hints
transparent_data_encryption_options:
  enabled: false
  chunk_length_kb: 64
  cipher: AES/CBC/PKCS5Padding
  key_alias: testing:1
  # CBC IV length for AES needs to be 16 bytes (which is also the default size)
  # iv_length: 16
  key_provider:
    - class_name: org.apache.cassandra.security.JKSKeyProvider
      parameters:
        - keystore: conf/.keystore
          keystore_password: cassandra
          store_type: JCEKS
          key_password: cassandra


#####################
# SAFETY THRESHOLDS #
#####################

# When executing a scan, within or across a partition, we need to keep the
# tombstones seen in memory so we can return them to the coordinator, which
# will use them to make sure other replicas also know about the deleted rows.
# With workloads that generate a lot of tombstones, this can cause performance
# problems and even exaust the server heap.
# (http://www.datastax.com/dev/blog/cassandra-anti-patterns-queues-and-queue-like-datasets)
# Adjust the thresholds here if you understand the dangers and want to
# scan more tombstones anyway.  These thresholds may also be adjusted at runtime
# using the StorageService mbean.
tombstone_warn_threshold: 1000
tombstone_failure_threshold: 100000

# Filtering and secondary index queries at read consistency levels above ONE/LOCAL_ONE use a
# mechanism called replica filtering protection to ensure that results from stale replicas do
# not violate consistency. (See CASSANDRA-8272 and CASSANDRA-15907 for more details.) This
# mechanism materializes replica results by partition on-heap at the coordinator. The more possibly
# stale results returned by the replicas, the more rows materialized during the query.
replica_filtering_protection:
    # These thresholds exist to limit the damage severely out-of-date replicas can cause during these
    # queries. They limit the number of rows from all replicas individual index and filtering queries
    # can materialize on-heap to return correct results at the desired read consistency level.
    #
    # "cached_replica_rows_warn_threshold" is the per-query threshold at which a warning will be logged.
    # "cached_replica_rows_fail_threshold" is the per-query threshold at which the query will fail.
    #
    # These thresholds may also be adjusted at runtime using the StorageService mbean.
    #
    # If the failure threshold is breached, it is likely that either the current page/fetch size
    # is too large or one or more replicas is severely out-of-sync and in need of repair.
    cached_rows_warn_threshold: 2000
    cached_rows_fail_threshold: 32000

# Log WARN on any multiple-partition batch size exceeding this value. 5KiB per batch by default.
# Caution should be taken on increasing the size of this threshold as it can lead to node instability.
# Min unit: KiB
batch_size_warn_threshold: 5KiB

# Fail any multiple-partition batch exceeding this value. 50KiB (10x warn threshold) by default.
# Min unit: KiB
batch_size_fail_threshold: 50KiB

# Log WARN on any batches not of type LOGGED than span across more partitions than this limit
unlogged_batch_across_partitions_warn_threshold: 10

# Log a warning when compacting partitions larger than this value
compaction_large_partition_warning_threshold: 100MiB

# Log a warning when writing more tombstones than this value to a partition
compaction_tombstone_warning_threshold: 100000

# GC Pauses greater than 200 ms will be logged at INFO level
# This threshold can be adjusted to minimize logging if necessary
# Min unit: ms
# gc_log_threshold: 200ms

# GC Pauses greater than gc_warn_threshold will be logged at WARN level
# Adjust the threshold based on your application throughput requirement. Setting to 0
# will deactivate the feature.
# Min unit: ms
# gc_warn_threshold: 1000ms

# Maximum size of any value in SSTables. Safety measure to detect SSTable corruption
# early. Any value size larger than this threshold will result into marking an SSTable
# as corrupted. This should be positive and less than 2GiB.
# Min unit: MiB
# max_value_size: 256MiB

# ** Impact on keyspace creation **
# If replication factor is not mentioned as part of keyspace creation, default_keyspace_rf would apply.
# Changing this configuration would only take effect for keyspaces created after the change, but does not impact
# existing keyspaces created prior to the change.
# ** Impact on keyspace alter **
# When altering a keyspace from NetworkTopologyStrategy to SimpleStrategy, default_keyspace_rf is applied if rf is not
# explicitly mentioned.
# ** Impact on system keyspaces **
# This would also apply for any system keyspaces that need replication factor.
# A further note about system keyspaces - system_traces and system_distributed keyspaces take RF of 2 or default,
# whichever is higher, and system_auth keyspace takes RF of 1 or default, whichever is higher.
# Suggested value for use in production: 3
# default_keyspace_rf: 1

# Track a metric per keyspace indicating whether replication achieved the ideal consistency
# level for writes without timing out. This is different from the consistency level requested by
# each write which may be lower in order to facilitate availability.
# ideal_consistency_level: EACH_QUORUM

# Automatically upgrade sstables after upgrade - if there is no ordinary compaction to do, the
# oldest non-upgraded sstable will get upgraded to the latest version
# automatic_sstable_upgrade: false
# Limit the number of concurrent sstable upgrades
# max_concurrent_automatic_sstable_upgrades: 1

# Audit logging - Logs every incoming CQL command request, authentication to a node. See the docs
# on audit_logging for full details about the various configuration options.
audit_logging_options:
  enabled: false
  logger:
    - class_name: BinAuditLogger
  # audit_logs_dir:
  # included_keyspaces:
  # excluded_keyspaces: system, system_schema, system_virtual_schema
  # included_categories:
  # excluded_categories:
  # included_users:
  # excluded_users:
  # roll_cycle: HOURLY
  # block: true
  # max_queue_weight: 268435456 # 256 MiB
  # max_log_size: 17179869184 # 16 GiB
  ## archive command is "/path/to/script.sh %path" where %path is replaced with the file being rolled:
  # archive_command:
  # max_archive_retries: 10


# default options for full query logging - these can be overridden from command line when executing
# nodetool enablefullquerylog
# full_query_logging_options:
  # log_dir:
  # roll_cycle: HOURLY
  # block: true
  # max_queue_weight: 268435456 # 256 MiB
  # max_log_size: 17179869184 # 16 GiB
  ## archive command is "/path/to/script.sh %path" where %path is replaced with the file being rolled:
  # archive_command:
  ## note that enabling this allows anyone with JMX/nodetool access to run local shell commands as the user running cassandra
  # allow_nodetool_archive_command: false
  # max_archive_retries: 10

# validate tombstones on reads and compaction
# can be either "disabled", "warn" or "exception"
# corrupted_tombstone_strategy: disabled

# Diagnostic Events #
# If enabled, diagnostic events can be helpful for troubleshooting operational issues. Emitted events contain details
# on internal state and temporal relationships across events, accessible by clients via JMX.
diagnostic_events_enabled: false

# Use native transport TCP message coalescing. If on upgrade to 4.0 you found your throughput decreasing, and in
# particular you run an old kernel or have very fewer client connections, this option might be worth evaluating.
#native_transport_flush_in_batches_legacy: false

# Enable tracking of repaired state of data during reads and comparison between replicas
# Mismatches between the repaired sets of replicas can be characterized as either confirmed
# or unconfirmed. In this context, unconfirmed indicates that the presence of pending repair
# sessions, unrepaired partition tombstones, or some other condition means that the disparity
# cannot be considered conclusive. Confirmed mismatches should be a trigger for investigation
# as they may be indicative of corruption or data loss.
# There are separate flags for range vs partition reads as single partition reads are only tracked
# when CL > 1 and a digest mismatch occurs. Currently, range queries don't use digests so if
# enabled for range reads, all range reads will include repaired data tracking. As this adds
# some overhead, operators may wish to disable it whilst still enabling it for partition reads
repaired_data_tracking_for_range_reads_enabled: false
repaired_data_tracking_for_partition_reads_enabled: false
# If false, only confirmed mismatches will be reported. If true, a separate metric for unconfirmed
# mismatches will also be recorded. This is to avoid potential signal:noise issues are unconfirmed
# mismatches are less actionable than confirmed ones.
report_unconfirmed_repaired_data_mismatches: false

# Having many tables and/or keyspaces negatively affects performance of many operations in the
# cluster. When the number of tables/keyspaces in the cluster exceeds the following thresholds
# a client warning will be sent back to the user when creating a table or keyspace.
# As of cassandra 4.1, these properties are deprecated in favor of keyspaces_warn_threshold and tables_warn_threshold
# table_count_warn_threshold: 150
# keyspace_count_warn_threshold: 40

# configure the read and write consistency levels for modifications to auth tables
# auth_read_consistency_level: LOCAL_QUORUM
# auth_write_consistency_level: EACH_QUORUM

# Delays on auth resolution can lead to a thundering herd problem on reconnects; this option will enable
# warming of auth caches prior to node completing startup. See CASSANDRA-16958
# auth_cache_warming_enabled: false

#########################
# EXPERIMENTAL FEATURES #
#########################

# Enables materialized view creation on this node.
# Materialized views are considered experimental and are not recommended for production use.
materialized_views_enabled: false

# Enables SASI index creation on this node.
# SASI indexes are considered experimental and are not recommended for production use.
sasi_indexes_enabled: false

# Enables creation of transiently replicated keyspaces on this node.
# Transient replication is experimental and is not recommended for production use.
transient_replication_enabled: false

# Enables the used of 'ALTER ... DROP COMPACT STORAGE' statements on this node.
# 'ALTER ... DROP COMPACT STORAGE' is considered experimental and is not recommended for production use.
drop_compact_storage_enabled: false

# Whether or not USE <keyspace> is allowed. This is enabled by default to avoid failure on upgrade.
#use_statements_enabled: true

# When the client triggers a protocol exception or unknown issue (Cassandra bug) we increment
# a client metric showing this; this logic will exclude specific subnets from updating these
# metrics
#client_error_reporting_exclusions:
#  subnets:
#    - 127.0.0.1
#    - 127.0.0.0/31

# Enables read thresholds (warn/fail) across all replicas for reporting back to the client.
# See: CASSANDRA-16850
# read_thresholds_enabled: false # scheduled to be set true in 4.2
# When read_thresholds_enabled: true, this tracks the materialized size of a query on the
# coordinator. If coordinator_read_size_warn_threshold is defined, this will emit a warning
# to clients with details on what query triggered this as well as the size of the result set; if
# coordinator_read_size_fail_threshold is defined, this will fail the query after it
# has exceeded this threshold, returning a read error to the user.
# coordinator_read_size_warn_threshold:
# coordinator_read_size_fail_threshold:
# When read_thresholds_enabled: true, this tracks the size of the local read (as defined by
# heap size), and will warn/fail based off these thresholds; undefined disables these checks.
# local_read_size_warn_threshold:
# local_read_size_fail_threshold:
# When read_thresholds_enabled: true, this tracks the expected memory size of the RowIndexEntry
# and will warn/fail based off these thresholds; undefined disables these checks
# row_index_read_size_warn_threshold:
# row_index_read_size_fail_threshold:

# Guardrail to warn or fail when creating more user keyspaces than threshold.
# The two thresholds default to -1 to disable.
# keyspaces_warn_threshold: -1
# keyspaces_fail_threshold: -1
# Guardrail to warn or fail when creating more user tables than threshold.
# The two thresholds default to -1 to disable.
# tables_warn_threshold: -1
# tables_fail_threshold: -1
# Guardrail to enable or disable the ability to create uncompressed tables
# uncompressed_tables_enabled: true
# Guardrail to warn or fail when creating/altering a table with more columns per table than threshold.
# The two thresholds default to -1 to disable.
# columns_per_table_warn_threshold: -1
# columns_per_table_fail_threshold: -1
# Guardrail to warn or fail when creating more secondary indexes per table than threshold.
# The two thresholds default to -1 to disable.
# secondary_indexes_per_table_warn_threshold: -1
# secondary_indexes_per_table_fail_threshold: -1
# Guardrail to enable or disable the creation of secondary indexes
# secondary_indexes_enabled: true
# Guardrail to warn or fail when creating more materialized views per table than threshold.
# The two thresholds default to -1 to disable.
# materialized_views_per_table_warn_threshold: -1
# materialized_views_per_table_fail_threshold: -1
# Guardrail to warn about, ignore or reject properties when creating tables. By default all properties are allowed.
# table_properties_warned: []
# table_properties_ignored: []
# table_properties_disallowed: []
# Guardrail to allow/disallow user-provided timestamps. Defaults to true.
# user_timestamps_enabled: true
# Guardrail to allow/disallow GROUP BY functionality.
# group_by_enabled: true
# Guardrail to allow/disallow TRUNCATE and DROP TABLE statements
# drop_truncate_table_enabled: true
# Guardrail to warn or fail when using a page size greater than threshold.
# The two thresholds default to -1 to disable.
# page_size_warn_threshold: -1
# page_size_fail_threshold: -1
# Guardrail to allow/disallow list operations that require read before write, i.e. setting list element by index and
# removing list elements by either index or value. Defaults to true.
# read_before_write_list_operations_enabled: true
# Guardrail to warn or fail when querying with an IN restriction selecting more partition keys than threshold.
# The two thresholds default to -1 to disable.
# partition_keys_in_select_warn_threshold: -1
# partition_keys_in_select_fail_threshold: -1
# Guardrail to warn or fail when an IN query creates a cartesian product with a size exceeding threshold,
# eg. "a in (1,2,...10) and b in (1,2...10)" results in cartesian product of 100.
# The two thresholds default to -1 to disable.
# in_select_cartesian_product_warn_threshold: -1
# in_select_cartesian_product_fail_threshold: -1
# Guardrail to warn about or reject read consistency levels. By default, all consistency levels are allowed.
# read_consistency_levels_warned: []
# read_consistency_levels_disallowed: []
# Guardrail to warn about or reject write consistency levels. By default, all consistency levels are allowed.
# write_consistency_levels_warned: []
# write_consistency_levels_disallowed: []
# Guardrail to warn or fail when encountering larger size of collection data than threshold.
# At query time this guardrail is applied only to the collection fragment that is being writen, even though in the case
# of non-frozen collections there could be unaccounted parts of the collection on the sstables. This is done this way to
# prevent read-before-write. The guardrail is also checked at sstable write time to detect large non-frozen collections,
# although in that case exceeding the fail threshold will only log an error message, without interrupting the operation.
# The two thresholds default to null to disable.
# Min unit: B
# collection_size_warn_threshold:
# Min unit: B
# collection_size_fail_threshold:
# Guardrail to warn or fail when encountering more elements in collection than threshold.
# At query time this guardrail is applied only to the collection fragment that is being writen, even though in the case
# of non-frozen collections there could be unaccounted parts of the collection on the sstables. This is done this way to
# prevent read-before-write. The guardrail is also checked at sstable write time to detect large non-frozen collections,
# although in that case exceeding the fail threshold will only log an error message, without interrupting the operation.
# The two thresholds default to -1 to disable.
# items_per_collection_warn_threshold: -1
# items_per_collection_fail_threshold: -1
# Guardrail to allow/disallow querying with ALLOW FILTERING. Defaults to true.
# allow_filtering_enabled: true
# Guardrail to warn or fail when creating a user-defined-type with more fields in than threshold.
# Default -1 to disable.
# fields_per_udt_warn_threshold: -1
# fields_per_udt_fail_threshold: -1
# Guardrail to warn or fail when local data disk usage percentage exceeds threshold. Valid values are in [1, 100].
# This is only used for the disks storing data directories, so it won't count any separate disks used for storing
# the commitlog, hints nor saved caches. The disk usage is the ratio between the amount of space used by the data
# directories and the addition of that same space and the remaining free space on disk. The main purpose of this
# guardrail is rejecting user writes when the disks are over the defined usage percentage, so the writes done by
# background processes such as compaction and streaming don't fail due to a full disk. The limits should be defined
# accordingly to the expected data growth due to those background processes, so for example a compaction strategy
# doubling the size of the data would require to keep the disk usage under 50%.
# The two thresholds default to -1 to disable.
# data_disk_usage_percentage_warn_threshold: -1
# data_disk_usage_percentage_fail_threshold: -1
# Allows defining the max disk size of the data directories when calculating thresholds for
# disk_usage_percentage_warn_threshold and disk_usage_percentage_fail_threshold, so if this is greater than zero they
# become percentages of a fixed size on disk instead of percentages of the physically available disk size. This should
# be useful when we have a large disk and we only want to use a part of it for Cassandra's data directories.
# Valid values are in [1, max available disk size of all data directories].
# Defaults to null to disable and use the physically available disk size of data directories during calculations.
# Min unit: B
# data_disk_usage_max_disk_size:
# Guardrail to warn or fail when the minimum replication factor is lesser than threshold.
# This would also apply to system keyspaces.
# Suggested value for use in production: 2 or higher
# minimum_replication_factor_warn_threshold: -1
# minimum_replication_factor_fail_threshold: -1

# Startup Checks are executed as part of Cassandra startup process, not all of them
# are configurable (so you can disable them) but these which are enumerated bellow.
# Uncomment the startup checks and configure them appropriately to cover your needs.
#
#startup_checks:
# Verifies correct ownership of attached locations on disk at startup. See CASSANDRA-16879 for more details.
#  check_filesystem_ownership:
#    enabled: false
#    ownership_token: "sometoken" # (overriden by "CassandraOwnershipToken" system property)
#    ownership_filename: ".cassandra_fs_ownership" # (overriden by "cassandra.fs_ownership_filename")
# Prevents a node from starting if snitch's data center differs from previous data center.
#  check_dc:
#    enabled: true # (overriden by cassandra.ignore_dc system property)
# Prevents a node from starting if snitch's rack differs from previous rack.
#  check_rack:
#    enabled: true # (overriden by cassandra.ignore_rack system property)
# Enable this property to fail startup if the node is down for longer than gc_grace_seconds, to potentially
# prevent data resurrection on tables with deletes. By default, this will run against all keyspaces and tables
# except the ones specified on excluded_keyspaces and excluded_tables.
#  check_data_resurrection:
#    enabled: false
# file where Cassandra periodically writes the last time it was known to run
#    heartbeat_file: /var/lib/cassandra/data/cassandra-heartbeat
#    excluded_keyspaces: # comma separated list of keyspaces to exclude from the check
#    excluded_tables: # comma separated list of keyspace.table pairs to exclude from the check
EOF

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/cassandra.service
[Unit]
Description=Cassandra
After=network.target

[Service]
PIDFile=/tmp/cassandra.pid
ExecStart=/opt/cassandra/bin/cassandra -p /tmp/cassandra.pid -R
StandardOutput=append:/tmp/cassandra.log
StandardError=append:/tmp/cassandra-error.log
LimitNOFILE=100000
LimitMEMLOCK=infinity
LimitNPROC=32768
LimitAS=infinity

[Install]
WantedBy=default.target
EOF
systemctl enable -q --now cassandra.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
