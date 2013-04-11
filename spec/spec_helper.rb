$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib', 'notification-dispatch'))
#puts "Load_PATH: #{$LOAD_PATH}"
require 'rubygems'
require 'notification-dispatch'
require 'rspec'
require 'dogapi'

# Set test env vars
RSpec.configure do |c|
  c.color_enabled = true
  #c.filter_run :focus => true
  #c.filter_run :broken => true
  c.filter_run_excluding :broken => true
end