
require 'fileutils'

self_path = File.expand_path(File.dirname(__FILE__))

FileUtils.rm_rf(self_path + "/.bundle")
FileUtils.rm_rf(self_path + "/vendor")
FileUtils.rm_rf(self_path + "/Gemfile.lock")
