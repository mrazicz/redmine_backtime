require 'redmine'
require 'dispatcher'
require 'backtime_user_patch'

Dispatcher.to_prepare do
  User.send(:include, BacktimeUserPatch) unless User.included_modules.include? BacktimeUserPatch
end

Redmine::Plugin.register :redmine_backtime do
  name 'Redmine Backtime plugin'
  author 'Daniel Mrózek'
  description 'Redmine plugin for tracking time usage between professionals.'
  version '0.0.1'
  url 'https://github.cz/mrazicz/Backtime'
  author_url 'https://github.cz/mrazicz'

  menu :top_menu, :backtime, { :controller => 'backtime', :action => 'index' }, :caption => 'BackTime', :before => :help
end
