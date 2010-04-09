# utility to check the replication status between MySQL master and slave
# dbs set up to replicate to each other
#
# All that is needed is to specify the two dbs by their rails database 
# config (environment) names (e.g. 'staging_master', 'staging_slave' or
# whatever).
#
# examples:
# 
# # specify both master and slave db configs
# monitor = MysqlReplicationMonitor.new(:master => 'master', :slave => 'slave)
# # default slave to the current environment
# monitor = MysqlReplicationMonitor.new(:master => 'master')
# # override the default time to cache the statuses (in seconds)
# monitor = MysqlReplicationMonitor.new(:master => 'master', :slave => 'slave,
#                                     :refresh_time => 10)
# # override the default database config file (not recommended)
# monitor = MysqlReplicationMonitor.new(:master => 'master', :slave => 'slave,
#                                     :db_config_file => 'foofile.txt')
#
#-------------------------------------------------------------------------------
class MysqlReplicationMonitor

  # exception raised if the class detects that either master or slave do not
  # appear to be configured for replication
  #-----------------------------------------------------------------------------
  class NoReplicationError < Exception; end


  # constructor accepts environment labels for the dbs to query replication
  # status for. if one or the other is not specified, will use the
  # rails environment that the class is currently running under. this
  # object can cache status to reduce traffic on master and slave if this
  # class's objects are to be called frequently (see :refresh_time option)
  # options:
  #   :master => string containing environment to query the master db status
  #   :slave  => string containing environment to query the slave db status
  #   (one or the other is optional, but never both)
  #   :refresh_time => how many seconds can elapse since last time the dbs
  #                    were polled before we need to hit dbs again (in between
  #                    any status methods called will just return cached
  #                    values). optional, default => 1 (cache very briefly).
  #                    recommend not setting this to 0, as calls like
  #                    slave_running? will result in two db hits.
  #   :db_config_file => file containing database config settings. optional,
  #                      default is rails default (recommended)
  #-----------------------------------------------------------------------------
  def initialize(options)
    if options.blank? || (!options.include?(:master) &&
                          !options.include?(:slave))
      raise "Invalid options configuration: should be a hash that includes " +
            "either :master or :slave or both"
    end

    # if asked to override database config file, use the special init()
    # function
    if options[:db_config_file]
      MultipleConnectionHandler.init(:config_file => options[:db_config_file])
    end

    @master_env = options[:master] || RAILS_ENV
    @slave_env = options[:slave] || RAILS_ENV

    @slave_status = nil
    @master_status = nil

    @refresh_time = options[:refresh_time] || 1
    @last_refresh = nil
  end


  # force a refresh of the cached status. overrides :refresh_time option.
  #-----------------------------------------------------------------------------
  def refresh
    @master_status = MultipleConnectionHandler.connection(@master_env).
                       execute("SHOW MASTER STATUS").all_hashes[0]
    @slave_status = MultipleConnectionHandler.connection(@slave_env).
                       execute("SHOW SLAVE STATUS").all_hashes[0]

    @last_refresh = Time.now

    if @master_status.blank? && @slave_status.blank?
      raise NoReplicationError,
            "Neither master (#{@master_env}) nor slave (#{@slave_env}) " +
              "appear to be configured for replication"
    elsif @master_status.blank?
      raise NoReplicationError,
            "Master (#{@master_env}) does not appear to be configured for replication"
    elsif @slave_status.blank?
      raise NoReplicationError,
            "Slave (#{@slave_env}) does not appear to be configured for replication"
    end
  end


  # indicates if both IO and SQL threads are running
  #-----------------------------------------------------------------------------
  def slave_running?
    cache_check_or_refresh

    slave_io_running? && slave_sql_running?
  end


  # indicates if master and slave currently have same log file and log file
  # position. note that if returns false, doesn't necessarily mean anything is
  # wrong...just that slave is lagging. but if returns true, it may be that
  # slave_running? is false.
  #-----------------------------------------------------------------------------
  def master_and_slave_in_sync?
    cache_check_or_refresh

    @master_status['Position'] == @slave_status['Exec_Master_Log_Pos'] &&
    @master_status['File'] == @slave_status['Relay_Master_Log_File']
  end


  # returns true if the slave IO thread is running
  #-----------------------------------------------------------------------------
  def slave_io_running?
    cache_check_or_refresh

    @slave_status['Slave_IO_Running'].downcase == 'yes'
  end


  # returns true if the slave SQL thread is running
  #-----------------------------------------------------------------------------
  def slave_sql_running?
    cache_check_or_refresh

    @slave_status['Slave_SQL_Running'].downcase == 'yes'
  end


  # return a hashed version of the result of running SHOW SLAVE STATUS
  # options: 
  #   :refresh_if_stale: indicate whether to refresh the status if it's stale
  #                      default is true, which should pretty much always be
  #                      used, unless you're doing some inspection and want to
  #                      be sure to see the same status that was used by the
  #                      most recent method call.
  #-----------------------------------------------------------------------------
  def raw_slave_status(options = {})
    if options.blank? || options[:refresh_if_stale]
      cache_check_or_refresh
    end

    @slave_status
  end


  # return a hashed version of the result of running SHOW MASTER STATUS
  #-----------------------------------------------------------------------------
  def raw_master_status
    cache_check_or_refresh

    @master_status
  end

  private

  # check to see if the cache needs refreshing and do so if so.
  #-----------------------------------------------------------------------------
  def cache_check_or_refresh
    if @last_refresh.nil? || @last_refresh + @refresh_time < Time.now
      refresh
    end
  end

end
