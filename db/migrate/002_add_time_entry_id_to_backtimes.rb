class AddTimeEntryIdToBacktimes < ActiveRecord::Migration
  def self.up
    add_column :backtimes, :time_entry_id, :integer
  end

  def self.down
    remove_column :backtimes, :time_entry_id
  end
end
