this_path = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_path) if File.directory?(this_path) && !$:.include?(this_path)

module ZMsgraphMailer
  class ZMsgraphMailerError < StandardError; end
end

require "action_mailer"
require 'active_support/all'
require 'z_msgraph_mailer/api'

# Register the delivery method with ActionMailer
ActionMailer::Base.add_delivery_method(
  :ms_graph,
  ZMsgraphMailer::Api
)

