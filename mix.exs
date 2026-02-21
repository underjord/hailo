defmodule Hailo.MixProject do
  use Mix.Project

  def project do
    [
      app: :hailo,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Hailo",
      description: "Elixir library for running inference on Hailo AI accelerators via HailoRT",
      docs: docs(),
      package: package(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      compilers: compilers(),
      make_env: fn ->
        %{
          "MIX_BUILD_EMBEDDED" => "#{Mix.Project.config()[:build_embedded]}",
          "FINE_INCLUDE_DIR" => Fine.include_dir()
        }
      end
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  def package do
    [
      name: :hailo,
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/TODO/hailo"}
    ]
  end

  def aliases do
    [
      check: [
        "hex.audit",
        "compile --warnings-as-errors --force",
        "format --check-formatted",
        "credo",
        "deps.unlock --check-unused",
        "spellweaver.check",
        "dialyzer"
      ]
    ]
  end

  def dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp compilers do
    if hailort_available?() do
      [:elixir_make] ++ Mix.compilers()
    else
      Mix.compilers()
    end
  end

  defp hailort_available? do
    match?({_, 0},
      System.cmd("sh", ["-c",
        "echo '#include <hailo/hailort.hpp>' | c++ -x c++ -E - -o /dev/null 2>/dev/null"
      ])
    )
  rescue
    _ -> false
  end

  defp deps do
    [
      {:nx, "~> 0.6"},
      {:elixir_make, "~> 0.6", runtime: false},
      {:fine, "~> 0.1.0", runtime: false},
      {:nstandard, "~> 0.1"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:spellweaver, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end
end
