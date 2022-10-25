# `world` function of module `World`
require "./hello"

module World
  def self.world
    return "World!"
  end

  def self.hello_world
    return Hello.hello + World.world
  end

  class New
    def initialize(name : String)
      @name = name
    end

    def say_hello
      return "Hello new world: #{@name}!"
    end
  end
end
