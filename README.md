# Hailo

Elixir library for running inference on [Hailo](https://hailo.ai/) AI accelerators via HailoRT.

Takes Nx tensors as input, runs inference on Hailo hardware, and returns parsed results. Designed for use with YOLO models compiled to HEF format.

## Credits

This library is based on [nx_hailo](https://github.com/vittoriabitton/nx_hailo) by **Vittoria Bitton** and **Paulo Valente**. Their original work provided the C++ NIF bindings, Elixir API layer, and YOLOv8 output parser that form the foundation of this library. The original project is licensed under the MIT License (see `LICENSES/nx_hailo_MIT.txt`).

## Prerequisites

- A Hailo AI accelerator (e.g. Hailo-8L on Raspberry Pi 5)
- HailoRT installed and accessible (`libhailort` must be linkable)
- A compiled HEF model file (e.g. `yolov8m.hef` from the Hailo Model Zoo)

## Installation

Add `hailo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hailo, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Load a model
{:ok, model} = Hailo.load("/path/to/yolov8m.hef")

# Prepare input - an Nx tensor matching the model's expected input shape
# (e.g. 640x640x3 uint8 for YOLOv8)
input_tensor = Nx.from_binary(image_binary, :u8) |> Nx.reshape({640, 640, 3})

# Run inference with the YOLOv8 parser
{:ok, detections} = Hailo.infer(
  model,
  %{"yolov8m/input_layer1" => input_tensor},
  Hailo.Parsers.YoloV8,
  classes: coco_classes,
  key: "yolov8m/yolov8_nms_postprocess"
)

# Remap normalized coordinates to original image dimensions
detections = Hailo.Parsers.YoloV8.postprocess(detections, {original_height, original_width})
```

## License

MIT License - see `LICENSE.md`.
