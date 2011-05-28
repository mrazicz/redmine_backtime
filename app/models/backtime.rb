class Backtime < ActiveRecord::Base
  unloadable
  
  belongs_to :user
  
  validates_presence_of :user_id
  validates_numericality_of :time, :back_time
end
