require "rails_helper"

RSpec.describe Config do
  it "loads a mapping" do
    expect(Config.load("name: web\n")).to eq("name" => "web")
  end
end
