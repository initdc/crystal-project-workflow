# `hello` function of module `Hello`
require "./version"

module Hello
  def self.hello
    return "Hello, "
  end

  def self.version
    Version.version
  end
end
