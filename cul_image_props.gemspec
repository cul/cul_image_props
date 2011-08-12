# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'cul_image_props/image/properties/version'

Gem::Specification.new do |s|
  s.name = "cul_image_props"
  s.version = Cul::Image::Properties::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Benjamin Armintor"]
  s.email = %q{armintor@gmail.com}
  s.description = "Library for extracting basic image properties"
  s.summary = "Library for extracting basic image properties"

  # s.add_dependency('active-fedora', ">= 2.3.0")
  s.add_development_dependency "rspec", "<2.0.0"
  s.add_development_dependency "mocha", ">= 0.9.8"
  s.add_development_dependency "ruby-debug"

  s.files = Dir.glob("{bin,lib}/**/*")
  s.require_path = 'lib'
end