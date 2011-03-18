# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'lib/version'

Gem::Specification.new do |s|
  s.name         = "offroad"
  s.version      = Offroad::VERSION
  s.authors      = ["David Mike Simon"]
  s.email        = "david.mike.simon@gmail.com"
  s.homepage     = "http://github.com/DavidMikeSimon/offroad"
  s.summary      = "Manages off-Internet instances of a Rails app"
  s.description  = "Offroad manages offline instances of a Rails app on computers without Internet access. The online and offline instances can communicate via mirror files, transported by the user via thumbdrive, burned CD, etc."

  s.files        = `git ls-files .`.split("\n") - ["offroad.gemspec", ".gitignore"]
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'

  s.add_dependency('ar-extensions')
end
