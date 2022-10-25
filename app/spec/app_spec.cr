require "./spec_helper"

describe App do
  # TODO: Write tests

  it "test main" do
    got = World.hello_world
    want = "Hello, World!"
    got.should eq want
  end
end
