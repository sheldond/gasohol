# Add some handy display options to the Time class
class Time
  def full_date_with_day
    self.strftime('%A, %B %d, %Y')
  end
end

# Let me ask a hash with only one member what they key or value is
class Hash
  def key
    self.keys.first if self.length == 1
  end
  
  def value
    self.values.first if self.length == 1
  end
end