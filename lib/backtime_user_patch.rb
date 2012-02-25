require_dependency 'principal'
require_dependency 'user'

module BacktimeUserPatch
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable

      has_many :backtimes

    end
  end

  module ClassMethods
  end

  module InstanceMethods
  end
end
