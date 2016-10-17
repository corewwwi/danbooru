class MetaSearchesController < ApplicationController
  # XXX
  def tags
    @meta_search = MetaSearches::Tag.new(params)
    @meta_search.load_all
  end
end
