defmodule Hailo.Model do
  @moduledoc """
  Represents a loaded Hailo model, ready for inference.
  """
  defstruct pipeline: nil,
            name: nil

  @type t :: %__MODULE__{
          pipeline: Hailo.API.Pipeline.t(),
          name: String.t()
        }
end
