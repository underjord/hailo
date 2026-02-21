defmodule Hailo do
  @moduledoc """
  Elixir library for running inference on Hailo AI accelerators via HailoRT.

  Provides a high-level API for loading HEF models and running inference
  using Hailo AI accelerators. Input data is provided as Nx tensors.

  ## Usage

      {:ok, model} = Hailo.load("/path/to/model.hef")

      input = %{"input_layer_name" => my_nx_tensor}
      {:ok, detections} = Hailo.infer(model, input, Hailo.Parsers.YoloV8, classes: classes, key: "output_layer_name")

  Based on [nx_hailo](https://github.com/vittoriabitton/nx_hailo) by Vittoria Bitton and Paulo Valente.
  """

  alias Hailo.Model
  alias Hailo.API

  @doc """
  Loads a HEF model file and returns a ready-to-use model struct.

  Creates a virtual device (cached via `:persistent_term`), configures the
  network group from the HEF file, and builds an inference pipeline.

  Returns `{:ok, %Hailo.Model{}}` on success or `{:error, reason}` on failure.
  """
  @spec load(String.t()) :: {:ok, Model.t()} | {:error, term()}
  def load(hef_path) when is_binary(hef_path) do
    with {:ok, vdevice} <- API.create_vdevice(),
         {:ok, ng} <- API.configure_network_group(vdevice, hef_path),
         {:ok, pipeline_struct} <- API.create_pipeline(ng) do
      model = %Model{
        pipeline: pipeline_struct,
        name: Path.basename(hef_path)
      }

      {:ok, model}
    end
  end

  @doc """
  Runs inference on a loaded model with the given inputs.

  ## Parameters

    * `model` - A `%Hailo.Model{}` struct returned by `Hailo.load/1`
    * `inputs` - A map of input stream name to Nx tensor
    * `output_parser` - A module implementing the `Hailo.OutputParser` behaviour
    * `output_parser_opts` - Options passed to the output parser

  Returns `{:ok, parsed_results}` on success or `{:error, reason}` on failure.
  """
  @spec infer(Model.t(), map(), module(), keyword()) :: {:ok, term()} | {:error, term()}
  def infer(
        %Model{
          pipeline:
            %API.Pipeline{
              input_vstream_infos: input_vstream_infos
            } = pipeline
        },
        inputs,
        output_parser,
        output_parser_opts \\ []
      )
      when is_map(inputs) and is_atom(output_parser) do
    with {:ok, encoded_inputs} <- encode_inputs(input_vstream_infos, inputs),
         {:ok, results} <- API.infer(pipeline, encoded_inputs) do
      output_parser.parse(results, output_parser_opts)
    end
  end

  defp encode_inputs(input_vstream_infos, inputs) do
    if length(input_vstream_infos) != map_size(inputs) do
      {:error, "Number of input vstream infos does not match number of inputs"}
    else
      result =
        Enum.reduce_while(input_vstream_infos, {[], 0}, fn vstream_info, {acc, index} ->
          key = vstream_info.name
          input = Map.get(inputs, key)

          shape_size = vstream_info.shape |> Map.values() |> Enum.product()

          cond do
            is_nil(input) ->
              {:halt, {:error, "Input #{key} not found in inputs"}}

            shape_size != Nx.size(input) ->
              {:halt,
               {:error,
                "Size for input #{index} does not match vstream info shape size. Expected #{inspect(vstream_info.shape)}, got #{inspect(Nx.shape(input))}"}}

            true ->
              {:cont, {[{key, Nx.to_binary(input)} | acc], index + 1}}
          end
        end)

      case result do
        {:error, reason} ->
          {:error, reason}

        {encoded, _} ->
          {:ok, Map.new(encoded)}
      end
    end
  end
end
