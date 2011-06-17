class Backtime < ActiveRecord::Base
  unloadable
  
  belongs_to :partner, :class_name => 'User', :foreign_key => :partner_id
  belongs_to :user, :class_name => 'User', :foreign_key => :user_id
  belongs_to :time_entry

  validates_presence_of :partner_id
  #validates_numericality_of :time, :back_time

end
