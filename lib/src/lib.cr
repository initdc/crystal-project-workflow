require "./version"
require "./hello"
require "./world"

module Lib
  include Version
  include Hello
  include World
end
