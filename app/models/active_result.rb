# Extends the default Gasohol::Result class with some extra methods that are specific to our implementation

class ActiveResult < Gasohol::Result
  
  # Returns a symbol with the type of result this is
  def type
    return :activity if @meta[:category] && @meta[:category] == 'Activities'
    return :article if @meta[:category] && @meta[:category] == 'Articles'
    return :community if @url.match(/community\.active\.com/)
    return :facility if @meta[:category] && @meta[:category] == 'Facilities'
    return :org if @meta[:category] && @meta[:category] == 'Organizations'
    return :training if @meta[:media_type] && @meta[:media_type].match(/Training Plan/) || @meta[:media_type].first.match(/Training Plan/)
    # if nothing else, just return 'unknown'
    return :unknown
  end

  # Is this an activity?
  def activity?
    type == :activity
  end
  
  # Is this an article?
  def article?
    type == :article
  end
  
  # Is this a community listing?
  def community?
    type == :community
  end
  
  # Is this a facility?
  def facility?
    type == :facility
  end
  
  # Is this a club or org?
  def org?
    type == :org
  end
  
  # Is this a training plan?
  def training?
    type == :training
  end
  
  # Is this some other type I don't recognize?
  def unknown?
    type == :unknown
  end
  
end