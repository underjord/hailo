defmodule HailoTest do
  use ExUnit.Case
  doctest Hailo

  test "greets the world" do
    assert Hailo.hello() == :world
  end
end
