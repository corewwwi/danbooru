class CreateUgoiraFrames < ActiveRecord::Migration
  def change
    create_table :ugoira_frames do |t|
      t.references :post,      null: false, index: true
      t.integer    :frame,     null: false
      t.integer    :delay,     null: false
      t.string     :file,      null: false
      t.string     :mime_type, null: false
    end
  end
end
