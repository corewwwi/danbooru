class CountsController < ApplicationController
  respond_to :xml, :json

  def posts
    @count = Post.fast_count(params[:tags], :statement_timeout => CurrentUser.user.statement_timeout)
    @counts = { counts: { posts: @count }}
    respond_with(@counts) do |format|
      format.xml { render xml: @counts.to_xml(root: :counts) }
    end
  end
end
