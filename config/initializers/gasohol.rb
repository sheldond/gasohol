# turns debugging on in the logs (writes out the full reponse from each API call, fills up the logs FAST)
GASOHOL_DEBUGGING = false

# load up the config file and convert all keys from strings to symbols
temp_config = File.open(RAILS_ROOT+'/config/gasohol.yml') { |file| YAML::load(file) }
temp_config.symbolize_keys!
temp_config.each { |key,value| value.symbolize_keys! }
GASOHOL_CONFIG = temp_config

# get the cache server ready
begin
  CACHE = MemCache.new(GASOHOL_CONFIG[:cache][:host])
rescue MemCache::MemCacheError
  RAILS_DEFAULT_LOGGER.error('Initializing CACHE failed: memcached server not running or not responding')
end

# get the search service ready
SEARCH = ActiveSearch.new(GASOHOL_CONFIG[:google])
