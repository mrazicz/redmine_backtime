require_dependency "time_entry"

module BacktimeTimeEntryPatch
  def self.included(base)
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable

      has_one :backtime, :dependent => :destroy
      
      accepts_nested_attributes_for :backtime, :update_only => true
    end
  end

  module ClassMethods
  end

  module InstanceMethods
  end
end
