defmodule Hailo.API.NetworkGroup do
  @moduledoc """
  Represents a configured network group on a VDevice.
  """
  defstruct ref: nil,
            vdevice_ref: nil,
            name: nil,
            input_vstream_infos: [],
            output_vstream_infos: []
end
