defmodule Hailo.API do
  @moduledoc false

  alias Hailo.NIF
  alias Hailo.API.VDevice
  alias Hailo.API.NetworkGroup
  alias Hailo.API.Pipeline
  alias Hailo.API.VStreamInfo

  def create_vdevice do
    if dev = :persistent_term.get({__MODULE__, :vdevice}, nil) do
      {:ok, dev}
    else
      case NIF.create_vdevice() do
        {:ok, ref} ->
          dev = %VDevice{ref: ref}
          :persistent_term.put({__MODULE__, :vdevice}, dev)
          {:ok, dev}

        error ->
          error
      end
    end
  end

  def configure_network_group(%VDevice{ref: vdevice_ref} = _vdevice, hef_path)
      when is_binary(hef_path) do
    with {:ok, ng_ref} <- NIF.configure_network_group(vdevice_ref, hef_path),
         {:ok, raw_input_infos} <- NIF.get_input_vstream_infos_from_ng(ng_ref),
         {:ok, raw_output_infos} <- NIF.get_output_vstream_infos_from_ng(ng_ref) do
      input_infos = Enum.map(raw_input_infos, &VStreamInfo.from_map/1)
      output_infos = Enum.map(raw_output_infos, &VStreamInfo.from_map/1)

      {:ok,
       %NetworkGroup{
         ref: ng_ref,
         vdevice_ref: vdevice_ref,
         input_vstream_infos: input_infos,
         output_vstream_infos: output_infos
       }}
    else
      error -> error
    end
  end

  def create_pipeline(%NetworkGroup{ref: ng_ref} = _network_group) do
    with {:ok, pipeline_ref} <- NIF.create_pipeline(ng_ref),
         {:ok, raw_input_infos} <- NIF.get_input_vstream_infos_from_pipeline(pipeline_ref),
         {:ok, raw_output_infos} <- NIF.get_output_vstream_infos_from_pipeline(pipeline_ref) do
      input_infos = Enum.map(raw_input_infos, &VStreamInfo.from_map/1)
      output_infos = Enum.map(raw_output_infos, &VStreamInfo.from_map/1)

      {:ok,
       %Pipeline{
         ref: pipeline_ref,
         network_group_ref: ng_ref,
         input_vstream_infos: input_infos,
         output_vstream_infos: output_infos
       }}
    end
  end

  def infer(
        %Pipeline{ref: pipeline_ref, input_vstream_infos: expected_infos} = _pipeline,
        input_data
      )
      when is_map(input_data) do
    case validate_input_data(expected_infos, input_data) do
      :ok ->
        NIF.infer(pipeline_ref, input_data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_input_vstream_infos(%NetworkGroup{ref: ng_ref}) do
    case NIF.get_input_vstream_infos_from_ng(ng_ref) do
      {:ok, raw_infos} -> {:ok, Enum.map(raw_infos, &VStreamInfo.from_map/1)}
      error -> error
    end
  end

  def get_input_vstream_infos(%Pipeline{ref: pipeline_ref}) do
    case NIF.get_input_vstream_infos_from_pipeline(pipeline_ref) do
      {:ok, raw_infos} -> {:ok, Enum.map(raw_infos, &VStreamInfo.from_map/1)}
      error -> error
    end
  end

  def get_output_vstream_infos(%NetworkGroup{ref: ng_ref}) do
    case NIF.get_output_vstream_infos_from_ng(ng_ref) do
      {:ok, raw_infos} -> {:ok, Enum.map(raw_infos, &VStreamInfo.from_map/1)}
      error -> error
    end
  end

  def get_output_vstream_infos(%Pipeline{ref: pipeline_ref}) do
    case NIF.get_output_vstream_infos_from_pipeline(pipeline_ref) do
      {:ok, raw_infos} -> {:ok, Enum.map(raw_infos, &VStreamInfo.from_map/1)}
      error -> error
    end
  end

  defp validate_input_data(expected_infos, input_data) do
    expected_names = Enum.map(expected_infos, & &1.name)
    provided_names = Map.keys(input_data)

    missing_streams =
      Enum.filter(expected_names, fn name -> name not in provided_names end)

    extra_streams =
      Enum.filter(provided_names, fn name -> name not in expected_names end)

    cond do
      length(missing_streams) > 0 ->
        {:error, "Missing input for vstreams: #{inspect(missing_streams)}"}

      length(extra_streams) > 0 ->
        {:error, "Extra input for vstreams: #{inspect(extra_streams)}"}

      true ->
        Enum.reduce_while(expected_infos, :ok, fn expected_info, _acc ->
          stream_name = expected_info.name
          expected_size = expected_info.frame_size
          actual_data = input_data[stream_name]

          cond do
            not is_binary(actual_data) ->
              {:halt, {:error, "Input data for vstream '#{stream_name}' must be a binary."}}

            byte_size(actual_data) != expected_size ->
              {:halt,
               {:error,
                "Invalid input data size for vstream '#{stream_name}'. Expected: #{expected_size}, Got: #{byte_size(actual_data)}"}}

            true ->
              {:cont, :ok}
          end
        end)
    end
  end
end
