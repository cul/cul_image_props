ENV["environment"] ||= 'development'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'cul_image_props'
require 'rspec'
require 'rspec/autorun'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

def fixture(file)
  File.new(File.join(File.dirname(__FILE__), 'fixtures', file),'rb')
end

def compare_property_nodesets(expected, actual)
  found_all = true
  expected.each { |n1|
    found = false
    actual.each { |n2|
      if (n2.name == n1.name) and (n2.namespace.href == n1.namespace.href)
        if (n2.text == n1.text) and (n2['rdf:resource'] == n1['rdf:resource'])
          found = true
        end
      end
    }
    puts "MISSING: #{n1.to_xml}" unless found
    found_all &&= found
  }
  unless found_all
    puts "EXPECTED: \"#{expected.to_xml}\""
    puts "ACTUAL: \"#{actual.to_xml}\""
  end
  found_all
end