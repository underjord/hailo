defmodule HailoTest do
  use ExUnit.Case

  test "YoloV8 parser parses empty output" do
    # 80 classes, each with 0 detections = 80 floats of value 0.0
    binary = for _ <- 1..80, into: <<>>, do: <<0.0::float-32-little>>
    output_map = %{"output" => binary}

    classes = for i <- 0..79, into: %{}, do: {i, "class_#{i}"}

    assert {:ok, []} =
             Hailo.Parsers.YoloV8.parse(output_map, classes: classes, key: "output")
  end

  test "YoloV8 parser parses single detection" do
    # Class 0 has 1 detection, classes 1-79 have 0
    count_1 = <<1.0::float-32-little>>

    detection =
      <<0.1::float-32-little, 0.2::float-32-little, 0.3::float-32-little, 0.4::float-32-little,
        0.9::float-32-little>>

    rest_zeros = for _ <- 1..79, into: <<>>, do: <<0.0::float-32-little>>

    binary = count_1 <> detection <> rest_zeros
    output_map = %{"output" => binary}

    classes = for i <- 0..79, into: %{}, do: {i, "class_#{i}"}

    assert {:ok, [%Hailo.Parsers.YoloV8.RawDetection{class_id: 0, class_name: "class_0"}]} =
             Hailo.Parsers.YoloV8.parse(output_map, classes: classes, key: "output")
  end

  test "YoloV8 postprocess remaps coordinates" do
    raw = [
      %Hailo.Parsers.YoloV8.RawDetection{
        ymin: 0.5,
        ymax: 1.0,
        xmin: 0.0,
        xmax: 0.5,
        score: 0.95,
        class_name: "person",
        class_id: 0
      }
    ]

    result = Hailo.Parsers.YoloV8.postprocess(raw, {480, 640})

    assert [%Hailo.Parsers.YoloV8.Detection{class_name: "person"}] = result
  end
end
