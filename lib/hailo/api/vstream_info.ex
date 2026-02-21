defmodule Hailo.API.VStreamInfo do
  @moduledoc """
  Represents detailed information for a single Hailo VStream.
  """
  defstruct name: nil,
            network_name: nil,
            direction: nil,
            frame_size: 0,
            format: %{},
            shape: nil,
            nms_shape: nil,
            quant_info: nil

  @type t :: %__MODULE__{
          name: String.t() | nil,
          network_name: String.t() | nil,
          direction: :h2d | :d2h | nil,
          frame_size: non_neg_integer(),
          format: map(),
          shape: map() | nil,
          nms_shape: map() | nil,
          quant_info: map() | nil
        }

  def from_map(map) when is_map(map) do
    for key <- Map.keys(%__MODULE__{}), into: %{} do
      value = map[key] || map[Atom.to_string(key)]
      {key, value}
    end
  end
end
