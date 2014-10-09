class UgoiraFrame < ActiveRecord::Base
  belongs_to :post

  attr_accessible :frame, :file, :delay, :mime_type, :as => [:default]

  def frame_metadata
    return {
      file:  file,
      delay: delay
    }
  end
end
