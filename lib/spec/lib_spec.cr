require "./spec_helper"

describe Lib do
  it "test version" do
    Version.version.should eq "0.1.0"
  end

  it "test hello" do
    Hello.hello.should eq "Hello, "
  end

  it "test world" do
    World.world.should eq "World!"
  end

  it "test World::New" do
    w = World::New.new "cyber"
    got = w.say_hello
    got.should eq "Hello new world: cyber!"
  end
end
