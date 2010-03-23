require File.join(File.dirname(__FILE__), 'mongo')
require File.join(File.dirname(__FILE__), 'null')

module JsChat::Storage
  def self.driver=(driver)
    @driver = driver
  end

  def self.driver ; @driver ; end

  def self.enabled=(enabled)
    @enabled = enabled
  end

  def self.enabled?
    @enabled
  end
end

