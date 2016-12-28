class ChangeReasonToNotNullOnPostFlagsAppeals < ActiveRecord::Migration
  def change
    change_column_null :post_flags, :reason, false
    change_column_null :post_appeals, :reason, false
  end
end
