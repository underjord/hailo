defmodule Hailo.Parsers.YoloV8 do
  @moduledoc """
  Parser for the YOLOv8 model with embedded NMS-pruning output.

  The Hailo YOLOv8 model outputs a run-length encoded binary where each class
  has `N` detections, each with `ymin, xmin, ymax, xmax, score` fields.
  `N` can be 0 for classes with no detections.
  """

  @behaviour Hailo.OutputParser

  defmodule RawDetection do
    @moduledoc """
    Raw detected object with normalized coordinates in the padded image space.

    Coordinates are normalized: `(0, 0)` is the top-left corner and `(1, 1)` is
    the bottom-right corner of the padded (letterboxed) input image.
    """
    defstruct [:ymin, :ymax, :xmin, :xmax, :score, :class_name, :class_id]
  end

  defmodule Detection do
    @moduledoc """
    Detected object with coordinates mapped to the original image space.

    Coordinates are in pixels: `(0, 0)` is the top-left corner and
    `(height, width)` is the bottom-right corner.
    """
    defstruct [:ymin, :ymax, :xmin, :xmax, :score, :class_name, :class_id]
  end

  @impl Hailo.OutputParser
  def parse(output_map, opts) when is_list(opts) do
    opts = Keyword.validate!(opts, [:classes, :key])
    key = Keyword.fetch!(opts, :key)
    classes = Keyword.fetch!(opts, :classes)

    floats_list =
      for <<x::float-32-little <- Map.fetch!(output_map, key)>> do
        x
      end

    parse_list(floats_list, 0, classes, [])
  end

  @doc """
  Remaps raw detections from normalized padded coordinates to original image pixel coordinates.

  ## Parameters

    * `detected_objects` - List of `%RawDetection{}` structs
    * `input_shape` - Tuple `{height, width}` of the original image before padding
  """
  def postprocess(detected_objects, input_shape) do
    {input_height, input_width} = input_shape

    max_dim = max(input_height, input_width)

    padding_h = div(max_dim - input_height, 2)
    padding_w = div(max_dim - input_width, 2)

    Enum.map(detected_objects, fn %RawDetection{} = object ->
      %Detection{
        ymin: remap_coordinate(object.ymin, max_dim, padding_h, input_height),
        ymax: remap_coordinate(object.ymax, max_dim, padding_h, input_height),
        xmin: remap_coordinate(object.xmin, max_dim, padding_w, input_width),
        xmax: remap_coordinate(object.xmax, max_dim, padding_w, input_width),
        score: object.score,
        class_name: object.class_name,
        class_id: object.class_id
      }
    end)
  end

  defp remap_coordinate(coordinate, scale, padding, max_size) do
    padded_denorm = coordinate * scale
    unpadded_denorm = padded_denorm - padding

    unpadded_denorm
    |> round()
    |> max(0)
    |> min(max_size)
  end

  defp parse_list([], _, _, acc), do: {:ok, acc}

  defp parse_list([count | items], current_class, classes, acc) when count == 0 do
    parse_list(items, current_class + 1, classes, acc)
  end

  defp parse_list([count | items], current_class, classes, acc) do
    count = trunc(count)
    {class_items, rest} = Enum.split(items, count * 5)

    class_items =
      class_items
      |> Enum.chunk_every(5)
      |> Enum.map(fn [ymin, xmin, ymax, xmax, score] ->
        %RawDetection{
          xmin: xmin,
          ymin: ymin,
          xmax: xmax,
          ymax: ymax,
          score: score,
          class_id: current_class,
          class_name: classes[current_class]
        }
      end)

    parse_list(rest, current_class + 1, classes, class_items ++ acc)
  end
end
