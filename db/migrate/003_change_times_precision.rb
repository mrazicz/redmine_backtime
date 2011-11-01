class ChangeTimesPrecision < ActiveRecord::Migration
  def self.up
    change_table :backtimes do |t|
      t.change :time, :decimal, :precision => 7, :scale => 2
      t.change :back_time, :decimal, :precision => 7, :scale => 2
    end
  end

  def self.down
    change_table :backtimes do |t|
      t.change :time, :decimal, :precision => 6, :scale => 1
      t.change :back_time, :decimal, :precision => 7, :scale => 1
    end
  end
end
