

self_path = File.expand_path(File.dirname(__FILE__))

Dir.chdir(self_path) do
    puts `bundle install --path vendor/bundle`
end

