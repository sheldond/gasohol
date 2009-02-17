# Errors for Gashol
module GasoholError
  # config options weren't passed in when Gasohol was instantiated
  class MissingConfig < StandardError; end;
  # a URL wasn't provided in the config options to Gasohol
  class MissingURL < StandardError; end;
end