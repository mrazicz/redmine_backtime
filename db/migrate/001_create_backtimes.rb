class CreateBacktimes < ActiveRecord::Migration
  def self.up
    
    create_table :backtimes do |t|
      t.column :user_id, :integer
      t.column :partner_id, :integer
      t.column :time, :decimal, :precision => 6, :scale => 1
      t.column :back_time, :decimal, :precision => 7, :scale => 1
      t.column :description, :text
      t.column :created_at, :timestamp
    end
    
    if !Group.find_by_lastname("BackTime")
      Group.create  :lastname => "BackTime",
                    :type => "Group",
                    :admin => "0",
                    :status => "1"
    end
  end

  def self.down
    drop_table :backtimes
  end
end
