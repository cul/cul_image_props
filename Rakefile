require 'bundler'
Bundler::GemHelper.install_tasks

# adding tasks defined in lib/tasks
Dir.glob('lib/tasks/*.rake').each { |r| import r }


#require 'spec/rake/spectask'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  #spec.libs << 'lib' << 'spec'
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  #spec.libs << 'lib' << 'spec'
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rcov = true
end

# task :spec => :check_dependencies

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = Cul::Image::Properties::VERSION 

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "cul_image_props #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end