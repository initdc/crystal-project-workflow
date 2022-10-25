# "Hello, world!"
require "../../lib/src/world"

class App
  def main
    puts World.hello_world
  end
end

a = App.new
a.main
