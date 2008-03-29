require File.join(File.join(File.dirname(__FILE__), "hooks"), "menu")
require File.join(File.join(File.dirname(__FILE__), "hooks"), "routing")

module Hooks
  class << self
    ##
    # This returns true if the hook is within a plugin that is active, false otherwise
    def is_hook_valid?(hook)
      file = eval("__FILE__", hook.binding)
      Plugin.all(:active => true).each do |p|
        #TODO: more efficient way to do this?
        return true if file[0..p.path.length - 1] == p.path
      end
      false
    end
  end
end