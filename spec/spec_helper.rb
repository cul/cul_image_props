ENV["environment"] ||= 'development'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'cul_image_props'
require 'spec'
require 'spec/autorun'
#require 'equivalent-xml/rspec_matchers'
require 'ruby-debug'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

def fixture(file)
  File.new(File.join(File.dirname(__FILE__), 'fixtures', file),'rb')
end

def compare_property_nodesets(nodes1, nodes2)
  found_all = true
  nodes1.each { |n1|
    found = false
    nodes2.each { |n2|
      if (n2.name == n1.name) and (n2.namespace.href == n1.namespace.href)
        if (n2.text == n1.text) and (n2['rdf:resource'] == n1['rdf:resource'])
          found = true
        end
      end
    }
    found_all &&= found
  }
  found_all
end