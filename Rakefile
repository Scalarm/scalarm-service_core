require "bundler/gem_tasks"
require 'rake/testtask'
require 'ci/reporter/rake/minitest'

task :check_test_env do
  raise 'RAILS_ENV not set to test' unless Rails.env.test?
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

namespace :test do |ns|
  # add dependency to check_test_env for each test task
  ns.tasks.each do |t|
    task_name = t.to_s.match(/test:(.*)/)[1]
    task task_name.to_sym => [:check_test_env] unless task_name.blank?
  end
end

namespace :ci do
  task :all => ['ci:setup:minitest', 'test']
end

