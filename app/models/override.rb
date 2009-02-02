# Due to the nastyness in the quality of data the asset service, we sometimes don't get the best results for regular keyword searches.
# Overrides are a way around this. We say "if the user just entered the keyword 'marathon' then give the GSA more
# details like sport = running, type = event and custom (distance) = marathon." Now our results are much more relevant
# without the user having to select those options manually on the search page.

class Override < ActiveRecord::Base
  
  self.inheritance_column = 'none'

  # Adding our own method for searching for a matching override since the logic is more complex than a standard find.
  # We have some interesting logic here. Basically we take all overrides in the DB and then compare each one to the
  # keywords the user entered. This allows us to do a "like" search in reverse. Rather than chopping up the keywords
  # into all kinds of combinations to see if any of them have overrides, we just compare each override to what they
  # entered.
  #
  # Example: user entered "la jolla half marathon" as their keywords. The database contains overrides for the keywords
  # "marathon" and "half marathon". Obviously the whole string doesn't match anything in the database. So we try splitting
  # on spaces and looking up each in the DB. Only "marathon" will match, which would exclude half marathons! So we do the
  # opposite and compare each override to the keywords. Both 'marathon' and 'half marathon' match, but we give 'half marathon'
  # more precidence since it contains a space - multi-word overrides will win over single word overrides.
  #
  # If there are multiple matches and none of them contain a space, then the longest string will win. Example: "5k race" will
  # match an override for "5k" and for "race" but the word "race" is longer so it is the override we go with. This is probably
  # not the best way to do this, but works okay for now. Perhaps we need some logic to combine the override values for both to
  # determine which is better?
  def self.search(text)
    text = text.strip.downcase                  # remove leading/trailing whitespace, lowercase everything
    
    if output = self.find_by_keywords(text)     # first see if there is an exact match and if so return it right away
      return output
    end
    
    # we need to do a deeper search
    all_overrides = self.find(:all, :order => 'keywords')             # get all overrides in the DB, sorted alphabetically
    matching_overrides = all_overrides.find_all do |override|   # find all the overrides that are part of the keywords, return as an array
      text.include?(override.keywords)
    end
    
    if matching_overrides.empty?                # there were no matches, exit with nil
      return nil
    end
    
    if matching_overrides.length > 1            # there were multiple matches, order the array of matches by 'best match'
      overrides_with_spaces = matching_overrides.find do |o|
        o.keywords.include?(' ')
      end
      if overrides_with_spaces.nil?             # there were no overrides with spaces, just sort by length of keyword string
        matching_overrides.sort! do |a,b|
          b.keywords.length <=> a.keywords.length
        end
      else                                      # at least one of the overrides contained spaces, sort the array by number of spaces, descending
        matching_overrides.sort! do |a,b| 
          b.keywords.split(' ').length <=> a.keywords.split(' ').length
        end
      end
    end
    
    return matching_overrides.first  # after all of that, there is an array with at least 1 member, return the first

  end
  
  def to_options
    # output a standard hash that can be merged into (and therefore replace) the parameters in the query string (see ActiveSearch::search)
    options = {}
    self.class.column_names.collect do |name|
      if name != 'id' && name != 'keywords' && !self.send(name).blank? 
        options.merge!({ name.to_sym => self.send(name) })
      end
    end
    
    return options
  end
  
end
