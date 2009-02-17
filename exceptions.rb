module Exceptions
  module LocationError
    class InvalidZip < StandardError; end;
    class InvalidState < StandardError; end;
    class InvalidCityState < StandardError; end;
    class InvalidLocation < StandardError; end;
  end
end