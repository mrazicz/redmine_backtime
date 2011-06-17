require 'redmine'
require 'dispatcher'
require 'backtime_user_patch'
require 'backtime_time_entry_patch'

require_dependency 'redmine_backtime/hooks'

Dispatcher.to_prepare do
  User.send(:include, BacktimeUserPatch) unless User.included_modules.include? BacktimeUserPatch
  TimeEntry.send(:include, BacktimeTimeEntryPatch) unless TimeEntry.included_modules.include? BacktimeTimeEntryPatch
end

Redmine::Plugin.register :redmine_backtime do
  name 'Redmine Backtime plugin'
  author 'Daniel Mrózek'
  description 'Redmine plugin for tracking time usage between professionals.'
  version '0.0.1'
  url 'https://github.cz/mrazicz/redmine_backtime'
  author_url 'https://github.cz/mrazicz'
  
  menu :top_menu, :backtime, { :controller => 'backtime', :action => 'index' }, :caption => 'BackTime', :before => :help,
       # shows BackTime tab only if current user is member of BackTime group or admin
       :if => Proc.new { User.current.group_ids.include?(Group.find_by_lastname("BackTime").id) || User.current.admin? }
end
