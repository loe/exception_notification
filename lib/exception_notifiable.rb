require 'ipaddr'

# Copyright (c) 2005 Jamis Buck
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
module ExceptionNotifiable
  def self.included(target)
    target.extend(ClassMethods)

    # Decorate rescue_action_in_public instead of just hijacking it.
    if target.instance_methods.include? 'rescue_action_in_public' and !target.instance_methods.include? 'rescue_action_in_public_without_exception_notifier'
      target.send(:alias_method, :rescue_action_in_public_without_exception_notifier, :rescue_action_in_public)
      target.send(:alias_method, :rescue_action_in_public, :rescue_action_in_public_with_exception_notifier)
    end
  end
  
  module ClassMethods
    
    def exceptions_to_treat_as_404
      exceptions = [ActiveRecord::RecordNotFound,
        ActionController::UnknownController,
        ActionController::UnknownAction]
      exceptions << ActionController::RoutingError if ActionController.const_defined?(:RoutingError)
      exceptions
    end
    
    def consider_local(*args)
      local_addresses.concat(args.flatten.map { |a| IPAddr.new(a) })
    end
    
    def local_addresses
      addresses = read_inheritable_attribute(:local_addresses)
      unless addresses
        addresses = [IPAddr.new("127.0.0.1")]
        write_inheritable_attribute(:local_addresses, addresses)
      end
      addresses
    end
    
    def exception_data(deliverer=self)
      if deliverer == self
        read_inheritable_attribute(:exception_data)
      else
        write_inheritable_attribute(:exception_data, deliverer)
      end
    end
    
  end
  
  private
  
  def rescue_action_in_public_with_exception_notifier(exception)
    unless self.class.exceptions_to_treat_as_404.include?(exception)
      deliverer = self.class.exception_data
      data = case deliverer
        when nil then {}
        when Symbol then send(deliverer)
        when Proc then deliverer.call(self)
      end
      
      ExceptionNotifier.deliver_exception_notification(exception, self, request, data)
    end
    
    rescue_action_in_public_without_exception_notifier(exception)
  end
  
  def local_request?
    remote = IPAddr.new(request.remote_ip)
    !self.class.local_addresses.detect { |addr| addr.include?(remote) }.nil?
  end
  
end